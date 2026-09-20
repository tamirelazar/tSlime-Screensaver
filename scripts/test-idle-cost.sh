#!/bin/bash
#
# Asserts the idle half of the destination: when no saver instance is on
# screen, the saver costs nothing.
#
#   1. no tslime process is alive, and
#   2. every extension instance is under --max-cpu (default 1%) of a core.
#
# Issue #10 measured that both hold today, for a reason that is not a policy:
# on the normal dismissal path the whole extension process is gone within a
# second, taking its tslime child with it, so there is no hidden instance left
# to be expensive. This script is what turns that observation into something
# that fails if it stops being true -- an instance that starts outliving its
# saver instance, or a teardown that stops reaping tslime, both surface here
# as a non-zero idle cost.
#
# Measuring CPU correctly is the whole trick, and the reason this borrows
# measure-saver.sh's helpers rather than writing its own: `ps -o %cpu` reports
# an average over the process's *lifetime*, so an instance that rendered at
# 33% for 75 seconds and has been idle since still reads 33%. The right figure
# is cumulative CPU time sampled twice over a known window, which is what
# cpu_seconds/pct do -- and what issue #18's regression test already covers.
#
# usage: scripts/test-idle-cost.sh [--window SECONDS] [--max-cpu PERCENT]
#
# Run it with the screensaver not running. It refuses if a saver instance
# looks like it is on screen, because "cheap while hidden" says nothing about
# an instance that is doing its job.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# A sourced script sees the sourcing script's positional parameters, and
# measure-saver.sh parses arguments at source time -- so this script's own
# --window reached its parser and was rejected as unknown. Hand it an empty
# argv and put ours back afterwards.
IDLE_ARGV=("$@")
set --
# shellcheck source=measure-saver.sh
MEASURE_SAVER_SOURCE_ONLY=1 source "$REPO/scripts/measure-saver.sh" || {
  echo "could not source $REPO/scripts/measure-saver.sh" >&2; exit 2; }
set -- ${IDLE_ARGV[@]+"${IDLE_ARGV[@]}"}
# A helper that silently isn't there would leave every reading empty, and an
# empty reading must never read as a pass -- that is issue #18's bug exactly.
for fn in cpu_seconds pct instances views_of count idle_seconds; do
  declare -F "$fn" >/dev/null || { echo "missing helper: $fn" >&2; exit 2; }
done

# Sourcing brings two things along that are wrong here, and both are silent:
# errexit (so a helper returning nothing would abort mid-assertion instead of
# failing a check), and an EXIT trap that tears down every saver process. This
# script exists to *observe* the idle state -- killing it on the way out would
# destroy the evidence and stop any instance the check just failed on from
# being inspected.
set +e
trap - EXIT INT TERM

# Arguments are parsed *after* the source, and under names of their own:
# measure-saver.sh sets WINDOW, SAMPLE_SECONDS and friends at source time, so
# parsing first meant this script's --window was silently overwritten by its
# defaults.
IDLE_WINDOW=5
IDLE_MAX_CPU=1.0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --window)  IDLE_WINDOW="$2"; shift 2 ;;
    --max-cpu) IDLE_MAX_CPU="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# --- refuse to measure a saver that is on screen -------------------------

if pgrep -x ScreenSaverEngine >/dev/null 2>&1; then
  echo "REFUSED: ScreenSaverEngine is running -- a saver instance is on screen."
  echo "         This measures the hidden case. Dismiss the screensaver first."
  exit 2
fi

idle="$(idle_seconds)"
timeout="$(defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null || echo 0)"
if [[ -n "$idle" && "${timeout:-0}" -gt 0 && "$idle" -ge "$timeout" ]]; then
  echo "REFUSED: idle for ${idle}s against a ${timeout}s screensaver timeout -- the"
  echo "         system may have started the saver itself. Touch the machine and retry."
  exit 2
fi

FAILED=0

# --- 1. no tslime ---------------------------------------------------------

tslime_pids="$(pgrep -x tslime 2>/dev/null || true)"
if [[ -n "$tslime_pids" ]]; then
  echo "FAIL: tslime alive with no saver on screen: $(echo "$tslime_pids" | tr '\n' ' ')"
  for p in $tslime_pids; do
    echo "      pid=$p ppid=$(ps -o ppid= -p "$p" | tr -d ' ') started=$(ps -o lstart= -p "$p")"
  done
  FAILED=1
else
  echo "PASS: no tslime process alive."
fi

# --- 2. every extension instance under the bar ----------------------------

pids="$(instances)"
if [[ -z "$pids" ]]; then
  echo "PASS: no extension instance alive (idle cost is structurally zero)."
  exit $FAILED
fi

echo "note: $(count "$pids") extension instance(s) alive; sampling ${IDLE_WINDOW}s."

declare -a before=()
for p in $pids; do before+=("$p=$(cpu_seconds "$p")"); done
sleep "$IDLE_WINDOW"

for entry in "${before[@]}"; do
  p="${entry%%=*}"; c0="${entry#*=}"
  c1="$(cpu_seconds "$p")"
  # pct prints n/a rather than inventing a number from a missing reading --
  # which is what an instance exiting mid-window looks like.
  reading="$(pct "$c1" "$c0" "$IDLE_WINDOW")"
  if [[ "$reading" == "n/a" ]]; then
    echo "      pid=$p exited during the window (not counted)."
    continue
  fi
  # Anything that is not a number is a failure to measure, never a pass: the
  # whole point of this check is that it cannot report "fine" without a reading.
  if [[ ! "$reading" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    echo "FAIL: extension pid=$p produced no usable CPU reading (got [$reading])"
    FAILED=1
    continue
  fi
  if (( $(echo "$reading > $IDLE_MAX_CPU" | bc -l) )); then
    echo "FAIL: extension pid=$p at ${reading}% of a core while hidden (bar: ${IDLE_MAX_CPU}%)"
    echo "      children: $(views_of "$p" | tr '\n' ' ')"
    FAILED=1
  else
    echo "PASS: extension pid=$p at ${reading}% of a core (bar: ${IDLE_MAX_CPU}%)"
  fi
done

exit $FAILED
