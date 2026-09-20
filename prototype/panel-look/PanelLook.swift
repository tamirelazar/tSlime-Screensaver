// PROTOTYPE — throwaway. Answers ticket #26: "How should the settings panel look?"
//
// Composites candidate settings panels over a real captured 190x56 tslime
// frame, rendered the way the saver renders it today (16 pt SF Mono metrics,
// procedural rounded dots at 78% of pitch, 2x backing, 1920x1080 points), so
// each candidate's footprint, opacity and control reading can be judged by
// eye against the thing it covers.
//
// The panels are real SwiftUI/AppKit controls rendered offscreen in dark
// appearance. The material behind each panel is faked here — a blur of the
// frame under it plus a tint — because `.regularMaterial` needs a compositor
// behind it and an offscreen bitmap has none. The blur is what the real
// material does, so the opacity judgment transfers.
//
// Headless only:  ./run.sh <outdir> [frame-index]
// Writes <key>-full.png (whole screen, 2x), <key>-crop.png (the panel and a
// margin, 2x native pixels) and contact-sheet.png (every candidate at 1x).

import AppKit
import CoreImage
import CoreText
import SwiftUI

// MARK: - Frame data (as prototype/braille-look)

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

/// The decided look (#8/#15): rounded square, 78% of pitch, corner 0.3, inset 0.
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

/// The saver's render: grid anchored top-left of a 1920x1080 point screen, black slack.
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

// MARK: - Candidates

/// What sits between the frame and the controls.
enum Backing {
    /// Blur the frame under the panel, then tint it: what `.regularMaterial` does.
    case material(tint: CGFloat, blur: CGFloat)
    /// A flat colour, no blur.
    case solid(alpha: CGFloat)
}

struct Candidate {
    let key: String
    let title: String
    let summary: String
    let backing: Backing
    let cornerRadius: CGFloat
    /// Top-left origin in points, y down, for a panel of `size` on a `canvas`.
    let place: (_ size: CGSize, _ canvas: CGSize) -> CGPoint
    let view: AnyView
}

// Shared pieces — deliberately few: each candidate lays itself out.

let sources = ["Drawn", "JuliaMono Bold", "JetBrainsMono NFM"]

struct SourcePicker: View {
    var label: String? = "Braille"
    var body: some View {
        let picker = Picker(label ?? "", selection: .constant(0)) {
            ForEach(0..<3) { Text(sources[$0]).tag($0) }
        }
        if label == nil { picker.labelsHidden() } else { picker }
    }
}

/// A radio row that can carry a subtitle, drawn by hand so the subtitle is
/// part of the row and not a caption floating under a radio group.
struct RadioRow: View {
    let title: String
    let subtitle: String
    let on: Bool
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            ZStack {
                Circle().strokeBorder(Color.secondary.opacity(0.6), lineWidth: 1)
                    .background(Circle().fill(on ? Color.accentColor : Color.clear))
                    .frame(width: 14, height: 14)
                if on { Circle().fill(Color.white).frame(width: 5, height: 5) }
            }
            .offset(y: 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// Two capsules, one half full and one full: the cost as a picture.
struct CoreMeter: View {
    let fraction: CGFloat
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule().fill(Color.accentColor).frame(width: g.size.width * fraction)
            }
        }
        .frame(height: 6)
    }
}

// A — corner card. Radio rows with the cost as a subtitle; sliders with
// numeric readouts; Exit alone on the left, Discard and Accept on the right.
struct CornerCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Screensaver").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                SourcePicker().frame(width: 260)
                HStack {
                    Text("Dot size").frame(width: 64, alignment: .leading)
                    Slider(value: .constant(0.78), in: 0.5...1)
                    Text("0.78").font(.caption.monospacedDigit()).frame(width: 30, alignment: .trailing)
                }
                HStack {
                    Text("Corner").frame(width: 64, alignment: .leading)
                    Slider(value: .constant(0.30), in: 0...1)
                    Text("0.30").font(.caption.monospacedDigit()).frame(width: 30, alignment: .trailing)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Frame rate").font(.subheadline.weight(.medium))
                RadioRow(title: "30 fps", subtitle: "Uses about half a CPU core while running", on: false)
                RadioRow(title: "60 fps", subtitle: "Uses about a full CPU core while running", on: true)
            }
            Divider()
            HStack {
                Button("Exit") {}
                Spacer()
                Button("Discard") {}
                Button("Accept") {}.buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 340)
    }
}

