// PROTOTYPE — throwaway. Answers: "How should the host app's main window look?"
//
// Four structurally different main windows for the host app, next to the one
// it has today, each drawn in four states of the stub behind it (fresh,
// installed, active, broken). Real SwiftUI controls rendered offscreen at 2x
// inside a mock macOS title bar, so each candidate can be judged as a window
// and not as a view in a vacuum.
//
// Headless:  ./run.sh <outdir> [--light]
//   Writes <candidate>--<state>.png (2x), one contact sheet per state with
//   every candidate side by side, and one per candidate with every state.
// Live:      ./run.sh --live
//   Opens a real window with a yellow switcher strip under it. ← → cycle the
//   candidate, ↑ ↓ cycle the state, R resets the state; the buttons drive a
//   stub, so Install / Enable / Uninstall move the window through its states.

import AppKit
import CoreText
import SwiftUI

// MARK: - Stub state

enum Stage: CaseIterable {
    case notInstalled, installed, active
}

struct AppState {
    var stage: Stage
    var embeddedVersion = "1.0"
    var installedVersion: String?
    var installedPath: String?
    var installError: String?
    var activationError: String?
    var hijackedPlist: String?
    var statusMessage = "Ready"

    var isInstalled: Bool { stage != .notInstalled }
    var isActive: Bool { stage == .active }
}

let derivedPath = "/Users/tamir/Library/Developer/Xcode/DerivedData/AppexSaverMinimal-dqzsfxlkrjbmefhcqavztaqbtaqz/Build/Products/Debug/AppexSaverMinimal.app/Contents/PlugIns/AppexSaverMinimalExtension.appex"
let containerPlist = "/Users/tamir/Library/Containers/net.aerialscreensaver.AppexSaverMinimal/Data/Library/Preferences/net.aerialscreensaver.AppexSaverMinimal.plist"

struct Scenario {
    let key: String
    let title: String
    let state: AppState
    /// Whether a candidate that folds its details away starts unfolded.
    let detailsOpen: Bool
}

let scenarios: [Scenario] = [
    Scenario(key: "1-fresh", title: "fresh: not installed",
             state: AppState(stage: .notInstalled), detailsOpen: false),
    Scenario(key: "2-installed", title: "installed, not active",
             state: AppState(stage: .installed, installedVersion: "1.0", installedPath: derivedPath,
                             statusMessage: "Extension installed successfully"), detailsOpen: false),
    Scenario(key: "3-active", title: "active: the steady state",
             state: AppState(stage: .active, installedVersion: "1.0", installedPath: derivedPath), detailsOpen: false),
    Scenario(key: "4-broken", title: "broken: activation failed, settings domain hijacked",
             state: AppState(stage: .installed, installedVersion: "1.0", installedPath: derivedPath,
                             activationError: "PaperSaver: could not write the screen-saver configuration for display 2",
                             hijackedPlist: containerPlist,
                             statusMessage: "Ready"), detailsOpen: true),
]

/// The stand-in for PluginManager. Every action flips the state after a
/// short pause so the live window shows the in-between too.
final class Stub: ObservableObject {
    @Published var state: AppState
    @Published var busy = false

    init(_ state: AppState) { self.state = state }

    private func later(_ work: @escaping () -> Void) {
        busy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.busy = false
            work()
        }
    }

    func install() {
        state.statusMessage = "Installing extension..."
        later {
            self.state.stage = .installed
            self.state.installedVersion = self.state.embeddedVersion
            self.state.installedPath = derivedPath
            self.state.installError = nil
            self.state.statusMessage = "Extension installed successfully"
        }
    }

    func uninstall() {
        state.statusMessage = "Uninstalling extension..."
        later {
            self.state.stage = .notInstalled
            self.state.installedVersion = nil
            self.state.installedPath = nil
            self.state.activationError = nil
            self.state.statusMessage = "Extension uninstalled successfully"
        }
    }

    func enable() {
        later {
            self.state.stage = .active
            self.state.activationError = nil
            self.state.statusMessage = "Ready"
        }
    }

    func refresh() { later {} }
    func tune() { state.statusMessage = "(would open the tuning surface)" }
    func openSystemSettings() { state.statusMessage = "(would open System Settings → Screen Saver)" }
}

// MARK: - Frame data and the saver's render (as prototype/panel-look), for the preview

struct Cell { var scalar: Unicode.Scalar; var fg: NSColor? }
let defaultFG = NSColor(calibratedRed: 0.85, green: 0.85, blue: 0.85, alpha: 1)

func parseFrame(_ text: String) -> [[Cell]] {
    var rows: [[Cell]] = []
    for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
        var cells: [Cell] = []
        var fg: NSColor? = nil
        let it = Array(line.unicodeScalars)
        var i = 0
        while i < it.count {
            let s = it[i]
            if s == "\u{1b}", i + 1 < it.count, it[i + 1] == "[" {
                var j = i + 2
                var params = ""
                while j < it.count, it[j] != "m", it[j] != "\u{1b}" { params.unicodeScalars.append(it[j]); j += 1 }
                if j < it.count, it[j] == "m" {
                    let p = params.split(separator: ";").map { Int($0) ?? 0 }
                    if p.isEmpty || p == [0] || p == [39] { fg = nil }
                    else if p.count >= 5, p[0] == 38, p[1] == 2 {
                        fg = NSColor(calibratedRed: CGFloat(p[2]) / 255, green: CGFloat(p[3]) / 255,
                                     blue: CGFloat(p[4]) / 255, alpha: 1)
                    }
                    i = j + 1
                    continue
                }
            }
            cells.append(Cell(scalar: s, fg: fg))
            i += 1
        }
        rows.append(cells)
    }
    while let last = rows.last, last.allSatisfy({ $0.scalar == " " }) { rows.removeLast() }
    return rows
}

