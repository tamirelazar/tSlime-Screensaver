//
//  ScreensaverPreviewController.swift
//  AppexSaverMinimal
//
//  Copyright © 2026 Guillaume Louel. Licensed under the MIT License.
//
//  Presents the PreviewView in borderless, full-screen windows at screensaver
//  level across all connected displays. Dismisses on any mouse or keyboard
//  activity, similar to a real screensaver.
//

import AppKit

final class ScreensaverPreviewController {
    static let shared = ScreensaverPreviewController()

    private var windows: [NSWindow] = []
    private var eventMonitors: [Any] = []

    private var isShowing: Bool { !windows.isEmpty }

    /// Show the preview full-screen on all connected displays.
    @MainActor
    func show() {
        guard !isShowing else { return }

        // Create one borderless window per screen at screensaver level.
        for screen in NSScreen.screens {
            let rect = screen.frame
            let window = NSWindow(
                contentRect: rect,
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

            // Fill with the same PreviewView used by the regular preview.
            let contentFrame = window.contentLayoutRect
            let preview = PreviewView(frame: contentFrame)
            preview.autoresizingMask = [.width, .height]
            window.contentView = preview

            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }

        // Hide cursor until movement, like a screensaver.
        NSCursor.hide()

        installEventMonitors()
    }

    /// Dismiss any visible preview windows and remove monitors.
    @MainActor
    func dismiss() {
        guard isShowing else { return }
        removeEventMonitors()

        // Close all windows to release their content views immediately.
        for window in windows {
            window.close()
        }
        windows.removeAll()

        // Balance the hide() performed in show().
        NSCursor.unhide()
    }

    // MARK: - Event Monitoring

    private func installEventMonitors() {
        // Local monitors swallow the first event and trigger dismissal.
        let localMasks: [NSEvent.EventTypeMask] = [
            .mouseMoved,
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .scrollWheel,
            .keyDown, .flagsChanged
        ]
        for mask in localMasks {
            if let token = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] _ in
                self?.dismiss()
                return nil // swallow
            }) {
                eventMonitors.append(token)
            }
        }

        // A global monitor is added as a safety net in case a local monitor misses an event.
        if let token = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .keyDown, .flagsChanged],
            handler: { [weak self] _ in self?.dismiss() }
        ) {
            eventMonitors.append(token)
        }
    }

    private func removeEventMonitors() {
        for token in eventMonitors {
            NSEvent.removeMonitor(token)
        }
        eventMonitors.removeAll()
    }
}
