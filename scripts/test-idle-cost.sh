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
# There is a second on-screen case, and it does not run ScreenSaverEngine:
# the screen-saver settings pane. Opening it starts *two* instances -- the
# preview instance drawing the thumbnail and the wallpaper instance painting
# the desktop behind the window -- both rendering, both expensive (#23). That
# is not the hidden state this check is about, so it REFUSES rather than
# failing: a FAIL would say something is wrong when nothing is, and a PASS
# would teach the check to accept two full-rate instances.
#
# Telling those two apart takes the extension's own log. `pgrep "System
# Settings"` is not the tell -- the pane can be open on any other page, and
# the app can be running with no window at all -- whereas each instance logs
# `ev=handshake.isPreview value=<bool>` against its pid at startup (#22). The
# thumbnail is the `true` one; the instance that handshook within a couple of
# seconds of it with `false` is the wallpaper instance.
#
# usage: scripts/test-idle-cost.sh [--window SECONDS] [--max-cpu PERCENT]
#        scripts/test-idle-cost.sh --self-test
#
# Run it with the screensaver not running. It refuses if a saver instance
# looks like it is on screen, because "cheap while hidden" says nothing about
# an instance that is doing its job.
#
# --self-test exercises the log parsing against captured lines and needs no
# saver, no settings pane and no log: the pane cannot be opened by script
# (#23), so the parser has to be testable without it.

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
SELF_TEST=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --window)    IDLE_WINDOW="$2"; shift 2 ;;
    --max-cpu)   IDLE_MAX_CPU="$2"; shift 2 ;;
    --self-test) SELF_TEST=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# --- reading roles out of the extension's log ----------------------------
#
# Kept as two pure functions -- text in, text out -- so --self-test can drive
# them from captured lines. Neither touches a process or the log.

# Reads `log show --style compact` text on stdin and prints one
#
#     <pid> <0|1> <seconds>
#
# per `ev=handshake.isPreview` event, in log order. Lines that are not a
# handshake, or that carry no pid or no readable value, are dropped rather
# than guessed at: a role this cannot read is a role it must not claim.
#
# The seconds are a monotone key, not an epoch: `log show` prints local time
# and this reads it as if it were UTC, so the number is offset by the zone.
# Every line carries the same offset and only *differences* are ever used, so
# the offset cancels -- and computing it here rather than shelling out to
# `date` keeps the whole parser one awk program with nothing to stub.
handshake_table() {
  awk '
    function days_from_civil(y, m, d,   era, yoe, doy, doe) {
      y -= (m <= 2)
      era = int((y >= 0 ? y : y - 399) / 400)
      yoe = y - era * 400
      doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
      doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
      return era * 146097 + doe - 719468
    }
    /ev=handshake\.isPreview/ {
      # The pid is in the Process[PID:TID] field. Found by shape, not by
      # position, because the process name is not the only thing before it.
      pid = ""; value = 0; have = 0
      for (i = 1; i <= NF; i++) {
        if (pid == "" && match($i, /\[[0-9]+:[0-9a-fA-F]+\]$/)) {
          tok = substr($i, RSTART + 1, RLENGTH - 2)
          sub(/:.*/, "", tok)
          pid = tok
        }
        if ($i ~ /^value=/) {
          v = substr($i, 7)
          if (v == "true")  { value = 1; have = 1 }
          if (v == "false") { value = 0; have = 1 }
        }
      }
      if (pid == "" || !have) next
      if ($1 !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) next
      if (split($1, D, "-") != 3 || split($2, T, ":") != 3) next
      printf "%s %d %.3f\n", pid, value,
        days_from_civil(D[1] + 0, D[2] + 0, D[3] + 0) * 86400 \
        + T[1] * 3600 + T[2] * 60 + T[3]
    }'
}

# How far apart two handshakes may be and still be the same settings pane.
# #23 measured both instances declaring within milliseconds of each other; two
# seconds is slack, not a claim.
PANE_TOLERANCE=2