struct BlockRect { let x0, x1, y0, y1: CGFloat; let alpha: CGFloat }
func blockRects(for cp: UInt32) -> [BlockRect]? {
    func upper(_ n: CGFloat) -> [BlockRect] { [BlockRect(x0: 0, x1: 8, y0: 0, y1: n, alpha: 1)] }
    func lower(_ n: CGFloat) -> [BlockRect] { [BlockRect(x0: 0, x1: 8, y0: 8 - n, y1: 8, alpha: 1)] }
    func left(_ n: CGFloat) -> [BlockRect] { [BlockRect(x0: 0, x1: n, y0: 0, y1: 8, alpha: 1)] }
    func right(_ n: CGFloat) -> [BlockRect] { [BlockRect(x0: 8 - n, x1: 8, y0: 0, y1: 8, alpha: 1)] }
    let ul = BlockRect(x0: 0, x1: 4, y0: 0, y1: 4, alpha: 1), ur = BlockRect(x0: 4, x1: 8, y0: 0, y1: 4, alpha: 1)
    let ll = BlockRect(x0: 0, x1: 4, y0: 4, y1: 8, alpha: 1), lr = BlockRect(x0: 4, x1: 8, y0: 4, y1: 8, alpha: 1)
    switch cp {
    case 0x2580: return upper(4)
    case 0x2581...0x2587: return lower(CGFloat(cp - 0x2580))
    case 0x2588: return [BlockRect(x0: 0, x1: 8, y0: 0, y1: 8, alpha: 1)]
    case 0x2589...0x258F: return left(CGFloat(8 - (cp - 0x2588)))
    case 0x2590: return right(4)
    case 0x2591: return [BlockRect(x0: 0, x1: 8, y0: 0, y1: 8, alpha: 0.25)]
    case 0x2592: return [BlockRect(x0: 0, x1: 8, y0: 0, y1: 8, alpha: 0.5)]
    case 0x2593: return [BlockRect(x0: 0, x1: 8, y0: 0, y1: 8, alpha: 0.75)]
    case 0x2594: return upper(1)
    case 0x2595: return right(1)
    case 0x2596: return [ll]
    case 0x2597: return [lr]
    case 0x2598: return [ul]
    case 0x2599: return [ul, ll, lr]
    case 0x259A: return [ul, lr]
    case 0x259B: return [ul, ur, ll]
    case 0x259C: return [ul, ur, lr]
    case 0x259D: return [ur]
    case 0x259E: return [ur, ll]
    case 0x259F: return [ur, ll, lr]
    default: return nil
    }
}

struct Metrics { let width, height, ascent: CGFloat }
func metrics(for font: CTFont, scale: CGFloat) -> Metrics {
    let asc = CTFontGetAscent(font), desc = CTFontGetDescent(font), lead = CTFontGetLeading(font)
    let h = ceil((asc + desc + lead) * scale) / scale
    var glyph = CTFontGetGlyphWithName(font, "W" as CFString)
    var adv = CGSize.zero
    CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &adv, 1)
    return Metrics(width: (adv.width * scale).rounded() / scale, height: h, ascent: asc)
}

func drawBrailleDots(_ cp: UInt32, in cell: CGRect, ctx: CGContext) {
    let bits = cp - 0x2800
    let pitchX = cell.width / 2, pitchY = cell.height / 4
    let d = min(pitchX, pitchY) * 0.78
    let layout: [(Int, Int)] = [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (0, 3), (1, 3)]
    for bit in 0..<8 where bits & (1 << UInt32(bit)) != 0 {
        let (c, r) = layout[bit]
        let cx = cell.minX + (CGFloat(c) + 0.5) * pitchX
        let cy = cell.minY + (CGFloat(3 - r) + 0.5) * pitchY
        let rect = CGRect(x: cx - d / 2, y: cy - d / 2, width: d, height: d)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: d * 0.3, cornerHeight: d * 0.3, transform: nil))
        ctx.fillPath()
    }
}

func renderBackdrop(grid: [[Cell]], canvas: CGSize, scale: CGFloat) -> CGImage {
    let font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular) as CTFont
    let m = metrics(for: font, scale: scale)
    let ctx = CGContext(data: nil, width: Int(canvas.width * scale), height: Int(canvas.height * scale),
                        bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fill(CGRect(origin: .zero, size: canvas))
    ctx.setShouldAntialias(true); ctx.setShouldSmoothFonts(true)
    for (r, line) in grid.enumerated() {
        let cellTop = canvas.height - CGFloat(r + 1) * m.height
        let baseline = cellTop + m.height - m.ascent
        for (c, cell) in line.enumerated() where cell.scalar != " " {
            let cp = cell.scalar.value
            let color = cell.fg ?? defaultFG
            let rect = CGRect(x: CGFloat(c) * m.width, y: cellTop, width: m.width, height: m.height)
            if let rects = blockRects(for: cp) {
                let xe = m.width / 8, ye = m.height / 8
                for br in rects {
                    ctx.setFillColor(color.withAlphaComponent(br.alpha).cgColor)
                    ctx.fill(CGRect(x: rect.minX + br.x0 * xe, y: rect.minY + m.height - br.y1 * ye,
                                    width: (br.x1 - br.x0) * xe, height: (br.y1 - br.y0) * ye))
                }
            } else if (0x2800...0x28FF).contains(cp) {
                ctx.setFillColor(color.cgColor)
                drawBrailleDots(cp, in: rect, ctx: ctx)
            } else {
                let attr = NSAttributedString(string: String(Character(cell.scalar)),
                                              attributes: [.font: font, .foregroundColor: color])
                ctx.textPosition = CGPoint(x: rect.minX, y: baseline)
                CTLineDraw(CTLineCreateWithAttributedString(attr), ctx)
            }
        }
    }
    return ctx.makeImage()!
}

/// One captured frame, rendered the way the saver renders it, for the
/// candidate that shows the saver in the window.
let previewImage: NSImage = {
    let here = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
    let root = FileManager.default.fileExists(atPath: here.appendingPathComponent("frames").path)
        ? here : here.deletingLastPathComponent()
    let url = root.appendingPathComponent("frames/03-dense.txt")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
        FileHandle.standardError.write("no frame at \(url.path)\n".data(using: .utf8)!)
        exit(1)
    }
    let cg = renderBackdrop(grid: parseFrame(text), canvas: CGSize(width: 1920, height: 1080), scale: 1)
    return NSImage(cgImage: cg, size: NSSize(width: 1920, height: 1080))
}()

// MARK: - Shared pieces — deliberately few

/// There is no app icon yet; this stands in for one so the candidates that
/// lead with an icon can be judged at all.
struct AppIcon: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.16), Color.black], startPoint: .top, endPoint: .bottom))
            Text("⣿⡇")
                .font(.system(size: size * 0.5))
                .foregroundStyle(Color(red: 0.45, green: 0.95, blue: 0.55))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
}

struct StatusDot: View {
    let on: Bool
    var body: some View {
        Circle().fill(on ? Color.green : Color.gray).frame(width: 9, height: 9)
    }
}

/// The alarm the current window shows for a hijacked settings domain; the
/// wording is the real one, so every candidate carries the same text.
struct HijackBanner: View {
    let plist: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Saver settings will not apply").fontWeight(.medium)
                Text("A container holds a preferences file for this app's settings domain, so this app writes there while the screensaver reads ~/Library/Preferences. Delete it and relaunch.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(plist).font(.caption.monospaced()).lineLimit(2).truncationMode(.middle)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.orange.opacity(0.35)))
    }
}

func stageSentence(_ s: AppState) -> String {
    switch s.stage {
    case .notInstalled: return "Not registered with macOS"
    case .installed: return "Registered, not your screensaver"
    case .active: return "Your screensaver on every display"
    }
}

// MARK: - 00 current: the window as it is today, ported verbatim onto the stub

