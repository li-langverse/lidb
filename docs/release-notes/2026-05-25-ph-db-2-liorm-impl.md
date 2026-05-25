# Release notes: 2026-05-25 — ph-db-2-liorm-impl

**Status:** Ready for review  
**Repo:** li-langverse/lidb  
**PR:** feat/ph-db-2-liorm-impl  
**PH / REQ:** PH-DB-2  
**Author:** agent

---

## Summary (one sentence)

Adds Python **liq** parser/compiler and **liorm** catalog-bound execute stubs with pytest unit tests and a CVE security harness wired to `scripts/security_probe.py`.

## Agent continuation (required)

1. **Read:** `docs/liq-spec.md`, `liq/README.md`, `liorm/README.md`, `tests/security/README.md`, `scripts/security_probe.py`
2. **Run:** `cd lidb && bash scripts/run_tests.sh`
3. **Then:** wire compiled plans to embedded engine (PH-DB-1 `engine/`); extend catalog from live `information_schema`; port hot paths to Li/Rust with ≥80% coverage on security modules
4. **Blocked on:** native lidb executor for real rows — **none** for stub merge

## Changed (specific)

| Area | What | Evidence |
|------|------|----------|
| liq | `parser.py` read/insert/update/delete; rejects `${}` and `;` | `tests/test_parser.py` |
| liq | `compiler.py` → `CompileResult(plan_id, ir, sql, param_schema)` | `tests/test_compiler.py` |
| liorm | `CATALOG_ALLOWLIST` registry + control-plane tables | `liorm/catalog.py` |
| liorm | `register_plan` / `execute` param validation | `tests/test_execute.py` |
| liorm | `RawSqlCapability` + `assert_capability` | `tests/test_capabilities.py`, CVE raw-sql probe |
| Security | `scripts/security_probe.py` + `tests/security/run_all.sh` | 4× PASS when `LIDB_ENGINE_READY=1` |
| CI local | `scripts/run_tests.sh` (venv pytest + security) | manual run |

## Not changed (scope fence)

- Native WAL/heap engine (`src/`, `engine/` production Postgres path) — **not** in this PR
- PH-DB-5 RLS JWT enforcement in embedded engine — **not** wired
- **lis** bundle in-process linking — **not** in this PR
- **li-cursor-agents** `runLiqQuery` mock — still `LI_LIDB_MOCK` until PH-DB-10

## Breaking changes

None — new Python packages only; no public C API change.

## Security

- CWE-89 class: parameterized SQL (`$1` slots); identifier allowlist at compile time
- CVE harness: `tests/security/cve-*.sh` → `security_probe.py`
- Agent/MCP denied `RawSqlCapability` (audit probe)

## Performance

N/A — stub execute returns synthetic rows; no bench until engine wired.

## Downstream

| Repo | Action |
|------|--------|
| li-cursor-agents | Optional: call lidb Python liq compile when `LI_LIDB_URL` set (PH-DB-10) |
| lis | WP5 handoff: consume `liorm::execute` after engine embed |

## CHANGELOG entry (paste into Unreleased)

```markdown
### Added
- **PH-DB-2**: Python `liq/` and `liorm/` stubs, pytest suite, CVE security harness (`scripts/security_probe.py`).
```
