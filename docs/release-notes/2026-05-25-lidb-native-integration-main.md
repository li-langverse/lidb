# Release notes: 2026-05-25 — lidb-native-integration-main

**Status:** Ready for review  
**Repo:** li-langverse/lidb  
**PR:** (integration merge)  
**PH / REQ:** PH-DB-2, PH-DB-3, PH-DB-3.1, PH-DB-N1, PH-DB-N2, WP-N4, WP-N5  
**Author:** agent

---

## Summary (one sentence)

Merges native Li integration work (N2 SQL, changefeed, audit harness, sqlite cutover) onto `main`'s N1 heap/WAL stack with PH-DB-3.1 CI that forbids `sqlite3`.

## Agent continuation (required)

1. Read: `docs/architecture-native-li.md`, `.github/workflows/ci.yml`, `scripts/check_no_sqlite.sh`
2. Run: `bash scripts/smoke.sh`, `bash scripts/check_no_sqlite.sh`, `bash scripts/run_audit_suite.sh`
3. Then: wire `lis` embed + realtime changefeed consumer (PH-DB-3); extend native catalog for UPDATE/RETURNING liq examples
4. Blocked on: none for merge; RLS engine harness needs `LIDB_RLS_HARNESS=1` when policies land in C++

## Changed (specific)

| Area | What | Evidence |
|------|------|----------|
| CI | PH-DB-3.1 `ci.yml` — no `sqlite3` apt; `check_no_sqlite.sh` + audit-suite job | `.github/workflows/ci.yml` |
| Engine | N2 `lidb_sql`, changefeed C API, `exec_select` param binding fix | `cmake --build build/smoke`, `scripts/smoke.sh` |
| liorm | `execute()` → `embed_engine`; audit harness WP-N5 | `bash tests/security/run_all.sh` pass=6 |
| Migrations | `*_embedded.sql` archived | `migrations/archive/` |
| Docs | ADR, changefeed, learned-from, token audit | `docs/release-notes/2026-05-25-*.md` |

## Not changed (scope fence)

- Postgres wire protocol / `lis` in-process embed wiring — **not** in this PR
- Full liq README spec examples (UPDATE/RETURNING) — native catalog subset only
- RLS policy enforcement in engine — stubs SKIP unless `LIDB_RLS_HARNESS=1`

## Breaking changes

**BREAKING:** `liorm/execute()` no longer returns stub rows; requires built `lidb_embed`. Hosts without cmake/native build fail closed.

## Security

WP-N5 audit suite + CVE harness green locally (`tests/security/run_all.sh` pass=6 skip=4).

## Performance

N/A — integration merge; bench harness env documented in README (WP-N4).

## Downstream

| Repo | Action |
|------|--------|
| li-cursor-agents | optional `LI_CONTROL_PLANE_STORE=lidb` e2e after deploy |
| benchmarks | use `BENCH_DB_*_RUN_HARNESS=1` for tier_db_* |

## CHANGELOG entry (paste into Unreleased)

```markdown
### Changed
- **PH-DB integration:** Merge N2 native SQL, changefeed API, WP-N5 audit harness, and PH-DB-3.1 sqlite cutover onto main N1 heap/WAL stack ([#PR](URL)).
```
