# Changelog

## [Unreleased]

### Changed
- **PH-DB integration:** Merge N2 native SQL, changefeed, WP-N5 audit harness, and PH-DB-3.1 sqlite cutover onto main N1 heap/WAL ([2026-05-25-lidb-native-integration-main.md](docs/release-notes/2026-05-25-lidb-native-integration-main.md)).
- **PH-DB-N1**: Native heap pages + WAL read/append; `scripts/smoke.sh` and `liorm/embed_engine.py` use `lidb_embed` only (sqlite3 smoke removed).

- **PH-DB-2 token audit:** `docs/liq-token-efficiency-audit.md` — measured liq vs SQL vs ORM/BaaS (benchmarks `tier_db_token_efficiency`) — [2026-05-25-liq-token-efficiency-audit.md](docs/release-notes/2026-05-25-liq-token-efficiency-audit.md).

- **WP-N5:** Security + auditability harness — `liorm/audit.py`, `tests/audit/`, expanded `tests/security/`, `scripts/run_audit_suite.sh`, `docs/auditability.md`, CI `audit-suite` job.
- **PH-DB-3.1 / native Li ADR:** `docs/architecture-native-li.md` — C++ storage + Li planner/protocol, sqlite removal gate, realtime RT-1…RT-6 ([2026-05-25-architecture-native-li.md](docs/release-notes/2026-05-25-architecture-native-li.md)).
- **PH-DB-0:** `docs/learned-from.md` — vertical survey (OLTP, analytics, realtime, graph, vector, ORM security) with Keep/Reject/Adapt; SQLite not a production backend.
- **WP-N2:** Native Li SQL (`sql/parser/`, `sql/li/README.md`) — `lidb_embed exec-json`; no Python `sqlite3` in `liorm/embed_engine.py`.
- **PH-DB-3 gap:** ~~`liorm/embed_engine.py` wires `execute()` to `lidb_embed` SQLite~~ superseded by WP-N2 native embed.
- **PH-DB-3 changefeed:** native WAL `subscribe` + C poll/Unix API (`engine/changefeed.*`, `docs/changefeed.md`).
- **PH-DB-3.1:** sqlite cutover — archive `migrations/*_embedded.sql`, `scripts/check_no_sqlite.sh`, CI native-only ([2026-05-25-ph-db-3-1-sqlite-cutover.md](docs/release-notes/2026-05-25-ph-db-3-1-sqlite-cutover.md)).

### Added

- **PH-DB-1**: Engine skeleton (`engine/`), `lidb_embed` CLI, smoke INSERT/SELECT, `001_registry_embedded.sql`, research mirror.
- **PH-DB-2**: `liq/parser.py` — read/insert/update/delete; rejects `${}` and `;`.
- **PH-DB-2**: `liq/compiler.py` — `compile()` → `CompileResult(plan_id, ir, sql, param_schema)`.
- **PH-DB-2**: `liorm/catalog.py` — `CATALOG_ALLOWLIST` (registry + control-plane tables).
- **PH-DB-2**: `liorm/execute.py` — `register_plan`, `execute` with param validation (no verbatim values in SQL).
- **PH-DB-2**: `liorm/capabilities.py` — `RawSqlCapability`; `assert_capability` denies agent/MCP profiles.
- **PH-DB-2**: `scripts/security_probe.py`, `scripts/run_tests.sh` (venv pytest + CVE harness).
- **PH-DB-2**: `tests/test_*.py` (parser, compiler, execute, capabilities).
- **PH-DB-2**: `tests/security/run_all.sh` sets `LIDB_ENGINE_READY=1` when stubs present; 4 CVE scripts PASS.
- **PH-DB-5**: `migrations/002_rls_registry.sql` — multi-tenant RLS, `registry_auth` JWT helpers (Supabase-compatible GUCs), `publisher_members`.
- **PH-DB-5**: `docs/auth-rls.md` — policy matrix, lis `set_jwt_claims`, Supabase/PostgREST notes.
- **PH-DB-5**: `tests/security/rls-*.test.sh` stubs (tenant isolation, JWT GUC, service_role bypass).
- **PH-DB-1**: Greenfield scaffold — migrations, footprint/SQL subset docs, storage smoke, toolchain manifest.
- **PH-DB-2**: `liorm/` and `liq/` API skeletons and README sketches (prior PR).
