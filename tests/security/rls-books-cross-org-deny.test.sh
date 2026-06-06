#!/usr/bin/env bash
# WP-020: verify cross-org RLS deny policies exist in 008_books_rls.sql
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RLS="$ROOT/migrations/008_books_rls.sql"
[[ -f "$RLS" ]] || { echo "missing 008_books_rls.sql"; exit 1; }

required=(
  "books_auth.is_org_member"
  "books_auth.has_book_access"
  "books_tenant_read_receipts"
  "ENABLE ROW LEVEL SECURITY"
)

for token in "${required[@]}"; do
  if ! grep -q "$token" "$RLS"; then
    echo "FAIL: 008 missing RLS token: $token"
    exit 1
  fi
done

# Cross-org deny: tenant policies must scope by org_id via is_org_member
if ! grep -q "books_auth.is_org_member(org_id)" "$RLS"; then
  echo "FAIL: receipts not org-scoped for cross-org deny"
  exit 1
fi

echo "PASS rls-books-cross-org-deny: org-scoped tenant policies present"
export LAST_RESULT=pass
exit 0
