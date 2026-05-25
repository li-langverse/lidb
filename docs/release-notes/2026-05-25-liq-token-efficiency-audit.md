# Release notes: 2026-05-25 — liq-token-efficiency-audit

**Status:** Ready for review  
**Repo:** li-langverse/lidb  
**PR:** feat/liq-token-audit  
**PH / REQ:** PH-DB-2

---

## Summary

Publishes measured **liq vs SQL vs ORM/BaaS** token audit (18 scenarios) with grammar recommendations and compiler parity notes.

## Agent continuation

1. **Read:** `docs/liq-token-efficiency-audit.md`, `docs/liq-spec.md`, `liq/README.md`
2. **Run:** `cd ../benchmarks && ./scripts/run-db-token-efficiency-bench.sh`
3. **Then:** Implement P0 alias folding / join sugar per audit §5; refresh scenarios JSON
4. **Blocked on:** none for doc merge

## Changed

| Area | What | Evidence |
|------|------|----------|
| Audit doc | `docs/liq-token-efficiency-audit.md` | Matrix from benchmarks manifest 2026-05-25 |
| Cross-links | Points to `tier-db-token-efficiency` tier | URLs in doc header |

## Not changed

- `liq/parser.py` / `compiler.py` behavior — **not** modified in this PR
- Security harness — unchanged

## Breaking changes

None.

## Security

N/A — documentation only.

## Performance

N/A — documents token efficiency, not bench latency. Authoring: liq **−35.6%** vs SQL corpus total.

## Downstream

| Repo | Action |
|------|--------|
| benchmarks | tier manifest + ecosystem doc (sibling PR) |

## CHANGELOG entry

- **liq token audit:** `docs/liq-token-efficiency-audit.md` — [2026-05-25-liq-token-efficiency-audit.md](2026-05-25-liq-token-efficiency-audit.md).
