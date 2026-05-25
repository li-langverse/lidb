#!/usr/bin/env bash
# PH-DB-N1: native heap + WAL smoke (no sqlite3).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
echo "[lidb smoke] PH-DB-N1 native heap + WAL"
[[ -f migrations/001_registry.sql ]] || { echo "missing 001_registry.sql" >&2; exit 1; }
BUILD_DIR="${LIDB_BUILD_DIR:-$ROOT/build/smoke}"
mkdir -p "$BUILD_DIR"
cmake -S "$ROOT" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$BUILD_DIR" --target lidb_embed -j >/dev/null
DATA_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lidb-smoke.XXXXXX")"
trap 'rm -rf "$DATA_DIR"' EXIT
EMBED="$BUILD_DIR/lidb_embed"
"$EMBED" open "$DATA_DIR"
"$EMBED" migrate "$DATA_DIR"
PUB_ID="$(python3 -c 'import uuid; print(uuid.uuid4())')"
PKG_ID="$(python3 -c 'import uuid; print(uuid.uuid4())')"
VER_ID="$(python3 -c 'import uuid; print(uuid.uuid4())')"
"$EMBED" exec "$DATA_DIR" "INSERT INTO publishers (id, name, public_key) VALUES ('${PUB_ID}', 'smoke-publisher', '00');"
"$EMBED" exec "$DATA_DIR" "INSERT INTO packages (id, name, description) VALUES ('${PKG_ID}', 'li-smoke', 'PH-DB-N1 smoke');"
"$EMBED" exec "$DATA_DIR" "INSERT INTO package_versions (id, package_id, version, tree_digest, coverage_pct, publisher_id) VALUES ('${VER_ID}', '${PKG_ID}', '0.0.1-smoke', 'sha256:smoke-tree', '100.0', '${PUB_ID}');"
COUNT="$("$EMBED" exec "$DATA_DIR" "SELECT COUNT(*) FROM package_versions")"
[[ "$COUNT" == "1" ]] || { echo "count mismatch: $COUNT" >&2; exit 1; }
NAME="$("$EMBED" exec "$DATA_DIR" "SELECT name FROM packages WHERE id = '${PKG_ID}'")"
[[ "$NAME" == "li-smoke" ]] || { echo "name mismatch: $NAME" >&2; exit 1; }
[[ -s "$DATA_DIR/.lidb/wal/00000001.seg" ]] || { echo "empty WAL" >&2; exit 1; }
echo "[lidb smoke] OK"
