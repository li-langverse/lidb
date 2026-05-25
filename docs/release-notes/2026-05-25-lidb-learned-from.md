# Release notes: 2026-05-25 — lidb-learned-from

**Status:** Ready for review  
**Repo:** li-langverse/lidb  
**PR:** (feat/lidb-learned-from)  
**PH / REQ:** PH-DB-0  
**Author:** agent

---

## Summary (one sentence)

Adds an engineering-standards **Learned from** survey for six database verticals with Keep/Reject/Adapt verdicts per system, explicitly rejecting SQLite as a production backend.

## Agent continuation (required)

1. **Read:** `docs/learned-from.md`, `docs/pg-subset-v1.md`, roadmap `proposals/lidb-li-data-platform.md`
2. **Run:** `./scripts/run_tests.sh` (no code change — docs-only PR)
3. **Then:** link vertical implementation PRs to updated Keep/Reject rows + ADR when promoting pg-subset items
4. **Blocked on:** none for merge

## Changed (specific)

| Area | What | Evidence |
|------|------|----------|
| Design | Vertical survey: OLTP (Postgres, SQLite, WiredTiger), analytics (DuckDB), realtime (Supabase, Firebase, Ably), graph (Kùzu, Neo4j), vector (pgvector, Faiss), ORM (Prisma) | `docs/learned-from.md` |
| README | Quick link to learned-from | `README.md` |
| CHANGELOG | Unreleased bullet PH-DB-0 | `CHANGELOG.md` |

## Not changed (scope fence)

- `engine/` heap/WAL implementation — still PH-DB-1..2
- `liorm` / `liq` behavior — no API changes
- `tests/security/` cases — no new CVE scripts
- SQLite smoke harness — still interim only; not promoted to target backend
- `lis` bundle profiles — no new `profiles/*.toml`

## Breaking changes

None.

## Security

N/A — documentation only; reinforces **Reject** of raw SQL defaults and SQLite as production store.

## Performance

N/A — no bench or RSS measurement in this PR.

## Downstream

| Repo | Action |
|------|--------|
| lic / lis / li-cursor-agents | N/A — reference `docs/learned-from.md` when scoping PH-DB vertical work |

## CHANGELOG entry (paste into Unreleased)

```markdown
### Added
- **PH-DB-0:** `docs/learned-from.md` — ecosystem survey with Keep/Reject/Adapt per vertical ([#NNN](URL))
```
