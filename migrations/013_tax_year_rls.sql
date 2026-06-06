-- lidb migration 013: RLS for book_year_entitlement

ALTER TABLE book_year_entitlement ENABLE ROW LEVEL SECURITY;

CREATE POLICY books_service_entitlements ON book_year_entitlement
    FOR ALL
    USING (books_auth.is_service_role())
    WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_tenant_read_entitlements ON book_year_entitlement
    FOR SELECT
    USING (books_auth.is_org_member(org_id));

CREATE POLICY books_tenant_write_entitlements ON book_year_entitlement
    FOR INSERT
    WITH CHECK (
        books_auth.is_org_member(org_id)
        AND books_auth.has_book_access(book_id)
    );
