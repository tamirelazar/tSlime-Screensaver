#!/bin/bash
# PROTOTYPE — throwaway. One command: fetch fonts if missing, build, run.
set -euo pipefail
cd "$(dirname "$0")"
[ -f fonts/JuliaMono-Regular.ttf ] || ./fetch-fonts.sh
mkdir -p .build
swiftc -O -o .build/BrailleLook BrailleLook.swift
exec .build/BrailleLook "$@"
