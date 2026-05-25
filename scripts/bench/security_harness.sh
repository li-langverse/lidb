#!/usr/bin/env bash
# tier_db_security — injection_blocked + rls_bypass_blocked (benchmarks WP-N4).
set -euo pipefail

# shellcheck source=common.sh
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

export LIDB_ENGINE_READY=1

lidb_bench_ensure_embed
export LIDB_EMBED="$LIDB_EMBED"
PYTHONPATH="$LIDB_BENCH_ROOT" python3 - <<'PY'
from liorm import embed_engine

embed_engine.reset_session_for_tests()
if embed_engine.engine_ready():
    embed_engine.seed_test_fixtures()
PY

injection_pass=0
injection_fail=0
injection_skip=0

for probe in \
  cve-cwe-89-sql-injection-via-param-concat \
  cve-cwe-89-second-order-sql-injection-stored-value \
  cve-cwe-89-identifier-injection-dynamic-table \
  cve-raw-sql-capability-audit-escalation; do
  if PYTHONPATH="$LIDB_BENCH_ROOT" python3 "$LIDB_BENCH_ROOT/scripts/security_probe.py" "$probe" >/dev/null 2>&1; then
    injection_pass=$((injection_pass + 1))
  else
    injection_fail=$((injection_fail + 1))
  fi
done

injection_total=$((injection_pass + injection_fail))
if [[ "$injection_total" -eq 0 ]]; then
  injection_rate=""
  injection_stat="unknown"
  injection_note="no CVE probes executed"
else
  injection_rate="$(python3 -c "print(${injection_pass}/${injection_total})")"
  if [[ "$injection_fail" -eq 0 ]]; then
    injection_stat="green"
    injection_note="CVE probes pass=${injection_pass} fail=${injection_fail} skip=${injection_skip}"
  else
    injection_stat="red"
    injection_note="CVE probes pass=${injection_pass} fail=${injection_fail} skip=${injection_skip}"
  fi
fi

rls_pass=0
rls_fail=0
rls_skip=0
if [[ "${LIDB_RLS_HARNESS:-}" != "1" ]]; then
  for _script in "$LIDB_BENCH_ROOT"/tests/security/rls-*.test.sh; do
    [[ -f "$_script" ]] || continue
    rls_skip=$((rls_skip + 1))
  done
else
  for script in "$LIDB_BENCH_ROOT"/tests/security/rls-*.test.sh; do
    [[ -f "$script" ]] || continue
    if out="$(bash "$script" 2>&1)"; then
      if echo "$out" | grep -q "^SKIP "; then
        rls_skip=$((rls_skip + 1))
      else
        rls_pass=$((rls_pass + 1))
      fi
    else
      rls_fail=$((rls_fail + 1))
    fi
  done
fi

rls_total=$((rls_pass + rls_fail))
if [[ "$rls_total" -eq 0 ]]; then
  rls_rate=""
  rls_stat="unknown"
  if [[ "$rls_skip" -gt 0 ]]; then
    rls_note="RLS probes skipped=${rls_skip} (set LIDB_RLS_HARNESS=1 when engine RLS harness is wired)"
  else
    rls_note="no RLS probes found"
  fi
elif [[ "$rls_fail" -eq 0 ]]; then
  rls_rate="$(python3 -c "print(${rls_pass}/${rls_total})")"
  rls_stat="green"
  rls_note="RLS probes pass=${rls_pass} fail=${rls_fail} skip=${rls_skip}"
else
  rls_rate="$(python3 -c "print(${rls_pass}/${rls_total})")"
  rls_stat="red"
  rls_note="RLS probes pass=${rls_pass} fail=${rls_fail} skip=${rls_skip}"
fi

export INJ_RATE="${injection_rate}"
export INJ_STAT="${injection_stat}"
export INJ_NOTE="${injection_note}"
export RLS_RATE="${rls_rate}"
export RLS_STAT="${rls_stat}"
export RLS_NOTE="${rls_note}"

scenarios_json="$(python3 - <<'PY'
import json, os

def row(sid, rate, stat, note, metric="pass_rate", unit="ratio"):
    val = None if rate == "" else float(rate)
    return {
        "id": sid,
        "metric": metric,
        "unit": unit,
        "lower_is_better": False,
        "threshold_pass_rate": 1.0,
        "pass_rate": val,
        "status": stat,
        "lidb": val,
        "notes": note,
        "ph_ids": ["WP-N4", "PH-DB-SEC"],
    }

rows = [
    row("injection_blocked", os.environ["INJ_RATE"], os.environ["INJ_STAT"], os.environ["INJ_NOTE"]),
    row("rls_bypass_blocked", os.environ["RLS_RATE"], os.environ["RLS_STAT"], os.environ["RLS_NOTE"]),
]
print(json.dumps(rows))
PY
)"

lidb_bench_emit --tier tier_db_security --profile "$BENCH_PROFILE" "$scenarios_json"
