# Draft — not submitted to Apple

## Title

macOS 26.5.1 Screen Saver Settings distorts a 16:9 live source to approximately 16:10; separately created preview instance does not supply the large image

## Environment

- macOS 26.5.1, build 25F80, Apple Silicon.
- Display reports 1920×1080 points, backing scale 2.
- System Settings → Wallpaper → Screen Saver, Custom.
- Minimal AppKit-only test rendering; no terminal emulator, GPU renderer or simulation dependency.

## Geometry reproduction

The attached geometry probe uses the existing private `.appex` screensaver integration, not a claimed public API. `build.py` produces a separate host/extension and a 1920×1080 reference image from the same drawing function. The source has four colored edges, numbered grid lines, four known cyan corner markers, a 5% inset, and a 400×400 magenta square.

1. Build and register the probe's host and extension.
2. Open the Screen Saver sheet, expand Other and select Geometry Probe.
3. Observe the large live image above the settings controls (not the static catalog tile).
4. Compare against `reference.png`, or run `measure.py` on the supplied Settings captures.
5. Select another saver, then reselect the probe. The same geometry reproduces.

Expected: the source's proportions are preserved; its square remains square, whether the image is letterboxed or proportionally fitted.

Actual: the complete 1920×1080 card appears in approximately 160×100 screenshot pixels. Its horizontal scale is 0.900 / 0.897 of its vertical scale across two selections. All four corner markers and edges remain visible. The source view reports 1920×1080 bounds and backing scale 2. Screenshot sampling limits precision, but the roughly 10% anisotropic distortion is clear.

Control: removing the root view's explicit width/height autoresizing mask, as in WebViewScreenSaver's published Tahoe scaling fix, leaves the result unchanged. Two additional selections from fresh full-size processes both measure 0.897, with the same 1920×1080 bounds. The current attached source omits that assignment. The drawing code and offscreen reference are unchanged. This rules out that explicit assignment as a necessary condition, without proving which host operation introduces the distortion.

No full-screen saver session was started. This report does not assert the same distortion in the real full-screen session or on other macOS releases.

## Separate public-API routing reproduction

The sibling `routing-probe` includes a public `.saver` implementing `ScreenSaverView.initWithFrame:isPreview:` and two private extension variants. Every renderer draws blue `P` for true and orange `F` for false, plus its size and PID.

On this Mac, the large selected-saver image shows the false instance for all three variants. A separate true instance is also created. The public legacy case showed different cropping/size behavior (3840×2160 reported bounds); the exact 10% geometry measurement above applies only to the extension probe. Switching to public legacy integration alone did not make the large image consume the true instance.

The public initializer documentation describes true for Settings previews: https://developer.apple.com/documentation/screensaver/screensaverview/init%28frame%3Aispreview%3A%29

Related developer discussion, not proof of an identical underlying cause: https://developer.apple.com/forums/thread/787444

## Questions

1. Should the large selected-saver image preserve the source aspect ratio on macOS 26?
2. Which supported API, if any, identifies or supplies that image independently from full-size saver rendering?
3. Is the separately created true instance intended for configuration preloading rather than that live image?

## Suggested attachments

- `Calibration.h`, `Calibration.m`, `GeometryView.m`, `Render.m`, `build.py`, and sibling routing-probe sources needed to build.
- `reference.png`, `settings-capture.png`, `settings-repeat.png`, `settings-no-autoresize.png`, `settings-no-autoresize-repeat.png`.
- `measure.py` and the five measurement JSON files.
- Filtered `observations.txt` and `no-autoresize-observations.txt`, plus each probe's README.

The local private-framework disassembly helped our investigation but is not needed for this behavioral reproduction. No credentials, user preferences dump, or full system log is included. Submit this draft only after the owner chooses to do so.
