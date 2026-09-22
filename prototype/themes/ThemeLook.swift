// PROTOTYPE — throwaway. Answers ticket #39: "Which themes ship?"
//
// Renders real captured tslime frames (tmux capture-pane -e, one per theme
// candidate) at the saver's metrics — SF Mono 16 pt, 2x backing, SwiftTerm's
// cell rule, the fork's procedural braille dots at the saved settings, block
// elements as rects — into one PNG per candidate plus two contact sheets:
//   shots/<round>/contact-sheet.png   every candidate, whole frame, scaled down
//   shots/<round>/crop-sheet.png      every candidate, top-left of the window, real pixels
//
// It is NOT the screensaver and NOT a terminal. Colour decisions only.
// usage: ThemeLook round-1.tsv [stage]   (stage: frames/<round>-<stage> -> shots/<round>-<stage>)

import AppKit
import CoreText

// MARK: - Candidates

struct Candidate {
    let id, name, palette, inner, outer, accent, idea: String
    var chosen = true
    var flags: String {
        var f = "--palette \(palette)"
        if inner != "-" { f += " --bg-color-inner \(inner)" }
        if outer != "-" { f += " --bg-color-outer \(outer)" }
        if accent != "-" { f += " --accent-color \(accent)" }
        return f
    }
}

func loadCandidates(_ path: String) -> [Candidate] {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { fatalError("no list at \(path)") }
    return text.split(separator: "\n").filter { !$0.hasPrefix("#") && !$0.isEmpty }.compactMap { line in
        let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        guard f.count >= 6 else { return nil }
        var c = Candidate(id: f[0], name: f[1], palette: f[2], inner: f[3], outer: f[4], accent: f[5],
                          idea: f.count > 6 ? f[6] : "")
        if f.count > 7 { c.chosen = f[7] == "1" }
        return c
    }
}

// MARK: - Frame data

struct Cell {
    var scalar: Unicode.Scalar
    var fg: NSColor?
    var bg: NSColor?
}

let defaultFG = NSColor(calibratedRed: 0.85, green: 0.85, blue: 0.85, alpha: 1)
let defaultBG = NSColor.black   // the terminal view's layer background in TerminalManager

func rgb(_ p: [Int], _ i: Int) -> NSColor {
    NSColor(calibratedRed: CGFloat(p[i]) / 255, green: CGFloat(p[i + 1]) / 255, blue: CGFloat(p[i + 2]) / 255, alpha: 1)
}

/// Parses `tmux capture-pane -e -N` output: text plus SGR colour escapes, fg
/// and bg. tmux emits an escape only when the pen changes and carries the pen
/// across lines, so the state lives outside the row loop.
func parseFrame(_ text: String) -> [[Cell]] {
    var rows: [[Cell]] = []
    var fg: NSColor? = nil, bg: NSColor? = nil
    for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
        var cells: [Cell] = []
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
                    var k = 0
                    if p.isEmpty { fg = nil; bg = nil }
                    while k < p.count {
                        switch p[k] {
                        case 0: fg = nil; bg = nil; k += 1
                        case 39: fg = nil; k += 1
                        case 49: bg = nil; k += 1
                        case 38 where k + 4 < p.count && p[k + 1] == 2: fg = rgb(p, k + 2); k += 5
                        case 48 where k + 4 < p.count && p[k + 1] == 2: bg = rgb(p, k + 2); k += 5
                        default: k += 1
                        }
                    }
                    i = j + 1
                    continue
                }
            }
            cells.append(Cell(scalar: s, fg: fg, bg: bg))
            i += 1
        }
        rows.append(cells)
    }
    return rows
}

// MARK: - Metrics (SwiftTerm's cell rule) and block elements

struct Metrics { let width, height, ascent: CGFloat }

func metrics(for font: CTFont, scale: CGFloat) -> Metrics {
    let asc = CTFontGetAscent(font), desc = CTFontGetDescent(font), lead = CTFontGetLeading(font)
    let h = ceil((asc + desc + lead) * scale) / scale
    var glyph = CTFontGetGlyphWithName(font, "W" as CFString)
    if glyph == 0 { var ch: UniChar = 87; CTFontGetGlyphsForCharacters(font, &ch, &glyph, 1) }
    var adv = CGSize.zero
    CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &adv, 1)
    return Metrics(width: max(1, (adv.width * scale).rounded() / scale), height: max(1, h), ascent: asc)
}

