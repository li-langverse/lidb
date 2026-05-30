#!/usr/bin/env python3
"""PH-DB-5: lidb embed vs Postgres 15+ P95 compare for tier_db_registry."""
from __future__ import annotations

import argparse
import json
import os
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BENCH_ROOT = ROOT.parent / "benchmarks" / "benchmarks" / "tier_db_registry"
if not BENCH_ROOT.is_dir():
    BENCH_ROOT = ROOT.parent.parent / "benchmarks" / "benchmarks" / "tier_db_registry"

SCENARIOS = ("registry_publish", "registry_read_by_name", "registry_read_latest")
THRESHOLD = float(os.environ.get("BENCH_DB_REGISTRY_THRESHOLD", "1.2"))


def p95_ms(samples: list[float]) -> float:
    if not samples:
        return 0.0
    ordered = sorted(samples)
    idx = max(0, int(round(0.95 * (len(ordered) - 1))))
    return ordered[idx]


def time_fn(fn, *, warmup: int, measure: int) -> tuple[float, float]:
    for _ in range(warmup):
        fn()
    samples: list[float] = []
    for _ in range(measure):
        t0 = time.perf_counter()
        fn()
        samples.append((time.perf_counter() - t0) * 1000.0)
    return statistics.median(samples), p95_ms(samples)


def embed_binary() -> Path | None:
    env = os.environ.get("LIDB_EMBED")
    if env and Path(env).is_file():
        return Path(env)
    for c in (ROOT / "build" / "smoke" / "lidb_embed", ROOT / "build" / "lidb_embed"):
        if c.is_file():
            return c
    return None


def build_embed() -> Path | None:
    build = ROOT / "build" / "smoke"
    build.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["cmake", "-S", str(ROOT), "-B", str(build), "-DCMAKE_BUILD_TYPE=Release"],
        check=False,
        capture_output=True,
    )
    subprocess.run(
        ["cmake", "--build", str(build), "--target", "lidb_embed", "-j"],
        check=False,
        capture_output=True,
    )
    return embed_binary()


