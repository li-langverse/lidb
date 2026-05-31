"""Embedded engine bridge — lidb_embed subprocess only (PH-DB-3.1 native embed)."""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import threading
import tempfile
from pathlib import Path
from typing import Any

_REPO_ROOT = Path(__file__).resolve().parent.parent
_EXEC_LOCK = threading.Lock()
_SESSION_LOCK = threading.Lock()

_PARAM_RE = re.compile(r"\$(\d+)")


def repo_root() -> Path:
    return _REPO_ROOT


def _embed_binary() -> Path | None:
    override = os.environ.get("LIDB_EMBED")
    if override and Path(override).is_file():
        return Path(override)
    for candidate in (_REPO_ROOT / "build" / "smoke" / "lidb_embed", _REPO_ROOT / "build" / "lidb_embed"):
        if candidate.is_file():
            return candidate
    return None


def _build_embed() -> Path | None:
    if not shutil.which("cmake"):
        return None
    build_dir = _REPO_ROOT / "build" / "smoke"
    build_dir.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["cmake", "-S", str(_REPO_ROOT), "-B", str(build_dir), "-DCMAKE_BUILD_TYPE=Release"],
        capture_output=True,
    )
    subprocess.run(["cmake", "--build", str(build_dir), "--target", "lidb_embed", "-j"], capture_output=True)
    return _embed_binary()


def heap_catalog_path(data_dir: Path) -> Path:
    return data_dir / ".lidb" / "catalog.heap"


def _flatten_sql(pg_sql: str) -> str:
    sql = re.sub(r'"[^"]+"\."([^"]+)"\."([^"]+)"', r"\2", pg_sql)
    sql = re.sub(r'"[^"]+"\."([^"]+)"', r"\1", sql)
    return _PARAM_RE.sub("?", sql)


def _run_embed(args: list[str], *, stdin: str | None = None) -> subprocess.CompletedProcess[str]:
    embed = _embed_binary() or _build_embed()
    if embed is None:
        return subprocess.CompletedProcess(args, 127, "", "lidb_embed missing")
    return subprocess.run([str(embed), *args], input=stdin, capture_output=True, text=True)


class EmbeddedSession:
    def __init__(self, data_dir: Path) -> None:
        self.data_dir = data_dir

    def open_and_migrate(self) -> bool:
        if _run_embed(["open", str(self.data_dir)]).returncode:
            return False
        if _run_embed(["migrate", str(self.data_dir)]).returncode:
            return False
        catalog = heap_catalog_path(self.data_dir)
        return catalog.is_file() and catalog.stat().st_size > 0

    def exec_parameterized(self, sql: str, params: list[Any]) -> list[dict[str, Any]]:
        with _EXEC_LOCK:
            flat = _flatten_sql(sql)
            proc = _run_embed(
                ["exec-json", str(self.data_dir), flat],
                stdin=json.dumps([str(p) for p in params]),
            )
            if proc.returncode:
                raise RuntimeError(proc.stderr.strip() or "lidb_embed exec-json failed")
            return [dict(row) for row in json.loads(proc.stdout or "{}").get("rows", [])]

    def close(self) -> None:
        return


_SESSION: EmbeddedSession | None = None
_SESSION_DIR: tempfile.TemporaryDirectory[str] | None = None
_READY: bool | None = None


def _default_data_dir() -> Path:
    global _SESSION_DIR
    if os.environ.get("LIDB_DATA_DIR"):
        return Path(os.environ["LIDB_DATA_DIR"])
    if _SESSION_DIR is None:
        _SESSION_DIR = tempfile.TemporaryDirectory(prefix="lidb-liorm-")
    return Path(_SESSION_DIR.name)


def ensure_session() -> EmbeddedSession | None:
    global _SESSION, _READY
    if _READY is False:
        return None
    if _SESSION:
        return _SESSION
    with _SESSION_LOCK:
        if _SESSION:
            return _SESSION
        if _READY is False:
            return None
        session = EmbeddedSession(_default_data_dir())
        if not session.open_and_migrate():
            _READY = False
            _SESSION = None
            return None
        _SESSION = session
        _READY = True
        return session


def engine_ready() -> bool:
    return ensure_session() is not None


def probe_engine_ready() -> bool:
    session = ensure_session()
    if not session:
        return False
    try:
        rows = session.exec_parameterized("SELECT 1 AS ok", [])
        return bool(rows) and rows[0].get("ok") == "1"
    except Exception:
        return False


def execute_sql(sql: str, params: list[Any]) -> list[dict[str, Any]]:
    session = ensure_session()
    if not session:
        raise RuntimeError("embedded engine unavailable (native lidb_embed required; PH-DB-3.1)")
    return session.exec_parameterized(sql, params)


def seed_test_fixtures() -> None:
    session = ensure_session()
    if not session:
        return
    pub = "00000000-0000-4000-8000-000000000010"

    def count(table: str) -> int:
        rows = session.exec_parameterized(f"SELECT COUNT(*) AS n FROM {table}", [])
        return int(rows[0].get("n", 0)) if rows else 0

    if count("publishers") == 0:
        session.exec_parameterized(
            "INSERT INTO publishers (id, name, public_key, display_name) VALUES (?, ?, ?, ?)",
            [pub, "pytest-publisher", "00" * 32, "Pytest Publisher"],
        )
    if count("agent_runs") == 0:
        session.exec_parameterized(
            "INSERT INTO agent_runs (id, status, publisher_id) VALUES (?, ?, ?)",
            ["00000000-0000-4000-8000-000000000001", "running", pub],
        )
    pkg = "00000000-0000-4000-8000-000000000020"
    if count("packages") == 0:
        session.exec_parameterized(
            "INSERT INTO packages (id, name, description) VALUES (?, ?, ?)",
            [pkg, "li-pytest", "liorm test package"],
        )
    if count("package_versions") == 0:
        session.exec_parameterized(
            "INSERT INTO package_versions (id, package_id, version, tree_digest, coverage_pct, publisher_id) VALUES (?, ?, ?, ?, ?, ?)",
            ["00000000-0000-4000-8000-000000000030", pkg, "0.0.1-test", "sha256:pytest-tree", "100.0", pub],
        )


def reset_session_for_tests() -> None:
    global _SESSION, _SESSION_DIR, _READY
    if _SESSION:
        _SESSION.close()
    _SESSION = None
    _READY = None
    if _SESSION_DIR:
        _SESSION_DIR.cleanup()
        _SESSION_DIR = None
