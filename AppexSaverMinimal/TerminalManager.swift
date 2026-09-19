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

    /// Size of the terminal view when the process was launched. tslime lays
    /// out for the character grid it starts with, so a material size change
    /// requires relaunching it.
    private var launchedSize: CGSize?
    private var pendingRestart: DispatchWorkItem?

    #if canImport(SwiftTerm)
    private var terminalView: LocalProcessTerminalView?
    #else
    private var placeholderLabel: NSTextField?
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
            term.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
            view.addSubview(term)
            terminalView = term
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
        launchedSize = terminalView?.frame.size
        launchProcess()
        #else
        // No-op; placeholder is shown.
        #endif
    }

    func stop() {
        isRunning = false
        pendingRestart?.cancel()
        pendingRestart = nil

        #if canImport(SwiftTerm)
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
        #if canImport(SwiftTerm)
        terminalView?.frame = bounds
        scheduleRestartIfNeeded(for: bounds.size)
        #else
        placeholderLabel?.frame = bounds
        #endif
    }

    #if canImport(SwiftTerm)
    private func launchProcess() {
        if let path = bundledTslimePath() {
            // Run the embedded binary directly
            terminalView?.startProcess(executable: path, args: ["--window-frame", "glow"])
        } else {
            // Fallback to PATH if developer hasn’t embedded yet
            terminalView?.startProcess(executable: "/usr/bin/env", args: ["tslime", "--window-frame glow"])
        }
        applyWindowSize()
        disableOutputPostProcessing()
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

    /// Relaunch tslime if the view has settled at a size meaningfully
    /// different from the one it was launched at. Debounced so a live window
    /// resize doesn't kill the process on every frame.
    private func scheduleRestartIfNeeded(for size: CGSize) {
        guard isRunning, let launched = launchedSize else { return }

        // Ignore changes smaller than roughly one character cell.
        let threshold: CGFloat = 20
        guard abs(size.width - launched.width) > threshold ||
              abs(size.height - launched.height) > threshold else { return }

        pendingRestart?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.restartProcess() }
        pendingRestart = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func restartProcess() {
        pendingRestart = nil
        guard isRunning, let term = terminalView else { return }
        term.terminate()
        launchedSize = term.frame.size
        launchProcess()
    }
    #endif
}

