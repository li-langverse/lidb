#!/usr/bin/env bash
# WP-N5: aggregate security harness, audit pytest, and unit tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
source "$ROOT/scripts/ensure_embed.sh"
export PYTHONPATH="$ROOT"
export LIDB_ENGINE_READY="${LIDB_ENGINE_READY:-1}"
export LIDB_SKIP_VALGRIND="${LIDB_SKIP_VALGRIND:-1}"

VENV="$ROOT/.venv"
if [[ ! -d "$VENV" ]]; then
  python3 -m venv "$VENV"
fi
# shellcheck disable=SC1091
source "$VENV/bin/activate"
python -m pip install -q pytest

echo "[lidb] pytest (unit + audit; native embed probe in CI native-smoke job)"
python -m pytest tests/ -q --tb=short --ignore=tests/test_embed_engine.py

echo "[lidb] security harness"
bash "$ROOT/tests/security/run_all.sh"

echo "[lidb] audit suite OK"
