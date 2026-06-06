-- lidb migration 008: li-books RLS + books_auth JWT helpers
-- Requires 007_finance_org.sql applied first.
-- Mirrors registry_auth pattern for org/book multi-tenancy.

BEGIN;

CREATE SCHEMA IF NOT EXISTS books_auth;

CREATE OR REPLACE FUNCTION books_auth.jwt()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    NULLIF(current_setting('request.jwt.claims', true), '')::jsonb,
    '{}'::jsonb
  );
$$;

CREATE OR REPLACE FUNCTION books_auth.role()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    NULLIF(books_auth.jwt() ->> 'role', ''),
    NULLIF(current_setting('request.jwt.claim.role', true), ''),
    'anon'
  );
$$;

CREATE OR REPLACE FUNCTION books_auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(
    COALESCE(
      NULLIF(books_auth.jwt() ->> 'sub', ''),
      NULLIF(current_setting('request.jwt.claim.sub', true), '')
    ),
    ''
  )::uuid;
$$;

CREATE OR REPLACE FUNCTION books_auth.org_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(
    COALESCE(
      NULLIF(books_auth.jwt() ->> 'org_id', ''),
      NULLIF(current_setting('request.jwt.claim.org_id', true), '')
    ),
    ''
  )::uuid;
$$;

CREATE OR REPLACE FUNCTION books_auth.org_role()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    NULLIF(books_auth.jwt() ->> 'org_role', ''),
    NULLIF(current_setting('request.jwt.claim.org_role', true), ''),
    'member'
  );
$$;

CREATE OR REPLACE FUNCTION books_auth.book_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(
    COALESCE(
      NULLIF(books_auth.jwt() ->> 'book_id', ''),
      NULLIF(current_setting('request.jwt.claim.book_id', true), '')
    ),
    ''
  )::uuid;
$$;

CREATE OR REPLACE FUNCTION books_auth.is_service_role()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT books_auth.role() = 'service_role';
$$;

CREATE OR REPLACE FUNCTION books_auth.set_jwt_claims(claims jsonb)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM set_config('request.jwt.claims', claims::text, true);
  IF claims ? 'role' THEN
    PERFORM set_config('request.jwt.claim.role', claims ->> 'role', true);
  END IF;
  IF claims ? 'sub' THEN
    PERFORM set_config('request.jwt.claim.sub', claims ->> 'sub', true);
  END IF;
  IF claims ? 'org_id' THEN
    PERFORM set_config('request.jwt.claim.org_id', claims ->> 'org_id', true);
  END IF;
  IF claims ? 'org_role' THEN
    PERFORM set_config('request.jwt.claim.org_role', claims ->> 'org_role', true);
  END IF;
  IF claims ? 'book_id' THEN
    PERFORM set_config('request.jwt.claim.book_id', claims ->> 'book_id', true);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION books_auth.effective_org_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    books_auth.org_id(),
    (
      SELECT om.org_id
      FROM org_member om
      WHERE om.user_id = books_auth.uid()
      ORDER BY om.created_at
      LIMIT 1
    )
  );
$$;

