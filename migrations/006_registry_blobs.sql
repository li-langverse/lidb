-- lidb migration 006: content-addressed artifact blobs for registry P2P origin
-- Tracks blob presence; bytes live on filesystem (LIP_BLOB_DIR) or object store.

BEGIN;

CREATE TABLE IF NOT EXISTS artifact_blobs (
    digest TEXT PRIMARY KEY CHECK (digest ~ '^sha256:[a-f0-9]{64}$'),
    size_bytes BIGINT NOT NULL CHECK (size_bytes >= 0),
    media_type TEXT NOT NULL DEFAULT 'application/vnd.li.package+tar',
    stored_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ref_count INTEGER NOT NULL DEFAULT 0 CHECK (ref_count >= 0)
);

CREATE INDEX IF NOT EXISTS idx_artifact_blobs_stored_at ON artifact_blobs (stored_at DESC);

ALTER TABLE package_versions
    ADD COLUMN IF NOT EXISTS artifact_digest TEXT;

ALTER TABLE package_versions
    DROP CONSTRAINT IF EXISTS package_versions_artifact_digest_fkey;

ALTER TABLE package_versions
    ADD CONSTRAINT package_versions_artifact_digest_fkey
    FOREIGN KEY (artifact_digest) REFERENCES artifact_blobs (digest)
    ON DELETE RESTRICT;

INSERT INTO schema_migrations (version, checksum)
VALUES ('006_registry_blobs', 'pending:computed-at-apply-time')
ON CONFLICT (version) DO NOTHING;

COMMIT;
