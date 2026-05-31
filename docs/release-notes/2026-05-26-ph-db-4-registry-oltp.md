# PH-DB-4 registry OLTP MVP (WP-D)

**PH / REQ:** PH-DB-4, REQ-registry-v2 (read path)  
**Branch:** `cursor/wp-d-ph-db-4-registry`

## Summary

- Added `registry/` package: frozen liorm plans + `RegistryOltp` for read/list/publish against native embed.
- Documented schema/OpenAPI gap table and PH-8d-v2 exit gate (lic cross-link).
- Aligned `liorm` catalog `publishers` columns with `001_registry.sql`.

## Verify

```bash
bash scripts/smoke.sh
PYTHONPATH=. pytest tests/test_registry_oltp.py -q
```

## Not in this slice

- lip HTTP handlers / OpenAPI merge (blocked-on-PH-DB-4)
- `003_registry_v2_publish.sql` (manifest_signature, source_*)
- `lis db` registry-min supervisor (PH-DB-3)
