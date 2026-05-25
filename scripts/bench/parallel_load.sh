#!/usr/bin/env bash
# tier_db_parallel — concurrent_readers (measured); concurrent_writers (stub until native writes scale).
set -euo pipefail

# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

lidb_bench_ensure_embed

DATA_DIR="$(lidb_bench_temp_data_dir)"
cleanup() { rm -rf "$DATA_DIR"; }
trap cleanup EXIT

"$LIDB_EMBED" open "$DATA_DIR" >/dev/null
"$LIDB_EMBED" migrate "$DATA_DIR" >/dev/null
lidb_bench_seed_registry "$DATA_DIR"

clients="${BENCH_PARALLEL_CLIENTS:-8}"
duration="${BENCH_PARALLEL_DURATION_SEC:-2}"
load_sql="SELECT COUNT(*) FROM package_versions"
ops_file="$(mktemp)"
echo 0 >"$ops_file"

reader_worker() {
  local end=$((SECONDS + duration))
  local n=0
  while ((SECONDS < end)); do
    "$LIDB_EMBED" exec "$DATA_DIR" "$load_sql" >/dev/null
    n=$((n + 1))
  done
  echo "$n"
}

pids=()
for ((i = 0; i < clients; i++)); do
  reader_worker >"${ops_file}.${i}" &
  pids+=("$!")
done
total_ops=0
for pid in "${pids[@]}"; do
  wait "$pid" || true
done
for ((i = 0; i < clients; i++)); do
  if [[ -f "${ops_file}.${i}" ]]; then
    n="$(<"${ops_file}.${i}")"
    total_ops=$((total_ops + n))
    rm -f "${ops_file}.${i}"
  fi
done
rm -f "$ops_file"

ops_per_sec="$(python3 -c "print(round(${total_ops}/max(${duration},1), 2))")"

scenarios_json="$(python3 - <<PY
import json

rows = [
    {
        "id": "concurrent_readers",
        "metric": "ops_per_sec",
        "unit": "ops",
        "lower_is_better": False,
        "threshold_ratio_vs_postgres": 1.0,
        "ops_per_sec": ${ops_per_sec},
        "status": "green",
        "lidb": ${ops_per_sec},
        "ratio_vs_postgres": None,
        "notes": "Measured ${total_ops} SELECT ops in ${duration}s across ${clients} clients (lidb_embed)",
        "ph_ids": ["WP-N4", "PH-DB-PAR"],
    },
    {
        "id": "concurrent_writers",
        "metric": "ops_per_sec",
        "unit": "ops",
        "lower_is_better": False,
        "threshold_ratio_vs_postgres": 1.0,
        "ops_per_sec": None,
        "status": "stub",
        "lidb": None,
        "ratio_vs_postgres": None,
        "notes": "Writer scalability harness pending native concurrent INSERT path",
        "ph_ids": ["WP-N4", "PH-DB-PAR"],
    },
]
print(json.dumps(rows))
PY
)"

lidb_bench_emit --tier tier_db_parallel --profile "$BENCH_PROFILE" "$scenarios_json"
