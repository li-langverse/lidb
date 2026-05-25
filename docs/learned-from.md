# Learned from — lidb vertical survey

**Status:** Design reference (PH-DB-0 / PH-DB-G0)  
**Phase:** PH-DB-1 … PH-DB-10  
**Policy:** [engineering-standards — Learn from other ecosystems](https://github.com/li-langverse/roadmap/blob/main/docs/ecosystem/engineering-standards.md#learn-from-other-ecosystems-required-design-step)  
**ADR:** [lidb-li-data-platform](https://github.com/li-langverse/roadmap/blob/main/proposals/lidb-li-data-platform.md)

## Scope

This document surveys **2–4 mature systems per vertical** that inform **native Li `lidb`**. Verdicts are **Keep** (adopt as-is where Li allows), **Reject** (do not port), or **Adapt** (Li-specific shape).

**Hard constraint:** **SQLite is not a production target backend** for `lidb`. It may appear only as a temporary PH-DB-1 smoke harness until the native heap/WAL engine accepts SQL; see [pg-subset-v1.md](./pg-subset-v1.md).

**North star:** Postgres-*shaped* SQL + wire ergonomics, **easy + AI-first + provable + fast**, embedded in **`lis`** with **`liorm` / `liq`** as the default agent path — not a 15-container Supabase clone.

---

## How to read the tables

| Verdict | Meaning |
|---------|---------|
| **Keep** | Pattern becomes a normative requirement or test in `lidb` / `liorm` / `liq`. |
| **Reject** | Explicit non-goal; do not expand [pg-subset-v1.md](./pg-subset-v1.md) without ADR. |
| **Adapt** | Idea survives with Li constraints (capabilities, profiles, proof-friendly bounds). |

---

## OLTP storage

| System | What we studied | Keep | Reject | Adapt for native Li `lidb` |
|--------|-----------------|------|--------|----------------------------|
| **[PostgreSQL](https://www.postgresql.org/docs/)** | MVCC heap, WAL, SQL/DDL subset, `information_schema`, RLS, GUC session vars, extended query + migrations | Typed SQL surface; versioned `migrations/*.sql`; multi-tenant **RLS** + JWT GUCs ([auth-rls.md](./auth-rls.md)); `BEGIN`/`COMMIT`/`ROLLBACK`; registry DDL in `001_registry.sql` | Full `pg_catalog`; replication/Patroni; `PL/pgSQL`; extensions (`CREATE EXTENSION`); unbounded prepared-statement catalogs; legacy types (`MONEY`, `WITH OIDS`) — see [pg-subset-v1.md](./pg-subset-v1.md) NOT list | **Postgres-shaped** engine + wire subset, not compatibility fork; capability model instead of `pg_hba.conf` matrix; promote features only via ADR + `pg-subset-v2.md` |
| **[SQLite](https://www.sqlite.org/arch.html)** | Embedded file DB, B-tree pages, single-writer simplicity, `sqlite3` CLI ergonomics | Single data directory mental model; parameterized statements; “open file → run migrations” dev loop **only** as interim smoke | SQLite file format as storage; `AUTOINCREMENT`/`ROWID` semantics; weak typing defaults; `ATTACH` federation; authorizer hooks replacing **liorm** catalog | **Reject** as target backend; borrow **footprint discipline** (see [footprint.md](./footprint.md)) while exceeding with typed catalog + registry schema |
| **[WiredTiger](https://source.wiredtiger.com/develop/arch-index.html)** | LSM vs B-tree tradeoffs, checkpointing, cache sizing, durability tuning | Page-oriented I/O + explicit **WAL** append path (`engine/wal`, `LIDW` records); cache/buffer budget tied to **registry-min** RSS; checkpoint/fsync policy documented | MongoDB API surface; full WT API exposure to agents; unbounded cache without profile caps | Native **Li heap** with WT-*inspired* checkpoint/WAL discipline; 8 KiB page layout in `engine/` — not linking libwiredtiger in PH-DB-1..3 |
| **[DuckDB](https://duckdb.org/docs/)** *(analytics overlap)* | Columnar execution, vectorized aggregates, embedded analytics | — (see Analytics vertical) | OLTP default store on columnar only | Optional **read-only analytics module** (PH-DB-7+) fed by export/snapshot, not primary registry path |

**OLTP synthesis:** Primary store = **native lidb heap + WAL** with **Postgres-shaped** SQL and catalogs. **SQLite → smoke only.** **WiredTiger → storage engineering patterns**, not a second user-facing engine.

---

## Analytics

| System | What we studied | Keep | Reject | Adapt for native Li `lidb` |
|--------|-----------------|------|--------|----------------------------|
| **[DuckDB](https://duckdb.org/why-duckspeed)** | Embedded OLAP, columnar scans, Parquet/CSV ingest, window aggregates | Embedded **analyst profile** (`profiles/analyst.toml` future); bounded `COPY`/export for bench evidence; `EXPLAIN`-friendly plans for regression | Sharing buffer pool with hot OLTP registry-min without RSS cap; arbitrary UDFs inside engine; replacing core executor | **`lidb-analytics` module**: read snapshots or replica tables; **liq** `read …` compiles to columnar path only when `RawSqlCapability` + profile allow; default bundle stays OLTP |

**Analytics synthesis:** DuckDB informs **optional** reporting/bench slices, not the registry/control-plane OLTP core.

---

## Realtime

| System | What we studied | Keep | Reject | Adapt for native Li `lidb` |
|--------|-----------------|------|--------|----------------------------|
| **[Supabase Realtime](https://supabase.com/docs/guides/realtime)** | Postgres `LISTEN`/`NOTIFY` fanout, RLS-filtered change payloads, channel auth | **RLS-filtered** change envelopes; topic naming `schema:table:id`; JWT-scoped subscriptions in **lis** broker | Separate Elixir/Realtime microservice as mandatory compose piece; Postgres logical replication as MVP requirement | **lis** WAL/tail subscriber → WebSocket hub; hooks in `lidb` catalog triggers; **off** in `registry-min` ([footprint.md](./footprint.md) +48 MiB budget) |
| **[Firebase Realtime Database](https://firebase.google.com/docs/database)** | JSON tree sync, presence, offline queue | Presence + connection metadata schema; small **agent dashboard** payloads | JSON document store as primary registry model; security rules language replacing SQL/RLS | **Adapt:** event API mirrors Firebase ergonomics but payloads are **typed rows** from `liorm` plans, not free-form JSON rules |
| **[Ably](https://ably.com/docs/core-features)** | Channel capabilities, token auth, message history, QoS | Capability tokens per channel; explicit subscribe/publish scopes; rate limits per connection | Commercial cloud as hard dependency; global multi-region mesh for registry-min | **lis** embeds Ably-*style* authZ for channels; optional external bridge behind feature flag |

**Realtime synthesis:** Realtime is a **supervisor module**, not an engine feature. Defer `LISTEN`/`NOTIFY` in engine ([pg-subset-v1.md](./pg-subset-v1.md)) until broker design lands (PH-DB-9).

---

## Graph

| System | What we studied | Keep | Reject | Adapt for native Li `lidb` |
|--------|-----------------|------|--------|----------------------------|
| **[Kùzu](https://docs.kuzudb.com/)** | Embedded property graph, Cypher-ish queries, columnar graph storage | **Embedded** graph module flag; package dependency / provenance edges for registry (PH-DB-G0 research) | Second full query language in agent default path | **`lidb-graph`**: property-graph tables + **liq** graph verbs later; import snapshots from registry FK graph |
| **[Neo4j](https://neo4j.com/docs/)** | Cypher, index-free adjacency, clustering, graph algorithms | Labeled property graph model for **provenance** queries; explicit **read-only** graph profiles | Bolt cluster as registry-min requirement; enterprise causal cluster ops | **Adapt:** algorithms (path, centrality) as offline jobs reading exported edge lists — not in hot OLTP path |

**Graph synthesis:** Graph is **optional** (PH-DB-G0 / multi-model research). Registry MVP uses relational FKs; graph module promotes when lip provenance queries need it.

---

## Vector

| System | What we studied | Keep | Reject | Adapt for native Li `lidb` |
|--------|-----------------|------|--------|----------------------------|
| **[pgvector](https://github.com/pgvector/pgvector)** | `vector` type, `<->` operators, HNSW/IVFFlat indexes, SQL-native embeddings | **pgvector-shaped** type + index DDL in PH-DB-6; planner hooks; distance ops in SQL subset | Hosting embedding models inside engine; unbounded index RAM in registry-min | **`vector` type + HNSW** as optional module; **+128 MiB** when loaded ([footprint.md](./footprint.md)); agents use **liq** plans, not raw index DDL |
| **[Faiss](https://github.com/facebookresearch/faiss/wiki)** | GPU/CPU ANN, index factories, quantization | Index build **offline**; reproducible bench artifacts; SIMD-friendly search kernels (Li codegen later) | Faiss C++ runtime inside default `lis db start`; dynamic index pick per query from agents | **Adapt:** Faiss (or Li SIMD) builds index files **out-of-line**; `lidb` stores metadata + mmap handle; query via secured **liorm** plans |

**Vector synthesis:** SQL shape from **pgvector**; build/search acceleration **Adapt** from Faiss as tooling, not a second database.

---

## ORM security

| System | What we studied | Keep | Reject | Adapt for native Li `lidb` |
|--------|-----------------|------|--------|----------------------------|
| **[Prisma](https://www.prisma.io/docs/orm/prisma-client)*** | Schema-first models, prepared statements, `PrismaClient` ergonomics, migrate | **Schema/catalog snapshot** drives allowed tables; **prepared plans** only; migrate as versioned SQL | `$queryRaw` / `$executeRaw` on by default for agent profiles; string-built `orderBy` from user input; Rust query engine as opaque blob agents cannot audit | **`liorm`**: `execute(plan_id, params)` + `Ident::from_catalog` ([liorm/README.md](../liorm/README.md)); **`RawSqlCapability`** audited; **liq** as safer default than Prisma for MCP |
| **Postgres extended query** *(ORM adjacency)* | Bind parameters, separate parse/plan/execute | Parameter binding end-to-end; cap prepared statements per connection | Portal suspend / copy-both edge cases in v1 | Wire protocol subset in later phase; always mirror binding rules in **liorm** tests |
| **Django ORM / SQLAlchemy** *(survey context)* | Identifier quoting, `extra()` footguns | “No dynamic identifiers from user strings” invariant | ORM string interpolation escape hatches | Covered by **liorm** + `tests/security/cve-cwe-89-*.sh` |
| **Supabase JS client** *(agent adjacency)* | PostgREST filters, RLS-aware reads | Filtered reads respect **RLS** + JWT claims | PostgREST as mandatory stack; anon key wide write in agents | **liq** + **lis** registry routes replace ad-hoc filter strings |

\*Prisma is the named ORM-security reference for this vertical; others listed for contrast only.

**ORM security synthesis:** **liorm + liq** are the secure default; raw SQL is a **capability**, not a SDK convenience. CVE harness in `tests/security/` is the merge gate ([tests/security/README.md](../tests/security/README.md)).

---

## Cross-vertical decisions (native `lidb`)

| Topic | Decision |
|-------|----------|
| **Storage** | Native heap/WAL (WiredTiger-*inspired*), Postgres-shaped SQL; **no SQLite production backend** |
| **Agents** | **liq** → IR → **liorm** `execute`; catalog allowlist; no string-built SQL |
| **Bundle** | **`lis db start`** + `registry-min` profile; verticals via **feature flags**, not new microservices per vertical |
| **Supabase parity** | JWT/RLS **Keep**; Realtime/Storage/Edge **Adapt** as optional modules ([roadmap proposal](https://github.com/li-langverse/roadmap/blob/main/proposals/lidb-li-data-platform.md)) |
| **Promotion** | NOT → IN requires ADR + benchmark/security note + `pg-subset-vN+1.md` |

---

## Traceability

| Vertical | PH phase (indicative) | Primary docs / code |
|----------|----------------------|---------------------|
| OLTP | PH-DB-1, PH-DB-2 | `engine/`, `docs/pg-subset-v1.md`, `migrations/` |
| Analytics | PH-DB-7 | `docs/footprint.md`, future `profiles/analyst.toml` |
| Realtime | PH-DB-9 | `lis` broker, `docs/handoff-wp5-lis.md` |
| Graph | PH-DB-G0 | `docs/research/multi-model-gpu.md` |
| Vector | PH-DB-6 | `docs/pg-subset-v1.md` § AI/vector deferred |
| ORM security | PH-DB-2, PH-DB-5 | `liorm/`, `liq/`, `tests/security/` |

---

## Agent continuation

1. **Read:** this file, [pg-subset-v1.md](./pg-subset-v1.md), [liq-spec.md](./liq-spec.md), [roadmap `lidb-li-data-platform`](https://github.com/li-langverse/roadmap/blob/main/proposals/lidb-li-data-platform.md).
2. **Run:** `./scripts/run_tests.sh` (liorm/liq + security harness).
3. **Then:** when implementing a vertical, add ADR rows and update the vertical’s **Keep/Reject** with file paths + test ids.
4. **Blocked on:** human approval to promote any **Reject** item to **Keep** without ADR.

---

## References (URLs)

| System | URL |
|--------|-----|
| PostgreSQL | https://www.postgresql.org/docs/current/storage.html |
| SQLite | https://www.sqlite.org/arch.html |
| WiredTiger | https://source.wiredtiger.com/develop/arch-index.html |
| DuckDB | https://duckdb.org/docs/stable/ |
| Supabase Realtime | https://supabase.com/docs/guides/realtime |
| Firebase RTDB | https://firebase.google.com/docs/database |
| Ably | https://ably.com/docs/auth |
| Kùzu | https://docs.kuzudb.com/ |
| Neo4j | https://neo4j.com/docs/ |
| pgvector | https://github.com/pgvector/pgvector |
| Faiss | https://github.com/facebookresearch/faiss/wiki |
| Prisma | https://www.prisma.io/docs/orm/prisma-client |