struct BlockRect { let x0, x1, y0, y1: CGFloat; let alpha: CGFloat }

func blockRects(for cp: UInt32) -> [BlockRect]? {
    func upper(_ n: CGFloat) -> [BlockRect] { [BlockRect(x0: 0, x1: 8, y0: 0, y1: n, alpha: 1)] }
    func lower(_ n: CGFloat) -> [BlockRect] { [BlockRect(x0: 0, x1: 8, y0: 8 - n, y1: 8, alpha: 1)] }
    func left(_ n: CGFloat) -> [BlockRect] { [BlockRect(x0: 0, x1: n, y0: 0, y1: 8, alpha: 1)] }
    func right(_ n: CGFloat) -> [BlockRect] { [BlockRect(x0: 8 - n, x1: 8, y0: 0, y1: 8, alpha: 1)] }
    switch cp {
    case 0x2580: return upper(4)
    case 0x2581...0x2588: return lower(CGFloat(cp - 0x2580))
    case 0x2589...0x258F: return left(CGFloat(0x2590 - cp))
    case 0x2590: return right(4)
    case 0x2591: return [BlockRect(x0: 0, x1: 8, y0: 0, y1: 8, alpha: 0.25)]
    case 0x2592: return [BlockRect(x0: 0, x1: 8, y0: 0, y1: 8, alpha: 0.5)]
    case 0x2593: return [BlockRect(x0: 0, x1: 8, y0: 0, y1: 8, alpha: 0.75)]
    case 0x2594: return upper(1)
    case 0x2595: return right(1)
    case 0x2596: return [BlockRect(x0: 0, x1: 4, y0: 4, y1: 8, alpha: 1)]
    case 0x2597: return [BlockRect(x0: 4, x1: 8, y0: 4, y1: 8, alpha: 1)]
    case 0x2598: return [BlockRect(x0: 0, x1: 4, y0: 0, y1: 4, alpha: 1)]
    case 0x2599: return [BlockRect(x0: 0, x1: 4, y0: 0, y1: 8, alpha: 1), BlockRect(x0: 4, x1: 8, y0: 4, y1: 8, alpha: 1)]
    case 0x259A: return [BlockRect(x0: 0, x1: 4, y0: 0, y1: 4, alpha: 1), BlockRect(x0: 4, x1: 8, y0: 4, y1: 8, alpha: 1)]
    case 0x259B: return [BlockRect(x0: 0, x1: 8, y0: 0, y1: 4, alpha: 1), BlockRect(x0: 0, x1: 4, y0: 4, y1: 8, alpha: 1)]
    case 0x259C: return [BlockRect(x0: 0, x1: 8, y0: 0, y1: 4, alpha: 1), BlockRect(x0: 4, x1: 8, y0: 4, y1: 8, alpha: 1)]
    case 0x259D: return [BlockRect(x0: 4, x1: 8, y0: 0, y1: 4, alpha: 1)]
    case 0x259E: return [BlockRect(x0: 4, x1: 8, y0: 0, y1: 4, alpha: 1), BlockRect(x0: 0, x1: 4, y0: 4, y1: 8, alpha: 1)]
    case 0x259F: return [BlockRect(x0: 4, x1: 8, y0: 0, y1: 4, alpha: 1), BlockRect(x0: 0, x1: 8, y0: 4, y1: 8, alpha: 1)]
    default: return nil
    }
}

// The fork's BrailleRenderer at the saved settings on this Mac
// (brailleSource=procedural, dot size 0.6945 of pitch, corner 1.0 = round).
let dotSizeFraction: CGFloat = 0.6945354129662522
let cornerFraction: CGFloat = 1.0

func drawBrailleDots(_ cp: UInt32, in cell: CGRect, ctx: CGContext) {
    let bits = cp - 0x2800
    guard bits != 0 else { return }
    let pitchX = cell.width / 2, pitchY = cell.height / 4
    let dot = min(pitchX, pitchY) * dotSizeFraction
    let corner = dot * cornerFraction
    let layout: [(Int, Int)] = [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (0, 3), (1, 3)]
    for bit in 0..<8 where bits & (1 << UInt32(bit)) != 0 {
        let (c, r) = layout[bit]
        let cx = cell.minX + (CGFloat(c) + 0.5) * pitchX
        let cy = cell.minY + (CGFloat(3 - r) + 0.5) * pitchY
        ctx.addPath(CGPath(roundedRect: CGRect(x: cx - dot / 2, y: cy - dot / 2, width: dot, height: dot),
                           cornerWidth: corner, cornerHeight: corner, transform: nil))
    }
    ctx.fillPath()
}

