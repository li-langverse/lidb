#!/usr/bin/env bash
# Emit tier_db */results/latest.csv under benchmarks (WP-DB measured / blocked honesty).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
export LIDB_BENCH_ROOT="$(cd "$DIR/../.." && pwd)"
export PYTHONPATH="${PYTHONPATH:-}:${DIR}"
cd "$DIR"
python3 emit_csv.py
