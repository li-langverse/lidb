"""Embedded engine bridge — lidb_embed native only (sqlite3 removed)."""
from __future__ import annotations
import json, os, re, shutil, subprocess, tempfile
from pathlib import Path
from typing import Any
_REPO_ROOT = Path(__file__).resolve().parent.parent
_PARAM_RE = re.compile(r"\$(\d+)")
def _embed_binary():
    o = os.environ.get("LIDB_EMBED")
    if o and Path(o).is_file(): return Path(o)
    for c in (_REPO_ROOT/"build"/"smoke"/"lidb_embed", _REPO_ROOT/"build"/"lidb_embed"):
        if c.is_file(): return c
    return None
def _build_embed():
    if not shutil.which("cmake"): return None
    b = _REPO_ROOT/"build"/"smoke"; b.mkdir(parents=True, exist_ok=True)
    subprocess.run(["cmake","-S",str(_REPO_ROOT),"-B",str(b),"-DCMAKE_BUILD_TYPE=Release"], capture_output=True)
    subprocess.run(["cmake","--build",str(b),"--target","lidb_embed","-j"], capture_output=True)
    return _embed_binary()
def _native_sql(pg_sql):
    sql = re.sub(r'"[^"]+"\."([^"]+)"\."([^"]+)"', r"\2", pg_sql)
    sql = re.sub(r'"[^"]+"\."([^"]+)"', r"\1", sql)
    return _PARAM_RE.sub("?", sql)
class EmbeddedSession:
    def __init__(self, data_dir): self.data_dir = data_dir
    def open_and_migrate(self):
        e = _embed_binary() or _build_embed()
        if not e: return False
        if subprocess.run([str(e),"open",str(self.data_dir)], capture_output=True).returncode: return False
        if subprocess.run([str(e),"migrate",str(self.data_dir)], capture_output=True).returncode: return False
        p = self.data_dir/".lidb"/"catalog.heap"
        return p.is_file() and p.stat().st_size > 0
    def exec_parameterized(self, sql, params):
        e = _embed_binary() or _build_embed()
        if not e: raise RuntimeError("embedded engine unavailable (native lidb_embed required; sqlite3 fallback removed)")
        proc = subprocess.run([str(e),"exec-json",str(self.data_dir),_native_sql(sql)], input=json.dumps([str(p) for p in params]), capture_output=True, text=True)
        if proc.returncode: raise RuntimeError(proc.stderr or "native exec failed")
        return [dict(r) for r in json.loads(proc.stdout or "{}").get("rows",[])]
    def close(self): pass
_SESSION=None; _SESSION_DIR=None; _READY=None
def ensure_session():
    global _SESSION,_READY,_SESSION_DIR
    if _READY is False: return None
    if _SESSION: return _SESSION
    if os.environ.get("LIDB_DATA_DIR"): data=Path(os.environ["LIDB_DATA_DIR"])
    else:
        if _SESSION_DIR is None: _SESSION_DIR=tempfile.TemporaryDirectory(prefix="lidb-liorm-")
        data=Path(_SESSION_DIR.name)
    s=EmbeddedSession(data)
    if not s.open_and_migrate(): _READY=False; _SESSION=None; return None
    _SESSION=s; _READY=True; return s
def engine_ready(): return ensure_session() is not None
def probe_engine_ready():
    s=ensure_session()
    if not s: return False
    try: return str(s.exec_parameterized("SELECT 1 AS ok",[])[0].get("ok"))=="1"
    except Exception: return False
def execute_sql(sql, params):
    s=ensure_session()
    if not s: raise RuntimeError("embedded engine unavailable (native lidb_embed required; sqlite3 fallback removed)")
    return s.exec_parameterized(sql, params)
def seed_test_fixtures():
    s=ensure_session()
    if not s: return
    pub="00000000-0000-4000-8000-000000000010"
    if int(s.exec_parameterized("SELECT COUNT(*) AS n FROM agent_runs",[])[0].get("n",0))==0:
        s.exec_parameterized("INSERT INTO agent_runs (id, status, publisher_id) VALUES (?,?,?)",["00000000-0000-4000-8000-000000000001","running",pub])
    if int(s.exec_parameterized("SELECT COUNT(*) AS n FROM publishers",[])[0].get("n",0))==0:
        s.exec_parameterized("INSERT INTO publishers (id, name, public_key, display_name) VALUES (?,?,?,?)",[pub,"pytest-publisher","\x00"*32,"Pytest Publisher"])
    pkg="00000000-0000-4000-8000-000000000020"
    if int(s.exec_parameterized("SELECT COUNT(*) AS n FROM packages",[])[0].get("n",0))==0:
        s.exec_parameterized("INSERT INTO packages (id, name, description) VALUES (?,?,?)",[pkg,"li-pytest","liorm test package"])
    if int(s.exec_parameterized("SELECT COUNT(*) AS n FROM package_versions",[])[0].get("n",0))==0:
        s.exec_parameterized("INSERT INTO package_versions (id, package_id, version, tree_digest, coverage_pct, publisher_id) VALUES (?,?,?,?,?,?)",["00000000-0000-4000-8000-000000000030",pkg,"0.0.1-test","sha256:pytest-tree",100.0,pub])
def reset_session_for_tests():
    global _SESSION,_SESSION_DIR,_READY
    if _SESSION: _SESSION.close()
    _SESSION=None; _READY=None
    if _SESSION_DIR: _SESSION_DIR.cleanup(); _SESSION_DIR=None
