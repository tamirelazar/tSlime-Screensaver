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

    private let terminal: TerminalManager

    /// - Parameter settings: the store this view's terminal draws from. The
    ///   tuning surface passes one store shared by every screen, so a staged
    ///   value reaches all of them at once; left out, the view reads the
    ///   domain on its own like the screensaver does.
    #if canImport(SwiftTerm)
    init(frame frameRect: NSRect, settings: SaverSettingsStore) {
        terminal = TerminalManager(settings: settings)
        super.init(frame: frameRect)
        wantsLayer = true
    }
    #endif

    override init(frame frameRect: NSRect) {
        terminal = TerminalManager()
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        terminal = TerminalManager()
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
