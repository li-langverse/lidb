#!/usr/bin/env bash
# tier_db_security: concurrent plan register/execute must not corrupt registry.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ "${LIDB_ENGINE_READY:-}" != "1" ]]; then
  echo "SKIP parallel-race-plan-registry: set LIDB_ENGINE_READY=1"
  export LAST_RESULT=skip; exit 0
fi
if timeout "${LIDB_SECURITY_PROBE_TIMEOUT_SEC:-120}" \
  env PYTHONPATH="$ROOT" python3 "$ROOT/scripts/audit_probe.py" parallel-race-plan-registry; then
  export LAST_RESULT=pass; exit 0
fi
export LAST_RESULT=fail; exit 1