struct CurrentWindow: View {
    @ObservedObject var stub: Stub
    var s: AppState { stub.state }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tv").font(.system(size: 60)).foregroundColor(.accentColor)
            Text("AppexSaverMinimal").font(.largeTitle).fontWeight(.bold)
            Text("Screensaver Extension").font(.title2).foregroundColor(.secondary)
            Divider().padding(.horizontal, 40)
            Text("Extension Status").font(.headline)
            extensionStatus.padding(.horizontal, 20)
            Divider().padding(.horizontal, 40)
            Text("Screensaver Activation").font(.headline)
            activation.padding(.horizontal, 20)
            Divider().padding(.horizontal, 40)
            HStack(spacing: 12) {
                Button("Saver Settings…") { stub.tune() }.buttonStyle(.borderedProminent)
                Button("Open Screen Saver Settings") { stub.openSystemSettings() }.buttonStyle(.bordered)
            }
            if let plist = s.hijackedPlist {
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                            Text("Saver settings will not apply").fontWeight(.medium)
                        }
                        Text("A container holds a preferences file for this app's settings domain, so this app writes there while the screensaver reads ~/Library/Preferences. Delete it and relaunch.")
                            .font(.caption).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(plist).font(.caption.monospaced()).lineLimit(3).truncationMode(.middle)
                    }
                    .padding(8)
                }
                .padding(.horizontal, 20)
            }
            Text(s.statusMessage).font(.caption).foregroundColor(.secondary)
                .padding(.top, 10).frame(maxWidth: .infinity).multilineTextAlignment(.center)
        }
        .padding(40)
        .fixedSize()
    }

    private var extensionStatus: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle().fill(s.isInstalled ? Color.green : Color.gray).frame(width: 10, height: 10)
                    if s.isInstalled {
                        Text("Installed").fontWeight(.medium)
                        if let v = s.installedVersion { Text("(v\(v))").foregroundColor(.secondary) }
                    } else {
                        Text("Not Installed").fontWeight(.medium).foregroundColor(.secondary)
                    }
                    Spacer()
                    if stub.busy { ProgressView().scaleEffect(0.7) }
                    else { Button { stub.refresh() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.borderless) }
                }
                if s.isInstalled {
                    if let path = s.installedPath {
                        HStack(alignment: .top) {
                            Text("Path:").foregroundColor(.secondary)
                            Text(path).lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                        }
                        .font(.caption)
                    }
                } else {
                    Text("Embedded version: \(s.embeddedVersion)").font(.caption).foregroundColor(.secondary)
                }
                if let e = s.installError { Text(e).font(.caption).foregroundColor(.red) }
                HStack {
                    Spacer()
                    if s.isInstalled {
                        Button("Uninstall") { stub.uninstall() }.buttonStyle(.bordered).disabled(stub.busy)
                    } else {
                        Button("Install") { stub.install() }.buttonStyle(.borderedProminent).disabled(stub.busy)
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(8)
        }
    }

    private var activation: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle().fill(s.isActive ? Color.green : Color.gray).frame(width: 10, height: 10)
                    if s.isActive { Text("Active").fontWeight(.medium) }
                    else { Text("Not Active").fontWeight(.medium).foregroundColor(.secondary) }
                    Spacer()
                    if stub.busy { ProgressView().scaleEffect(0.7) }
                    else { Button { stub.refresh() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.borderless) }
                }
                if let e = s.activationError { Text(e).font(.caption).foregroundColor(.red) }
                if s.isInstalled && !s.isActive {
                    HStack {
                        Spacer()
                        Button("Enable as Screensaver") { stub.enable() }.buttonStyle(.borderedProminent).disabled(stub.busy)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .padding(8)
        }
    }
}

// MARK: - A steps: the three things to do, in order, each with its one button

struct StepRow<Trailing: View>: View {
    let number: Int
    let done: Bool
    let isNext: Bool
    let title: String
    let caption: String
    var error: String? = nil
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(done ? Color.green : (isNext ? Color.accentColor : Color.secondary.opacity(0.22)))
                    .frame(width: 26, height: 26)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isNext ? Color.white : Color.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.medium))
                Text(caption).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let error { Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 12)
            trailing().padding(.top, 2)
        }
    }
}

struct StepsWindow: View {
    @ObservedObject var stub: Stub
    var s: AppState { stub.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                AppIcon(size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("tSlime").font(.title2.weight(.semibold))
                    Text(stageSentence(s)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 18)

            if let plist = s.hijackedPlist { HijackBanner(plist: plist).padding(.bottom, 16) }

            StepRow(number: 1, done: s.isInstalled, isNext: !s.isInstalled,
                    title: "Register the extension",
                    caption: s.isInstalled
                        ? "Version \(s.installedVersion ?? "?"), registered with pluginkit."
                        : "macOS usually finds a fresh build by itself. This nudges pluginkit when it hasn't.",
                    error: s.installError) {
                if s.isInstalled {
                    Button("Uninstall") { stub.uninstall() }.controlSize(.small).disabled(stub.busy)
                } else {
                    Button("Install") { stub.install() }.buttonStyle(.borderedProminent).disabled(stub.busy)
                }
            }
            Divider().padding(.vertical, 12).padding(.leading, 40)
            StepRow(number: 2, done: s.isActive, isNext: s.isInstalled && !s.isActive,
                    title: "Make it your screensaver",
                    caption: s.isActive ? "Active on every display." : "Sets tSlime as the screensaver on every display.",
                    error: s.activationError) {
                if s.isActive {
                    Button { stub.refresh() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.borderless).help("Refresh status")
                } else if s.isInstalled {
                    Button("Enable") { stub.enable() }.buttonStyle(.borderedProminent).disabled(stub.busy)
                } else {
                    Button("Enable") {}.disabled(true)
                }
            }
            Divider().padding(.vertical, 12).padding(.leading, 40)
            StepRow(number: 3, done: false, isNext: s.isActive,
                    title: "Tune the look",
                    caption: "Braille, dot size and frame rate, over a live full-screen render.") {
                if s.isActive {
                    Button("Tune…") { stub.tune() }.buttonStyle(.borderedProminent)
                } else {
                    Button("Tune…") { stub.tune() }
                }
            }
            Divider().padding(.top, 14).padding(.bottom, 10)
            HStack {
                Button("System Settings → Screen Saver") { stub.openSystemSettings() }
                    .buttonStyle(.link).font(.caption)
                Spacer()
                Text(s.statusMessage).font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(24)
        .frame(width: 470)
    }
}

// MARK: - B preview first: the saver itself leads, status is a strip under it

struct Chip: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            StatusDot(on: true)
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(Color.primary.opacity(0.08)))
    }
}

struct PreviewFirstWindow: View {
    @ObservedObject var stub: Stub
    var s: AppState { stub.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(nsImage: previewImage)
                .resizable()
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(width: 600)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("tSlime").font(.title2.weight(.semibold))
                    Text(stageSentence(s)).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Tune the Look…") { stub.tune() }.buttonStyle(.borderedProminent).controlSize(.large)
            }
            .padding(.top, 14)

            if let plist = s.hijackedPlist { HijackBanner(plist: plist).padding(.top, 12) }
            if let e = s.activationError ?? s.installError {
                Text(e).font(.caption).foregroundStyle(.red).padding(.top, 8)
            }

            Divider().padding(.vertical, 12)

