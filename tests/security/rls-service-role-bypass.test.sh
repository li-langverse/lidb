#!/usr/bin/env bash
set -euo pipefail
if [[ "${LIDB_ENGINE_READY:-}" != "1" ]]; then
  echo "SKIP rls-service-role-bypass: lidb engine not ready"
  export LAST_RESULT=skip; exit 0
fi
echo "FAIL rls-service-role-bypass: harness not wired"
export LAST_RESULT=fail; exit 1
