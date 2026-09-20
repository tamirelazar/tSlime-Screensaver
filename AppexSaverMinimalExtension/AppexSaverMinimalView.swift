//
//  AppexSaverMinimalView.swift
//  AppexSaverMinimalExtension
//
//  Copyright © 2026 Guillaume Louel. Licensed under the MIT License.
//
//  ScreenSaverView that displays the rainbow color animation. The actual
//  animation logic lives in RainbowAnimator (shared with the host app's
//  PreviewView).
//
//  Two equally valid rendering options exist for an Appex screensaver:
//    1. Direct CALayer animation driven by your own Timer or CABasicAnimation
//       (this sample's approach — see RainbowAnimator).
//    2. The traditional ScreenSaverView overrides (startAnimation,
//       stopAnimation, animateOneFrame). Both work; pick whichever fits
//       your animation model.
//
//  SwiftUI can also be used for screensaver content via NSHostingView: create
//  the SwiftUI root view, wrap it in NSHostingView, and add it as a subview
//  of this ScreenSaverView. The Aerial screensaver uses this pattern for
//  weather/clock overlays on top of video playback.
//

import AppKit
import ScreenSaver
import QuartzCore

private let logger = AppexLog.logger("View")

final class AppexSaverMinimalView: ScreenSaverView {

    private let terminal: TerminalManager

    override init?(frame: NSRect, isPreview: Bool) {
        // The System Settings preview instance runs tslime at 30 fps whatever
        // the user saved, and ignores later changes to the setting (#28, #29).
        // It is the thumbnail in the settings pane, not the tuning surface --
        // that is the host app's panel. The pane starts *two* instances, the
        // other being the wallpaper instance, which has no lever at all: it
        // is a saver instance in every observable way. So this is the whole
        // lever there is, and it halves one of the two.
        //
        // `isPreview` comes from the host's handshake (#22); the value the
        // framework would compute here has never been anything but false.
        terminal = TerminalManager(frameRateOverride: isPreview ? .thirty : nil)
        logger.info("init(frame: \(frame.size.width, privacy: .public)x\(frame.size.height, privacy: .public), isPreview: \(isPreview))")
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        // Don't override animationTimeInterval: we don't implement animateOneFrame,
        // so a 60fps timer would fire 60 no-op callbacks/sec on the main queue.
    }

    required init?(coder: NSCoder) {
        // Never reached for an appex saver: the framework builds the view
        // through init(frame:isPreview:). No archive carries isPreview, so
        // this path follows the setting like any saver instance.
        terminal = TerminalManager()
        super.init(coder: coder)
        wantsLayer = true
    }

    deinit {
        LifecycleProbe.event("view.deinit")
        LifecycleProbe.stopPolling()
        terminal.stop()
        logger.info("deinit")
    }

    // MARK: - Layer Setup

    override func makeBackingLayer() -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = NSColor.black.cgColor
        layer.isOpaque = true
        return layer
    }

    // MARK: - ScreenSaverView Overrides
    //
    // The view is created at a guessed size; the host delivers the real
    // surface size only after the view is attached to the remote window (via
    // remoteViewSizeChanged: on the view controller). Delivery of
    // startAnimation to this view is not guaranteed on every macOS version,
    // so the terminal starts eagerly in viewDidMoveToWindow and
    // TerminalManager relaunches tslime once the real size arrives (the
    // child lays out for the grid it starts with).

    override func startAnimation() {
        logger.info("startAnimation()")
        LifecycleProbe.event("view.startAnimation", LifecycleProbe.census(self))
        super.startAnimation()
        terminal.start()
    }

    override func stopAnimation() {
        logger.info("stopAnimation()")
        LifecycleProbe.event("view.stopAnimation", LifecycleProbe.census(self))
        terminal.stop()
        super.stopAnimation()
    }

    // MARK: - Lifecycle probe (issue #9)
    //
    // The two callbacks the ticket asks about by name. AppKit calls them when
    // the view (or an ancestor) has its `isHidden` toggled -- which is not the
    // same thing as the saver being off screen, and may well never fire in a
    // remote-hosted view. Observed, not relied upon.

    override func viewDidHide() {
        super.viewDidHide()
        LifecycleProbe.event("view.viewDidHide", LifecycleProbe.census(self))
    }

    override func viewDidUnhide() {
        super.viewDidUnhide()
        LifecycleProbe.event("view.viewDidUnhide", LifecycleProbe.census(self))
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        LifecycleProbe.event("view.viewDidMoveToSuperview", "hasSuperview=\(self.superview != nil) \(LifecycleProbe.census(self))")
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        LifecycleProbe.event("view.viewWillMoveToWindow", "newWindow=\(newWindow?.windowNumber ?? -1) \(LifecycleProbe.census(self))")
    }

    // MARK: - View Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        logger.info("viewDidMoveToWindow() hasWindow=\(self.window != nil)")
        LifecycleProbe.event("view.viewDidMoveToWindow", LifecycleProbe.census(self))
        if self.window != nil {
            LifecycleProbe.startPolling(self, tag: isPreview ? "preview" : "saver")
        } else {
            LifecycleProbe.stopPolling()
        }

        if self.window != nil {
            terminal.attach(to: self)
            terminal.updateFrame(bounds)
            terminal.start()
        } else {
            terminal.stop()
        }
    }

    override func layout() {
        super.layout()
        terminal.updateFrame(bounds)
    }
}

