#!/bin/bash
#
# Takes a frame-rate / CPU measurement of the running screensaver and writes the
# artifacts (fps series, `sample` output, summary) to an output directory.
#
# Always builds through scripts/build-saver.sh first, so a measurement can never
# land on an unoptimized build; pass --no-build only when the running appex is
# known to be the optimized one.
#
# The extension is hosted by more than one client, and a resident instance is
# restarted by its client as fast as it is killed -- sometimes with a tslime
# child of its own, rendering and costing CPU. So the instance to measure is
# identified as the one that did not exist before this run launched the engine:
# not the first pid, and not merely the first pid with a tslime child.
#
# A saver instance can vanish at any moment, because any user input dismisses
# the screensaver, so the window is read incrementally and a short run is
# reported as short rather than crashed on.
#
# usage: scripts/measure-saver.sh [--seconds N] [--warmup N] [--sample N]
#                                 [--runs N] [--min-window N]
#                                 [--out DIR] [--no-build] [--keep-running]

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WINDOW=20
WARMUP=10
SAMPLE_SECONDS=10
RUNS=1
MIN_WINDOW=5
OUT="${TMPDIR:-/tmp}/appexsaver-measure-$(date +%Y%m%d-%H%M%S)"
BUILD=1
KEEP=0
SUBSYSTEM=net.aerialscreensaver.AppexSaverMinimal
STARTUP_TIMEOUT=30

while [[ $# -gt 0 ]]; do
  case "$1" in
    --seconds) WINDOW="$2"; shift 2 ;;
    --warmup) WARMUP="$2"; shift 2 ;;
    --sample) SAMPLE_SECONDS="$2"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    --min-window) MIN_WINDOW="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --no-build) BUILD=0; shift ;;
    --keep-running) KEEP=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# CPU seconds consumed by a pid so far, from ps's [[hh:]mm:ss.ss] cputime.
# Prints nothing for a pid that is gone, and never fails: under `set -o pipefail`
# a bare `ext=$(cpu_seconds $dead)` would otherwise take `set -e` down with it.
cpu_seconds() {
  ps -o cputime= -p "$1" 2>/dev/null |
    awk -F: '{s=0; m=1; for (i=NF; i>=1; i--) {s += $i * m; m *= 60} printf "%.2f", s}' || true
}

# Summed CPU seconds of a pid list; prints nothing unless every pid is alive, so
# a child that exits mid-window leaves the last complete reading standing rather
# than silently subtracting itself from the total.
cpu_seconds_all() {
  local total=0 one
  [[ -z "${1:-}" ]] && return 0
  for one in $@; do
    local v; v=$(cpu_seconds "$one")
    [[ -z "$v" ]] && return 0
    total=$(echo "$total + $v" | bc)
  done
  printf "%s" "$total"
}

# Seconds since the last keyboard or mouse event. Any input dismisses the
# screensaver, which is the usual reason a run ends early or never starts --
# worth naming, because the symptom otherwise looks like a bug in the saver.
idle_seconds() {
  ioreg -c IOHIDSystem 2>/dev/null |
    awk '/HIDIdleTime/ {gsub(/[^0-9]/, "", $NF); print int($NF / 1000000000); exit}' || true
}

blame_input() {
  local idle; idle=$(idle_seconds)
  [[ -n "$idle" && "$idle" -lt 120 ]] &&
    echo "  (last input ${idle}s ago — user input dismisses the screensaver; measure from an idle machine)" >&2
  return 0
}

instances() { pgrep -x AppexSaverMinimalExtension 2>/dev/null || true; }
views_of() { pgrep -P "$1" -x tslime 2>/dev/null || true; }
count() { printf "%s\n" "$1" | grep -c . || true; }

# Percentage of a core, refusing to invent a number from a missing reading.
pct() {
  local c1="$1" c0="$2" secs="$3"
  [[ -z "$c1" || -z "$c0" || "$secs" -le 0 ]] && { printf "n/a"; return; }
  echo "scale=1; ($c1 - $c0) * 100 / $secs" | bc
}

# Idempotent, and deliberately does not insist on an empty process list: a
# resident instance is restarted by its client as fast as it is killed, so
# looping on pkill only burns time and CPU. Whatever survives is snapshotted
# before the next launch and excluded from selection instead.
teardown() {
  pkill -x ScreenSaverEngine 2>/dev/null || true
  sleep 1
  # The engine's view never gets stopAnimation on kill, so its tslime child leaks.
  pkill -x tslime 2>/dev/null || true
  pkill -x AppexSaverMinimalExtension 2>/dev/null || true
  sleep 2
}

STOPPED=0
cleanup() {
  local rc=$?
  if [[ $KEEP -eq 0 && $STOPPED -eq 0 ]]; then teardown; fi
  exit $rc
}
trap cleanup EXIT INT TERM

# Lets scripts/test-measure-saver.sh source the helpers above without launching
# a saver; everything below this line is the measurement proper.
[[ "${MEASURE_SAVER_SOURCE_ONLY:-0}" == "1" ]] && return 0

