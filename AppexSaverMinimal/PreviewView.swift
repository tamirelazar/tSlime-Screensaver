//
//  PreviewView.swift
//  AppexSaverMinimal
//
//  Copyright © 2026 Guillaume Louel. Licensed under the MIT License.
//
//  NSView that runs the same RainbowAnimator the screensaver extension uses,
//  so the host app's Preview window matches what the screensaver displays.
//

import AppKit

final class PreviewView: NSView {

    private let terminal = TerminalManager()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func makeBackingLayer() -> CALayer {
        let layer = CALayer()
        layer.backgroundColor = NSColor.black.cgColor
        layer.isOpaque = true
        return layer
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
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

    deinit {
        terminal.stop()
    }
}
