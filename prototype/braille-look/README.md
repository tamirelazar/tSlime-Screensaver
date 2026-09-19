# PROTOTYPE — how should braille look? (ticket #8)

Throwaway. Answers one question: which braille treatment the saver should use,
and with what dot shape and size. Not the screensaver, not a terminal.

```
./run.sh                       # fetch fonts if missing, build, open the comparison
./run.sh --png <dir> [frame] [col] [row] [cols] [rows] [zoom]   # headless contact sheet
```

- `frames/` — four real tslime frames, captured with
  `tmux new-session -d -x 190 -y 56 'tslime --window-frame glow'` + `capture-pane -p -e`
  (truecolour per cell, as tslime actually emits it).
- Fonts are downloaded by `fetch-fonts.sh` into `fonts/` (gitignored) and
  registered per-process with `CTFontManagerRegisterFontsForURL(..., .process, ...)`
  — nothing is installed system-wide.

What it copies from SwiftTerm 1.20, so the judgment transfers:

- cell size from the primary font — `ceil((ascent+descent+leading) * scale) / scale`
  and the `"W"` advance, snapped to the pixel grid (`AppleTerminalView.computeFontDimensions`)
- `U+2580..U+259F` drawn as rects, shades at alpha .25/.5/.75 (`BlockElementRenderer`),
  in every variant — the frame's `██▓▓▒` glow border comes out solid next to the stipple
- per-cell glyph placement (what the Metal path does: `originX = column * cellWidthPx`),
  with a "natural run advance" mode to show the Apple Symbols overrun

Everything renders offscreen at 2x and blits with nearest-neighbour, so 1x is the
real pixel grid and the loupe magnifies real pixels rather than resampling.

Keys: arrows pan (shift = fast) · 1..6 toggle variants · z zoom · f next frame
