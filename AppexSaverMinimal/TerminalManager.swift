//
//  TerminalManager.swift
//  Shared between appex and host app
//

import AppKit

#if canImport(SwiftTerm)
import SwiftTerm
#endif

private let logger = AppexLog.logger("Terminal")

/// Manages a full-screen terminal session that runs `tslime -l`.
/// Shared between the screensaver extension view and the host app preview.
final class TerminalManager {

    private weak var parentView: NSView?
    private var isRunning: Bool = false

    // MARK: Diagnostics (persisted at .notice so `log show` can recover them)
    private var startedAt: Date?
    private var firstFrameLogged = false
    private var lastMetalState: String = "n/a"
    private var lastPresentedCount: UInt64 = 0
    private var fpsTimer: Timer?
    private var metalStatusObserver: NSObjectProtocol?
    private var lastLoggedFrame: CGRect = .null

    #if canImport(SwiftTerm)
    private var terminalView: LocalProcessTerminalView?

    /// The saver settings, read once here and then watched. Constructing the
    /// manager is what "read at loadView" means for the extension: the view
    /// owns the manager, and the framework builds the view in `loadView`.
    ///
    /// The host app's tuning surface passes one store shared by every screen,
    /// so a staged value reaches all of them at once. Nothing here can tell a
    /// staged value from a saved one, which is the point — what the user
    /// tunes is drawn by this code path, not a parallel one.
    private let settings: SaverSettingsStore

    /// A frame rate this manager runs at instead of the saved one, for the
    /// life of the manager. `nil` — every case but one — means "follow the
    /// setting", which is what the saver and wallpaper instances do.
    ///
    /// The one case is the System Settings preview instance (#28, #29): the
    /// thumbnail is not the tuning surface, so it is capped at 30 fps
    /// whatever the user saved. It is expressed as a rate rather than an
    /// `isPreview` flag because `TerminalManager` is shared with the host app
    /// and has no business knowing which kind of instance owns it; the view
    /// that does know decides.
    ///
    /// It also silences the frame-rate callback entirely — see `attach(to:)`.
    private let frameRateOverride: FrameRate?
    #else
    private var placeholderLabel: NSTextField?
    #endif

    #if canImport(SwiftTerm)
    init(settings: SaverSettingsStore = SaverSettingsStore(),
         frameRateOverride: FrameRate? = nil) {
        self.settings = settings
        self.frameRateOverride = frameRateOverride
    }
    #endif

    private func bundledTslimePath() -> String? {
        // Works for both host app and .appex: both have a Contents/MacOS directory.
        let ResourcesDir = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
        let candidate = ResourcesDir.appendingPathComponent("tslime").path
        return FileManager.default.isExecutableFile(atPath: candidate) ? candidate : nil
    }

