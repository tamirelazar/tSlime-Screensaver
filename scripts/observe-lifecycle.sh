#!/bin/bash
#
# Records which lifecycle / visibility signals each extension instance receives,
# for issue #9. The instrumentation itself lives in
# AppexSaverMinimalExtension/LifecycleProbe.swift and logs at .notice under
# category "Lifecycle", so the run is reconstructed from the unified log after
# the fact rather than scraped live.
#
# Like scripts/measure-saver.sh this kills every instance first, so nothing that
# respawns can be running a previous build. Unlike it, it does NOT try to
# identify "the" saver instance: the whole question here is which instance gets
# which signal, so every pid that logs is reported, side by side.
#
# Scenarios (the ticket asks for the last two to be told apart):
#   idle   -- launch, watch, tear down cleanly at the end
#   kill   -- launch, watch, then `pkill ScreenSaverEngine` mid-run
#   input  -- launch, watch, and wait for a human to dismiss with a keypress
#
# usage: scripts/observe-lifecycle.sh [--seconds N] [--scenario idle|kill|input]
#                                     [--timer true|false] [--out DIR] [--no-build]

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECONDS_TO_WATCH=45
SCENARIO=idle
TIMER=""
OUT="${TMPDIR:-/tmp}/appexsaver-lifecycle-$(date +%Y%m%d-%H%M%S)"
BUILD=1
SUBSYSTEM=net.aerialscreensaver.AppexSaverMinimal
PLIST="$REPO/AppexSaverMinimalExtension/Info.plist"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --seconds) SECONDS_TO_WATCH="$2"; shift 2 ;;
    --scenario) SCENARIO="$2"; shift 2 ;;
    --timer) TIMER="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --no-build) BUILD=0; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$OUT"

# The SSENeedsAnimationTimer A/B rewrites a tracked file, so it is always put
# back -- including on ^C, which is how an `input` run usually ends.
PLIST_RESTORED=1
restore_plist() {
  [[ $PLIST_RESTORED -eq 1 ]] && return
  cp "$OUT/Info.plist.orig" "$PLIST"
  PLIST_RESTORED=1
  echo "restored $PLIST"
}

teardown() {
  pkill -x ScreenSaverEngine 2>/dev/null || true
  sleep 1
  pkill -x tslime 2>/dev/null || true
  pkill -x AppexSaverMinimalExtension 2>/dev/null || true
  sleep 2
}

cleanup() {
  local rc=$?
  restore_plist
  teardown
  exit $rc
}
trap cleanup EXIT INT TERM

if [[ -n "$TIMER" ]]; then
  cp "$PLIST" "$OUT/Info.plist.orig"
  PLIST_RESTORED=0
  /usr/libexec/PlistBuddy -c "Set :SSENeedsAnimationTimer $TIMER" "$PLIST"
  echo "SSENeedsAnimationTimer set to $TIMER for this run"
fi

if [[ $BUILD -eq 1 ]]; then
  "$REPO/scripts/build-saver.sh" --log "$OUT/build.log"
fi

# Taken before the teardown, not after it: the wallpaper client can restart an
# instance the moment the old one dies, and a start timestamp taken after the
# teardown misses that instance's startup events by a second -- which is where
# every interesting signal lives.
START="$(date '+%Y-%m-%d %H:%M:%S')"

echo "clearing any running saver instances"
teardown

echo "launching ScreenSaverEngine"
open -a /System/Library/CoreServices/ScreenSaverEngine.app

case "$SCENARIO" in
  idle)
    echo "watching for ${SECONDS_TO_WATCH}s (do not touch the keyboard or mouse)"
    sleep "$SECONDS_TO_WATCH"
    ;;
  kill)
    local_half=$((SECONDS_TO_WATCH / 2))
    echo "watching for ${local_half}s, then killing ScreenSaverEngine"
    sleep "$local_half"
    echo "--- killing ScreenSaverEngine now"
    pkill -x ScreenSaverEngine 2>/dev/null || true
    sleep "$local_half"
    ;;
  input)
    echo "watching for up to ${SECONDS_TO_WATCH}s."
    echo ">>> Let it run at least 15s, THEN press a key to dismiss the saver. <<<"
    sleep "$SECONDS_TO_WATCH"
    ;;
  *) echo "unknown scenario: $SCENARIO" >&2; exit 2 ;;
esac

END="$(date '+%Y-%m-%d %H:%M:%S')"
echo "collecting log from $START to $END"

/usr/bin/log show --start "$START" --end "$END" \
  --predicate "subsystem == \"$SUBSYSTEM\" && category == \"Lifecycle\"" \
  --style compact --info --debug > "$OUT/lifecycle.log" 2>/dev/null || true

# The whole subsystem too, so probe events can be read against the terminal's
# own diag lines (grid size, first frame, fps) on the same timeline.
/usr/bin/log show --start "$START" --end "$END" \
  --predicate "subsystem == \"$SUBSYSTEM\"" \
  --style compact --info --debug > "$OUT/all.log" 2>/dev/null || true

# One file per pid, because the point of the run is to compare what the
# resident instance received against what the saver instance received.
awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^0x/) { print; break } }' "$OUT/lifecycle.log" >/dev/null 2>&1 || true
grep -o '\[[0-9]*:' "$OUT/lifecycle.log" 2>/dev/null | tr -d '[:' | sort -u > "$OUT/pids.txt" || true

echo
echo "=== instances that logged (pid: event count) ==="
if [[ -s "$OUT/pids.txt" ]]; then
  while read -r pid; do
    [[ -z "$pid" ]] && continue
    n=$(grep -c "\[$pid:" "$OUT/lifecycle.log" || true)
    grep "\[$pid:" "$OUT/lifecycle.log" > "$OUT/pid-$pid.log" || true
    echo "  pid $pid: $n events -> $OUT/pid-$pid.log"
  done < "$OUT/pids.txt"
else
  echo "  (no pids parsed; read $OUT/lifecycle.log directly)"
fi

echo
echo "=== distinct events seen, by pid ==="
sed -n 's/.*\[\([0-9]*\):.*ev=\([a-zA-Z._]*\).*/\1 \2/p' "$OUT/lifecycle.log" |
  sort | uniq -c | sort -k2,2n -k1,1nr || true

echo
echo "artifacts in $OUT"
