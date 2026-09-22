# PROTOTYPE — How should the login-screen cards look?

Throwaway comparison for [How should the login-screen cards look?](https://github.com/tamirelazar/tSlime-Screensaver/issues/42).

**Resolved: retain the existing appearance.** After reviewing the real native
login controls over the running saver, the owner chose no special treatment.
The linked ticket holds the decision; these studies remain reference artifacts.

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

**Live overlap is now visually verified on this Mac (2026-09-22, 20:20).**
The native clock, avatar, name and password field appeared over the running
saver. See the reproduction below.

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

## Feasibility — verified on this Mac

The successful attempt began at 20:20:13 on 2026-09-22, after a fresh explicit
"ready" from the owner. With the password delay set to Immediately, starting
the saver and then pressing Shift raised the native login UI over its content.
The event-triggered capture caught the actual overlap, rather than a later
wallpaper session:

- 20:20:13.053: loginwindow reported password delay 0.
- 20:20:13.146: WallpaperAgent identified saver extension PID 86007.
- 20:20:19.664: the lock-UI notify state changed to 1.
- Three screenshots at approximately 20:20:19–20 visibly show the native clock,
  avatar, name and password field over Oozel. The same extension reports
  30 presented frames per second throughout the overlap.
- 20:20:49.676: the UI state returned to 0 after about 30 seconds idle, while
  that same saver instance continued rendering. It rose again at 20:20:57.159.
- Authentication succeeded at 20:20:59.194 and the session then ended.
- The password delay was restored to **After 15 minutes**, verified in System
  Settings after the test.

Raw captures and the notify samples remain local in the ignored folder
`captures/20260922-202002-triggered/`. The representative image is
`overlap-2.png`. This verifies visible overlap and the externally observed
state signal on this configuration; it does not yet test a card implementation
or notification delivery inside the actual extension.

### Reproduce

1. Temporarily set System Settings → Lock Screen → Require password to
   **Immediately**. Let the owner authenticate directly if requested.
2. Explain the input sequence and **wait for a fresh explicit "ready"** before
   starting the saver. Prior general permission is not a readiness signal.
3. Run `bash prototype/lock-cards/capture-on-overlap.sh`. It arms the read-only
   observer, waits ten seconds, and starts ScreenSaverEngine.
4. After five seconds of animation, the owner taps Shift once, leaves the UI
   untouched for ten seconds, then unlocks normally. The script captures three
   frames on the first simultaneous UI-visible/extension-present sample.
5. Restore **After 15 minutes** and verify the value in System Settings.

Starting with Control-Command-Q produced wallpaper instead in the earlier
attempt. With a 15-minute grace period, input before the grace expires simply
dismisses the saver. Neither is the working quick reproduction above.

### Earlier attempts and research correction

On 2026-09-22 the owner asked to establish reproducible live overlap before
doing any more appearance work. Historical log rechecking also corrects the
research's original 2026-09-21 01:52 session: at 01:52:56.979, loginwindow
reported a preferred screen-lock delay of **900**, not the 0 stated in the
research table. The known raises after display sleep cannot prove live overlap.

`observe-overlap.c` is a read-only helper that samples the lock-UI notify state
and extension PIDs four times a second. Build and run it with:

```
clang -Wall -Wextra -Werror prototype/lock-cards/observe-overlap.c -o prototype/lock-cards/.build/observe-overlap
prototype/lock-cards/.build/observe-overlap 30
```

It needs access to notifyd and the process list outside the agent sandbox.
An unlocked-desktop control run returned `lock_ui=0 extension_pids=none`
and `NO_OVERLAP_OBSERVED`. This verifies the reader, not the target behavior.
Even a candidate overlap is not proof by itself: a settings preview instance
could be alive. Identify the same saver PID across the transition and confirm
the actual clock/login UI over its content in a contemporaneous screenshot.

The owner authorized temporarily changing the password requirement to
Immediately, running the experiment, and restoring 15 minutes. Both setting
values were verified in System Settings; restoration is complete.

The immediate-password attempt at 20:09:25 remains visually inconclusive:

- 20:09:25.568: loginwindow confirmed the password delay was 0.
- 20:09:26.027: saver extension PID 81967 started.
- 20:09:26.087–27.292: login UI was raised. The observer simultaneously saw
  `lock_ui=1` and that same extension PID in five samples.
- 20:09:27.258: password authentication succeeded; the UI was then lowered,
  the screensaver session stopped, and the extension exited at 27.646.
- The first screenshot at 20:09:28 was too late: it shows a new direct-lock
  session over the wallpaper. Later captures also do not establish overlap.

That attempt was evidence of brief concurrent process/UI state, not visual proof.
It does not show that macOS inherently tears down the saver on raising login
UI: a successful unlock ended this attempt. The successful follow-up above
triggered on the first overlap sample rather than waiting three seconds.

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
