-- SQLite control-plane tables for liorm / liq smoke (PH-DB-3).
PRAGMA foreign_keys = ON;

ALTER TABLE publishers ADD COLUMN display_name TEXT;

CREATE TABLE IF NOT EXISTS agent_runs (
    id TEXT PRIMARY KEY,
    run_id TEXT,
    agent_id TEXT,
    publisher_id TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    started_at TEXT,
    status TEXT,
    briefing_hash TEXT,
    completed_at TEXT,
    output TEXT
);

CREATE INDEX IF NOT EXISTS idx_agent_runs_created ON agent_runs (created_at);

ALTER TABLE package_versions ADD COLUMN tarball_sha256 TEXT;
