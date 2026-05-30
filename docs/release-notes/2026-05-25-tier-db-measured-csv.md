# tier_db CSV smoke harness (WP-DB)

**Status:** Ready for review  
**Repo:** li-langverse/lidb  
**PR:** (feat/tier-db-measured)  
**PH / REQ:** PH-DB-5, WP-N4  
**Author:** agent

---

## Summary (one sentence)

Adds `scripts/bench/tier_db_csv.sh` to emit per-tier `latest.csv` rows for all benchmarks `catalog.toml` lidb ids — measured smoke on `lidb_embed` plus honest `passed=false` blocked rows.

## Agent continuation (required)

1. Read: `scripts/bench/tier_db_csv_impl.py`, `scripts/bench/emit_csv.py`.
2. Run: `BENCH_TIER_DB_ROOT=../benchmarks/benchmarks ./scripts/bench/tier_db_csv.sh`.
3. Then: extend blocked tiers (vector, GPU, graph, audit, realtime) when native harness lands.
4. Blocked on: **none** for smoke CSV emitter.

## Changed (specific)

| Area | What | Evidence |
|------|------|----------|
| CSV emitter | `scripts/bench/emit_csv.py`, `tier_db_csv_impl.py` | Writes 9 tier `results/latest.csv` files |
| Runner | `scripts/bench/tier_db_csv.sh` | `BENCH_TIER_DB_ROOT` → benchmarks tree |

## Not changed (scope fence)

- Postgres/FAISS timing oracles — not in this PR.
- `harness_emit.py` JSON path — unchanged; CSV is dashboard ingest source.

## Breaking changes

None.

## Security

CVE probes via existing `security_probe.py` for `injection_blocked`.

## Performance

Smoke P95 on registry reads; RSS/ops_per_sec on embed — local darwin arm64.

## Downstream

| Repo | Action |
|------|--------|
| benchmarks | Merge ingest PR; run `run-db-measured-bench.sh` on CI |

## CHANGELOG entry

```markdown
### Added
- **tier_db CSV smoke bench** for benchmarks catalog ingest — [2026-05-25-tier-db-measured-csv.md](docs/release-notes/2026-05-25-tier-db-measured-csv.md).
```
