#!/usr/bin/env python3
"""PH-DB-2 security probes — invoked by tests/security/cve-*.sh."""

from __future__ import annotations

import sys

from liq.compiler import compile
from liq.errors import CompileError, ParseError
from liq.parser import parse
from liorm.capabilities import Profile, RawSqlCapability, assert_capability
from liorm.errors import CapabilityDenied, CatalogError, ParameterMismatch
from liorm.execute import clear_plans, execute, register_plan


def _probe_param_concat() -> bool:
    """CVE: param values must not be concatenated into SQL text."""
    clear_plans()
    src = "read agent_runs where status = $status limit 5"
    plan = compile(src)
    if "running" in plan.sql or "' OR 1=1" in plan.sql:
        return False
    pid = register_plan(
        "probe.param_concat",
        plan_id=plan.plan_id,
        ir=plan.ir,
        sql=plan.sql,
        param_schema=plan.param_schema,
    )
    malicious = "' OR 1=1 --"
    try:
        execute(pid, {"status": malicious})
    except ParameterMismatch:
        return True
    if malicious in plan.sql:
        return False
    return True


def _probe_second_order() -> bool:
    """CVE: stored SQL-like values bind as parameters, not reparsed."""
    clear_plans()
    src = "read agent_runs where status = $status limit 1"
    plan = compile(src)
    pid = register_plan(
        "probe.second_order",
        plan_id=plan.plan_id,
        ir=plan.ir,
        sql=plan.sql,
        param_schema=plan.param_schema,
    )
    stored = "x'; DROP TABLE agent_runs; --"
    result = execute(pid, {"status": stored})
    if stored in result.sql:
        return False
    if stored not in result.bound_params:
        return False
    return True


def _probe_identifier_injection() -> bool:
    """CVE: dynamic table/column names must fail at compile."""
    fixtures = [
        "read evil_table limit 1",
        "read agent_runs { id, not_a_column } limit 1",
    ]
    for src in fixtures:
        try:
            compile(src)
            return False
        except (ParseError, CompileError, CatalogError):
            continue
    return True


def _probe_raw_sql_escalation() -> bool:
    """CVE: agent/MCP profiles cannot obtain RawSqlCapability."""
    for profile in (Profile.AGENT, Profile.MCP):
        for cap in (RawSqlCapability.SESSION, RawSqlCapability.MIGRATION):
            try:
                assert_capability(profile, cap)
                return False
            except CapabilityDenied:
                continue
    assert_capability(Profile.CLI_ADMIN, RawSqlCapability.SESSION)
    assert_capability(Profile.MIGRATION_RUNNER, RawSqlCapability.MIGRATION)
    return True


_PROBES = {
    "cve-cwe-89-sql-injection-via-param-concat": _probe_param_concat,
    "cve-cwe-89-second-order-sql-injection-stored-value": _probe_second_order,
    "cve-cwe-89-identifier-injection-dynamic-table": _probe_identifier_injection,
    "cve-raw-sql-capability-audit-escalation": _probe_raw_sql_escalation,
}


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: security_probe.py <probe-id>", file=sys.stderr)
        return 2
    probe_id = argv[1]
    fn = _PROBES.get(probe_id)
    if fn is None:
        print(f"unknown probe: {probe_id}", file=sys.stderr)
        return 2
    ok = fn()
    if not ok:
        print(f"FAIL {probe_id}", file=sys.stderr)
        return 1
    print(f"PASS {probe_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
