# PROTOTYPE — how should the host app's main window look? (ticket #32)

Throwaway. Answers one question: what the host app's main window — the one
that installs the extension, activates it as the screensaver, opens the tuning
surface and opens System Settings — should lead with, and how its states
should read. Not the settings panel (#26), not the tuning surface.

```
./run.sh shots/dark              # build, render every candidate in every state
./run.sh shots/light --light     # the same in light appearance
./run.sh --live                  # a real window with a switcher strip under it
```

- The candidates are **real SwiftUI windows** driven by a stub of
  `PluginManager` whose Install / Uninstall / Enable flip the state after half
  a second. Rendered offscreen at 2x with the window lying about being key
  (as `prototype/panel-look`), then composited into a mock macOS title bar on
  a flat desktop so each one reads as a window of a certain size.
- Every candidate is drawn in **four states**: `1-fresh` (not installed),
  `2-installed` (installed, not active), `3-active` (the steady state), and
  `4-broken` (installed, activation failed, settings domain hijacked as
  ADR 0002 describes), so the failure surfaces are judged too.
- `--live` opens one window: ← → cycle the candidate, ↑ ↓ cycle the state,
  R resets it, and the buttons drive the stub. The yellow strip is the
  switcher, not part of any design.
- `frames/` holds the captured tslime frames from `prototype/braille-look`;
  the preview in B is `03-dense` rendered the way the saver renders it.

Per run it writes `<candidate>--<state>.png` (2x), `sheet--<state>.png`
(every candidate side by side in that state) and `sheet--<candidate>.png`
(that candidate through every state). `shots/00-real-window-installed.png`
is the real app's window captured on 2026-09-20 with the extension installed.

## Candidates

`00-current` is today's window ported verbatim onto the stub, for the
baseline. The other four each answer "what leads?" differently, so parts can
be stolen across them.

| | leads with | install / activate | tune | width |
|---|---|---|---|---|
| 00 current | a 60 pt glyph and the sample's name | two centred group boxes, one button each | a prominent button in a row of two | none — grows to fit the path (1195 pt installed, #33) |
| A steps | three numbered steps in order; the next one is blue | steps 1 and 2, one button each | step 3, prominent once active | 470 |
| B preview first | the saver itself, 600 pt wide | a chip strip under the preview; buttons until done, chips after | the one large button, always | 640 |
| C one sentence, one button | what is true now, as a sentence | the one next action; the rest under Details | the button once active | 500 |
| D grouped form | System Settings' own idiom | a section each, label / value rows | a Look section | 520 |

All four call the app **tSlime** with a stand-in icon (a braille glyph on a
dark tile), because they cannot be judged with `AppexSaverMinimal` in them;
the rename itself is not decided here.

## What was found on the way

The current window has no width. `.fixedSize()` on the outer stack gives the
path `Text` its ideal single-line width, so on this machine the real window is
**1195 x 797 pt** once the extension is registered — filed as #33.
