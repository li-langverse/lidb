-- Registry security: signup invites + access audit trail
-- Requires 001_registry.sql, 004_auth_tokens.sql

BEGIN;

CREATE TABLE IF NOT EXISTS signup_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token_hash      TEXT NOT NULL UNIQUE,
    email_hint      TEXT,
    max_uses        INT NOT NULL DEFAULT 1 CHECK (max_uses > 0),
    uses            INT NOT NULL DEFAULT 0 CHECK (uses >= 0),
    expires_at      TIMESTAMPTZ,
    created_by      UUID,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_signup_tokens_hash ON signup_tokens (token_hash);

CREATE TABLE IF NOT EXISTS registry_audit_log (
    id              BIGSERIAL PRIMARY KEY,
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    event           TEXT NOT NULL,
    method          TEXT,
    path            TEXT,
    status          INT,
    client_ip       INET,
    publisher_id    UUID REFERENCES publishers(id) ON DELETE SET NULL,
    user_id         UUID,
    package_name    TEXT,
    package_version TEXT,
    details         JSONB
);

CREATE INDEX IF NOT EXISTS idx_registry_audit_occurred
    ON registry_audit_log (occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_registry_audit_publisher
    ON registry_audit_log (publisher_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_registry_audit_ip
    ON registry_audit_log (client_ip, occurred_at DESC);

INSERT INTO schema_migrations (version, checksum)
VALUES ('016_registry_security', 'pending:computed-at-apply-time')
ON CONFLICT (version) DO NOTHING;

COMMIT;