mkdir -p "$OUT"

if [[ $BUILD -eq 1 ]]; then
  "$REPO/scripts/build-saver.sh" --log "$OUT/build.log"
fi

# Launches the engine and measures one window into $1 (a run directory).
# Echoes "elapsed ext_cpu ts_cpu views ended" on success; returns 1 if no saver
# instance could be identified or the window was too short to report.
measure_once() {
  local dir="$1"
  mkdir -p "$dir"

  echo "clearing any running saver instances"
  teardown

  # Anything still standing belongs to another client and must not be mistaken
  # for ours -- including a resident instance that has a tslime child and is
  # rendering, which is indistinguishable from the engine's by any other test.
  local before pre_views p
  before="$(instances)"
  pre_views=""
  for p in $before; do pre_views="$pre_views $p:$(count "$(views_of "$p")")"; done
  [[ -n "$before" ]] && echo "pre-existing instances:$pre_views"

  echo "launching ScreenSaverEngine"
  open -a /System/Library/CoreServices/ScreenSaverEngine.app

  # The saver instance is the one this launch created: a pid absent from the
  # snapshot that has a tslime child. If the engine instead attached a view to
  # an existing instance, that instance's child count goes up.
  local ext="" views="" i
  for i in $(seq 1 "$STARTUP_TIMEOUT"); do
    for p in $(instances); do
      local n; n=$(count "$(views_of "$p")")
      [[ "$n" -eq 0 ]] && continue
      if ! printf "%s\n" $before | grep -qx "$p"; then ext="$p"; break; fi
      local was; was=$(printf "%s" "$pre_views" | tr ' ' '\n' | grep "^$p:" | cut -d: -f2)
      if [[ -n "$was" && "$n" -gt "$was" ]]; then ext="$p"; break; fi
    done
    [[ -n "$ext" ]] && break
    sleep 1
  done
  if [[ -z "$ext" ]]; then
    echo "no new saver instance appeared within ${STARTUP_TIMEOUT}s" >&2
    if [[ -z "$(pgrep -x ScreenSaverEngine || true)" ]]; then
      echo "  ScreenSaverEngine is not running: it exited without starting a saver instance," >&2
      echo "  or never launched. Check that the saver is selected in System Settings." >&2
    fi
    if [[ -n "$before" ]]; then
      echo "  a resident instance ($before) was already running and was excluded on purpose;" >&2
      echo "  the engine does not appear to start a second one while it is up." >&2
    fi
    blame_input
    return 1
  fi

  echo "saver instance pid $ext; warming up ${WARMUP}s"
  sleep "$WARMUP"
  if [[ -z "$(cpu_seconds "$ext")" ]]; then
    echo "saver instance $ext died during warm-up" >&2
    blame_input
    return 1
  fi

  local tslime; tslime="$(views_of "$ext")"
  local n_views; n_views=$(count "$tslime")
  echo "tslime children: $n_views (one per saver instance)"
  if [[ "$n_views" -ne 1 ]]; then
    echo "WARNING: expected 1 instance; the numbers below cover $n_views" >&2
  fi

  local start t0 ext0 ts0
  start=$(date "+%Y-%m-%d %H:%M:%S")
  t0=$(date +%s)
  ext0=$(cpu_seconds "$ext")
  ts0=$(cpu_seconds_all "$tslime")

  # Read the window a second at a time: the instance can be dismissed at any
  # point, and the last complete reading is a real measurement of a short
  # window, where re-reading a dead pid at the end is no measurement at all.
  echo "measuring up to ${WINDOW}s"
  local ext1="$ext0" ts1="$ts0" t1="$t0" ended="full" now v
  for ((i = 0; i < WINDOW; i++)); do
    sleep 1
    v=$(cpu_seconds "$ext")
    if [[ -z "$v" ]]; then ended="instance died"; break; fi
    now=$(date +%s)
    ext1="$v"; t1="$now"
    v=$(cpu_seconds_all "$tslime")
    [[ -n "$v" ]] && ts1="$v"
  done
  local end; end=$(date "+%Y-%m-%d %H:%M:%S")

  local elapsed=$((t1 - t0))
  if [[ "$elapsed" -lt "$MIN_WINDOW" ]]; then
    echo "window was ${elapsed}s, under the ${MIN_WINDOW}s minimum ($ended) — no numbers from this run" >&2
    blame_input
    return 1
  fi
  if [[ "$ended" != "full" ]]; then
    echo "run ended early after ${elapsed}s: $ended"
    blame_input
  fi

  # Sampled after the CPU window so the sampler's overhead stays out of the CPU
  # numbers, and only while there is still something to sample.
  if [[ -n "$(cpu_seconds "$ext")" ]]; then
    echo "sampling main thread for ${SAMPLE_SECONDS}s"
    sample "$ext" "$SAMPLE_SECONDS" -f "$dir/sample.txt" >/dev/null 2>&1 || true
  else
    echo "instance gone before sampling — no main-thread breakdown for this run"
  fi

  # The log outlives the instance, so the fps series survives an early end.
  /usr/bin/log show --start "$start" --end "$end" --predicate "subsystem == \"$SUBSYSTEM\"" --style compact \
    >"$dir/log.txt" 2>/dev/null || true
  grep -oE "diag fps presented=[0-9]+" "$dir/log.txt" | grep -oE "[0-9]+$" >"$dir/fps.txt" || true

  printf "%s %s %s %s %s\n" \
    "$elapsed" "$(pct "$ext1" "$ext0" "$elapsed")" "$(pct "$ts1" "$ts0" "$elapsed")" "$n_views" "$ended" \
    >"$dir/result.txt"
  return 0
}

