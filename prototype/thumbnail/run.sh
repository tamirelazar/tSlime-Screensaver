#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build shots
if [[ "${1:-}" == "--capture" ]]; then python3 capture.py; fi
swiftc -O -module-cache-path .build/module-cache -o .build/Thumbnail Thumbnail.swift
.build/Thumbnail
echo "Open $PWD/index.html"
