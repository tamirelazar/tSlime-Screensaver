#!/bin/bash
#
# Regression test for the silent failures in measure-saver.sh (issue #18).
#
# Both failures were on the path where the measured instance is gone: reading a
# dead pid took `set -e` down mid-run, and the one reading that survived would
# have reported a negative CPU percentage as if it were a measurement. Neither
# needs a saver to reproduce, so this runs anywhere.
#
# usage: scripts/test-measure-saver.sh

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0

ok() { printf "  ok   %s\n" "$1"; }
no() { printf "  FAIL %s\n" "$1"; FAILED=1; }
check() { if [[ "$2" == "$3" ]]; then ok "$1"; else no "$1 (expected [$3], got [$2])"; fi; }

# A pid that is certainly gone: spawn one and reap it.
sleep 0 & DEAD=$!; wait $DEAD 2>/dev/null
LIVE=$$

echo "sourcing helpers from measure-saver.sh"
MEASURE_SAVER_SOURCE_ONLY=1 source "$REPO/scripts/measure-saver.sh"
# The sourced script turns on errexit for this shell too. Off again, so a helper
# that fails is reported as a FAIL rather than killing the harness -- errexit is
# tested deliberately below, in a subshell that opts back into it.
set +e

echo "cpu_seconds"
check "reports a number for a live pid" "$( [[ -n "$(cpu_seconds "$LIVE")" ]] && echo yes || echo no )" "yes"
check "reports nothing for a dead pid" "$(cpu_seconds "$DEAD")" ""
# The original bug: ps exits 1 for a dead pid and pipefail propagated it, so a
# bare assignment from this function aborted the whole script under set -e.
(
  set -euo pipefail
  MEASURE_SAVER_SOURCE_ONLY=1 source "$REPO/scripts/measure-saver.sh"
  v=$(cpu_seconds "$DEAD")
  exit 0
) >/dev/null 2>&1
check "assigning from a dead pid survives set -e + pipefail" "$?" "0"

echo "cpu_seconds_all"
check "reports nothing for an empty list" "$(cpu_seconds_all "")" ""
check "reports nothing if any pid is dead" "$(cpu_seconds_all "$LIVE $DEAD")" ""
check "reports a number when all are alive" "$( [[ -n "$(cpu_seconds_all "$LIVE")" ]] && echo yes || echo no )" "yes"

echo "pct"
check "computes a percentage" "$(pct 12.00 10.00 20)" "10.0"
# The reading that did not crash: bc parsed "( - 10.00)" as unary minus and
# returned -50.0%, a wrong number indistinguishable from a real one.
check "refuses a missing end reading" "$(pct "" 10.00 20)" "n/a"
check "refuses a missing start reading" "$(pct 12.00 "" 20)" "n/a"
check "refuses a zero-length window" "$(pct 12.00 10.00 0)" "n/a"

echo "idle_seconds"
check "reports an integer" "$( [[ "$(idle_seconds)" =~ ^[0-9]+$ ]] && echo yes || echo no )" "yes"

echo "count"
check "counts an empty list as 0" "$(count "")" "0"
check "counts two pids" "$(count "$(printf '111\n222')")" "2"

# Issue #19: a run now identifies its instance as the one WallpaperAgent brings
# back after the run kills the current one, so this is the whole selection rule.
echo "new_since"
check "finds the replacement" "$(new_since "$(printf '111')" "$(printf '222')")" "222"
check "reports nothing when nothing changed" "$(new_since "$(printf '111')" "$(printf '111')")" ""
check "ignores survivors" "$(new_since "$(printf '111\n222')" "$(printf '222\n333')")" "333"
check "reports every newcomer" "$(new_since "" "$(printf '111\n222')")" "$(printf '111\n222')"
# A pid that is a prefix of another must not count as present: 11 surviving
# would otherwise hide 111, and the run would measure the old instance.
check "matches pids whole, not by prefix" "$(new_since "$(printf '11')" "$(printf '111')")" "111"

if [[ $FAILED -eq 0 ]]; then echo "all checks passed"; else echo "FAILURES"; fi
exit $FAILED