    func attach(to view: NSView) {
        parentView = view
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor

        #if canImport(SwiftTerm)
        if terminalView == nil {
            let term = LocalProcessTerminalView(frame: view.bounds)
            term.autoresizingMask = [.width, .height]
            term.frame = view.bounds
            // The `.procedural` font. `applyBrailleSettings` below replaces it
            // if the stored source names a face, before anything is drawn.
            term.font = NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .regular)
            view.addSubview(term)
            terminalView = term
            // tslime redraws large portions of the screen every frame, so
            // perFrameAggregated skips the per-row cache overhead entirely.
            // setUseMetal is safe here because attach() is only called while
            // the parent view already has a window (viewDidMoveToWindow guard).
            term.metalBufferingMode = .perFrameAggregated
            do {
                try term.setUseMetal(true)
                logger.notice("diag setUseMetal(true) ok; status=\(String(describing: term.metalRendererStatus.state), privacy: .public)")
            } catch {
                logger.error("diag setUseMetal(true) FAILED: \(String(describing: error), privacy: .public)")
            }
            installMetalStatusObserver(for: term)
            applyBrailleSettings(settings.braille)
            settings.onBrailleChange = { [weak self] updated in
                self?.applyBrailleSettings(updated)
            }
            // Separate callback because it is applied separately: the braille
            // values are an assignment, the frame rate is a relaunch.
            //
            // An overridden manager does not install it at all. The relaunch
            // would terminate the child and fork a new one to arrive at the
            // same --fps the old one already had: a frozen frame for ~290 ms
            // in exchange for nothing.
            if let override = frameRateOverride {
                logger.notice("diag frame rate pinned at fps=\(override.argument, privacy: .public); not watching the setting")
            } else {
                settings.onFrameRateChange = { [weak self] updated in
                    self?.relaunchProcess(at: updated)
                }
            }
            // Re-reads as it starts, so a change made while this manager had
            // no view is picked up rather than waiting for the next one.
            settings.startObserving()
        }
        #else
        if placeholderLabel == nil {
            let label = NSTextField(labelWithString: "Terminal unavailable.\nAdd the 'SwiftTerm' Swift Package to build a terminal, then this screensaver will run: tslime -l")
            label.textColor = .white
            label.alignment = .center
            label.font = .systemFont(ofSize: 16)
            label.lineBreakMode = .byWordWrapping
            label.frame = view.bounds
            label.autoresizingMask = [.width, .height]
            view.addSubview(label)
            placeholderLabel = label
        }
        #endif
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        #if canImport(SwiftTerm)
        if terminalView == nil, let view = parentView {
            attach(to: view)
        }
        startedAt = Date()
        firstFrameLogged = false
        logProcessContext()
        launchProcess()
        startFpsTimer()
        #else
        // No-op; placeholder is shown.
        #endif
    }

    func stop() {
        isRunning = false
        fpsTimer?.invalidate()
        fpsTimer = nil
        logger.notice("diag stop()")

        #if canImport(SwiftTerm)
        settings.stopObserving()
        settings.onBrailleChange = nil
        settings.onFrameRateChange = nil
        if let term = terminalView {
            term.terminate()
            term.removeFromSuperview()
            terminalView = nil
        }
        #else
        if let label = placeholderLabel {
            label.removeFromSuperview()
            placeholderLabel = nil
        }
        #endif
    }

    func updateFrame(_ bounds: CGRect) {
        if bounds != lastLoggedFrame {
            lastLoggedFrame = bounds
            logger.notice("diag updateFrame \(Int(bounds.width), privacy: .public)x\(Int(bounds.height), privacy: .public)")
        }
        #if canImport(SwiftTerm)
        // Resizing the view makes SwiftTerm resize the emulator grid and push
        // the new winsize to the pty; tslime handles the resulting SIGWINCH
        // and re-lays out live, so no relaunch is needed.
        terminalView?.frame = bounds
        #else
        placeholderLabel?.frame = bounds
        #endif
    }

    #if canImport(SwiftTerm)
    /// Pushes the settings into the live view. Always explicit values, never
    /// "leave it at the default": what the saver looks like is decided here,
    /// not by whichever fork revision happens to be pinned.
    ///
    /// The source picks both halves of the look together. `.procedural` draws
    /// the dot grid in the renderer and leaves the view on the system
    /// monospaced face; either font source turns the drawn grid off and hands
    /// the braille cell to a face that actually has one. They are set in that
    /// order on purpose — see `applyFont`.
    private func applyBrailleSettings(_ braille: BrailleSettings) {
        guard let term = terminalView else { return }
        term.customBrailleGlyphs = braille.source == .procedural
        term.brailleDotSizeFraction = braille.dotSizeFraction
        term.brailleCornerFraction = braille.cornerFraction
        applyFont(for: braille.source, to: term)
        logger.notice("diag braille applied source=\(braille.source.rawValue, privacy: .public) dot=\(String(format: "%.3f", braille.dotSizeFraction), privacy: .public) corner=\(String(format: "%.3f", braille.cornerFraction), privacy: .public)")
    }

    /// Sets the view's font for `source`, and tells tslime about the grid it
    /// just changed.
    ///
    /// The three sources do not share a cell: at 16 pt on a 2x display both
    /// bundled faces give a 9.50 pt cell against the system face's 10.00, and
    /// JetBrainsMono NFM a 21.50 pt line against 19.00. So a font change is a
    /// grid change. SwiftTerm's `font` setter already recomputes the cell,
    /// resizes the emulator and pushes the new winsize down the pty, which
    /// tslime handles as a SIGWINCH and re-lays out live — but only while the
    /// child is running, so a font set before `start()` needs no push and a
    /// font set after gets one for free.
    ///
    /// Guarded on the name because the setter is unconditional: assigning the
    /// same font still rebuilds the font set and drops every glyph cache. A
    /// settings change that moved only the dot size must not pay that.
    private func applyFont(for source: BrailleSource, to term: LocalProcessTerminalView) {
        let font = BrailleFonts.font(for: source, size: Self.fontSize)
        guard term.font.fontName != font.fontName else { return }

        let before = term.getTerminal()
        let (oldCols, oldRows) = (before.cols, before.rows)
        term.font = font
        let after = term.getTerminal()
        logger.notice("diag font -> \(font.fontName, privacy: .public) grid=\(oldCols, privacy: .public)x\(oldRows, privacy: .public) -> \(after.cols, privacy: .public)x\(after.rows, privacy: .public) running=\(term.process?.running ?? false, privacy: .public)")
    }

    /// The one font size this saver uses. Fixed by the destination, not a
    /// setting: the grid it produces is what every measurement in this map
    /// was taken against.
    private static let fontSize: CGFloat = 16

    private func launchProcess() {
        if let term = terminalView {
            let t = term.getTerminal()
            let w = Int(term.frame.width), h = Int(term.frame.height)
            logger.notice("diag launchProcess grid=\(t.cols, privacy: .public)x\(t.rows, privacy: .public) frame=\(w, privacy: .public)x\(h, privacy: .public)")
        }
        // The frame rate tslime is asked for -- a setting since #21, still
        // defaulting to the sixty decided in #24. It is a launch argument, so
        // this is the only place it can be applied, and changing it means
        // relaunching the child: see `relaunchProcess(at:)`.
        //
        // `source=` is on the line so the log alone says which instance got
        // which rate: with the settings pane open there are two of them at
        // once, and only one is overridden (#29).
        let fps = (frameRateOverride ?? settings.frameRate).argument
        let source = frameRateOverride == nil ? "settings" : "override"
        if let path = bundledTslimePath() {
            // Run the embedded binary directly
            terminalView?.startProcess(executable: path, args: ["--window-frame", "glow", "--fps", fps])
        } else {
            // Fallback to PATH if developer hasn’t embedded yet
            terminalView?.startProcess(executable: "/usr/bin/env", args: ["tslime", "--window-frame", "glow", "--fps", fps])
        }
        logger.notice("diag launchProcess fps=\(fps, privacy: .public) source=\(source, privacy: .public)")
        applyWindowSize()
        disableOutputPostProcessing()
    }

    /// Restarts tslime so it picks up a new `--fps`.
    ///
    /// The rate is a launch argument, so unlike every braille value it cannot
    /// be assigned into a running view. `terminate()` clears `running`, closes
    /// the pty and reaps the child; `startProcess` then forks a fresh one,
    /// while the view, the Metal renderer and the glyph caches all survive --
    /// only the child restarts.
    ///
    /// Nothing clears the terminal buffer, so the ~290 ms tslime takes to
    /// start (#10) shows the **last frame frozen**, not black. That is the
    /// whole cost of applying this live, and it is cheaper than a control that
    /// visibly does nothing until the next time the screensaver starts.
    private func relaunchProcess(at rate: FrameRate) {
        guard isRunning, terminalView != nil else { return }
        // `attach(to:)` never installs the callback that calls this when the
        // rate is overridden, so this is belt and braces -- but a relaunch
        // here would restart the child at the overridden rate anyway, making
        // the churn invisible in the log rather than absent.
        guard frameRateOverride == nil else {
            logger.notice("diag ignoring fps=\(rate.rawValue, privacy: .public); this manager is pinned")
            return
        }
        logger.notice("diag relaunching tslime at fps=\(rate.rawValue, privacy: .public)")
        terminalView?.terminate()
        launchProcess()
    }

    /// Turn off ONLCR on the pty.
    ///
    /// Normally ncurses puts the pty into raw mode (ONLCR off) so a bare LF is
    /// a pure line feed that leaves the cursor column unchanged. Inside the
    /// appex sandbox the pty stays in cooked mode with ONLCR on, so every LF
    /// the child writes is translated to CR+LF — the carriage return resets the
    /// cursor to column 0, and the next glyphs land at the left edge
    /// instead of their intended column (the "wraparound" artifact). Clearing
    /// ONLCR on the master descriptor makes the sandboxed pty behave like the
    /// non-sandboxed one.
    private func disableOutputPostProcessing() {
        guard let process = terminalView?.process, process.running else { return }
        let fd = process.childfd
        guard fd >= 0 else { return }
        var tio = termios()
        guard tcgetattr(fd, &tio) == 0 else {
            logger.error("tcgetattr failed on pty")
            return
        }
        tio.c_oflag &= ~tcflag_t(ONLCR)
        _ = tcsetattr(fd, TCSANOW, &tio)
    }

    /// The winsize SwiftTerm passes to forkpty does not reliably reach the
    /// PTY (observed as a 0×0 winsize on the tty, which makes ncurses apps
    /// fall back to an 80×24 grid drawn in the top-left corner). Set it
    /// explicitly on the master descriptor right after launching; the child
    /// has not called initscr yet at this point.
    private func applyWindowSize() {
        guard let term = terminalView, let process = term.process, process.running else { return }
        let t = term.getTerminal()
        var size = winsize(ws_row: UInt16(clamping: t.rows),
                           ws_col: UInt16(clamping: t.cols),
                           ws_xpixel: UInt16(clamping: Int(term.frame.width)),
                           ws_ypixel: UInt16(clamping: Int(term.frame.height)))
        _ = PseudoTerminalHelpers.setWinSize(masterPtyDescriptor: process.childfd, windowSize: &size)
    }

    // MARK: - Diagnostics

    /// Process identity and scheduling context. The appex is launched by the
    /// system, so QoS / Darwin role can differ from a normal app; the pid lets
    /// `launchctl procinfo <pid>` be correlated with these lines.
    private func logProcessContext() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let mainQoS = qos_class_main().rawValue
        let selfQoS = qos_class_self().rawValue
        let threadQoS = Thread.current.qualityOfService.rawValue
        let cores = ProcessInfo.processInfo.activeProcessorCount
        logger.notice("diag process pid=\(pid, privacy: .public) qos_main=\(mainQoS, privacy: .public) qos_self=\(selfQoS, privacy: .public) threadQoS=\(threadQoS, privacy: .public) isMain=\(Thread.isMainThread, privacy: .public) cores=\(cores, privacy: .public) bundle=\(Bundle.main.bundleIdentifier ?? "?", privacy: .public)")
    }

    private func installMetalStatusObserver(for term: LocalProcessTerminalView) {
        if let o = metalStatusObserver { NotificationCenter.default.removeObserver(o) }
        metalStatusObserver = NotificationCenter.default.addObserver(
            forName: .terminalViewMetalRendererStatusDidChange,
            object: nil,
            queue: nil
        ) { [weak self, weak term] _ in
            guard let self, let term else { return }
            let status = term.metalRendererStatus
            let state = String(describing: status.state)
            if state != self.lastMetalState {
                self.lastMetalState = state
                let sinceStart = self.startedAt.map { Date().timeIntervalSince($0) } ?? -1
                logger.notice("diag metal state -> \(state, privacy: .public) frames=\(status.presentedFrameCount, privacy: .public) t+\(String(format: "%.3f", sinceStart), privacy: .public)s")
            }
            if !self.firstFrameLogged, status.presentedFrameCount > 0 {
                self.firstFrameLogged = true
                let sinceStart = self.startedAt.map { Date().timeIntervalSince($0) } ?? -1
                logger.notice("diag first metal frame presented t+\(String(format: "%.3f", sinceStart), privacy: .public)s")
            }
        }
    }

    private func startFpsTimer() {
        fpsTimer?.invalidate()
        lastPresentedCount = terminalView?.metalRendererStatus.presentedFrameCount ?? 0
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let term = self.terminalView else { return }
            let status = term.metalRendererStatus
            let delta = status.presentedFrameCount &- self.lastPresentedCount
            self.lastPresentedCount = status.presentedFrameCount
            let win = term.window
            let visible = win?.isVisible ?? false
            let onScreen = win?.occlusionState.contains(.visible) ?? false
            let winNum = win?.windowNumber ?? -1
            logger.notice("diag fps presented=\(delta, privacy: .public) state=\(String(describing: status.state), privacy: .public) usingMetal=\(term.isUsingMetalRenderer, privacy: .public) frame=\(Int(term.frame.width), privacy: .public)x\(Int(term.frame.height), privacy: .public) win=\(winNum, privacy: .public) visible=\(visible, privacy: .public) onScreen=\(onScreen, privacy: .public)")
        }
        RunLoop.main.add(timer, forMode: .common)
        fpsTimer = timer
    }
    #endif
}