            HStack(spacing: 8) {
                if s.isInstalled {
                    Chip(text: "Installed \(s.installedVersion ?? "")")
                } else {
                    Button("Install Extension") { stub.install() }
                        .buttonStyle(.borderedProminent).controlSize(.small).disabled(stub.busy)
                }
                if s.isActive {
                    Chip(text: "Your screensaver")
                } else if s.isInstalled {
                    Button("Set as Screensaver") { stub.enable() }
                        .buttonStyle(.borderedProminent).controlSize(.small).disabled(stub.busy)
                } else {
                    Button("Set as Screensaver") {}.controlSize(.small).disabled(true)
                }
                Spacer()
                Text(s.statusMessage).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                Menu {
                    Button("Refresh Status") { stub.refresh() }
                    if s.isInstalled { Button("Uninstall Extension") { stub.uninstall() } }
                    Divider()
                    Button("Open System Settings → Screen Saver") { stub.openSystemSettings() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            }
        }
        .padding(20)
        .frame(width: 640)
    }
}

// MARK: - C one sentence, one button: what is true now and the one thing to do about it

struct OneButtonWindow: View {
    @ObservedObject var stub: Stub
    @State private var detailsOpen: Bool
    var s: AppState { stub.state }

    init(stub: Stub, detailsOpen: Bool) {
        self.stub = stub
        _detailsOpen = State(initialValue: detailsOpen)
    }

    private var headline: String {
        switch s.stage {
        case .notInstalled: return "tSlime isn't registered with macOS yet."
        case .installed: return "tSlime is registered, but isn't your screensaver."
        case .active: return "tSlime is your screensaver."
        }
    }
    private var subline: String {
        switch s.stage {
        case .notInstalled: return "Register the extension so System Settings can offer it. A fresh build is usually picked up on its own."
        case .installed: return "Version \(s.installedVersion ?? "?"). Make it the screensaver on every display."
        case .active: return "Version \(s.installedVersion ?? "?"), on every display. Tune the braille, dot size and frame rate over a live render."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let plist = s.hijackedPlist { HijackBanner(plist: plist).padding(.bottom, 16) }
            HStack(alignment: .top, spacing: 16) {
                AppIcon(size: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text(headline).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    Text(subline).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if let e = s.activationError ?? s.installError {
                        Text(e).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 10) {
                        switch s.stage {
                        case .notInstalled:
                            Button("Install") { stub.install() }.buttonStyle(.borderedProminent).controlSize(.large).disabled(stub.busy)
                        case .installed:
                            Button("Set as Screensaver") { stub.enable() }.buttonStyle(.borderedProminent).controlSize(.large).disabled(stub.busy)
                        case .active:
                            Button("Tune the Look…") { stub.tune() }.buttonStyle(.borderedProminent).controlSize(.large)
                        }
                        if stub.busy { ProgressView().controlSize(.small) }
                    }
                    .padding(.top, 8)
                }
            }
            DisclosureGroup(isExpanded: $detailsOpen) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
                    GridRow {
                        Text("Extension").foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                        Text(s.isInstalled ? "Registered, version \(s.installedVersion ?? "?")" : "Not registered · embedded \(s.embeddedVersion)")
                    }
                    if let path = s.installedPath {
                        GridRow {
                            Text("Path").foregroundStyle(.secondary)
                            Text(path).font(.caption.monospaced()).lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                        }
                    }
                    GridRow {
                        Text("Screensaver").foregroundStyle(.secondary)
                        Text(s.isActive ? "Active on every display" : "Not active")
                    }
                    GridRow {
                        Text("")
                        HStack(spacing: 8) {
                            if s.isInstalled { Button("Uninstall") { stub.uninstall() } }
                            else { Button("Install") { stub.install() } }
                            Button("Refresh") { stub.refresh() }
                            Button("System Settings…") { stub.openSystemSettings() }
                        }
                        .controlSize(.small)
                    }
                }
                .font(.callout)
                .padding(.top, 10)
                .padding(.leading, 4)
            } label: {
                Text("Details").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            Text(s.statusMessage).font(.caption).foregroundStyle(.tertiary).padding(.top, 10)
        }
        .padding(24)
        .frame(width: 500)
    }
}

// MARK: - D grouped form: System Settings' own idiom, a section per concern

struct GroupedFormWindow: View {
    @ObservedObject var stub: Stub
    let height: CGFloat
    var s: AppState { stub.state }

    var body: some View {
        Form {
            Section {
                LabeledContent("Extension") {
                    HStack(spacing: 6) {
                        StatusDot(on: s.isInstalled)
                        Text(s.isInstalled ? "Registered" : "Not registered")
                    }
                }
                LabeledContent("Version") {
                    Text(s.isInstalled ? (s.installedVersion ?? "?") : "\(s.embeddedVersion) embedded, not registered")
                }
                if let path = s.installedPath {
                    LabeledContent("Path") {
                        Text(path).font(.caption.monospaced()).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                    }
                }
                if let e = s.installError { Text(e).font(.caption).foregroundStyle(.red) }
                HStack {
                    Spacer()
                    Button("Refresh") { stub.refresh() }
                    if s.isInstalled { Button("Uninstall") { stub.uninstall() }.disabled(stub.busy) }
                    else { Button("Install") { stub.install() }.buttonStyle(.borderedProminent).disabled(stub.busy) }
                }
            } header: {
                Text("Extension")
            }
            Section("Screensaver") {
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        StatusDot(on: s.isActive)
                        Text(s.isActive ? "Active on every display" : "Not active")
                    }
                }
                if let e = s.activationError { Text(e).font(.caption).foregroundStyle(.red) }
                HStack {
                    Spacer()
                    Button("Refresh") { stub.refresh() }
                    Button("Set as Screensaver") { stub.enable() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!s.isInstalled || s.isActive || stub.busy)
                }
            }
            Section("Look") {
                LabeledContent {
                    Button("Tune…") { stub.tune() }.buttonStyle(.borderedProminent)
                } label: {
                    Text("Braille, dot size, frame rate")
                    Text("Over a live full-screen render")
                }
                LabeledContent("System Settings") {
                    Button("Open Screen Saver Settings") { stub.openSystemSettings() }
                }
            }
            if let plist = s.hijackedPlist {
                Section {
                    HijackBanner(plist: plist)
                        .listRowInsets(EdgeInsets())
                }
            }
            Section {
                Text(s.statusMessage).font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: height)
    }
}

/// A grouped Form is a list and has no intrinsic height, so each state gets one.
func groupedFormHeight(_ s: AppState) -> CGFloat {
    var h: CGFloat = 512
    if s.installedPath != nil { h += 30 }
    if s.installError != nil { h += 28 }
    if s.activationError != nil { h += 28 }
    if s.hijackedPlist != nil { h += 150 }
    return h
}

// MARK: - The candidates

struct Candidate {
    let key: String
    let title: String
    let summary: String
    let windowTitle: String
    /// No title bar of its own: the content runs to the top and the traffic
    /// lights sit over it (fullSizeContentView with a transparent title bar).
    var chromeless: Bool = false
    let make: (Stub, Scenario) -> AnyView
}

