# Aerial and the installed working savers

Investigated 2026-09-23 after the owner identified Electric Sheep and Magic Window Air as examples whose Settings previews look correct. This is a comparison of implementations and a disposable native rendering test, not a product migration.

## Findings

The previous conclusion was too broad if read as “macOS cannot show a well-framed saver preview.” Electric Sheep and Magic Window Air both rendered a clean image filling the selected-preview slot on this Mac. Our measured approximately 10% horizontal compression is repeatable for the tested private saver extension, but it does not establish that every integration has the same problem, nor explain every difference between the original coarse-grid prototype and the installed product.

| Implementation | Rendering/hosting path | What we verified |
| --- | --- | --- |
| Our product | `com.apple.screensaver`, AppKit + SwiftTerm/Metal | Existing calibration reproduces compression through this integration without the terminal renderer. |
| Aerial's minimal sample | `com.apple.screensaver`, `ScreenSaverView` + Core Animation | Same screen-sized initial controller frame as our template; no new preview geometry fix found in that sample. |
| Aerial 4.0.14 | `com.apple.screensaver`, `ScreenSaverView` + `AVPlayerLayer` | Fits/fills video with aspect-preserving gravity within its view bounds. A control using that construction still compresses our calibration in Settings. |
| Current Aerial 4.1 source | `com.apple.wallpaper`, direct remote `CAContext` and content layers | Receives destination size, display scale and preview/presentation fields; builds its output from those values. This is a distinct, still untested candidate for our content. |
| Installed Electric Sheep | Public legacy `.saver`, linked OpenGL renderer | Its Settings image rendered and filled the slot. Published Mac source initializes a child OpenGL view from the provided frame. |
| Installed Magic Window Air 3.1.2 | Public legacy `.saver`, links AVFoundation/AVKit | Its Settings image rendered and filled the slot after the host refresh. Closed-source behavior beyond this is not established. |

The installed third-party footage does not contain our calibration markers. Those screenshots establish the visible framing comparison; they do **not** prove exact pixel aspect preservation. The public Electric Sheep repository was inspected at `d63a51aee34b642eea3a9d5e300af84ebd0fa91f`; that source has not been matched byte-for-byte to the installed binary.

Sources: [minimal controller](https://github.com/AerialScreensaver/AppexSaverMinimal/blob/6be6c85b49e827320711289853726e68d3fbd7ea/AppexSaverMinimalExtension/AppexSaverMinimalViewController.swift#L41-L50), [Aerial 4.0 video-layer setup](https://github.com/AerialScreensaver/Aerial/blob/55eddc3def7c4c39bb15c16ab29b906ab39fdd2b/AerialScreenSaverExtension/AerialSaverView.swift#L901-L919), [current Aerial destination extraction](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/WallpaperXPCHandler.swift#L104-L128), [Electric Sheep Mac view](https://github.com/scottdraves/electricsheep/blob/d63a51aee34b642eea3a9d5e300af84ebd0fa91f/client_generic/MacBuild/ESScreensaverView.m#L13-L173), [Magic Window Air developer support](https://www.jetsoncreative.com/airportlounge).

## Aerial-style video control

`build-av.py` builds **AV Geometry Probe**, a separate host/extension with the same private superclass/controller handshake as the existing calibration. `AVGeometryView.m` uses the Aerial 4.0 construction: a layer-backed `ScreenSaverView`, plain backing `CALayer`, child `AVPlayerLayer`, `.resizeAspect`, and child frame updated to view bounds with implicit animations disabled. A two-second looping H.264 video contains the exact existing `reference.png`. This changes the rendering construction as a whole; it is not a claim that one isolated property caused the outcome. No Aerial app was installed.

The movie uses square pixels and 1920×1080 frames. A frame decoded back from the movie passes the same four-marker geometry check, excluding video encoding as the source of the approximately 10% distortion.

| Image | Horizontal / vertical scale | Uniform within 2%? |
| --- | --- | --- |
| Decoded movie reference | 1.000 | Yes |
| Actual selected AV Geometry Probe image | 0.897 | No |

Commands:

```sh
python3 build-av.py
python3 measure.py av-decoded-reference.png --verify-uniform
python3 measure.py av-settings-capture.png --settings --verify-uniform
```

The first measurement exits 0; the native measurement exits 1. Native logs show PID 46317, `preview=0`, view bounds and video frame both 1920×1080, backing scale 2, and `AVLayerVideoGravityResizeAspect`. See [av-observations.txt](av-observations.txt), [reference measurement](av-reference-measurements.json), [native measurement](av-settings-measurements.json), and [capture](av-settings-capture.png).

Both host-declared instances play the same video, so this control does not independently repeat the earlier colored-instance routing experiment. It tests the selected output's proportions, with the earlier routing evidence as context.

### Discovery interruption

Initially System Settings launched only the true preview instance, then reverted its selected image to Tahoe Day. WallpaperAgent logged `Failed to find screen saver module` at those attempts. Those failed selections were not counted as geometry results. Refreshing the identified WallpaperAgent process made the registered module selectable, and the calibration was then visible. This was a discovery failure, not an AVPlayerLayer rendering result. Magic Window Air also rendered successfully after the refresh.

## Installed-app comparison and cleanup

- [Electric Sheep restored and rendering](electric-sheep-restored.png).
- [Magic Window Air rendering](magic-window-settings-retry.png).
- Electric Sheep was already selected when this turn's native inspection began; it was restored after the test, rather than overriding the owner's latest choice with AppexSaverMinimal.
- Settings was closed; the AV Geometry Probe host and extension were unregistered; no probe processes remained. No full-screen saver session ran. Product source and saved rendering settings were not changed.

## Next decisive comparison

The smaller AVPlayerLayer change did not repair the old extension path. The next concrete candidate is an **isolated native `com.apple.wallpaper` calibration**, following current Aerial's destination-sized remote context. It must render distinct acquire IDs and preview/presentation flags into the card so we can identify which request actually supplies the Settings image. Then run the same marker measurement and verify an independently composed small grid can be confined to that image. This would test the newly identified interface, not assert in advance that migration fixes the issue.

The [pinned source audit](aerial-wallpaper-research.md) identifies the request parser, registration model, context creation, scale handling, content gravity, updates and limits. Aerial also contains a plain-layer/IOSurface workaround for a different remote video-surface mapping failure; that half-size symptom is not our 10% anisotropic distortion. Do not copy that workaround as an unexplained fix or submit the Apple draft as proof of a platform-wide limitation.
