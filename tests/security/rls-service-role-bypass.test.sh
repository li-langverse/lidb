#!/usr/bin/env bash
set -euo pipefail
if [[ "${LIDB_RLS_HARNESS:-}" != "1" ]]; then
  echo "SKIP rls-service-role-bypass: set LIDB_RLS_HARNESS=1 when RLS harness is wired"
  export LAST_RESULT=skip; exit 0
fi
echo "FAIL rls-service-role-bypass: harness not wired"
export LAST_RESULT=fail; exit 1
