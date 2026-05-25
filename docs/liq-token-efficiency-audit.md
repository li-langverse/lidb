# liq token efficiency audit (PH-DB-2)

**Status:** Measured corpus 2026-05-25  
**Benchmark tier:** [`benchmarks` tier_db_token_efficiency](https://github.com/li-langverse/benchmarks/blob/main/docs/ecosystem/tier-db-token-efficiency.md)  
**Manifest:** [`data/latest/tier-db-token-efficiency.json`](https://github.com/li-langverse/benchmarks/blob/main/data/latest/tier-db-token-efficiency.json)  
**Spec / examples:** [`docs/liq-spec.md`](./liq-spec.md), [`liq/README.md`](../liq/README.md)

## Executive summary

**liq** is designed as the **agent-authored** query surface for lidb: fewer keywords than SQL for registry and control-plane shapes, with catalog-bound identifiers and `$param` value slots ([`liq-spec.md` §3](./liq-spec.md)).

This audit compares **what an LLM puts in context** across 18 tasks — not executor latency.

| Metric | SQL (baseline) | liq | Notes |
|--------|----------------|-----|-------|
| **Total tokens (18 scenarios)** | 629 | 405 | **−35.6%** (`tiktoken_cl100k_base`) |
| **Compression ratio** | 1.0 | 1.55× vs SQL | `sql_tokens / liq_tokens` |
| **Median per scenario** | 32 | 24 | PostgREST URL median **23** (smallest wire, weakest safety typing) |
| **Compiled SQL from liq** | 29 (hand) | 68 (compiler today) | Agent still writes liq; planner should fold qualifiers (§2.4) |

**Measured vs estimated:** All matrix numbers are **measured** from frozen strings in `benchmarks/tier_db_token_efficiency/scenarios.json`. Illustrative ranges in [`liq-spec.md` §3](./liq-spec.md) (−54% to −57%) align with but do not replace this corpus.

**Honest limitations:**

- **JOIN** (`join_publisher_package`): v0 liq has no join — matrix liq cell is single-table; **`liq_2step`** ≈34 tokens for semantic parity.
- **GROUP BY** (`count_agent_runs_by_status`): liq cell is a **limit scan stub**, not equivalent to SQL aggregate — grammar extension required.
- **Publish + attestation:** SQL uses CTE; liq/Supabase use **multi-step** in production (corpus notes two round-trips).
- **ORM snippets** exclude `import` / client setup (would add ~15–40 tokens per file).

---

## 1. Methodology

### 1.1 Surfaces

| Surface | What we count | Source |
|---------|---------------|--------|
| **sql** | Hand-written Postgres SQL, parameterized | `migrations/001_registry.sql`, control-plane DDL |
| **liq** | Surface programs per spec/README | `liq/README.md` examples + registry shapes |
| **prisma** | Representative `findMany` / `create` / `groupBy` one-liners | Idiomatic 5.x client style |
| **drizzle** | `db.select` / `insert` / `transaction` chains | Idiomatic drizzle-orm style |
| **supabase_js** | `supabase.from(...).select(...)` | [@supabase/supabase-js](https://github.com/supabase/supabase-js) patterns |
| **postgrest** | REST path + query string (no host/auth) | PostgREST v12 filter syntax |
| **graphql** | Hasura-style minimal query/mutation | Variables inline where needed |

### 1.2 Token counting

1. Normalize to **single line** (no pretty-print noise).
2. Encode with **`tiktoken.get_encoding("cl100k_base")`** (GPT-4/3.5 family).
3. Fallback: `round(word_count × 1.3)` if tiktoken unavailable (`compute_tokens.py`).
4. Record **characters** and **tokens** per surface in manifest JSON.

### 1.3 Baseline and deltas

- **Baseline:** `sql` tokens per scenario.
- **Δ% vs SQL:** `100 × (surface − sql) / sql`.
- **Compression ratio:** `sql_tokens / surface_tokens` (>1 means surface is smaller).

### 1.4 Reproducibility

```bash
cd ../benchmarks
./scripts/run-db-token-efficiency-bench.sh
```

Updates `data/latest/tier-db-token-efficiency.json` and uses `benchmarks/tier_db_token_efficiency/compute_tokens.py`.

### 1.5 Compiler cross-check (measured)

```text
liq: read agent_runs { run_id, agent_id, status, started_at, briefing_hash } order started_at desc limit 20
hand SQL tokens: 29
liq source tokens: 25
compiled SQL tokens: 68  (fully qualified "public"."agent_runs" columns)
```

**Implication:** Token wins are on **authoring**; SqlIr lowering should emit alias-short SQL for EXPLAIN/bench parity ([`liq-spec.md` §8](./liq-spec.md)).

---

## 2. Master matrix (measured)

| Scenario | SQL | liq | Δ% vs SQL | Prisma | Supabase JS | PostgREST | GraphQL |
|----------|-----|-----|-----------|--------|-------------|-----------|---------|
| `list_packages_limit_20` | 20 | 18 | -10.0% | 42 | 31 | 21 | 24 |
| `get_package_version_by_name_version` | 53 | 31 | -41.5% | 52 | 55 | 42 | 44 |
| `insert_publish_with_attestation` | 78 | 39 | -50.0% | 55 | 66 | 26 | 41 |
| `join_publisher_package` | 45 | 18 | -60.0% | 35 | 35 | 27 | 29 |
| `filter_tenant_publisher_rls` | 35 | 23 | -34.3% | 46 | 36 | 23 | 24 |
| `agent_runs_order_started_at` | 29 | 25 | -13.8% | 51 | 50 | 35 | 33 |
| `vector_search_stub` | 24 | 18 | -25.0% | 31 | 23 | 12 | 31 |
| `yank_package` | 52 | 24 | -53.8% | 34 | 22 | 15 | 39 |
| `schema_introspection_mcp` | 35 | 11 | -68.6% | 27 | 21 | 23 | 22 |
| `bulk_read_pagination_cursor` | 39 | 34 | -12.8% | 44 | 43 | 36 | 73 |
| `list_package_versions_for_package` | 28 | 27 | -3.6% | 29 | 42 | 33 | 39 |
| `update_publisher_display_name` | 21 | 18 | -14.3% | 30 | 31 | 14 | 37 |
| `blocklist_lookup_by_name` | 23 | 23 | +0.0% | 20 | 32 | 27 | 30 |
| `count_agent_runs_by_status` | 20 | 9 | -55.0% | 38 | 17 | 9 | 18 |
| `insert_agent_run_stub` | 41 | 29 | -29.3% | 41 | 31 | 8 | 23 |
| `read_attestations_for_version` | 26 | 25 | -3.8% | 25 | 35 | 32 | 38 |
| `delete_yanked_flag_update` | 28 | 27 | -3.6% | 24 | 38 | 21 | 33 |
| `describe_table_agent_runs_mcp` | 32 | 6 | -81.2% | 16 | 16 | 15 | 21 |

---

## 3. Safety surface (per scenario class)

| Class | SQL | liq | ORM / Supabase | GraphQL |
|-------|-----|-----|----------------|---------|
| **Read/list** | Validator + limit required for agents | Allowlisted tables; parse rejects `;` and `${}` | RLS on server; client filter typos fail at runtime | Depth/complexity limits needed |
| **Filter/param** | `$1` binding | `$name` → prepared schema | `.eq()` chained | typed variables |
| **Mutate** | Capability token (`RawSqlCapability`) | `insert`/`update`/`delete` + catalog | Service role keys risky in agents | mutation permissions |
| **Introspection** | `information_schema` wide rows | `schema_snapshot` / `describe_table_liq` MCP verbs | `limit(0)` hack | `__type` introspection |
| **RLS** | `current_setting('request.jwt.claim…')` | Session injects predicate at compile (PH-DB-5) | JWT in Supabase client | Hasura permissions layer |

**Second-order:** Values read from DB must not be reparsed as liq source ([`liq/README.md`](../liq/README.md) §Security properties).

---

## 4. Per-vertical appendix

### 4.1 Registry OLTP (lip / `001_registry.sql`)

- **Largest liq wins:** publish insert (−50%), yank (−54%), name+version resolve (−41.5%).
- **Parity risk:** `get_package_version_by_name_version` liq uses `package_id = $pkg` — agents need a **name→id** resolver plan or `read packages where name = $n` prelude (+~12 tokens).
- **PostgREST** wins on short mutations (yank **15** tokens) but omits error handling and auth headers.

### 4.2 Control plane (`agent_runs`, MCP)

- **agent_runs_order_started_at:** liq **25** vs SQL **29** — matches [`liq/README.md`](../liq/README.md) `read agent_runs limit 20` pattern extended with projection/order.
- **describe_table_agent_runs_mcp:** `describe_table_liq agent_runs` → **6** tokens vs `information_schema` **32** — prefer MCP verb in agent prompts over raw SQL introspection.

### 4.3 RLS / tenant (`002_rls_registry.sql`)

- SQL embeds `current_setting('request.jwt.claim.publisher_id')` — verbose but explicit.
- liq should compile RLS from session context (not repeated in source) → displayed `where id = $publisher_id` is **authoring** shorthand; **Not changed:** policies in [`docs/auth-rls.md`](./auth-rls.md).

### 4.4 Vector (PH-DB-7 stub)

- Proposed: `read attestations { … } similar $vec limit 10` (**18** tokens) vs SQL `ORDER BY embedding <=> $1::vector` (**24**).
- **Not implemented** in `liq/parser.py` today — stub for benchmark spectrum only.

### 4.5 GraphQL / Hasura

- Competitive on simple reads; **bulk_read_pagination_cursor** GraphQL **73** tokens (nested `_or`) — worst in corpus.
- Li strategy: **liq-first** for agents; GraphQL for human dashboards only ([`roadmap` matrices](https://github.com/li-langverse/roadmap/blob/main/proposals/lidb-native-li-matrices.md)).

---

## 5. Recommendations — liq grammar & tooling

| Priority | Change | Token / safety impact |
|----------|--------|------------------------|
| **P0** | SqlIr **alias folding** in compiler output | Cuts compiled SQL ~50%; no agent syntax change |
| **P0** | `read A with B on …` join sugar (inner only) | Restores join row honesty; target <35 tokens vs SQL 45 |
| **P1** | `aggregate agent_runs { count by status }` | Replaces GROUP BY SQL / stub `limit 500` scans |
| **P1** | `publish package_version + attestation { … }` multi-insert verb | One agent utterance vs 2-step Supabase |
| **P2** | Optional `select` alias for `read` ([`liq-spec.md` §9](./liq-spec.md)) | ~0 tokens; familiarity for SQL-native models |
| **P2** | `similar $vec` vector op (PH-DB-7) | Keeps ANN out of raw SQL strings |
| **P3** | `name resolve packages $name → $pkg_id` prelude macro | Saves repeat preludes in version lookups |

---

## 6. Agent continuation

1. **Read:** this file; [`docs/liq-spec.md`](./liq-spec.md); [`../benchmarks/docs/ecosystem/tier-db-token-efficiency.md`](../benchmarks/docs/ecosystem/tier-db-token-efficiency.md)
2. **Run:** `cd ../benchmarks && ./scripts/run-db-token-efficiency-bench.sh`
3. **Then:** After grammar/compiler changes, edit `benchmarks/tier_db_token_efficiency/scenarios.json` and re-run; verify `lidb/liq/compiler.py` parity on changed examples
4. **Blocked on:** none for audit refresh; dashboard `catalog.toml` row is benchmarks follow-up

---

## 7. References

- Compiler: [`liq/compiler.py`](../liq/compiler.py), [`liq/parser.py`](../liq/parser.py)
- Security: [`tests/security/README.md`](../tests/security/README.md)
- Control-plane consumer: [`li-cursor-agents` `src/db/liq-query.ts`](https://github.com/li-langverse/li-cursor-agents/blob/main/src/db/liq-query.ts)
