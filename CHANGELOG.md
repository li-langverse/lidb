# Changelog

## [Unreleased]

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
- **PH-DB-1**: Greenfield scaffold — migrations, footprint/SQL subset docs, storage smoke, toolchain manifest.
- **PH-DB-2**: `liorm/` and `liq/` API skeletons and README sketches (prior PR).
