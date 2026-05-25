-- lidb migration 001: central registry metadata (PH-DB-1 / PH-DB-4)
-- Aligned with lip registry-v1 schema and publish gate fields:
--   proof_digest, coverage_pct, tree_digest (lip Phase 8d)

BEGIN;

CREATE TABLE publishers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL UNIQUE,
    public_key      BYTEA NOT NULL,          -- ed25519 verify key (32 bytes)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at      TIMESTAMPTZ
);

CREATE TABLE packages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT NOT NULL UNIQUE,    -- e.g. li-math
    description     TEXT,
    repository_url  TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE package_versions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_id      UUID NOT NULL REFERENCES packages(id) ON DELETE CASCADE,
    version         TEXT NOT NULL,           -- semver string
    tree_digest     TEXT NOT NULL,           -- sha256:… content tree
    proof_digest    TEXT,                    -- sha256:… lean proof artifact (nullable pre-proof)
    coverage_pct    DOUBLE PRECISION NOT NULL CHECK (coverage_pct >= 0 AND coverage_pct <= 100),
    publisher_id    UUID NOT NULL REFERENCES publishers(id),
    published_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    yanked          BOOLEAN NOT NULL DEFAULT false,
    UNIQUE (package_id, version)
);

CREATE INDEX idx_package_versions_name_version
    ON package_versions (package_id, version);

CREATE TABLE attestations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_version_id UUID NOT NULL REFERENCES package_versions(id) ON DELETE CASCADE,
    kind            TEXT NOT NULL,           -- e.g. sig-ed25519, sbom, coverage
    digest          TEXT NOT NULL,           -- sha256:…
    signature       BYTEA,                   -- detached sig when kind requires
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (package_version_id, kind, digest)
);

CREATE TABLE yanks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_version_id UUID NOT NULL REFERENCES package_versions(id) ON DELETE CASCADE,
    reason          TEXT NOT NULL,
    yanked_by       UUID NOT NULL REFERENCES publishers(id),
    yanked_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (package_version_id)
);

CREATE TABLE blocklist (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_name    TEXT,                    -- block all versions when set alone
    tree_digest     TEXT,                    -- block specific artifact
    reason          TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (package_name IS NOT NULL OR tree_digest IS NOT NULL)
);

CREATE INDEX idx_blocklist_package_name ON blocklist (package_name);
CREATE INDEX idx_blocklist_tree_digest ON blocklist (tree_digest);

COMMIT;
