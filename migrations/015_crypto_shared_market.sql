-- lidb migration 015: shared crypto market data (WP-244)
-- Platform-owned minute prices (multi-user); user-scoped sync audit + cursors.

-- Global minute EUR prices — no user_id; shared across all books/users.
CREATE TABLE crypto_market_minute (
    asset           TEXT NOT NULL,
    minute_ts       TIMESTAMPTZ NOT NULL,
    price_eur       NUMERIC(18, 8) NOT NULL CHECK (price_eur > 0),
    source          TEXT NOT NULL CHECK (source IN ('coingecko', 'binance_public', 'manual', 'other')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (asset, minute_ts)
);

CREATE INDEX idx_crypto_market_minute_ts ON crypto_market_minute (minute_ts);
CREATE INDEX idx_crypto_market_minute_asset ON crypto_market_minute (asset, minute_ts);

-- Optional public on-chain events — dedupe across users watching the same contract.
CREATE TABLE crypto_chain_event (
    chain               TEXT NOT NULL,
    tx_hash             TEXT NOT NULL,
    log_index           INT NOT NULL DEFAULT 0,
    block_number        BIGINT,
    occurred_at         TIMESTAMPTZ,
    contract_address    TEXT,
    event_type          TEXT NOT NULL,
    payload             JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (chain, tx_hash, log_index)
);

CREATE INDEX idx_crypto_chain_event_contract ON crypto_chain_event (chain, contract_address, occurred_at);

-- User-scoped raw API responses for audit/replay (never shared across users).
CREATE TABLE crypto_sync_raw (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id         UUID NOT NULL REFERENCES bookkeeping_account(id) ON DELETE CASCADE,
    user_id         TEXT NOT NULL,
    source          TEXT NOT NULL,
    sync_cursor     TIMESTAMPTZ,
    response_body   JSONB NOT NULL,
    fetched_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_crypto_sync_raw_book_source ON crypto_sync_raw (book_id, user_id, source, fetched_at DESC);

-- Incremental exchange sync cursor per user + book + source.
CREATE TABLE crypto_sync_cursor (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id         UUID NOT NULL REFERENCES bookkeeping_account(id) ON DELETE CASCADE,
    user_id         TEXT NOT NULL,
    source          TEXT NOT NULL,
    last_sync_at    TIMESTAMPTZ NOT NULL,
    cursor_payload  JSONB,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (book_id, user_id, source)
);

CREATE INDEX idx_crypto_sync_cursor_book ON crypto_sync_cursor (book_id, user_id, source);
