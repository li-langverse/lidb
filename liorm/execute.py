"""Plan registry and execute — parameters never interpolated into SQL text."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from liorm.errors import ParameterMismatch, UnknownPlan

_PLANS: dict[str, _RegisteredPlan] = {}


@dataclass(frozen=True)
class _RegisteredPlan:
    name: str
    ir: dict[str, Any]
    sql: str
    param_schema: dict[str, str]


@dataclass(frozen=True)
class ExecuteResult:
    plan_id: str
    sql: str
    bound_params: list[Any]
    rows: list[dict[str, Any]]


def register_plan(
    name: str,
    *,
    plan_id: str,
    ir: dict[str, Any],
    sql: str,
    param_schema: dict[str, str],
) -> str:
    """Register a compiled plan; returns plan_id."""
    _PLANS[plan_id] = _RegisteredPlan(
        name=name,
        ir=ir,
        sql=sql,
        param_schema=dict(param_schema),
    )
    return plan_id


def _ordered_params(schema: dict[str, str], params: dict[str, Any]) -> list[Any]:
    """Bind params in $1..$N order as declared by schema keys."""
    keys = list(schema.keys())
    return [params[k] for k in keys]


def execute(plan_id: str, params: dict[str, Any]) -> ExecuteResult:
    """
    Execute a registered plan.

    Invariants:
    - User param values never appear verbatim in the SQL text.
    - Extra/missing param keys raise ParameterMismatch.
    """
    plan = _PLANS.get(plan_id)
    if plan is None:
        raise UnknownPlan(f"unknown plan_id: {plan_id}")

    expected = set(plan.param_schema.keys())
    given = set(params.keys())
    if given != expected:
        missing = expected - given
        extra = given - expected
        raise ParameterMismatch(
            f"param mismatch for {plan_id}: missing={sorted(missing)} extra={sorted(extra)}"
        )

    for key, value in params.items():
        if isinstance(value, str) and value in plan.sql:
            raise ParameterMismatch(
                f"param value must not appear verbatim in SQL text (possible injection): {key!r}"
            )

    bound = _ordered_params(plan.param_schema, params)
    rows = _run_engine(plan.sql, bound)
    return ExecuteResult(
        plan_id=plan_id,
        sql=plan.sql,
        bound_params=bound,
        rows=rows,
    )


def _run_engine(sql: str, bound: list[Any]) -> list[dict[str, Any]]:
    from liorm import embed_engine

    if not embed_engine.engine_ready():
        raise RuntimeError(
            "embedded engine unavailable (native lidb_embed required; PH-DB-3.1 sqlite cutover)"
        )
    return embed_engine.execute_sql(sql, bound)


def clear_plans() -> None:
    """Test helper — reset plan registry."""
    _PLANS.clear()
