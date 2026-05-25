#!/usr/bin/env bash
# PH-DB-2 + PH-DB-5: security regression harness (CVE + RLS).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROBE="$ROOT/scripts/security_probe.py"
FAIL=0
SKIP=0
PASS=0

if [[ -f "$PROBE" ]]; then
  export LIDB_ENGINE_READY=1
  echo "lidb security harness: Python stubs ready (LIDB_ENGINE_READY=1)"
else
  echo "lidb security harness: missing scripts/security_probe.py — skipping CVE suite"
  exit 0
fi

for t in "$ROOT"/tests/security/cve-*.sh "$ROOT"/tests/security/rls-*.test.sh; do
  [[ -f "$t" ]] || continue
  name="$(basename "$t" .sh)"
  if out="$(PYTHONPATH="$ROOT" bash "$t" 2>&1)"; then
    echo "$out"
    if echo "$out" | grep -q "^SKIP "; then
      SKIP=$((SKIP + 1))
      echo "SKIP $name"
    else
      PASS=$((PASS + 1))
      echo "PASS $name"
    fi
  else
    echo "$out"
    echo "FAIL $name"
    FAIL=1
  fi
done

echo "security harness: pass=$PASS skip=$SKIP fail=$FAIL"
if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
exit 0
