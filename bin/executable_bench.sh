#!/usr/bin/env bash
# Rails dev hardware benchmark — multi-run, median + stddev, JSON output.
# Run from repo root.

set -uo pipefail

REPO_ROOT="$(pwd)"
RUNS=${RUNS:-3}
WARMUP=${WARMUP:-1}
SINGLE_SPEC=${SINGLE_SPEC:-"spec/models/statuses"}
PARALLEL_SPEC=${PARALLEL_SPEC:-"spec/models/order"}
TSC_SMALL_PROJECT=${TSC_SMALL_PROJECT:-"packages/utils/tsconfig.json"}
TSC_LARGE_PROJECT=${TSC_LARGE_PROJECT:-"apps/marketplace/tsconfig.json"}
SKIP_CLAUDE=${SKIP_CLAUDE:-0}
SKIP_BUILD=${SKIP_BUILD:-1}        # client_build slow; opt-in
SKIP_TSC=${SKIP_TSC:-0}
SKIP_PARALLEL=${SKIP_PARALLEL:-0}

# Rails env: disable Spring; force test env so boot is consistent
export DISABLE_SPRING=1
export RAILS_ENV=${RAILS_ENV:-test}

OUT=${OUT:-"$REPO_ROOT/benchmark-$(hostname -s)-$(date +%Y%m%d-%H%M%S).json"}
RESULTS_FILE="$(mktemp -t bench-results.XXXXXX)"
trap 'rm -f "$RESULTS_FILE"' EXIT

have() { command -v "$1" >/dev/null 2>&1; }
now_ms() { python3 -c 'import time; print(int(time.time()*1000))'; }

run_task() {
  local label="$1" setup="$2" cmd="$3"
  echo ">>> $label" >&2
  local times=() rcs=()
  local i
  for i in $(seq 1 "$WARMUP"); do
    echo "  warmup $i..." >&2
    ( cd "$REPO_ROOT"; eval "$setup" ) >/dev/null 2>&1 || true
    ( cd "$REPO_ROOT"; eval "$cmd"  ) >/dev/null 2>&1 || true
  done
  for i in $(seq 1 "$RUNS"); do
    ( cd "$REPO_ROOT"; eval "$setup" ) >/dev/null 2>&1 || true
    local t0 t1 elapsed rc
    t0=$(now_ms)
    ( cd "$REPO_ROOT"; eval "$cmd" ) >/dev/null 2>&1
    rc=$?
    t1=$(now_ms)
    elapsed=$(python3 -c "print(($t1-$t0)/1000.0)")
    echo "  run $i: ${elapsed}s (rc=$rc)" >&2
    times+=("$elapsed")
    rcs+=("$rc")
  done
  python3 - "$label" "${rcs[*]}" "${times[@]}" >> "$RESULTS_FILE" <<'PY'
import json, statistics, sys
label = sys.argv[1]
rcs = sys.argv[2].split()
xs = [float(x) for x in sys.argv[3:]]
print(json.dumps({
    "task": label,
    "median_s": round(statistics.median(xs), 3),
    "stddev_s": round(statistics.stdev(xs) if len(xs) > 1 else 0.0, 3),
    "min_s": round(min(xs), 3),
    "max_s": round(max(xs), 3),
    "runs": [round(x, 3) for x in xs],
    "exit_codes": rcs,
}))
PY
}

# --- system info ---
SYS_MODEL=$(sysctl -n hw.model 2>/dev/null || echo unknown)
SYS_CPU=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)
SYS_CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo 0)
SYS_PERF_CORES=$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || echo 0)
SYS_RAM_GB=$(python3 -c "import subprocess; print(int(subprocess.check_output(['sysctl','-n','hw.memsize']))//(1024**3))" 2>/dev/null || echo 0)
SYS_OS=$(sw_vers -productVersion 2>/dev/null || uname -r)
RUBY_V=$(ruby -v 2>/dev/null | head -1 || echo none)
NODE_V=$(node -v 2>/dev/null || echo none)
LOWPOWER=$(pmset -g 2>/dev/null | awk '/lowpowermode/ {print $2}')
THERMAL=$(pmset -g therm 2>/dev/null | awk -F= '/CPU_Speed_Limit/ {print $2}' | tr -d ' ')

echo "=== Rails dev benchmark — $RUNS runs/task, $WARMUP warmup ==="
echo "Host: $(hostname -s) | $SYS_MODEL | $SYS_CPU | ${SYS_CORES}c (${SYS_PERF_CORES}p) | ${SYS_RAM_GB}GB | macOS $SYS_OS"
echo "DISABLE_SPRING=$DISABLE_SPRING RAILS_ENV=$RAILS_ENV"
[[ "$LOWPOWER" == "1" ]] && echo "WARNING: Low Power Mode ON — disable for accurate results."
[[ -n "$THERMAL" && "$THERMAL" != "100" ]] && echo "WARNING: thermal throttle active (CPU_Speed_Limit=$THERMAL)"

