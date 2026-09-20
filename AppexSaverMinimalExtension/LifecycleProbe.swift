//
//  LifecycleProbe.swift
//  AppexSaverMinimalExtension
//
//  Instrumentation for issue #9: which signals tell the extension its view is
//  hidden or shown?
//
//  Every instance of the extension runs this, so the log carries events from
//  the resident instance, the System Settings preview instance and the saver
//  instance at once; they are told apart by pid. Events are logged at .notice
//  so `/usr/bin/log show` can recover them after the run, under
//
//      subsystem == "net.aerialscreensaver.AppexSaverMinimal" && category == "Lifecycle"
//
//  Line format, fixed so scripts/observe-lifecycle.sh can parse it:
//
//      probe t+<seconds> ev=<name> [key=value ...]
//
//  This file only observes. Nothing here changes what the saver does -- the
//  policy question of what to do with these signals is issue #10.
//

import AppKit
import ScreenSaver

private let logger = AppexLog.logger("Lifecycle")

enum LifecycleProbe {

    /// Process start, so every event carries a pid-local timeline. Two instances
    /// started at different times still line up via the log's own timestamps.
    private static let started = Date()

    /// Last census string per window-owner, so the periodic poll reports
    /// transitions rather than a wall of identical lines.
    private static var lastCensus: [ObjectIdentifier: String] = [:]
    private static var pollTimer: Timer?

    static func event(_ name: String, _ details: String = "") {
        let t = Date().timeIntervalSince(started)
        logger.notice("probe t+\(String(format: "%.3f", t), privacy: .public) ev=\(name, privacy: .public) \(details, privacy: .public)")
    }

    // MARK: - Window census

    /// Everything about the window that could plausibly distinguish a visible
    /// saver from a hidden one. `#9` reports which of these actually move.
    static func census(_ view: NSView?) -> String {
        guard let view else { return "view=nil" }
        let hidden = view.isHidden
        let hiddenAncestor = view.isHiddenOrHasHiddenAncestor
        guard let win = view.window else {
            return "win=nil viewHidden=\(hidden) viewHiddenAncestor=\(hiddenAncestor)"
        }
        let occ = win.occlusionState.contains(.visible) ? "visible" : "notVisible"
        let screen = win.screen.map { "\(Int($0.frame.width))x\(Int($0.frame.height))" } ?? "nil"
        return [
            "win=\(win.windowNumber)",
            "winClass=\(String(describing: type(of: win)))",
            "isVisible=\(win.isVisible)",
            "occlusion=\(occ)",
            "level=\(win.level.rawValue)",
            "alpha=\(String(format: "%.2f", win.alphaValue))",
            "onActiveSpace=\(win.isOnActiveSpace)",
            "isKey=\(win.isKeyWindow)",
            "isMain=\(win.isMainWindow)",
            "miniaturized=\(win.isMiniaturized)",
            "sharingType=\(win.sharingType.rawValue)",
            "screen=\(screen)",
            "winFrame=\(Int(win.frame.width))x\(Int(win.frame.height))",
            "viewHidden=\(hidden)",
            "viewHiddenAncestor=\(hiddenAncestor)",
            "appWindows=\(NSApp?.windows.count ?? -1)",
        ].joined(separator: " ")
    }

    /// Logs the census only when it differs from the last one for this view,
    /// plus a heartbeat every `heartbeat` polls so a steady state is still
    /// visible in the log.
    static func pollCensus(_ view: NSView?, tag: String) {
        guard let view else { return }
        let key = ObjectIdentifier(view)
        let now = census(view)
        if lastCensus[key] != now {
            lastCensus[key] = now
            event("census", "tag=\(tag) \(now)")
        }
    }

    /// Starts a 1 s census poll. A signal that never arrives as a callback may
    /// still show up here as a state that changed on its own.
    static func startPolling(_ view: NSView?, tag: String) {
        pollTimer?.invalidate()
        var ticks = 0
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak view] _ in
            ticks += 1
            if ticks % 15 == 0 {
                event("heartbeat", "tag=\(tag) \(census(view))")
                lastCensus[ObjectIdentifier(view ?? NSView())] = census(view)
            } else {
                pollCensus(view, tag: tag)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    static func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Notification observers

    /// Window- and workspace-level notifications that could stand in for a
    /// hidden/shown signal if the view callbacks turn out not to fire.
    static func observeNotifications() {
        let nc = NotificationCenter.default
        let windowNotes: [(Notification.Name, String)] = [
            (NSWindow.didChangeOcclusionStateNotification, "win.didChangeOcclusionState"),
            (NSWindow.willCloseNotification, "win.willClose"),
            (NSWindow.didMiniaturizeNotification, "win.didMiniaturize"),
            (NSWindow.didDeminiaturizeNotification, "win.didDeminiaturize"),
            (NSWindow.didBecomeKeyNotification, "win.didBecomeKey"),
            (NSWindow.didResignKeyNotification, "win.didResignKey"),
            (NSWindow.didChangeScreenNotification, "win.didChangeScreen"),
        ]
        for (name, label) in windowNotes {
            nc.addObserver(forName: name, object: nil, queue: .main) { note in
                let win = note.object as? NSWindow
                let occ = win?.occlusionState.contains(.visible) == true ? "visible" : "notVisible"
                event(label, "win=\(win?.windowNumber ?? -1) isVisible=\(win?.isVisible ?? false) occlusion=\(occ)")
            }
        }

        let appNotes: [(Notification.Name, String)] = [
            (NSApplication.didResignActiveNotification, "app.didResignActive"),
            (NSApplication.didBecomeActiveNotification, "app.didBecomeActive"),
            (NSApplication.didHideNotification, "app.didHide"),
            (NSApplication.didUnhideNotification, "app.didUnhide"),
            (NSApplication.willTerminateNotification, "app.willTerminate"),
        ]
        for (name, label) in appNotes {
            nc.addObserver(forName: name, object: nil, queue: .main) { _ in event(label) }
        }

        // Screen sleep and session switches are the other way a saver stops
        // being seen without its view hearing about it.
        let wsNotes: [(Notification.Name, String)] = [
            (NSWorkspace.screensDidSleepNotification, "ws.screensDidSleep"),
            (NSWorkspace.screensDidWakeNotification, "ws.screensDidWake"),
            (NSWorkspace.willSleepNotification, "ws.willSleep"),
            (NSWorkspace.didWakeNotification, "ws.didWake"),
            (NSWorkspace.sessionDidBecomeActiveNotification, "ws.sessionDidBecomeActive"),
            (NSWorkspace.sessionDidResignActiveNotification, "ws.sessionDidResignActive"),
        ]
        for (name, label) in wsNotes {
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: name, object: nil, queue: .main
            ) { _ in event(label) }
        }
    }

