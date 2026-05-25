#!/usr/bin/env python3
"""Emit tier_db_* harness JSON for benchmarks ingest (stdout or BENCH_HARNESS_JSON)."""
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from typing import Any


def tier_status(scenarios: list[dict[str, Any]]) -> str:
    statuses = {s.get("status") for s in scenarios}
    if "red" in statuses:
        return "fail"
    measured = statuses - {"stub"}
    if not measured:
        return "stub"
    if measured <= {"green"}:
        return "pass"
    if measured == {"unknown"} or measured <= {"unknown", "stub"}:
        return "unknown"
    return "unknown"


def build_payload(*, tier: str, profile: str, scenarios: list[dict[str, Any]]) -> dict[str, Any]:
    for s in scenarios:
        s.setdefault("engines", {"lidb": None, "postgres": None})
        if "lidb" in s:
            s["engines"]["lidb"] = s.pop("lidb")
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "tier": tier,
        "profile": profile,
        "status": tier_status(scenarios),
        "compare_oracle": None,
        "harness_repo": "lidb",
        "harness_version": os.environ.get("LIDB_BENCH_HARNESS_VERSION", "1"),
        "scenarios": scenarios,
        "ph_ids": [],
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tier", required=True)
    ap.add_argument("--profile", default=os.environ.get("BENCH_PROFILE", "ci"))
    ap.add_argument("scenarios_json", help="JSON array of scenario objects")
    args = ap.parse_args(argv)

    scenarios = json.loads(args.scenarios_json)
    payload = build_payload(tier=args.tier, profile=args.profile, scenarios=scenarios)
    text = json.dumps(payload, indent=2) + "\n"
    out_path = os.environ.get("BENCH_HARNESS_JSON", "").strip()
    if out_path:
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"wrote {out_path} (tier={args.tier}, status={payload['status']})")
    else:
        sys.stdout.write(text)
    return 0 if payload["status"] != "fail" else 1


if __name__ == "__main__":
    raise SystemExit(main())
