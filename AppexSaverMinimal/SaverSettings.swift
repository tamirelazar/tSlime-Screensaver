//
//  SaverSettings.swift
//  Shared between appex and host app
//
//  The saver settings: the values the saver reads to decide how it looks and
//  what it costs. Two groups — the braille look, and the frame rate.
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
//  in this file; the host app's is in SaverSettingsWriter.swift, which is a
//  separate file for exactly that reason — the extension's copy of the world
//  does not contain it.
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

// MARK: - The braille group

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

// MARK: - The frame-rate group

/// The rate the saver asks tslime for, and therefore the rate it presents.
///
/// Two values, not a number. A rate above what the saver can present is
/// strictly wasteful — the parser is paid for every frame including the ones
/// that are dropped, which is why a 60 fps source behind the old 30 fps cap
/// cost 41–44% of a core to show the same 30 frames a 30 fps source showed
/// for 37.5% (#24). An open integer invites exactly that mistake.
///
/// This is not a look. It is a power control: 60 costs 67.1% of a core
/// against 30's 37.5%, continuously, for as long as the saver is up.
enum FrameRate: Int, CaseIterable {
    case thirty = 30
    case sixty = 60

    /// Sixty, decided in #24 — the fork's redraw is vsync-paced now, so the
    /// saver presents every frame it is given.
    static let `default` = FrameRate.sixty

    /// No dots, for the same reason the braille keys have none.
    static let key = "frameRate"

    /// Anything that is not one of the two values — missing, wrong-typed, or
    /// a number nobody should have stored — reads as the default.
    init(reading defaults: UserDefaults) {
        guard let number = defaults.object(forKey: FrameRate.key) as? NSNumber,
              let rate = FrameRate(rawValue: number.intValue) else {
            self = FrameRate.default
            return
        }
        self = rate
    }

    /// What tslime's `--fps` wants.
    var argument: String { String(rawValue) }
}

// MARK: - Both groups

/// Every saver setting, in its groups.
///
/// The groups are kept apart because they differ in *kind*, not just in
/// content: the braille values are applied to a live view by assignment,
/// while the frame rate is a launch argument and can only be applied by
/// restarting tslime. `SaverSettingsStore` reports them through separate
/// callbacks so that difference is structural rather than remembered — a
/// single callback would put "did only the dot size move?" into the consumer
/// as a hand-written diff, and getting that wrong means a slider drag
/// restarts a process.
struct SaverSettings: Equatable {
    var braille: BrailleSettings
    var frameRate: FrameRate

    static let `default` = SaverSettings(braille: .default, frameRate: .default)

    init(braille: BrailleSettings, frameRate: FrameRate) {
        self.braille = braille
        self.frameRate = frameRate
    }

    init(reading defaults: UserDefaults) {
        self.braille = BrailleSettings(reading: defaults)
        self.frameRate = FrameRate(reading: defaults)
    }

    /// Every key the store observes. A key that is not here is a setting that
    /// silently never reaches a running instance.
    static let observedKeys = BrailleSettings.Key.all + [FrameRate.key]
}

// MARK: - Reading the domain

