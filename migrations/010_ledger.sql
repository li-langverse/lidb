-- lidb migration 010: ledger, journal, period close, bank import
-- Requires 007_finance_org.sql applied first.
-- WP-220

BEGIN;

CREATE TABLE ledger_account (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id             UUID NOT NULL REFERENCES bookkeeping_account(id) ON DELETE CASCADE,
    account_number      TEXT NOT NULL,
    name                TEXT NOT NULL,
    account_type        TEXT NOT NULL
                        CHECK (account_type IN ('asset', 'liability', 'equity', 'revenue', 'expense')),
    active              BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (book_id, account_number)
);

CREATE INDEX idx_ledger_account_book ON ledger_account (book_id);

CREATE TABLE journal_entry (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id             UUID NOT NULL REFERENCES bookkeeping_account(id) ON DELETE CASCADE,
    entry_date          DATE NOT NULL,
    description         TEXT,
    receipt_id          UUID REFERENCES receipts(id) ON DELETE SET NULL,
    source              TEXT NOT NULL DEFAULT 'manual'
                        CHECK (source IN ('manual', 'receipt_post', 'bank_import', 'adjustment')),
    created_by          UUID,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_journal_entry_book_date ON journal_entry (book_id, entry_date DESC);

CREATE TABLE journal_line (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id            UUID NOT NULL REFERENCES journal_entry(id) ON DELETE CASCADE,
    ledger_account_id   UUID NOT NULL REFERENCES ledger_account(id) ON DELETE RESTRICT,
    debit               NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (debit >= 0),
    credit              NUMERIC(14, 2) NOT NULL DEFAULT 0 CHECK (credit >= 0),
    tax_category_code   TEXT,
    memo                TEXT,
    CHECK (debit > 0 OR credit > 0),
    CHECK (NOT (debit > 0 AND credit > 0))
);

CREATE INDEX idx_journal_line_entry ON journal_line (entry_id);
CREATE INDEX idx_journal_line_account ON journal_line (ledger_account_id);

CREATE TABLE tax_period_close (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id             UUID NOT NULL REFERENCES bookkeeping_account(id) ON DELETE CASCADE,
    period_start        DATE NOT NULL,
    period_end          DATE NOT NULL,
    closed_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_by           UUID,
    status              TEXT NOT NULL DEFAULT 'closed'
                        CHECK (status IN ('open', 'closed', 'exported')),
    metadata            JSONB NOT NULL DEFAULT '{}',
    UNIQUE (book_id, period_start, period_end)
);

CREATE INDEX idx_tax_period_close_book ON tax_period_close (book_id, period_end DESC);

CREATE TABLE bank_import_batch (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id             UUID NOT NULL REFERENCES bookkeeping_account(id) ON DELETE CASCADE,
    filename            TEXT,
    imported_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    row_count           INTEGER NOT NULL DEFAULT 0,
    status              TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'reconciled', 'failed'))
);

CREATE TABLE bank_import_line (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id            UUID NOT NULL REFERENCES bank_import_batch(id) ON DELETE CASCADE,
    line_index          INTEGER NOT NULL,
    booking_date        DATE NOT NULL,
    amount              NUMERIC(14, 2) NOT NULL,
    currency            TEXT NOT NULL DEFAULT 'EUR',
    counterparty        TEXT,
    reference           TEXT,
    matched_entry_id    UUID REFERENCES journal_entry(id) ON DELETE SET NULL,
    needs_clarification BOOLEAN NOT NULL DEFAULT false,
    UNIQUE (batch_id, line_index)
);

CREATE INDEX idx_bank_import_line_batch ON bank_import_line (batch_id);

INSERT INTO schema_migrations (version, checksum)
VALUES ('010_ledger', 'pending:computed-at-apply-time')
ON CONFLICT (version) DO NOTHING;

COMMIT;
