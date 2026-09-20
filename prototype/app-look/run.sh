#!/bin/bash
# PROTOTYPE — throwaway. One command: build, then render every candidate in every state, or open the live window.
#   ./run.sh <outdir> [--light]     # PNGs + contact sheets
#   ./run.sh --live                 # a real window with a switcher strip
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build
swiftc -O -o .build/AppLook AppLook.swift
exec .build/AppLook "$@"
