-- WP-020: unified token pool + telemetry (TTS primary store on lidb)
-- Append-friendly ledger; reservations; usage + telemetry audit trail.

BEGIN;

CREATE TABLE IF NOT EXISTS token_pool (
  pool_id       UUID PRIMARY KEY,
  tenant_id     TEXT NOT NULL UNIQUE,
  label         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS token_ledger (
  id              UUID PRIMARY KEY,
  pool_id         UUID NOT NULL REFERENCES token_pool(pool_id),
  delta_tokens    BIGINT NOT NULL,
  reason          TEXT NOT NULL,
  ref_id          TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_token_ledger_pool
  ON token_ledger (pool_id, created_at DESC);

CREATE TABLE IF NOT EXISTS token_reservation (
  reservation_id  UUID PRIMARY KEY,
  pool_id           UUID NOT NULL REFERENCES token_pool(pool_id),
  request_id        TEXT NOT NULL,
  reserved_tokens   BIGINT NOT NULL CHECK (reserved_tokens > 0),
  status            TEXT NOT NULL CHECK (status IN ('active', 'released', 'consumed')),
  idempotency_key   TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_token_reservation_pool_status
  ON token_reservation (pool_id, status);

CREATE TABLE IF NOT EXISTS usage_metering (
  id              UUID PRIMARY KEY,
  pool_id         UUID NOT NULL REFERENCES token_pool(pool_id),
  product_id      TEXT NOT NULL,
  operation       TEXT NOT NULL,
  units           NUMERIC NOT NULL DEFAULT 1,
  cost_tokens     BIGINT NOT NULL,
  idempotency_key TEXT,
  request_id      TEXT,
  reservation_id  TEXT,
  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (pool_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_usage_metering_pool_created
  ON usage_metering (pool_id, created_at DESC);

CREATE TABLE IF NOT EXISTS telemetry_events (
  id              UUID PRIMARY KEY,
  pool_id         UUID NOT NULL REFERENCES token_pool(pool_id),
  product_id      TEXT NOT NULL,
  event_type      TEXT NOT NULL,
  request_id      TEXT,
  tokens_in       BIGINT NOT NULL DEFAULT 0,
  tokens_out      BIGINT NOT NULL DEFAULT 0,
  latency_ms      INTEGER,
  metadata        JSONB NOT NULL DEFAULT '{}',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_telemetry_events_pool_created
  ON telemetry_events (pool_id, created_at DESC);

COMMIT;
