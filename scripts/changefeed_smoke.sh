#!/usr/bin/env bash
# Native WAL changefeed smoke (no sqlite).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="${LIDB_BUILD_DIR:-$ROOT/build/smoke}"
mkdir -p "$BUILD_DIR"
cmake -S "$ROOT" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$BUILD_DIR" --target lidb_changefeed_smoke -j >/dev/null

echo "[lidb changefeed] C++ smoke"
"$BUILD_DIR/lidb_changefeed_smoke"

echo "[lidb changefeed] OK"
exit 0