// B — bottom strip. One row across the screen's foot: every control inline,
// a captioned segmented control for the rate, Exit as the row's last word.
struct BottomStrip: View {
    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            SourcePicker().frame(width: 230)
            HStack(spacing: 6) {
                Text("Dot size")
                Slider(value: .constant(0.78), in: 0.5...1).frame(width: 110)
                Text("0.78").font(.caption.monospacedDigit())
            }
            HStack(spacing: 6) {
                Text("Corner")
                Slider(value: .constant(0.30), in: 0...1).frame(width: 110)
                Text("0.30").font(.caption.monospacedDigit())
            }
            VStack(spacing: 3) {
                Picker("", selection: .constant(1)) {
                    Text("30 fps").tag(0)
                    Text("60 fps").tag(1)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 150)
                HStack {
                    Text("½ core").frame(maxWidth: .infinity)
                    Text("1 core").frame(maxWidth: .infinity)
                }
                .font(.caption2).foregroundStyle(.secondary).frame(width: 150)
            }
            Spacer()
            Button("Discard") {}
            Button("Accept") {}.buttonStyle(.borderedProminent)
            Divider().frame(height: 22)
            Button("Exit") {}
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(width: 1920)
    }
}

// C — centred sheet. A form the way System Settings would lay it out; the
// rate is a "smooth motion" switch that says what it costs; the fractions are
// steppers with the number in a field; the title row carries the close.
struct CentredSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Screensaver Settings").font(.title3.weight(.semibold))
                Spacer()
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
            }
            .padding(.bottom, 16)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Text("Braille").gridColumnAlignment(.trailing)
                    SourcePicker(label: nil).frame(width: 220)
                }
                GridRow {
                    Text("Dot size")
                    HStack(spacing: 4) {
                        TextField("", text: .constant("0.78")).textFieldStyle(.roundedBorder).frame(width: 56)
                        Stepper("", value: .constant(78), in: 50...100).labelsHidden()
                        Text("of the dot pitch").font(.caption).foregroundStyle(.secondary)
                    }
                }
                GridRow {
                    Text("Corner")
                    HStack(spacing: 4) {
                        TextField("", text: .constant("0.30")).textFieldStyle(.roundedBorder).frame(width: 56)
                        Stepper("", value: .constant(30), in: 0...100).labelsHidden()
                        Text("0 square · 1 round").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Divider().padding(.vertical, 14)
            Toggle(isOn: .constant(true)) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Smooth motion")
                    Text("60 fps. Uses about a full CPU core the whole time the saver is up; off, 30 fps uses about half.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            Divider().padding(.vertical, 14)
            HStack {
                Text("Esc exits without saving").font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button("Discard") {}
                Button("Accept") {}.buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 460)
    }
}

// D — compact palette. Opaque, small, in the corner the logo is not in.
// Qualitative sliders with no numbers; the rate as two rows with a meter
// showing what each spends; one prominent button and two that are not.
struct CompactPalette: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SourcePicker(label: nil).frame(width: 200)
            VStack(alignment: .leading, spacing: 2) {
                Slider(value: .constant(0.78), in: 0.5...1)
                HStack { Text("finer"); Spacer(); Text("dot size"); Spacer(); Text("bolder") }
                    .font(.caption2).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Slider(value: .constant(0.30), in: 0...1)
                HStack { Text("square"); Spacer(); Text("corner"); Spacer(); Text("round") }
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    RadioRow(title: "30 fps", subtitle: "", on: false).frame(width: 64, alignment: .leading)
                    CoreMeter(fraction: 0.5)
                    Text("½ core").font(.caption).foregroundStyle(.secondary).frame(width: 46, alignment: .trailing)
                }
                HStack(spacing: 10) {
                    RadioRow(title: "60 fps", subtitle: "", on: true).frame(width: 64, alignment: .leading)
                    CoreMeter(fraction: 1.0)
                    Text("1 core").font(.caption).foregroundStyle(.secondary).frame(width: 46, alignment: .trailing)
                }
                Text("CPU while the saver runs").font(.caption2).foregroundStyle(.tertiary)
            }
            Divider()
            HStack(spacing: 14) {
                Button("Accept") {}.buttonStyle(.borderedProminent)
                Button("Discard") {}.buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button("Exit") {}.buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 250)
    }
}

