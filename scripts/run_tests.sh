#!/usr/bin/env bash
# PH-DB-2: unit tests + security harness (venv pytest).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PYTHONPATH="$ROOT"

VENV="$ROOT/.venv"
if [[ ! -d "$VENV" ]]; then
  python3 -m venv "$VENV"
fi
# shellcheck disable=SC1091
source "$VENV/bin/activate"
python -m pip install -q pytest

echo "[lidb] pytest"
python -m pytest tests/ -q --tb=short

echo "[lidb] security harness"
bash "$ROOT/tests/security/run_all.sh"
