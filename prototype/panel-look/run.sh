#!/bin/bash
# PROTOTYPE — throwaway. One command: build, render every candidate over a captured frame.
#   ./run.sh <outdir> [frame-index]
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build
swiftc -O -o .build/PanelLook PanelLook.swift
exec .build/PanelLook "$@"
