//
//  SaverSettings.swift
//  Shared between appex and host app
//
//  The saver settings: the values the saver reads to decide how it looks.
//  Braille is their only group today.
//
//  Where they live and why is ADR 0002. The short version, because the two
//  halves of this file only make sense together:
//
//  The values live in the host app's own defaults domain. The host app is
//  unsandboxed and is the only writer. Every extension instance reads that
//  domain under com.apple.security.temporary-exception.shared-preference
//  .read-only, and physically cannot write it — the kernel denies the
//  attempt — so the direction is a property of the system, not a convention
//  this file is asking anyone to keep. There is deliberately no write path
//  in this file.
//
//  This file must not be built into a sandboxed host app. cfprefsd routes a
//  domain into a container the moment that container holds a plist for it,
//  for every writer, and the app's writes would then land somewhere the
//  extension's reads never look. `hijackingContainerPlistURL` is the alarm
//  for that, and the host app surfaces it.
//

#if canImport(SwiftTerm)

import Foundation
import CoreGraphics
import SwiftTerm

// MARK: - Values

/// Which of three ways a braille cell is drawn. Not a font choice: one of
/// its values is not a font.
enum BrailleSource: String, CaseIterable {
    /// Drawn by the renderer as a 2x4 dot grid — the default, and the only
    /// source whose dots tile exactly across cells.
    case procedural
    case juliaMonoBold
    case jetBrainsMonoNerdFontMono
}

/// The braille group of the saver settings.
///
/// The defaults are the fork's own renderer constants rather than copies of
/// them, so "the look an unconfigured view draws" and "the look this saver
/// falls back to" are the same number in one place.
struct BrailleSettings: Equatable {
    var source: BrailleSource
    var dotSizeFraction: CGFloat
    var cornerFraction: CGFloat

    static let `default` = BrailleSettings(
        source: .procedural,
        dotSizeFraction: BrailleRenderer.defaultDotSizeFraction,
        cornerFraction: BrailleRenderer.defaultCornerFraction)

    /// Below half the dot pitch the lattice stops reading as a lattice; above
    /// the pitch adjacent dots merge into a block. Inset is not settable at
    /// all — any inset above zero bands the lattice, which is the one
    /// property procedural drawing exists to guarantee.
    static let dotSizeFractionRange: ClosedRange<CGFloat> = 0.50...1.00
    static let cornerFractionRange: ClosedRange<CGFloat> = 0.0...1.0

    /// Keys in the settings domain. No dots: a dotted key would be read as a
    /// key *path* by the KVO registration below and never observe anything.
    enum Key {
        static let source = "brailleSource"
        static let dotSizeFraction = "brailleDotSizeFraction"
        static let cornerFraction = "brailleCornerFraction"

        static let all = [source, dotSizeFraction, cornerFraction]
    }

    /// Reads the group out of `defaults`, clamping what is out of range and
    /// falling back to the default for what is missing, wrong-typed or
    /// unrecognised. Nothing is ever written back: a stored value the UI
    /// cannot produce is corrected on the way in, every time it is read,
    /// rather than repaired in place by a reader that is not allowed to write.
    init(reading defaults: UserDefaults) {
        let fallback = BrailleSettings.default

        if let raw = defaults.string(forKey: Key.source),
           let source = BrailleSource(rawValue: raw) {
            self.source = source
        } else {
            self.source = fallback.source
        }

        self.dotSizeFraction = BrailleSettings.fraction(
            defaults.object(forKey: Key.dotSizeFraction),
            in: BrailleSettings.dotSizeFractionRange,
            fallback: fallback.dotSizeFraction)
        self.cornerFraction = BrailleSettings.fraction(
            defaults.object(forKey: Key.cornerFraction),
            in: BrailleSettings.cornerFractionRange,
            fallback: fallback.cornerFraction)
    }

    init(source: BrailleSource, dotSizeFraction: CGFloat, cornerFraction: CGFloat) {
        self.source = source
        self.dotSizeFraction = dotSizeFraction
        self.cornerFraction = cornerFraction
    }

