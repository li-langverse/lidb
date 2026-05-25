#!/usr/bin/env bash
set -euo pipefail
if [[ "${LIDB_RLS_HARNESS:-}" != "1" ]]; then
  echo "SKIP rls-package-version-tenant-isolation: set LIDB_RLS_HARNESS=1 when RLS harness is wired"
  export LAST_RESULT=skip; exit 0
fi
echo "FAIL rls-package-version-tenant-isolation: harness not wired"
export LAST_RESULT=fail; exit 1
