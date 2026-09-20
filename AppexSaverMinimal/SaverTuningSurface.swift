//
//  SaverTuningSurface.swift
//  Host app only.
//
//  Copyright © 2026 Guillaume Louel. Licensed under the MIT License.
//
//  The surface the user tunes the saver on: the real screensaver, rendered
//  full-screen at screensaver level on every display, with a settings panel
//  floating over it on the main one.
//
//  It used to be a preview that dismissed itself on the first mouse or key
//  event, the way a screensaver does. That behaviour is gone — the user has
//  to be able to operate the panel — and with it went the hidden cursor. What
//  stays is the window level: over the menu bar, over everything, which is
//  what makes the render true to the conditions the braille is actually
//  judged in. Because nothing else is reachable while it is up, **Exit has to
//  exist**, and Escape is its accelerator.
//
//  The panel sits at the centre of the render (#26), which is also where the
//  trails converge, so it can be dragged by its title row and hidden. Hide
//  brings the dismiss reflex back, scoped to the panel: while it is hidden
//  the next mouse move, click or key press reveals it and goes nowhere else.
//
//  (This is not the System Settings preview instance, which is a different
//  thing hosted by a different process — see CONTEXT.md.)
//

import AppKit
import SwiftUI

private let logger = AppexLog.logger("TuningSurface")

/// A borderless window that can take keyboard focus.
///
/// Borderless windows refuse key status by default, which would leave every
/// control on the panel dead. The panel is the only reason this window exists,
/// so the refusal has to be overridden rather than worked around.
private final class TuningSurfaceWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class SaverTuningSurface {
    static let shared = SaverTuningSurface()

    /// The URL scheme the extension's Options sheet opens this surface with.
    /// Registered as `CFBundleURLTypes` in the host app's Info.plist; the
    /// extension carries its own copy of this string, because the two targets
    /// share no file that could hold it.
    static let urlScheme = "appexsaverminimal"

    /// How long after Hide a mouse *move* is not yet "the next input". The
    /// hand that clicked Hide is still on the mouse, and the tremor of
    /// letting go would otherwise bring the panel straight back. Clicks and
    /// keys are deliberate and reveal at once.
    static let mouseMoveGrace: TimeInterval = 1.0

    private var windows: [NSWindow] = []
    private var inputMonitor: Any?
    /// The panel, as the subview the surface positions. Nil when not showing.
    private var panel: NSView?
    private var isPanelHidden = false
    private var hiddenAt = Date.distantPast
    #if canImport(SwiftTerm)
    private var stores: [SaverSettingsStore] = []
    #endif

    private var isShowing: Bool { !windows.isEmpty }

    /// Show the saver full-screen on all connected displays, with the panel
    /// over the main one.
    @MainActor
    func show() {
        guard !isShowing else {
            // Already up and possibly behind something: bring it back rather
            // than doing nothing, since the URL scheme can ask for it twice.
            for window in windows { window.orderFront(nil) }
            windows.first?.makeKey()
            revealPanel()
            return
        }

        // Every window is built before the panel is added, because the panel
        // stages into one store per screen and needs all of them.
        let panelScreen = NSScreen.main ?? NSScreen.screens.first
        var panelHost: (window: NSWindow, container: NSView)?

        for screen in NSScreen.screens {
            let window = TuningSurfaceWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )

            window.level = .screenSaver
            window.isOpaque = true
            window.backgroundColor = .black
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.ignoresMouseEvents = false
            // A mouse move only becomes an event a monitor can see if the
            // window asks for it; Hide's "next input" includes a move.
            window.acceptsMouseMovedEvents = true
            window.hasShadow = false
            // We keep a strong reference to each window in `windows`, so ARC must
            // own its lifetime. Leaving this `true` would make -close send an extra
            // release that ARC doesn't know about, over-releasing the window and
            // crashing (EXC_BAD_ACCESS) when the array drops its reference on dismiss.
            window.isReleasedWhenClosed = false

            let contentFrame = window.contentLayoutRect
            let container = NSView(frame: contentFrame)
            container.autoresizingMask = [.width, .height]

            #if canImport(SwiftTerm)
            // One store per screen: a store carries a single callback per
            // group, so one shared across screens would drive only the render
            // that attached last. The panel stages into all of them together.
            let store = SaverSettingsStore()
            stores.append(store)
            let preview = PreviewView(frame: container.bounds, settings: store)
            #else
            let preview = PreviewView(frame: container.bounds)
            #endif
            preview.autoresizingMask = [.width, .height]
            container.addSubview(preview)

            window.contentView = container
            windows.append(window)
            if screen == panelScreen { panelHost = (window, container) }

            window.orderFront(nil)
        }

