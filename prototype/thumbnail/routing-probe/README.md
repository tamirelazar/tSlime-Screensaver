# Settings preview routing comparison

Tested 2026-09-22 on macOS 26.5.1 (25F80), Apple Silicon, a 1920×1080-point display. This is a disposable diagnostic, not a product change.

## Result

The selected-saver image at the top of System Settings displayed the **full-size (`isPreview=false`) instance in all three variants**. Switching to the documented `.saver` integration did not give this image the preview instance. Starting the extension view at zero size did not change routing either.

| Variant | Preview flag source | Initial frame | Visible test card |
| --- | --- | --- | --- |
| Routing Probe Legacy | Public `ScreenSaverView.init(frame:isPreview:)` argument | Supplied by macOS | Orange full-size output; cropped, reporting 3840×2160 bounds |
| Routing Probe Appex | Extension handshake, as in the product | Main screen, 1920×1080 | Orange `APPEX FULL / F`, 1920×1080 |
| Routing Probe Zero | Same extension handshake | Zero | Orange `ZERO FULL / F`, eventually 1920×1080 |

The shared renderer draws blue `P` for `isPreview=true`, orange `F` otherwise, with a border, kind, bounds, PID, and a ticking counter. It uses AppKit drawing only: no SwiftTerm, Metal renderer, PTY, settings persistence, or simulation. The legacy card was observed repeatedly, including after switching through both extension variants.

Logs confirmed separate true and false instances. For the decisive final extension selections, the orange card PIDs matched the false instances: APPEX 56262 and ZERO 56330. The legacy full-size PID was 45836; its true counterpart was 45835. See `observations.txt`.

This isolates the same routing behavior outside the product. It rules out the terminal renderer and our screen-sized initial frame as necessary causes, and shows that changing integration format alone is not a workaround on this OS. It does **not** establish behavior on other macOS versions, prove that every alternate preview mechanism is impossible, or distinguish an Apple bug from a deliberate but undocumented implementation choice. No full-screen saver session was started in this experiment.

Recommendation: keep the chosen 64×20 composition as a design preference, but do not apply it to the false instance just to change this image: the real saver uses that instance class too. A preview-only implementation remains unproven. Preserve the main saver's composition pending an explicit scope decision or a verified independent preview route.

## Reproduce

1. Run `python3 build.py` from this directory. It needs the macOS SDK and command-line tools. It produces an ad-hoc-signed `.saver` and a host `.app` containing two independent extensions.
2. Install the legacy bundle through Finder. Register the host with Launch Services, then both embedded extensions with `pluginkit -a`. The test used a copy of the host beside the product's Xcode build. All bundle IDs start with `local.oozel.routing-probe`.
3. Record only the probes' logs:

   ```sh
   log stream --style compact --level info --predicate 'subsystem == "local.oozel.routing-probe" OR eventMessage BEGINSWITH "ROUTING-PROBE"'
   ```

4. In System Settings → Wallpaper → Screen Saver → Other → Show All, scroll to the **bottom** of the collection. Select each probe. Observe the large selected-saver image, not its static catalog tile. A blue `P` would demonstrate preview-instance routing; orange `F` reproduces the result here. Match its PID/bounds to the log.
5. Restore the original saver. Unregister the test extensions and host, remove the installed legacy saver and test host, and stop any verified test-only lingering processes.

The normal product source and build were untouched. AppexSaverMinimal was restored and its live green animation verified; the installed probes and their remaining processes were removed after this run.

## UI automation caveat

The catalog uses a lazily exposed collection. The first accessibility tree after “Show All” omitted the last row. `AXScrollToBottom` on the collection exposed it. Actions on the saver tiles needed the owning `com.apple.Wallpaper-Settings.extension` target; querying `com.apple.systempreferences` could show the sheet but tile selection there did not take effect. Capture the composed screenshot through System Settings. The apparent discovery failure was not established as a packaging or macOS catalog bug. Several connector calls also stalled; their elapsed time is unrelated to saver performance.

## Apple references

- [Public preview initializer](https://developer.apple.com/documentation/screensaver/screensaverview/init%28frame%3Aispreview%3A%29): documents true for Settings previews, false for full-screen content.
- [Tahoe screen saver discussion](https://developer.apple.com/forums/thread/787444): developers report extra full-size instances in Settings; Apple DTS discusses the filed bugs. Similarity is supporting context, not proof that our case has the same underlying defect.
- [Catalog thumbnail discussion](https://developer.apple.com/forums/thread/806641): Apple's support engineer says the static thumbnail convention is not a supported API. That is a different surface from the live image tested here.

`thumbnail.png` is copied from the repository's existing sample asset solely to make the temporary catalog tiles recognizable. No conclusion about catalog-thumbnail support is based on that asset.
