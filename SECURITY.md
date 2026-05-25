# Security policy (lidb)

## Reporting

Report security issues in **lidb** the same way as [**lic**](https://github.com/li-langverse/lic/blob/main/SECURITY.md): private disclosure first, no public exploit threads before coordination.

## Non-negotiable gates (do not weaken)

These policies are owned by the ecosystem; **lidb must not bypass them**:

| Gate | Owner | Requirement |
|------|--------|-------------|
| Publish | **lip** | `lic build` (proof) + **ed25519** signature + **`lit` ≥ 80%** coverage |
| Unsigned third-party | **lip** | Rejected by default |
| Blocklist / yank | **lidb** + **lip** | `blocklist` and `yanks` tables are authoritative; API fail-closed |
| Attestations | **lidb** | `attestations` rows required for trusted install paths (PH-DB-4) |

Scaffold SQL in `migrations/001_registry.sql` models these tables; enforcement code lands in PH-DB-4.

## Engine scope

- SQL injection resistance for application code is primarily **liorm** / **liq** (WP2); lidb still uses bound parameters only in server paths.
- Memory safety: prefer Li + audited C++ for hot paths; ASan/UBSan in CI when native code ships (PH-DB-2).
- Encryption at rest: explicit opt-in module (PH-DB-5); no silent downgrade to plaintext for registry-min production.

## CVE / dependency tracking

Native dependencies (when added) will be listed in `security/` with the same **pinned catalog + CI** pattern as `lic`. Until then, this repo is docs + SQL only.
