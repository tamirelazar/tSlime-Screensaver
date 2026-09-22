#!/bin/bash
# PROTOTYPE ONLY — native AppKit offscreen renderer, no display takeover.
set -euo pipefail
script_dir="$(cd "$(dirname "$0")" && pwd)"
cd "$script_dir"
mkdir -p .build shots /private/tmp/lock-cards-module-cache
swiftc -O -framework AppKit -framework CoreGraphics \
  -module-cache-path /private/tmp/lock-cards-module-cache \
  LockCards.swift -o .build/lock-cards
.build/lock-cards
