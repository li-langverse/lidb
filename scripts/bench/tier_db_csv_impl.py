"""Collect tier_db catalog CSV rows (measured + honest blocked)."""
from __future__ import annotations

import os
import platform
import statistics
import subprocess
import tempfile
import time
import uuid
from pathlib import Path
from typing import Any

from emit_csv import base_row, blocked_row, measured_row

LIDB_ROOT = Path(__file__).resolve().parents[2]
BUILD_DIR = Path(os.environ.get("LIDB_BUILD_DIR", LIDB_ROOT / "build" / "bench"))
EMBED = Path(os.environ.get("LIDB_EMBED", BUILD_DIR / "lidb_embed"))
VARIANT = os.environ.get("BENCH_PROFILE", "ci")
READ_ITERS = int(os.environ.get("BENCH_REGISTRY_READ_ITERS", "40"))


def ensure_embed() -> Path:
    if EMBED.is_file() and os.access(EMBED, os.X_OK):
        return EMBED
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["cmake", "-S", str(LIDB_ROOT), "-B", str(BUILD_DIR), "-DCMAKE_BUILD_TYPE=Release"],
        check=True,
        stdout=subprocess.DEVNULL,
    )
    subprocess.run(
        ["cmake", "--build", str(BUILD_DIR), "--target", "lidb_embed", "-j"],
        check=True,
        stdout=subprocess.DEVNULL,
    )
    if not EMBED.is_file():
        raise RuntimeError(f"failed to build {EMBED}")
    return EMBED


def p95_ms(samples: list[float]) -> float:
    if not samples:
        return 0.0
    ordered = sorted(samples)
    idx = min(len(ordered) - 1, int(len(ordered) * 0.95))
    return ordered[idx]


