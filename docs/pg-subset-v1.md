# Postgres subset v1 (`pg-subset-v1`)

**lidb** aims for Postgres-*shaped* SQL and wire ergonomics, not feature parity. This document is the explicit **NOT** list for PH-DB-1 … PH-DB-3 unless a later phase promotes an item.

## In scope (v1)

- `CREATE TABLE`, `INSERT`, `UPDATE`, `DELETE`, `SELECT` (single-statement, parameterized)
- B-tree indexes, primary key, unique, `NOT NULL`, `CHECK` (simple scalar)
- `TIMESTAMPTZ`, `TEXT`, `BYTEA`, `UUID`, `JSONB` (subset operators)
- Numeric types: `INT8`, `INT4`, `BOOL`, `FLOAT8`
- Transactions: `BEGIN` / `COMMIT` / `ROLLBACK`
- Embedded mode: single data directory, WAL on local FS
- Migrations: versioned SQL files (`migrations/*.sql`)
- Registry schema (see `migrations/001_registry.sql`)

## Explicit NOT list (v1)

### Replication & HA

- Streaming / logical replication
- Hot standby, failover manager, Patroni-style orchestration
- Multi-master, quorum writes

### Procedural & extensions

- `PL/pgSQL`, `PL/Python`, any server-side procedural language
- `CREATE EXTENSION` ecosystem (incl. PostGIS, `citext`, `hstore`, …)
- Foreign data wrappers (`postgres_fdw`, file FDWs)
- Custom aggregates / operators / types (beyond fixed v1 builtins)

### Advanced SQL & DDL

- Table partitioning (`PARTITION BY`, detach/attach)
- Inheritance (`INHERITS`)
- `RULE`, `EVENT TRIGGER`, `ALTER EVENT TRIGGER`
- `MERGE` (SQL:2003 merge)
- `COPY FREEZE`, binary `COPY` full parity
- `LISTEN` / `NOTIFY` (deferred to realtime module)
- Materialized views + `REFRESH MATERIALIZED VIEW CONCURRENTLY`
- Full-text search (`tsvector`, GIN tsquery) — basic `LIKE` only in v1
- Window functions beyond `ROW_NUMBER`, `COUNT` over partitions (phase later)
- Recursive CTEs
- Lateral joins (phase later)
- Savepoints nested depth &gt; 1

### Security & auth (Postgres-native)

- `pg_hba.conf` full matrix (use Li capability model instead)
- SCRAM channel binding edge cases beyond v1 interop profile
- Row-level security policies (RLS SQL) — **hooks only** in v1; enforcement via `lis` + `liorm` in PH-DB-5
- `SECURITY DEFINER` functions

### Storage & admin

- Tablespaces, tablespace-level placement
- Large objects (`lo_*` API)
- `pg_dump` / `pg_restore` custom format parity
- `VACUUM FULL`, parallel `VACUUM` workers
- Autovacuum tuning surface (fixed policy in v1)
- `pg_rewind`, base backup PITR (WAL archive is PH-DB-2+)

### Wire protocol & clients

- Full extended query protocol edge cases (portal suspend, copy-both)
- `PREPARE` name catalog unbounded (cap prepared statements per connection)
- JDBC/ODBC legacy compatibility modes

### Legacy Postgres surface (intentionally dropped)

- `WITH OIDS`
- `UNLOGGED` tables (use explicit temp/ephemeral API later)
- `SERIAL` implicit sequence magic — prefer `GENERATED … AS IDENTITY` subset
- `MONEY` type
- `XML` type and XPath functions
- `ENUM` alterations mid-flight
- System catalog compatibility views (`pg_catalog` full shape) — minimal catalogs only

### AI / vector (deferred)

- `vector` type + HNSW/IVFFlat indexes (PH-DB-6, pgvector-shaped)
- Embedding model hosting inside the engine

## Promotion process

To move an item from **NOT** → **IN**:

1. ADR in `roadmap/proposals/` or `docs/adr/`
2. Benchmark or security note if user-visible
3. Bump `pg-subset-v2.md` (do not silently expand v1)