let round1: [Candidate] = [
    Candidate(key: "00-current", title: "00  current",
              summary: "icon + big title · two status group boxes · two buttons · caption",
              windowTitle: "AppexSaverMinimal",
              make: { stub, _ in AnyView(CurrentWindow(stub: stub)) }),
    Candidate(key: "A-steps", title: "A  steps",
              summary: "three numbered steps in order · next step is blue · one button per step",
              windowTitle: "tSlime",
              make: { stub, _ in AnyView(StepsWindow(stub: stub)) }),
    Candidate(key: "B-preview-first", title: "B  preview first",
              summary: "the saver leads · Tune is the big button · install/activate as a chip strip · ⋯ menu",
              windowTitle: "tSlime",
              make: { stub, _ in AnyView(PreviewFirstWindow(stub: stub)) }),
    Candidate(key: "C-one-button", title: "C  one sentence, one button",
              summary: "what is true now · the one next action · everything else under Details",
              windowTitle: "tSlime",
              make: { stub, sc in AnyView(OneButtonWindow(stub: stub, detailsOpen: sc.detailsOpen)) }),
    Candidate(key: "D-grouped-form", title: "D  grouped form",
              summary: "System Settings idiom · a section per concern · label / value rows",
              windowTitle: "tSlime",
              make: { stub, sc in AnyView(GroupedFormWindow(stub: stub, height: groupedFormHeight(sc.state))) }),
]


// MARK: - Round 2: D, the grouped form, in the settings panel's style (#32 verdict)
//
// The shape is settled — a section for the extension, one for the
// screensaver (with Open Screen Saver Settings in it), one for the look; no
// version, no path. These five differ in how far they take the panel's own
// idiom: its 22 pt padding on a 460 pt sheet, the title3 title row, the
// trailing-label grid at 16/12, dividers at 14, the switch with a sentence
// under it, and exactly one prominent button.

let sheetPad: CGFloat = 22
let sheetWidth: CGFloat = 460

/// The panel's title row with the app's name where "Screensaver Settings" is.
struct SheetTitle: View {
    var close = false
    var body: some View {
        HStack(spacing: 10) {
            AppIcon(size: 26)
            Text("tSlime").font(.title3.weight(.semibold))
            Spacer()
            if close {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
            }
        }
    }
}

/// The panel's Hide row, repurposed: a plain button at the left with a
/// tertiary caption beside it.
struct SheetFoot: View {
    @ObservedObject var stub: Stub
    var body: some View {
        HStack {
            Button("Refresh") { stub.refresh() }
            Text(stub.state.statusMessage).font(.caption).foregroundStyle(.tertiary)
            Spacer()
            if stub.busy { ProgressView().controlSize(.small) }
        }
    }
}

struct SheetDivider: View {
    var body: some View { Divider().padding(.vertical, 14) }
}

/// The panel's hijack alarm, in its wording, as a row of the sheet.
struct SheetHijack: View {
    let plist: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("Saver settings will not apply")
                Text("A container holds a preferences file for this app's settings domain, so this app writes there while the screensaver reads ~/Library/Preferences. Delete it and relaunch.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(plist).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(2).truncationMode(.middle)
            }
        }
    }
}

// D1 — label grid. The panel's Grid, a trailing label per section, the
// status and its one button in the value column.
struct LabelGridSheet: View {
    @ObservedObject var stub: Stub
    var close = false
    var s: AppState { stub.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetTitle(close: close).padding(.bottom, 16)
            if let plist = s.hijackedPlist { SheetHijack(plist: plist); SheetDivider() }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Text("Extension").gridColumnAlignment(.trailing)
                    HStack {
                        StatusDot(on: s.isInstalled)
                        Text(s.isInstalled ? "Registered with pluginkit" : "Not registered")
                        Spacer()
                        if s.isInstalled { Button("Uninstall") { stub.uninstall() }.disabled(stub.busy) }
                        else { Button("Install") { stub.install() }.buttonStyle(.borderedProminent).disabled(stub.busy) }
                    }
                }
                if let e = s.installError { GridRow { Text(""); Text(e).font(.caption).foregroundStyle(.red) } }
            }
            SheetDivider()
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Text("Screensaver").gridColumnAlignment(.trailing)
                    HStack {
                        StatusDot(on: s.isActive)
                        Text(s.isActive ? "Yours, on every display" : "Not yours")
                        Spacer()
                        Button("Set as Screensaver") { stub.enable() }
                            .buttonStyle(.borderedProminent)
                            .disabled(!s.isInstalled || s.isActive || stub.busy)
                    }
                }
                if let e = s.activationError {
                    GridRow { Text(""); Text(e).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
                }
                GridRow {
                    Text("")
                    HStack {
                        Button("Open Screen Saver Settings") { stub.openSystemSettings() }
                        Text("to preview or time it").font(.caption).foregroundStyle(.tertiary)
                        Spacer()
                    }
                }
            }
            SheetDivider()
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Text("Look").gridColumnAlignment(.trailing)
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Braille, dot size, frame rate")
                            Text("Over a live full-screen render").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Tune…") { stub.tune() }
                            .buttonStyle(s.isActive ? .borderedProminent : .bordered)
                    }
                }
            }
            SheetDivider()
            SheetFoot(stub: stub)
        }
        .padding(sheetPad)
        .frame(width: sheetWidth)
    }
}

// The one prominent button per window is the next thing to do. SwiftUI
// cannot switch button styles on a Bool directly; this can.
extension View {
    @ViewBuilder
    func buttonStyle(_ prominent: Bool) -> some View {
        if prominent { self.buttonStyle(.borderedProminent) } else { self.buttonStyle(.bordered) }
    }
}
extension Button {
    func buttonStyle(_ style: PrimitiveButtonStyleChoice) -> some View {
        Group {
            switch style {
            case .borderedProminent: self.buttonStyle(BorderedProminentButtonStyle())
            case .bordered: self.buttonStyle(BorderedButtonStyle())
            }
        }
    }
}
enum PrimitiveButtonStyleChoice { case borderedProminent, bordered }

// D2 — switches. Each state is the panel's "Smooth motion" row: a switch
// with a sentence under the title saying what it does. Turning a switch on
// installs or activates; the screensaver switch cannot be turned off from
// here, which its sentence says.
struct SwitchesSheet: View {
    @ObservedObject var stub: Stub
    var s: AppState { stub.state }