def exec_sql(embed: Path, data_dir: Path, sql: str) -> None:
    subprocess.run(
        [str(embed), "exec", str(data_dir), sql],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def seed_registry(embed: Path, data_dir: Path) -> tuple[str, str]:
    pub = str(uuid.uuid4())
    pkg = str(uuid.uuid4())
    ver = str(uuid.uuid4())
    exec_sql(
        embed,
        data_dir,
        f"INSERT INTO publishers (id, name, public_key) VALUES ('{pub}', 'bench-publisher', '00');",
    )
    exec_sql(
        embed,
        data_dir,
        f"INSERT INTO packages (id, name, description) VALUES ('{pkg}', 'li-bench', 'harness seed');",
    )
    exec_sql(
        embed,
        data_dir,
        (
            "INSERT INTO package_versions (id, package_id, version, tree_digest, coverage_pct, publisher_id) "
            f"VALUES ('{ver}', '{pkg}', '0.0.1-bench', 'sha256:bench', 100.0, '{pub}');"
        ),
    )
    return pkg, pub


def time_query(embed: Path, data_dir: Path, sql: str, *, iters: int) -> float:
    samples: list[float] = []
    for _ in range(iters):
        t0 = time.perf_counter()
        exec_sql(embed, data_dir, sql)
        samples.append((time.perf_counter() - t0) * 1000.0)
    return p95_ms(samples)


def peak_rss_kib_darwin(cmd: list[str]) -> int:
    out = subprocess.run(
        ["/usr/bin/time", "-l", *cmd],
        capture_output=True,
        text=True,
        check=False,
    )
    for line in (out.stderr or "").splitlines():
        if "maximum resident set size" in line:
            parts = line.split()
            try:
                return int(float(parts[-1]) / 1024)
            except (ValueError, IndexError):
                pass
    return 0


def measure_memory(embed: Path, data_dir: Path) -> tuple[float, float]:
    load_sql = "SELECT COUNT(*) FROM package_versions"
    clients = int(os.environ.get("BENCH_MEMORY_CLIENTS", "4"))
    duration = int(os.environ.get("BENCH_MEMORY_LOAD_SEC", "1"))
    idle_kib = peak_rss_kib_darwin([str(embed), "exec", str(data_dir), load_sql])
    peak_kib = idle_kib
    import concurrent.futures

    def worker() -> None:
        end = time.time() + duration
        while time.time() < end:
            exec_sql(embed, data_dir, load_sql)

    with concurrent.futures.ThreadPoolExecutor(max_workers=clients) as pool:
        futs = [pool.submit(worker) for _ in range(clients)]
        concurrent.futures.wait(futs)
    exec_kib = peak_rss_kib_darwin([str(embed), "exec", str(data_dir), load_sql])
    peak_kib = max(peak_kib, exec_kib)
    return idle_kib / 1024.0, peak_kib / 1024.0


def measure_parallel_readers(embed: Path, data_dir: Path) -> float:
    load_sql = "SELECT COUNT(*) FROM package_versions"
    clients = int(os.environ.get("BENCH_PARALLEL_CLIENTS", "4"))
    duration = int(os.environ.get("BENCH_PARALLEL_DURATION_SEC", "1"))
    total_ops = 0

    def worker() -> int:
        n = 0
        end = time.time() + duration
        while time.time() < end:
            exec_sql(embed, data_dir, load_sql)
            n += 1
        return n

    import concurrent.futures

    with concurrent.futures.ThreadPoolExecutor(max_workers=clients) as pool:
        total_ops = sum(pool.map(lambda _: worker(), range(clients)))
    return round(total_ops / max(duration, 1), 2)


def measure_security() -> tuple[dict[str, Any], dict[str, Any]]:
    """CVE probes via security_probe.py; RLS scripts optional."""
    probes = [
        "cve-cwe-89-sql-injection-via-param-concat",
        "cve-cwe-89-second-order-sql-injection-stored-value",
        "cve-cwe-89-identifier-injection-dynamic-table",
        "cve-raw-sql-capability-audit-escalation",
    ]
    passed = 0
    failed = 0
    for probe in probes:
        rc = subprocess.run(
            ["python3", str(LIDB_ROOT / "scripts" / "security_probe.py"), probe],
            cwd=str(LIDB_ROOT),
            env={**os.environ, "PYTHONPATH": str(LIDB_ROOT)},
            capture_output=True,
        )
        if rc.returncode == 0:
            passed += 1
        else:
            failed += 1
    total = passed + failed
    inj: dict[str, Any]
    if total == 0:
        inj = {"value": None, "passed": False, "flags": "harness_blocked:no_probes"}
    elif failed == 0:
        inj = {"value": passed / total, "passed": True, "flags": f"probes_pass={passed}"}
    else:
        inj = {"value": passed / total, "passed": False, "flags": f"probes_fail={failed}"}

    rls_pass = 0
    rls_fail = 0
    rls_skip = 0
    if os.environ.get("LIDB_RLS_HARNESS") == "1":
        for script in sorted((LIDB_ROOT / "tests" / "security").glob("rls-*.test.sh")):
            proc = subprocess.run(["bash", str(script)], capture_output=True, text=True)
            if proc.returncode == 0 and "SKIP " in (proc.stdout or ""):
                rls_skip += 1
            elif proc.returncode == 0:
                rls_pass += 1
            else:
                rls_fail += 1
    else:
        rls_skip = len(list((LIDB_ROOT / "tests" / "security").glob("rls-*.test.sh")))

    rls_total = rls_pass + rls_fail
    rls: dict[str, Any]
    if rls_total == 0:
        rls = {
            "value": None,
            "passed": False,
            "flags": f"harness_blocked:rls_skipped={rls_skip}",
        }
    elif rls_fail == 0:
        rls = {"value": rls_pass / rls_total, "passed": True, "flags": f"rls_pass={rls_pass}"}
    else:
        rls = {"value": rls_pass / rls_total, "passed": False, "flags": f"rls_fail={rls_fail}"}
    return inj, rls


def collect_rows() -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    embed = ensure_embed()
    data_dir = Path(tempfile.mkdtemp(prefix="lidb-tier-db-csv."))
    try:
        subprocess.run(
            [str(embed), "open", str(data_dir)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        subprocess.run(
            [str(embed), "migrate", str(data_dir)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        pkg_id, pub_id = seed_registry(embed, data_dir)
        idle_kib = peak_rss_kib_darwin([str(embed), "migrate", str(data_dir)])

        read_name_sql = "SELECT id FROM packages WHERE name = 'li-bench';"
        read_latest_sql = f"SELECT version FROM package_versions WHERE package_id = '{pkg_id}';"
        rows.append(
            measured_row(
                "registry_read_by_name",
                "latency_p95",
                time_query(embed, data_dir, read_name_sql, iters=READ_ITERS),
                "ms",
                variant=VARIANT,
                flags="lidb_embed_smoke",
            )
        )
        rows.append(
            measured_row(
                "registry_read_latest",
                "latency_p95",
                time_query(embed, data_dir, read_latest_sql, iters=READ_ITERS),
                "ms",
                variant=VARIANT,
                flags="lidb_embed_smoke",
            )
        )
        pub_sql = (
            "INSERT INTO package_versions (id, package_id, version, tree_digest, coverage_pct, publisher_id) "
            f"VALUES ('{uuid.uuid4()}', '{pkg_id}', '0.0.2-bench', 'sha256:bench2', 100.0, '{pub_id}');"
        )
        try:
            rows.append(
                measured_row(
                    "registry_publish",
                    "latency_p95",
                    time_query(embed, data_dir, pub_sql, iters=max(10, READ_ITERS // 4)),
                    "ms",
                    variant=VARIANT,
                    flags="lidb_embed_smoke_insert",
                )
            )
        except subprocess.CalledProcessError:
            rows.append(
                blocked_row(
                    "registry_publish",
                    "latency_p95",
                    "ms",
                    reason="publish_insert_failed",
                    variant=VARIANT,
                )
            )

        idle_mb, peak_mb = measure_memory(embed, data_dir)
        if idle_kib:
            idle_mb = max(idle_mb, idle_kib / 1024.0)
        rows.append(measured_row("rss_idle", "rss_mb", idle_mb, "mb", variant=VARIANT))
        rows.append(measured_row("rss_peak_load", "rss_mb", peak_mb, "mb", variant=VARIANT))

        ops = measure_parallel_readers(embed, data_dir)
        rows.append(
            measured_row(
                "concurrent_readers",
                "ops_per_sec",
                ops,
                "ops",
                variant=VARIANT,
                flags="lidb_embed_parallel",
            )
        )
        rows.append(
            blocked_row(
                "concurrent_writers",
                "ops_per_sec",
                "ops",
                reason="writer_scalability_pending",
                variant=VARIANT,
            )
        )

        inj, rls = measure_security()
        rows.append(
            base_row(
                benchmark="injection_blocked",
                lang="lidb",
                metric="pass_rate",
                value=inj["value"],
                unit="ratio",
                variant=VARIANT,
                passed=bool(inj["passed"]) if inj.get("passed") is not None else False,
                flags=str(inj.get("flags", "")),
            )
        )
        rows.append(
            base_row(
                benchmark="rls_bypass_blocked",
                lang="lidb",
                metric="pass_rate",
                value=rls["value"],
                unit="ratio",
                variant=VARIANT,
                passed=bool(rls["passed"]) if rls.get("passed") is not None else False,
                flags=str(rls.get("flags", "")),
            )
        )
    finally:
        import shutil

        shutil.rmtree(data_dir, ignore_errors=True)

    blocked_specs = [
        ("ann_qps_10k", "queries_per_sec", "qps", "vector_ann_harness_pending"),
        ("ann_recall_at_10_10k", "recall_at_10", "ratio", "vector_ann_harness_pending"),
        ("ann_recall_at_10_1m", "recall_at_10", "ratio", "vector_ann_nightly_pending"),
        ("gpu_ann_speedup_10k", "speedup_ratio", "ratio", "gpu_harness_pending"),
        ("gpu_ann_speedup_1m", "speedup_ratio", "ratio", "gpu_harness_nightly_pending"),
        ("graph_cycle_detect", "latency_p95", "ms", "graph_registry_harness_pending"),
        ("graph_dep_closure", "latency_p95", "ms", "graph_registry_harness_pending"),
        ("query_log_complete", "completeness_ratio", "ratio", "audit_harness_pending"),
        ("tamper_evidence", "pass_rate", "ratio", "audit_harness_pending"),
        ("ws_publish_latency", "latency_p95", "ms", "realtime_harness_pending"),
    ]
    for bench, metric, unit, reason in blocked_specs:
        rows.append(
            blocked_row(bench, metric, unit, reason=reason, variant=VARIANT)
        )
    return rows
