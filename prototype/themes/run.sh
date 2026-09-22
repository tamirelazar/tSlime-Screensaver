#!/bin/bash
# PROTOTYPE — throwaway. One command per round: expand the manifest, capture
# (unless frames exist), build, render, open the viewer.
# usage: ./run.sh round-2.json
set -euo pipefail
cd "$(dirname "$0")"
M=${1:-round-2.json}; ROUND=$(basename "$M" .json)
./manifest.py "$M"
[ -n "$(ls frames/$ROUND 2>/dev/null)" ] || ./capture.sh "$ROUND.tsv" 30
[ -n "$(ls frames/$ROUND-young 2>/dev/null)" ] || ./capture.sh "$ROUND.tsv" 8 young
mkdir -p .build
swiftc -O -o .build/ThemeLook ThemeLook.swift
.build/ThemeLook "$ROUND.tsv"
.build/ThemeLook "$ROUND.tsv" young
open viewer/index.html
