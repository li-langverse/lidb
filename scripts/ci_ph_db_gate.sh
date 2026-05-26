#!/usr/bin/env bash
# WP-G: cross-repo PH-DB CI gate — native smoke + key pytest subset (not full security suite).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PYTHONPATH="$ROOT"

PYTEST_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --pytest-only) PYTEST_ONLY=true ;;
  esac
done

if [[ "$PYTEST_ONLY" != true ]]; then
  bash "$ROOT/scripts/smoke.sh"
fi

VENV="$ROOT/.venv"
if [[ ! -d "$VENV" ]]; then
  python3 -m venv "$VENV"
fi
# shellcheck disable=SC1091
source "$VENV/bin/activate"
python -m pip install -q pytest

echo "[lidb ph-db gate] key pytest subset"
python -m pytest \
  tests/test_embed_engine.py \
  tests/test_execute.py \
  tests/test_native_sql.py \
  tests/test_capabilities.py \
  -q --tb=short

echo "[lidb ph-db gate] OK"
