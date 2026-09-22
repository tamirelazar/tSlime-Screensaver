# PROTOTYPE — How should the login-screen cards look?

Throwaway comparison for [How should the login-screen cards look?](https://github.com/tamirelazar/tSlime-Screensaver/issues/42).

The owner chose to compare treatments before deciding whether the brief overlap
between the running saver and the login UI warrants cards.

Comparison: untreated screen, separate dark cards, and a softer backing
behind the clock and login area. These are static appearance studies.
macOS owns the clock and authentication controls; this prototype only explores
what the saver draws behind them.

Run `bash prototype/lock-cards/run.sh` to render the comparison into `shots/`.
The contact sheet compares full screens; the authentication crop sheet makes
the small login controls readable. No window or screensaver is launched.

The depicted clock and controls are schematic approximations at positions
observed over this Mac's wallpaper, not captured native UI over the saver.
The avatar is a neutral placeholder. macOS's translucent clock material,
motion, alternate accounts and authentication states are not reproduced.

## Sources

- `frames/{dense,trails}.png`: unchanged `00-bare.png` assets from
  `prototype/panel-look:prototype/panel-look/shots/{dense,trails}/`.
  Real captured tslime cell data, rendered offscreen at the saver's metrics:
  190×56 cells, SF Mono 16 pt, procedural braille, 1920×1080 pt at 2×.
- Detection and derived geometry:
  `research/lock-screen:docs/research/lock-screen-over-saver.md`.
  The observations below supersede its predicted central login-group position
  for the particular configuration captured here.
- `frames/opal.png`: unchanged `C3-Opal seam.png` from the themes worktree,
  `prototype/themes/shots/round-3/`, copied 2026-09-22. Its 3800×2128 grid is
  placed at native pixel size at the top-left of a 3840×2160 canvas.
- `frames/parchment.png`: unchanged `03-parchment.png` from
  `prototype/themes/shots/round-1/`, copied 2026-09-22, also 3800×2128.
  Included as a bright-background stress case; this is a theme study,
  not a statement that the theme has been chosen to ship.

## Capture observations — 2026-09-22

The first capture launched the saver at 19:22:37. A saver instance and tslime
child were present in the 19:22:40 capture; by 19:22:48 both were gone and
the screen showed the desktop application. System logs explicitly reported
a **900-second password grace period**, and at 19:22:45 reported that the
keybag was not locked. Input therefore dismissed the saver without login UI.
The research's immediate-lock assumption does not describe this run.

For the authorized retry, Control-Command-Q explicitly locked the Mac at
19:24:46. The log says `Screen saver is NOT running tell luiframework to use
desktop picture`. Starting ScreenSaverEngine at 19:24:52 did not produce a
live extension in any of the three capture process snapshots. The first PNG
at 19:24:55 successfully captured the real lock UI over the wallpaper; later
captures show the unlocked desktop. We have **not** verified lock UI over a
live saver or real notification delivery to that saver in this session.

Visually measured from the 3840×2160 screenshot, expressed approximately in
1920×1080 points, with the origin at top-left:

| Element | Observed position |
| --- | --- |
| Date | centred at x960; visible top around y104 |
| Clock | centred at x960; visible y146–257 |
| Avatar | centred around x960, y895; about 50 pt diameter |
| Name | centred at x960; visible top around y937 |
| Password field | approximately x880, y967, 160×28 pt |

The login group is near the **bottom**, not the centre guessed from the
private-layout research. These bounds describe one display/configuration,
not a stable macOS geometry contract. A chosen treatment still needs a
live-saver check and a decision about layout uncertainty before production.

## Capture — requires permission to take the display

Run `bash prototype/lock-cards/capture-lock.sh` only after approval and after
checking that the password grace period will not make input dismiss the saver.
The two attempts above demonstrate that the script alone does not ensure
an overlap between the saver and lock UI; do not repeat it as a verified recipe.
The script launches the installed saver and captures at roughly 3, 10 and 18
seconds. Tap Shift once about five seconds after the animation appears, then
wait until 20 seconds to unlock. Capture timing is approximate.

The script does not build, install, change settings, enter credentials, or end
the session. Raw captures stay local in the ignored `captures/` directory.
Confirm the images contain the actual raised lock UI over a live saver before
using them to position any candidate.