// MARK: - Render one frame

let font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular) as CTFont
let scale: CGFloat = 2
let m = metrics(for: font, scale: scale)

func renderFrame(_ grid: [[Cell]], cols: Int, rows: Int) -> CGImage {
    let pxW = Int((CGFloat(cols) * m.width * scale).rounded()), pxH = Int((CGFloat(rows) * m.height * scale).rounded())
    let ctx = CGContext(data: nil, width: pxW, height: pxH, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    ctx.setShouldAntialias(true); ctx.setShouldSmoothFonts(true)
    ctx.setFillColor(defaultBG.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(cols) * m.width, height: CGFloat(rows) * m.height))
    for r in 0..<rows {
        guard r < grid.count else { continue }
        let line = grid[r]
        let cellTop = CGFloat(rows - 1 - r) * m.height
        let baseline = cellTop + m.height - m.ascent
        for c in 0..<cols {
            guard c < line.count else { continue }
            let cell = line[c]
            let rect = CGRect(x: CGFloat(c) * m.width, y: cellTop, width: m.width, height: m.height)
            if let bg = cell.bg { ctx.setFillColor(bg.cgColor); ctx.fill(rect) }
            if cell.scalar == " " { continue }
            let color = cell.fg ?? defaultFG
            let cp = cell.scalar.value
            if let rects = blockRects(for: cp) {
                let xe = m.width / 8, ye = m.height / 8
                for br in rects {
                    ctx.setFillColor(color.withAlphaComponent(br.alpha).cgColor)
                    ctx.fill(CGRect(x: rect.minX + br.x0 * xe, y: rect.minY + m.height - br.y1 * ye,
                                    width: (br.x1 - br.x0) * xe, height: (br.y1 - br.y0) * ye))
                }
                continue
            }
            if (0x2800...0x28FF).contains(cp) {
                ctx.setFillColor(color.cgColor)
                drawBrailleDots(cp, in: rect, ctx: ctx)
                continue
            }
            let attr = NSAttributedString(string: String(Character(cell.scalar)), attributes: [.font: font, .foregroundColor: color])
            ctx.saveGState(); ctx.clip(to: rect)
            ctx.textPosition = CGPoint(x: rect.minX, y: baseline)
            CTLineDraw(CTLineCreateWithAttributedString(attr), ctx)
            ctx.restoreGState()
        }
    }
    return ctx.makeImage()!
}

// MARK: - Sheets

func label(_ ctx: CGContext, _ text: String, at p: CGPoint, size: CGFloat, color: NSColor = .white) {
    let attr = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: color])
    ctx.textPosition = p
    CTLineDraw(CTLineCreateWithAttributedString(attr), ctx)
}

