#!/usr/bin/env python3
"""WP-N5 audit probes — invoked by tests/security/*.sh."""

from __future__ import annotations

import os
import sys
import threading
from typing import Callable

os.environ.setdefault("LIORM_EXECUTE_STUB", "1")

from liorm.audit import AppendOnlyAuditLog, record_capability_denial, redact_query_log
from liorm.capabilities import Profile, RawSqlCapability, assert_capability
from liorm.errors import CapabilityDenied
from liorm.execute import clear_plans, execute, register_plan
from liq.compiler import compile


def _probe_append_only_chain() -> bool:
    log = AppendOnlyAuditLog()
    log.append("query.executed", plan_id="p1", profile="agent")
    log.append("capability.denied", profile="mcp", capability="raw_sql:session")
    if len(log.entries()) != 2:
        return False
    if log.entries()[1].prev_hash != log.entries()[0].entry_hash:
        return False
    return log.verify_chain()


def _probe_parallel_race() -> bool:
    clear_plans()
    plan = compile("read agent_runs limit 3")
    pid = register_plan(
        "race.read",
        plan_id=plan.plan_id,
        ir=plan.ir,
        sql=plan.sql,
        param_schema=plan.param_schema,
    )
    errors: list[str] = []

    def worker(_: int) -> None:
        try:
            for _ in range(40):
                if execute(pid, {}).plan_id != pid:
                    errors.append("plan_id mismatch")
        except Exception as exc:  # noqa: BLE001
            errors.append(str(exc))

    threads = [threading.Thread(target=worker, args=(i,)) for i in range(8)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    return len(errors) == 0


def _probe_query_redaction() -> bool:
    raw = (
        "SELECT 1 WHERE password='s3cret' AND api_key='abc' "
        "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig"
    )
    redacted = redact_query_log(raw)
    return (
        "s3cret" not in redacted
        and "abc" not in redacted
        and "Bearer [REDACTED]" in redacted
        and "[REDACTED]" in redacted
    )


def _probe_capability_denial_trail() -> bool:
    log = AppendOnlyAuditLog()
    for profile in (Profile.AGENT, Profile.MCP):
        for cap in (RawSqlCapability.SESSION, RawSqlCapability.MIGRATION):
            try:
                assert_capability(profile, cap)
                return False
            except CapabilityDenied:
                record_capability_denial(log, profile, cap)
    denied = [e for e in log.entries() if e.event == "capability.denied"]
    return len(denied) == 4 and log.verify_chain()


_PROBES: dict[str, Callable[[], bool]] = {
    "audit-log-append-only": _probe_append_only_chain,
    "parallel-race-plan-registry": _probe_parallel_race,
    "query-log-redaction": _probe_query_redaction,
    "capability-denial-audit-trail": _probe_capability_denial_trail,
}


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: audit_probe.py <probe-id>", file=sys.stderr)
        return 2
    fn = _PROBES.get(argv[1])
    if fn is None:
        print(f"unknown probe: {argv[1]}", file=sys.stderr)
        return 2
    if not fn():
        print(f"FAIL {argv[1]}", file=sys.stderr)
        return 1
    print(f"PASS {argv[1]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
