# Registry auth and row-level security (PH-DB-5)

Multi-tenant RLS for the central package registry (`migrations/001_registry.sql` + `002_rls_registry.sql`). Session identity uses **JWT claims** as PostgreSQL GUCs, matching [PostgREST / Supabase](https://postgrest.org/en/stable/api.html#accessing-request-headers-cookies-and-jwt-claims).

## Claims and helpers

| Claim / GUC | Purpose |
|-------------|---------|
| `request.jwt.claims` | JSON blob (PostgREST 9); primary source |
| `request.jwt.claim.sub` | User id → `registry_auth.uid()` |
| `request.jwt.claim.role` | `anon`, `authenticated`, `service_role` |
| `request.jwt.claim.publisher_id` | Registry tenant |

| Function | Returns |
|----------|---------|
| `registry_auth.jwt()` | Full claims `jsonb` |
| `registry_auth.uid()` | `uuid` from `sub` |
| `registry_auth.publisher_id()` | Tenant from JWT |
| `registry_auth.effective_publisher_id()` | JWT tenant or `publisher_members` fallback |
| `registry_auth.set_jwt_claims(jsonb)` | Transaction-local GUCs (lis embed) |

## Tenant model

- **Publisher** = tenant; catalog reads are public; writes to `package_versions` / `attestations` / `yanks` require matching `publisher_id`.
- **`publisher_members`** links `uid` → `publisher_id` when JWT omits `publisher_id`.
- **`service_role`** bypasses RLS for migrate, blocklist, and ops.

## lis session

```sql
SELECT registry_auth.set_jwt_claims(
  '{"role":"authenticated","sub":"<user-uuid>","publisher_id":"<publisher-uuid>"}'::jsonb
);
```

## Tests

`tests/security/rls-*.test.sh` — run `./tests/security/run_all.sh` (SKIP until `LIDB_ENGINE_READY=1`).
