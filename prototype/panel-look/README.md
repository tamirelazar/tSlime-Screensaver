# PROTOTYPE — how should the settings panel look? (ticket #26)

Throwaway. Answers one question: where the saver's settings panel sits over a
live full-screen render, how big and how opaque it is, how its frame-rate
control shows what it costs, how the two fractions read, and how Accept,
Discard and Exit are ranked. Not the host app, not the real panel.

```
./run.sh <outdir> [frame-index]     # build, composite every candidate over one captured frame
./run.sh shots/trails 1             # the run in this directory
./run.sh shots/dense 3
```

- `frames/` — the four real tslime frames from `prototype/braille-look`
  (`tmux ... -x 190 -y 56` + `capture-pane -p -e`, truecolour per cell).
- The backdrop is drawn the way the saver draws it today: 16 pt SF Mono
  metrics, grid anchored top-left of 1920x1080 points, procedural rounded
  dots at 78% of pitch (#8, #15), block shades as alpha rects, 2x backing.
- The panels are **real SwiftUI/AppKit controls** in dark appearance,
  rendered offscreen with `cacheDisplay`. An offscreen window is never key
  and AppKit then draws every prominent control inactive-grey, which would
  hide the one thing the buttons ticket asks to judge; the window subclass
  overrides the private appearance selectors so controls draw as they do in
  the real, key panel window.
- `.regularMaterial` cannot render offscreen (it needs a compositor behind
  it), so the material is faked per candidate: a Gaussian blur of the frame
  under the panel, then a tint. That is what the real material does, so the
  opacity judgment transfers.

Per run it writes `<key>-full.png` (whole screen, 2x), `<key>-crop.png`
(the panel plus a margin, native 2x pixels), `00-bare.png` (the frame with
no panel) and `contact-sheet.png` (all four at 1x, labelled).

## Candidates

Each one is a different *structure*, and each pairs a different reading of
the frame-rate cost and of the fractions, so parts can be stolen across them.

| | placement | backing | frame-rate cost | fractions | buttons |
|---|---|---|---|---|---|
| A corner card | top-right, 40 pt in | material, tint .55 | radio rows, cost as a subtitle | sliders + numbers | Exit left · Discard · **Accept** |
| B bottom strip | full-width foot | darker material, tint .72 | segmented, "½ core / 1 core" captions | sliders + numbers, inline | Discard · **Accept** ‖ Exit |
| C centred sheet | centre | light material, tint .45 | "Smooth motion" switch with a sentence | number field + stepper | ⊗ in title · Discard · **Accept**, "Esc exits" |
| D compact palette | bottom-left | opaque .92, no blur | radio rows with a core meter | sliders with qualitative ends, no numbers | **Accept** · Discard · Exit as text |

Footprint over the 190x56 grid, panel bounds only: A 5.3%, B 6.1%, C 7.0%,
D 3.8%. B's is almost entirely the glow border and the black slack under
row 56, so it covers the least *content* of the four.

## Verdict (2026-09-20)

**C, the centred sheet** — with the two fractions as sliders with numeric
readouts like the other candidates, draggable, and a **Hide** button at the
bottom-left that takes the panel away until the next mouse or key input.
Rendered as `C2-decided-sheet` in `shots/trails` and `shots/dense`. Resolution
on [#26](https://github.com/tamirelazar/tSlime-Screensaver/issues/26).
