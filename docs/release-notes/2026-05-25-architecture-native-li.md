# Release notes: 2026-05-25 — architecture-native-li

**Status:** Ready for review  
**Repo:** li-langverse/lidb  
**PH / REQ:** PH-DB-1, PH-DB-3.1, PH-DB-7

---

## Summary

Documents native Li layered architecture (C++ storage + Li planner/protocol), PH-DB-3.1 sqlite removal rationale, realtime WAL→`lis` requirements, and WP-N repo mapping.

## Agent continuation

1. **Read:** `docs/architecture-native-li.md`, `docs/pg-subset-v1.md`, `engine/include/lidb/changefeed.hpp`
2. **Run:** `bash scripts/smoke.sh` (deprecation banner until PH-DB-3.1)
3. **Then:** WP-N1 heap/WAL + WP-N2 executor until sqlite paths deleted
4. **Blocked on:** none for doc merge

## Changed

| Area | What | Evidence |
|------|------|----------|
| ADR | Native architecture + RT-1…RT-6 | `docs/architecture-native-li.md` |
| pg-subset | PH-DB-3.1 link | `docs/pg-subset-v1.md` |
| README | sqlite deprecation note | `README.md` |

## Not changed

- `liorm/embed_engine.py` sqlite path — removed in PH-DB-3.1 PR
- `lis` broker implementation — sibling repo

## Breaking changes

None (documentation).

## Security

References WP-N5 harness; no runtime change.

## Performance

References `tier_db_registry` 1.2× gate.

## Downstream

- **roadmap:** `proposals/lidb-native-li-matrices.md`
- **li-cursor-agents:** PH-DB-10 blocked on PH-DB-3.1 + engine