# Decides whether the live instances are a settings pane, and names them.
#
#   $1 = live extension pids, whitespace separated
#   $2 = a handshake_table
#
# Prints "<thumbnail-pid> <wallpaper-pid>" when one of the live instances
# declared isPreview=1, with an empty second field if no live sibling
# handshook alongside it. Prints nothing otherwise -- including when the log
# says nothing about these pids, which is the case this must not turn into a
# refusal: an unreadable log is not evidence of a pane.
#
# The pid list is flattened to spaces first, because `instances` returns one
# pid per line and `awk -v` refuses a value with a newline in it -- it does
# not truncate or complain to the caller, it aborts the whole program with
# "newline in string". Caught by a real pane-open run, where the refusal
# silently never fired and the check fell through to two bare FAILs.
pane_roles() {
  local live
  live="$(printf '%s' "$1" | tr '\n\t' '  ')"
  printf "%s\n" "$2" | awk -v live="$live" -v tol="$PANE_TOLERANCE" '
    BEGIN {
      n = split(live, L, /[ \t\n]+/)
      for (i = 1; i <= n; i++) if (L[i] != "") alive[L[i]] = 1
    }
    # Last line per pid wins: one handshake per process, and a recycled pid
    # must be read as the process alive now, not the one that used to hold it.
    NF >= 3 { val[$1] = $2; at[$1] = $3 }
    END {
      thumb = ""
      for (p in val) {
        if (!(p in alive) || val[p] != 1) continue
        if (thumb == "" || at[p] > at[thumb]) thumb = p
      }
      if (thumb == "") exit 0
      wall = ""; best = tol
      for (p in val) {
        if (!(p in alive) || val[p] != 0) continue
        d = at[p] - at[thumb]; if (d < 0) d = -d
        if (d <= best) { best = d; wall = p }
      }
      print thumb, wall
    }'
}

# Seconds since a pid started, from ps`s [[dd-]hh:]mm:ss etime. Used only to
# size the log window, so a pid that is gone prints nothing and the caller
# falls back.
elapsed_seconds() {
  ps -o etime= -p "$1" 2>/dev/null | awk '
    { gsub(/^ +| +$/, "")
      d = 0; t = $0
      if (t ~ /-/) { split(t, P, "-"); d = P[1]; t = P[2] }
      n = split(t, C, ":")
      s = 0
      for (i = 1; i <= n; i++) s = s * 60 + C[i]
      printf "%d", d * 86400 + s }' || true
}

# --- self-test -----------------------------------------------------------

if [[ "$SELF_TEST" == "1" ]]; then
  ST_FAILED=0
  ok() { printf "  ok   %s\n" "$1"; }
  no() { printf "  FAIL %s\n" "$1"; ST_FAILED=1; }
  check() { if [[ "$2" == "$3" ]]; then ok "$1"; else no "$1 (expected [$3], got [$2])"; fi; }

  # Captured from a real pane-open run (#23): the two instances declare
  # 7 ms apart, and everything else in the subsystem is noise to this parser.
  PANE_LOG='Timestamp               Ty Process[PID:TID]
