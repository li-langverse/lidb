# WP-N5: lidb security + auditability harness

**Status:** Ready for review  
**Repo:** li-langverse/lidb  
**Branch:** `feat/ph-db-security-audit-harness`  
**PH / REQ:** PH-DB-2, WP-N5  

---

## Summary

Expands **tier_db_security** and **tier_db_audit** harnesses with append-only audit chain, query log redaction, concurrency probe, optional valgrind smoke, aggregated `run_audit_suite.sh`, and GHA CI.

## Agent continuation

1. **Read:** `docs/auditability.md`, `tests/security/README.md`, `tests/audit/`.
2. **Run:** `LIDB_ENGINE_READY=1 ./scripts/run_audit_suite.sh`
3. **Then:** wire persistent audit storage in engine; enable `LIDB_RLS_HARNESS=1` when RLS scripts are implemented.
4. **Blocked on:** benchmarks `tier_db_security` / `tier_db_audit` ingest manifests (sibling PR) — harness names align but tiers are not in catalog yet.

## Changed

| Area | What | Evidence |
|------|------|----------|
| Audit API | `liorm/audit.py` — `AppendOnlyAuditLog`, `redact_query_log`, `record_capability_denial` | `tests/audit/` pytest green |
| Security shell | `parallel-race-*.test.sh`, `memory-leak-*.test.sh`, `audit-log-*.test.sh` | `tests/security/run_all.sh` |
| Probes | `scripts/audit_probe.py` | PASS under `LIDB_ENGINE_READY=1` |
| Aggregate | `scripts/run_audit_suite.sh` | pytest + security harness exit 0 |
| Docs | `docs/auditability.md` | tier mapping |
| CI | `.github/workflows/ci.yml` | `audit-suite` + `native-smoke` jobs |
| Execute | `LIORM_EXECUTE_STUB=1` for registry probes | avoids cmake block in audit_probe |

## Not changed

- PostgreSQL RLS live tests (still SKIP without `LIDB_RLS_HARNESS=1`)
- **benchmarks** catalog rows for `tier_db_security` / `tier_db_audit`
- Control-plane lidb migration in **li-cursor-agents**

## Breaking changes

None.

## Security

- CWE-89 regression suite unchanged (4 CVE scripts PASS)
- New: append-only audit chain verification, capability denial trail, query log redaction

## Performance

N/A — harness only; no OLTP bench rows.

## Downstream

| Repo | Action |
|------|--------|
| benchmarks | Add `tier_db_security` / `tier_db_audit` skeleton + ingest when ready |
| li-cursor-agents | Reference `run_audit_suite.sh` in lidb e2e gate |

## CHANGELOG entry

- **WP-N5:** Security + auditability harness (see above).
