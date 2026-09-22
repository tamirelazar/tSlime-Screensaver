# PROTOTYPE — which themes ship? (ticket #39)

Throwaway. Answers one question: which sets of tslime colours — palette,
inner field, outer field, accent (frame ring and chrome) — the saver ships as
themes, and which is the default. Not the screensaver, not a terminal. Colour
decisions only, judged by eye in the viewer.

```
./run.sh round-2.json     # expand the manifest, capture (if no frames yet), build, render, open the viewer
python3 design.py round-2 # regenerate round-2.json from the design source (design.py)
./palette.py "L,C,h@pos ..." [--ground HEX]   # bake one OKLCH gradient to tslime's 11 stops and check it
```

## Round 2 (concept-led) — how a round is built

- `design.py` — the design source: the overarching concept, the designed
  grays, and every candidate as a concept + decision tree with 3–4
  alternatives, each an OKLCH keyframe string plus field colours. `alt()`
  bakes the keyframes through `palette.py` and records the gamut check
  (chroma clipping, lightness drops, stop 0 vs the field). Emits `round-N.json`.
- `manifest.py` — expands `round-N.json` into `round-N.tsv` (every alternative,
  chosen flagged) for capture and render, and `viewer/data.js` for the viewer.
- `capture.sh round-N.tsv [seconds] [stage]` — one real tslime frame per row in a
  detached tmux pane (private server `-L themes`) at the saver's 190x56 grid,
  eight sessions in parallel, `capture-pane -p -e -N` (truecolour per cell,
  trailing spaces kept; tmux carries the pen across lines, so the parser does
  too). Round 2 captures a **mature** frame at 30 s (what a viewer mostly sees:
  a third as many trails as at 8 s, but spanning the whole palette; median
  intensity 0.4) and a **young** frame at 8 s (dense, faint: nothing above 0.75).
- `ThemeLook.swift` — renders each frame at the saver's metrics into
  `shots/<round>[-stage]/<id>-<name>.png` and `…-crop.png` (top-left of the
  window, real 2x pixels), plus `contact-sheet.png` (all), `crop-sheet.png` (all)
  and `queue-sheet.png` (the chosen alternatives only).
- `viewer/index.html` — the browser for a round: the queue is the chosen
  alternatives (tick "include drafts" for all), ← → to step, mature/young and
  real-pixel toggles, the palette ramp and field chips, the flags to copy, the
  candidate's concept and decision tree, this alternative's rationale and gamut
  check, why the chosen one won, and the other drafts from the same tree.
  Open it with `open viewer/index.html` (no server needed).
- `research/colour.md` — the colour-theory and painters research the concepts draw on.

## Round 1 (flat spread, superseded)

`round-1.tsv` and `shots/round-1/`: thirteen named palettes on black, one idea
each, no concept. Kept as the record of what was rejected: harsh black grounds,
palettes taken as found.

What the renderer copies so the judgment transfers: SwiftTerm's cell rule on
SF Mono 16 pt (10x19 pt), block elements as rects with the shades at .25/.5/.75
alpha, the fork's procedural braille dots at this Mac's saved settings (0.69 of
the pitch, round), the view's black behind anything tslime does not paint.
tslime's side: a custom `--palette` is 2–11 hex stops, evenly spaced across the
intensity range and interpolated linearly in sRGB (so a designed OKLCH ramp is
baked to 11 stops); the intensity mapping is logarithmic.
