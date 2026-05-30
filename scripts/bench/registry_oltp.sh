#!/usr/bin/env bash
# PH-DB-5: lidb vs Postgres registry OLTP bench (tier_db_registry).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BENCH_ROOT="${BENCH_ROOT:-$ROOT/../benchmarks}"
PROFILE="${BENCH_PROFILE:-ci}"
JSON_OUT="${BENCH_HARNESS_JSON:-$BENCH_ROOT/data/latest/tier-db-registry-harness.json}"
COMPARE_PY="$ROOT/scripts/bench/registry_oltp_compare.py"
MANIFEST="$BENCH_ROOT/scripts/ingest/write-tier-db-registry-manifest.py"

if [[ ! -f "$COMPARE_PY" ]]; then
  echo "registry_oltp: missing $COMPARE_PY" >&2
  exit 1
fi

# Ensure lidb_embed exists
if [[ ! -x "${LIDB_EMBED:-}" && ! -f "$ROOT/build/smoke/lidb_embed" ]]; then
  echo "registry_oltp: building lidb_embed..."
  cmake -S "$ROOT" -B "$ROOT/build/smoke" -DCMAKE_BUILD_TYPE=Release
  cmake --build "$ROOT/build/smoke" --target lidb_embed -j"$(nproc 2>/dev/null || echo 2)"
fi

python3 "$COMPARE_PY" --profile "$PROFILE" --json-out "$JSON_OUT"

if [[ -f "$MANIFEST" ]]; then
  python3 "$MANIFEST" --profile "$PROFILE" --from-compare "$JSON_OUT"
else
  echo "registry_oltp: manifest writer not found at $MANIFEST (harness JSON only)"
fi
