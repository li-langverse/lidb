# liq — Li query language

**Phase:** PH-DB-2  
**Goal:** Smaller, safer surface than raw SQL for agents and programmatic callers. Parameterized by construction; identifiers resolved via catalog.

Full spec: [docs/liq-spec.md](../docs/liq-spec.md).

## Example programs (AST-oriented)

Surface syntax is intentionally terse for LLM token budgets.

### Read with limit

```liq
read agent_runs limit 20
```

**AST (conceptual)**

```json
{
  "op": "read",
  "from": { "ident": "public.agent_runs" },
  "limit": { "const": 20 }
}
```

### Filtered read

```liq
read agent_runs
  where status = $status
  limit 20
```

- `$status` → bound parameter slot (string/enum per catalog), never concatenated into SQL.

### Project columns

```liq
read agent_runs { id, created_at, status }
  where publisher_id = $pub
  order created_at desc
  limit 50
```

### Insert (registry control-plane sketch)

```liq
insert package_versions {
  package_id: $pkg,
  version: $ver,
  tarball_sha256: $sha
}
```

### Update with returning

```liq
update publishers
  set display_name = $name
  where id = $id
  returning id, display_name
```

## Compilation path

```text
liq source → Lang (parse) → LiqIr → SqlIr → parameterized SQL + metadata
```

liorm registers the resulting plan:

```li
let plan = liq::compile("read agent_runs limit 20")?;
let id = liorm::register_plan("agent_runs.recent", plan.ir)?;
let rows = liorm::execute(id, Map::new())?;
```

## Token efficiency vs SQL

| Intent | SQL (approx tokens) | liq |
|--------|---------------------|-----|
| Recent runs | `SELECT id, created_at, status FROM public.agent_runs ORDER BY created_at DESC LIMIT 20` | `read agent_runs { id, created_at, status } order created_at desc limit 20` |
| Param filter | `... WHERE status = $1` (+ driver binding boilerplate) | `where status = $status` |

Keywords are reduced; schema defaults to `search_path` / profile (`registry-min` → `public`).

## Security properties

1. **No raw identifiers** in source — names tokenize to catalog lookups.
2. **Parameters** only via `$name` or typed literals.
3. **No string literals** used as dynamic table/column names.
4. Second-order data (values read from DB) must pass through `execute` params, not be reparsed as liq.

Regression stubs: [tests/security/](../tests/security/README.md).
