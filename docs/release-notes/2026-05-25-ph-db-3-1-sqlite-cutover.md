# Release notes: 2026-05-25 — ph-db-3-1-sqlite-cutover

**Status:** Ready for review  
**Repo:** li-langverse/lidb  
**PR:** `feat/ph-db-3-1-sqlite-cutover`  
**PH / REQ:** PH-DB-3.1, WP-N2  
**Author:** agent

---

## Summary (one sentence)

Completes PH-DB-3.1 sqlite removal gate: CI asserts no sqlite3 binary, embedded SQL migrations archived, `liorm/embed_engine` native-only.

## Agent continuation (required)

1. **Read:** `scripts/check_no_sqlite.sh`, `.github/workflows/ci.yml`
2. **Run:** `bash scripts/check_no_sqlite.sh && bash scripts/smoke.sh && bash scripts/run_tests.sh`
3. **Then:** merge after N1 (#13) and N2 (#12) on integration branch (already on `feat/ph-db-2-liorm-liq`)
4. **Blocked on:** human `lidb` default branch rename to `main` — optional for this PR

## Changed (specific)

| Area | What | Evidence |
|------|------|----------|
| CI | No sqlite3 on PATH; `check_no_sqlite.sh` | `.github/workflows/ci.yml` |
| Migrations | `*_embedded.sql` → `migrations/archive/` | `migrations/archive/` |
| liorm | `embed_engine.py` lidb_embed only | `liorm/embed_engine.py` |

## Not changed (scope fence)

- WP-N5 audit harness (separate commit on stack; may merge via #9)
- Benchmarks ingest wiring (`BENCH_DB_*_RUN_HARNESS` in benchmarks repo)
- PG wire (WP-N6)

## Breaking changes

Embedded sqlite smoke path removed; consumers must build `lidb_embed`.

## Security

N/A — removal of sqlite smoke reduces trusted surface; CVE harness unchanged.

## Performance

N/A — native embed smoke only.

## Downstream

| Repo | Action |
|------|--------|
| lis / lip | Use native changefeed + embed; no sqlite3 fallback |

## CHANGELOG entry (paste into Unreleased)

- PH-DB-3.1: sqlite cutover — archive `*_embedded.sql`, CI `check_no_sqlite.sh`, native embed only ([2026-05-25-ph-db-3-1-sqlite-cutover.md](2026-05-25-ph-db-3-1-sqlite-cutover.md))
