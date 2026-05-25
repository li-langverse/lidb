"""Embedded engine bridge — lidb_embed CLI + sqlite3 parameterized exec."""

from __future__ import annotations

import os
import re
import shutil
import sqlite3
import subprocess
import tempfile
from pathlib import Path
from typing import Any

_REPO_ROOT = Path(__file__).resolve().parent.parent
_PARAM_RE = re.compile(r"\$(\d+)")


def repo_root() -> Path:
    return _REPO_ROOT


def _embed_binary() -> Path | None:
    override = os.environ.get("LIDB_EMBED")
    if override:
        p = Path(override)
        return p if p.is_file() else None
    for candidate in (
        _REPO_ROOT / "build" / "smoke" / "lidb_embed",
        _REPO_ROOT / "build" / "lidb_embed",
    ):
        if candidate.is_file():
            return candidate
    return None


def _build_embed() -> Path | None:
    if shutil.which("cmake") is None:
        return None
    build_dir = _REPO_ROOT / "build" / "smoke"
    build_dir.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["cmake", "-S", str(_REPO_ROOT), "-B", str(build_dir), "-DCMAKE_BUILD_TYPE=Release"],
        check=False,
        capture_output=True,
    )
    subprocess.run(
        ["cmake", "--build", str(build_dir), "--target", "lidb_embed", "-j"],
        check=False,
        capture_output=True,
    )
    return _embed_binary()


def catalog_path(data_dir: Path) -> Path:
    return data_dir / ".lidb" / "catalog.db"


def _sqlite_sql(pg_sql: str) -> str:
    """Postgres-style $N placeholders → sqlite ?; flatten catalog-qualified idents."""
    sql = re.sub(r'"[^"]+"\."([^"]+)"\."([^"]+)"', r"\2", pg_sql)
    sql = re.sub(r'"[^"]+"\."([^"]+)"', r"\1", sql)
    return _PARAM_RE.sub("?", sql)


def _run_embed(args: list[str]) -> bool:
    embed = _embed_binary() or _build_embed()
    if embed is None:
        return False
    proc = subprocess.run([str(embed), *args], capture_output=True, text=True)
    return proc.returncode == 0


class EmbeddedSession:
    """One embedded data directory (open + migrate via lidb_embed)."""

    def __init__(self, data_dir: Path) -> None:
        self.data_dir = data_dir
        self._conn: sqlite3.Connection | None = None

    def open_and_migrate(self) -> bool:
        if not shutil.which("sqlite3"):
            return False
        if not _run_embed(["open", str(self.data_dir)]):
            return False
        if not _run_embed(["migrate", str(self.data_dir)]):
            return False
        cat = catalog_path(self.data_dir)
        if not cat.is_file() or cat.stat().st_size == 0:
            return False
        self._conn = sqlite3.connect(str(cat))
        self._conn.row_factory = sqlite3.Row
        return True

    def exec_parameterized(self, sql: str, params: list[Any]) -> list[dict[str, Any]]:
        if self._conn is None:
            raise RuntimeError("embedded session not open")
        bound_sql = _sqlite_sql(sql)
        cur = self._conn.execute(bound_sql, params)
        if cur.description is None:
            self._conn.commit()
            return []
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]

    def close(self) -> None:
        if self._conn is not None:
            self._conn.close()
            self._conn = None


_SESSION: EmbeddedSession | None = None
_SESSION_DIR: tempfile.TemporaryDirectory[str] | None = None
_READY: bool | None = None


def _default_data_dir() -> Path:
    if env := os.environ.get("LIDB_DATA_DIR"):
        return Path(env)
    global _SESSION_DIR
    if _SESSION_DIR is None:
        _SESSION_DIR = tempfile.TemporaryDirectory(prefix="lidb-liorm-")
    return Path(_SESSION_DIR.name)


def ensure_session() -> EmbeddedSession | None:
    global _SESSION, _READY
    if _READY is False:
        return None
    if _SESSION is not None:
        return _SESSION
    data = _default_data_dir()
    sess = EmbeddedSession(data)
    if not sess.open_and_migrate():
        _READY = False
        _SESSION = None
        return None
    _SESSION = sess
    _READY = True
    return _SESSION


def engine_ready() -> bool:
    return ensure_session() is not None


def probe_engine_ready() -> bool:
    """Ping embedded backend (build embed + migrate + SELECT 1)."""
    sess = ensure_session()
    if sess is None:
        return False
    try:
        rows = sess.exec_parameterized("SELECT 1 AS ok", [])
        return bool(rows) and rows[0].get("ok") == 1
    except Exception:
        return False


def execute_sql(sql: str, params: list[Any]) -> list[dict[str, Any]]:
    sess = ensure_session()
    if sess is None:
        raise RuntimeError("embedded engine unavailable")
    return sess.exec_parameterized(sql, params)


def seed_test_fixtures() -> None:
    """Minimal rows so liorm pytest and doc examples can SELECT/UPDATE."""
    sess = ensure_session()
    if sess is None or sess._conn is None:
        return
    conn = sess._conn
    pub_id = "00000000-0000-4000-8000-000000000010"
    cur = conn.execute("SELECT COUNT(*) AS n FROM agent_runs")
    if cur.fetchone()[0] == 0:
        conn.execute(
            "INSERT INTO agent_runs (id, status, publisher_id) VALUES (?, ?, ?)",
            ("00000000-0000-4000-8000-000000000001", "running", pub_id),
        )
        conn.commit()
    cur = conn.execute("SELECT COUNT(*) FROM publishers")
    if cur.fetchone()[0] == 0:
        conn.execute(
            "INSERT INTO publishers (id, name, public_key, display_name) "
            "VALUES (?, ?, ?, ?)",
            (
                "00000000-0000-4000-8000-000000000010",
                "pytest-publisher",
                b"\x00" * 32,
                "Pytest Publisher",
            ),
        )
        conn.commit()
    pkg_id = "00000000-0000-4000-8000-000000000020"
    cur = conn.execute("SELECT COUNT(*) FROM packages")
    if cur.fetchone()[0] == 0:
        conn.execute(
            "INSERT INTO packages (id, name, description) VALUES (?, ?, ?)",
            (pkg_id, "li-pytest", "liorm test package"),
        )
        conn.commit()
    cur = conn.execute("SELECT COUNT(*) FROM package_versions")
    if cur.fetchone()[0] == 0:
        conn.execute(
            "INSERT INTO package_versions "
            "(id, package_id, version, tree_digest, coverage_pct, publisher_id) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (
                "00000000-0000-4000-8000-000000000030",
                pkg_id,
                "0.0.1-test",
                "sha256:pytest-tree",
                100.0,
                pub_id,
            ),
        )
        conn.commit()


def reset_session_for_tests() -> None:
    """Close session so the next call uses a fresh temp data dir."""
    global _SESSION, _SESSION_DIR, _READY
    if _SESSION is not None:
        _SESSION.close()
    _SESSION = None
    _READY = None
    if _SESSION_DIR is not None:
        _SESSION_DIR.cleanup()
        _SESSION_DIR = None