    private var registered: Binding<Bool> {
        Binding(get: { s.isInstalled }, set: { $0 ? stub.install() : stub.uninstall() })
    }
    private var yours: Binding<Bool> {
        Binding(get: { s.isActive }, set: { if $0 { stub.enable() } })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetTitle().padding(.bottom, 16)
            if let plist = s.hijackedPlist { SheetHijack(plist: plist); SheetDivider() }
            Toggle(isOn: registered) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Registered with macOS")
                    Text(s.isInstalled
                         ? "Version \(s.installedVersion ?? "?"), with pluginkit. Off unregisters it."
                         : "Registers the extension with pluginkit. macOS usually finds a fresh build by itself.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if let e = s.installError { Text(e).font(.caption).foregroundStyle(.red) }
                }
            }
            .toggleStyle(.switch).disabled(stub.busy)
            SheetDivider()
            Toggle(isOn: yours) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your screensaver")
                    Text(s.isActive
                         ? "On every display. To pick another, use System Settings."
                         : "Sets tSlime as the screensaver on every display.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if let e = s.activationError { Text(e).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
                }
            }
            .toggleStyle(.switch).disabled(!s.isInstalled || s.isActive || stub.busy)
            HStack {
                Spacer()
                Button("Open Screen Saver Settings") { stub.openSystemSettings() }
            }
            .padding(.top, 12)
            SheetDivider()
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Look")
                    Text("Braille, dot size and frame rate, over a live full-screen render.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Tune…") { stub.tune() }.buttonStyle(s.isActive)
            }
            SheetDivider()
            SheetFoot(stub: stub)
        }
        .padding(sheetPad)
        .frame(width: sheetWidth)
    }
}

// D5 — captioned rows. The Smooth-motion row again, but with a button
// where the switch is: title, a sentence saying what is true, one control.
struct CaptionedRow<Control: View>: View {
    let title: String
    let caption: String
    var error: String? = nil
    @ViewBuilder let control: () -> Control
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(caption).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let error { Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 16)
            control()
        }
    }
}

struct CaptionedRowsSheet: View {
    @ObservedObject var stub: Stub
    var s: AppState { stub.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetTitle().padding(.bottom, 16)
            if let plist = s.hijackedPlist { SheetHijack(plist: plist); SheetDivider() }
            CaptionedRow(title: "Extension",
                         caption: s.isInstalled
                            ? "Registered with pluginkit, version \(s.installedVersion ?? "?")."
                            : "Not registered. macOS usually finds a fresh build by itself.",
                         error: s.installError) {
                if s.isInstalled { Button("Uninstall") { stub.uninstall() }.disabled(stub.busy) }
                else { Button("Install") { stub.install() }.buttonStyle(.borderedProminent).disabled(stub.busy) }
            }
            SheetDivider()
            CaptionedRow(title: "Screensaver",
                         caption: s.isActive ? "Yours, on every display." : (s.isInstalled ? "Not yours yet." : "Not yours yet; register the extension first."),
                         error: s.activationError) {
                Button("Set as Screensaver") { stub.enable() }
                    .buttonStyle(s.isInstalled && !s.isActive)
                    .disabled(!s.isInstalled || s.isActive || stub.busy)
            }
            CaptionedRow(title: "System Settings", caption: "Where the screensaver is previewed and timed.") {
                Button("Open Screen Saver Settings") { stub.openSystemSettings() }
            }
            .padding(.top, 12)
            SheetDivider()
            CaptionedRow(title: "Look", caption: "Braille, dot size and frame rate, over a live full-screen render.") {
                Button("Tune…") { stub.tune() }.buttonStyle(s.isActive)
            }
            SheetDivider()
            SheetFoot(stub: stub)
        }
        .padding(sheetPad)
        .frame(width: sheetWidth)
    }
}

// D4 — the native grouped form with the decided edits: no version, no path,
// Open Screen Saver Settings under Screensaver. The control for the range.
struct DecidedGroupedForm: View {
    @ObservedObject var stub: Stub
    let height: CGFloat
    var s: AppState { stub.state }

    var body: some View {
        Form {
            Section("Extension") {
                LabeledContent("Status") {
                    HStack(spacing: 6) { StatusDot(on: s.isInstalled); Text(s.isInstalled ? "Registered" : "Not registered") }
                }
                if let e = s.installError { Text(e).font(.caption).foregroundStyle(.red) }
                HStack {
                    Spacer()
                    Button("Refresh") { stub.refresh() }
                    if s.isInstalled { Button("Uninstall") { stub.uninstall() }.disabled(stub.busy) }
                    else { Button("Install") { stub.install() }.buttonStyle(.borderedProminent).disabled(stub.busy) }
                }
            }
            Section("Screensaver") {
                LabeledContent("Status") {
                    HStack(spacing: 6) { StatusDot(on: s.isActive); Text(s.isActive ? "Active on every display" : "Not active") }
                }
                if let e = s.activationError { Text(e).font(.caption).foregroundStyle(.red) }
                HStack {
                    Spacer()
                    Button("Refresh") { stub.refresh() }
                    // Plain until the extension is registered (#34): a dim
                    // prominent button under a step not yet taken read wrong.
                    Button("Set as Screensaver") { stub.enable() }
                        .buttonStyle(s.isInstalled)
                        .disabled(!s.isInstalled || s.isActive || stub.busy)
                }
                LabeledContent("System Settings") {
                    Button("Open Screen Saver Settings") { stub.openSystemSettings() }
                }
            }
            Section("Look") {
                LabeledContent {
                    Button("Tune…") { stub.tune() }.buttonStyle(.borderedProminent)
                } label: {
                    Text("Braille, dot size, frame rate")
                    Text("Over a live full-screen render")
                }
            }
            if let plist = s.hijackedPlist {
                Section { HijackBanner(plist: plist).listRowInsets(EdgeInsets()) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: height)
    }
}

// Decided (2026-09-20): D4 without the status caption at the foot — the
// dots already say what it said, and "Ready" said nothing.
func decidedFormHeight(_ s: AppState) -> CGFloat {
    var h: CGFloat = 418
    if s.installError != nil { h += 28 }
    if s.activationError != nil { h += 28 }
    if s.hijackedPlist != nil { h += 150 }
    return h
}

// D3 — the sheet over the saver. What the panel is: the label grid on
// material, floating over a 1:1 crop of the render, in a window with no
// title bar of its own. The material is faked the way the panel prototype
// faked it — a blur of what is under the sheet, then a tint — because
// `.regularMaterial` cannot render offscreen.

let backdrop2x: CGImage = {
    let here = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
    let root = FileManager.default.fileExists(atPath: here.appendingPathComponent("frames").path)
        ? here : here.deletingLastPathComponent()
    let text = try! String(contentsOf: root.appendingPathComponent("frames/03-dense.txt"), encoding: .utf8)
    return renderBackdrop(grid: parseFrame(text), canvas: CGSize(width: 1920, height: 1080), scale: 2)
}()
let ciContext = CIContext()

/// A `size`-point window's worth of the render, centred on the trails'
/// convergence, at 2x; and the same, blurred for the material.
func saverCrop(size: CGSize) -> (NSImage, NSImage) {
    let scale: CGFloat = 2
    let centre = CGPoint(x: 960, y: 560)
    let px = CGRect(x: (centre.x - size.width / 2) * scale, y: (centre.y - size.height / 2) * scale,
                    width: size.width * scale, height: size.height * scale)
    let crop = backdrop2x.cropping(to: px)!
    let ci = CIImage(cgImage: crop).clampedToExtent()
        .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 24])
        .cropped(to: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
    let blurred = ciContext.createCGImage(ci, from: ci.extent)!
    return (NSImage(cgImage: crop, size: size), NSImage(cgImage: blurred, size: size))
}

func measure<V: View>(_ view: V) -> CGSize {
    let hosting = NSHostingView(rootView: view)
    hosting.appearance = NSAppearance(named: .darkAqua)
    return hosting.fittingSize
}

struct SheetOverSaverWindow: View {
    @ObservedObject var stub: Stub
    let size: CGSize
    let crop: NSImage
    let blurred: NSImage

