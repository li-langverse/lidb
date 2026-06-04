-- lidb migration 003: token pool + telemetry events (li-db studio P0 / WP-030)
-- Products meter exclusively via token-telemetry-service; no provider keys in product repos.

BEGIN;

CREATE TABLE token_pool (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL,
    product_id      TEXT NOT NULL,
    budget_tokens   BIGINT NOT NULL CHECK (budget_tokens >= 0),
    consumed_tokens BIGINT NOT NULL DEFAULT 0 CHECK (consumed_tokens >= 0),
    period_start    TIMESTAMPTZ NOT NULL,
    period_end      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (consumed_tokens <= budget_tokens),
    CHECK (period_end > period_start)
);

CREATE INDEX idx_token_pool_tenant_product
    ON token_pool (tenant_id, product_id);

CREATE TABLE telemetry_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pool_id         UUID NOT NULL REFERENCES token_pool(id) ON DELETE CASCADE,
    event_type      TEXT NOT NULL CHECK (event_type IN ('authorize', 'usage', 'refund')),
    tokens_delta    BIGINT NOT NULL,
    request_id      TEXT,
    authorization_id UUID,
    metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_telemetry_events_pool_recorded
    ON telemetry_events (pool_id, recorded_at DESC);

COMMIT;
