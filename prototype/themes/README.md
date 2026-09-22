# PROTOTYPE — which themes ship? (ticket #39)

Throwaway. Answers one question: which sets of tslime colours — inner
background, outer background, accent (frame ring and chrome) and palette —
the saver ships as themes, and which is the default. Not the screensaver,
not a terminal. Colour decisions only.

```
./run.sh [round-N.tsv]          # capture (if no frames yet), build, render, open the sheets
./capture.sh round-N.tsv 8 30   # one real frame per candidate: seconds, fps, [stage]
.build/ThemeLook round-N.tsv    # render frames/<round>/ -> shots/<round>/
```

- `round-N.tsv` — the candidates of one round: id, name, palette, inner, outer,
  accent (hex or `-` for tslime's own default), and the idea the candidate tests.
- `frames/<round>/` — one real tslime frame per candidate, captured with
  `tmux new-session -x 190 -y 56 'tslime --window-frame glow --skip-warmup --seed 7 <theme flags>'`
  and `capture-pane -p -e -N` (truecolour per cell, trailing spaces kept; tmux
  carries the pen across lines, so the parser does too). `<round>-late` is the
  same round after more simulation steps: the dense steady state.
- `shots/<round>/` — one PNG per candidate at the saver's metrics, plus
  `contact-sheet.png` (every candidate, whole frame, scaled down) and
  `crop-sheet.png` (every candidate, top-left of the window, real 2x pixels).

What it copies so the judgment transfers: SwiftTerm's cell rule on SF Mono
16 pt (10x19 pt), block elements as rects with the shades at .25/.5/.75 alpha,
the fork's procedural braille dots at this Mac's saved settings (0.69 of the
pitch, round), the view's black behind anything tslime does not paint.
