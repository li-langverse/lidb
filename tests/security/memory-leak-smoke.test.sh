#!/usr/bin/env bash
# tier_db_security: optional valgrind smoke on lidb_embed open (SKIP when unavailable).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="${LIDB_EMBED_BIN:-$ROOT/build/smoke/lidb_embed}"
if [[ "${LIDB_SKIP_VALGRIND:-}" == "1" ]]; then
  echo "SKIP memory-leak-smoke: LIDB_SKIP_VALGRIND=1"
  export LAST_RESULT=skip; exit 0
fi
if ! command -v valgrind >/dev/null 2>&1; then
  echo "SKIP memory-leak-smoke: valgrind not installed"
  export LAST_RESULT=skip; exit 0
fi
if [[ ! -x "$BIN" ]]; then
  echo "SKIP memory-leak-smoke: missing executable $BIN"
  export LAST_RESULT=skip; exit 0
fi
DATA_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lidb-valgrind.XXXXXX")"
cleanup() { rm -rf "$DATA_DIR"; }
trap cleanup EXIT
if valgrind --error-exitcode=42 --leak-check=summary --quiet "$BIN" open "$DATA_DIR" 2>&1; then
  echo "PASS memory-leak-smoke"
  export LAST_RESULT=pass; exit 0
fi
echo "FAIL memory-leak-smoke: valgrind reported errors"
export LAST_RESULT=fail; exit 1
