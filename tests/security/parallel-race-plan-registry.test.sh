#!/usr/bin/env bash
# tier_db_security: concurrent plan register/execute must not corrupt registry.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export LIDB_EMBED="${LIDB_EMBED:-$ROOT/build/smoke/lidb_embed}"
export LIDB_DATA_DIR="${LIDB_DATA_DIR:-/tmp/lidb-parallel-race-$$}"
if [[ "${LIDB_ENGINE_READY:-}" != "1" ]]; then
  echo "SKIP parallel-race-plan-registry: set LIDB_ENGINE_READY=1"
  export LAST_RESULT=skip; exit 0
fi
if PYTHONPATH="$ROOT" python3 "$ROOT/scripts/audit_probe.py" parallel-race-plan-registry; then
  export LAST_RESULT=pass; exit 0
fi
export LAST_RESULT=fail; exit 1
