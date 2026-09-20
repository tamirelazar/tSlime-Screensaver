#!/bin/bash
#
# Checks the three braille sources on a live saver instance: that the two
# bundled faces register from inside the appex sandbox, that switching the
# source reaches an instance nobody restarted, and that the grid follows the
# face rather than staying at the old one.
#
# The grid is the part worth a script. Both bundled faces give a 9.50 pt cell
# against the system face's 10.00, and JetBrainsMono NFM a 21.50 pt line
# against 19.00, so a switch that changed the font but not the grid would look
# almost right — a slightly narrower frame, a row of black at the bottom —
# and stay wrong until someone measured it. Here it is an assertion.
#
# It also writes a PNG per source, because the remaining half of this is a
# look, and the look is judged by eye (#8).
#
# This takes the screen: it puts a real screensaver session up and captures it.
# Nothing here can put the screen back — ending a session takes real input —
# so it leaves the saver up and says so, exactly as measure-saver.sh does.
#
# usage: scripts/test-braille-fonts.sh [--out DIR] [--settle N] [--no-build]

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# start_saver / stop_saver / instances / blame_input, without arming that
# script's EXIT trap or launching anything.
#
# This has to come before this script's own configuration, not after. The hook
# returns partway down measure-saver.sh, so everything above it has already run
# — including its REPO, OUT and BUILD defaults, which are the same names used
# here. Sourcing second silently reset --out and --no-build to its values.
# Its argument parser has also already run, so the positionals are cleared
# across the source: it would reject --settle, which is not one of its options.
ARGS=("$@")
set --
MEASURE_SAVER_SOURCE_ONLY=1 source "$REPO/scripts/measure-saver.sh"
set -- "${ARGS[@]:-}"
[[ ${#ARGS[@]} -eq 0 ]] && set --

OUT="${TMPDIR:-/tmp}/appexsaver-braille-$(date +%Y%m%d-%H%M%S)"
SETTLE=4
BUILD=1
DOMAIN=net.aerialscreensaver.AppexSaverMinimal
SUBSYSTEM=net.aerialscreensaver.AppexSaverMinimal

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    --settle) SETTLE="$2"; shift 2 ;;
    --no-build) BUILD=0; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# The faces, and the PostScript names CoreText must resolve them to. Kept here
# rather than derived, so a rename in the bundle fails this script instead of
# quietly falling back to the system face.
FACE_JULIA="JuliaMono-Bold"
FACE_JETBRAINS="JetBrainsMonoNFM-Regular"

# Restore whatever the user had, whether this passes, fails or is interrupted.
HAD_SOURCE=0
PREV_SOURCE=""
if PREV_SOURCE="$(defaults read "$DOMAIN" brailleSource 2>/dev/null)"; then HAD_SOURCE=1; fi

restore_source() {
  if [[ $HAD_SOURCE -eq 1 ]]; then
    defaults write "$DOMAIN" brailleSource -string "$PREV_SOURCE"
  else
    defaults delete "$DOMAIN" brailleSource 2>/dev/null || true
  fi
}

cleanup() {
  local rc=$?
  restore_source
  stop_saver || true
  exit $rc
}
trap cleanup EXIT INT TERM

mkdir -p "$OUT"

if [[ $BUILD -eq 1 ]]; then
  "$REPO/scripts/build-saver.sh" --log "$OUT/build.log"
fi

# Everything the extension logged from here on. Taken as one window at the end
# rather than per source, because `log show` costs a second or two and the
# switches are what is being timed.
START_TS="$(date '+%Y-%m-%d %H:%M:%S')"

start_saver || exit 1
sleep "$SETTLE"

SOURCES=(procedural juliaMonoBold jetBrainsMonoNerdFontMono)

for source in "${SOURCES[@]}"; do
  defaults write "$DOMAIN" brailleSource -string "$source"
  sleep "$SETTLE"
  if [[ -z "$(instances)" ]]; then
    echo "the saver instance is gone before $source could be captured" >&2
    blame_input
    exit 1
  fi
  # -x: no shutter sound, and no other input either -- a sound is harmless but
  # anything that looks like input to loginwindow would end the session.
  screencapture -x "$OUT/$source.png"
  echo "captured $source"
done

sleep 1
LOG="$OUT/extension.log"
/usr/bin/log show --start "$START_TS" --predicate "subsystem == \"$SUBSYSTEM\"" --style compact \
  > "$LOG" 2>/dev/null || true

# ---- assertions -------------------------------------------------------------

FAILED=0
check() {                             # $1 = what, $2 = pattern
  if grep -q "$2" "$LOG"; then
    echo "  ok    $1"
  else
    echo "  FAIL  $1"
    FAILED=1
  fi
}

# The grid the source ends on, from the last `diag font ->` line naming that
# face, or from `diag launchProcess grid=` for the system face.
grid_after() {                        # $1 = font name as the log prints it
  grep "diag font -> $1 " "$LOG" | tail -1 |
    sed -n 's/.* -> \([0-9]*x[0-9]*\) running=.*/\1/p'
}

echo
echo "registration (inside the appex sandbox):"
check "$FACE_JULIA registered"     "diag font registered $FACE_JULIA"
check "$FACE_JETBRAINS registered" "diag font registered $FACE_JETBRAINS"
if grep -q "falling back to the system monospaced face" "$LOG"; then
  echo "  FAIL  a face fell back to the system monospaced face"
  FAILED=1
else
  echo "  ok    no face fell back to the system monospaced face"
fi

echo
echo "the switch reached a live instance:"
for source in "${SOURCES[@]}"; do
  check "source=$source applied" "diag braille applied source=$source"
done

echo
echo "the grid followed the face:"
BASE_GRID="$(grep 'diag launchProcess grid=' "$LOG" | tail -1 | sed -n 's/.*grid=\([0-9]*x[0-9]*\).*/\1/p')"
JULIA_GRID="$(grid_after "$FACE_JULIA")"
JETBRAINS_GRID="$(grid_after "$FACE_JETBRAINS")"
echo "  system face  ${BASE_GRID:-?}"
echo "  $FACE_JULIA  ${JULIA_GRID:-?}"
echo "  $FACE_JETBRAINS  ${JETBRAINS_GRID:-?}"
for pair in "$FACE_JULIA:$JULIA_GRID" "$FACE_JETBRAINS:$JETBRAINS_GRID"; do
  name="${pair%%:*}"; grid="${pair#*:}"
  if [[ -z "$grid" ]]; then
    echo "  FAIL  $name never resized the grid"
    FAILED=1
  elif [[ "$grid" == "$BASE_GRID" ]]; then
    echo "  FAIL  $name kept the system face's grid ($grid)"
    FAILED=1
  else
    echo "  ok    $name resized the grid to $grid"
  fi
done

echo
echo "the saver kept presenting across the switches:"
# The lowest per-second presented count after the first switch. A font change
# drops every glyph cache and soft-resets the terminal, so one slow second is
# expected; a run of them is the switch stalling the renderer.
LOW="$(grep 'diag fps presented=' "$LOG" | sed -n 's/.*presented=\([0-9]*\).*/\1/p' |
       sort -n | head -1)"