/// Reads the saver settings domain, keeps reading it, and — in the host app
/// only — holds staged values on top of it.
///
/// A change has to reach the instance the user is actually looking at, and
/// that instance may never call `loadView` again. So a read at load is not
/// enough on its own: the store also observes the domain across processes,
/// which delivers a change in tens of milliseconds.
///
/// **Staging** is how the tuning surface shows an uncommitted value without
/// writing it anywhere. Staged values sit on top of what the domain says and
/// are reported through the very same callbacks a domain change would have
/// fired, so a consumer cannot tell staged from saved — which is the whole
/// point: what the user tunes is drawn by the same code path that draws what
/// ships, not a parallel one that has to be kept in step. Staging is still
/// not writing, so this stays inside the read-only half of ADR 0002; the
/// extension simply never stages anything.
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

    /// The defaults object the settings domain is reached through, for
    /// whichever process is asking. Shared with the writer so the two halves
    /// can never disagree about which domain they mean.
    ///
    /// Addressing the domain by name from the host app itself is the one case
    /// `UserDefaults` rejects, since it is already the standard domain there.
    static func makeDefaults() -> UserDefaults {
        if Bundle.main.bundleIdentifier == domain {
            return .standard
        }
        if let suite = UserDefaults(suiteName: domain) {
            return suite
        }
        // Only reachable if the domain name itself is bad. Falling back to
        // the process's own domain would read nothing and report no error,
        // so say so.
        logger.error("settings domain \(domain, privacy: .public) unavailable; using own domain instead")
        return .standard
    }

    private let defaults: UserDefaults
    private var observing = false

    /// What the domain says. Reading this never touches the defaults system.
    private(set) var saved: SaverSettings

    /// What the tuning surface is showing but has not committed, if anything.
    /// Collapsed back to nil the moment it agrees with `saved`, so `isDirty`
    /// cannot drift.
    private(set) var staged: SaverSettings?

    /// What a consumer should draw: staged if anything is staged, saved
    /// otherwise.
    var effective: SaverSettings { staged ?? saved }

    var braille: BrailleSettings { effective.braille }
    var frameRate: FrameRate { effective.frameRate }

    /// Whether there is anything for Accept to write or Discard to throw away.
    var isDirty: Bool { staged != nil }

    /// Called on the main thread whenever the effective values of that group
    /// change, from either source. Not called for a change that leaves the
    /// group equal.
    var onBrailleChange: ((BrailleSettings) -> Void)?
    var onFrameRateChange: ((FrameRate) -> Void)?

    override init() {
        defaults = SaverSettingsStore.makeDefaults()
        saved = SaverSettings(reading: defaults)
        super.init()
        SaverSettingsStore.logger.notice(
            "diag settings read source=\(self.saved.braille.source.rawValue, privacy: .public) dot=\(String(format: "%.3f", self.saved.braille.dotSizeFraction), privacy: .public) corner=\(String(format: "%.3f", self.saved.braille.cornerFraction), privacy: .public) fps=\(self.saved.frameRate.rawValue, privacy: .public) domain=\(SaverSettingsStore.domain, privacy: .public)")
    }

    deinit {
        stopObserving()
    }

    // MARK: Staging

    /// Shows `settings` without writing them anywhere.
    func stage(_ settings: SaverSettings) {
        let previous = effective
        staged = (settings == saved) ? nil : settings
        publish(changedFrom: previous)
    }

    /// Throws staged values away and goes back to what the domain says.
    func discardStaged() {
        guard staged != nil else { return }
        let previous = effective
        staged = nil
        SaverSettingsStore.logger.notice("diag settings staged values discarded")
        publish(changedFrom: previous)
    }

    /// Fires the per-group callbacks for whichever groups the effective
    /// values just moved in.
    private func publish(changedFrom previous: SaverSettings) {
        let now = effective
        if now.braille != previous.braille { onBrailleChange?(now.braille) }
        if now.frameRate != previous.frameRate { onFrameRateChange?(now.frameRate) }
    }

    // MARK: Observing

    /// Starts delivering changes. Safe to call more than once.
    func startObserving() {
        guard !observing else { return }
        observing = true
        for key in SaverSettings.observedKeys {
            defaults.addObserver(self, forKeyPath: key, options: [], context: nil)
        }
    }

    func stopObserving() {
        guard observing else { return }
        observing = false
        for key in SaverSettings.observedKeys {
            defaults.removeObserver(self, forKeyPath: key)
        }
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard let keyPath, SaverSettings.observedKeys.contains(keyPath) else {
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
        let updated = SaverSettings(reading: defaults)
        guard updated != saved else { return }
        let previous = effective
        saved = updated
        // The domain catching up with what was staged is how an Accept ends:
        // the staged values are dropped exactly when they stop being an
        // overlay, so the effective values never move and nothing is redrawn.
        if staged == saved { staged = nil }
        SaverSettingsStore.logger.notice(
            "diag settings changed source=\(updated.braille.source.rawValue, privacy: .public) dot=\(String(format: "%.3f", updated.braille.dotSizeFraction), privacy: .public) corner=\(String(format: "%.3f", updated.braille.cornerFraction), privacy: .public) fps=\(updated.frameRate.rawValue, privacy: .public)")
        publish(changedFrom: previous)
    }

    fileprivate static let logger = AppexLog.logger("Settings")
}

#endif
