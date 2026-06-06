-- lidb migration 014: crypto ledger (WP-241)
-- Minute-granularity tax load; FIFO lots; wallet + exchange sources.

CREATE TABLE crypto_wallet (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id         UUID NOT NULL REFERENCES bookkeeping_account(id) ON DELETE CASCADE,
    chain           TEXT NOT NULL DEFAULT 'ethereum',
    address         TEXT NOT NULL,
    label           TEXT,
    vault_secret_ref TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (book_id, chain, address)
);

CREATE TABLE crypto_exchange_account (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id         UUID NOT NULL REFERENCES bookkeeping_account(id) ON DELETE CASCADE,
    exchange        TEXT NOT NULL CHECK (exchange IN ('kraken', 'binance', 'coinbase', 'csv_import', 'other')),
    label           TEXT,
    vault_secret_ref TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE crypto_transaction (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id         UUID NOT NULL REFERENCES bookkeeping_account(id) ON DELETE CASCADE,
    tax_year        INT NOT NULL CHECK (tax_year >= 2000 AND tax_year <= 2100),
    source_type     TEXT NOT NULL CHECK (source_type IN ('wallet', 'exchange', 'csv')),
    source_id       UUID,
    tx_hash         TEXT,
    external_id     TEXT,
    occurred_at     TIMESTAMPTZ NOT NULL,
    asset           TEXT NOT NULL,
    quantity        NUMERIC(36, 18) NOT NULL,
    fiat_amount_eur NUMERIC(18, 2),
    tx_type         TEXT NOT NULL CHECK (tx_type IN (
        'buy', 'sell', 'transfer_in', 'transfer_out', 'swap', 'staking_reward', 'fee', 'unknown'
    )),
    counterparty    TEXT,
    de_tax_category_id UUID REFERENCES de_tax_category(id) ON DELETE SET NULL,
    needs_clarification BOOLEAN NOT NULL DEFAULT false,
    raw_payload     JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_crypto_tx_book_year_time ON crypto_transaction (book_id, tax_year, occurred_at);
CREATE INDEX idx_crypto_tx_book_clarify ON crypto_transaction (book_id, needs_clarification)
    WHERE needs_clarification = true;

CREATE TABLE crypto_lot (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id         UUID NOT NULL REFERENCES bookkeeping_account(id) ON DELETE CASCADE,
    tax_year        INT NOT NULL,
    asset           TEXT NOT NULL,
    acquired_at     TIMESTAMPTZ NOT NULL,
    quantity        NUMERIC(36, 18) NOT NULL,
    cost_basis_eur  NUMERIC(18, 2) NOT NULL,
    remaining_qty   NUMERIC(36, 18) NOT NULL,
    source_tx_id    UUID REFERENCES crypto_transaction(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_crypto_lot_book_asset ON crypto_lot (book_id, asset, acquired_at);

-- Minute rollup: cumulative tax load timeline (P&L + estimated tax EUR)
CREATE TABLE crypto_tax_minute (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id             UUID NOT NULL REFERENCES bookkeeping_account(id) ON DELETE CASCADE,
    tax_year            INT NOT NULL,
    minute_ts           TIMESTAMPTZ NOT NULL,
    realized_pnl_eur    NUMERIC(18, 2) NOT NULL DEFAULT 0,
    unrealized_pnl_eur  NUMERIC(18, 2) NOT NULL DEFAULT 0,
    taxable_gain_eur    NUMERIC(18, 2) NOT NULL DEFAULT 0,
    estimated_tax_eur   NUMERIC(18, 2) NOT NULL DEFAULT 0,
    tx_count            INT NOT NULL DEFAULT 0,
    spike_flag          BOOLEAN NOT NULL DEFAULT false,
    metadata            JSONB,
    UNIQUE (book_id, tax_year, minute_ts)
);

CREATE INDEX idx_crypto_tax_minute_book_year ON crypto_tax_minute (book_id, tax_year, minute_ts);
