# liorm — secure Li ORM

**Phase:** PH-DB-2  
**Goal:** Parameterized, catalog-bound data access with no string-built SQL for values or identifiers unless explicitly allowlisted.

## Coverage gate

When the Rust/Li implementation lands, **liorm** must maintain **≥80% line coverage** on security-critical modules:

- `Ident` resolution and catalog binding
- plan compilation and parameter binding
- raw-SQL capability gates
- second-order value re-binding

Track in CI via `tests/security/` plus unit tests under `liorm/tests/` (future).

## Core API (sketch)

```li
// Prepared plan execution — params are typed values, never interpolated into SQL text.
fn execute(plan_id: PlanId, params: Map<String, Value>) -> Result<Rows, OrmError>

// Catalog-bound identifier — rejects unknown schema/table/column at compile or prepare time.
fn Ident::from_catalog(schema: &str, object: &str, column: Option<&str>) -> Result<Ident, IdentError>

// Optional: register a named plan from liq IR (compiled offline or at startup).
fn register_plan(name: &str, ir: LiqIr) -> Result<PlanId, OrmError>
```

### `execute(plan_id, params)`

| Input | Semantics |
|-------|-----------|
| `plan_id` | Opaque handle to a precompiled statement (LIQ or SQL source frozen at register time) |
| `params` | **Only** value slots; keys must match plan metadata; extra keys → error |

**Invariants**

1. No user-controlled string becomes SQL text except via `Ident::from_catalog` or an explicit `RawSqlCapability` token (audited).
2. Plans are immutable after registration; parameter types are fixed.
3. Errors surface as `OrmError::{ParameterMismatch, UnknownPlan, CapabilityDenied, ...}` without leaking connection secrets.

### `Ident::from_catalog()`

Resolves `schema.object` or `schema.object.column` against the live **catalog snapshot** (information_schema-shaped). Unknown names fail at prepare time, not at execute time with a generic driver error.

```li
let runs = Ident::from_catalog("public", "agent_runs", None)?;
let col = Ident::from_catalog("public", "agent_runs", Some("id"))?;
// plan compiler embeds quoted, validated identifiers from Ident only
```

**Anti-patterns (must fail tests in `tests/security/`)**

- `Ident::from_string(user_input)` — not part of public API
- Dynamic `ORDER BY` from unchecked strings
- `execute` with params that embed SQL fragments

## Relationship to liq and SQL

| Surface | Use when |
|---------|----------|
| **liq** | Agents, MCP tools, token-budget queries |
| **liorm plans** | Application code, repeated registry/control-plane reads |
| **Raw SQL** | Migrations, admin, `EXPLAIN` — requires `RawSqlCapability` |

liq compiles to the same IR liorm uses; `execute` accepts plans registered from either liq or vetted SQL templates.

## WP5 handoff (lis bundle)

**lis** should link lidb + liorm in-process and expose:

- Environment: `LI_DATA_DIR`, `LI_PROFILE` (e.g. `registry-min`)
- No separate ORM connection pool for registry-min; use `liorm::execute` against the embedded engine handle passed from lidb init.

Contract for WP5: see [../docs/handoff-wp5-lis.md](../docs/handoff-wp5-lis.md).