// Fix the subtitle-less radio rows' height so they line up with the meter.
extension RadioRow {
    init(title: String, on: Bool) { self.init(title: title, subtitle: "", on: on) }
}

// C, decided (2026-09-20): the sheet, with the fractions as sliders like the
// other candidates, draggable by its title row, and a Hide button at the
// bottom-left that takes the panel away until the next mouse or key input.
struct DecidedSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                Text("Screensaver Settings").font(.title3.weight(.semibold))
                Spacer()
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
            }
            .padding(.bottom, 16)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Text("Braille").gridColumnAlignment(.trailing)
                    SourcePicker(label: nil).frame(width: 220)
                }
                GridRow {
                    Text("Dot size")
                    HStack {
                        Slider(value: .constant(0.78), in: 0.5...1)
                        Text("0.78").font(.caption.monospacedDigit()).frame(width: 30, alignment: .trailing)
                    }
                }
                GridRow {
                    Text("Corner")
                    HStack {
                        Slider(value: .constant(0.30), in: 0...1)
                        Text("0.30").font(.caption.monospacedDigit()).frame(width: 30, alignment: .trailing)
                    }
                }
            }
            Divider().padding(.vertical, 14)
            Toggle(isOn: .constant(true)) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Smooth motion")
                    Text("60 fps. Uses about a full CPU core the whole time the saver is up; off, 30 fps uses about half.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(.switch)
            Divider().padding(.vertical, 14)
            HStack {
                Button("Hide") {}
                Text("until the next input").font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button("Discard") {}
                Button("Accept") {}.buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 460)
    }
}

let candidates: [Candidate] = [
    Candidate(key: "A-corner-card", title: "A  corner card",
              summary: "top-right · material · radio rows with cost subtitles · sliders with numbers",
              backing: .material(tint: 0.55, blur: 18), cornerRadius: 12,
              place: { s, c in CGPoint(x: c.width - s.width - 40, y: 40) },
              view: AnyView(CornerCard())),
    Candidate(key: "B-bottom-strip", title: "B  bottom strip",
              summary: "full-width foot · darker material · captioned segment · everything inline",
              backing: .material(tint: 0.72, blur: 18), cornerRadius: 0,
              place: { s, c in CGPoint(x: 0, y: c.height - s.height) },
              view: AnyView(BottomStrip())),
    Candidate(key: "C-centred-sheet", title: "C  centred sheet",
              summary: "centre · light material · smooth-motion switch · steppers with numbers · close in title",
              backing: .material(tint: 0.45, blur: 24), cornerRadius: 14,
              place: { s, c in CGPoint(x: (c.width - s.width) / 2, y: (c.height - s.height) / 2) },
              view: AnyView(CentredSheet())),
    Candidate(key: "D-compact-palette", title: "D  compact palette",
              summary: "bottom-left · opaque · qualitative sliders · rate rows with a core meter",
              backing: .solid(alpha: 0.92), cornerRadius: 10,
              place: { s, c in CGPoint(x: 40, y: c.height - s.height - 40) },
              view: AnyView(CompactPalette())),
    Candidate(key: "C2-decided-sheet", title: "C2  decided sheet",
              summary: "C with sliders · drag handle in the title · Hide at bottom-left until the next input",
              backing: .material(tint: 0.45, blur: 24), cornerRadius: 14,
              place: { s, c in CGPoint(x: (c.width - s.width) / 2, y: (c.height - s.height) / 2) },
              view: AnyView(DecidedSheet())),
]

