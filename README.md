# lidb

Li-native Postgres-shaped database engine (library + embedded server). Part of the **PH-DB** program for registry v2 and the lean **lidb + lis** bundle.

## Smoke (PH-DB-1)

```bash
./scripts/smoke.sh
```

Requires `cmake` and `python3` only (native `lidb_embed`; sqlite3 removed PH-DB-3.1). Not production Postgres.

## CI / cross-repo gate (WP-G)

```bash
./scripts/ci_ph_db_gate.sh   # smoke + key pytest subset
```

See [docs/ci-ph-db-gate.md](docs/ci-ph-db-gate.md) for `LIDB_CI_REF`, `LIDB_REPO`, and workflow triggers.

## Container (WP-H)

Standalone embed image (no **lis** supervisor):

```bash
docker build -f docker/Dockerfile.embed -t lidb-embed:local .
```

For `lis db start` + compose dev stack, use **lis** [`docker-compose.ph-db.yml`](https://github.com/li-langverse/lis/blob/main/docker-compose.ph-db.yml) (multi-stage bake of this repo).

## Benchmark harnesses (WP-N4)

When `BENCH_DB_*_RUN_HARNESS=1`, **benchmarks** invokes scripts under `scripts/bench/`:

| Env | Script | Tier |
|-----|--------|------|
| `BENCH_DB_SECURITY_RUN_HARNESS=1` | `scripts/bench/security_harness.sh` | `tier_db_security` |
| `BENCH_DB_MEMORY_RUN_HARNESS=1` | `scripts/bench/memory_footprint.sh` | `tier_db_memory` |
| `BENCH_DB_PARALLEL_RUN_HARNESS=1` | `scripts/bench/parallel_load.sh` | `tier_db_parallel` |

Optional: `BENCH_PROFILE=ci|nightly`, `LIDB_EMBED`, `LIDB_RLS_HARNESS=1` (RLS probes). JSON lines via `harness_emit.py` for benchmarks ingest.

## Layout

| Path | Phase | Role |
|------|-------|------|
| `migrations/` | PH-DB-1 / PH-DB-5 | Registry schema + RLS (`001_registry.sql`, `002_rls_registry.sql`) |
| `liq/` | PH-DB-2 | Token-efficient query language — parser/compiler (Python stub) |
| `liorm/` | PH-DB-2 | Secure ORM — catalog allowlist, `execute`, capabilities (Python stub) |
| `tests/` | PH-DB-2 | pytest unit tests for liq/liorm |
| `tests/security/` | PH-DB-2 / PH-DB-5 | CVE harness (liorm) + RLS stubs (engine) |
| `scripts/run_tests.sh` | PH-DB-2 | venv pytest + security `run_all.sh` |
| `docs/footprint.md` | PH-DB-1 | registry-min RAM/CPU targets |
| `docs/pg-subset-v1.md` | PH-DB-1 | Supported / excluded SQL surface |
| `docs/liq-spec.md` | PH-DB-2 | liq Lang→IR→SQL pipeline |
| `docs/auth-rls.md` | PH-DB-5 | JWT GUCs, tenant RLS policies, lis session setup |
| `src/` | PH-DB-1+ | Engine (WAL, heap — in progress) |

## Quick links

- [Footprint targets](docs/footprint.md)
- [Postgres subset v1](docs/pg-subset-v1.md)
- [liorm API sketch](liorm/README.md)
- [liq AST examples](liq/README.md)
- [liq specification](docs/liq-spec.md)
- [Auth and RLS](docs/auth-rls.md)
- [Security regression stubs](tests/security/README.md)

## Consumers

- **lis** (PH-DB-3): embeds lidb in-process; agents and CLI use `liq` / `liorm` instead of ad-hoc SQL strings.
- **lic / registry**: registry-min profile; see `profiles/registry-min.toml` in **lis** when available.

## License

TBD — align with Li Langverse policy when publishing `li-langverse/lidb`.