# --- Rails tasks ---
if [[ -f api/Gemfile ]]; then
  run_task "rails_boot" \
    "true" \
    "cd api && bundle exec rails runner 'nil'"

  run_task "rspec_single_dir_serial" \
    "true" \
    "cd api && bundle exec rspec $SINGLE_SPEC"

  if [[ "$SKIP_PARALLEL" != "1" ]] && (cd api && bundle exec which parallel_rspec >/dev/null 2>&1); then
    run_task "rspec_parallel" \
      "true" \
      "cd api && bundle exec parallel_rspec $PARALLEL_SPEC"
  fi
fi

# --- Frontend tasks ---
if [[ "$SKIP_TSC" != "1" && -f client/package.json ]]; then
  if [[ -f "client/$TSC_SMALL_PROJECT" ]]; then
    run_task "tsc_small_pkg" \
      "true" \
      "cd client && npx tsc --noEmit -p $TSC_SMALL_PROJECT"
  fi
  if [[ -f "client/$TSC_LARGE_PROJECT" ]]; then
    run_task "tsc_large_app" \
      "true" \
      "cd client && npx tsc --noEmit -p $TSC_LARGE_PROJECT"
  fi
fi

if [[ "$SKIP_BUILD" != "1" && -f client/package.json ]]; then
  run_task "client_build" \
    "true" \
    "cd client && npm run build"
fi

# --- Claude variants ---
if [[ "$SKIP_CLAUDE" != "1" ]] && have claude; then
  # CLI boot — no tools, trivial prompt. Local CPU + Node startup dominant.
  run_task "claude_cli_boot" \
    "true" \
    "claude -p 'ok' --allowedTools none"

  # Tool-heavy — Grep + Read in api/. Local CPU + IO + API mix.
  run_task "claude_tool_grep" \
    "true" \
    "claude -p 'Use Grep to find files in api/app/models containing \"belongs_to :store\". List paths only, no analysis.' --allowedTools Grep,Read"

  # Pure generation — no tools, longer output. Network/API-bound (sanity check).
  run_task "claude_long_gen" \
    "true" \
    "claude -p 'Write a 200-word essay about cats. No preamble.' --allowedTools none"
fi

# --- emit final JSON ---
python3 - "$RESULTS_FILE" "$OUT" <<PY
import json, sys
results_file, out_file = sys.argv[1], sys.argv[2]
tasks = {}
with open(results_file) as f:
    for line in f:
        line = line.strip()
        if not line: continue
        d = json.loads(line)
        tasks[d.pop("task")] = d
doc = {
    "host": "$(hostname -s)",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "system": {
        "model": "$SYS_MODEL",
        "cpu": "$SYS_CPU",
        "cores": $SYS_CORES,
        "perf_cores": $SYS_PERF_CORES,
        "ram_gb": $SYS_RAM_GB,
        "macos": "$SYS_OS",
        "ruby": "$RUBY_V",
        "node": "$NODE_V",
    },
    "config": {
        "runs": $RUNS, "warmup": $WARMUP,
        "single_spec": "$SINGLE_SPEC", "parallel_spec": "$PARALLEL_SPEC",
        "tsc_small": "$TSC_SMALL_PROJECT", "tsc_large": "$TSC_LARGE_PROJECT",
        "disable_spring": "$DISABLE_SPRING", "rails_env": "$RAILS_ENV",
    },
    "results": tasks,
}
with open(out_file, "w") as f:
    json.dump(doc, f, indent=2)
print(json.dumps(doc, indent=2))
PY

echo
echo "Wrote $OUT"
echo
echo "Summary (median seconds):"
python3 - "$OUT" <<'PY'
import json, math, sys
d = json.load(open(sys.argv[1]))
medians = []
for k, v in d["results"].items():
    print(f"  {k:<30} {v['median_s']:>8.3f} s  (±{v['stddev_s']:.3f})  rc={','.join(v['exit_codes'])}")
    medians.append(v["median_s"])
if medians:
    total = sum(medians)
    geo = math.exp(sum(math.log(x) for x in medians) / len(medians))
    print(f"  {'-'*60}")
    print(f"  {'sum_of_medians':<30} {total:>8.3f} s   ({len(medians)} tasks)")
    print(f"  {'geometric_mean':<30} {geo:>8.3f} s   <-- use for M1 vs M5 ratio")
    # Persist into JSON too
    d["aggregate"] = {"sum_of_medians_s": round(total, 3),
                      "geometric_mean_s": round(geo, 3),
                      "task_count": len(medians)}
    json.dump(d, open(sys.argv[1], "w"), indent=2)
PY