// MARK: - Offscreen rendering of a SwiftUI panel, 2x, dark, transparent

/// An offscreen window is never key, and AppKit draws prominent buttons,
/// switches and segment selections in inactive grey when it is not. The
/// real panel lives in a key window, so lie about it here.
final class KeyOffscreenWindow: NSWindow {
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
    // The public overrides are not what cells consult; these private ones are.
    @objc func hasKeyAppearance() -> Bool { true }
    @objc func _hasActiveAppearance() -> Bool { true }
    @objc func _hasActiveControls() -> Bool { true }
    @objc func _hasKeyAppearance() -> Bool { true }
}

func renderPanel(_ view: AnyView, scale: CGFloat) -> (CGImage, CGSize) {
    let hosting = NSHostingView(rootView: view)
    hosting.appearance = NSAppearance(named: .darkAqua)
    let size = hosting.fittingSize
    hosting.frame = NSRect(origin: .zero, size: size)
    let window = KeyOffscreenWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .darkAqua)
    window.backgroundColor = .clear
    window.isOpaque = false
    window.contentView = hosting
    hosting.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    hosting.layoutSubtreeIfNeeded()
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
                               pixelsHigh: Int(size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    hosting.cacheDisplay(in: hosting.bounds, to: rep)
    return (rep.cgImage!, size)
}

// MARK: - Compositing

let ciContext = CIContext()

func composite(backdrop: CGImage, candidate: Candidate, canvas: CGSize, scale: CGFloat) -> (CGImage, CGRect) {
    let (panelImg, panelSize) = renderPanel(candidate.view, scale: scale)
    let origin = candidate.place(panelSize, canvas)
    // CG space: y up.
    let rect = CGRect(x: origin.x, y: canvas.height - origin.y - panelSize.height,
                      width: panelSize.width, height: panelSize.height)
    let ctx = CGContext(data: nil, width: backdrop.width, height: backdrop.height, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
    ctx.draw(backdrop, in: CGRect(x: 0, y: 0, width: backdrop.width, height: backdrop.height))
    ctx.scaleBy(x: scale, y: scale)

    let path = CGPath(roundedRect: rect, cornerWidth: candidate.cornerRadius,
                      cornerHeight: candidate.cornerRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    switch candidate.backing {
    case .material(let tint, let blur):
        let px = CGRect(x: rect.minX * scale, y: rect.minY * scale,
                        width: rect.width * scale, height: rect.height * scale)
        let ci = CIImage(cgImage: backdrop)
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blur * scale / 2])
            .cropped(to: px)
        if let blurred = ciContext.createCGImage(ci, from: px) {
            ctx.draw(blurred, in: rect)
        }
        ctx.setFillColor(NSColor(white: 0.13, alpha: tint).cgColor)
        ctx.fill(rect)
    case .solid(let alpha):
        ctx.setFillColor(NSColor(white: 0.11, alpha: alpha).cgColor)
        ctx.fill(rect)
    }
    ctx.restoreGState()
    // A hairline so the edge reads against dark braille, the way material does.
    ctx.addPath(path)
    ctx.setStrokeColor(NSColor(white: 1, alpha: 0.10).cgColor)
    ctx.setLineWidth(1 / scale)
    ctx.strokePath()
    ctx.draw(panelImg, in: rect)
    return (ctx.makeImage()!, rect)
}

func writePNG(_ img: CGImage, to url: URL) {
    let data = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])!
    try! data.write(to: url)
}

