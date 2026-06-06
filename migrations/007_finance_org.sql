-- lidb migration 007: li-books finance org, books, receipts, chat, clarifications
-- Requires prior registry migrations applied.
-- WP-020: org/book scoped bookkeeping schema (ported from documenting-receipts).

BEGIN;

-- ---------------------------------------------------------------------------
-- Organizations & membership
-- ---------------------------------------------------------------------------

CREATE TABLE finance_org (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                TEXT NOT NULL,
    kleinunternehmer    BOOLEAN NOT NULL DEFAULT false,
    stripe_customer_id  TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE org_member (
    org_id              UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    user_id             UUID NOT NULL,
    role                TEXT NOT NULL DEFAULT 'member'
                        CHECK (role IN ('owner', 'admin', 'member', 'accountant')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (org_id, user_id)
);

CREATE INDEX idx_org_member_user ON org_member (user_id);

-- Book = isolated tax domain ledger within an org
CREATE TABLE bookkeeping_account (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    name                TEXT NOT NULL,
    tax_domain          TEXT NOT NULL
                        CHECK (tax_domain IN ('freelance', 'company', 'income')),
    currency            TEXT NOT NULL DEFAULT 'EUR',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (org_id, name)
);

CREATE INDEX idx_bookkeeping_account_org ON bookkeeping_account (org_id);

-- ---------------------------------------------------------------------------
-- DE tax categories (seeded in seeds/de_tax_category.sql)
-- ---------------------------------------------------------------------------

CREATE TABLE de_tax_category (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code                TEXT NOT NULL UNIQUE,
    name                TEXT NOT NULL,
    tax_domains         TEXT[] NOT NULL DEFAULT '{}',
    deductibility_pct   NUMERIC(5, 2),
    vat_rate            NUMERIC(5, 2),
    ustva_line          TEXT,
    law_chunk_ids       UUID[] NOT NULL DEFAULT '{}',
    active              BOOLEAN NOT NULL DEFAULT true,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_de_tax_category_domains ON de_tax_category USING gin (tax_domains);

-- ---------------------------------------------------------------------------
-- Blob metadata (bytes in li-blob-service)
-- ---------------------------------------------------------------------------

CREATE TABLE blob_object (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id             UUID REFERENCES bookkeeping_account(id) ON DELETE SET NULL,
    storage_key         TEXT NOT NULL,
    content_type        TEXT,
    byte_size           BIGINT,
    sha256              TEXT,
    created_by          UUID,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_blob_object_org_book ON blob_object (org_id, book_id);

-- ---------------------------------------------------------------------------
-- Receipts (ported from documenting-receipts; book-scoped)
-- ---------------------------------------------------------------------------

CREATE TABLE receipts (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id             UUID NOT NULL REFERENCES bookkeeping_account(id) ON DELETE CASCADE,
    blob_object_id      UUID REFERENCES blob_object(id) ON DELETE SET NULL,
    amount              NUMERIC(12, 2) NOT NULL DEFAULT 0,
    subtotal_amount     NUMERIC(12, 2),
    tax_amount          NUMERIC(12, 2),
    tax_rate_percent    NUMERIC(5, 2),
    currency            TEXT NOT NULL DEFAULT 'EUR',
    spent_at            DATE NOT NULL DEFAULT CURRENT_DATE,
    merchant            TEXT,
    merchant_address    TEXT,
    payment_method      TEXT,
    payment_reference   TEXT,
    checkout_number     TEXT,
    terminal_number     TEXT,
    payment_checksum    TEXT,
    ust_id              TEXT,
    de_tax_category_id  UUID REFERENCES de_tax_category(id) ON DELETE SET NULL,
    notes               TEXT,
    raw_ocr_text        TEXT,
    ocr_provider        TEXT,
    llm_parse_snapshot  JSONB,
    validation_warnings BOOLEAN NOT NULL DEFAULT false,
    validation_snapshot JSONB,
    status              TEXT NOT NULL DEFAULT 'draft'
                        CHECK (status IN (
                            'draft', 'parsed', 'categorizing',
                            'needs_clarification', 'ready_to_post', 'posted'
                        )),
    confidence_score    NUMERIC(4, 3),
    created_by          UUID,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_receipts_org_book_spent ON receipts (org_id, book_id, spent_at DESC);
CREATE INDEX idx_receipts_book_status ON receipts (book_id, status);
CREATE INDEX idx_receipts_book_category ON receipts (book_id, de_tax_category_id);

CREATE OR REPLACE FUNCTION set_receipts_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER receipts_set_updated_at
    BEFORE UPDATE ON receipts
    FOR EACH ROW
    EXECUTE PROCEDURE set_receipts_updated_at();

CREATE TABLE receipt_line_items (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_id          UUID NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
    line_index          INTEGER NOT NULL,
    raw_line_text       TEXT,
    raw_product_name    TEXT NOT NULL,
    quantity            NUMERIC(12, 4),
    unit_price          NUMERIC(12, 2),
    line_total          NUMERIC(12, 2),
    de_tax_category_id  UUID REFERENCES de_tax_category(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (receipt_id, line_index)
);

CREATE INDEX idx_receipt_line_items_receipt ON receipt_line_items (receipt_id);

-- ---------------------------------------------------------------------------
-- Clarification FSM (ADR-002)
-- ---------------------------------------------------------------------------

CREATE TABLE clarification_thread (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id             UUID NOT NULL REFERENCES bookkeeping_account(id) ON DELETE CASCADE,
    receipt_id          UUID REFERENCES receipts(id) ON DELETE CASCADE,
    status              TEXT NOT NULL DEFAULT 'open'
                        CHECK (status IN ('open', 'resolved')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_clarification_thread_book_status
    ON clarification_thread (book_id, status);

CREATE TABLE clarification_question (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id           UUID NOT NULL REFERENCES clarification_thread(id) ON DELETE CASCADE,
    question_text       TEXT NOT NULL,
    suggested_category_id UUID REFERENCES de_tax_category(id) ON DELETE SET NULL,
    sort_order          INTEGER NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE clarification_answer (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id         UUID NOT NULL REFERENCES clarification_question(id) ON DELETE CASCADE,
    answer_text         TEXT NOT NULL,
    answered_by         UUID NOT NULL,
    answered_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Chat sessions (agentic-first UX)
-- ---------------------------------------------------------------------------

CREATE TABLE chat_session (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id             UUID NOT NULL REFERENCES bookkeeping_account(id) ON DELETE CASCADE,
    created_by          UUID,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_chat_session_book ON chat_session (book_id, created_at DESC);

CREATE TABLE chat_message (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id          UUID NOT NULL REFERENCES chat_session(id) ON DELETE CASCADE,
    role                TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content             TEXT NOT NULL,
    metadata            JSONB NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_chat_message_session ON chat_message (session_id, created_at);

-- ---------------------------------------------------------------------------
-- Finance audit trail (law citations in metadata)
-- ---------------------------------------------------------------------------

CREATE TABLE finance_action_audit (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id             UUID REFERENCES bookkeeping_account(id) ON DELETE SET NULL,
    actor_user_id       UUID,
    action              TEXT NOT NULL,
    entity_type         TEXT NOT NULL,
    entity_id           UUID,
    metadata            JSONB NOT NULL DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_finance_action_audit_org_book
    ON finance_action_audit (org_id, book_id, created_at DESC);

INSERT INTO schema_migrations (version, checksum)
VALUES ('007_finance_org', 'pending:computed-at-apply-time')
ON CONFLICT (version) DO NOTHING;

COMMIT;
