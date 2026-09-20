//
//  SaverSettingsWriter.swift
//  Host app only — deliberately NOT a member of the extension target.
//
//  The one write path into the saver settings domain.
//
//  ADR 0002 rests on the extension being unable to write: it reads the host
//  app's domain under com.apple.security.temporary-exception.shared-preference
//  .read-only, and the kernel denies any attempt to write it. This file keeps
//  the other half of that arrangement honest by simply not existing in the
//  extension's copy of the world. That is why it is a separate file rather
//  than a `#if` inside SaverSettings.swift — target membership is checked by
//  the build system, a conditional is only as right as the build setting
//  behind it.
//
//  Writing is also the *only* thing this file does. Clamping, fallbacks and
//  the range rules all live on the read side, in SaverSettings.swift, where
//  they apply to every value the saver ever draws — including ones written
//  by an older build of this app, or by hand with `defaults write`.
//

#if canImport(SwiftTerm)

import Foundation

private let logger = AppexLog.logger("SettingsWriter")

/// Commits saver settings to the domain every extension instance reads.
enum SaverSettingsWriter {

    /// Writes every key of every group.
    ///
    /// All of them, every time, rather than only what changed: a partial
    /// write would leave the domain in a state no UI produced, and the whole
    /// value is four keys. The reads on the other side are idempotent, and a
    /// write that does not change a key does not notify its observers, so
    /// this costs nothing it does not have to.
    static func write(_ settings: SaverSettings) {
        guard isHostApp else {
            // Not a hypothetical: it is what this file is built to prevent.
            // The extension would be denied by the kernel, but a third
            // process writing this domain would succeed and be wrong.
            logger.error("refusing to write the saver settings domain from \(Bundle.main.bundleIdentifier ?? "?", privacy: .public); only the host app may write it")
            return
        }

        let defaults = SaverSettingsStore.makeDefaults()
        defaults.set(settings.braille.source.rawValue, forKey: BrailleSettings.Key.source)
        defaults.set(Double(settings.braille.dotSizeFraction), forKey: BrailleSettings.Key.dotSizeFraction)
        defaults.set(Double(settings.braille.cornerFraction), forKey: BrailleSettings.Key.cornerFraction)
        defaults.set(settings.frameRate.rawValue, forKey: FrameRate.key)

        logger.notice("diag settings written source=\(settings.braille.source.rawValue, privacy: .public) dot=\(String(format: "%.3f", settings.braille.dotSizeFraction), privacy: .public) corner=\(String(format: "%.3f", settings.braille.cornerFraction), privacy: .public) fps=\(settings.frameRate.rawValue, privacy: .public)")
    }

    /// Whether this process is the domain's owner. The host app's bundle
    /// identifier *is* the domain name, which is what makes this checkable
    /// rather than assumed.
    private static var isHostApp: Bool {
        Bundle.main.bundleIdentifier == SaverSettingsStore.domain
    }
}

#endif
