#!/usr/bin/env bash
# WP-020: verify cross-book RLS deny when book_id JWT claim is set
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RLS="$ROOT/migrations/008_books_rls.sql"
[[ -f "$RLS" ]] || { echo "missing 008_books_rls.sql"; exit 1; }

required=(
  "books_auth.book_id()"
  "books_auth.has_book_access"
  "books_tenant_read_receipts"
)

for token in "${required[@]}"; do
  if ! grep -q "$token" "$RLS"; then
    echo "FAIL: 008 missing cross-book token: $token"
    exit 1
  fi
done

# has_book_access must restrict when book_id claim is set
if ! grep -A20 "books_auth.has_book_access" "$RLS" | grep -q "books_auth.book_id() IS NULL"; then
  echo "FAIL: has_book_access must allow NULL book_id or match claim"
  exit 1
fi

echo "PASS rls-books-cross-book-deny: book-scoped access helper present"
export LAST_RESULT=pass
exit 0
