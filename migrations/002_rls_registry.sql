-- lidb migration 002: RLS + JWT session GUC (PH-DB-5 prep)
-- Multi-tenant isolation for publishers / package_versions; Supabase-compatible JWT GUCs.
-- Requires 001_registry.sql applied first.

BEGIN;

CREATE SCHEMA IF NOT EXISTS registry_auth;

CREATE OR REPLACE FUNCTION registry_auth.jwt()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    NULLIF(current_setting('request.jwt.claims', true), '')::jsonb,
    '{}'::jsonb
  );
$$;

CREATE OR REPLACE FUNCTION registry_auth.role()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    NULLIF(registry_auth.jwt() ->> 'role', ''),
    NULLIF(current_setting('request.jwt.claim.role', true), ''),
    'anon'
  );
$$;

CREATE OR REPLACE FUNCTION registry_auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(
    COALESCE(
      NULLIF(registry_auth.jwt() ->> 'sub', ''),
      NULLIF(current_setting('request.jwt.claim.sub', true), '')
    ),
    ''
  )::uuid;
$$;

CREATE OR REPLACE FUNCTION registry_auth.publisher_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(
    COALESCE(
      NULLIF(registry_auth.jwt() ->> 'publisher_id', ''),
      NULLIF(current_setting('request.jwt.claim.publisher_id', true), '')
    ),
    ''
  )::uuid;
$$;

CREATE OR REPLACE FUNCTION registry_auth.is_service_role()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT registry_auth.role() = 'service_role';
$$;

CREATE OR REPLACE FUNCTION registry_auth.set_jwt_claims(claims jsonb)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM set_config('request.jwt.claims', claims::text, true);
  IF claims ? 'role' THEN
    PERFORM set_config('request.jwt.claim.role', claims ->> 'role', true);
  END IF;
  IF claims ? 'sub' THEN
    PERFORM set_config('request.jwt.claim.sub', claims ->> 'sub', true);
  END IF;
  IF claims ? 'publisher_id' THEN
    PERFORM set_config(
      'request.jwt.claim.publisher_id',
      claims ->> 'publisher_id',
      true
    );
  END IF;
END;
$$;

CREATE TABLE publisher_members (
    publisher_id    UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL,
    role            TEXT NOT NULL DEFAULT 'member'
                    CHECK (role IN ('owner', 'admin', 'member')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (publisher_id, user_id)
);

CREATE INDEX idx_publisher_members_user ON publisher_members (user_id);

CREATE OR REPLACE FUNCTION registry_auth.effective_publisher_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    registry_auth.publisher_id(),
    (
      SELECT pm.publisher_id
      FROM publisher_members pm
      WHERE pm.user_id = registry_auth.uid()
      ORDER BY pm.created_at
      LIMIT 1
    )
  );
$$;

ALTER TABLE publishers ENABLE ROW LEVEL SECURITY;
ALTER TABLE packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE package_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE attestations ENABLE ROW LEVEL SECURITY;
ALTER TABLE yanks ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocklist ENABLE ROW LEVEL SECURITY;
ALTER TABLE publisher_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY registry_service_publishers ON publishers
    FOR ALL
    USING (registry_auth.is_service_role())
    WITH CHECK (registry_auth.is_service_role());

CREATE POLICY registry_service_packages ON packages
    FOR ALL
    USING (registry_auth.is_service_role())
    WITH CHECK (registry_auth.is_service_role());

CREATE POLICY registry_service_package_versions ON package_versions
    FOR ALL
    USING (registry_auth.is_service_role())
    WITH CHECK (registry_auth.is_service_role());

CREATE POLICY registry_service_attestations ON attestations
    FOR ALL
    USING (registry_auth.is_service_role())
    WITH CHECK (registry_auth.is_service_role());

CREATE POLICY registry_service_yanks ON yanks
    FOR ALL
    USING (registry_auth.is_service_role())
    WITH CHECK (registry_auth.is_service_role());

CREATE POLICY registry_service_blocklist ON blocklist
    FOR ALL
    USING (registry_auth.is_service_role())
    WITH CHECK (registry_auth.is_service_role());

CREATE POLICY registry_service_publisher_members ON publisher_members
    FOR ALL
    USING (registry_auth.is_service_role())
    WITH CHECK (registry_auth.is_service_role());

CREATE POLICY registry_public_read_packages ON packages
    FOR SELECT
    USING (true);

CREATE POLICY registry_public_read_package_versions ON package_versions
    FOR SELECT
    USING (NOT yanked);

CREATE POLICY registry_public_read_attestations ON attestations
    FOR SELECT
    USING (true);

CREATE POLICY registry_public_read_publishers ON publishers
    FOR SELECT
    USING (revoked_at IS NULL);

CREATE POLICY registry_tenant_read_own_publisher ON publishers
    FOR SELECT
    USING (
        registry_auth.effective_publisher_id() IS NOT NULL
        AND id = registry_auth.effective_publisher_id()
    );

CREATE POLICY registry_tenant_insert_package_versions ON package_versions
    FOR INSERT
    WITH CHECK (
        registry_auth.effective_publisher_id() IS NOT NULL
        AND publisher_id = registry_auth.effective_publisher_id()
    );

CREATE POLICY registry_tenant_update_own_versions ON package_versions
    FOR UPDATE
    USING (publisher_id = registry_auth.effective_publisher_id())
    WITH CHECK (publisher_id = registry_auth.effective_publisher_id());

CREATE POLICY registry_tenant_insert_attestations ON attestations
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM package_versions pv
            WHERE pv.id = package_version_id
              AND pv.publisher_id = registry_auth.effective_publisher_id()
        )
    );

CREATE POLICY registry_tenant_insert_yanks ON yanks
    FOR INSERT
    WITH CHECK (
        yanked_by = registry_auth.effective_publisher_id()
        AND EXISTS (
            SELECT 1
            FROM package_versions pv
            WHERE pv.id = package_version_id
              AND pv.publisher_id = registry_auth.effective_publisher_id()
        )
    );

CREATE POLICY registry_member_read_own ON publisher_members
    FOR SELECT
    USING (user_id = registry_auth.uid());

CREATE POLICY registry_member_manage_own_publisher ON publisher_members
    FOR ALL
    USING (
        registry_auth.effective_publisher_id() IS NOT NULL
        AND publisher_id = registry_auth.effective_publisher_id()
    )
    WITH CHECK (
        registry_auth.effective_publisher_id() IS NOT NULL
        AND publisher_id = registry_auth.effective_publisher_id()
    );

COMMIT;
