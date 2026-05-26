#!/usr/bin/env bash
# tier_db_registry OLTP — invoke benchmarks harness with lidb embed built (PH-DB-5).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

BENCH_ROOT="${BENCHMARKS_ROOT:-}"
if [[ -z "$BENCH_ROOT" ]]; then
  for candidate in \
    "$LIDB_BENCH_ROOT/../benchmarks" \
    "$LIDB_BENCH_ROOT/../../benchmarks" \
    "$(cd "$LIDB_BENCH_ROOT/.." && pwd)/benchmarks"; do
    if [[ -f "$candidate/benchmarks/tier_db_registry/suite.toml" ]]; then
      BENCH_ROOT="$candidate"
      break
    fi
  done
fi

if [[ -z "$BENCH_ROOT" || ! -f "$BENCH_ROOT/benchmarks/tier_db_registry/suite.toml" ]]; then
  echo "registry_oltp: benchmarks repo not found (set BENCHMARKS_ROOT)" >&2
  exit 1
fi

lidb_bench_ensure_embed
export LIDB_ROOT="${LIDB_ROOT:-$LIDB_BENCH_ROOT}"
export LIDB_EMBED="$LIDB_EMBED"
export BENCH_DB_REGISTRY_RUN_HARNESS=1
export BENCH_HARNESS_JSON="${BENCH_HARNESS_JSON:-$BENCH_ROOT/data/latest/tier-db-registry-harness.json}"

exec bash "$BENCH_ROOT/scripts/run-db-registry-bench.sh"
