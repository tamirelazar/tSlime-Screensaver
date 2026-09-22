#!/bin/bash
# PROTOTYPE: run only after the user agrees to a brief display takeover.
# Tap Shift about five seconds after the animation appears. Unlock after 20s.
set -euo pipefail
cd "$(dirname "$0")"
capture_dir="captures/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$capture_dir"
capture_frame() {
  local name="$1"
  date -u '+%Y-%m-%dT%H:%M:%SZ' > "$capture_dir/$name.txt"
  pgrep -fl 'AppexSaverMinimalExtension|/tslime' >> "$capture_dir/$name.txt" || true
  /usr/sbin/screencapture -x "$capture_dir/$name.png" 2>> "$capture_dir/$name.txt" || true
}
echo "Starting saver. Tap Shift after about five seconds; unlock after 20 seconds."
open -a /System/Library/CoreServices/ScreenSaverEngine.app
sleep 3
capture_frame 00-before-input
sleep 7
capture_frame 01-raised
sleep 8
capture_frame 02-raised-later
echo "Capture finished: $PWD/$capture_dir — you can unlock now."
