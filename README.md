# lidb

Li-native Postgres-shaped database engine (library + embedded server). Part of the **PH-DB** program for registry v2 and the lean **lidb + lis** bundle.

## Layout

| Path | Phase | Role |
|------|-------|------|
| `migrations/` | PH-DB-1 | Registry schema (`001_registry.sql`) |
| `docs/footprint.md` | PH-DB-1 | registry-min RAM/CPU targets |
| `docs/pg-subset-v1.md` | PH-DB-1 | Supported / excluded SQL surface |
| `src/` | PH-DB-1+ | Engine (WAL, heap — in progress) |
| `liorm/` | PH-DB-2 | Secure ORM — catalog-bound identifiers, prepared plans |
| `liq/` | PH-DB-2 | Token-efficient query language (Lang → IR → SQL) |
| `tests/security/` | PH-DB-2 | CVE-oriented regression harness (stubs until engine) |
| `docs/liq-spec.md` | PH-DB-2 | liq language and compilation pipeline |

## Quick links

- [Footprint targets](docs/footprint.md)
- [Postgres subset v1](docs/pg-subset-v1.md)
- [liorm API sketch](liorm/README.md)
- [liq AST examples](liq/README.md)
- [liq specification](docs/liq-spec.md)
- [Security regression stubs](tests/security/README.md)
- [WP5 lis handoff](docs/handoff-wp5-lis.md)

## Consumers

- **lis** (PH-DB-3): embeds lidb in-process; agents and CLI use `liq` / `liorm` instead of ad-hoc SQL strings.
- **lic / registry**: registry-min profile; see `profiles/registry-min.toml` in **lis** when available.

## License

TBD — align with Li Langverse policy when publishing `li-langverse/lidb`.