func sheet(tiles: [(CGImage, Candidate)], tileW: Int, tileH: Int, columns: Int, header: Int, gap: Int,
           interpolation: CGInterpolationQuality, crop: CGRect?, title: String) -> CGImage {
    let rowsN = (tiles.count + columns - 1) / columns
    let W = columns * (tileW + gap) + gap, H = rowsN * (tileH + header + gap) + gap + 60
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(NSColor(white: 0.16, alpha: 1).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    label(ctx, title, at: CGPoint(x: gap, y: H - 42), size: 28)
    ctx.interpolationQuality = interpolation
    for (i, (img, cand)) in tiles.enumerated() {
        let col = i % columns, row = i / columns
        let x = gap + col * (tileW + gap)
        let yTop = H - 60 - gap - row * (tileH + header + gap)
        let src = crop.map { img.cropping(to: $0)! } ?? img
        ctx.draw(src, in: CGRect(x: x, y: yTop - header - tileH, width: tileW, height: tileH))
        label(ctx, "\(cand.id)  \(cand.name)", at: CGPoint(x: CGFloat(x), y: CGFloat(yTop - 26)), size: 22)
        label(ctx, cand.flags, at: CGPoint(x: CGFloat(x), y: CGFloat(yTop - 50)), size: 15, color: NSColor(white: 0.8, alpha: 1))
        label(ctx, cand.idea, at: CGPoint(x: CGFloat(x), y: CGFloat(yTop - 72)), size: 15, color: NSColor(white: 0.65, alpha: 1))
    }
    return ctx.makeImage()!
}

func writePNG(_ img: CGImage, _ path: String) {
    let rep = NSBitmapImageRep(cgImage: img)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

// MARK: - Main

let listPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "round-1.tsv"
let stage = CommandLine.arguments.count > 2 ? "-" + CommandLine.arguments[2] : ""
let round = (listPath as NSString).lastPathComponent.replacingOccurrences(of: ".tsv", with: "") + stage
let root = URL(fileURLWithPath: listPath).deletingLastPathComponent()
let framesDir = root.appendingPathComponent("frames/\(round)")
let shotsDir = root.appendingPathComponent("shots/\(round)")
try? FileManager.default.createDirectory(at: shotsDir, withIntermediateDirectories: true)

let cols = 190, rows = 56
var tiles: [(CGImage, Candidate)] = []
for cand in loadCandidates(listPath) {
    let f = framesDir.appendingPathComponent("\(cand.id)-\(cand.name).txt")
    guard let text = try? String(contentsOf: f, encoding: .utf8) else { print("missing frame \(f.path)"); continue }
    let img = renderFrame(parseFrame(text), cols: cols, rows: rows)
    writePNG(img, shotsDir.appendingPathComponent("\(cand.id)-\(cand.name).png").path)
    writePNG(img.cropping(to: CGRect(x: Int(m.width * scale * 12), y: 0, width: 1100, height: 640))!,
             shotsDir.appendingPathComponent("\(cand.id)-\(cand.name)-crop.png").path)
    tiles.append((img, cand))
    print("\(cand.id) \(cand.name): \(img.width)x\(img.height)")
}
let fw = tiles.first!.0.width, fh = tiles.first!.0.height
let queue = tiles.filter { $0.1.chosen }
if queue.count < tiles.count {
    let q = sheet(tiles: queue, tileW: Int(Double(fw) * 0.35), tileH: Int(Double(fh) * 0.35), columns: 3, header: 80, gap: 30,
                  interpolation: .high, crop: nil, title: "\(round): the chosen candidates, whole frame")
    writePNG(q, shotsDir.appendingPathComponent("queue-sheet.png").path)
}
// Whole frames at 0.35 of the 2x backing, three across.
let s = sheet(tiles: tiles, tileW: Int(Double(fw) * 0.35), tileH: Int(Double(fh) * 0.35), columns: 3, header: 80, gap: 30,
              interpolation: .high, crop: nil, title: "\(round): whole frame, 190x56 at 0.35 of the 2x backing")
writePNG(s, shotsDir.appendingPathComponent("contact-sheet.png").path)
// Top-left of the window at real pixels: the outer zone, the ring, the badge and the first trails.
let cropW = 1100, cropH = 640
let cellPxW = m.width * scale, cellPxH = m.height * scale
let cropRect = CGRect(x: Int(cellPxW * 12), y: 0, width: cropW, height: cropH)
let c = sheet(tiles: tiles, tileW: cropW, tileH: cropH, columns: 3, header: 80, gap: 30,
              interpolation: .none, crop: cropRect, title: "\(round): top-left of the window, real 2x pixels")
writePNG(c, shotsDir.appendingPathComponent("crop-sheet.png").path)
// One sheet per candidate (tiles whose id shares a first letter), two across, for judging a tree on its own.
let groups = Dictionary(grouping: tiles, by: { String($0.1.id.prefix(1)) })
for (g, ts) in groups where ts.count > 1 {
    let gs = sheet(tiles: ts.sorted { $0.1.id < $1.1.id }, tileW: Int(Double(fw) * 0.42), tileH: Int(Double(fh) * 0.42), columns: 2, header: 80, gap: 30,
                   interpolation: .high, crop: nil, title: "\(round): candidate \(g)")
    writePNG(gs, shotsDir.appendingPathComponent("candidate-\(g).png").path)
}
print("wrote \(shotsDir.path)  cell \(m.width)x\(m.height) pt")
