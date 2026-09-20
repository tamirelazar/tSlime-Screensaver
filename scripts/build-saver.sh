#!/bin/bash
#
# Builds the screensaver and refuses to hand back a build that isn't optimized.
#
# Xcode compiles a Swift package target with the *package's* own build settings,
# so a Debug build gives it -Onone no matter what the project sets — and -Onone
# SwiftTerm is roughly half the frame rate. Our SwiftTerm fork now asks for -O
# in its own Package.swift, so a plain xcodebuild or Xcode ⌘B is optimized too;
# this script no longer overrides SWIFT_OPTIMIZATION_LEVEL, and builds exactly
# what ⌘B builds. What it keeps is the check: a measurement is only worth
# anything if the thing measured was optimized.
#
# usage: scripts/build-saver.sh [--config Debug|Release] [--log PATH] [-- <extra xcodebuild args>]

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG=Debug
LOG="${TMPDIR:-/tmp}/appexsaver-build-$(date +%Y%m%d-%H%M%S).log"

# Modules that never run in the screensaver's frame loop, and so may be -Onone:
# PaperSaverKit is linked into the host app only (the extension links SwiftTerm
# and ScreenSaver.framework), and SwiftTermBuildInfoGenerator is a build-time
# tool that never ships. Anything else unoptimized is a real problem, so a new
# package added to the extension trips this check until it is dealt with.
EXEMPT_MODULES="PaperSaverKit SwiftTermBuildInfoGenerator"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2 ;;
    --log) LOG="$2"; shift 2 ;;
    --) shift; break ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

echo "building $CONFIG (log: $LOG)"
set +e
# SwiftTerm ships a build-tool plugin (SwiftTermBuildInfoPlugin), and Xcode
# asks for it to be trusted once per package identity. Since SwiftTerm is now
# pinned to our own fork, that prompt has no answer in a non-interactive build,
# so the validation is skipped here.
xcodebuild -project "$REPO/AppexSaverMinimal.xcodeproj" \
  -scheme AppexSaverMinimal \
  -configuration "$CONFIG" \
  -skipPackagePluginValidation \
  "$@" build >"$LOG" 2>&1
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "BUILD FAILED (exit $status); last lines of $LOG:" >&2
  tail -30 "$LOG" >&2
  exit $status
fi

# One compiler invocation can carry several optimization flags — the package's
# own -Onone, then the fork's -O after it — and the *last* one wins. So read the
# effective level per module instead of grepping for -Onone anywhere in the log.
effective_levels() {
  awk '
    /-module-name [A-Za-z0-9_]+/ {
      mod = ""; lvl = ""
      for (i = 1; i <= NF; i++) {
        if ($i == "-module-name") mod = $(i + 1)
        else if ($i == "-O" || $i == "-Onone" || $i == "-Osize") lvl = $i
      }
      if (mod != "" && lvl != "") print mod, lvl
    }
  ' "$1" | sort -u
}

# The refusal rule itself, kept a function so scripts/test-build-saver.sh can
# eval it instead of restating it — a hand-written copy of this rule is what let
# the blank-line bug below live through six passing checks.
#
# NF == 2 is not cosmetic: an incremental build that recompiled nothing produces
# no levels at all, and a caller that pipes an empty string through `echo` hands
# awk one blank line — a module named "" at level "", which is not -O, is not
# exempt, and used to refuse the build with an empty list of offenders.
unoptimized_modules() {               # reads levels on stdin
  awk -v exempt=" $EXEMPT_MODULES " '
    NF == 2 && $2 != "-O" && index(exempt, " " $1 " ") == 0 { print $1, $2 }'
}

LEVELS=$(effective_levels "$LOG")
UNOPTIMIZED=$(echo "$LEVELS" | unoptimized_modules)

if [[ -n "$UNOPTIMIZED" ]]; then
  echo "REFUSING: modules were compiled unoptimized:" >&2
  echo "$UNOPTIMIZED" >&2
  echo "(full log: $LOG)" >&2
  exit 1
fi

# An incremental build that recompiled nothing is fine: changing the optimization
# level changes the build description, so unchanged settings imply -O products.
OPTIMIZED=$(echo "$LEVELS" | awk '$2 == "-O" { printf "%s ", $1 }')
PRODUCT=$(grep -oE "/.*/Build/Products/$CONFIG/AppexSaverMinimal.app" "$LOG" | head -1 || true)

echo "build ok; optimized this run: ${OPTIMIZED:-(nothing recompiled)}"
if [[ -n "$PRODUCT" ]]; then echo "product: $PRODUCT"; fi
echo "registered appex:"
pluginkit -m -v -p com.apple.screensaver | grep AppexSaverMinimal || echo "  (not registered — open the host app once)"