def lidb_exec(data_dir: Path, sql: str, params: list[str] | None = None) -> None:
    exe = embed_binary() or build_embed()
    if not exe:
        raise RuntimeError("lidb_embed not built")
    proc = subprocess.run(
        [str(exe), "exec-json", str(data_dir), sql],
        input=json.dumps(params or []),
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode:
        raise RuntimeError(proc.stderr or "lidb exec failed")


def lidb_open_migrate(data_dir: Path) -> None:
    exe = embed_binary() or build_embed()
    if not exe:
        raise RuntimeError("lidb_embed not built")
    for cmd in ("open", "migrate"):
        if subprocess.run([str(exe), cmd, str(data_dir)], capture_output=True).returncode:
            raise RuntimeError(f"lidb_embed {cmd} failed")


def pg_connect():
    url = os.environ.get("POSTGRES_URL") or os.environ.get("DATABASE_URL")
    if not url:
        return None
    try:
        import psycopg2  # type: ignore
    except ImportError:
        return None
    return psycopg2.connect(url)


def pg_seed(conn) -> None:
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS publishers (
            id SERIAL PRIMARY KEY, name TEXT UNIQUE NOT NULL, public_key BYTEA NOT NULL DEFAULT '\\x00'
        );
        CREATE TABLE IF NOT EXISTS packages (
            id SERIAL PRIMARY KEY, name TEXT UNIQUE NOT NULL, description TEXT
        );
        CREATE TABLE IF NOT EXISTS package_versions (
            id SERIAL PRIMARY KEY, package_id INT REFERENCES packages(id),
            version TEXT NOT NULL, tree_digest TEXT NOT NULL, proof_digest TEXT,
            coverage_pct DOUBLE PRECISION NOT NULL DEFAULT 90,
            publisher_id INT REFERENCES publishers(id) DEFAULT 1,
            published_at TIMESTAMPTZ DEFAULT now(), yanked BOOLEAN DEFAULT false,
            UNIQUE (package_id, version)
        );
        """
    )
    cur.execute("INSERT INTO publishers (name) VALUES ('bench-pub') ON CONFLICT DO NOTHING")
    cur.execute("INSERT INTO packages (name) VALUES ('bench-pkg') ON CONFLICT DO NOTHING")
    conn.commit()
    cur.close()


def run_compare(*, profile: str, warmup: int, measure: int) -> dict:
    if profile == "ci":
        warmup = min(warmup, 5)
        measure = min(measure, 30)

    lidb_dir = Path(tempfile.mkdtemp(prefix="lidb-bench-"))
    lidb_open_migrate(lidb_dir)

    # seed lidb
    lidb_exec(
        lidb_dir,
        "INSERT INTO publishers (id, name, public_key) VALUES (?, ?, ?)",
        ["1", "bench-pub", "00"],
    )
    lidb_exec(
        lidb_dir,
        "INSERT INTO packages (id, name) VALUES (?, ?)",
        ["1", "bench-pkg"],
    )
    lidb_exec(
        lidb_dir,
        "INSERT INTO package_versions (id, package_id, version, tree_digest, coverage_pct, publisher_id, yanked) "
        "VALUES (?, ?, ?, ?, ?, ?, ?)",
        ["1", "1", "0.1.0", "sha256:tree", "90", "1", "0"],
    )

    pg = pg_connect()
    pg_cur = None
    if pg:
        pg_seed(pg)
        pg_cur = pg.cursor()

    rows: list[dict] = []
    pub_n = {"n": 1}

    def lidb_publish() -> None:
        pub_n["n"] += 1
        n = pub_n["n"]
        lidb_exec(
            lidb_dir,
            "INSERT INTO package_versions (package_id, version, tree_digest, coverage_pct, publisher_id) "
            "VALUES (?, ?, ?, ?, ?)",
            ["1", f"0.0.{n}", f"sha256:t{n}", "90", "1"],
        )

    def lidb_read_name() -> None:
        lidb_exec(lidb_dir, "SELECT id, name FROM packages WHERE name = ?", ["bench-pkg"])

    def lidb_read_latest() -> None:
        lidb_exec(
            lidb_dir,
            "SELECT pv.version FROM package_versions pv JOIN packages p ON p.id = pv.package_id "
            "WHERE p.name = ?",
            ["bench-pkg"],
        )

    fns = {
        "registry_publish": lidb_publish,
        "registry_read_by_name": lidb_read_name,
        "registry_read_latest": lidb_read_latest,
    }

    for sid in SCENARIOS:
        p50_l, p95_l = time_fn(fns[sid], warmup=warmup, measure=measure)
        p95_p = None
        ratio = None
        status = "measured"
        if pg_cur:
            # Postgres timing uses equivalent SQL
            def pg_publish() -> None:
                n = pub_n["n"] + 1
                pg_cur.execute(
                    "INSERT INTO package_versions (package_id, version, tree_digest, coverage_pct) "
                    "VALUES ((SELECT id FROM packages WHERE name=%s), %s, %s, %s)",
                    ("bench-pkg", f"0.0.{n}", f"sha256:t{n}", 90.0),
                )
                pg.commit()

            def pg_read_name() -> None:
                pg_cur.execute("SELECT id, name FROM packages WHERE name=%s", ("bench-pkg",))
                pg_cur.fetchone()

            def pg_read_latest() -> None:
                pg_cur.execute(
                    """
                    SELECT pv.version FROM package_versions pv
                    JOIN packages p ON p.id = pv.package_id
                    WHERE p.name = %s ORDER BY pv.published_at DESC LIMIT 1
                    """,
                    ("bench-pkg",),
                )
                pg_cur.fetchone()

            pg_fn = {
                "registry_publish": pg_publish,
                "registry_read_by_name": pg_read_name,
                "registry_read_latest": pg_read_latest,
            }[sid]
            _, p95_p = time_fn(pg_fn, warmup=warmup, measure=measure)
            if p95_p and p95_p > 0:
                ratio = round(p95_l / p95_p, 4)
                status = "passed" if ratio <= THRESHOLD else "failed"

        rows.append(
            {
                "benchmark": sid,
                "lidb_p95_ms": round(p95_l, 4),
                "lidb_p50_ms": round(p50_l, 4),
                "postgres_p95_ms": round(p95_p, 4) if p95_p else None,
                "ratio_vs_postgres": ratio,
                "threshold": THRESHOLD,
                "status": status if pg_cur else "unknown",
            }
        )

    if pg:
        pg.close()

    return {
        "engine_mode": "lidb_vs_postgres" if pg else "lidb_only",
        "profile": profile,
        "threshold": THRESHOLD,
        "rows": rows,
        "ph_ids": ["PH-DB-5"],
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", default=os.environ.get("BENCH_PROFILE", "ci"))
    ap.add_argument("--warmup", type=int, default=20)
    ap.add_argument("--measure", type=int, default=100)
    ap.add_argument("--json-out", type=Path, required=True)
    args = ap.parse_args()

    if not embed_binary() and not build_embed():
        print("registry_oltp_compare: lidb_embed missing", file=sys.stderr)
        return 1

    payload = run_compare(profile=args.profile, warmup=args.warmup, measure=args.measure)
    args.json_out.parent.mkdir(parents=True, exist_ok=True)
    args.json_out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"registry_oltp_compare: wrote {args.json_out} mode={payload['engine_mode']}")
    for row in payload["rows"]:
        print(
            f"  {row['benchmark']}: lidb_p95={row['lidb_p95_ms']}ms "
            f"ratio={row.get('ratio_vs_postgres')} status={row['status']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
