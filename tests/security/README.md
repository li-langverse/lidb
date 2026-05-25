# lidb security regression harness (PH-DB-2)

CVE-oriented stubs for **liorm** and **liq**. All cases **skip** until the lidb engine and liorm implementation exist; CI should still run the harness and report `SKIP` (exit 0).

## Coverage goal

When liorm is implemented, maintain **≥80% line coverage** on:

- `Ident` / catalog resolution
- plan registration and `execute` parameter binding
- liq compile lowering
- `RawSqlCapability` gates

## Cases

| Script | CWE / theme |
|--------|-------------|
| `cve-cwe-89-sql-injection-via-param-concat.sh` | Classic value injection via string concat |
| `cve-cwe-89-second-order-sql-injection-stored-value.sh` | Stored value reparsed as SQL |
| `cve-cwe-89-identifier-injection-dynamic-table.sh` | Dynamic table/column names |
| `cve-raw-sql-capability-audit-escalation.sh` | Agent profile must not gain raw SQL |

## Run

```bash
./tests/security/run_all.sh
```

## Integration

- **lidb** CI: run on every PR touching `liorm/`, `liq/`, or `tests/security/`.
- **lic** optional mirror: `li-tests/security/db-orm/` may symlink or invoke this directory once lidb is vendored.

## PH-DB-5 (RLS)

RLS stubs: `rls-*.test.sh` — skipped until `LIDB_ENGINE_READY=1`.