func crop(_ img: CGImage, to rect: CGRect, margin: CGFloat, canvas: CGSize, scale: CGFloat) -> CGImage {
    let r = rect.insetBy(dx: -margin, dy: -margin).intersection(CGRect(origin: .zero, size: canvas))
    // CGImage.cropping is y-down in pixels.
    let px = CGRect(x: r.minX * scale, y: (canvas.height - r.maxY) * scale,
                    width: r.width * scale, height: r.height * scale)
    return img.cropping(to: px)!
}

// MARK: - Main

_ = NSApplication.shared
NSApp.setActivationPolicy(.prohibited)

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: PanelLook <outdir> [frame-index]\n".data(using: .utf8)!)
    exit(2)
}
let outDir = URL(fileURLWithPath: args[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let here = URL(fileURLWithPath: args[0]).deletingLastPathComponent()
let root = FileManager.default.fileExists(atPath: here.appendingPathComponent("frames").path)
    ? here : URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let framesDir = root.appendingPathComponent("frames")
let frameFiles = (try? FileManager.default.contentsOfDirectory(atPath: framesDir.path).sorted()) ?? []
let frameIndex = args.count > 2 ? (Int(args[2]) ?? 1) : 1
guard frameIndex < frameFiles.count,
      let text = try? String(contentsOf: framesDir.appendingPathComponent(frameFiles[frameIndex]), encoding: .utf8)
else { FileHandle.standardError.write("no frame \(frameIndex) in \(framesDir.path)\n".data(using: .utf8)!); exit(1) }

let canvas = CGSize(width: 1920, height: 1080)
let scale: CGFloat = 2
let grid = parseFrame(text)
let backdrop = renderBackdrop(grid: grid, canvas: canvas, scale: scale)
writePNG(backdrop, to: outDir.appendingPathComponent("00-bare.png"))

var tiles: [(Candidate, CGImage, CGRect)] = []
for c in candidates {
    let (img, rect) = composite(backdrop: backdrop, candidate: c, canvas: canvas, scale: scale)
    writePNG(img, to: outDir.appendingPathComponent("\(c.key)-full.png"))
    writePNG(crop(img, to: rect, margin: 28, canvas: canvas, scale: scale),
             to: outDir.appendingPathComponent("\(c.key)-crop.png"))
    tiles.append((c, img, rect))
    let cells = (rect.width / 10) * (rect.height / 19) / (190 * 56) * 100
    print(String(format: "%-20@ panel %4.0f x %3.0f pt  covers %4.1f%% of the grid", c.key as NSString, rect.width, rect.height, cells))
}

// Contact sheet: 2x2 at 1x, each tile labelled.
let tileW = canvas.width, tileH = canvas.height, labelH: CGFloat = 44
let sheetRows = CGFloat((tiles.count + 1) / 2)
let sheet = CGContext(data: nil, width: Int(tileW * 2), height: Int((tileH + labelH) * sheetRows), bitsPerComponent: 8,
                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!
sheet.setFillColor(NSColor(white: 0.16, alpha: 1).cgColor)
sheet.fill(CGRect(x: 0, y: 0, width: tileW * 2, height: (tileH + labelH) * sheetRows))
sheet.interpolationQuality = .high
for (i, (c, img, _)) in tiles.enumerated() {
    let col = CGFloat(i % 2), row = CGFloat(i / 2)
    let x = col * tileW
    let y = (tileH + labelH) * (sheetRows - 1 - row)
    sheet.draw(img, in: CGRect(x: x, y: y, width: tileW, height: tileH))
    let label = NSAttributedString(string: "\(c.title)   —   \(c.summary)", attributes: [
        .font: NSFont.systemFont(ofSize: 22, weight: .medium), .foregroundColor: NSColor.systemYellow])
    sheet.textPosition = CGPoint(x: x + 16, y: y + tileH + 13)
    CTLineDraw(CTLineCreateWithAttributedString(label), sheet)
}
writePNG(sheet.makeImage()!, to: outDir.appendingPathComponent("contact-sheet.png"))
print("wrote \(tiles.count * 2 + 2) png(s) to \(outDir.path)")
