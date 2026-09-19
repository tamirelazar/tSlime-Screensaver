#!/bin/bash
#
# Takes a frame-rate / CPU measurement of the running screensaver and writes the
# artifacts (fps series, `sample` output, summary) to an output directory.
#
# Always builds through scripts/build-saver.sh first, so a measurement can never
# land on an unoptimized build; pass --no-build only when the running appex is
# known to be the optimized one.
#
# usage: scripts/measure-saver.sh [--seconds N] [--warmup N] [--sample N]
#                                 [--out DIR] [--no-build] [--keep-running]

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WINDOW=20
WARMUP=10
SAMPLE_SECONDS=10
OUT="${TMPDIR:-/tmp}/appexsaver-measure-$(date +%Y%m%d-%H%M%S)"
BUILD=1
KEEP=0
SUBSYSTEM=net.aerialscreensaver.AppexSaverMinimal

while [[ $# -gt 0 ]]; do
  case "$1" in
    --seconds) WINDOW="$2"; shift 2 ;;
    --warmup) WARMUP="$2"; shift 2 ;;
    --sample) SAMPLE_SECONDS="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --no-build) BUILD=0; shift ;;
    --keep-running) KEEP=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# CPU seconds consumed by a pid so far, from ps's [[hh:]mm:ss.ss] cputime.
cpu_seconds() {
  ps -o cputime= -p "$1" 2>/dev/null | awk -F: '{s=0; m=1; for (i=NF; i>=1; i--) {s += $i * m; m *= 60} printf "%.2f", s}'
}

teardown() {
  pkill -x ScreenSaverEngine 2>/dev/null || true
  sleep 1
  # The engine's view never gets stopAnimation on kill, so its tslime child leaks.
  pkill -x tslime 2>/dev/null || true
  pkill -x AppexSaverMinimalExtension 2>/dev/null || true
  sleep 1
}

mkdir -p "$OUT"

if [[ $BUILD -eq 1 ]]; then
  "$REPO/scripts/build-saver.sh" --log "$OUT/build.log"
fi

echo "clearing any running saver instances"
teardown

echo "launching ScreenSaverEngine"
open -a /System/Library/CoreServices/ScreenSaverEngine.app

EXT=""
for _ in $(seq 1 30); do
  EXT=$(pgrep -x AppexSaverMinimalExtension | head -1 || true)
  [[ -n "$EXT" ]] && break
  sleep 1
done
if [[ -z "$EXT" ]]; then
  echo "extension never started — is the saver selected in System Settings?" >&2
  teardown
  exit 1
fi

echo "extension pid $EXT; warming up ${WARMUP}s"
sleep "$WARMUP"

TSLIME=$(pgrep -P "$EXT" -x tslime || true)
INSTANCES=$(printf "%s\n" "$TSLIME" | grep -c . || true)
echo "tslime children: $INSTANCES (one per saver instance)"
if [[ "$INSTANCES" -ne 1 ]]; then
  echo "WARNING: expected 1 instance; the numbers below cover $INSTANCES" >&2
fi

START=$(date "+%Y-%m-%d %H:%M:%S")
t0=$(date +%s)
ext0=$(cpu_seconds "$EXT")
ts0=0; for p in $TSLIME; do ts0=$(echo "$ts0 + $(cpu_seconds "$p")" | bc); done

echo "measuring ${WINDOW}s"
sleep "$WINDOW"

t1=$(date +%s)
ext1=$(cpu_seconds "$EXT")
ts1=0; for p in $TSLIME; do ts1=$(echo "$ts1 + $(cpu_seconds "$p")" | bc); done
END=$(date "+%Y-%m-%d %H:%M:%S")

elapsed=$((t1 - t0))
ext_cpu=$(echo "scale=1; ($ext1 - $ext0) * 100 / $elapsed" | bc)
ts_cpu=$(echo "scale=1; ($ts1 - $ts0) * 100 / $elapsed" | bc)

# Sampled after the CPU window so the sampler's overhead stays out of the CPU numbers.
echo "sampling main thread for ${SAMPLE_SECONDS}s"
sample "$EXT" "$SAMPLE_SECONDS" -f "$OUT/sample.txt" >/dev/null 2>&1 || true

/usr/bin/log show --start "$START" --end "$END" --predicate "subsystem == \"$SUBSYSTEM\"" --style compact \
  >"$OUT/log.txt" 2>/dev/null || true
grep -oE "diag fps presented=[0-9]+" "$OUT/log.txt" | grep -oE "[0-9]+$" >"$OUT/fps.txt" || true

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
  echo "measured: $START -> $END (${elapsed}s)"
  echo "instances: $INSTANCES"
  echo "fps (presented/s): $fps_stats"
  echo "extension CPU: ${ext_cpu}% of a core"
  echo "tslime CPU: ${ts_cpu}% of a core"
  digest
} | tee "$OUT/summary.txt"

if [[ $KEEP -eq 0 ]]; then
  teardown
  echo "saver stopped"
fi
echo "artifacts: $OUT"
