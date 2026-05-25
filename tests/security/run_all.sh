#!/usr/bin/env bash
# PH-DB-2: security regression harness — stubs skip until liorm engine exists.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FAIL=0
SKIP=0
PASS=0

if [[ "${LIDB_ENGINE_READY:-}" != "1" ]]; then
  echo "lidb security harness: engine not ready (LIDB_ENGINE_READY!=1); running stub suite"
fi

for t in "$ROOT"/tests/security/cve-*.sh; do
  [[ -f "$t" ]] || continue
  name="$(basename "$t" .sh)"
  if bash "$t"; then
    case "${LAST_RESULT:-}" in
      skip) SKIP=$((SKIP + 1)); echo "SKIP $name" ;;
      pass) PASS=$((PASS + 1)); echo "PASS $name" ;;
      *) SKIP=$((SKIP + 1)); echo "SKIP $name" ;;
    esac
  else
    echo "FAIL $name"
    FAIL=1
  fi
done

echo "security harness: pass=$PASS skip=$SKIP fail=$FAIL"
if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
exit 0
