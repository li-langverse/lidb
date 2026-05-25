#!/usr/bin/env bash
# PH-DB-3.1: fail if production paths still reference sqlite3 or live *_embedded.sql migrations.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if rg -n 'import sqlite3|sqlite3\.' \
  --glob '!migrations/archive/**' \
  --glob '!docs/**' \
  --glob '!*.md' \
  --glob '!scripts/check_no_sqlite.sh' \
  --glob '!tests/test_native_sql.py' \
  . >/tmp/lidb-sqlite-hits.txt 2>/dev/null; then
  if [[ -s /tmp/lidb-sqlite-hits.txt ]]; then
    echo "sqlite3 references remain (PH-DB-3.1):" >&2
    cat /tmp/lidb-sqlite-hits.txt >&2
    exit 1
  fi
fi

for path in migrations/*_embedded.sql; do
  [[ -e "$path" ]] || continue
  echo "active embedded sql migration must be archived: $path" >&2
  exit 1
done

echo "check_no_sqlite: ok"
