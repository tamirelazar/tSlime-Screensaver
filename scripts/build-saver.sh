#!/bin/bash
#
# Builds the screensaver with Swift optimization on for every target, and refuses
# to hand back a build that isn't optimized.
#
# Xcode compiles Swift package targets (SwiftTerm, PaperSaverKit) with their own
# build settings: a Debug build gives them -Onone no matter what the project sets,
# and -Onone SwiftTerm is roughly half the frame rate of -O SwiftTerm. Only a
# command-line override outranks the package's own setting, so every measurement
# on this repo goes through this script.
#
# usage: scripts/build-saver.sh [--config Debug|Release] [--log PATH] [-- <extra xcodebuild args>]

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG=Debug
LOG="${TMPDIR:-/tmp}/appexsaver-build-$(date +%Y%m%d-%H%M%S).log"

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
xcodebuild -project "$REPO/AppexSaverMinimal.xcodeproj" \
  -scheme AppexSaverMinimal \
  -configuration "$CONFIG" \
  SWIFT_OPTIMIZATION_LEVEL=-O \
  "$@" build >"$LOG" 2>&1
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "BUILD FAILED (exit $status); last lines of $LOG:" >&2
  tail -30 "$LOG" >&2
  exit $status
fi

# Any -Onone in a compiler invocation means some module was built unoptimized.
# An incremental build that recompiled nothing is fine: changing the optimization
# level changes the build description, so unchanged settings imply -O products.
if grep -q -- "-Onone" "$LOG"; then
  echo "REFUSING: modules were compiled with -Onone:" >&2
  grep -oE "module-name [A-Za-z0-9_]+ -Onone" "$LOG" | sort -u >&2
  echo "(full log: $LOG)" >&2
  exit 1
fi

OPTIMIZED=$(grep -oE "module-name [A-Za-z0-9_]+ -O" "$LOG" | sort -u | sed 's/module-name //' | tr '\n' ' ' || true)
PRODUCT=$(grep -oE "/.*/Build/Products/$CONFIG/AppexSaverMinimal.app" "$LOG" | head -1 || true)

echo "build ok; optimized this run: ${OPTIMIZED:-(nothing recompiled)}"
if [[ -n "$PRODUCT" ]]; then echo "product: $PRODUCT"; fi
echo "registered appex:"
pluginkit -m -v -p com.apple.screensaver | grep AppexSaverMinimal || echo "  (not registered — open the host app once)"
