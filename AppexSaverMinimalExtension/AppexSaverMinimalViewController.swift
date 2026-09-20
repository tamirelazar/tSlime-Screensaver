//
//  AppexSaverMinimalViewController.swift
//  AppexSaverMinimalExtension
//
//  Copyright © 2026 Guillaume Louel. Licensed under the MIT License.
//
//  Main view controller for the screensaver. Specified as
//  ScreenSaverViewControllerClass in Info.plist as
//  `$(PRODUCT_MODULE_NAME).AppexSaverMinimalViewController`.
//
//  Mirrors Apple's Arabesque.appex pattern: only override the standard
//  init(nibName:bundle:), init(coder:), and loadView(); let the framework
//  drive everything else.
//

import AppKit
import ScreenSaver

private let logger = AppexLog.logger("ViewController")

@objc(AppexSaverMinimalViewController)
class AppexSaverMinimalViewController: ScreenSaverViewController {

    /// Strong reference so the framework can't drop our view while we still own it.
    private var saverView: AppexSaverMinimalView?

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        logger.info("init(nibName:bundle:)")
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        logger.info("init(coder:)")
        super.init(coder: coder)
    }

    deinit {
        logger.info("deinit")
    }

    /// Called by the framework to create the view.
    override func loadView() {
        logger.info("loadView()")
        LifecycleProbe.event("vc.loadView")

        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        // Issue #22. The sample-code idiom here is `frame.width < 400`, but
        // `frame` is the *screen's* frame rather than a host-supplied one, so
        // that test could never be true: the preview case was unreachable and
        // the answer was always `false`. The host states the real value on the
        // handshake four milliseconds earlier -- see HostHandshake -- and
        // `false` is kept only as the fallback the old test amounted to.
        let isPreview = HostHandshake.isPreview(fallback: false)

        let view = AppexSaverMinimalView(frame: frame, isPreview: isPreview)
        saverView = view
        self.view = view ?? NSView(frame: frame)
    }

    // MARK: - Lifecycle probe (issue #9)
    //
    // ScreenSaverViewController declares startAnimation, stopAnimation,
    // invalidate, awakeFromRemoteView and remoteViewSizeChanged:transaction:
    // of its own; none of them were overridden before this instrumentation, so
    // whether the framework delivers them here -- and whether it forwards them
    // to the view -- was never observed. These overrides only log and call
    // super; the terminal is still driven from the view.

    override func viewWillAppear() {
        LifecycleProbe.event("vc.viewWillAppear", LifecycleProbe.census(viewIfLoaded))
        super.viewWillAppear()
    }

    override func viewDidAppear() {
        LifecycleProbe.event("vc.viewDidAppear", LifecycleProbe.census(viewIfLoaded))
        super.viewDidAppear()
    }

    override func viewWillDisappear() {
        LifecycleProbe.event("vc.viewWillDisappear", LifecycleProbe.census(viewIfLoaded))
        super.viewWillDisappear()
    }

    override func viewDidDisappear() {
        LifecycleProbe.event("vc.viewDidDisappear", LifecycleProbe.census(viewIfLoaded))
        super.viewDidDisappear()
    }

    override func startAnimation() {
        LifecycleProbe.event("vc.startAnimation", LifecycleProbe.census(viewIfLoaded))
        super.startAnimation()
    }

    override func stopAnimation() {
        LifecycleProbe.event("vc.stopAnimation", LifecycleProbe.census(viewIfLoaded))
        super.stopAnimation()
    }

    override func invalidate() {
        LifecycleProbe.event("vc.invalidate", LifecycleProbe.census(viewIfLoaded))
        super.invalidate()
    }

    override func awakeFromRemoteView() -> UInt64 {
        let result = super.awakeFromRemoteView()
        LifecycleProbe.event("vc.awakeFromRemoteView", "result=\(result) \(LifecycleProbe.census(viewIfLoaded))")
        LifecycleProbe.describeController(self)
        return result
    }

    override func remoteViewSizeChanged(_ size: NSSize, transaction: Any?) -> Bool {
        let result = super.remoteViewSizeChanged(size, transaction: transaction)
        LifecycleProbe.event(
            "vc.remoteViewSizeChanged",
            "size=\(Int(size.width))x\(Int(size.height)) result=\(result) \(LifecycleProbe.census(viewIfLoaded))"
        )
        return result
    }

    // The ViewBridge-level pair. If the view's own hidden/shown callbacks never
    // fire, these are the next candidates: the host window association is
    // exactly "this view is now (not) attached to something on screen".

    override func _didAssociateWithHostWindow() {
        LifecycleProbe.event("vc._didAssociateWithHostWindow", LifecycleProbe.census(viewIfLoaded))
        super._didAssociateWithHostWindow()
    }

    override func _didDisassociateFromHostWindow() {
        LifecycleProbe.event("vc._didDisassociateFromHostWindow", LifecycleProbe.census(viewIfLoaded))
        super._didDisassociateFromHostWindow()
    }

    /// Candidate for the user-input dismissal path: the host forwards the event
    /// *type* only. Logged with a count, because input arrives in bursts and one
    /// line per mouse-moved event would swamp the log.
    override func hostWindowReceivedEventType(_ type: UInt64) {
        LifecycleProbe.countEvent(type: type)
        super.hostWindowReceivedEventType(type)
    }

    override func beginAppearanceTransition(_ isAppearing: Bool) {
        LifecycleProbe.event("vc.beginAppearanceTransition", "appearing=\(isAppearing) \(LifecycleProbe.census(viewIfLoaded))")
        super.beginAppearanceTransition(isAppearing)
    }

    override func endAppearanceTransition() {
        LifecycleProbe.event("vc.endAppearanceTransition", LifecycleProbe.census(viewIfLoaded))
        super.endAppearanceTransition()
    }
}
