#!/bin/bash
#
# Checks the frame-rate setting on a live saver instance (#21).
#
# The frame rate is the one setting that is not a property assignment: it is a
# tslime launch argument, so applying it means killing the child and forking a
# new one. That is worth a script for two reasons, and they pull in opposite
# directions:
#
#   - a frame-rate change MUST relaunch tslime, or the setting silently does
#     nothing until the next time the screensaver starts;
#   - a braille change MUST NOT, or every drag of a slider restarts a process.
#
# Both are asserted here against tslime's pid, which is the only evidence that
# does not depend on reading our own log correctly. The presented rate is then
# checked against what was asked for, because a relaunch that came up at the
# old rate would satisfy the pid test and still be wrong.
#
# This takes the screen: it puts a real screensaver session up. Nothing here
# can put the screen back -- ending a session takes real input -- so it leaves
# the saver up and says so, exactly as measure-saver.sh does.
#
# usage: scripts/test-frame-rate.sh [--settle N] [--no-build]

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# start_saver / stop_saver / instances / views_of / blame_input, without
# arming that script's EXIT trap or launching anything. Sourced before this
# script's own configuration -- see the note in test-braille-fonts.sh.
ARGS=("$@")
set --
MEASURE_SAVER_SOURCE_ONLY=1 source "$REPO/scripts/measure-saver.sh"
set -- "${ARGS[@]:-}"
[[ ${#ARGS[@]} -eq 0 ]] && set --

OUT="${TMPDIR:-/tmp}/appexsaver-framerate-$(date +%Y%m%d-%H%M%S)"
SETTLE=5
BUILD=1
DOMAIN=net.aerialscreensaver.AppexSaverMinimal
SUBSYSTEM=net.aerialscreensaver.AppexSaverMinimal

while [[ $# -gt 0 ]]; do
  case "$1" in
    --settle) SETTLE="$2"; shift 2 ;;
    --no-build) BUILD=0; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Restore whatever the user had, whether this passes, fails or is interrupted.
# Plain variables rather than an associative array: /bin/bash here is 3.2.
HAD_RATE=0; PREV_RATE=""
HAD_DOT=0;  PREV_DOT=""
HAD_SRC=0;  PREV_SRC=""
if PREV_RATE="$(defaults read "$DOMAIN" frameRate 2>/dev/null)"; then HAD_RATE=1; fi
if PREV_DOT="$(defaults read "$DOMAIN" brailleDotSizeFraction 2>/dev/null)"; then HAD_DOT=1; fi
if PREV_SRC="$(defaults read "$DOMAIN" brailleSource 2>/dev/null)"; then HAD_SRC=1; fi

restore_keys() {
  if [[ $HAD_RATE -eq 1 ]]; then
    defaults write "$DOMAIN" frameRate -int "$PREV_RATE"
  else
    defaults delete "$DOMAIN" frameRate 2>/dev/null || true
  fi
  if [[ $HAD_DOT -eq 1 ]]; then
    defaults write "$DOMAIN" brailleDotSizeFraction -float "$PREV_DOT"
  else
    defaults delete "$DOMAIN" brailleDotSizeFraction 2>/dev/null || true
  fi
  if [[ $HAD_SRC -eq 1 ]]; then
    defaults write "$DOMAIN" brailleSource -string "$PREV_SRC"
  else
    defaults delete "$DOMAIN" brailleSource 2>/dev/null || true
  fi
}

cleanup() {
  local rc=$?
  restore_keys
  stop_saver || true
  exit $rc
}
trap cleanup EXIT INT TERM

mkdir -p "$OUT"

if [[ $BUILD -eq 1 ]]; then
  "$REPO/scripts/build-saver.sh" --log "$OUT/build.log"
fi

FAILED=0
fail() { echo "  FAIL  $1"; FAILED=1; }
ok()   { echo "  ok    $1"; }

# The saver instance, or give up loudly: every assertion below is about one
# instance nobody restarted, so losing it invalidates the run rather than
# failing it.
require_instance() {
  local pids; pids="$(instances)"
  if [[ -z "$pids" ]]; then
    echo "the saver instance is gone: $1" >&2
    blame_input
    exit 1
  fi
  printf "%s\n" "$pids" | head -1
}

# tslime's pid under the instance. The whole test rests on this: a relaunch
# changes it, an assignment does not.
tslime_pid() { views_of "$1" | head -1; }

# The presented rate, from the extension's own per-second counter. Reads the
# last few seconds only, so it reflects the rate now rather than an average
# across a change.
presented_now() {
  /usr/bin/log show --last 4s --predicate "subsystem == \"$SUBSYSTEM\"" --style compact 2>/dev/null |
    grep 'diag fps presented=' | sed -n 's/.*presented=\([0-9]*\).*/\1/p' | sort -n | tail -2 | head -1
}

# Start from a known rate rather than whatever was last accepted.
defaults write "$DOMAIN" frameRate -int 60

START_TS="$(date '+%Y-%m-%d %H:%M:%S')"
start_saver || exit 1
sleep "$SETTLE"

EXT="$(require_instance "before anything was changed")"
PID_START="$(tslime_pid "$EXT")"
echo
echo "instance $EXT, tslime $PID_START"

echo
echo "the stored rate is what the saver asks for:"
RATE_60="$(presented_now)"
if [[ -z "$RATE_60" ]]; then
  fail "the saver reported no presented rate at all"
elif [[ "$RATE_60" -ge 55 ]]; then
  ok "frameRate=60 presents ${RATE_60} fps"
else
  fail "frameRate=60 presents only ${RATE_60} fps"
fi

echo
echo "a braille change does NOT restart tslime:"
# The point of carrying the two groups behind separate callbacks. If this
# fails, every drag of a slider is killing a process.
defaults write "$DOMAIN" brailleDotSizeFraction -float 0.62
sleep "$SETTLE"
EXT="$(require_instance "after the braille change")"
PID_AFTER_BRAILLE="$(tslime_pid "$EXT")"
if [[ "$PID_AFTER_BRAILLE" == "$PID_START" ]]; then
  ok "tslime is still pid $PID_AFTER_BRAILLE"
else
  fail "tslime was restarted ($PID_START -> ${PID_AFTER_BRAILLE:-gone}) by a braille change"
fi

echo
echo "a frame-rate change DOES restart tslime, at the new rate:"
defaults write "$DOMAIN" frameRate -int 30
sleep "$SETTLE"
EXT="$(require_instance "after the drop to 30")"
PID_AFTER_30="$(tslime_pid "$EXT")"
if [[ -z "$PID_AFTER_30" ]]; then
  fail "tslime is gone after the drop to 30 -- the relaunch did not come back"
elif [[ "$PID_AFTER_30" == "$PID_START" ]]; then
  fail "tslime was never restarted (still pid $PID_START), so --fps never changed"
else
  ok "tslime relaunched ($PID_START -> $PID_AFTER_30)"
fi
RATE_30="$(presented_now)"
if [[ -z "$RATE_30" ]]; then
  fail "the saver reported no presented rate after the drop to 30"
elif [[ "$RATE_30" -le 34 && "$RATE_30" -ge 26 ]]; then
  ok "frameRate=30 presents ${RATE_30} fps"
else
  fail "frameRate=30 presents ${RATE_30} fps"
fi

echo
echo "and back up again:"
defaults write "$DOMAIN" frameRate -int 60
sleep "$SETTLE"
EXT="$(require_instance "after the return to 60")"
PID_AFTER_60="$(tslime_pid "$EXT")"
if [[ -n "$PID_AFTER_60" && "$PID_AFTER_60" != "$PID_AFTER_30" ]]; then
  ok "tslime relaunched ($PID_AFTER_30 -> $PID_AFTER_60)"
else
  fail "tslime did not relaunch on the way back up (${PID_AFTER_60:-gone})"
fi
RATE_BACK="$(presented_now)"
if [[ -n "$RATE_BACK" && "$RATE_BACK" -ge 55 ]]; then
  ok "frameRate=60 presents ${RATE_BACK} fps again"
else
  fail "frameRate=60 presents ${RATE_BACK:-?} fps after coming back up"
fi

echo
echo "a rate nobody should have stored falls back rather than being obeyed:"
# FrameRate has exactly two values. 144 is the mistake an open number field
# would have invited, and it must read as the default, not as 144.
defaults write "$DOMAIN" frameRate -int 144
sleep "$SETTLE"
EXT="$(require_instance "after the bad rate")"
RATE_BAD="$(presented_now)"
if [[ -n "$RATE_BAD" && "$RATE_BAD" -ge 55 ]]; then
  ok "frameRate=144 falls back to 60 (${RATE_BAD} fps presented)"
else
  fail "frameRate=144 left the saver at ${RATE_BAD:-?} fps"
fi

sleep 1
LOG="$OUT/extension.log"
/usr/bin/log show --start "$START_TS" --predicate "subsystem == \"$SUBSYSTEM\"" --style compact \
  > "$LOG" 2>/dev/null || true

echo
echo "the extension said so in its own log:"
if grep -q 'diag relaunching tslime at fps=30' "$LOG"; then
  ok "logged the relaunch at 30"
else
  fail "no 'relaunching tslime at fps=30' line"
fi
RELAUNCHES="$(grep -c 'diag relaunching tslime at fps=' "$LOG" || true)"
echo "  ${RELAUNCHES} relaunch(es) logged across the run"

echo
echo "log: $LOG"
if [[ $FAILED -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit $FAILED