        let host = panelHost ?? windows.first.map { ($0, $0.contentView!) }
        if let host {
            addPanel(to: host.container)
            // Key status goes to the screen holding the panel, so its controls
            // are live the moment the surface appears.
            host.window.makeKeyAndOrderFront(nil)
        }
        installInputMonitor()
        logger.notice("diag tuning surface shown on \(self.windows.count, privacy: .public) screen(s)")
    }

    /// Close the surface. Anything staged and not accepted is dropped, which
    /// is safe because Discard is a visible click away while the panel is up.
    @MainActor
    func dismiss() {
        guard isShowing else { return }
        removeInputMonitor()

        // Close all windows to release their content views immediately, which
        // is what stops each screen's tslime.
        for window in windows {
            window.close()
        }
        windows.removeAll()
        panel = nil
        isPanelHidden = false
        #if canImport(SwiftTerm)
        stores.removeAll()
        #endif
        logger.notice("diag tuning surface dismissed")
    }

    // MARK: - The panel

    /// Adds the panel at the centre of `container`. Positioned by frame, not
    /// constraints, because it moves: a drag is a frame change, and a
    /// constraint would fight every one.
    @MainActor
    private func addPanel(to container: NSView) {
        #if canImport(SwiftTerm)
        let model = SettingsPanelModel(stores: stores)
        let view = SettingsPanelView(
            model: model,
            onExit: { [weak self] in self?.dismiss() },
            onHide: { [weak self] in self?.hidePanel() },
            onDrag: { [weak self] delta in self?.movePanel(by: delta) })
        let hosting = NSHostingView(rootView: view)
        // The sheet was decided over a black render in dark appearance; it
        // stays that way whatever the system theme is.
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.autoresizingMask = []
        let size = hosting.fittingSize
        hosting.frame = NSRect(
            x: ((container.bounds.width - size.width) / 2).rounded(),
            y: ((container.bounds.height - size.height) / 2).rounded(),
            width: size.width, height: size.height)
        // A subview, not a second window: it cannot lose a z-order fight with
        // the render it sits on.
        container.addSubview(hosting)
        panel = hosting
        #endif
    }

    /// Moves the panel by `delta` (window coordinates), keeping it on the
    /// screen: a panel dragged off it could not be dragged back.
    @MainActor
    private func movePanel(by delta: CGPoint) {
        guard let panel, let container = panel.superview else { return }
        var frame = panel.frame
        frame.origin.x = min(max(frame.origin.x + delta.x, 0), container.bounds.width - frame.width)
        frame.origin.y = min(max(frame.origin.y + delta.y, 0), container.bounds.height - frame.height)
        panel.frame = frame
    }

    /// Takes the panel away. It keeps its position and its staged values;
    /// only the next input brings it back, and that input goes nowhere else.
    @MainActor
    private func hidePanel() {
        guard let panel, !isPanelHidden else { return }
        isPanelHidden = true
        hiddenAt = Date()
        panel.isHidden = true
        installInputMonitor()
        logger.notice("diag tuning panel hidden")
    }

    @MainActor
    private func revealPanel() {
        guard isPanelHidden else { return }
        isPanelHidden = false
        panel?.isHidden = false
        installInputMonitor()
        logger.notice("diag tuning panel revealed")
    }

    // MARK: - Input

    /// While the panel shows, Escape exits and nothing else is intercepted:
    /// every other event goes to the panel's controls or, harmlessly, to the
    /// render. While it is hidden the monitor widens to the mouse as well,
    /// and the first thing it sees reveals the panel and is swallowed — so
    /// Escape while hidden reveals, and a second Escape exits.
    private func installInputMonitor() {
        removeInputMonitor()
        let mask: NSEvent.EventTypeMask = isPanelHidden
            ? [.keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown]
            : [.keyDown]
        inputMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self else { return event }
            if self.isPanelHidden {
                if event.type == .mouseMoved,
                   Date().timeIntervalSince(self.hiddenAt) < Self.mouseMoveGrace {
                    return event
                }
                Task { @MainActor in self.revealPanel() }
                return nil
            }
            guard event.type == .keyDown, event.keyCode == 53 else { return event }   // Escape
            Task { @MainActor in self.dismiss() }
            return nil
        }
    }

    private func removeInputMonitor() {
        if let inputMonitor {
            NSEvent.removeMonitor(inputMonitor)
        }
        inputMonitor = nil
    }
}

