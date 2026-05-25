-- SQLite subset for PH-DB-1 embedded smoke only.
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, checksum TEXT NOT NULL, applied_at TEXT NOT NULL DEFAULT (datetime('now')));
CREATE TABLE IF NOT EXISTS publishers (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, public_key BLOB NOT NULL, created_at TEXT NOT NULL DEFAULT (datetime('now')), revoked_at TEXT);
CREATE TABLE IF NOT EXISTS packages (id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, description TEXT, repository_url TEXT, created_at TEXT NOT NULL DEFAULT (datetime('now')));
CREATE TABLE IF NOT EXISTS package_versions (id TEXT PRIMARY KEY, package_id TEXT NOT NULL REFERENCES packages(id) ON DELETE CASCADE, version TEXT NOT NULL, tree_digest TEXT NOT NULL, proof_digest TEXT, coverage_pct REAL NOT NULL CHECK (coverage_pct >= 0 AND coverage_pct <= 100), publisher_id TEXT NOT NULL REFERENCES publishers(id), published_at TEXT NOT NULL DEFAULT (datetime('now')), yanked INTEGER NOT NULL DEFAULT 0 CHECK (yanked IN (0, 1)), UNIQUE (package_id, version));
CREATE INDEX IF NOT EXISTS idx_package_versions_pkg_ver ON package_versions (package_id, version);
