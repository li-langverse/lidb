#!/usr/bin/env bash
# tier_db_audit: hash-chained append-only audit log integrity.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ "${LIDB_ENGINE_READY:-}" != "1" ]]; then
  echo "SKIP audit-log-append-only: set LIDB_ENGINE_READY=1"
  export LAST_RESULT=skip; exit 0
fi
if PYTHONPATH="$ROOT" python3 "$ROOT/scripts/audit_probe.py" audit-log-append-only; then
  export LAST_RESULT=pass; exit 0
fi
export LAST_RESULT=fail; exit 1
