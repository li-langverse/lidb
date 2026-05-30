#!/usr/bin/env bash
# Build lidb_embed when missing (CI audit job + local pytest).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${LIDB_BUILD_DIR:-$ROOT/build/smoke}"
EMBED="${LIDB_EMBED:-$BUILD_DIR/lidb_embed}"
if [[ -x "$EMBED" ]]; then
  export LIDB_EMBED="$EMBED"
  export LIDB_BUILD_DIR="$BUILD_DIR"
  exit 0
fi
mkdir -p "$BUILD_DIR"
cmake -S "$ROOT" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$BUILD_DIR" --target lidb_embed -j >/dev/null
export LIDB_EMBED="$EMBED"
export LIDB_BUILD_DIR="$BUILD_DIR"