    var body: some View {
        ZStack {
            Image(nsImage: crop).resizable().frame(width: size.width, height: size.height)
            LabelGridSheet(stub: stub, close: true)
                .background(
                    Image(nsImage: blurred).resizable().frame(width: size.width, height: size.height)
                        .overlay(Color(white: 0.13).opacity(0.45))
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.10)))
        }
        .frame(width: size.width, height: size.height)
    }
}

func sheetOverSaver(_ stub: Stub) -> AnyView {
    let sheet = measure(LabelGridSheet(stub: stub, close: true))
    let size = CGSize(width: sheet.width + 80, height: sheet.height + 80)
    let (crop, blurred) = saverCrop(size: size)
    return AnyView(SheetOverSaverWindow(stub: stub, size: size, crop: crop, blurred: blurred))
}

let round2: [Candidate] = [
    Candidate(key: "D4-decided-grouped", title: "D4  decided grouped form",
              summary: "the native grouped form with the decided edits, no status caption · the verdict",
              windowTitle: "tSlime",
              make: { stub, sc in AnyView(DecidedGroupedForm(stub: stub, height: decidedFormHeight(sc.state))) }),
    Candidate(key: "D1-label-grid", title: "D1  label grid",
              summary: "the panel's grid: a trailing label per section, status and its button in the value column",
              windowTitle: "tSlime",
              make: { stub, _ in AnyView(LabelGridSheet(stub: stub)) }),
    Candidate(key: "D5-captioned-rows", title: "D5  captioned rows",
              summary: "the Smooth-motion row with a button in the switch's place: title, sentence, one control",
              windowTitle: "tSlime",
              make: { stub, _ in AnyView(CaptionedRowsSheet(stub: stub)) }),
    Candidate(key: "D2-switches", title: "D2  switches",
              summary: "each state is a switch with a sentence under it; on installs or activates",
              windowTitle: "tSlime",
              make: { stub, _ in AnyView(SwitchesSheet(stub: stub)) }),
    Candidate(key: "D3-sheet-over-saver", title: "D3  sheet over the saver",
              summary: "the label grid on material over a 1:1 crop of the render · no title bar · the panel itself",
              windowTitle: "tSlime", chromeless: true,
              make: { stub, _ in sheetOverSaver(stub) }),
]

// MARK: - Offscreen rendering, 2x, inside a mock title bar

/// An offscreen window is never key, and AppKit draws prominent buttons in
/// inactive grey when it is not. Lie about it, as prototype/panel-look did.
final class KeyOffscreenWindow: NSWindow {
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
    @objc func hasKeyAppearance() -> Bool { true }
    @objc func _hasActiveAppearance() -> Bool { true }
    @objc func _hasActiveControls() -> Bool { true }
    @objc func _hasKeyAppearance() -> Bool { true }
}

func renderContent(_ view: AnyView, dark: Bool, scale: CGFloat) -> (CGImage, CGSize) {
    let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    let hosting = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
    hosting.appearance = appearance
    let size = hosting.fittingSize
    hosting.frame = NSRect(origin: .zero, size: size)
    let window = KeyOffscreenWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = appearance
    window.backgroundColor = .clear
    window.isOpaque = false
    window.contentView = hosting
    hosting.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    hosting.layoutSubtreeIfNeeded()
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
                               pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    hosting.cacheDisplay(in: hosting.bounds, to: rep)
    return (rep.cgImage!, size)
}

let titleBarHeight: CGFloat = 28
let desktopMargin: CGFloat = 44

/// The content inside a mock titled window on a flat desktop, with a shadow,
/// so the candidate reads as a window and its size against the title bar can
/// be judged.
func windowImage(content: CGImage, size: CGSize, title: String, dark: Bool, scale: CGFloat, chromeless: Bool = false) -> CGImage {
    let titleBarHeight: CGFloat = chromeless ? 0 : titleBarHeight
    let w = size.width + desktopMargin * 2
    let h = size.height + titleBarHeight + desktopMargin * 2
    let ctx = CGContext(data: nil, width: Int(w * scale), height: Int(h * scale), bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    ctx.setFillColor(NSColor(white: dark ? 0.32 : 0.78, alpha: 1).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

    let frame = CGRect(x: desktopMargin, y: desktopMargin, width: size.width, height: size.height + titleBarHeight)
    let path = CGPath(roundedRect: frame, cornerWidth: 10, cornerHeight: 10, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: NSColor.black.withAlphaComponent(0.55).cgColor)
    ctx.addPath(path)
    ctx.setFillColor(NSColor(white: dark ? 0.19 : 0.93, alpha: 1).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    ctx.draw(content, in: CGRect(x: frame.minX, y: frame.minY, width: size.width, height: size.height))
    let bar = CGRect(x: frame.minX, y: frame.maxY - (chromeless ? 28 : titleBarHeight), width: size.width, height: chromeless ? 28 : titleBarHeight)
    if !chromeless {
        ctx.setFillColor(NSColor(white: dark ? 0.19 : 0.93, alpha: 1).cgColor)
        ctx.fill(bar)
        ctx.setFillColor(NSColor(white: dark ? 0 : 0.7, alpha: 0.5).cgColor)
        ctx.fill(CGRect(x: bar.minX, y: bar.minY, width: bar.width, height: 1 / scale))
    }
    for (i, color) in [NSColor(srgbRed: 1, green: 0.373, blue: 0.341, alpha: 1),
                       NSColor(srgbRed: 0.996, green: 0.737, blue: 0.180, alpha: 1),
                       NSColor(srgbRed: 0.157, green: 0.784, blue: 0.251, alpha: 1)].enumerated() {
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: bar.minX + 13 + CGFloat(i) * 20, y: bar.midY - 6, width: 12, height: 12))
    }
    if !chromeless {
        let label = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor(white: dark ? 1 : 0, alpha: dark ? 0.7 : 0.75)])
        let line = CTLineCreateWithAttributedString(label)
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        ctx.textPosition = CGPoint(x: bar.midX - width / 2, y: bar.midY - 4.5)
        CTLineDraw(line, ctx)
    }
    ctx.restoreGState()

    ctx.addPath(path)
    ctx.setStrokeColor(NSColor(white: dark ? 1 : 0, alpha: dark ? 0.16 : 0.18).cgColor)
    ctx.setLineWidth(1 / scale)
    ctx.strokePath()
    return ctx.makeImage()!
}

func writePNG(_ img: CGImage, to url: URL) {
    let data = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])!
    try! data.write(to: url)
}

