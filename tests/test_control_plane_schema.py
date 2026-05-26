"""Control-plane ORM contract — native embed tables (WP-J / DB-R0-4)."""

import json
from pathlib import Path

import pytest

from liorm.embed_engine import execute_sql, probe_engine_ready, repo_root, reset_session_for_tests


@pytest.fixture(autouse=True)
def _fresh_embed_session():
    reset_session_for_tests()
    yield
    reset_session_for_tests()


def test_control_plane_state_table_in_migration_sql():
    sql = (repo_root() / "migrations" / "003_control_plane.sql").read_text()
    assert "control_plane_state" in sql
    assert "003_control_plane" in sql


@pytest.mark.skipif(not __import__("shutil").which("cmake"), reason="cmake required")
def test_control_plane_state_upsert_via_embed():
    assert probe_engine_ready()
    execute_sql("DELETE FROM control_plane_state WHERE id = ?", [1])
    payload = json.dumps({"version": 1, "tick": 42})
    execute_sql(
        "INSERT INTO control_plane_state (id, payload, updated_at) VALUES (?, ?, ?)",
        [1, payload, "2026-05-26T00:00:00.000Z"],
    )
    rows = execute_sql("SELECT id, payload FROM control_plane_state WHERE id = ? LIMIT 1", [1])
    assert len(rows) == 1
    assert rows[0]["id"] == "1"
    assert json.loads(rows[0]["payload"])["tick"] == 42


def test_agent_runs_catalog_includes_supabase_parity_columns():
    from liorm.catalog import CATALOG_ALLOWLIST

    cols = CATALOG_ALLOWLIST["public.agent_runs"]
    assert cols is not None
    for name in ("backend", "finished_at", "output_md", "completion", "meta"):
        assert name in cols
