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

    private var windows: [NSWindow] = []
    private var escapeMonitor: Any?
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
        installEscapeMonitor()
        logger.notice("diag tuning surface shown on \(self.windows.count, privacy: .public) screen(s)")
    }

    /// Close the surface. Anything staged and not accepted is dropped, which
    /// is safe because Discard is a visible click away while the panel is up.
    @MainActor
    func dismiss() {
        guard isShowing else { return }
        removeEscapeMonitor()

        // Close all windows to release their content views immediately, which
        // is what stops each screen's tslime.
        for window in windows {
            window.close()
        }
        windows.removeAll()
        #if canImport(SwiftTerm)
        stores.removeAll()
        #endif
        logger.notice("diag tuning surface dismissed")
    }

    // MARK: - The panel

    @MainActor
    private func addPanel(to container: NSView) {
        #if canImport(SwiftTerm)
        let model = SettingsPanelModel(stores: stores)
        let panel = SettingsPanelView(model: model) { [weak self] in
            self?.dismiss()
        }
        let hosting = NSHostingView(rootView: panel)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        // A subview, not a second window: it cannot lose a z-order fight with
        // the render it sits on. Where it sits and how big it is are #26.
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -40),
            hosting.topAnchor.constraint(equalTo: container.topAnchor, constant: 40)
        ])
        #endif
    }

    // MARK: - Escape

    /// Escape exits, and nothing else is intercepted.
    ///
    /// The surface used to swallow the first event of any kind and tear down;
    /// this monitor passes every event through except the one key that stands
    /// in for the mouse-dismiss reflex the user no longer has.
    private func installEscapeMonitor() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }   // Escape
            Task { @MainActor in self?.dismiss() }
            return nil
        }
    }

    private func removeEscapeMonitor() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
        }
        escapeMonitor = nil
    }
}
