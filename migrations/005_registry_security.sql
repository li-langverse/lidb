-- lidb migration 005: signup invites, device OAuth, audit log (registry security)

BEGIN;

CREATE TABLE signup_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token_hash      TEXT NOT NULL UNIQUE,
    email_hint      TEXT,
    max_uses        INT NOT NULL DEFAULT 1 CHECK (max_uses >= 1),
    uses            INT NOT NULL DEFAULT 0,
    expires_at      TIMESTAMPTZ,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE device_codes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_code     TEXT NOT NULL UNIQUE,
    user_code       TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'approved', 'expired')),
    user_id         UUID REFERENCES users(id),
    session_token   TEXT,
    api_token       TEXT,
    expires_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_device_codes_user_code ON device_codes (user_code);
CREATE INDEX idx_device_codes_device_code ON device_codes (device_code);

CREATE TABLE registry_audit_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event           TEXT NOT NULL,
    package_name    TEXT,
    package_version TEXT,
    publisher_id    UUID,
    token_id        UUID,
    client_ip       TEXT,
    details         JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_registry_audit_created ON registry_audit_log (created_at DESC);
CREATE INDEX idx_registry_audit_package ON registry_audit_log (package_name, package_version);

INSERT INTO schema_migrations (version, checksum)
VALUES ('005_registry_security', 'pending:computed-at-apply-time')
ON CONFLICT (version) DO NOTHING;

COMMIT;