    /// A stored number clamped into range. Anything that is not a number at
    /// all — absent, a string, a date — is the fallback, not zero: a
    /// wrong-typed key must not read as the bottom of the range.
    private static func fraction(_ stored: Any?,
                                 in range: ClosedRange<CGFloat>,
                                 fallback: CGFloat) -> CGFloat {
        guard let number = stored as? NSNumber else { return fallback }
        let value = CGFloat(number.doubleValue)
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

// MARK: - Reading the domain

/// Reads the saver settings domain, and keeps reading it.
///
/// A change has to reach the instance the user is actually looking at, and
/// that instance is very often the resident one, which never calls
/// `loadView` again. So a read at load is not enough on its own: the store
/// also observes the domain across processes, which delivers a change in
/// tens of milliseconds.
final class SaverSettingsStore: NSObject {

    /// The host app's own bundle identifier, and therefore its defaults
    /// domain. The extension's bundle id is this plus `.Extension`; its own
    /// domain holds nothing.
    static let domain = "net.aerialscreensaver.AppexSaverMinimal"

    /// The plist whose mere existence reroutes the whole settings domain
    /// into a container — for every writer, sandboxed or not. Left behind by
    /// a sandboxed build of the host app, it makes the app write one file
    /// while the extension reads another, with no error on either side.
    static var hijackingContainerPlistURL: URL? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(domain)/Data/Library/Preferences/\(domain).plist")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private let defaults: UserDefaults
    private var observing = false

    /// The last values read. Reading this never touches the defaults system.
    private(set) var braille: BrailleSettings

    /// Called on the main thread whenever the domain changes the values.
    /// Not called for a write that leaves them equal.
    var onBrailleChange: ((BrailleSettings) -> Void)?

    override init() {
        // Addressing the domain by name from the host app itself is the one
        // case UserDefaults rejects, since it is already the standard domain
        // there.
        if Bundle.main.bundleIdentifier == SaverSettingsStore.domain {
            defaults = .standard
        } else if let suite = UserDefaults(suiteName: SaverSettingsStore.domain) {
            defaults = suite
        } else {
            // Only reachable if the domain name itself is bad. Falling back
            // to the process's own domain would read nothing and report no
            // error, so say so.
            defaults = .standard
            SaverSettingsStore.logger.error(
                "settings domain \(SaverSettingsStore.domain, privacy: .public) unavailable; reading own domain instead")
        }
        braille = BrailleSettings(reading: defaults)
        super.init()
        SaverSettingsStore.logger.notice(
            "diag settings read source=\(self.braille.source.rawValue, privacy: .public) dot=\(String(format: "%.3f", self.braille.dotSizeFraction), privacy: .public) corner=\(String(format: "%.3f", self.braille.cornerFraction), privacy: .public) domain=\(SaverSettingsStore.domain, privacy: .public)")
    }

    deinit {
        stopObserving()
    }

    /// Starts delivering changes. Safe to call more than once.
    func startObserving() {
        guard !observing else { return }
        observing = true
        for key in BrailleSettings.Key.all {
            defaults.addObserver(self, forKeyPath: key, options: [], context: nil)
        }
    }

    func stopObserving() {
        guard observing else { return }
        observing = false
        for key in BrailleSettings.Key.all {
            defaults.removeObserver(self, forKeyPath: key)
        }
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard let keyPath, BrailleSettings.Key.all.contains(keyPath) else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        // A cross-process notification arrives on an arbitrary thread, and
        // the values go straight into a view.
        if Thread.isMainThread {
            reread()
        } else {
            DispatchQueue.main.async { [weak self] in self?.reread() }
        }
    }

    private func reread() {
        let updated = BrailleSettings(reading: defaults)
        guard updated != braille else { return }
        braille = updated
        SaverSettingsStore.logger.notice(
            "diag settings changed source=\(updated.source.rawValue, privacy: .public) dot=\(String(format: "%.3f", updated.dotSizeFraction), privacy: .public) corner=\(String(format: "%.3f", updated.cornerFraction), privacy: .public)")
        onBrailleChange?(updated)
    }

    private static let logger = AppexLog.logger("Settings")
}

#endif
