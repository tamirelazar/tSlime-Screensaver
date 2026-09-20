#!/bin/bash
#
# Covers build-saver.sh's optimization check against synthetic build logs. The
# check is the reason the script exists — #3 traced a misleading measurement to
# an -Onone SwiftTerm — so it is worth proving it still refuses one now that a
# correct invocation contains the literal string "-Onone" (the package's own
# setting, overridden by the fork's -O after it).

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fails=0

# Re-use the script's own definitions rather than copying them, so this test
# cannot drift from what runs. Everything below the argument parsing is skipped.
EXEMPT_MODULES=$(awk -F'"' '/^EXEMPT_MODULES=/ { print $2 }' "$REPO/scripts/build-saver.sh")
eval "$(awk '/^effective_levels\(\) \{/, /^\}/' "$REPO/scripts/build-saver.sh")"
eval "$(awk '/^unoptimized_modules\(\) \{/, /^\}/' "$REPO/scripts/build-saver.sh")"

# The same two steps build-saver.sh runs, including the `echo` — a hand-written
# mirror used to pipe instead, which hid the blank line an empty build produces.
unoptimized() {
  local levels; levels=$(effective_levels "$1")
  echo "$levels" | unoptimized_modules
}

check() {
  local name="$1" log="$2" want="$3"
  local got; got=$(unoptimized "$log" | tr '\n' ';')
  if [[ "$got" == "$want" ]]; then
    echo "ok   $name"
  else
    echo "FAIL $name: want '$want', got '$got'"; fails=$((fails + 1))
  fi
}

line() { # module, flags... -> a plausible swiftc invocation
  local mod="$1"; shift
  echo "    /usr/bin/swiftc -incremental -module-name $mod $* -sdk /x -target arm64-apple-macos14.0"
}

# A correct build today: SwiftTerm carries its package's -Onone, then the -O the
# fork's manifest appends. The old `grep -Onone` would have refused this.
{ line SwiftTerm -Onone -enable-testing -O
  line AppexSaverMinimalExtension -O
  line PaperSaverKit -Onone
  line SwiftTermBuildInfoGenerator -Onone
} > "$TMP/good.log"
check "an -O-after-Onone build passes" "$TMP/good.log" ""

# The bug #3 found: the override is gone and nothing puts -O back.
{ line SwiftTerm -Onone -enable-testing
  line AppexSaverMinimalExtension -O
} > "$TMP/onone.log"
check "an -Onone SwiftTerm is refused" "$TMP/onone.log" "SwiftTerm -Onone;"

# Order matters the other way too: a trailing -Onone wins over a leading -O.
{ line SwiftTerm -O -enable-testing -Onone; } > "$TMP/reordered.log"
check "a trailing -Onone is refused" "$TMP/reordered.log" "SwiftTerm -Onone;"

# An exempt module may be unoptimized; a new one may not.
{ line PaperSaverKit -Onone
  line SomeNewPackage -Onone
} > "$TMP/newpkg.log"
check "an exempt module is allowed, a new one is not" "$TMP/newpkg.log" "SomeNewPackage -Onone;"

# An incremental build that recompiled nothing has no invocations to judge.
: > "$TMP/empty.log"
check "an empty log yields no complaint" "$TMP/empty.log" ""

# -Osize is not -O, and is not what any measurement here assumes.
{ line SwiftTerm -Osize; } > "$TMP/osize.log"
check "-Osize is refused" "$TMP/osize.log" "SwiftTerm -Osize;"

echo
if [[ $fails -eq 0 ]]; then echo "all checks passed"; else echo "$fails check(s) failed"; exit 1; fi
