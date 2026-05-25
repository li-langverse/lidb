#!/usr/bin/env bash
# PH-DB-1 engine smoke: embedded open → migrate → INSERT/SELECT (sqlite3 smoke backend).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[lidb smoke] PH-DB-1 engine skeleton"

for f in migrations/001_registry.sql migrations/001_registry_embedded.sql; do
  if [[ ! -f "$f" ]]; then
    echo "missing $f" >&2
    exit 1
  fi
done

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 required for PH-DB-1 smoke backend (Postgres engine TODO PH-DB-2)" >&2
  exit 1
fi

BUILD_DIR="${LIDB_BUILD_DIR:-$ROOT/build/smoke}"
mkdir -p "$BUILD_DIR"
cmake -S "$ROOT" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$BUILD_DIR" --target lidb_embed -j >/dev/null

DATA_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lidb-smoke.XXXXXX")"
cleanup() { rm -rf "$DATA_DIR"; }
trap cleanup EXIT

EMBED="$BUILD_DIR/lidb_embed"

echo "[lidb smoke] open $DATA_DIR"
"$EMBED" open "$DATA_DIR"

echo "[lidb smoke] migrate (001_registry_embedded.sql via embedded API)"
"$EMBED" migrate "$DATA_DIR"

PUB_ID="$(python3 -c 'import uuid; print(uuid.uuid4())')"
PKG_ID="$(python3 -c 'import uuid; print(uuid.uuid4())')"
VER_ID="$(python3 -c 'import uuid; print(uuid.uuid4())')"
PUB_KEY="$(python3 -c 'print("00"*32)')"

echo "[lidb smoke] INSERT publishers + packages + package_versions"
"$EMBED" exec "$DATA_DIR" \
  "INSERT INTO publishers (id, name, public_key) VALUES ('${PUB_ID}', 'smoke-publisher', x'${PUB_KEY}');"
"$EMBED" exec "$DATA_DIR" \
  "INSERT INTO packages (id, name, description) VALUES ('${PKG_ID}', 'li-smoke', 'PH-DB-1 smoke');"
"$EMBED" exec "$DATA_DIR" \
  "INSERT INTO package_versions (id, package_id, version, tree_digest, coverage_pct, publisher_id) VALUES ('${VER_ID}', '${PKG_ID}', '0.0.1-smoke', 'sha256:smoke-tree', 100.0, '${PUB_ID}');"

COUNT="$("$EMBED" exec "$DATA_DIR" "SELECT COUNT(*) FROM package_versions;")"
if [[ "$COUNT" != "1" ]]; then
  echo "expected 1 package_version row, got: $COUNT" >&2
  exit 1
fi

NAME="$("$EMBED" exec "$DATA_DIR" "SELECT name FROM packages WHERE id = '${PKG_ID}';")"
if [[ "$NAME" != "li-smoke" ]]; then
  echo "SELECT name mismatch: $NAME" >&2
  exit 1
fi

if [[ -f src/storage_smoke.cpp ]]; then
  echo "[lidb smoke] legacy placeholder still present: src/storage_smoke.cpp"
fi

echo "[lidb smoke] OK (embedded + migrate + INSERT/SELECT)"
exit 0
