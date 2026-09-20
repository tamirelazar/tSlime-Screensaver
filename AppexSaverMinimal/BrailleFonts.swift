//
//  BrailleFonts.swift
//  Shared between appex and host app
//
//  Turns a `BrailleSource` into the font the terminal view should draw with.
//
//  Two of the three sources name a bundled face. Neither is on any Mac, so
//  both ship in the extension's Resources and are registered into this
//  process before the first lookup. `.process` scope is the whole reason
//  this works from inside the appex sandbox: it needs no entitlement, asks
//  the user nothing, and leaves no trace outside the process — unlike
//  `.user`, which mutates the login session's font state for every app.
//
//  The faces ship *once*, in the extension. The host app needs them too, for
//  the settings preview, but it is unsandboxed and reads them straight out
//  of the `.appex` embedded in its own bundle. One copy means the preview
//  can never render a different font build than the saver does.
//

#if canImport(SwiftTerm)

import AppKit
import CoreText

/// The bundled faces, and where a process finds them.
enum BrailleFonts {

    /// A face this saver ships. `postScriptName` is what `NSFont(name:)`
    /// wants and is not derivable from the file name — the Nerd Fonts patch
    /// renames `JetBrainsMono` to `JetBrainsMonoNFM`.
    struct Face {
        let fileName: String
        let postScriptName: String
    }

    static let juliaMonoBold = Face(fileName: "JuliaMono-Bold.ttf",
                                    postScriptName: "JuliaMono-Bold")
    static let jetBrainsMonoNerdFontMono = Face(fileName: "JetBrainsMonoNerdFontMono-Regular.ttf",
                                                postScriptName: "JetBrainsMonoNFM-Regular")

    /// The face a source draws with, or nil for `.procedural` — which is not
    /// a font at all, and leaves the view on the system monospaced face.
    static func face(for source: BrailleSource) -> Face? {
        switch source {
        case .procedural: return nil
        case .juliaMonoBold: return juliaMonoBold
        case .jetBrainsMonoNerdFontMono: return jetBrainsMonoNerdFontMono
        }
    }

    /// The font to draw `source` with at `size`.
    ///
    /// Falls back to the system monospaced face — what `.procedural` uses —
    /// if the bundled one cannot be loaded, because a saver that draws the
    /// wrong braille is better than a saver that draws nothing. The fallback
    /// is logged at `.error`: it means the resource is missing from the
    /// bundle, which is a packaging bug rather than a user's choice.
    static func font(for source: BrailleSource, size: CGFloat) -> NSFont {
        let fallback = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        guard let face = face(for: source) else { return fallback }

        registerBundledFaces()

        guard let font = NSFont(name: face.postScriptName, size: size) else {
            logger.error("braille face \(face.postScriptName, privacy: .public) unavailable after registration; falling back to the system monospaced face")
            return fallback
        }
        return font
    }

    // MARK: - Registration

    /// Registers both faces into this process, once. Both, not just the one
    /// asked for: registration is a few milliseconds and happens off the
    /// render loop, while a per-face lazy registration would put a file read
    /// on the path of a live settings change.
    static func registerBundledFaces() {
        guard !didRegister else { return }
        didRegister = true

        guard let directory = resourcesDirectory() else {
            logger.error("no bundled fonts directory; searched own Resources and the embedded extension's")
            return
        }

        for face in [juliaMonoBold, jetBrainsMonoNerdFontMono] {
            let url = directory.appendingPathComponent(face.fileName)
            guard FileManager.default.fileExists(atPath: url.path) else {
                logger.error("bundled font missing: \(face.fileName, privacy: .public) in \(directory.path, privacy: .public)")
                continue
            }
            var error: Unmanaged<CFError>?
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                logger.notice("diag font registered \(face.postScriptName, privacy: .public)")
            } else {
                let description = error.map { String(describing: $0.takeRetainedValue()) } ?? "unknown error"
                logger.error("registering \(face.fileName, privacy: .public) failed: \(description, privacy: .public)")
            }
        }
    }

    /// The directory the faces live in, for whichever of the two bundles is
    /// asking.
    ///
    /// In the extension that is its own Resources. In the host app it is the
    /// embedded extension's — reading a font out of the *app's* Resources is
    /// exactly the case the appex sandbox denies (`deny file-read-data`), so
    /// there is deliberately no second copy to read.
    private static func resourcesDirectory() -> URL? {
        if let own = Bundle.main.resourceURL,
           FileManager.default.fileExists(atPath: own.appendingPathComponent(juliaMonoBold.fileName).path) {
            return own
        }
        return Bundle.main.builtInPlugInsURL?
            .appendingPathComponent("AppexSaverMinimalExtension.appex")
            .appendingPathComponent("Contents/Resources")
    }

    private static var didRegister = false

    private static let logger = AppexLog.logger("Fonts")
}

#endif
