#!/usr/bin/env bash
set -euo pipefail
if [[ "${LIDB_ENGINE_READY:-}" != "1" ]]; then
  echo "SKIP rls-jwt-guc-session: lidb engine not ready"
  export LAST_RESULT=skip; exit 0
fi
echo "FAIL rls-jwt-guc-session: harness not wired"
export LAST_RESULT=fail; exit 1
