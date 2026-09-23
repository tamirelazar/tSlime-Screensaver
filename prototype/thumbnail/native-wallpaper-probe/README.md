# Native Wallpaper selected-image probe

Tested on macOS 26.5.1 (25F80), 2026-09-23. This disposable `com.apple.wallpaper` ExtensionKit probe tests the alternative identified in [the Aerial comparison](../geometry-probe/working-saver-comparison.md). It is separate from the tslime product and from the earlier `com.apple.screensaver` calibration.

## Result

System Settings selected **Native Wallpaper Geometry Probe** and displayed its live calibration card. The tile was supplied separately by the settings model's thumbnail URL. The public probe log records exactly one acquire for the selected image:

```text
ACQUIRE A1 P1 idle ... destination=(1920.0, 1080.0) scale=1.0 displayID=3
READY A1 P1 idle ... root=(0.0, 0.0, 1920.0, 1080.0)@1.0 image=(0.0, 0.0, 1920.0, 1080.0)@1.0 gravity=resizeAspect
```

`P1` is the request's `isPreview=true` flag; the unique `A1` marker was overlaid on the selected card. This establishes that this native path has a distinct preview request that can choose its own composition. It does **not** establish the same behavior in the product's current extension type. A product migration would still need a separate implementation and compatibility decision.

The 1920×1080 card filled the roughly 160×100 selected-image slot, with its cyan corners and colored edges visible. By visual inspection, the native output appears about 10% taller relative to width than the source. The earlier private saver path measured 0.897 to 0.900 horizontal/vertical scale with the same reference card. We did **not** save a pixel capture of this native run, so the native ratio is an estimate rather than a marker measurement. The new path solves independent routing, but has not demonstrated aspect preservation.

[Filtered public diagnostics](observations.txt) capture the acquire. The later `UPDATE missing` line resulted from this probe initially keying a wallpaper object by its ephemeral object description; the source now extracts its stable UUID, but that fix was compiled after the native run and was not retested in Settings.

## Reproduce

```sh
python3 prototype/thumbnail/native-wallpaper-probe/generate-project.py
xcodebuild -project prototype/thumbnail/native-wallpaper-probe/NativeGeometryProbe.xcodeproj \
  -scheme NativeGeometryProbeHost -configuration Debug \
  -derivedDataPath /private/tmp/native-geometry-derived \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual build
pluginkit -a '/private/tmp/native-geometry-derived/Build/Products/Debug/Native Geometry Probe Host.app/Contents/Extensions/NativeGeometryProbe.appex'
```

Refresh WallpaperAgent, then select the probe in System Settings → Wallpaper → Screen Saver. The extension logs to subsystem `local.oozel.native-wallpaper-probe`, category `geometry`:

```sh
/usr/bin/log show --last 5m --style compact \
  --predicate 'subsystem == "local.oozel.native-wallpaper-probe"'
```

After observing, restore the prior saver, close Settings, and unregister the extension with `pluginkit -r` using the same `.appex` path. During this run Electric Sheep was restored and the probe registration was removed. No full-screen saver session ran. The main checkout and saved theme settings were not changed.

## Source provenance

`CodableShims.swift`, `RuntimeHelpers.swift`, `SettingsProvider.swift`, and `PrivateBridge.h` were adapted from [Aerial](https://github.com/AerialScreensaver/Aerial) at `2fcb2b8`; its MIT notice is included in [AERIAL-LICENSE](AERIAL-LICENSE). `Probe.swift` is the separate calibration renderer and handler. This prototype uses Apple's private wallpaper XPC interface, so its shape may change with macOS.
