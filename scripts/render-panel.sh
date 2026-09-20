#!/bin/bash
#
# Renders the settings panel to a PNG without taking the screen: the tuning
# surface covers every display at screensaver level, so this is the only way
# to look at the panel's layout while the machine is in use. It is the real
# SettingsPanelView, at 2x in dark appearance, over a flat fill where the
# material would be (see SaverTuningSurface.renderPanelIfAsked).
#
# usage: scripts/render-panel.sh [--out PATH] [--no-build]

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/appexsaver-panel-$(date +%Y%m%d-%H%M%S).png"
BUILD=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --no-build) BUILD=0; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

LOG="${TMPDIR:-/tmp}/appexsaver-panel-build.log"
if [[ $BUILD -eq 1 ]]; then
  "$REPO/scripts/build-saver.sh" --log "$LOG" >/dev/null
fi
PRODUCT="$(xcodebuild -project "$REPO/AppexSaverMinimal.xcodeproj" -scheme AppexSaverMinimal -configuration Debug \
  -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR = / {print $3; exit}')/AppexSaverMinimal.app"
[[ -x "$PRODUCT/Contents/MacOS/AppexSaverMinimal" ]] || { echo "no host app at $PRODUCT" >&2; exit 1; }

"$PRODUCT/Contents/MacOS/AppexSaverMinimal" --render-panel "$OUT"
