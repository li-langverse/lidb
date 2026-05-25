"""liq compiler tests."""

import pytest

from liorm.errors import CatalogError
from liq.compiler import compile


def test_compile_read_produces_placeholders():
    plan = compile("read agent_runs where status = $status limit 10")
    assert "$1" in plan.sql
    assert "status" in plan.param_schema
    assert plan.ir["op"] == "read"
    assert plan.plan_id.startswith("liq:")


def test_compile_unknown_table_fails():
    with pytest.raises(CatalogError):
        compile("read not_in_catalog limit 1")


def test_compile_no_verbatim_param_in_sql():
    plan = compile("read agent_runs where status = $status limit 1")
    assert "running" not in plan.sql
