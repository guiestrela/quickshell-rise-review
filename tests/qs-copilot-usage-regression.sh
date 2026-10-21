#!/usr/bin/env bash
# Regression coverage for the GitHub Copilot usage collector and the QML parse that
# feeds the AI usage pill. Copilot meters a MONTHLY premium-request allowance rather
# than a 5h/7d window, so these tests pin the window length, the unlimited case, the
# staleness gate and the 0..1 utilization clamp.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COPILOT_USAGE="${COPILOT_USAGE:-$REPO_ROOT/scripts/copilot-usage}"
WORK="$(mktemp -d /tmp/qs-copilot-usage-test.XXXXXX)"

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'ok: %s\n' "$*"; }

command -v python3 >/dev/null 2>&1 || fail "python3 is required"

# ── 1. the collector maps the premium_interactions snapshot onto the monthly window ──
run_usage() {
  local snapshot="$1" out="$2"
  python3 - "$COPILOT_USAGE" "$snapshot" "$out" <<'PY'
import importlib.machinery, importlib.util, json, sys
from pathlib import Path

spec_path, snapshot_path, out_path = sys.argv[1:4]
spec = importlib.util.spec_from_loader("copilot_usage",
                                       importlib.machinery.SourceFileLoader("copilot_usage", spec_path))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

snapshot = json.loads(Path(snapshot_path).read_text())
mod.fetch = lambda _token: snapshot
mod.CACHE_FILE = Path(out_path)
mod.main()
PY
}

snapshot_with() {
  python3 - "$@" <<'PY'
import json, sys
used, entitlement, unlimited, reset = (int(sys.argv[1]), int(sys.argv[2]),
                                      sys.argv[3] == "true", sys.argv[4])
print(json.dumps({
    "copilot_plan": "individual",
    "access_type_sku": "free_educational_quota",
    "quota_reset_date_utc": reset,
    "quota_snapshots": {
        "premium_interactions": {
            "credits_used": used, "entitlement": entitlement,
            "unlimited": unlimited, "has_quota": not unlimited,
            "percent_remaining": 0.0,
        },
        "chat": {"unlimited": True, "percent_remaining": 100.0},
    },
}))
PY
}

assert_cache() {
  python3 - "$1" "$2" "$3" "$4" "$5" "$6" <<'PY'
import json, sys
path, pct, label, used, ent, status = sys.argv[1:7]
d = json.loads(open(path).read())
win = d["windows"][0]
checks = [
    (win["minutes"] == 43200, f"monthly window is 43200 min, got {win['minutes']}"),
    (win["label"] == label, f"window label is {label}, got {win['label']}"),
    (abs(win["utilization"] - float(pct)) < 1e-9, f"utilization is {pct}, got {win['utilization']}"),
    (d["_credits_used"] == int(used), f"credits_used {used}, got {d['_credits_used']}"),
    (d["_credits_entitlement"] == int(ent), f"entitlement {ent}, got {d['_credits_entitlement']}"),
    (d["status"] == status, f"status {status}, got {d['status']}"),
    (d["schemaVersion"] == 3, "cache must stay on schemaVersion 3"),
]
for ok, msg in checks:
    if not ok:
        print(f"FAIL: {msg}", file=sys.stderr)
        raise SystemExit(1)
PY
}

# fully consumed → 100%, rejected, exhaustion flagged
snapshot_with 200 200 false "2026-10-01T00:00:00.000Z" > "$WORK/full.json"
run_usage "$WORK/full.json" "$WORK/full-cache.json"
assert_cache "$WORK/full-cache.json" 1.0 30d 200 200 rejected
pass "exhausted allowance reports 100% / rejected"

# half used → 50%, allowed
snapshot_with 100 200 false "2026-10-01T00:00:00.000Z" > "$WORK/half.json"
run_usage "$WORK/half.json" "$WORK/half-cache.json"
assert_cache "$WORK/half-cache.json" 0.5 30d 100 200 allowed
pass "half allowance reports 50% / allowed"

# near the cap → warning, not rejected
snapshot_with 190 200 false "2026-10-01T00:00:00.000Z" > "$WORK/warn.json"
run_usage "$WORK/warn.json" "$WORK/warn-cache.json"
assert_cache "$WORK/warn-cache.json" 0.95 30d 190 200 allowed_warning
pass "95% allowance reports allowed_warning"

# unlimited → no fabricated percentage, not rejected
snapshot_with 0 0 true "2026-10-01T00:00:00.000Z" > "$WORK/unl.json"
run_usage "$WORK/unl.json" "$WORK/unl-cache.json"
python3 - "$WORK/unl-cache.json" <<'PY'
import json, sys
d = json.loads(open(sys.argv[1]).read())
assert d["_unlimited"] is True, "unlimited flag lost"
assert d["windows"][0]["utilization"] == 0, "unlimited must not report a usage percentage"
assert d["status"] == "allowed", "unlimited must not report rejected"
PY
pass "unlimited plan reports no percentage"

# keep a pristine copy for the QML parse below, which must not see the stale marker
cp "$WORK/full-cache.json" "$WORK/live-cache.json"

# a fetch failure marks the previous cache stale instead of dropping it
python3 - "$COPILOT_USAGE" "$WORK/full-cache.json" <<'PY'
import importlib.machinery, importlib.util, json, sys
from pathlib import Path
spec_path, cache_path = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_loader("copilot_usage",
    importlib.machinery.SourceFileLoader("copilot_usage", spec_path))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
mod.fetch = lambda _t: None
mod.CACHE_FILE = Path(cache_path)
mod.main()
assert json.loads(Path(cache_path).read_text())["_source"] == "stale", "failed fetch must mark stale"
PY
pass "failed fetch degrades to stale, keeping the last numbers"

# ── 2. the QML parse in both variants ──
for variant in versions/V1/Theme.qml versions/V1/variants/V2/Theme.qml; do
  [[ -f "$REPO_ROOT/$variant" ]] || fail "missing $variant"
  node "$REPO_ROOT/tests/qr04n-copilot-parse.mjs" "$REPO_ROOT/$variant" "$WORK/live-cache.json" \
    || fail "Copilot cache parse regressed in $variant"
  pass "Theme.qml Copilot parse holds for $variant"
done

printf 'qs-copilot-usage regression tests passed\n'