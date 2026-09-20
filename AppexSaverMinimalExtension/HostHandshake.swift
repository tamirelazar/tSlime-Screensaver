//
//  HostHandshake.swift
//  AppexSaverMinimalExtension
//
//  What the host tells the extension about itself, for issue #22.
//
//  Today that is one fact: whether this instance is a System Settings preview
//  or a real saver. The host states it on the `handshake` extension item that
//  reaches -beginRequestWithExtensionContext: (issue #9 measured the item's
//  userInfo as command=handshake isPreview=0, at t+0.002 against loadView at
//  t+0.006).
//
//  It has to be parked process-wide because the principal class is built and
//  destroyed per request -- ext.init -> beginRequest -> ext.deinit -- and
//  holds no reference to the view controller that will ask for the value four
//  milliseconds later. A runtime dump of ScreenSaver.framework says there is
//  no other channel: ScreenSaverViewController declares nothing about
//  previews, and every isPreview accessor in the framework
//  (ScreenSaverExtensionManager, ScreenSaverModules,
//  ScreenSaverExtensionModule) belongs to the *host* side of the boundary.
//

import Foundation

private let logger = AppexLog.logger("Handshake")

enum HostHandshake {

    private static let lock = NSLock()
    private static var declared: Bool?
    /// What `isPreview(fallback:)` actually handed out, so a declaration that
    /// arrives afterwards can be reported as the stale read it causes.
    private static var handedOut: Bool?

    /// Records what this request declares. Called from
    /// -beginRequestWithExtensionContext:, which #9 timed ahead of `loadView`
    /// on every run -- but nothing in the extension point promises that order,
    /// so a late or disagreeing declaration is logged rather than assumed
    /// away.
    static func record(_ context: NSExtensionContext) {
        let raw = context.inputItems
            .compactMap { ($0 as? NSExtensionItem)?.userInfo?["isPreview"] }
            .first
        guard let raw else { return }
        guard let number = raw as? NSNumber else {
            logger.error("handshake carried isPreview as \(String(describing: type(of: raw)), privacy: .public), not a number; ignoring it")
            LifecycleProbe.event("handshake.unreadable", "raw=\(String(describing: raw).prefix(60))")
            return
        }
        let value = number.boolValue

        lock.lock()
        let previous = declared
        let used = handedOut
        declared = value
        lock.unlock()

        if let previous, previous != value {
            logger.error("host changed isPreview \(previous) -> \(value) within one process")
            LifecycleProbe.event("handshake.changed", "from=\(previous) to=\(value)")
        }
        if let used, used != value {
            logger.error("isPreview=\(value) declared after the view was built as isPreview=\(used); the view keeps the stale value")
            LifecycleProbe.event("handshake.late", "declared=\(value) used=\(used)")
        }
    }

    /// The value `loadView` should build the view with.
    ///
    /// `fallback` is only reached if no handshake landed first, which #9 never
    /// saw; it is logged at .error rather than passed over quietly, because
    /// the fallback cannot tell a preview from a saver and would silently call
    /// every instance a saver.
    static func isPreview(fallback: Bool) -> Bool {
        lock.lock()
        let declared = declared
        let value = declared ?? fallback
        handedOut = value
        lock.unlock()

        if declared != nil {
            LifecycleProbe.event("handshake.isPreview", "value=\(value) source=declared")
        } else {
            logger.error("no handshake reached this process before loadView; falling back to isPreview=\(fallback)")
            LifecycleProbe.event("handshake.isPreview", "value=\(value) source=fallback")
        }
        return value
    }
}
