#!/bin/bash
#
# Measures what each braille source costs at 60 fps (issue #25): procedural,
# JuliaMono Bold, JetBrainsMono NFM, each on a fresh saver instance.
#
# A fresh instance applies the saved brailleSource before it launches tslime,
# and every measure-saver.sh run kills the instance and measures WallpaperAgent's
# replacement -- so setting the domain key between invocations measures each
# source on a new instance, with no mid-run switch. Each run's log.txt carries
# `diag braille applied source=` and the launch grid as proof of what ran.
#
# The sequence is A B C A B C with --runs 2 each: twelve 20 s windows, about
# ten minutes, from an idle machine (any input dismisses the saver). The
# user's brailleSource and frameRate are restored on exit, whatever happens.
#
# This takes the screen, and cannot put it back: press a key when it is done.
#
# usage: scripts/measure-braille-sources.sh [--out DIR] [--runs N]

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAIN=net.aerialscreensaver.AppexSaverMinimal
OUT="${TMPDIR:-/tmp}/appexsaver-sources-$(date +%Y%m%d-%H%M%S)"
RUNS=2
SEQ=(procedural juliaMonoBold jetBrainsMonoNerdFontMono procedural juliaMonoBold jetBrainsMonoNerdFontMono)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
mkdir -p "$OUT"

PREV_SOURCE="$(defaults read "$DOMAIN" brailleSource 2>/dev/null || echo __none__)"
PREV_RATE="$(defaults read "$DOMAIN" frameRate 2>/dev/null || echo __none__)"
restore() {
  if [[ "$PREV_SOURCE" == "__none__" ]]; then defaults delete "$DOMAIN" brailleSource 2>/dev/null || true
  else defaults write "$DOMAIN" brailleSource -string "$PREV_SOURCE"; fi
  if [[ "$PREV_RATE" == "__none__" ]]; then defaults delete "$DOMAIN" frameRate 2>/dev/null || true
  else defaults write "$DOMAIN" frameRate -int "$PREV_RATE"; fi
  echo "restored brailleSource=$PREV_SOURCE frameRate=$PREV_RATE"
}
trap restore EXIT

echo "idle: $(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {gsub(/[^0-9]/,"",$NF); print int($NF/1e9); exit}')s since last input"
"$REPO/scripts/build-saver.sh" --log "$OUT/build.log" || exit 1
defaults write "$DOMAIN" frameRate -int 60

i=0
for src in "${SEQ[@]}"; do
  i=$((i+1)); dir="$OUT/$(printf '%02d' $i)-$src"
  defaults write "$DOMAIN" brailleSource -string "$src"
  echo; echo "=========== $i/${#SEQ[@]} $src"
  "$REPO/scripts/measure-saver.sh" --no-build --keep-running --runs "$RUNS" --out "$dir"
  # Prove which source and grid each window actually ran.
  for r in "$dir"/run*; do
    [[ -d "$r" ]] || continue
    echo "  $(basename "$r"): $(grep -o 'diag braille applied source=[A-Za-z]*' "$r/log.txt" | sort -u | tr '\n' ' ')$(grep -o 'diag launchProcess grid=[0-9x]*' "$r/log.txt" | tail -1)"
  done
done

echo
echo "=========== summary per source (pooled across the A B C A B C windows)"
for src in procedural juliaMonoBold jetBrainsMonoNerdFontMono; do
  echo "--- $src"
  cat "$OUT"/*-"$src"/summary.txt 2>/dev/null | grep -E "fps|extension CPU|tslime CPU|renderer draw|pty read" | sed 's/^/  /'
done
echo "artifacts: $OUT"
echo "the screensaver is still on screen: press a key to end the session"
