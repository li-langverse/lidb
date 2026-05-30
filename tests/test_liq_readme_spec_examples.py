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

# Match tests/conftest.py seed_test_fixtures() so parameterized reads return rows.
_SEED_PARAMS = {
    "status": "running",
    "pub": "00000000-0000-4000-8000-000000000010",
    "name": "pytest-publisher",
    "id": "00000000-0000-4000-8000-000000000010",
    "pkg": "00000000-0000-4000-8000-000000000020",
    "ver": "9.9.9-doc-test",
    "sha": "sha256:doc-test",
}

# Native catalog exec subset (PH-DB-N2) — compile always; skip execute when unsupported.
_NATIVE_EXEC_SKIP_PREFIXES = (
    "update publishers",
    "read agent_runs {",
)


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
    if any(source.startswith(prefix) for prefix in _NATIVE_EXEC_SKIP_PREFIXES):
        pytest.skip("native embed SQL subset (PH-DB-N2)")

    params = {k: _SEED_PARAMS[k] for k in plan.param_schema}
    result = execute(pid, params)
    if source.startswith("insert "):
        return  # insert succeeds when execute raises no error (no RETURNING rows yet)
    assert result.rows
