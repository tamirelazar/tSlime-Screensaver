# Aerial native-wallpaper source audit

The subsequent [native comparison](working-saver-comparison.md) tested the cheaper Aerial 4.0-style AVPlayerLayer construction and measured the same 0.897 ratio. The new native wallpaper path below has not yet been implemented or tested for tSlime.

**Scope.** This is a read-only audit of Aerial at commit [`2fcb2b8a357bd9580cea48500848b339a01e01b5`](https://github.com/AerialScreensaver/Aerial/tree/2fcb2b8a357bd9580cea48500848b339a01e01b5), plus the pre-wallpaper ScreenSaver extension at [`55eddc3def7c4c39bb15c16ab29b906ab39fdd2b`](https://github.com/AerialScreensaver/Aerial/tree/55eddc3def7c4c39bb15c16ab29b906ab39fdd2b). The current source is a native `com.apple.wallpaper` extension; it does not contain the old `AerialScreenSaverExtension` target. This report separates source-established facts from interpretation.

## Current native path, end to end

1. **System Settings asks for a picker model; this is not the live preview renderer.** Aerial publishes the same one-item model for both `desktop` and `screenSaver` [at lines 14–84](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/SettingsProvider.swift#L14-L84). Both the `ChoiceDescriptor` and `SettingsItem` use an image URL [at lines 33–52](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/SettingsProvider.swift#L33-L52).

2. **That picker thumbnail is a pre-bundled PNG copied to the extension cache.** `aerialThumbnailURL()` loads `aerial-thumbnail.png`, atomically writes it as `aerial-thumbnail-photo.png`, and returns that URL [at lines 135–155](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/SettingsProvider.swift#L135-L155). It does not create a `CAContext`, render video, or provide a view. Therefore it cannot explain or repair the selected live-image aspect distortion.

3. **The live surface enters through the XPC `acquire` request.** Aerial mirror-walks the request’s `destination` to take `size`, `scaleFactor`, and `directDisplayID` [at lines 104–128](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/WallpaperXPCHandler.swift#L104-L128). In `acquire`, it uses that tuple directly; only a missing/unreadable request falls back to `2560×1440 @2x` [at lines 1859–1863](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/WallpaperXPCHandler.swift#L1859-L1863). Thus no source-defined special preview size exists in Aerial’s current geometry path.

4. **Preview classification is independent of geometry.** The request parser reads `isPreview`, `presentationMode`, and other context fields [at lines 43–101](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/WallpaperXPCHandler.swift#L43-L101). `isPreview` excludes an idle request from saver classification [at lines 257–263](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/Shared/Wallpaper/WallpaperControlState.swift#L257-L263) and is retained to route policy/diagnostics [at lines 133–160](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/WallpaperHandlerState.swift#L133-L160). Neither branch substitutes a thumbnail-sized frame or scales the root differently.

5. **Aerial makes the remote Context’s point/pixel contract explicit at construction.** It passes the request `scaleFactor` as `contentsScale` and the display ID to `CAContext.remoteContextWithOptions:` [at lines 1899–1917](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/WallpaperXPCHandler.swift#L1899-L1917), then tries to set/read the same value for diagnostics [at lines 1928–1953](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/WallpaperXPCHandler.swift#L1928-L1953). The remote-context ID is the sole value packed into `WallpaperRemoteContextXPC` [at lines 9–28](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/RuntimeHelpers.swift#L9-L28).

6. **At acquire, the root and video/content layers are explicitly sized in destination *points* and each receives the request scale.** Aerial sets `rootLayer.frame = (0,0,destination.size)`, `rootLayer.contentsScale = scaleFactor`, attaches it to the CAContext, and flushes [at lines 1964–1984](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/WallpaperXPCHandler.swift#L1964-L1984). The normal video layer is built with the same size/scale [at lines 784–791](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/Rendering/VideoRenderer.swift#L784-L791); its production contents-swap layer likewise gets the destination frame and scale [at lines 2037–2058](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/WallpaperXPCHandler.swift#L2037-L2058). There is no root autoresizing-mask assignment in the current extension source.

7. **Scaling uses aspect fill/fit, not `resize`/anisotropic stretch.** The AV sample-buffer layer maps Aerial’s mode to `resizeAspectFill` or `resizeAspect` [at lines 317–335](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/WallpaperXPCHandler.swift#L317-L335) and applies the chosen gravity before optional spanned geometry [at lines 2065–2082](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/WallpaperXPCHandler.swift#L2065-L2082). The contents-swap layer gets the equivalent `CALayer.contentsGravity` mapping in those same lines.

8. **Destination changes are an explicit, but partial, re-layout path.** On update, if request size/scale/display changes, Aerial changes the video/swap frames and their `contentsScale`, and changes `rootLayer.contentsScale`, inside a disabled-actions transaction [at lines 2452–2478](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/WallpaperXPCHandler.swift#L2452-L2478). Those lines do **not** rewrite `rootLayer.frame` or the CAContext creation scale. The source thus establishes initial acquire alignment, not perpetual three-way equality after a destination-size update.

## The material geometry difference to probe

### Established fact

At initial acquire, the current Aerial implementation establishes this three-way alignment:

| Quantity | Aerial source behavior |
|---|---|
| Context mapping | `CAContext` is constructed with `contentsScale = request.destination.scaleFactor` |
| Root geometry | `(0,0, request.destination.size)` with that same `contentsScale` |
| Content geometry | video/contents-swap layer starts at the same size and scale |

It additionally selects aspect-preserving gravity. Its explicit code comments describe a macOS 26.5.2 remote-context adoption scale failure and say a fully sized tree had been composited as half size; those comments are Aerial maintainers’ field diagnosis, not an Apple API guarantee [at lines 1900–1905](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/WallpaperXPCHandler.swift#L1900-L1905) and [at lines 2004–2022](https://github.com/AerialScreensaver/Aerial/blob/2fcb2b8a357bd9580cea48500848b339a01e01b5/WallpaperExtension/XPC/WallpaperXPCHandler.swift#L2004-L2022).

### Limits and inference for tSlime

Current tSlime uses `com.apple.screensaver`, not the native `com.apple.wallpaper` extension point audited above. Its colloquial Settings-selected “wallpaper instance” must not be treated as a native WallpaperExtension `acquire`; tSlime has not observed such an acquire. Consequently, Aerial’s `isPreview` field may still label an unused native surface in a future control, but it says nothing decisive about the current target. A unique content ID in any calibration grid is required to prove which instantiated surface is actually visible.

If an isolated native wallpaper control is later built, and its root has no autoresizing mask, that fact alone does not test the Aerial mechanism: compare the **remote CAContext creation scale**, root frame/scale, and visible child frame/scale against that native request destination. A mismatch can produce a reduced or distorted hosted surface even when every local layer looks correctly framed.

The observed `sx/sy = 0.897` is **not** the simple 2× point/pixel error that Aerial’s comments discuss. The Aerial source therefore does **not** establish that copying its native wallpaper path fixes that anisotropic calibration. It does establish a narrowly transferable diagnostic/control mechanism: source every geometry value from the request destination, make context scale explicit at creation, and log/read back the resulting mapping.

## Test order and smallest decisive native control (no implementation proposal)

The cheaper calibration on tSlime’s existing private ScreenSaver path is now complete: the isolated `AVPlayerLayer` construction still measured 0.897. See the [native test record](working-saver-comparison.md). This tested a rendering change without claiming a native wallpaper acquire exists.

The next candidate is a separate isolated native `com.apple.wallpaper` control. Select that control in System Settings and use a deliberately non-square calibration grid with a unique content ID and marks at 0%, 50%, and 100% in both axes. For the exact native `acquire` and first subsequent `update`, record in one line each:

1. request `destination.size`, `destination.scaleFactor`, and `directDisplayID`;
2. CAContext creation options and any readable effective `contentsScale`;
3. root frame/bounds/`contentsScale` and the visible content child’s frame/bounds/`contentsScale`/gravity; and
4. the on-screen grid bounds and unique ID measured in the selected live image.

Interpretation: if (1)–(3) agree but (4) remains `sx/sy≈0.897`, the native-control defect is downstream host composition or its calibration transform; changing an autoresizing mask or Aerial-style view classification is unsupported. If the Context scale differs from (1), or a root/child dimension or scale differs from it, that mismatched field is the smallest concrete target. The unique ID distinguishes the selected native surface from any unused preview surface and from the static picker thumbnail.

## Historical comparison: old ScreenSaver extension

The v4.0.14 implementation was an `NSView`/`AVPlayerLayer` saver, not a remote wallpaper CAContext. Its controller inferred preview from `NSScreen.main.frame.width < 400` [at lines 33–52](https://github.com/AerialScreensaver/Aerial/blob/55eddc3def7c4c39bb15c16ab29b906ab39fdd2b/AerialScreenSaverExtension/AerialViewController.swift#L33-L52). Its player layer used aspect fill/fit and was inserted below other content [at lines 901–919](https://github.com/AerialScreensaver/Aerial/blob/55eddc3def7c4c39bb15c16ab29b906ab39fdd2b/AerialScreenSaverExtension/AerialSaverView.swift#L901-L919); `layout()` explicitly invokes geometry refresh [at lines 887–897](https://github.com/AerialScreensaver/Aerial/blob/55eddc3def7c4c39bb15c16ab29b906ab39fdd2b/AerialScreenSaverExtension/AerialSaverView.swift#L887-L897), and normal modes assign the layer to `bounds` [at lines 935–970](https://github.com/AerialScreensaver/Aerial/blob/55eddc3def7c4c39bb15c16ab29b906ab39fdd2b/AerialScreenSaverExtension/AerialSaverView.swift#L935-L970). This is the relevant lower-cost renderer control; it has no evidence about remote-context host scaling.
