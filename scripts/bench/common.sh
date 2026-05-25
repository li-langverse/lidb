#!/usr/bin/env bash
# Shared helpers for lidb WP-N4 benchmark harnesses (tier_db_* in li-langverse/benchmarks).
set -euo pipefail

if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  _bench_common_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  _bench_common_dir="$(cd "$(dirname "$0")" && pwd)"
fi
LIDB_BENCH_ROOT="$(cd "$_bench_common_dir/../.." && pwd)"
export LIDB_BENCH_ROOT
export PYTHONPATH="${PYTHONPATH:-}:${LIDB_BENCH_ROOT}"

LIDB_BUILD_DIR="${LIDB_BUILD_DIR:-$LIDB_BENCH_ROOT/build/bench}"
LIDB_EMBED="${LIDB_EMBED:-$LIDB_BUILD_DIR/lidb_embed}"
BENCH_PROFILE="${BENCH_PROFILE:-ci}"
BENCH_HARNESS_JSON="${BENCH_HARNESS_JSON:-}"

lidb_bench_emit() {
  python3 "$LIDB_BENCH_ROOT/scripts/bench/harness_emit.py" "$@"
}

lidb_bench_ensure_embed() {
  if [[ -x "$LIDB_EMBED" ]]; then
    return 0
  fi
  mkdir -p "$LIDB_BUILD_DIR"
  cmake -S "$LIDB_BENCH_ROOT" -B "$LIDB_BUILD_DIR" -DCMAKE_BUILD_TYPE=Release >/dev/null
  cmake --build "$LIDB_BUILD_DIR" --target lidb_embed -j >/dev/null
  if [[ ! -x "$LIDB_EMBED" ]]; then
    echo "lidb bench: failed to build $LIDB_EMBED" >&2
    return 1
  fi
}

lidb_bench_temp_data_dir() {
  mktemp -d "${TMPDIR:-/tmp}/lidb-bench.XXXXXX"
}

lidb_bench_peak_rss_kib() {
  local cmd=("$@")
  if [[ "$(uname -s)" == "Darwin" ]]; then
    local out
    out="$(/usr/bin/time -l "${cmd[@]}" 2>&1)" || true
    echo "$out" | awk '/maximum resident set size/ { print int($1/1024); exit }'
    return 0
  fi
  if command -v /usr/bin/time >/dev/null 2>&1; then
    local out
    out="$(/usr/bin/time -v "${cmd[@]}" 2>&1)" || true
    echo "$out" | awk '/Maximum resident set size/ { print int($1); exit }'
    return 0
  fi
  echo "0"
}

lidb_bench_rss_kib_pid() {
  local pid="$1"
  ps -o rss= -p "$pid" 2>/dev/null | awk '{print int($1)}'
}

lidb_bench_seed_registry() {
  local data_dir="$1"
  local pub pkg ver
  pub="$(python3 -c 'import uuid; print(uuid.uuid4())')"
  pkg="$(python3 -c 'import uuid; print(uuid.uuid4())')"
  ver="$(python3 -c 'import uuid; print(uuid.uuid4())')"
  "$LIDB_EMBED" exec "$data_dir" \
    "INSERT INTO publishers (id, name, public_key) VALUES ('${pub}', 'bench-publisher', '00');" >/dev/null
  "$LIDB_EMBED" exec "$data_dir" \
    "INSERT INTO packages (id, name, description) VALUES ('${pkg}', 'li-bench', 'harness seed');" >/dev/null
  "$LIDB_EMBED" exec "$data_dir" \
    "INSERT INTO package_versions (id, package_id, version, tree_digest, coverage_pct, publisher_id) VALUES ('${ver}', '${pkg}', '0.0.1-bench', 'sha256:bench', '100.0', '${pub}');" >/dev/null
}
