#!/usr/bin/env python3
"""Write tier_db latest.csv rows (benchmarks ingest format)."""
from __future__ import annotations

import csv
import os
import platform
import subprocess
import sys
from pathlib import Path
from typing import Any

FIELDNAMES = [
    "benchmark",
    "lang",
    "variant",
    "threads",
    "metric",
    "value",
    "unit",
    "git_sha",
    "cpu_model",
    "flags",
    "passed",
    "os",
]


def git_sha() -> str:
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            stderr=subprocess.DEVNULL,
            text=True,
        )
        return out.strip() or "unknown"
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "unknown"


def host_os() -> str:
    sysname = platform.system().lower()
    if sysname == "darwin":
        return "darwin"
    if sysname == "linux":
        return "linux"
    if sysname == "windows":
        return "windows"
    return sysname or "unknown"


def cpu_model() -> str:
    machine = platform.machine().lower()
    if machine in ("arm64", "aarch64"):
        return "arm"
    if machine in ("x86_64", "amd64"):
        return "x86_64"
    return machine or "unknown"


def base_row(
    *,
    benchmark: str,
    lang: str,
    metric: str,
    value: str | float | None,
    unit: str,
    variant: str = "ci",
    passed: bool | None = None,
    flags: str = "",
) -> dict[str, str]:
    row: dict[str, str] = {
        "benchmark": benchmark,
        "lang": lang,
        "variant": variant,
        "threads": "1",
        "metric": metric,
        "value": "" if value is None else str(value),
        "unit": unit,
        "git_sha": git_sha(),
        "cpu_model": cpu_model(),
        "flags": flags,
        "passed": "",
        "os": host_os(),
    }
    if passed is not None:
        row["passed"] = "true" if passed else "false"
    return row


def blocked_row(
    benchmark: str,
    metric: str,
    unit: str,
    *,
    reason: str,
    variant: str = "ci",
) -> dict[str, str]:
    return base_row(
        benchmark=benchmark,
        lang="lidb",
        metric=metric,
        value=None,
        unit=unit,
        variant=variant,
        passed=False,
        flags=f"harness_blocked:{reason}",
    )


def measured_row(
    benchmark: str,
    metric: str,
    value: float,
    unit: str,
    *,
    variant: str = "ci",
    flags: str = "",
) -> dict[str, str]:
    return base_row(
        benchmark=benchmark,
        lang="lidb",
        metric=metric,
        value=round(value, 6),
        unit=unit,
        variant=variant,
        passed=True,
        flags=flags,
    )


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def benchmarks_tier_root() -> Path:
    env = os.environ.get("BENCH_TIER_DB_ROOT", "").strip()
    if env:
        return Path(env) / "benchmarks"
    return Path(__file__).resolve().parents[2].parent / "benchmarks" / "benchmarks"


def split_by_tier(
    rows: list[dict[str, str]], bench_root: Path
) -> dict[str, list[dict[str, str]]]:
    """Map catalog benchmark ids to tier_db_* result directories."""
    tier_dirs = {
        "ann_qps_10k": "tier_db_vector_ann",
        "ann_recall_at_10_10k": "tier_db_vector_ann",
        "ann_recall_at_10_1m": "tier_db_vector_ann",
        "gpu_ann_speedup_10k": "tier_db_gpu_speedup",
        "gpu_ann_speedup_1m": "tier_db_gpu_speedup",
        "graph_cycle_detect": "tier_db_graph_registry",
        "graph_dep_closure": "tier_db_graph_registry",
        "registry_publish": "tier_db_registry",
        "registry_read_by_name": "tier_db_registry",
        "registry_read_latest": "tier_db_registry",
        "injection_blocked": "tier_db_security",
        "rls_bypass_blocked": "tier_db_security",
        "rss_idle": "tier_db_memory",
        "rss_peak_load": "tier_db_memory",
        "concurrent_readers": "tier_db_parallel",
        "concurrent_writers": "tier_db_parallel",
        "query_log_complete": "tier_db_audit",
        "tamper_evidence": "tier_db_audit",
        "ws_publish_latency": "tier_db_realtime",
    }
    buckets: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        bench = row["benchmark"]
        tier = tier_dirs.get(bench)
        if not tier:
            continue
        buckets.setdefault(tier, []).append(row)
    out: dict[str, list[dict[str, str]]] = {}
    for tier, tier_rows in buckets.items():
        out[str(bench_root / tier / "results" / "latest.csv")] = tier_rows
    return out


def emit_all(rows: list[dict[str, str]], bench_root: Path) -> list[Path]:
    paths: list[Path] = []
    for csv_path, tier_rows in split_by_tier(rows, bench_root).items():
        p = Path(csv_path)
        write_csv(p, tier_rows)
        paths.append(p)
        print(f"wrote {p} ({len(tier_rows)} rows)", file=sys.stderr)
    return paths


def main(argv: list[str] | None = None) -> int:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from tier_db_csv_impl import collect_rows  # noqa: PLC0415

    rows = collect_rows()
    emit_all(rows, benchmarks_tier_root())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
