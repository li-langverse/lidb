# Release notes: 2026-05-25 — ph-db-3-liorm-engine-wire

**PR:** feat/ph-db-3-liorm-engine-wire  
**Phase:** PH-DB-3 (gap #3)

## Summary

Wires Python **liorm** `execute()` to the PH-DB-1 embedded engine (`lidb_embed` + sqlite3 smoke catalog) with safe `$N` → `?` parameter binding.

## Agent continuation

1. **Read:** `liorm/embed_engine.py`, `liorm/execute.py`, `engine/embedded.cpp`, `tests/security/run_all.sh`
2. **Run:** `bash scripts/smoke.sh` and `bash scripts/run_tests.sh` (needs `cmake`, `sqlite3`)
3. **Next:** Replace sqlite smoke with native heap/WAL exec; expose parameterized API on `lidb_embed` CLI
4. **Blocked:** None for merge review

## Changed

| Area | What | Evidence |
|------|------|----------|
| liorm | `embed_engine.py` — open/migrate via CLI, exec via sqlite3 | `tests/test_embed_engine.py` |
| liorm | `execute.py` calls engine when `engine_ready()` | `tests/test_execute.py` |
| engine | `migrate()` applies `002_control_plane_embedded.sql` | `migrations/002_control_plane_embedded.sql` |
| security | `LIDB_ENGINE_READY=1` only after `probe_engine_ready()` | `tests/security/run_all.sh` |
| smoke | liorm read after registry INSERT/SELECT | `scripts/smoke.sh` |

## Not changed

- Postgres-native engine execution path (still sqlite3 smoke backend)
- `liq` parser/compiler semantics
- RLS / JWT enforcement (PH-DB-5)

## Breaking

N/A — additive wire-up behind existing plan registry API.

## Security

- Parameter values bound via sqlite3, not concatenated into SQL text
- CVE harness unchanged; probes still PASS when engine ready

## Performance

N/A — smoke-scale sqlite only.

## Downstream

| Consumer | Action |
|----------|--------|
| **lis** | Embed in-process once C++ API exports parameterized exec |
