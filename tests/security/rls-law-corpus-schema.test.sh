#!/usr/bin/env bash
# WP-030: verify law corpus tables and refresh run tracking
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MIG="$ROOT/migrations/009_law_corpus.sql"
[[ -f "$MIG" ]] || { echo "missing 009_law_corpus.sql"; exit 1; }

for token in law_source law_document law_chunk law_embedding law_refresh_run; do
  grep -q "CREATE TABLE $token" "$MIG" || { echo "FAIL: missing $token"; exit 1; }
done

grep -q "law_refresh_run" "$MIG" || { echo "FAIL: missing refresh run"; exit 1; }
echo "PASS rls-law-corpus-schema: tables present"
export LAST_RESULT=pass
exit 0
