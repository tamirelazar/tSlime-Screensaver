# Deep link to the Screen Saver settings on this macOS (issue #43)

Research date: 2026-09-21, on macOS 26.5.1 (build 25F80, Darwin 25.5.0), System Settings 15.0.
Question: why does the host app's *Open Screen Saver Settings* button land on General, and is
there an `x-apple.systempreferences:` URL that opens the Screen Saver settings on this machine?

Everything below was read off this Mac (bundles, plists, binaries, the System Settings scripting
dictionary) and then tested by opening each candidate URL and asking System Settings which pane
it showed. No web list was used.

## TL;DR

- **This URL works:** `x-apple.systempreferences:com.apple.Wallpaper-Settings.extension?ScreenSaver`.
  It opens System Settings on the Wallpaper pane with the **Screen Saver sheet** already up: the
  selected saver's thumbnail (tslime's, on this Mac), "Start Screen Saver… After 10 minutes",
  "Use Screen Saver: Automatic / Custom", and a Done button.
- **Why General today:** the app opens `x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension`
  (`AppexSaverMinimal/ContentView.swift:237`). No extension on this machine has that bundle
  identifier, System Settings' own scripting interface reports `Can't get pane id
  "com.apple.ScreenSaver-Settings.extension"`, and an identifier System Settings cannot resolve
  falls back to its default pane, General. Tested twice (with and without an anchor); both landed
  on `com.apple.systempreferences.GeneralSettings`.
- **The pane no longer exists as a destination.** On macOS 26 the screen-saver UI lives inside
  the Wallpaper extension (`com.apple.Wallpaper-Settings.extension`), whose binary contains
  `ScreenSaverSheet`, `ScreenSaverSettingsController`, `START_SCREEN_SAVER` and
  `_showScreenSaverSheet`, and whose AppleScript anchors are `ClockAppearance, ScreenSaver,
  Wallpaper`. The Lock Screen pane also declares a `ScreenSaver` anchor, but opening it changes
  nothing visible; the "Start Screen Saver when inactive" row is gone from Lock Screen.
- Two equivalents also work: the legacy identifier
  `x-apple.systempreferences:com.apple.preference.desktopscreeneffect?ScreenSaver` (System
  Settings maps it to the Wallpaper extension via the plist's `legacyBundleIdentifier`), and the
  AppleScript `reveal anchor "ScreenSaver" of pane id "com.apple.Wallpaper-Settings.extension"`.
- The anchor form is the grammar Apple's own frameworks use for this scheme:
  `x-apple.systempreferences:<pane id>[*<subpane>]?<anchor>`, e.g.
  `com.apple.settings.PrivacySecurity.extension?Privacy_LocationServices` and
  `com.apple.Accessibility?Captions` are literal strings in the dyld shared cache.

Loss side: the anchor opens a *modal sheet* over Wallpaper, not a standalone pane, so the user
sees the wallpaper grid load behind it (the Wallpaper pane takes several seconds to show its
window on this Mac) and has to press Done to get back. And the identifiers are private:
`com.apple.ScreenSaver-Settings.extension` presumably worked on the macOS that the app's
`41d0386` (2026-05-17) commit targeted and stopped resolving here, so the new URL is just as
exposed to the next release.

## Candidates tested

Method per row: `osascript -e 'quit app "System Settings"'`, wait for the process to exit,
`open "<url>"`, wait 12 s, then `tell application "System Settings" to get {name, id} of
current pane`, `tell application "System Events" to tell process "System Settings" to get
{name of windows, (count of sheets of window 1)}`, and `screencapture -x -l <window id>` of
the System Settings window (window id from `CGWindowListCopyWindowInfo`, filtered to owner
"System Settings"). Rows 02, 03 and 06 were first run with a 5 s wait; the pane id was already
right but the window was not yet on screen, so they were re-run at 12 s.

| # | URL / action | `current pane` reported | Sheets | What the screenshot showed |
|---|---|---|---|---|
| 01 | `x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension` (the app's current URL) | `com.apple.systempreferences.GeneralSettings` (name empty) | 0 | General: "Manage your overall setup…", About / Software Update / Storage list |
| 02 | `x-apple.systempreferences:com.apple.Wallpaper-Settings.extension` | Wallpaper, `com.apple.Wallpaper-Settings.extension` | 0 | Wallpaper pane, no sheet; "Screen Saver…" and "Clock Appearance…" buttons under the current wallpaper |
| 03 | **`x-apple.systempreferences:com.apple.Wallpaper-Settings.extension?ScreenSaver`** | Wallpaper, `com.apple.Wallpaper-Settings.extension` | **1** | Wallpaper pane dimmed, Screen Saver sheet up: saver thumbnail, "Start Screen Saver… After 10 minutes", "Use Screen Saver ◉ Automatic ○ Custom", Done |
| 04 | `x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension?ScreenSaver` | Lock Screen, `com.apple.Lock-Screen-Settings.extension` | 0 | Lock Screen pane, identical to row 08; no screen-saver row on the pane at all |
| 05 | `x-apple.systempreferences:com.apple.preference.desktopscreeneffect` (legacy id) | Wallpaper, `com.apple.Wallpaper-Settings.extension` | 0 | Wallpaper pane, no sheet |
| 06 | `x-apple.systempreferences:com.apple.preference.desktopscreeneffect?ScreenSaver` | Wallpaper, `com.apple.Wallpaper-Settings.extension` | **1** | Same as row 03 |
| 07 | `x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension?ScreenSaver` | `com.apple.systempreferences.GeneralSettings` | 0 | General (an anchor does not rescue an unknown pane id) |
| 08 | `x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension` | Lock Screen, `com.apple.Lock-Screen-Settings.extension` | 0 | Lock Screen: display-off delay, password delay, hints, login window options |
| 09 | AppleScript: `tell application "System Settings" to reveal anchor "ScreenSaver" of pane id "com.apple.Wallpaper-Settings.extension"` | Wallpaper, `com.apple.Wallpaper-Settings.extension` | **1** | Second System Settings window appeared (the sheet, ~150 000 px²) over the Wallpaper window |

`open` returned 0 for every URL; LaunchServices accepts the scheme regardless of the identifier,
so the exit code says nothing about where it lands.

## Evidence

### 1. What the app does

`AppexSaverMinimal/ContentView.swift:236-240`:

```swift
private func openScreenSaverSettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension") {
        NSWorkspace.shared.open(url)
    }
}
```

`git log -S "ScreenSaver-Settings.extension" -- AppexSaverMinimal` shows the string arrived in
commit `41d0386` ("Update", 2026-05-17).

### 2. Which settings extensions exist on this machine

System Settings 15.0 (`/System/Applications/System Settings.app/Contents/Info.plist`,
`CFBundleShortVersionString` 15.0) registers the scheme as
`CFBundleURLTypes = [{CFBundleURLSchemes: ["x-apple.systempreferences"], CFBundleURLName:
"System Preferences URL", LSIsAppleDefaultForScheme: true}]` and links
`Settings.framework`, `PreferencePanesSupport.framework`, `PreferencePanes.framework` and
`ExtensionFoundation.framework` directly (`otool -L`); `SettingsHost.framework`, where the URL
transforms live (section 5), is not a direct link.

Panes are ExtensionKit appexes declaring the extension point
`com.apple.Settings.extension.ui`. A script over every `*.appex/Contents/Info.plist` under
`/System/Library/ExtensionKit/Extensions`, `/System/Applications/System Settings.app/Contents/Extensions`,
`/System/Applications/*/Contents/{Extensions,PlugIns}`, `/System/Library/CoreServices/*/Contents/Extensions`,
`/Library/ExtensionKit/Extensions` and `/Applications/*/Contents/Extensions` found 52 such
extensions (53 bundles; Spotlight's appex is present twice). The ones that matter here (`plutil -extract EXAppExtensionAttributes json -o -`):

| Appex | `CFBundleIdentifier` | `allowsXAppleSystemPreferencesURLScheme` | `legacyBundleIdentifier` / `legacyPrefPaneBundleName` |
|---|---|---|---|
| `/System/Library/ExtensionKit/Extensions/Wallpaper.appex` (v245.4.8, `LSMinimumSystemVersion` 26.5) | `com.apple.Wallpaper-Settings.extension` | true | `com.apple.preference.desktopscreeneffect` / `DesktopScreenEffectsPref.prefPane` |
| `/System/Library/ExtensionKit/Extensions/LockScreen.appex` | `com.apple.Lock-Screen-Settings.extension` | true | none |
| `/System/Library/ExtensionKit/Extensions/DesktopSettings.appex` | `com.apple.Desktop-Settings.extension` | true | `com.apple.preference.dock` / `Dock.prefPane` |
| `/System/Applications/System Settings.app/Contents/Extensions/GeneralSettings.appex` | `com.apple.systempreferences.GeneralSettings` | true | none |

**No appex anywhere in those directories has the identifier `com.apple.ScreenSaver-Settings.extension`**
(`grep -l ScreenSaver-Settings` over all the plists: no hits; `find /System/Library
/System/Applications -iname "*ScreenSaver*Settings*" -o -iname "ScreenSaver*.appex"`: nothing).
The eleven `ExtensionKit/Extensions/*.appex` plists that do mention "screensaver" are saver
modules (Drift, Flurry, Hello, Monterey, Ventura, Shell, Word of the Day, …) on the
`com.apple.screensaver` point, not settings panes.

`/System/Library/PreferencePanes/DesktopScreenEffectsPref.prefPane` is listed but has no
`Contents/` directory at all (only 8 of the 40 `.prefPane` entries still carry an `Info.plist`);
it is a stub the Wallpaper appex's `legacyPrefPaneBundleName` points at.

`pluginkit -mAvv -p com.apple.systempreferences.extensionpoint` and `pluginkit -m -v -p
com.apple.Settings.extension.ui` both print `(no matches)`: pluginkit does not enumerate these
ExtensionKit panes, which is why the enumeration went over the plists directly.

### 3. The System Settings scripting dictionary is the authoritative pane and anchor list

`sdef "/System/Applications/System Settings.app"` exposes `current pane` (code `xpcp`) and
`reveal anchor`. Querying the running app:

- `get {name, id} of every pane` lists 47 panes. Wallpaper, Lock Screen and Desktop & Dock are
  there as `com.apple.Wallpaper-Settings.extension`, `com.apple.Lock-Screen-Settings.extension`,
  `com.apple.Desktop-Settings.extension`. There is no Screen Saver pane and no pane whose id
  contains "ScreenSaver".
- `get name of every anchor of pane id "com.apple.Wallpaper-Settings.extension"` →
  `ClockAppearance, ScreenSaver, Wallpaper`.
- `get name of every anchor of pane id "com.apple.Lock-Screen-Settings.extension"` →
  `DisplayOff, LargeClock, LockScreenMessage, LoginWindow, Password, ScreenSaver`.
- `get name of every anchor of pane id "com.apple.Desktop-Settings.extension"` →
  `Applications, Desktop, Dock, HotCorners, MissionControl, Shortcuts, StageManager, Widgets, WindowTiling, Windows`.
- `get name of pane id "com.apple.ScreenSaver-Settings.extension"` →
  `execution error: System Settings got an error: Can't get pane id "com.apple.ScreenSaver-Settings.extension". (-1728)`.
  The same error for `com.apple.preference.desktopscreeneffect`: the legacy alias is resolved by
  the URL handler (rows 05/06), not by the AppleScript object model.

### 4. The screen-saver UI is a sheet inside the Wallpaper extension

`strings` over `/System/Library/ExtensionKit/Extensions/Wallpaper.appex/Contents/MacOS/Wallpaper`
contains, among others: `ScreenSaverSheet`, `_showScreenSaverSheet`,
`_TtC23WallpaperSettingsUICore29ScreenSaverSettingsController`,
`_TtC23WallpaperSettingsUICore28ScreenSaverSettingsViewModel`, `ScreenSaverPreview`,
`ScreenSaverDelayOption`, `_screenSaverDelayOptions`, `_selectedScreenSaverDelay`,
`START_SCREEN_SAVER`, `START_SCREEN_SAVER_NEVER`, `USE_SCREEN_SAVER`, `SCREEN_SAVER_BUTTON_TITLE`,
`ON_SCREEN_SAVER_AND_LOCK_SCREEN`, `LegacyScreenSaverOptionsView`,
`WallpaperScreenSaverLocationView`, `Could not find selected screen saver module: %s`,
`screenSaverStartNowWithOptions:`, plus the navigation entry points
`setNavigationWithPath:` and `willSelectWithNavigationPath:` (the `Settings.NavigationPath`
class from Settings.framework, which is what a `?anchor` becomes). The appex also ships
`Resources/ScreenSaverAppleScriptSupport.scripting` next to `DesktopAppleScriptSupport.scripting`.

This matches what the screenshots show: the Wallpaper pane has a "Screen Saver…" button under
the current wallpaper (row 02), and the sheet (row 03) carries the start delay and the
Automatic/Custom choice that used to sit on the Lock Screen pane; the Lock Screen pane on this
build (rows 04/08) has only display-off delay, password delay, password hints, lock message and
login-window options.

### 5. What the System Settings binary and frameworks say about the identifiers

`strings -a "/System/Applications/System Settings.app/Contents/MacOS/System Settings"` contains
both `com.apple.ScreenSaver-Settings.extension` and `com.apple.Wallpaper-Settings.extension`:

- `com.apple.ScreenSaver-Settings.extension` sits right after `com.apple.Classroom-Settings.extension`
  and right before a `…/Sources/SystemPrefsApp/Swift/Cache.swift` path and the strings
  `Cache is invalid`, `com.apple.systemsettings.usercache`: it is known to the app's cache code,
  not to a registered extension.
- `com.apple.Wallpaper-Settings.extension` sits in an alias table:
  `com.apple.preference.desktopscreeneffect` → `com.apple.Wallpaper-Settings.extension`,
  `com.apple.preference.network` → `com.apple.Network-Settings.extension`, next to
  `SettingsExtensionAttributes` and `CurrentExtensionURL`. That is the legacy-id mapping rows
  05/06 exercised.

The URL parser itself lives in the dyld shared cache. `dyld_info -exports
/System/Library/PrivateFrameworks/SettingsHost.framework/Versions/A/SettingsHost` lists the
transforms `xAppleSystemPreferencesToNavigation`, `prefsToNavigation`, `appPrefsToNavigation`,
`normalizedPrefsAndApp`, `osBetaUpdatesToNavigation`, `prefsPreBuddyToNavigation`,
`prefsTVProviderToNavigation` and `URLComponents.settingsNavigation` (Swift-mangled names,
demangled by eye), and `Settings.framework` exports `Settings.NavigationPath` (NSCoding,
`pathToken`) and `SearchItem.anchor` / `searchAnchor`. The `?anchor` is therefore a
first-class navigation token, not a Wallpaper-specific hack.

`strings -n 6` over `/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e.01`
(5.47 M strings) shows the grammar Apple's own frameworks use with this scheme, all as literals:

```
x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocationServices
x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Blocklist
x-apple.systempreferences:com.apple.Accessibility?Captions
x-apple.systempreferences:com.apple.WalletSettingsExtension?addPass
x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings*AppleIDSettings?iCloud
x-apple.systempreferences:com.apple.Family-Settings.extension*Family?aaaction=showFamilySettingsV2&familyPath=/subscriptions
x-apple.systempreferences:com.apple.preferences.softwareupdate?__OpenIfNotSeen
x-apple.systempreferences:com.apple.preference.general
```

So: `<pane id>`, optional `*<subpane>`, optional `?<anchor or query>`; both new-style extension
ids and legacy `com.apple.preference.*` ids appear. The shared cache contains **no** string
`ScreenSaver-Settings` and no `com.apple.preference.screensaver`: no Apple framework on this
machine links to a Screen Saver pane.

## Uncertainties not resolved from primary sources

- Whether `com.apple.ScreenSaver-Settings.extension` resolved on the macOS the app was first
  built against was not verified here (no earlier macOS on hand); the System Settings binary
  still carrying the string in its cache code is consistent with a pane that was removed.
- The `ScreenSaver` anchor on the Lock Screen pane produces no visible change (row 04). It may
  scroll to a row that no longer exists, or be a leftover in the anchor list; the pane's binary
  was not inspected.
- The `*<subpane>` form was not tried with Wallpaper; the `?ScreenSaver` anchor already reaches
  the sheet, so there was nothing left to find.
- Screenshots were taken with `screencapture -l <window id>`; the sheet is composited into the
  Wallpaper window's capture (visible in row 03) but capturing the sheet's own window id failed
  with "could not create image from window", so the sheet count from System Events is the
  machine-readable record.