CREATE OR REPLACE FUNCTION books_auth.is_org_member(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT books_auth.is_service_role()
    OR (
      books_auth.effective_org_id() IS NOT NULL
      AND p_org_id = books_auth.effective_org_id()
      AND EXISTS (
        SELECT 1 FROM org_member om
        WHERE om.org_id = p_org_id
          AND om.user_id = books_auth.uid()
      )
    );
$$;

CREATE OR REPLACE FUNCTION books_auth.has_book_access(p_book_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT books_auth.is_service_role()
    OR (
      EXISTS (
        SELECT 1
        FROM bookkeeping_account ba
        WHERE ba.id = p_book_id
          AND books_auth.is_org_member(ba.org_id)
          AND (
            books_auth.book_id() IS NULL
            OR ba.id = books_auth.book_id()
          )
      )
    );
$$;

-- Enable RLS on all li-books tables
ALTER TABLE finance_org ENABLE ROW LEVEL SECURITY;
ALTER TABLE org_member ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookkeeping_account ENABLE ROW LEVEL SECURITY;
ALTER TABLE de_tax_category ENABLE ROW LEVEL SECURITY;
ALTER TABLE blob_object ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipt_line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE clarification_thread ENABLE ROW LEVEL SECURITY;
ALTER TABLE clarification_question ENABLE ROW LEVEL SECURITY;
ALTER TABLE clarification_answer ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_session ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_message ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_action_audit ENABLE ROW LEVEL SECURITY;

-- Service role bypass (internal jobs)
CREATE POLICY books_service_finance_org ON finance_org
    FOR ALL USING (books_auth.is_service_role())
    WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_org_member ON org_member
    FOR ALL USING (books_auth.is_service_role())
    WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_bookkeeping ON bookkeeping_account
    FOR ALL USING (books_auth.is_service_role())
    WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_de_tax_category ON de_tax_category
    FOR ALL USING (books_auth.is_service_role())
    WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_blob ON blob_object
    FOR ALL USING (books_auth.is_service_role())
    WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_receipts ON receipts
    FOR ALL USING (books_auth.is_service_role())
    WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_receipt_lines ON receipt_line_items
    FOR ALL USING (books_auth.is_service_role())
    WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_clarification_thread ON clarification_thread
    FOR ALL USING (books_auth.is_service_role())
    WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_clarification_question ON clarification_question
    FOR ALL USING (books_auth.is_service_role())
    WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_clarification_answer ON clarification_answer
    FOR ALL USING (books_auth.is_service_role())
    WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_chat_session ON chat_session
    FOR ALL USING (books_auth.is_service_role())
    WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_chat_message ON chat_message
    FOR ALL USING (books_auth.is_service_role())
    WITH CHECK (books_auth.is_service_role());

CREATE POLICY books_service_finance_audit ON finance_action_audit
    FOR ALL USING (books_auth.is_service_role())
    WITH CHECK (books_auth.is_service_role());

-- Public read of active tax categories (reference data)
CREATE POLICY books_public_read_tax_categories ON de_tax_category
    FOR SELECT USING (active = true);

-- Org-scoped tenant policies (cross-org deny by default)
CREATE POLICY books_tenant_read_org ON finance_org
    FOR SELECT USING (books_auth.is_org_member(id));

CREATE POLICY books_tenant_manage_org ON finance_org
    FOR UPDATE USING (
        books_auth.is_org_member(id)
        AND books_auth.org_role() IN ('owner', 'admin')
    );

CREATE POLICY books_tenant_read_members ON org_member
    FOR SELECT USING (books_auth.is_org_member(org_id));

CREATE POLICY books_tenant_manage_members ON org_member
    FOR ALL USING (
        books_auth.is_org_member(org_id)
        AND books_auth.org_role() IN ('owner', 'admin')
    )
    WITH CHECK (
        books_auth.is_org_member(org_id)
        AND books_auth.org_role() IN ('owner', 'admin')
    );

CREATE POLICY books_tenant_read_books ON bookkeeping_account
    FOR SELECT USING (books_auth.is_org_member(org_id));

CREATE POLICY books_tenant_write_books ON bookkeeping_account
    FOR ALL USING (
        books_auth.is_org_member(org_id)
        AND books_auth.org_role() IN ('owner', 'admin', 'member')
    )
    WITH CHECK (
        books_auth.is_org_member(org_id)
        AND books_auth.org_role() IN ('owner', 'admin', 'member')
    );

CREATE POLICY books_tenant_read_blob ON blob_object
    FOR SELECT USING (books_auth.is_org_member(org_id));

CREATE POLICY books_tenant_write_blob ON blob_object
    FOR ALL USING (
        books_auth.is_org_member(org_id)
        AND (book_id IS NULL OR books_auth.has_book_access(book_id))
    )
    WITH CHECK (
        books_auth.is_org_member(org_id)
        AND (book_id IS NULL OR books_auth.has_book_access(book_id))
    );

-- Receipts: org member + book access (cross-book deny when book_id claim set)
CREATE POLICY books_tenant_read_receipts ON receipts
    FOR SELECT USING (
        books_auth.is_org_member(org_id)
        AND books_auth.has_book_access(book_id)
    );

CREATE POLICY books_tenant_write_receipts ON receipts
    FOR ALL USING (
        books_auth.is_org_member(org_id)
        AND books_auth.has_book_access(book_id)
    )
    WITH CHECK (
        books_auth.is_org_member(org_id)
        AND books_auth.has_book_access(book_id)
    );

CREATE POLICY books_tenant_read_receipt_lines ON receipt_line_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM receipts r
            WHERE r.id = receipt_line_items.receipt_id
              AND books_auth.is_org_member(r.org_id)
              AND books_auth.has_book_access(r.book_id)
        )
    );

