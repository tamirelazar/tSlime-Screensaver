#!/bin/bash
# PROTOTYPE — throwaway. One command: capture (unless frames exist), build, render.
# usage: ./run.sh [round-1.tsv]
set -euo pipefail
cd "$(dirname "$0")"
LIST=${1:-round-1.tsv}; ROUND=$(basename "$LIST" .tsv)
[ -n "$(ls frames/$ROUND 2>/dev/null)" ] || ./capture.sh "$LIST" 8 30
mkdir -p .build
swiftc -O -o .build/ThemeLook ThemeLook.swift
.build/ThemeLook "$LIST"
open "shots/$ROUND/contact-sheet.png" "shots/$ROUND/crop-sheet.png"
