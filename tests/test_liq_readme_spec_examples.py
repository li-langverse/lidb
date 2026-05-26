"""Executable examples from liq/README.md and docs/liq-spec.md §3 / §6."""

from __future__ import annotations

import pytest

from liq.compiler import compile
from liorm.execute import clear_plans, execute, register_plan

_PUB_ID = "00000000-0000-4000-8000-000000000010"
_PKG_ID = "00000000-0000-4000-8000-000000000020"


def _doc_params(source: str, param_schema: dict[str, str]) -> dict[str, str]:
    """Bind doc-example params to native catalog seed rows."""
    if "update publishers" in source:
        return {
            "name": "Updated Publisher",
            "id": _PUB_ID,
        }
    if "read publishers" in source and "name" in param_schema:
        return {"name": "pytest-publisher"}
    defaults = {
        "status": "running",
        "pub": _PUB_ID,
        "pkg": _PKG_ID,
        "ver": "0.0.2-doc",
        "sha": "sha256:doc-example",
    }
    return {k: defaults.get(k, f"v-{k}") for k in param_schema}

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
    params = _doc_params(source, plan.param_schema)
    assert execute(pid, params).rows
