-- lidb migration 004: API bearer tokens for registry publish/yank
-- Requires 001_registry.sql applied first.

BEGIN;

CREATE TABLE IF NOT EXISTS api_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token_hash      TEXT NOT NULL UNIQUE,
    publisher_id    UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    scope           TEXT NOT NULL DEFAULT 'publish'
                    CHECK (scope IN ('publish', 'yank', 'publish+yank')),
    expires_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_api_tokens_publisher_id
    ON api_tokens (publisher_id);

CREATE INDEX IF NOT EXISTS idx_api_tokens_token_hash
    ON api_tokens (token_hash);

INSERT INTO schema_migrations (version, checksum)
VALUES ('004_auth_tokens', 'pending:computed-at-apply-time')
ON CONFLICT (version) DO NOTHING;

COMMIT;
