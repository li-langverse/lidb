# Release notes: 2026-05-25 — ph-db-n1-native-storage

**Status:** Ready for review  
**Repo:** li-langverse/lidb  
**PR:** feat/ph-db-native-storage-n1  
**PH / REQ:** PH-DB-N1  

---

## Summary

Replace sqlite3 smoke backend with native C++ heap pages, WAL append/read, and `lidb_embed` catalog executor; `liorm/embed_engine.py` uses `exec-json` only.

## Agent continuation

1. Read: `engine/native_catalog.cpp`, `engine/embedded.cpp`, `docs/pg-subset-v1.md`
2. Run: `bash scripts/smoke.sh` and `bash scripts/run_tests.sh` (no sqlite3 required)
3. Then: PH-DB-N2 SQL planner over `001_registry.sql`; WAL replay into heap pages
4. Blocked on: none

## Changed

| Area | What | Evidence |
|------|------|----------|
| engine/heap.cpp | 8 KiB LIDH page allocate/write | smoke WAL segment non-empty |
| engine/wal.cpp | WalReader::read_all | segment records after INSERT |
| engine/native_catalog.cpp | snapshot catalog + INSERT/SELECT subset | smoke INSERT/SELECT |
| engine/embedded.cpp | native migrate/exec; no sqlite3 shell | migration_intent.txt `smoke_backend=native` |
| scripts/smoke.sh | lidb_embed only | local smoke OK |
| liorm/embed_engine.py | `exec-json`; RuntimeError if sqlite fallback | pytest probe_engine_ready |

## Not changed

- Postgres wire protocol / lis server integration
- Full `001_registry.sql` DDL parse (still bootstrap subset)
- `liorm/execute.py` stub rows (no native execute wire yet)

## Breaking changes

**BREAKING:** `liorm/embed_engine.py` no longer uses `sqlite3`; hosts without `lidb_embed` build fail closed.

## Security

N/A — same parameterized `exec-json` path; no new trusted surface.

## Performance

N/A — smoke-only catalog; no bench row yet.

## Downstream

| Repo | Action |
|------|--------|
| lis / li-cursor-agents | consume native embed when pinning lidb |

## CHANGELOG entry

```markdown
### Changed
- PH-DB-N1: native heap + WAL smoke path; deprecate `migrations/*_embedded.sql` sqlite bootstrap ([#PR](URL))
```
