// PROTOTYPE: real ANSI cells rendered with the established theme renderer.
// Source: prototype/themes/ThemeLook.swift, adapted for thumbnail sizes.
import AppKit
import CoreText

// MARK: - Candidates

struct Candidate {
    let id, name, palette, inner, outer, accent, idea: String
    var chosen = true
    var frame = "glow"
    var matteCols = 4
    var matteRows = 1
    var flags: String {
        var f = "--window-frame \(frame) --frame-matte-cols \(matteCols) --frame-matte-rows \(matteRows) --palette \(palette)"
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
        if f.count > 8 { c.frame = f[8] }
        if f.count > 10 { c.matteCols = Int(f[9]) ?? 4; c.matteRows = Int(f[10]) ?? 1 }
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

// ANSI truecolor and palette hex values are sRGB. Generic calibrated RGB
// changes the saved colors when the sRGB bitmap context converts them.
func rgb(_ p: [Int], _ i: Int) -> NSColor {
    NSColor(srgbRed: CGFloat(p[i]) / 255, green: CGFloat(p[i + 1]) / 255, blue: CGFloat(p[i + 2]) / 255, alpha: 1)
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

// MARK: - The five treatments (all PNGs are 2x for a 190 x 100 pt slot)

func bitmap(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
func writePNG(_ image: CGImage, _ path: String) {
    try! NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: path))
}
func thumbnail(_ image: CGImage, crop: Bool = false) -> CGImage {
    let ctx = bitmap(380, 200)
    ctx.interpolationQuality = .high
    var source = image
    if crop {
        // Central 64-column region, retaining the slot aspect. Fixed camera:
        // no search for whichever region makes an individual frame look best.
        let w = CGFloat(64) * m.width * scale
        let h = w * 100 / 190
        source = image.cropping(to: CGRect(x: (CGFloat(image.width) - w) / 2,
                                          y: (CGFloat(image.height) - h) / 2, width: w, height: h))!
    }
    ctx.draw(source, in: CGRect(x: 0, y: 0, width: 380, height: 200))
    return ctx.makeImage()!
}
func text(_ ctx: CGContext, _ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, muted: Bool = false) {
    let color = NSColor(srgbRed: muted ? 0.70 : 0.94, green: muted ? 0.72 : 0.95,
                        blue: muted ? 0.75 : 0.96, alpha: 1)
    let a = NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size), .foregroundColor: color])
    ctx.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(CTLineCreateWithAttributedString(a), ctx)
}

let themes = ["S2", "N1"]
let names = ["Studio · simple border", "Nocturne · glow border"]
let stages = ["young", "network", "mature"]
let treatments = ["A · Current", "B · Live, 96 × 28", "C · Live, 64 × 20", "D · Centre crop", "E · Curated still"]
var images: [String: CGImage] = [:]
try! FileManager.default.createDirectory(atPath: "shots", withIntermediateDirectories: true)
for theme in themes {
    for stage in stages {
        var frames: [Int: CGImage] = [:]
        for (cols, rows) in [(190,56), (96,28), (64,20)] {
            let data = try! String(contentsOfFile: "frames/\(theme)-\(cols)-\(stage).txt", encoding: .utf8)
            frames[cols] = renderFrame(parseFrame(data), cols: cols, rows: rows)
        }
        let sources = [thumbnail(frames[190]!), thumbnail(frames[96]!), thumbnail(frames[64]!), thumbnail(frames[190]!, crop: true)]
        for (i, image) in sources.enumerated() {
            let key = "\(theme)-\(stage)-\(i)"
            images[key] = image
            writePNG(image, "shots/\(key).png")
        }
    }
    // Stable composition: hold the captured 96x28 network frame at every age.
    let still = images["\(theme)-network-1"]!
    for stage in stages {
        let key = "\(theme)-\(stage)-4"
        images[key] = still
        writePNG(still, "shots/\(key).png")
    }
}

// 1x sheet makes each thumbnail exactly 190 px wide when displayed 1:1.
// The HTML viewer is the authority for physical on-screen size.
for stage in stages {
    let ctx = bitmap(1098, 444)
    ctx.setFillColor(NSColor(srgbRed: 0.12, green: 0.13, blue: 0.15, alpha: 1).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: 1098, height: 444))
    text(ctx, "Oozel thumbnail study", 28, 407, 24)
    text(ctx, "Real tslime frames · 190 × 100 pt target · \(stage) stage · still held at 8 s", 28, 381, 13, muted: true)
    for (row, theme) in themes.enumerated() {
        let top = CGFloat(347 - row * 161)
        text(ctx, names[row], 28, top, 15)
        for i in 0..<5 {
            let x = CGFloat(28 + i * 212)
            text(ctx, treatments[i], x, top - 23, 12, muted: true)
            ctx.interpolationQuality = .high
            ctx.draw(images["\(theme)-\(stage)-\(i)"]!, in: CGRect(x: x, y: top - 133, width: 190, height: 100))
        }
    }
    writePNG(ctx.makeImage()!, "shots/comparison-\(stage).png")
}
print("Rendered 30 thumbnail PNGs and 3 comparison sheets; cell \(m.width) × \(m.height) pt")
