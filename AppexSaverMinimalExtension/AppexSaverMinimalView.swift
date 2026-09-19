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

    private let terminal = TerminalManager()

    override init?(frame: NSRect, isPreview: Bool) {
        logger.info("init(frame: \(frame.size.width, privacy: .public)x\(frame.size.height, privacy: .public), isPreview: \(isPreview))")
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        animationTimeInterval = 1.0 / 60.0
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    deinit {
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
    // TerminalManager relaunches cbonsai once the real size arrives (cbonsai
    // cannot re-layout after SIGWINCH).

    override func startAnimation() {
        logger.info("startAnimation()")
        super.startAnimation()
        terminal.start()
    }

    override func stopAnimation() {
        logger.info("stopAnimation()")
        terminal.stop()
        super.stopAnimation()
    }

    // MARK: - View Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        logger.info("viewDidMoveToWindow() hasWindow=\(self.window != nil)")

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

