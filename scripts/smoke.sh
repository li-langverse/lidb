#!/usr/bin/env bash
# PH-DB-1 storage smoke — exits 0 until real engine lands (PH-DB-2).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[lidb smoke] PH-DB-1 scaffold"
echo "[TODO PH-DB-2] open data dir, apply migrations/001_registry.sql"
echo "[TODO PH-DB-2] WAL segment allocate + heap page smoke"
echo "[TODO PH-DB-7] RSS check against docs/footprint.md (256MB registry-min)"

if [[ ! -f migrations/001_registry.sql ]]; then
  echo "missing migrations/001_registry.sql" >&2
  exit 1
fi

if [[ -f src/storage_smoke.cpp ]]; then
  echo "[lidb smoke] C++ placeholder present: src/storage_smoke.cpp"
fi

echo "[lidb smoke] OK (placeholder)"
exit 0
