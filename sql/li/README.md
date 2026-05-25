# Li SQL layer (`sql/li`)

Native **Li** SQL for lidb embedded mode — not SQLite, not string concatenation in Python.

## Pipeline

```text
liq source → liq.compiler (Python) → parameterized SQL ($N)
          → sql/parser (C++) flatten + parse registry subset
          → NativeCatalog::exec → catalog.heap persistence
          → NativeExecutor WAL hook (WP-N1)
```

`liorm/embed_engine.py` calls `lidb_embed exec-json` only; parameters travel as a JSON array on stdin.

## Learned from (comments only — not shipped runtimes)

| System | Borrowed idea | Rejected for v1 |
|--------|---------------|-----------------|
| **PostgreSQL** | Statement-kind dispatch; flatten catalog-qualified names to heap tables | Full planner, indexes, MVCC |
| **SQLite VDBE** | Opcode-style SELECT/INSERT smoke path | `sqlite3` file format, B-tree codec |

## Scope (registry subset)

- `SELECT` with optional `WHERE col = ?`, `ORDER BY`, `LIMIT`
- `INSERT INTO … VALUES (?, …)`
- `SELECT COUNT(*)`, `SELECT 1 AS ok`

## WP-N1 hook

`NativeExecutor::insert` appends `kHeapInsert` WAL records when the embedded catalog reports `affected > 0`.
