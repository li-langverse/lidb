"""Native Li SQL layer — liq compile + lidb_embed exec-json (WP-N2)."""

import json
import re
import subprocess
from pathlib import Path

import pytest

from liq.compiler import compile
from liorm.embed_engine import (
    _build_embed,
    _embed_binary,
    execute_sql,
    probe_engine_ready,
    repo_root,
    reset_session_for_tests,
)
from liorm.execute import clear_plans, execute, register_plan

_PARAM_RE = re.compile(r"\$(\d+)")


def _flatten_sql(pg_sql: str) -> str:
    sql = re.sub(r'"[^"]+"\."([^"]+)"\."([^"]+)"', r"\2", pg_sql)
    sql = re.sub(r'"[^"]+"\."([^"]+)"', r"\1", sql)
    return _PARAM_RE.sub("?", sql)


@pytest.mark.parametrize(
    "source",
    [
        "read agent_runs limit 5",
        "read agent_runs where status = $status limit 10",
        "read package_versions where version = $ver limit 1",
    ],
)
def test_compile_registry_queries_use_placeholders(source: str):
    plan = compile(source)
    if plan.param_schema:
        assert "$" in plan.sql or "?" in _flatten_sql(plan.sql)
    assert plan.plan_id.startswith("liq:")


@pytest.mark.skipif(
    __import__("shutil").which("cmake") is None,
    reason="cmake required to build lidb_embed",
)
def test_native_embed_probe():
    assert probe_engine_ready()


def test_execute_compiled_read_via_embed():
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
    assert "_stub" not in result.rows[0]


def test_execute_parameterized_where():
    plan = compile("read agent_runs where status = $status limit 5")
    pid = register_plan(
        "agent_runs.by_status",
        plan_id=plan.plan_id,
        ir=plan.ir,
        sql=plan.sql,
        param_schema=plan.param_schema,
    )
    result = execute(pid, {"status": "running"})
    assert result.rows
    assert all(row.get("status") == "running" for row in result.rows)


def test_exec_json_cli_roundtrip():
    embed = _embed_binary() or _build_embed()
    if embed is None:
        pytest.skip("cmake/lidb_embed unavailable")
    reset_session_for_tests()
    data = repo_root() / "build" / "pytest-data"
    data.mkdir(parents=True, exist_ok=True)
    subprocess.run([str(embed), "open", str(data)], check=True, capture_output=True, text=True)
    subprocess.run([str(embed), "migrate", str(data)], check=True, capture_output=True, text=True)
    proc = subprocess.run(
        [str(embed), "exec-json", str(data), "SELECT 1 AS ok"],
        input="[]",
        capture_output=True,
        text=True,
        check=True,
    )
    payload = json.loads(proc.stdout)
    assert payload["rows"][0]["ok"] == "1"


def test_no_sqlite_import_in_embed_engine():
    import liorm.embed_engine as mod

    source = Path(mod.__file__).read_text()
    assert "import sqlite3" not in source
    assert "sqlite3" not in source


def test_no_active_embedded_sql_migrations():
    root = repo_root()
    assert list(root.glob("migrations/*_embedded.sql")) == []
    archived = root / "migrations" / "archive"
    assert (archived / "001_registry_embedded.sql").is_file()
    assert (archived / "002_control_plane_embedded.sql").is_file()


def test_execute_module_uses_native_embed_only():
    source = Path(repo_root() / "liorm" / "execute.py").read_text()
    assert "LIORM_EXECUTE_STUB" not in source
    assert "_stub" not in source
    assert "embed_engine.execute_sql" in source


@pytest.fixture(autouse=True)
def _clear_plans():
    clear_plans()
    yield
    clear_plans()
