-- lidb migration 003: control-plane singleton + core tables (PH-DB-10 / WP-J / DB-R0-4)
-- Aligned with li-cursor-agents supabase/migrations/20260517120000_control_plane.sql (subset).

BEGIN;

CREATE TABLE IF NOT EXISTS control_plane_state (
    id          INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    version     INTEGER NOT NULL DEFAULT 1,
    payload     JSONB NOT NULL,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Extend agent_runs when table already exists from registry/control-plane smoke paths.
ALTER TABLE agent_runs ADD COLUMN IF NOT EXISTS backend TEXT;
ALTER TABLE agent_runs ADD COLUMN IF NOT EXISTS reason TEXT;
ALTER TABLE agent_runs ADD COLUMN IF NOT EXISTS fingerprint TEXT;
ALTER TABLE agent_runs ADD COLUMN IF NOT EXISTS coordinator TEXT;
ALTER TABLE agent_runs ADD COLUMN IF NOT EXISTS duration_ms INTEGER;
ALTER TABLE agent_runs ADD COLUMN IF NOT EXISTS output_md TEXT;
ALTER TABLE agent_runs ADD COLUMN IF NOT EXISTS output_path TEXT;
ALTER TABLE agent_runs ADD COLUMN IF NOT EXISTS error TEXT;
ALTER TABLE agent_runs ADD COLUMN IF NOT EXISTS completion JSONB;
ALTER TABLE agent_runs ADD COLUMN IF NOT EXISTS pr_urls JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE agent_runs ADD COLUMN IF NOT EXISTS deliverables JSONB;
ALTER TABLE agent_runs ADD COLUMN IF NOT EXISTS meta JSONB NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE agent_runs ADD COLUMN IF NOT EXISTS finished_at TIMESTAMPTZ;
ALTER TABLE agent_runs ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

INSERT INTO schema_migrations (version, checksum)
VALUES ('003_control_plane', 'wp-j-control-plane-state')
ON CONFLICT (version) DO NOTHING;

COMMIT;