2026-09-19 21:14:02.118 Df AppexSaverMinimalExtension[31337:1a2b3c] [net.aerialscreensaver.AppexSaverMinimal:Lifecycle] probe t+0.007 ev=handshake.isPreview value=true source=declared
2026-09-19 21:14:02.125 Df AppexSaverMinimalExtension[31338:1a2b3d] [net.aerialscreensaver.AppexSaverMinimal:Lifecycle] probe t+0.006 ev=handshake.isPreview value=false source=declared
2026-09-19 21:14:02.400 Df AppexSaverMinimalExtension[31337:1a2b3c] [net.aerialscreensaver.AppexSaverMinimal:Terminal] diag launchProcess fps=30 source=override
2026-09-19 21:14:02.410 Df AppexSaverMinimalExtension[31338:1a2b3d] [net.aerialscreensaver.AppexSaverMinimal:Terminal] diag launchProcess fps=60 source=settings'

  echo "handshake_table"
  TABLE="$(printf "%s\n" "$PANE_LOG" | handshake_table)"
  check "keeps only the handshake lines" "$(printf "%s\n" "$TABLE" | grep -c .)" "2"
  check "reads the preview pid and value" "$(printf "%s\n" "$TABLE" | awk 'NR==1 {print $1, $2}')" "31337 1"
  check "reads the saver pid and value" "$(printf "%s\n" "$TABLE" | awk 'NR==2 {print $1, $2}')" "31338 0"
  check "times them 0.007s apart" \
    "$(printf "%s\n" "$TABLE" | awk 'NR==1 {a=$3} NR==2 {printf "%.3f", $3 - a}')" "0.007"
  # A value the parser cannot read is a role it must not claim. The fallback
  # handshake is a real line and carries a real value, so it is kept.
  check "drops a line with no pid" \
    "$(printf '%s\n' '2026-09-19 21:14:02.118 Df Ext [x:Lifecycle] ev=handshake.isPreview value=true' | handshake_table)" ""
  check "drops an unreadable value" \
    "$(printf '%s\n' '2026-09-19 21:14:02.118 Df Ext[1:a] [x:Lifecycle] ev=handshake.isPreview value=maybe' | handshake_table)" ""
  check "drops a line with no timestamp" \
    "$(printf '%s\n' 'probe ev=handshake.isPreview value=true Ext[1:a]' | handshake_table)" ""
  check "keeps a source=fallback handshake" \
    "$(printf '%s\n' '2026-09-19 21:14:02.118 Df Ext[1:a] [x:Lifecycle] ev=handshake.isPreview value=false source=fallback' | handshake_table | awk '{print $1, $2}')" "1 0"

  echo "pane_roles"
  check "names both instances of an open pane" "$(pane_roles "31337 31338" "$TABLE")" "31337 31338"
  # The shape `instances` actually returns. Passing it straight to `awk -v`
  # aborts the program with "newline in string", which is how the first
  # pane-open run got two bare FAILs instead of a refusal.
  check "takes a newline-separated pid list" \
    "$(pane_roles "$(printf '31337\n31338\n')" "$TABLE")" "31337 31338"
  check "names the thumbnail alone when its sibling is dead" \
    "$(pane_roles "31337" "$TABLE")" "31337 "
  # The ordinary case this check runs in, and the one it must not refuse on.
  check "says nothing when no live instance is a preview" "$(pane_roles "31338" "$TABLE")" ""
  check "says nothing when the log is silent about the live pids" \
    "$(pane_roles "40000 40001" "$TABLE")" ""
  check "says nothing for an empty table" "$(pane_roles "31337" "")" ""
  # A saver instance that merely started around the same time as a preview
  # instance that has since died is not this pane; and a false instance far
  # from the thumbnail is some other launch, not the desktop behind it.
  FAR="$(printf '%s\n' '31337 1 100.000' '31338 0 140.000')"
  check "will not pair a distant sibling" "$(pane_roles "31337 31338" "$FAR")" "31337 "
  # Pids are recycled. The later line is the process running now.
  RECYCLED="$(printf '%s\n' '31337 0 100.000' '31337 1 500.000' '31338 0 500.500')"
  check "reads the most recent handshake for a pid" \
    "$(pane_roles "31337 31338" "$RECYCLED")" "31337 31338"

  echo "elapsed_seconds"
  check "reports an integer for a live pid" \
    "$( [[ "$(elapsed_seconds $$)" =~ ^[0-9]+$ ]] && echo yes || echo no )" "yes"
  check "reports nothing for a dead pid" "$(elapsed_seconds 999999)" ""

  [[ "$ST_FAILED" == "0" ]] && echo "self-test: all checks passed" || echo "self-test: FAILED"
  exit "$ST_FAILED"
fi

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

# The settings pane is the other on-screen case, and it runs no engine. The
# log window is sized to the oldest live instance so a pane that has been open
# for an hour is still classified; `log show` is only asked for the Lifecycle
# category, which is a few lines per instance.
pids="$(instances)"
if [[ -n "$pids" ]]; then
  oldest=0
  for p in $pids; do
    e="$(elapsed_seconds "$p")"
    [[ -n "$e" && "$e" -gt "$oldest" ]] && oldest="$e"
  done
  table="$(/usr/bin/log show --last "$((oldest + 60))s" \
             --predicate "subsystem == \"$SUBSYSTEM\" && category == \"Lifecycle\"" \
             --style compact 2>/dev/null | handshake_table)"
  roles="$(pane_roles "$pids" "$table")"
  if [[ -n "$roles" ]]; then
    thumb="${roles%% *}"; wall="${roles#* }"
    if [[ -n "$wall" ]]; then
      echo "REFUSED: pid $thumb is the settings thumbnail (isPreview=1), pid $wall is the"
      echo "         desktop preview behind the pane; close System Settings and retry."
      echo "         The thumbnail is pinned at 30 fps (#29); the desktop preview is a"
      echo "         saver instance and renders at the saved rate, by design (#28)."
    else
      echo "REFUSED: pid $thumb is the settings thumbnail (isPreview=1); close System"
      echo "         Settings and retry. It renders while the pane is open, pinned at"
      echo "         30 fps (#29)."
    fi
    echo "         Either way that is not the hidden state this check measures, so it"
    echo "         is neither a pass nor a failure."
    exit 2
  fi
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

# Re-read deliberately: the refusal above took a census seconds ago, and an
# instance that has died since must not be sampled as if it were alive.
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
