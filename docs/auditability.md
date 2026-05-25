# lidb auditability (WP-N5)

What **agents** and **humans** can verify before trusting lidb for control-plane or registry data.

## Benchmark tiers

| Tier | Harness path | What it proves |
|------|----------------|----------------|
| **tier_db_security** | `tests/security/` | CVE regressions (CWE-89), RLS stubs, parallel registry races, optional valgrind smoke |
| **tier_db_audit** | `tests/audit/` + `audit-log-append-only` | Append-only audit chain, query log redaction, capability denial events |

Run the combined gate:

```bash
./scripts/run_audit_suite.sh
```

CI: `.github/workflows/ci.yml` job `audit-suite`.

## Humans can verify

1. **Parameterized SQL only** — `scripts/security_probe.py` + `tests/security/cve-*.sh`.
2. **Raw SQL gated** — `RawSqlCapability` denied for `agent` / `mcp`; denials in `liorm/audit.py`.
3. **Audit chain** — `AppendOnlyAuditLog.verify_chain()` detects tampering.
4. **Export-safe logs** — `redact_query_log()` strips passwords, API keys, Bearer tokens, JWT-shaped strings.
5. **Concurrency** — `parallel-race-plan-registry` stresses `register_plan` / `execute` under threads.
6. **Native memory (optional)** — `memory-leak-smoke.test.sh` uses valgrind when available; otherwise **SKIP**.

## Agents should run

1. Read: this file, `tests/security/README.md`, `docs/auth-rls.md`.
2. Run: `LIDB_ENGINE_READY=1 ./scripts/run_audit_suite.sh`
3. Then: persist audit rows in the engine (PH-DB-6+); harness log is in-memory today.
4. Blocked on: `LI_CONTROL_PLANE_STORE=lidb` in **li-cursor-agents** until engine + backfill land.

## Not in scope

- Live PostgreSQL RLS (`LIDB_RLS_HARNESS=1` when wired)
- `tier_db_registry` / vector / graph OLTP benches — **benchmarks** repo
