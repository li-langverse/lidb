# PH-DB-4 registry schema parity (WP-D)

**Status:** MVP alignment (2026-05-26)  
**Canonical DDL:** [`migrations/001_registry.sql`](../migrations/001_registry.sql)  
**OLTP facade:** [`registry/`](../registry/) (liorm plans + `RegistryOltp`)  
**lip OpenAPI (blocked):** [`lip/registry/api`](https://github.com/li-langverse/lip/tree/main/registry/api) — full spec on branch `feat/ph-db-4-registry-openapi` (not merged)  
**Bench DDL:** [`benchmarks/tier_db_registry/schema/registry-v1.sql`](https://github.com/li-langverse/benchmarks/blob/main/benchmarks/tier_db_registry/schema/registry-v1.sql)

## Read-path field parity (lip OpenAPI → lidb `001_registry`)

| lip / OpenAPI field | `001_registry.sql` | Blocking PH-8d-v2 read? | Notes |
|---------------------|-------------------|-------------------------|-------|
| `name` | `packages.name` | No | `RegistryOltp.get_package_version` |
| `version` | `package_versions.version` | No | |
| `tree_digest` | `package_versions.tree_digest` | No | publish gate |
| `proof_digest` | `package_versions.proof_digest` (nullable) | No | nullable pre-proof |
| `coverage_pct` | `package_versions.coverage_pct` | No | |
| `publisher_id` | `package_versions.publisher_id` | No | |
| `published_at` | `package_versions.published_at` | No | |
| `yanked` | `package_versions.yanked` | No | column + `yanks` table |
| `repository_url` | `packages.repository_url` | No | package row |
| `description` | `packages.description` | No | |
| `manifest_signature` | — | **Yes** (publish path) | lip v2 schema; add migration `003_registry_v2_publish.sql` |
| `source_type` / `source_url` / `source_tag` | — | **Yes** (publish path) | Git-first v1 uses index.json; central DB needs columns or JSONB |
| `spdx_license`, `changelog_url`, `documentation_url` | — | No (optional metadata) | defer to v2.1 |
| `attestations[]` | `attestations` table | No (read via separate plan) | kind/digest vs lip `attestation_type`/`metadata` naming drift |
| blocklist by `block_kind` | `blocklist(package_name\|tree_digest)` | Partial | lip uses typed block_kind; map at HTTP layer |

## DDL source drift (non-blocking for MVP reads)

| Source | ID type | `packages.publisher_id` | Notes |
|--------|---------|-------------------------|-------|
| **lidb `001_registry`** | UUID | absent (publisher on version) | **canonical** for embed + WP-D |
| **tier_db_registry v1** | BIGSERIAL | on `packages` | bench harness only; sync before WP-C measured runs |
| **lip `registry/schema` (open branch)** | BIGSERIAL + extra columns | N/A | merge after `003_*` migration lands on lidb |

## Engine limitations (documented, not schema blockers)

- Native embed `exec_select` supports **one** parameterized `WHERE` column; multi-key filters are composed in `RegistryOltp` (Python).
- No HTTP server in lidb — **lip** implements REST after PH-DB-4 exit gate.

## PH-8d-v2 unblock checklist

See [lic PH-DB-4 exit gate](https://github.com/li-langverse/lic/blob/main/docs/superpowers/plans/ph-db-4-exit-gate.md).
