# Community reports and published workarounds

Researched 2026-09-23 against original developer reports, release notes and source commits. Scope: the large live selected-saver image, its framing/proportions, and the separate `isPreview` instance. No native tests or product changes were made during this online research.

## Answer

Other developers report Tahoe's two-instance/incorrect-preview behavior. There are published workarounds for preview classification, legacy viewport sizing and lifecycle management. None of the reviewed sources demonstrates a fix for our exact approximately 10% horizontal compression or a supported independent composition route for the large Settings image. That is a bounded search result, not proof that none exists.

## 1. WebViewScreenSaver: a concrete, shipped scaling fix

Users reported web content positioned off the top-right of the screen on macOS 26, while macOS 15 worked. The maintainer fixed it by removing **the root ScreenSaverView's** `NSViewWidthSizable | NSViewHeightSizable` autoresizing mask. This is a one-line patch, shipped in **v2.5 on 2025-11-15**. Sources: [original report and maintainer confirmation](https://github.com/liquidx/webviewscreensaver/issues/90#issuecomment-3536861586), [exact fix](https://github.com/liquidx/webviewscreensaver/commit/f5bc558ad35de7162ea319a8de80982b2db23828), [release](https://github.com/liquidx/webviewscreensaver/releases/tag/v2.5).

**Local applicability:** our product's `AppexSaverMinimalView` and controller do not explicitly set that outer mask; the disposable `GeometryView.m` does. This gives us a useful one-variable calibration control before assigning the distortion entirely to the host. It is not yet a verified fix for our product or the measured aspect ratio. A child terminal view's autoresizing policy is a different setting.

**Subsequent native control, 2026-09-23:** removing that single assignment did **not** improve our result. Two selections both measured horizontal/vertical scale 0.897, matching the baseline reselection; fresh processes still logged full 1920×1080 bounds. The probe now omits the assignment. See the [test record and captures](README.md#root-autoresizing-control--no-improvement). This rules out the published one-line change as a fix for this reproduction, without contradicting its success for WebViewScreenSaver's different symptom.

## 2. ScreenSaverMinimal: infer preview from lock state

The author published an experimental change on **2025-07-28**, then made it optional on **2025-07-29**. It reads the session's `CGSSessionScreenIsLocked` value: locked means full-screen; unlocked means preview, regardless of the incoming `isPreview`. It passes that reclassified value into the saver initializer. The follow-up checks whether System Settings is running and exits an inferred preview after Settings closes. Sources: [initial implementation](https://github.com/AerialScreensaver/ScreenSaverMinimal/commit/f94b6e787ce6554bf4dee3372eac1d5f2cd8ed16), [optional workaround and cleanup](https://github.com/AerialScreensaver/ScreenSaverMinimal/commit/6f6a39932af1d13e34c6d81f9a7d90262cc3d9e1).

**Local applicability:** this could let the *currently displayed false instance* choose a different composition; it need not reroute the separate true instance to be useful. However, unlocked does not reliably mean Settings: the actual saver can run before locking or during a password grace period. It therefore is not a trustworthy preview-only selector without further evidence. It does not itself fix aspect-ratio scaling. The repository's [README](https://github.com/AerialScreensaver/ScreenSaverMinimal) still says no known Tahoe workaround, so that sentence should not obscure the narrower experimental code that is actually published.

## 3. iScreensaver: vendor claims a preview fix, mechanism unpublished

The vendor's **6.9.1 release, 2025-09-16**, says it fixed nonfunctioning System Settings preview mode on Tahoe 26.0. Their prescribed solution is to update the authoring tool, rebuild the saver, and redistribute it. The same notes retain an intermittent missing-preview problem; moving the pointer over the image may wake it. [Vendor release notes](https://forum.iscreensaver.com/t/iscreensaver-designer-6-release-notes/598).

The reviewed notes do not publish the implementation or claim to fix stretched proportions. This is a worthwhile lead to ask the author about, not a technique we can copy or a reason to recommend buying/rebuilding with that tool. No contact was made.

## 4. Legacy backing-pixel mismatch: size the child in logical points

A developer's **2026-05-06** Tahoe WebView write-up reports parent bounds of 3840×2160 on a 1920×1080 external display, with only part of the page visible. Their workaround clamps the child WebView to the screen's logical dimensions and updates its frame explicitly instead of allowing autoresizing to expand it again. [Original account and code, Trap 2](https://www.ytyng.com/en/blog/macos-26-screensaver-webview-without-xcode/).

This resembles the crop in our earlier public `.saver` probe. Our extension calibration instead logs 1920×1080 and retains all corners, so it is not evidence that this clamp would fix the extension's roughly 10% distortion. The author's assumption about which instance supplies the small preview also differs from our measured routing; do not import that assumption.

## 5. Aerial developers: same duplication, cleanup fixes, newer integration

The original [Aerial report](https://github.com/JohnCoates/Aerial/issues/1396) and [Apple Developer Forums discussion](https://developer.apple.com/forums/thread/787444) describe Settings launching both full-size and preview instances. Reported feedback includes FB18697726 and FB19201567. Developers also describe accumulated views and leftover processes. Apple DTS acknowledged and rerouted reports; that is not a published fix for the large image's geometry.

The sample's delayed `exit(0)` after `com.apple.screensaver.willstop` addresses those leftover processes. It does not repair image scaling. See [sample cleanup code](https://github.com/AerialScreensaver/ScreenSaverMinimal/blob/master/ScreenSaverMinimal/ScreenSaverMinimalView.swift#L1442-L1482). The forum reports that cleanup workarounds can themselves fail, sometimes requiring a restart.

Aerial's current project migrated from legacy `.saver` hosting to an app extension; 4.1 adds a native Wallpaper Extension. Its release notes also mention fixing wallpaper/saver classification when Settings opens. [Current repository](https://github.com/AerialScreensaver/Aerial), [4.1 release notes](https://aerialscreensaver.github.io/release-notes/). This is a broader integration change, not demonstrated correction of our selected-image proportions. Our product already uses a saver `.appex`; this research did not exhaustively trace Aerial 4.1's distinct wallpaper implementation. Do not treat old sample limitations as a statement about every current Aerial path.

## Recommended next investigation

The root-mask control is now complete and did not fix our geometry. Assess preview identification separately: the lock-state heuristic is concrete but must be tested against an actual unlocked saver, Settings, and transitions before considering it for C. The iScreensaver author may know another approach, but their release note alone does not establish one.

We have not submitted the Apple report, contacted maintainers, or installed any third-party software. The existing measurements remain valid observations of the tested probe; attribution to a particular host operation remains provisional.
