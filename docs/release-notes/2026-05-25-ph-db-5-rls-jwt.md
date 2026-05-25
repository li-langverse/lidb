# Release notes: 2026-05-25 — ph-db-5-rls-jwt

**Status:** Ready for review  
**Repo:** li-langverse/lidb  
**PH / REQ:** PH-DB-5  

## Summary

Registry RLS + Supabase-compatible JWT GUC helpers (`registry_auth`) and RLS security test stubs.

## Agent continuation

1. Read `docs/auth-rls.md`, `migrations/002_rls_registry.sql`
2. Run `./tests/security/run_all.sh` (SKIP until engine)
3. Wire harness when `LIDB_ENGINE_READY=1`; lis migrate applies `002` after `001`

## Not changed

- Engine/WAL implementation; `001_registry.sql` columns unchanged.

## Security

RLS tenant isolation on `package_versions`; stubs `rls-*.test.sh`.

## Performance

N/A