CREATE POLICY books_tenant_write_receipt_lines ON receipt_line_items
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM receipts r
            WHERE r.id = receipt_line_items.receipt_id
              AND books_auth.is_org_member(r.org_id)
              AND books_auth.has_book_access(r.book_id)
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM receipts r
            WHERE r.id = receipt_line_items.receipt_id
              AND books_auth.is_org_member(r.org_id)
              AND books_auth.has_book_access(r.book_id)
        )
    );

CREATE POLICY books_tenant_read_clarification ON clarification_thread
    FOR SELECT USING (
        books_auth.is_org_member(org_id)
        AND books_auth.has_book_access(book_id)
    );

CREATE POLICY books_tenant_write_clarification ON clarification_thread
    FOR ALL USING (
        books_auth.is_org_member(org_id)
        AND books_auth.has_book_access(book_id)
    )
    WITH CHECK (
        books_auth.is_org_member(org_id)
        AND books_auth.has_book_access(book_id)
    );

CREATE POLICY books_tenant_read_clarification_q ON clarification_question
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM clarification_thread t
            WHERE t.id = clarification_question.thread_id
              AND books_auth.is_org_member(t.org_id)
              AND books_auth.has_book_access(t.book_id)
        )
    );

CREATE POLICY books_tenant_write_clarification_q ON clarification_question
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM clarification_thread t
            WHERE t.id = clarification_question.thread_id
              AND books_auth.is_org_member(t.org_id)
              AND books_auth.has_book_access(t.book_id)
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM clarification_thread t
            WHERE t.id = clarification_question.thread_id
              AND books_auth.is_org_member(t.org_id)
              AND books_auth.has_book_access(t.book_id)
        )
    );

CREATE POLICY books_tenant_read_clarification_a ON clarification_answer
    FOR SELECT USING (
        EXISTS (
            SELECT 1
            FROM clarification_question q
            JOIN clarification_thread t ON t.id = q.thread_id
            WHERE q.id = clarification_answer.question_id
              AND books_auth.is_org_member(t.org_id)
              AND books_auth.has_book_access(t.book_id)
        )
    );

CREATE POLICY books_tenant_write_clarification_a ON clarification_answer
    FOR ALL USING (
        EXISTS (
            SELECT 1
            FROM clarification_question q
            JOIN clarification_thread t ON t.id = q.thread_id
            WHERE q.id = clarification_answer.question_id
              AND books_auth.is_org_member(t.org_id)
              AND books_auth.has_book_access(t.book_id)
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM clarification_question q
            JOIN clarification_thread t ON t.id = q.thread_id
            WHERE q.id = clarification_answer.question_id
              AND books_auth.is_org_member(t.org_id)
              AND books_auth.has_book_access(t.book_id)
        )
    );

CREATE POLICY books_tenant_read_chat_session ON chat_session
    FOR SELECT USING (
        books_auth.is_org_member(org_id)
        AND books_auth.has_book_access(book_id)
    );

CREATE POLICY books_tenant_write_chat_session ON chat_session
    FOR ALL USING (
        books_auth.is_org_member(org_id)
        AND books_auth.has_book_access(book_id)
    )
    WITH CHECK (
        books_auth.is_org_member(org_id)
        AND books_auth.has_book_access(book_id)
    );

CREATE POLICY books_tenant_read_chat_message ON chat_message
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM chat_session s
            WHERE s.id = chat_message.session_id
              AND books_auth.is_org_member(s.org_id)
              AND books_auth.has_book_access(s.book_id)
        )
    );

CREATE POLICY books_tenant_write_chat_message ON chat_message
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM chat_session s
            WHERE s.id = chat_message.session_id
              AND books_auth.is_org_member(s.org_id)
              AND books_auth.has_book_access(s.book_id)
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM chat_session s
            WHERE s.id = chat_message.session_id
              AND books_auth.is_org_member(s.org_id)
              AND books_auth.has_book_access(s.book_id)
        )
    );

CREATE POLICY books_tenant_read_audit ON finance_action_audit
    FOR SELECT USING (books_auth.is_org_member(org_id));

CREATE POLICY books_tenant_insert_audit ON finance_action_audit
    FOR INSERT WITH CHECK (books_auth.is_org_member(org_id));

INSERT INTO schema_migrations (version, checksum)
VALUES ('008_books_rls', 'pending:computed-at-apply-time')
ON CONFLICT (version) DO NOTHING;

COMMIT;
