# lidb footprint targets (registry-min)

**Registry-min** = single-node embedded `lidb` backing the central package registry (PH-DB-4), no Supabase-style compose stack.

Targets are **budgets**, not guarantees, until PH-DB-7 benchmarking locks them in CI.

## Registry-min profile (256 MB class)

| Resource | Target | Notes |
|----------|--------|--------|
| **RSS (steady state)** | ≤ **256 MB** | Empty DB + connection pool (8) + WAL buffer; no vector indexes loaded |
| **RSS (publish burst)** | ≤ **384 MB** peak &lt; 30s | Single `POST /publish` transaction + attestation verify |
| **Disk (metadata only)** | ≤ **64 MB** | 10k package versions, indexes on `name`, `publisher_id` |
| **Disk (with blobs external)** | N/A in-min | Tarballs stay in object storage / git; DB holds digests only |
| **CPU (idle)** | &lt; **2%** one core | Embedded mode, no replication sender |
| **CPU (p99 read)** | &lt; **15 ms** on laptop class | `GET /packages/{name}/{version}` indexed lookup |
| **Startup** | &lt; **500 ms** | Cold start to accept SQL on Unix/macOS dev |

## Comparison anchors (design intent)

| Stack | Typical dev RAM | lidb goal |
|-------|-----------------|-----------|
| Supabase local Docker | ~1–2 GB+ | **≤256 MB** registry-min |
| Postgres 16 default docker | ~128–512 MB+ idle | Match or beat with Li heap + no legacy GUC surface |
| SQLite embedded | ~1–10 MB | Borrow simplicity; exceed with typed SQL + registry schema |

## Vertical budgets (full bundle, later phases)

Documented here for traceability; implementation is PH-DB-5+.

| Vertical | Registry-min | Full `lidb`+`lis` bundle |
|----------|--------------|---------------------------|
| Core SQL + migrations | ✓ in-min | ✓ |
| Auth (JWT/RLS hooks) | metadata only | +32 MB |
| Storage (metadata) | digest refs | +64 MB |
| Realtime | — | +48 MB optional module |
| Vector (pgvector-shaped) | — | +128 MB when index loaded |

## Measurement

| Check | PH-DB-1 | PH-DB-7 target |
|-------|---------|----------------|
| Functional smoke | `./scripts/smoke.sh` | + 1k version seed |
| RSS sampling | not gated in smoke | `lidb-bench --profile registry-min` |

### PH-DB-1 smoke expectations

- Build: `cmake` Release `lidb_embed` under `build/smoke/`.
- Data: temp dir with `.lidb/catalog.db` (sqlite smoke) and WAL segment stub.

## Measurement (TODO PH-DB-7)

- `scripts/smoke.sh` → placeholder until `lidb-bench` reports RSS via `/proc` or macOS `ps`.
- CI gate: fail if registry-min profile exceeds 256 MB RSS after `migrations/001_registry.sql` apply + 1k synthetic versions.
