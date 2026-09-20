//
//  AppexSaverMinimalExtension.swift
//  AppexSaverMinimalExtension
//
//  Copyright © 2026 Guillaume Louel. Licensed under the MIT License.
//
//  Principal class for the screensaver extension. Specified as
//  NSExtensionPrincipalClass in Info.plist as
//  `$(PRODUCT_MODULE_NAME).AppexSaverMinimalExtension`.
//
//  Following Apple's own screensavers (e.g. Arabesque.appex) we keep this
//  minimal — only implement init() and let the framework drive lifecycle.
//

import Foundation
import ScreenSaver

private let logger = AppexLog.logger("Extension")

@objc(AppexSaverMinimalExtension)
class AppexSaverMinimalExtension: ScreenSaverExtension {

    @objc override init() {
        logger.info("AppexSaverMinimalExtension.init() PID=\(ProcessInfo.processInfo.processIdentifier, privacy: .public)")
        super.init()
        LifecycleProbe.announceProcess()
        LifecycleProbe.observeNotifications()
        LifecycleProbe.event("ext.init")
    }

    /// The extension point's only entry point. Per the note in
    /// ScreenSaverPrivate.h, WallpaperAgent sends start/stop here as extension
    /// items rather than as -startAnimation on the view -- issue #9 is partly
    /// the question of what those items actually contain.
    override func beginRequest(with context: NSExtensionContext) {
        LifecycleProbe.describeRequest(context)
        // The handshake carries isPreview, and this object does not outlive the
        // request -- HostHandshake parks it for loadView (issue #22).
        HostHandshake.record(context)
        super.beginRequest(with: context)
    }

    deinit {
        logger.info("AppexSaverMinimalExtension.deinit")
        LifecycleProbe.event("ext.deinit")
    }
}
