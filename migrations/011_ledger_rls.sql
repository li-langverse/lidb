-- lidb migration 011: RLS for ledger tables (WP-220)
-- Requires 008_books_rls.sql and 010_ledger.sql.

BEGIN;

ALTER TABLE ledger_account ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entry ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_line ENABLE ROW LEVEL SECURITY;
ALTER TABLE tax_period_close ENABLE ROW LEVEL SECURITY;
ALTER TABLE bank_import_batch ENABLE ROW LEVEL SECURITY;
ALTER TABLE bank_import_line ENABLE ROW LEVEL SECURITY;

CREATE POLICY books_service_ledger_account ON ledger_account
    FOR ALL USING (books_auth.is_service_role()) WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_journal_entry ON journal_entry
    FOR ALL USING (books_auth.is_service_role()) WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_journal_line ON journal_line
    FOR ALL USING (books_auth.is_service_role()) WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_tax_period_close ON tax_period_close
    FOR ALL USING (books_auth.is_service_role()) WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_bank_import_batch ON bank_import_batch
    FOR ALL USING (books_auth.is_service_role()) WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_bank_import_line ON bank_import_line
    FOR ALL USING (books_auth.is_service_role()) WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_tenant_ledger_account ON ledger_account
    FOR ALL USING (books_auth.is_org_member(org_id) AND books_auth.has_book_access(book_id))
    WITH CHECK (books_auth.is_org_member(org_id) AND books_auth.has_book_access(book_id));

CREATE POLICY books_tenant_journal_entry ON journal_entry
    FOR ALL USING (books_auth.is_org_member(org_id) AND books_auth.has_book_access(book_id))
    WITH CHECK (books_auth.is_org_member(org_id) AND books_auth.has_book_access(book_id));

CREATE POLICY books_tenant_journal_line ON journal_line
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM journal_entry je
            WHERE je.id = journal_line.entry_id
              AND books_auth.is_org_member(je.org_id)
              AND books_auth.has_book_access(je.book_id)
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM journal_entry je
            WHERE je.id = journal_line.entry_id
              AND books_auth.is_org_member(je.org_id)
              AND books_auth.has_book_access(je.book_id)
        )
    );

CREATE POLICY books_tenant_tax_period_close ON tax_period_close
    FOR ALL USING (books_auth.is_org_member(org_id) AND books_auth.has_book_access(book_id))
    WITH CHECK (books_auth.is_org_member(org_id) AND books_auth.has_book_access(book_id));

CREATE POLICY books_tenant_bank_import_batch ON bank_import_batch
    FOR ALL USING (books_auth.is_org_member(org_id) AND books_auth.has_book_access(book_id))
    WITH CHECK (books_auth.is_org_member(org_id) AND books_auth.has_book_access(book_id));

CREATE POLICY books_tenant_bank_import_line ON bank_import_line
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM bank_import_batch b
            WHERE b.id = bank_import_line.batch_id
              AND books_auth.is_org_member(b.org_id)
              AND books_auth.has_book_access(b.book_id)
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM bank_import_batch b
            WHERE b.id = bank_import_line.batch_id
              AND books_auth.is_org_member(b.org_id)
              AND books_auth.has_book_access(b.book_id)
        )
    );

INSERT INTO schema_migrations (version, checksum)
VALUES ('011_ledger_rls', 'pending:computed-at-apply-time')
ON CONFLICT (version) DO NOTHING;

COMMIT;
