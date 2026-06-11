-- lidb migration 004: registry auth users + API tokens (PH-DB-5 auth)
-- Requires 001_registry.sql (publishers) and 002_rls_registry.sql (publisher_members).

BEGIN;

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           TEXT NOT NULL UNIQUE,
    password_hash   TEXT NOT NULL,
    publisher_id    UUID NOT NULL REFERENCES publishers(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_email ON users (email);

CREATE TABLE api_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token_hash      TEXT NOT NULL UNIQUE,
    publisher_id    UUID NOT NULL REFERENCES publishers(id),
    scope           TEXT NOT NULL CHECK (scope IN ('publish', 'yank', 'publish+yank', 'audit', 'publish+audit')),
    name            TEXT,
    expires_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at      TIMESTAMPTZ
);

CREATE INDEX idx_api_tokens_publisher ON api_tokens (publisher_id);
CREATE INDEX idx_api_tokens_hash ON api_tokens (token_hash);

INSERT INTO schema_migrations (version, checksum)
VALUES ('004_auth_tokens', 'pending:computed-at-apply-time')
ON CONFLICT (version) DO NOTHING;

COMMIT;
