#!/bin/bash
# PROTOTYPE: run only during an approved live capture with immediate locking.
# Capture as soon as UI visibility and an extension PID coincide.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build
clang -Wall -Wextra -Werror observe-overlap.c -o .build/observe-overlap
capture_dir="captures/$(date +%Y%m%d-%H%M%S)-triggered"
mkdir -p "$capture_dir"
echo "Arming capture; saver starts in ten seconds. Press Shift once after five seconds of animation."
(
  captured=0
  while IFS= read -r sample; do
    printf '%s\n' "$sample" >> "$capture_dir/overlap.txt"
    if [[ "$sample" == *'candidate_overlap=1'* && "$captured" == 0 ]]; then
      captured=1
      for shot in 0 1 2; do
        date -u '+%Y-%m-%dT%H:%M:%SZ' > "$capture_dir/overlap-$shot.txt"
        /usr/sbin/screencapture -x "$capture_dir/overlap-$shot.png" 2>> "$capture_dir/overlap-$shot.txt" || true
        sleep 0.25
      done
    fi
  done < <(.build/observe-overlap 40 || true)
) &
reader_pid=$!
sleep 10
open -a /System/Library/CoreServices/ScreenSaverEngine.app
wait "$reader_pid"
echo "Capture complete: $PWD/$capture_dir"
