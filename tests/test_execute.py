"""liorm execute tests."""

import pytest

from liq.compiler import compile
from liorm.errors import ParameterMismatch, UnknownPlan
from liorm.execute import clear_plans, execute, register_plan


@pytest.fixture(autouse=True)
def _reset_plans():
    clear_plans()
    yield
    clear_plans()


def test_register_and_execute():
    plan = compile("read agent_runs limit 5")
    pid = register_plan(
        "agent_runs.recent",
        plan_id=plan.plan_id,
        ir=plan.ir,
        sql=plan.sql,
        param_schema=plan.param_schema,
    )
    result = execute(pid, {})
    assert result.rows
    assert "SELECT" in result.sql


def test_execute_rejects_verbatim_param_in_sql():
    plan = compile("read agent_runs where status = $status limit 1")
    pid = register_plan(
        "probe",
        plan_id=plan.plan_id,
        ir=plan.ir,
        sql=plan.sql,
        param_schema=plan.param_schema,
    )
    with pytest.raises(ParameterMismatch):
        execute(pid, {"status": "$1"})


def test_execute_unknown_plan():
    with pytest.raises(UnknownPlan):
        execute("liq:missing", {})
