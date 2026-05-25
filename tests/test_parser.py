"""liq parser tests."""

import pytest

from liq.errors import ParseError
from liq.parser import ReadStmt, parse


def test_parse_read_limit():
    stmt = parse("read agent_runs limit 20")
    assert isinstance(stmt, ReadStmt)
    assert stmt.table.raw == "agent_runs"
    assert stmt.limit == 20


def test_parse_read_where_param():
    stmt = parse("read agent_runs where status = $status limit 5")
    assert stmt.where is not None
    assert stmt.where.rhs.name == "status"  # type: ignore[attr-defined]


def test_reject_dollar_brace():
    with pytest.raises(ParseError, match="forbidden"):
        parse("read agent_runs where status = ${status}")


def test_reject_semicolon():
    with pytest.raises(ParseError, match="forbidden"):
        parse("read agent_runs; drop table agent_runs")


def test_parse_insert():
    stmt = parse("insert package_versions { package_id: $pkg, version: $ver }")
    assert stmt.table.raw == "package_versions"
    assert len(stmt.bindings) == 2


def test_parse_update():
    stmt = parse("update publishers set display_name = $name where id = $id")
    assert stmt.table.raw == "publishers"
    assert stmt.where is not None


def test_parse_delete():
    stmt = parse("delete from agent_runs where run_id = $rid")
    assert stmt.table.raw == "agent_runs"