/// Tiles in a grid at 1x, `cols` across, tops aligned, each with a label
/// above it — the panel prototype's contact sheet, with more tiles.
func contactSheet(tiles: [(label: String, sub: String, image: CGImage)], cols: Int, scale: CGFloat) -> CGImage {
    let gap: CGFloat = 28, labelH: CGFloat = 56
    let widths = tiles.map { CGFloat($0.image.width) / scale }
    let heights = tiles.map { CGFloat($0.image.height) / scale }
    let cellW = (widths.max() ?? 0), cellH = (heights.max() ?? 0) + labelH
    let rows = (tiles.count + cols - 1) / cols
    let w = cellW * CGFloat(cols) + gap * CGFloat(cols + 1)
    let h = cellH * CGFloat(rows) + gap * CGFloat(rows + 1)
    let ctx = CGContext(data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
    ctx.setFillColor(NSColor(white: 0.12, alpha: 1).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.interpolationQuality = .high
    for (i, tile) in tiles.enumerated() {
        let col = CGFloat(i % cols), row = CGFloat(i / cols)
        let x = gap + col * (cellW + gap)
        let top = h - gap - row * (cellH + gap) - labelH
        ctx.draw(tile.image, in: CGRect(x: x, y: top - heights[i], width: widths[i], height: heights[i]))
        let title = NSAttributedString(string: tile.label, attributes: [
            .font: NSFont.systemFont(ofSize: 24, weight: .semibold), .foregroundColor: NSColor.systemYellow])
        ctx.textPosition = CGPoint(x: x + 8, y: top + 28)
        CTLineDraw(CTLineCreateWithAttributedString(title), ctx)
        let sub = NSAttributedString(string: tile.sub, attributes: [
            .font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor(white: 0.8, alpha: 1)])
        ctx.textPosition = CGPoint(x: x + 8, y: top + 8)
        CTLineDraw(CTLineCreateWithAttributedString(sub), ctx)
    }
    return ctx.makeImage()!
}

// MARK: - Live mode: a real window with a switcher strip under the candidate

var candidates: [Candidate] = []

final class LiveNav: ObservableObject {
    @Published var candidate = 1
    @Published var scenario = 2
}

struct SwitcherBar: View {
    @ObservedObject var nav: LiveNav
    let reset: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Button("◀") { nav.candidate = (nav.candidate + candidates.count - 1) % candidates.count }
            Text(candidates[nav.candidate].title).frame(minWidth: 190)
            Button("▶") { nav.candidate = (nav.candidate + 1) % candidates.count }
            Text("·")
            Button("▲") { nav.scenario = (nav.scenario + scenarios.count - 1) % scenarios.count }
            Text(scenarios[nav.scenario].title).frame(minWidth: 150)
            Button("▼") { nav.scenario = (nav.scenario + 1) % scenarios.count }
            Text("·")
            Button("reset") { reset() }
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .foregroundStyle(.black)
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(Capsule().fill(Color.yellow))
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }
}

struct LiveRoot: View {
    @ObservedObject var nav: LiveNav
    @ObservedObject var stub: Stub
    let reset: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            candidates[nav.candidate].make(stub, scenarios[nav.scenario])
                .id("\(nav.candidate)-\(nav.scenario)")
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            SwitcherBar(nav: nav, reset: reset)
        }
    }
}

func runLive() {
    NSApp.setActivationPolicy(.regular)
    let nav = LiveNav()
    let stub = Stub(scenarios[nav.scenario].state)
    let reset = { stub.state = scenarios[nav.scenario].state }
    let hosting = NSHostingView(rootView: LiveRoot(nav: nav, stub: stub, reset: reset))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
    window.contentView = hosting
    window.isReleasedWhenClosed = false
    window.title = candidates[nav.candidate].windowTitle + "   [prototype]"

    var lastScenario = nav.scenario
    func fit() {
        DispatchQueue.main.async {
            let size = hosting.fittingSize
            window.setContentSize(size)
            window.title = candidates[nav.candidate].windowTitle + "   [prototype]"
        }
    }
    let subs = [
        nav.objectWillChange.sink { _ in
            DispatchQueue.main.async {
                if nav.scenario != lastScenario { lastScenario = nav.scenario; reset() }
                fit()
            }
        },
        stub.objectWillChange.sink { _ in fit() },
    ]
    withExtendedLifetime(subs) {}
    fit()
    window.center()
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    _ = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        if window.firstResponder is NSTextView { return event }
        switch event.keyCode {
        case 123: nav.candidate = (nav.candidate + candidates.count - 1) % candidates.count
        case 124: nav.candidate = (nav.candidate + 1) % candidates.count
        case 126: nav.scenario = (nav.scenario + scenarios.count - 1) % scenarios.count
        case 125: nav.scenario = (nav.scenario + 1) % scenarios.count
        case 15: reset()   // r
        default: return event
        }
        return nil
    }
    _ = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
        NSApp.terminate(nil)
    }
    NSApp.run()
}

// MARK: - Main

_ = NSApplication.shared
NSApp.setActivationPolicy(.prohibited)

let args = Array(CommandLine.arguments.dropFirst())
if args.contains("--live") {
    candidates = args.contains("--round1") ? round1 : round2
    runLive()
    exit(0)
}
guard let outArg = args.first(where: { !$0.hasPrefix("--") }) else {
    FileHandle.standardError.write("usage: AppLook <outdir> [--light] [--round1]  |  AppLook --live [--round1]\n".data(using: .utf8)!)
    exit(2)
}
let dark = !args.contains("--light")
candidates = args.contains("--round1") ? round1 : round2
let outDir = URL(fileURLWithPath: outArg)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let scale: CGFloat = 2

var images: [String: (CGImage, CGSize)] = [:]
for sc in scenarios {
    for c in candidates {
        let stub = Stub(sc.state)
        let (content, size) = renderContent(c.make(stub, sc), dark: dark, scale: scale)
        let img = windowImage(content: content, size: size, title: c.windowTitle, dark: dark, scale: scale, chromeless: c.chromeless)
        images["\(c.key)|\(sc.key)"] = (img, size)
        writePNG(img, to: outDir.appendingPathComponent("\(c.key)--\(sc.key).png"))
        print(String(format: "%-18@ %-14@ window %4.0f x %3.0f pt", c.key as NSString, sc.key as NSString, size.width, size.height + titleBarHeight))
    }
}

for sc in scenarios {
    let tiles = candidates.map { c in (label: c.title, sub: c.summary, image: images["\(c.key)|\(sc.key)"]!.0) }
    writePNG(contactSheet(tiles: tiles, cols: 3, scale: scale), to: outDir.appendingPathComponent("sheet--\(sc.key).png"))
}
for c in candidates {
    let tiles = scenarios.map { sc in (label: sc.title, sub: c.title, image: images["\(c.key)|\(sc.key)"]!.0) }
    writePNG(contactSheet(tiles: tiles, cols: 2, scale: scale), to: outDir.appendingPathComponent("sheet--\(c.key).png"))
}
print("wrote \(images.count + scenarios.count + candidates.count) png(s) to \(outDir.path)")
