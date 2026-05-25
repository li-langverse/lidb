# Release notes: 2026-05-25 — ph-db-native-sql-li

**Status:** Ready for review  
**Repo:** li-langverse/lidb  
**PR:** (open on `feat/ph-db-native-sql-li`)  
**PH / REQ:** WP-N2, PH-DB-2  
**Author:** agent

---

## Summary (one sentence)

Adds native Li SQL parsing (`sql/parser/`) and `lidb_embed exec-json` so liq→plan→SQL runs through the embedded heap catalog without Python `sqlite3`.

## Agent continuation (required)

1. **Read:** `sql/li/README.md`, `engine/native_catalog.cpp`, `liorm/embed_engine.py`
2. **Run:** `bash scripts/smoke.sh` and `bash scripts/run_tests.sh` (needs `cmake`, no `sqlite3`)
3. **Then:** Wire WP-N1 full WAL replay when engine API stabilizes
4. **Blocked on:** none for smoke subset

## Changed (specific)

| Area | What | Evidence |
|------|------|----------|
| sql/parser | `lexer.cpp`, `registry_parse.cpp` — SELECT/INSERT flatten + parse | `cmake --build build/smoke` |
| engine | `native_catalog.cpp`, `embedded` path — `catalog.heap`, no sqlite shell | `scripts/smoke.sh` |
| liorm | `embed_engine.py` — subprocess `exec-json` only | `tests/test_native_sql.py` |
| CLI | `lidb_embed exec-json` stdin JSON params | `tests/test_native_sql.py` |

## Not changed (scope fence)

- Postgres wire protocol / `lis` server
- Full `001_registry.sql` DDL interpreter
- RLS enforcement inside engine (PH-DB-5 / capabilities)

## Breaking changes

None — embedded default backend is `native`.

## Security

N/A — parameterized `exec-json`; existing CVE harness unchanged.

## Performance

N/A — in-memory heap smoke.

## Downstream

| Repo | Action |
|------|--------|
| li-cursor-agents | N/A |

## CHANGELOG entry (paste into Unreleased)

```markdown
### Added
- **WP-N2:** Native Li SQL layer (`sql/parser/`, `sql/li/README.md`) and `lidb_embed exec-json` (no Python sqlite3).
```
