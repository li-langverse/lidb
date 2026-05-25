"""Executable examples from liq/README.md and docs/liq-spec.md §3 / §6."""

from __future__ import annotations

import pytest

from liq.compiler import compile
from liorm.execute import clear_plans, execute, register_plan

# liq/README.md — AST-oriented examples
LIQ_README_EXAMPLES = [
    "read agent_runs limit 20",
    "read agent_runs where status = $status limit 20",
    "read agent_runs { id, created_at, status } where publisher_id = $pub order created_at desc limit 50",
    "insert package_versions { package_id: $pkg, version: $ver, tarball_sha256: $sha }",
    "update publishers set display_name = $name where id = $id returning id, display_name",
]

# docs/liq-spec.md — comparative / integration shapes
LIQ_SPEC_EXAMPLES = [
    "read package_versions limit 10",
    "read publishers where name = $name limit 1",
]


@pytest.fixture(autouse=True)
def _reset():
    clear_plans()
    yield
    clear_plans()


@pytest.mark.parametrize("source", LIQ_README_EXAMPLES + LIQ_SPEC_EXAMPLES)
def test_liq_doc_example_compiles_and_executes(source: str) -> None:
    plan = compile(source)
    pid = register_plan(
        f"doc.{plan.plan_id}",
        plan_id=plan.plan_id,
        ir=plan.ir,
        sql=plan.sql,
        param_schema=plan.param_schema,
    )
    params = {k: f"v-{k}" for k in plan.param_schema}
    assert execute(pid, params).rows