    // MARK: - Host-forwarded events

    /// Input arrives in bursts, so a line per event would swamp the log. The
    /// first of each type is logged as it happens -- that is the "does this
    /// arrive at all" answer -- and the rest are counted and flushed each second.
    private static var seenEventTypes: Set<UInt64> = []
    private static var eventCounts: [UInt64: Int] = [:]
    private static var eventFlushTimer: Timer?

    static func countEvent(type: UInt64) {
        if seenEventTypes.insert(type).inserted {
            event("hostEvent.first", "type=\(type) name=\(eventTypeName(type))")
        }
        eventCounts[type, default: 0] += 1
        if eventFlushTimer == nil {
            let timer = Timer(timeInterval: 1.0, repeats: true) { _ in flushEventCounts() }
            RunLoop.main.add(timer, forMode: .common)
            eventFlushTimer = timer
        }
    }

    private static func flushEventCounts() {
        guard !eventCounts.isEmpty else { return }
        let summary = eventCounts
            .sorted { $0.key < $1.key }
            .map { "\(eventTypeName($0.key))=\($0.value)" }
            .joined(separator: " ")
        eventCounts.removeAll()
        event("hostEvent.burst", summary)
    }

    private static func eventTypeName(_ raw: UInt64) -> String {
        guard let type = NSEvent.EventType(rawValue: UInt(raw)) else { return "raw\(raw)" }
        switch type {
        case .keyDown: return "keyDown"
        case .keyUp: return "keyUp"
        case .flagsChanged: return "flagsChanged"
        case .mouseMoved: return "mouseMoved"
        case .leftMouseDown: return "leftMouseDown"
        case .leftMouseUp: return "leftMouseUp"
        case .rightMouseDown: return "rightMouseDown"
        case .scrollWheel: return "scrollWheel"
        case .mouseEntered: return "mouseEntered"
        case .mouseExited: return "mouseExited"
        default: return "type\(raw)"
        }
    }

    // MARK: - Controller state

    /// The read-only ViewBridge state that explains which callbacks to expect.
    /// Sampled once the remote view is awake, because most of it is meaningless
    /// before then.
    static func describeController(_ vc: ScreenSaverViewController) {
        let size = vc.remoteViewSize()
        event("vcState", [
            "shouldBridgeAppearanceTransitions=\(vc._shouldBridgeAppearanceTransitions())",
            "isValid=\(vc.isValid())",
            "allowsSnapshot=\(vc.allowsSnapshot())",
            "canBecomeKey=\(vc.canBecomeKey())",
            "remoteViewSize=\(Int(size.width))x\(Int(size.height))",
            "hostSDKVersion=\(vc.hostSDKVersion())",
        ].joined(separator: " "))
    }

    // MARK: - Extension request channel

    /// The start/stop commands arrive here as NSExtensionItems rather than as
    /// -startAnimation on the view. Dumps enough of the item to identify the
    /// command without guessing at its shape.
    static func describeRequest(_ context: NSExtensionContext) {
        let items = context.inputItems.compactMap { $0 as? NSExtensionItem }
        event("ext.beginRequest", "items=\(items.count) raw=\(context.inputItems.count)")
        for (i, item) in items.enumerated() {
            var parts = ["i=\(i)"]
            if let type = item.userInfo?["command"] { parts.append("command=\(type)") }
            parts.append("attributedTitle=\(item.attributedTitle?.string ?? "nil")")
            parts.append("attachments=\(item.attachments?.count ?? 0)")
            let keys = (item.userInfo?.keys.map { "\($0)" } ?? []).sorted().joined(separator: ",")
            parts.append("userInfoKeys=[\(keys)]")
            for (k, v) in item.userInfo ?? [:] {
                parts.append("ui.\(k)=\(String(describing: v).prefix(120))")
            }
            event("ext.item", parts.joined(separator: " "))
        }
    }

    /// One-shot description of the process, so a pid in the log can be tied to
    /// the instance it came from.
    static func announceProcess() {
        let pi = ProcessInfo.processInfo
        event("process", [
            "pid=\(pi.processIdentifier)",
            "bundle=\(Bundle.main.bundleIdentifier ?? "?")",
            "host=\(pi.processName)",
            "args=\(pi.arguments.dropFirst().joined(separator: ","))",
            "needsAnimationTimer=\(Bundle.main.object(forInfoDictionaryKey: "SSENeedsAnimationTimer") as? Bool ?? false)",
        ].joined(separator: " "))
    }
}