// MARK: - Rendering the panel without taking the screen

#if canImport(SwiftTerm)

/// An offscreen window is never key, and AppKit draws prominent buttons and
/// switches inactive-grey when it is not. The real panel lives in a key
/// window, so lie about it here. The public overrides are not what cells
/// consult; the private ones are.
private final class KeyOffscreenWindow: NSWindow {
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
    @objc func hasKeyAppearance() -> Bool { true }
    @objc func _hasActiveAppearance() -> Bool { true }
    @objc func _hasActiveControls() -> Bool { true }
    @objc func _hasKeyAppearance() -> Bool { true }
}

extension SaverTuningSurface {

    /// `--render-panel PATH`: writes the panel to a PNG at 2x, in dark
    /// appearance, and returns true so the app can exit instead of opening
    /// its window. The surface takes over every screen, so this is how the
    /// panel's layout is checked without taking one (scripts/render-panel.sh).
    ///
    /// The values are the domain's with the dot size nudged, so the buttons
    /// draw enabled. Material cannot render offscreen — there is no
    /// compositor behind a bitmap — so the sheet is composited over a flat
    /// dark fill of its own shape; everything else is the real view.
    @MainActor
    static func renderPanelIfAsked() -> Bool {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--render-panel"), i + 1 < args.count else { return false }
        let url = URL(fileURLWithPath: args[i + 1])
        _ = NSApplication.shared

        let model = SettingsPanelModel(stores: [SaverSettingsStore()])
        model.dotSizeFraction = min(model.dotSizeFraction + 0.05, BrailleSettings.dotSizeFractionRange.upperBound)
        let view = SettingsPanelView(model: model, onExit: {}, onHide: {}, onDrag: { _ in })
        let hosting = NSHostingView(rootView: view)
        hosting.appearance = NSAppearance(named: .darkAqua)
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = KeyOffscreenWindow(contentRect: hosting.frame, styleMask: [.borderless],
                                        backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        hosting.layoutSubtreeIfNeeded()

        // What a press lands on, since that is the part of a drag that can be
        // checked without a screen: the title row must reach the drag handle
        // and the close glyph must not. Hosting views are flipped, so y is
        // measured from the top.
        for (what, point) in [("title row", NSPoint(x: 120, y: 30)),
                              ("close glyph", NSPoint(x: size.width - 32, y: 30)),
                              ("dot-size slider", NSPoint(x: 220, y: 100))] {
            let hit = hosting.hitTest(hosting.convert(point, to: hosting.superview))
            print("render-panel: a press on the \(what) lands on \(hit.map { String(describing: type(of: $0)) } ?? "nothing")")
        }

        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
            FileHandle.standardError.write("render-panel: could not make a bitmap\n".data(using: .utf8)!)
            return true
        }
        rep.size = size
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        guard let panelImage = rep.cgImage,
              let ctx = CGContext(data: nil, width: panelImage.width, height: panelImage.height,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            FileHandle.standardError.write("render-panel: could not draw\n".data(using: .utf8)!)
            return true
        }
        ctx.scaleBy(x: scale, y: scale)
        let rect = CGRect(origin: .zero, size: size)
        let radius = SettingsPanelView.cornerRadius
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fill(rect)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.setFillColor(NSColor(white: 0.13, alpha: 1).cgColor)
        ctx.fillPath()
        ctx.draw(panelImage, in: rect)

        guard let out = ctx.makeImage(),
              let png = NSBitmapImageRep(cgImage: out).representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write("render-panel: could not encode\n".data(using: .utf8)!)
            return true
        }
        do {
            try png.write(to: url)
            print("render-panel: \(url.path) (\(Int(size.width))x\(Int(size.height)) pt at \(Int(scale))x)")
        } catch {
            FileHandle.standardError.write("render-panel: \(error)\n".data(using: .utf8)!)
        }
        return true
    }
}

#endif
