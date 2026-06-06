-- lidb migration 012: tax_year on receipts + per-book-year unlock (WP-320 billing model)
-- One-time unlock per book_id + tax_year; tax_domain pricing at checkout time.

-- ---------------------------------------------------------------------------
-- tax_year on receipts (fiscal/tax year scoping; defaults from spent_at)
-- ---------------------------------------------------------------------------

ALTER TABLE receipts
    ADD COLUMN IF NOT EXISTS tax_year INT;

UPDATE receipts
SET tax_year = EXTRACT(YEAR FROM spent_at)::INT
WHERE tax_year IS NULL;

ALTER TABLE receipts
    ALTER COLUMN tax_year SET NOT NULL;

ALTER TABLE receipts
    ADD CONSTRAINT receipts_tax_year_range
    CHECK (tax_year >= 2000 AND tax_year <= 2100);

CREATE OR REPLACE FUNCTION set_receipt_tax_year()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.tax_year IS NULL THEN
        NEW.tax_year := EXTRACT(YEAR FROM NEW.spent_at)::INT;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS receipts_set_tax_year ON receipts;
CREATE TRIGGER receipts_set_tax_year
    BEFORE INSERT OR UPDATE OF spent_at, tax_year ON receipts
    FOR EACH ROW
    EXECUTE PROCEDURE set_receipt_tax_year();

CREATE INDEX IF NOT EXISTS idx_receipts_book_tax_year
    ON receipts (book_id, tax_year, spent_at DESC);

CREATE INDEX IF NOT EXISTS idx_receipts_org_book_year_status
    ON receipts (org_id, book_id, tax_year, status);

-- ---------------------------------------------------------------------------
-- book_year_entitlement — one-time Stripe unlock per book + calendar/fiscal year
-- ---------------------------------------------------------------------------

CREATE TABLE book_year_entitlement (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                      UUID NOT NULL REFERENCES finance_org(id) ON DELETE CASCADE,
    book_id                     UUID NOT NULL REFERENCES bookkeeping_account(id) ON DELETE CASCADE,
    tax_year                    INT NOT NULL CHECK (tax_year >= 2000 AND tax_year <= 2100),
    tax_domain                  TEXT NOT NULL
                                CHECK (tax_domain IN ('freelance', 'company', 'income')),
    unlocked_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
    stripe_checkout_session_id  TEXT,
    stripe_payment_intent_id    TEXT,
    amount_cents                INT NOT NULL,
    currency                    TEXT NOT NULL DEFAULT 'EUR',
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (book_id, tax_year)
);

CREATE INDEX idx_book_year_entitlement_org ON book_year_entitlement (org_id);
CREATE INDEX idx_book_year_entitlement_book_year ON book_year_entitlement (book_id, tax_year);

-- tax_period_close: scope closes to tax_year
ALTER TABLE tax_period_close
    ADD COLUMN IF NOT EXISTS tax_year INT;

UPDATE tax_period_close
SET tax_year = EXTRACT(YEAR FROM period_start::DATE)::INT
WHERE tax_year IS NULL;

ALTER TABLE tax_period_close
    ALTER COLUMN tax_year SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tax_period_close_book_year
    ON tax_period_close (book_id, tax_year);