RESULTS=()
for ((run = 1; run <= RUNS; run++)); do
  [[ "$RUNS" -gt 1 ]] && echo "=== run $run of $RUNS ==="
  if measure_once "$OUT/run$run"; then
    RESULTS+=("$OUT/run$run")
  else
    echo "run $run produced no usable window" >&2
  fi
done

if [[ ${#RESULTS[@]} -eq 0 ]]; then
  echo "no run produced a usable window — nothing measured" >&2
  exit 1
fi

# Pool the runs: fps samples concatenate, CPU averages weight by observed
# seconds, and the main-thread digest comes from the longest run.
: >"$OUT/fps.txt"
best=""; best_elapsed=0; total=0; ext_num=0; ts_num=0; ends=""
for dir in "${RESULTS[@]}"; do
  cat "$dir/fps.txt" >>"$OUT/fps.txt" 2>/dev/null || true
  read -r elapsed ext_cpu ts_cpu n_views ended <"$dir/result.txt"
  total=$((total + elapsed))
  [[ "$ext_cpu" != "n/a" ]] && ext_num=$(echo "$ext_num + $ext_cpu * $elapsed" | bc)
  [[ "$ts_cpu" != "n/a" ]] && ts_num=$(echo "$ts_num + $ts_cpu * $elapsed" | bc)
  [[ "$ended" != "full" ]] && ends="$ends run:$ended"
  # A `sample` taken as the instance goes away still writes a file, but without
  # a main-thread stack in it, so a non-empty file is not enough to prefer.
  if [[ "$elapsed" -gt "$best_elapsed" ]] && grep -q "com.apple.main-thread" "$dir/sample.txt" 2>/dev/null; then
    best="$dir"; best_elapsed="$elapsed"
  fi
done
[[ -n "$best" ]] && cp "$best/sample.txt" "$OUT/sample.txt"
cp "${RESULTS[0]}/log.txt" "$OUT/log.txt" 2>/dev/null || true

fps_stats=$(sort -n "$OUT/fps.txt" | awk '{v[NR]=$1; s+=$1} END {
  if (NR == 0) {print "no fps samples"; exit}
  printf "n=%d mean=%.1f median=%d min=%d max=%d", NR, s/NR, v[int((NR+1)/2)], v[1], v[NR]
}')

# Main-thread digest: total samples on the main thread and the two branches that
# dominate it today — the MTKView draw callback and the pty-read -> parser path.
digest() {
  local total draw parse
  total=$(grep -m1 -oE "[0-9]+ Thread_[0-9]+ *DispatchQueue_1: com.apple.main-thread" "$OUT/sample.txt" 2>/dev/null | grep -oE "^[0-9]+" || true)
  draw=$(grep -m1 -oE "[0-9]+ @objc MetalTerminalRenderer.draw\(in:\)" "$OUT/sample.txt" 2>/dev/null | grep -oE "^[0-9]+" || true)
  parse=$(grep -m1 -oE "[0-9]+ LocalProcess.drainReceivedData\(\)" "$OUT/sample.txt" 2>/dev/null | grep -oE "^[0-9]+" || true)
  if [[ -z "$total" ]]; then echo "main thread: no sample"; return; fi
  echo "main thread: $total samples"
  if [[ -n "$draw" ]]; then echo "  renderer draw: $draw ($(echo "scale=1; $draw * 100 / $total" | bc)%)"; fi
  if [[ -n "$parse" ]]; then echo "  pty read + parse: $parse ($(echo "scale=1; $parse * 100 / $total" | bc)%)"; fi
}

{
  echo "runs: ${#RESULTS[@]} of $RUNS usable, ${total}s measured in total"
  [[ -n "$ends" ]] && echo "early endings:$ends"
  echo "fps (presented/s): $fps_stats"
  echo "extension CPU: $(echo "scale=1; $ext_num / $total" | bc)% of a core"
  echo "tslime CPU: $(echo "scale=1; $ts_num / $total" | bc)% of a core"
  digest
} | tee "$OUT/summary.txt"

if [[ $KEEP -eq 0 ]]; then
  teardown
  STOPPED=1
  echo "saver stopped"
fi
echo "artifacts: $OUT"
