#!/usr/bin/env bash
# PH-DB-4: registry OLTP smoke (read + publish via RegistryOltp).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PYTHONPATH="$ROOT${PYTHONPATH:+:$PYTHONPATH}"
python3 - <<'PY'
import sys
import uuid

from liorm.embed_engine import seed_test_fixtures
from registry import RegistryOltp

seed_test_fixtures()
svc = RegistryOltp()
if not svc.ready():
    print("registry smoke: embed not ready", file=sys.stderr)
    sys.exit(1)
rec = svc.get_package_version("li-pytest", "0.0.1-test")
if rec is None:
    print("registry smoke: missing seeded version", file=sys.stderr)
    sys.exit(1)
suffix = uuid.uuid4().hex[:8]
pub = svc.publish_package_version(
    publisher_name=f"smoke-pub-{suffix}",
    publisher_public_key=b"\x00" * 32,
    package_name=f"li-smoke-reg-{suffix}",
    version="0.0.1",
    tree_digest=f"sha256:smoke-{suffix}",
    coverage_pct=100.0,
)
if pub.name != f"li-smoke-reg-{suffix}":
    print("registry smoke: publish name mismatch", file=sys.stderr)
    sys.exit(1)
print("[registry smoke] OK")
PY
