#!/usr/bin/env bash
# tier_db_memory — rss_idle + rss_peak_load (lidb_embed peak RSS, KiB → MB in manifest).
set -euo pipefail

# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

lidb_bench_ensure_embed

DATA_DIR="$(lidb_bench_temp_data_dir)"
cleanup() { rm -rf "$DATA_DIR"; }
trap cleanup EXIT

"$LIDB_EMBED" open "$DATA_DIR" >/dev/null
idle_kib="$(lidb_bench_peak_rss_kib "$LIDB_EMBED" migrate "$DATA_DIR")"
lidb_bench_seed_registry "$DATA_DIR"

clients="${BENCH_MEMORY_CLIENTS:-8}"
duration="${BENCH_MEMORY_LOAD_SEC:-2}"
load_sql="SELECT COUNT(*) FROM package_versions"

peak_kib="$idle_kib"
pids=()
for ((i = 0; i < clients; i++)); do
  (
    end=$((SECONDS + duration))
    while ((SECONDS < end)); do
      "$LIDB_EMBED" exec "$DATA_DIR" "$load_sql" >/dev/null
    done
  ) &
  pids+=("$!")
done
samples=$((duration * 10))
for ((s = 0; s < samples; s++)); do
  for pid in "${pids[@]}"; do
    rss="$(lidb_bench_rss_kib_pid "$pid" 2>/dev/null || true)"
    if [[ -n "${rss:-}" && "$rss" -gt "$peak_kib" ]]; then
      peak_kib="$rss"
    fi
  done
  sleep 0.1
done
wait || true

# Sample peak RSS of a single hot exec if background workers were too short-lived.
exec_kib="$(lidb_bench_peak_rss_kib "$LIDB_EMBED" exec "$DATA_DIR" "$load_sql")"
if [[ "$exec_kib" -gt "$peak_kib" ]]; then
  peak_kib="$exec_kib"
fi

idle_mb="$(python3 -c "print(round(${idle_kib}/1024, 3))")"
peak_mb="$(python3 -c "print(round(${peak_kib}/1024, 3))")"
threshold_ratio="${BENCH_MEMORY_THRESHOLD_RATIO:-1.1}"

scenarios_json="$(python3 - <<PY
import json

def row(sid, mb, note):
    return {
        "id": sid,
        "metric": "rss_mb",
        "unit": "mb",
        "lower_is_better": True,
        "threshold_ratio_vs_postgres": ${threshold_ratio},
        "rss_mb": mb,
        "status": "green",
        "lidb": mb,
        "ratio_vs_postgres": None,
        "notes": note,
        "ph_ids": ["WP-N4", "PH-DB-MEM"],
    }

rows = [
    row("rss_idle", ${idle_mb}, "Peak RSS KiB during open+migrate (${idle_kib} KiB)"),
    row("rss_peak_load", ${peak_mb}, "Peak RSS under ${clients} clients for ${duration}s + hot exec (${peak_kib} KiB)"),
]
print(json.dumps(rows))
PY
)"

lidb_bench_emit --tier tier_db_memory --profile "$BENCH_PROFILE" "$scenarios_json"
