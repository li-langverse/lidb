# Release notes: 2026-05-25 — ph-db-1-engine-skeleton

**Status:** Ready for review
**Repo:** li-langverse/lidb
**PH / REQ:** PH-DB-1, REQ-registry-v2

## Summary

PH-DB-1 engine skeleton: buffer pool, WAL append stub, embedded open/migrate API, smoke INSERT/SELECT via documented sqlite3 backend.

## Agent continuation

1. Read: , 
2. Run: 
3. Then: PH-DB-2 native SQL executor and WAL replay
4. Blocked on: PH-DB-2 for Postgres  apply

## Changed

| Area | What | Evidence |
|------|------|----------|
| engine/ | Buffer pool, WAL, embedded API |  |
| migrations/ | , embedded sqlite DDL | smoke migrate |
| scripts/smoke.sh | open + migrate + INSERT/SELECT | exit 0 |

## Not changed

- Postgres wire protocol, replication, full RLS enforcement
- lis  wiring (PH-DB-3)
- RSS CI gate (PH-DB-7)

## Breaking / Security / Performance

None / N/A / N/A