STALLED="$(grep 'diag fps presented=' "$LOG" | sed -n 's/.*presented=\([0-9]*\).*/\1/p' |
           awk '$1 < 30 {n++} END {print n + 0}')"
echo "  slowest second ${LOW:-?} fps, ${STALLED} second(s) under 30"
if [[ "${STALLED:-0}" -gt 3 ]]; then
  echo "  FAIL  more than one second per switch was slow"
  FAILED=1
else
  echo "  ok    no sustained stall"
fi

echo
echo "no caret was left on screen:"
# A font change used to soft-reset the terminal, which cleared DECTCEM and so
# un-hid the cursor tslime had hidden with `civis` at startup -- leaving a grey
# caret in the corner that nothing took away again (fixed in the fork, see
# "Re-grid a font change the way a window resize does"). Nothing tslime draws
# is neutral grey, so counting grey pixels is the whole test.
cat > "$OUT/caret.swift" <<'SWIFT'
import AppKit
for path in CommandLine.arguments.dropFirst() {
    guard let img = NSImage(contentsOfFile: path),
          let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("\(path) unreadable"); continue
    }
    let w = cg.width, h = cg.height
    var px = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        print("\(path) unreadable"); continue
    }
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    var n = 0
    for i in stride(from: 0, to: px.count, by: 4) {
        let r = Int(px[i]), g = Int(px[i + 1]), b = Int(px[i + 2])
        if r > 90 && r < 190 && abs(r - g) < 12 && abs(g - b) < 12 { n += 1 }
    }
    print("\((path as NSString).lastPathComponent.replacingOccurrences(of: ".png", with: "")) \(n)")
}
SWIFT
if xcrun swiftc -O "$OUT/caret.swift" -o "$OUT/caret" 2>"$OUT/caret-build.log"; then
  while read -r source grey; do
    if [[ "$grey" -lt 40 ]]; then
      echo "  ok    $source ($grey grey px)"
    else
      echo "  FAIL  $source has a caret on screen ($grey grey px)"
      FAILED=1
    fi
  done < <("$OUT/caret" "$OUT"/*.png)
else
  echo "  FAIL  could not build the caret probe (see $OUT/caret-build.log)"
  FAILED=1
fi

echo
echo "captures (judge the look by eye):"
for source in "${SOURCES[@]}"; do echo "  $OUT/$source.png"; done
echo "log: $LOG"

echo
if [[ $FAILED -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit $FAILED
