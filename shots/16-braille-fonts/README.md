# #16 — the three braille sources on a real saver instance

Captured by `scripts/test-braille-fonts.sh` on the development Mac
(1920x1080 points at 2x, 16 pt), one screensaver session, switching the
`brailleSource` setting under a live instance that nobody restarted.

The frames differ between captures — tslime never stops — so these compare the
**lattice each source draws**, not the same picture three times.

| File | What it shows |
|---|---|
| `contact-sheet.png` | the three sources at 3x on the same screen region |
| `procedural.png` | full frame, renderer-drawn rounded squares (the default) |
| `juliaMonoBold.png` | full frame, JuliaMono Bold's own round dots |
| `jetBrainsMonoNerdFontMono.png` | full frame, JetBrainsMono NFM's generated 2x4 grid |
| `caret-before-fix-8x.png` | the bug the first run found, at 8x |
| `switch.log` | the extension's own account of the two switches |

## The grid follows the face

    diag launchProcess grid=190x56
    diag font -> JuliaMono-Bold            grid=190x56 -> 200x56  running=true
    diag font -> JetBrainsMonoNFM-Regular  grid=200x56 -> 200x49  running=true

Both faces give a 9.50 pt cell against the system face's 10.00, and
JetBrainsMono NFM a 21.50 pt line against 19.00 — so ten columns appear, and
then seven rows go. `running=true` is the part that matters for tslime: the pty
gets a new winsize, tslime takes the SIGWINCH and re-lays out without a restart.

## `caret-before-fix-8x.png`

The first run of this check came back green on every assertion it had, and the
captures still had a grey box in the bottom-right corner that the procedural
capture did not.

A font change re-gridded through SwiftTerm's `resize(cols:rows:)`, which
soft-resets the terminal; a window resize goes through `processSizeChange`,
which does not. A soft reset clears DECTCEM, the palette, the charset, origin
mode, wraparound and the scroll margins. tslime redraws its colours and
attributes every frame and never noticed those coming back — but `civis` it
sends once at startup, so un-hiding the cursor stuck, and the caret stayed for
the life of the instance.

Fixed on the fork ("Re-grid a font change the way a window resize does"), and
the check now counts neutral-grey pixels so it cannot come back: 306 and 342 of
them before, 0 after.
