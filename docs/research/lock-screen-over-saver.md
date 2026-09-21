# The lock screen over the saver: detection and geometry (issue #41)

Research date: 2026-09-21, on this Mac (Darwin 25.5.0, macOS 26.5, main display 0x3 at
1920×1080 pt, three local accounts: tamirelazar, crossover, Guest). Question: can a
sandboxed screensaver extension instance learn that the lock screen is being shown over
it, and does the lock UI (clock, avatar, name, password field) sit at a knowable geometry?

Context from the ticket: the map wants **cards**, dark panels the saver draws beneath the
lock UI so it stays legible over a bright simulation. Nothing here was observed by locking
the screen; every fact comes from headers, binaries, the sandbox profiles, and the unified
log archive of the locks that happened on this machine over the last two weeks (the saver
was ours in three of today's sessions).

## TL;DR

- **Detection: yes, with high confidence.** `loginwindow` announces every lock-related
  transition three ways at once, and all three reach a process inside the app sandbox:
  a distributed notification (`com.apple.screenIsLocked`, `com.apple.screenLockUIIsShown`,
  and their opposites), a Darwin notification (`com.apple.sessionagent.*` names), and a
  notify(3) *state* (`com.apple.sessionagent.screenLockUIIsShowing` = 1/0) that a
  late-starting instance can read with `notify_get_state` instead of waiting for an event.
  `application.sb` grants the two Mach services these need, Apple's only sandbox rule for
  distributed notifications is on *posting* with a `userInfo`, and a deny-default
  `sandbox-exec` profile carrying just those rules received both kinds in a test.
- **Two different events, and the cards want the second.** "Screen is locked"
  (`screenIsLocked`) fires ~100 ms after the saver starts on this Mac (the lock is
  requested by the saver launch itself, reason `kLWLockFromScreenSaverIdleLaunch`), and
  the lock UI is immediately *lowered* — the saver runs alone. The UI is only *raised*
  when the user gives input (`screenLockUIIsShown`), and it is lowered again after 30 s
  idle (`screenLockUIIsHidden`) or removed by an unlock, which also ends the saver.
- **The window is narrow.** At display sleep (10 min on this Mac) WallpaperAgent exits
  the saver instance ("Exiting the screen saver extension"), and no instance exists when
  the display wakes and the UI is raised. So "lock UI over a live saver" happens only when
  input arrives before the display sleeps; after that the UI sits over the wallpaper.
- **No signal reaches the extension through AppKit or the host.** Across today's sessions
  our lifecycle probe saw no window, occlusion, key, or app-activation change at a raise;
  ScreenSaver.framework and Wallpaper.framework have no lock API at all; the saver window
  stays at level −2147483625 while loginwindow's shield (2001) and lock UI (2004) windows
  live in loginwindow's own process. Detection has to come from the notifications above.
- **Geometry: not documented anywhere; derivable, and one observation away.** The lock UI
  is Auto Layout inside the private `LoginUIKit` (`LUI2UIController`), one `LUI2Window`
  per display. Its inputs are the *main* display's size, the "Show large clock" setting,
  the number of accounts (single-user "stack" vs multi-user "peekaboo" layout), and the
  auth state (Touch ID only changes text and whether the password field shows). The
  constants pulled from the binary: avatar diameter 70 pt; date font = 0.028 × main
  screen short side, its top 0.09 × main screen height from the top; big clock font =
  0.12 × short side (0.14 behind a feature flag), placed 4.3 × the date font size from
  the date; everything else is centred on X with fixed 5–30 pt gaps. On this display
  that predicts a ≈130 pt clock under a ≈30 pt date starting 97 pt from the top and a
  70 pt avatar centred horizontally near mid-height. The absolute frames have to be
  read off one screenshot of the raised UI; that is the prototype's first step.

## What loginwindow does at lock, raise, lower and unlock

Reconstructed from the unified log (`/usr/bin/log show`, process `loginwindow`,
subsystem `com.apple.loginwindow.logging`) for the 2026-09-21 01:52 session, in which our
extension (pid 28885) was the saver. The pattern repeats on every session in the archive
(2026-09-07 through 09-21).

| Time (09-21) | loginwindow | What it means for a saver |
|---|---|---|
| 01:52:56.956 | `-[ScreenSaverDaemon screenSaverDidFade] about to call lockScreen`, `enqueueLockScreenRequest reason: 3` (`kLWLockFromScreenSaverIdleLaunch`) | the saver launch itself requests the lock |
| +0.10 s | `LWShieldWindowController` creates the shield window at level 2001 on `LUIUnmanagedSpace level=300`; `setNotifySharedSpace com.apple.sessionagent.shieldWindowIsShowing=1`; distributed `com.apple.shieldWindowRaised`; Darwin `com.apple.sessionagent.shieldWindowRaised` | the shield exists for the whole session |
| +0.12 s | `-[LWScreenLock setCGScreenLocked]` ("setting lock time to preferred screen lock delay of: 0") | writes `CGSSessionScreenIsLocked`/`ScreenLockedTime` into the WindowServer session properties |
| +0.25 s | `-[LWDefaultScreenLockUI _load]` builds the UI at window level 2004; `Screen saver IS running dont tell luiframework to use desktop layer`; `-[LWDefaultScreenLockUI _lowerLockUI]` | the UI is built but **hidden**; the saver is the only thing on screen |
| 01:52:57.277 | `setNotifySharedSpace com.apple.sessionagent.screenIsLocked=1`; distributed **`com.apple.screenIsLocked`** object `501`; Darwin **`com.apple.sessionagent.screenIsLocked`** | the "locked" signal, ~0.3 s after saver start |
| 01:52:57.796 | our extension logs `ev=process pid=28885` | the instance is born *after* the lock signal |
| 02:03:08 | (display sleep) `WallpaperAgent: Exiting the screen saver extension`; PlugInKit `Removed` | the instance dies ten minutes in |
| 10:47:50.531 | `IOPMScheduleUserActiveChangedNotification received:1`, `-[LWScreenLock userActivityChanged:] user event received, start an unlock`, `startUnlock: kLWUnlockFromUserActive (9)` | user input (here: display wake) |
| 10:47:50.697 | `-[LWDefaultScreenLockUI showScreenLock:] enter 9` → `_raiseLockUI`: `activate loginwindow`, `setEnabled:YES`, `show windows`; `CGSSessionSetScreenLockWindow(270)` | the UI is **raised** |
| 10:47:50.706 | `setNotifySharedSpace com.apple.sessionagent.screenLockUIIsShowing=1`; distributed **`com.apple.screenLockUIIsShown`** object `501`; Darwin **`com.apple.sessionagent.screenLockUIIsShown`** | the "UI is over you" signal, 9 ms after the windows show |
| 10:47:55.553 | `com.apple.loginUI: switchToLayout current LUI2UserStackLayout → LUI2UserPeekabooLayout` | five seconds later the multi-user layout peeks in |
| 10:48:20.707 | `-[LWDefaultScreenLockUI handleTimeOutTimer:] idletime hit canceling the auth`; `screenLockUIIsShowing=0`; distributed **`com.apple.screenLockUIIsHidden`**; Darwin **`…screenLockUIIsHidden`**; `CGSSessionIDSetScreenLockWindowID kCGSNullWindowID`; `_lowerLockUI` | 30 s without input **lowers** the UI again |
| 11:04:51.587 | `-[ScreenSaverDaemon _screenSaverStop]`; then `screenIsLocked=0`, distributed **`com.apple.screenIsUnlocked`**, Darwin **`…screenIsUnlocked`** | unlock ends the saver session first, then announces |

Two consequences the ticket did not anticipate:

1. On this Mac "locked" and "saver running" are the same state: `com.apple.screenIsLocked`
   is posted before the instance's process even starts. The signal that matters for the
   cards is `screenLockUIIsShown` / `screenLockUIIsHidden`, and it can toggle several
   times per session (three raises between 13:22 and 13:24 today).
2. A raise after display sleep does not land on a saver. At 10:47:50 and 13:22:21 there was
   no `AppexSaverMinimalExtension` process at all (the archive has no line from it between
   02:03:08 and 11:06, nor between 13:11:06 and 13:24:20); WallpaperAgent had removed the
   `com.apple.wallpaper.choice.screen-saver` content at sleep and did not bring it back.
   The lock UI over a *live* saver therefore requires input within the display-sleep
   timeout (10 min here), and the instance that sees it is the one born at saver start.

## Evidence per candidate signal

### Distributed notifications (`NSDistributedNotificationCenter`) — usable

- **Names.** In the on-disk `loginwindow` binary
  (`/System/Library/CoreServices/loginwindow.app/Contents/MacOS/loginwindow`, `strings -a`):
  `com.apple.screenIsLocked`, `com.apple.screenIsUnlocked`, and the log lines above add
  `com.apple.screenLockUIIsShown`, `com.apple.screenLockUIIsHidden`, `com.apple.shieldWindowRaised`.
  Poster is `-[SessionAgentNotificationCenter sendDistributedNotification:object:]`; the
  binary imports `_CFNotificationCenterGetDistributedCenter`, `_CFNotificationCenterPostNotification`
  and `_OBJC_CLASS_$_NSDistributedNotificationCenter` (`nm -u`). The object is the uid as
  a string (`with object:501`), so an observer should filter on `String(getuid())`.
- **Sandbox.** `/System/Library/Sandbox/Profiles/application.sb` (the base profile every
  `com.apple.security.app-sandbox` process gets; our appex's entitlements file sets that key)
  allows `mach-lookup` of `com.apple.distributed_notifications@1v3` and
  `com.apple.distributed_notifications@Uv3` (lines 597–598). Apple's documentation for
  `postNotificationName(_:object:userInfo:deliverImmediately:)` states the only sandbox
  restriction: "If the sending application is in an App Sandbox, `userInfo` must be `nil`"
  — a rule on posting, and loginwindow posts with no `userInfo`. The SDK header
  `NSDistributedNotificationCenter.h` carries no sandbox caveat on observing.
- **Verified.** A receiver registering for a test name was run under
  `sandbox-exec -p '(version 1)(deny default)(import "system.sb")(allow process-exec*)(allow file-read*)(allow file-map-executable)(allow mach-lookup (global-name "com.apple.distributed_notifications@Uv3"))'`
  while an unsandboxed poster posted it: `distributed: received … object=501`. The control
  without the `distributed_notifications@Uv3` rule received nothing distributed
  (`result: distributed=false darwin=true`). Test names only; the real lock names were never posted.
- **Caveat.** Delivery needs the main run loop; the extension has one (`RunLoopType
  _NSApplicationMain` in ScreenSaver.framework's extension-point definition).

### Darwin notifications and notify state (`notify(3)`) — usable, and answers "what is the state now"

- **Names.** `com.apple.sessionagent.screenIsLocked`, `…screenIsUnlocked`,
  `…screenLockUIIsShown`, `…screenLockUIIsHidden`, `…shieldWindowRaised` are posted by
  `-[SessionAgentNotificationCenter sendBSDNotification:object:]` (`notify_post` is
  imported). Separately, `-[SessionAgentNotificationCenter setNotifySharedSpace:key:toValue:]`
  sets a state on `com.apple.sessionagent.screenIsLocked`, `…screenLockUIIsShowing` and
  `…shieldWindowIsShowing` (`to value:1` / `0` in the log), which is `notify_set_state`.
- **Sandbox.** `system.sb`, imported by every profile, allows `mach-lookup` of
  `com.apple.system.notification_center` (line 173) and the `apple.shm.notification_center`
  shared memory (line 154), which is all `notify_register_*` and `notify_get_state` need.
- **Verified.** Under a deny-default `sandbox-exec` profile importing only `system.sb`,
  `notify_register_check` + `notify_get_state` returned `state=0` for all three keys (the
  screen is unlocked), and the same receiver got the Darwin test notification. This is the
  signal to read at instance start: an instance born after a raise (e.g. WallpaperAgent's
  replacement after a crash) cannot see the event but can read the state.

### `CGSessionCopyCurrentDictionary` — works, but is a poll with an unverified key

- **Public API.** `CoreGraphics/CGSession.h` in the SDK documents the function and five
  keys (`kCGSessionUserIDKey`, `UserName`, `ConsoleSet`, `OnConsole`, `LoginDone`) and two
  `notify_post` names for *console session* and *user* changes — nothing about locking.
- **Private key.** `loginwindow` contains the strings `CGSSessionScreenIsLocked` and
  `CGSSessionScreenLockedTime` and imports `_CGSSessionSetCurrentSessionProperties`;
  `-[LWScreenLock setCGScreenLocked]` / `setCGScreenUnlocked` write them at lock/unlock.
  The public function returns the same property bag: on this shell, right now, it holds
  `CGSSessionUniqueSessionUUID, kCGSSessionAuditIDKey, GroupID, LoginwindowSafeLogin,
  OnConsole=1, SystemSafeBoot, UserID=501, UserName, kCGSessionLoginDoneKey=1,
  kCGSessionLongUserNameKey, kSCSecuritySessionID` — identical to SkyLight's
  `SLSSessionCopyCurrentSessionProperties` except that the private call also carries
  `kCGSSessionIDKey`. `CGSSessionScreenIsLocked` is absent while unlocked.
- **Sandbox.** `application.sb` line 692 allows `com.apple.windowserver.active`, and the
  extension already holds a WindowServer connection (it has a window).
- **Limits.** No change notification exists for it, so it is a poll; and whether the key
  appears as a value `1` while locked is not verified here (open observation 5). It adds
  nothing over the notify state, which is documented-shape (`notify(3)`) and event-driven.
- **`kCGSessionOnConsoleKey`** is "whether the session is on a console" per the header,
  i.e. fast user switching; it stays 1 through a lock and says nothing about the UI.

### `NSWorkspace` notifications — not a lock signal

- `sessionDidResignActiveNotification` is documented as "posted before a user session
  switches out" (fast user switching), and its counterpart for switching back in. The
  AppKit header groups them under "Session notifications" with no lock semantics.
- `screensDidSleepNotification` does reach the extension (probe line
  `ev=ws.screensDidSleep` at t+610.474 today) — and 1 ms later WallpaperAgent exits the
  instance, so it is a death notice, not something to act on.

### Window-, view- and host-level signals — none

- Our `LifecycleProbe` census (window number, `isVisible`, occlusion, level, key/main,
  `onActiveSpace`, `isHidden`) changed **once** per instance today (at t+1 s) and never
  again, across the raises at 10:47:50, 11:03:50, 13:22:21, 13:23:04, 13:24:03. No
  `win.didResignKey`, `app.didResignActive`, `win.didChangeOcclusionState` after start,
  no `hostWindowReceivedEventType`. (The window reports `occlusion=notVisible` even while
  it is the only thing on screen — a ViewBridge artefact known from #9.)
- The raise happens entirely inside loginwindow: `activate loginwindow`, its
  `LUI2Window`s shown at level 2004 above its shield window (2001); the saver's
  `NSServiceViewControllerWindow` stays at level −2147483625 (`kCGMinimumWindowLevel + 23`).
- The host has nothing to say: `WallpaperAgent`'s binary has no lock-related strings or
  imports beyond `NSDistributedNotificationCenter` itself; a runtime class dump of
  ScreenSaver.framework (22 classes) and Wallpaper.framework (16) finds no lock, shield or
  loginwindow API — only the legacy `-[ScreenSaverView canRunAtLoginWindow]`. The private
  headers already dumped in `AppexSaverMinimalExtension/PrivateHeaders/ScreenSaverPrivate.h`
  are complete on this point: the extension point delivers `handshake`/`startAnimation`
  items and nothing about locks.

### Recommended wiring (for the prototype, not decided here)

Observe `com.apple.screenLockUIIsShown` / `…Hidden` on `DistributedNotificationCenter.default()`
(or the Darwin twins via `notify_register_dispatch`), filter `object == String(getuid())`,
and at start read `notify_get_state` of `com.apple.sessionagent.screenLockUIIsShowing`.
`com.apple.screenIsLocked` is redundant on this Mac (it coincides with saver start) but is
the right signal on a Mac whose "require password" delay is longer than the saver delay.

## Geometry of the lock UI

### Who draws it, and where

- The UI is `loginwindow`'s `LWDefaultScreenLockUI`, which owns a `LUI2UIController` from
  the private `LoginUIKit.framework` (linked by loginwindow; 179 classes in a runtime dump).
  `LUI2MultiWindowController` keeps `_mainWindow` plus `_secondaryWindows` keyed per
  display, each an `LUI2Window` (`isSecondary`), and has `setUsesScreenSaver:` /
  `setUsesDesktopLayer:` — the log line "Screen saver IS running dont tell luiframework
  to use desktop layer" is loginwindow choosing the former, which is why the saver shows
  through. Displays come from `LUI2Screen` (`+screens`, `+mainScreen`, `frame`,
  `shortSide`, `longSide`); today's log: `main display 0x3 frame={{0, 0}, {1920, 1080}}`.
- The user/password stack, name label, clock and date are children of the main window.
  What a secondary display shows besides background is not settled here (observation 3).
- Nothing about this is documented. Apple's Lock Screen settings pane
  (`/System/Library/ExtensionKit/Extensions/LockScreen.appex`) exposes only
  "Show large clock" (`ClockDisplayOption`) and 12/24-hour, both under `com.apple.loginwindow`.

### The parameters, from the binary

`LoginUIKit` lives in the dyld shared cache; `dyld_info -disassemble` and a runtime
class dump were used (see Method). Constants that are loaded from `__const` were read in
process by slide arithmetic; the class-method values were called directly.

| Quantity | Where | Value / formula |
|---|---|---|
| Avatar diameter | `+[LUI2Constants userPictureDiameter]` | **70 pt** (`primaryShadowRadius` 1, `secondaryShadowRadius` 3, opacity 1 / 0.5) |
| Date font size | `+[LUI2DateViewController fontSize]` | `0.028 × mainScreen.shortSide` (fallback 18) → **30.2 pt** here |
| Big clock font size | `-[LUI2BigTimeViewController _fontSize]` | `0.12 × shortSide`, or `0.14 ×` when `LUIFeatureEnabled(4)` → **129.6 / 151.2 pt** here |
| Date vertical constant | `-[LUI2UIController _dateConstraintConstant]` | `0.09 × mainScreen.frame.height` → **97.2 pt** here, used as `topAnchor` constant |
| Big clock vertical constant | `-[LUI2UIController _bigTimeConstraintConstant]` | `dateFontSize × 4.3` (or `× 4.0` without feature 4) → **130 / 121 pt** |
| Message constant | `-[LUI2UIController _messageConstraintConstant]` | `ceil(−font.descender)` plus a `LUI2UserView` dimension |
| User stack alignment | `_setupControllerWithAuthorizationPluginView:` | `_userViewAligner`: `centerXAnchor == centerXAnchor`; `centerYAnchor == centerYAnchor`; a top constraint of `centerY + (−0.5 × _revealedMenuBarHeight + 5)` |
| Fixed gaps in the same method | | constants 5, 8, 10, 18, 20, 23, 30 pt between stacked elements (the 8 and 20 pt ones partly as `≥` constraints) |
| Single-user item frame | `-[LUI2UserStackLayout itemFrameForItemIndex:]` | focused user centred on `layoutBounds.midX − userPictureCenter.x`, top of bounds; other users at 75 % (`userViewDimensionsForPercentageOfDefault: 0.75`), at most `maxUsersForPeekABoo` = 5 |

So the geometry on a given Mac is a function of: the **main display's** short side and
height (every scale factor above reads `LUI2Screen.mainScreen`, even for secondary
windows); the **big clock toggle** (`LUIClockSettings.showsBigClock`, `ShowsBigClock` in a
per-user `ClockSettings.plist` under the wallpaper store; `bigClockHidden = 0` in
today's log, and `com.apple.loginwindow` defaults carry `ClockFontIdentifier = soft`,
`ClockFontWeight = 661.57`); the **number of accounts** (one → `LUI2UserStackLayout`;
more → the peekaboo transition seen five seconds after each raise today, which lays the
other avatars out at 75 % beside the focused one); and the **auth state** —
`LWAuthServiceState` (Touch ID, AutoUnlock, continuity) decides only whether the
password field is shown and which hint text appears (`show textfield:0 …` at raise,
`Enter Password` placeholder), i.e. it toggles `userNameLabelPasswordRequiredConstraint`,
not the positions of clock or avatar. Touch ID reported `state:0 - Unknown` on this Mac.

Everything in the table is derived from code, not measured; the fractions and the 70 pt
are certain, the composition into absolute frames (which anchor is the window's top
versus the safe-area guide, whether the date sits above or below the clock) is not.

## Open observations for the human

These need the real lock screen. Each is one lock; do them during a session that started
less than ten minutes ago, or the saver will already have been exited at display sleep.

1. **Capture the raised UI over the live saver.** From a terminal: `sleep 50; screencapture -x ~/Desktop/lock-ui.png`
   then lock at once (Ctrl-Cmd-Q, or wait for the saver), press Shift once at about 35 s
   so the UI is raised when the capture fires (it lowers 30 s after the last input), and
   do nothing else. If the PNG is black or shows only the shield, take a phone photo
   with the display edges in frame instead. Then measure, in points (px ÷ backing scale),
   the top of the date and clock, the avatar centre and diameter, the name label, and the
   password field's frame, and compare against the derived 97 pt / 130 pt / 70 pt above.
2. **Order of clock and date**, and whether the big clock's top is anchored to the window
   top or the date's bottom.
3. **Second display attached:** which display carries the user stack and password field,
   and what the other shows (clock? nothing?).
4. **Peekaboo:** whether the other accounts' avatars appear beside yours after ~5 s, and
   whether that shifts the focused avatar.
5. **`CGSSessionScreenIsLocked`:** `sleep 40; swift cgsession.swift > ~/Desktop/cgsession-locked.txt`
   (the script is five lines: print `CGSessionCopyCurrentDictionary()`), lock, and read
   the file after unlocking — does the key appear, with which value?
6. **Touch ID / password field at raise:** whether the field is visible immediately or
   only after a keypress, since that decides whether the field's card is always drawn.

## Method

- Headers: SDK `CoreGraphics/CGSession.h`, `Foundation/NSDistributedNotificationCenter.h`,
  `AppKit/NSWorkspace.h` (Xcode's MacOSX.sdk). Documentation: Apple Developer pages for
  `postNotificationName(_:object:userInfo:deliverImmediately:)` and
  `NSWorkspace.sessionDidResignActiveNotification` (fetched from the docs JSON).
- Sandbox: `/System/Library/Sandbox/Profiles/{application,appsandbox-common,system}.sb`;
  the appex's `AppexSaverMinimalExtension.entitlements` and `Info.plist`; the extension
  point from `/System/Library/Frameworks/ScreenSaver.framework/Versions/A/Resources/Info.plist`.
  Empirical check with `sandbox-exec -p` over small Swift binaries (receiver / poster /
  notify-state reader) using test notification names only.
- Binaries: `strings -a`, `nm -u`, `otool -L` on `loginwindow` and `WallpaperAgent` (on
  disk); `dyld_info -section __TEXT __cstring` and `dyld_info -disassemble` on
  `LoginUIKit` in the shared cache; a 25-line Swift class dumper (`dlopen` +
  `objc_copyClassNamesForImage` + `class_copyMethodList`) for LoginUIKit, ScreenSaver and
  Wallpaper; constants read by calling `+[LUI2Constants …]` through the runtime and by
  reading `__const` doubles at `unslid address + slide` (slide from a known IMP).
- Logs: `/usr/bin/log show --last 14d` / `--start … --end …` with predicates on
  `loginwindow`, `WallpaperAgent`, `AppexSaverMinimalExtension` and our subsystem
  `net.aerialscreensaver.AppexSaverMinimal`; no `log stream`, no lock, no saver launch.
- Not found on this machine: `class-dump`, `dyld_shared_cache_util`; `CONTEXT.md` referenced
  by `CLAUDE.md` does not exist on any branch.
