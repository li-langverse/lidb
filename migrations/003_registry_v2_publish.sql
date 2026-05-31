-- lidb migration 003: registry v2 publish metadata (manifest + source provenance)
-- Adds lip Phase-8 publish fields to package_versions.
-- Requires 001_registry.sql applied first.

BEGIN;

ALTER TABLE package_versions
    ADD COLUMN IF NOT EXISTS manifest_signature TEXT;

ALTER TABLE package_versions
    ADD COLUMN IF NOT EXISTS source_type TEXT;

ALTER TABLE package_versions
    ADD COLUMN IF NOT EXISTS source_url TEXT;

ALTER TABLE package_versions
    ADD COLUMN IF NOT EXISTS source_tag TEXT;

ALTER TABLE package_versions
    DROP CONSTRAINT IF EXISTS package_versions_source_type_check;

ALTER TABLE package_versions
    ADD CONSTRAINT package_versions_source_type_check
    CHECK (source_type IS NULL OR source_type IN ('git', 'registry', 'path'));

INSERT INTO schema_migrations (version, checksum)
VALUES ('003_registry_v2_publish', 'pending:computed-at-apply-time')
ON CONFLICT (version) DO NOTHING;

COMMIT;
