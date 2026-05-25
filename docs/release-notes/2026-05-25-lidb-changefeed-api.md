# Release notes: 2026-05-25 — lidb-changefeed-api

**Status:** Ready for review  
**Repo:** li-langverse/lidb  
**PR:** feat/lidb-changefeed-api  
**PH / REQ:** PH-DB-3  
**Author:** agent

---

## Summary (one sentence)

Native WAL changefeed: `subscribe(table, callback)` on heap insert events, C poll/Unix API for lis realtime, smoke tests — no sqlite triggers.

## Agent continuation (required)

1. Read: `docs/changefeed.md`, `engine/include/lidb/changefeed_c.h`, `engine/native_exec.cpp`
2. Run: `scripts/changefeed_smoke.sh`
3. Then: wire `lis` to `lidb_changefeed_poll` or `serve_unix`; route native INSERT plans through `NativeExecutor`
4. Blocked on: **none** for merge; lis bundle repo for consumer wiring

## Changed (specific)

| Area | What | Evidence |
|------|------|----------|
| Changefeed | `Changefeed::subscribe`, poll queue, Unix fan-out | `engine/changefeed.cpp` |
| Native exec | `NativeExecutor::insert` → `kHeapInsert` WAL | `engine/native_exec.cpp` |
| Embedded | `wal_writer`, `changefeed_hub`, `native_executor` | `engine/embedded.cpp` |
| C API | `lidb_changefeed_open/poll/serve_unix/native_insert` | `engine/changefeed_c.cpp` |
| Docs | lis realtime integration | `docs/changefeed.md` |
| Tests | `lidb_changefeed_smoke`, `scripts/changefeed_smoke.sh` | local run |

## Not changed (scope fence)

- sqlite `exec_sql` / migrate path — **does not** emit changefeed events
- WAL replay, heap page materialization, TCP wire — **not** in this PR
- `liorm/embed_engine.py` — unchanged

## Breaking changes

None.

## Security

N/A — optional local Unix socket; lis must restrict socket path permissions.

## Performance

N/A — in-memory poll queue only.

## Downstream

| Repo | Action |
|------|--------|
| lis | Changefeed consumer per `docs/changefeed.md` |

## CHANGELOG entry (paste into Unreleased)

```markdown
### Added
- Native WAL changefeed API and C bindings for lis realtime (`engine/changefeed.*`, `docs/changefeed.md`).
```
