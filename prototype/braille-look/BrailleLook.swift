// PROTOTYPE — throwaway. Answers ticket #8: "How should braille look?"
//
// Renders real captured tslime frames side by side through the candidate
// braille treatments from ticket #4, at the saver's real metrics (16 pt,
// 2x backing), so the look can be judged by eye.
//
// It is NOT the screensaver and NOT a terminal: no pty, no parser, no Metal.
// It mirrors only the parts of SwiftTerm 1.20 that decide how a cell looks:
//   - cell size from the primary font (ascent+descent+leading, "W" advance,
//     snapped to the pixel grid) — AppleTerminalView.computeFontDimensions
//   - U+2580..U+259F drawn as rects, shades at alpha .25/.5/.75 — BlockElementRenderer
//   - glyphs placed per column (Metal path) or by CoreText run advances (the
//     thing that makes today's Apple Symbols braille overrun its cell)
//
// Keys: arrows pan (shift = fast) · 1..6 toggle variants · z zoom · f next frame

import AppKit
import CoreText

// MARK: - Frame data

struct Cell {
    var scalar: Unicode.Scalar
    var fg: NSColor?
}

let defaultFG = NSColor(calibratedRed: 0.85, green: 0.85, blue: 0.85, alpha: 1)

/// Parses `tmux capture-pane -e` output: text plus SGR colour escapes.
func parseFrame(_ text: String) -> [[Cell]] {
    var rows: [[Cell]] = []
    for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
        var cells: [Cell] = []
        var fg: NSColor? = nil
        var it = Array(line.unicodeScalars)
        var i = 0
        while i < it.count {
            let s = it[i]
            if s == "\u{1b}", i + 1 < it.count, it[i + 1] == "[" {
                var j = i + 2
                var params = ""
                while j < it.count, it[j] != "m", it[j] != "\u{1b}" {
                    params.unicodeScalars.append(it[j]); j += 1
                }
                if j < it.count, it[j] == "m" {
                    let p = params.split(separator: ";").map { Int($0) ?? 0 }
                    if p.isEmpty || p == [0] || p == [39] {
                        fg = nil
                    } else if p.count >= 5, p[0] == 38, p[1] == 2 {
                        fg = NSColor(calibratedRed: CGFloat(p[2]) / 255,
                                     green: CGFloat(p[3]) / 255,
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

// MARK: - Block elements (mirrors SwiftTerm's BlockElementRenderer)

struct BlockRect { let x0, x1, y0, y1: CGFloat; let alpha: CGFloat }

func blockRects(for cp: UInt32) -> [BlockRect]? {
    func upper(_ n: CGFloat) -> [BlockRect] { [BlockRect(x0: 0, x1: 8, y0: 0, y1: n, alpha: 1)] }
    func lower(_ n: CGFloat) -> [BlockRect] { [BlockRect(x0: 0, x1: 8, y0: 8 - n, y1: 8, alpha: 1)] }
    func left(_ n: CGFloat) -> [BlockRect] { [BlockRect(x0: 0, x1: n, y0: 0, y1: 8, alpha: 1)] }
    func right(_ n: CGFloat) -> [BlockRect] { [BlockRect(x0: 8 - n, x1: 8, y0: 0, y1: 8, alpha: 1)] }
    let ul = BlockRect(x0: 0, x1: 4, y0: 0, y1: 4, alpha: 1)
    let ur = BlockRect(x0: 4, x1: 8, y0: 0, y1: 4, alpha: 1)
    let ll = BlockRect(x0: 0, x1: 4, y0: 4, y1: 8, alpha: 1)
    let lr = BlockRect(x0: 4, x1: 8, y0: 4, y1: 8, alpha: 1)
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

// MARK: - Variants

enum Treatment {
    case font(CTFont)      // braille comes from this face (or its CoreText fallback)
    case procedural        // braille dots drawn by us
}

struct Variant {
    let id: Int
    let title: String
    let treatment: Treatment
    /// Font the cell grid is sized from, and that non-braille text uses.
    let metricFont: CTFont
    var enabled: Bool
}

enum DotShape: Int { case round, square, rounded }

struct DotParams {
    var shape: DotShape = .round
    var sizePct: CGFloat = 0.78   // of the dot pitch
    var stretch = false            // size per axis instead of min(pitch)
    // Inset 0 is the only value that tiles perfectly: cross-cell dot spacing
    // is (0.5 + inset) cell widths against an intra-cell pitch of (0.5 - inset),
    // so any inset > 0 bands the lattice at the cell boundary.
    var insetX: CGFloat = 0
    var insetY: CGFloat = 0
}

enum Placement: Int { case perCell, naturalRun }

struct Options {
    var placement: Placement = .perCell
    var clipToCell = false
    var shadesFromFont = false     // off = SwiftTerm's alpha rects
    var dots = DotParams()
}

// MARK: - Metrics (mirrors AppleTerminalView.computeFontDimensions)

struct Metrics {
    let width: CGFloat
    let height: CGFloat
    let ascent: CGFloat
}

func metrics(for font: CTFont, scale: CGFloat) -> Metrics {
    let asc = CTFontGetAscent(font), desc = CTFontGetDescent(font), lead = CTFontGetLeading(font)
    let h = ceil((asc + desc + lead) * scale) / scale
    var glyph = CTFontGetGlyphWithName(font, "W" as CFString)
    if glyph == 0 {
        var ch: UniChar = 87
        CTFontGetGlyphsForCharacters(font, &ch, &glyph, 1)
    }
    var adv = CGSize.zero
    CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &adv, 1)
    let w = (adv.width * scale).rounded() / scale
    return Metrics(width: max(1, w), height: max(1, h), ascent: asc)
}

/// Advance of a braille cell in whatever face actually supplies the glyph —
/// the number that makes today's rendering overrun (Apple Symbols 68.4 vs ~60).
func brailleAdvance(for font: CTFont) -> (CGFloat, String) {
    var ch: UniChar = 0x28FF
    var glyph: CGGlyph = 0
    if CTFontGetGlyphsForCharacters(font, &ch, &glyph, 1), glyph != 0 {
        var adv = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &adv, 1)
        return (adv.width, String(CTFontCopyPostScriptName(font)))
    }
    // Ask CoreText which face it would fall back to.
    let fallback = CTFontCreateForString(font, "\u{28FF}" as CFString, CFRange(location: 0, length: 1))
    var g2: CGGlyph = 0
    CTFontGetGlyphsForCharacters(fallback, &ch, &g2, 1)
    var adv = CGSize.zero
    CTFontGetAdvancesForGlyphs(fallback, .horizontal, &g2, &adv, 1)
    return (adv.width, String(CTFontCopyPostScriptName(fallback)) + " (fallback)")
}

// MARK: - Grid rendering

func drawBrailleDots(_ cp: UInt32, in cell: CGRect, ctx: CGContext, p: DotParams) {
    let bits = cp - 0x2800
    let insetW = cell.width * p.insetX, insetH = cell.height * p.insetY
    let usableW = cell.width - 2 * insetW, usableH = cell.height - 2 * insetH
    let pitchX = usableW / 2, pitchY = usableH / 4
    let dw = p.stretch ? pitchX * p.sizePct : min(pitchX, pitchY) * p.sizePct
    let dh = p.stretch ? pitchY * p.sizePct : min(pitchX, pitchY) * p.sizePct
    // bit -> (col, row) within the 2x4 dot grid
    let layout: [(Int, Int)] = [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (0, 3), (1, 3)]
    for bit in 0..<8 where bits & (1 << UInt32(bit)) != 0 {
        let (c, r) = layout[bit]
        let cx = cell.minX + insetW + (CGFloat(c) + 0.5) * pitchX
        let cy = cell.minY + insetH + (CGFloat(3 - r) + 0.5) * pitchY  // row 0 is the top
        let rect = CGRect(x: cx - dw / 2, y: cy - dh / 2, width: dw, height: dh)
        switch p.shape {
        case .round: ctx.fillEllipse(in: rect)
        case .square: ctx.fill(rect)
        case .rounded:
            let path = CGPath(roundedRect: rect, cornerWidth: dw * 0.3, cornerHeight: dh * 0.3, transform: nil)
            ctx.addPath(path); ctx.fillPath()
        }
    }
}

func renderGrid(ctx: CGContext, grid: [[Cell]], originCol: Int, originRow: Int,
                cols: Int, rows: Int, variant: Variant, m: Metrics, opts: Options) {
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(cols) * m.width, height: CGFloat(rows) * m.height))
    ctx.setShouldAntialias(true)
    ctx.setShouldSmoothFonts(true)

    let textFont: CTFont = {
        if case .font(let f) = variant.treatment { return f }
        return variant.metricFont
    }()

    for r in 0..<rows {
        let gr = originRow + r
        guard gr >= 0, gr < grid.count else { continue }
        let line = grid[gr]
        let cellTop = CGFloat(rows - 1 - r) * m.height   // CG origin is bottom-left
        let baseline = cellTop + m.height - m.ascent

        var pendingRun: [(Unicode.Scalar, Int)] = []     // for natural-advance mode
        var pendingColor: NSColor = defaultFG
        var pendingStartCol = 0

        func flushRun() {
            guard !pendingRun.isEmpty else { pendingRun = []; return }
            let str = String(String.UnicodeScalarView(pendingRun.map { $0.0 }))
            let attr = NSAttributedString(string: str, attributes: [
                .font: textFont, .foregroundColor: pendingColor,
            ])
            let l = CTLineCreateWithAttributedString(attr)
            ctx.textPosition = CGPoint(x: CGFloat(pendingStartCol) * m.width, y: baseline)
            CTLineDraw(l, ctx)
            pendingRun = []
        }

        for c in 0..<cols {
            let gc = originCol + c
            guard gc >= 0, gc < line.count else { continue }
            let cell = line[gc]
            let cp = cell.scalar.value
            if cell.scalar == " " { if opts.placement == .naturalRun { flushRun() }; continue }
            let color = cell.fg ?? defaultFG
            let rect = CGRect(x: CGFloat(c) * m.width, y: cellTop, width: m.width, height: m.height)

            // Blocks and shades: SwiftTerm draws these itself, in every variant.
            if !opts.shadesFromFont, let rects = blockRects(for: cp) {
                if opts.placement == .naturalRun { flushRun() }
                let xe = m.width / 8, ye = m.height / 8
                for br in rects {
                    ctx.setFillColor(color.withAlphaComponent(br.alpha).cgColor)
                    ctx.fill(CGRect(x: rect.minX + br.x0 * xe,
                                    y: rect.minY + m.height - br.y1 * ye,
                                    width: (br.x1 - br.x0) * xe,
                                    height: (br.y1 - br.y0) * ye))
                }
                continue
            }

            // Procedural braille.
            if case .procedural = variant.treatment, (0x2800...0x28FF).contains(cp) {
                ctx.setFillColor(color.cgColor)
                drawBrailleDots(cp, in: rect, ctx: ctx, p: opts.dots)
                continue
            }

            switch opts.placement {
            case .naturalRun:
                if pendingRun.isEmpty { pendingStartCol = c; pendingColor = color }
                else if pendingColor != color { flushRun(); pendingStartCol = c; pendingColor = color }
                pendingRun.append((cell.scalar, c))
            case .perCell:
                let attr = NSAttributedString(string: String(Character(cell.scalar)), attributes: [
                    .font: textFont, .foregroundColor: color,
                ])
                let l = CTLineCreateWithAttributedString(attr)
                ctx.saveGState()
                if opts.clipToCell { ctx.clip(to: rect) }
                ctx.textPosition = CGPoint(x: rect.minX, y: baseline)
                CTLineDraw(l, ctx)
                ctx.restoreGState()
            }
        }
        flushRun()
    }
}

// MARK: - Pane

final class PaneView: NSView {
    var variant: Variant!
    var grid: [[Cell]] = []
    var originCol = 0, originRow = 0
    var cols = 0, rows = 0
    var zoom: CGFloat = 1
    var opts = Options()

    override var isFlipped: Bool { true }

    var metricsForVariant: Metrics { metrics(for: variant.metricFont, scale: 2) }

    override func draw(_ dirty: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let m = metricsForVariant
        let scale: CGFloat = 2
        let pxW = Int((CGFloat(cols) * m.width * scale).rounded())
        let pxH = Int((CGFloat(rows) * m.height * scale).rounded())
        guard pxW > 0, pxH > 0,
              let off = CGContext(data: nil, width: pxW, height: pxH, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        else { return }
        off.scaleBy(x: scale, y: scale)
        renderGrid(ctx: off, grid: grid, originCol: originCol, originRow: originRow,
                   cols: cols, rows: rows, variant: variant, m: m, opts: opts)
        guard let img = off.makeImage() else { return }

        ctx.saveGState()
        ctx.interpolationQuality = .none            // loupe shows real pixels
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        let drawW = CGFloat(pxW) / scale * zoom, drawH = CGFloat(pxH) / scale * zoom
        ctx.draw(img, in: CGRect(x: 0, y: bounds.height - drawH, width: drawW, height: drawH))
        ctx.restoreGState()
    }
}

// MARK: - Window

final class MainVC: NSViewController {
    var variants: [Variant] = []
    var frames: [(name: String, grid: [[Cell]])] = []
    var frameIndex = 0
    var originCol = 30, originRow = 18
    var zoom: CGFloat = 1
    var opts = Options()
    var cropRows = 9

    private var panesStack = NSStackView()
    private var paneViews: [PaneView] = []
    private var readout = NSTextField(labelWithString: "")

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1400, height: 900))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(white: 0.08, alpha: 1).cgColor

        panesStack.orientation = .vertical
        panesStack.alignment = .leading
        panesStack.spacing = 6
        panesStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panesStack)

        let controls = buildControls()
        controls.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controls)

        NSLayoutConstraint.activate([
            panesStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            panesStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            panesStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -8),
            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            controls.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            controls.topAnchor.constraint(greaterThanOrEqualTo: panesStack.bottomAnchor, constant: 8),
        ])
        rebuildPanes()
    }

    // MARK: controls

    private func label(_ s: String) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.font = .systemFont(ofSize: 11)
        l.textColor = .secondaryLabelColor
        return l
    }

    private func buildControls() -> NSView {
        let framePopup = NSPopUpButton()
        framePopup.addItems(withTitles: frames.map { $0.name })
        framePopup.target = self; framePopup.action = #selector(frameChanged(_:))

        let zoomPopup = NSPopUpButton()
        zoomPopup.addItems(withTitles: ["1x true size", "3x loupe", "6x loupe"])
        zoomPopup.target = self; zoomPopup.action = #selector(zoomChanged(_:))

        let placement = NSPopUpButton()
        placement.addItems(withTitles: ["per-cell (Metal path)", "natural run advance"])
        placement.target = self; placement.action = #selector(placementChanged(_:))

        let clip = NSButton(checkboxWithTitle: "clip to cell", target: self, action: #selector(clipChanged(_:)))
        let shades = NSButton(checkboxWithTitle: "shades from font", target: self, action: #selector(shadesChanged(_:)))

        let shape = NSPopUpButton()
        shape.addItems(withTitles: ["round", "square", "rounded"])
        shape.target = self; shape.action = #selector(shapeChanged(_:))

        let size = NSSlider(value: 78, minValue: 30, maxValue: 115, target: self, action: #selector(sizeChanged(_:)))
        size.widthAnchor.constraint(equalToConstant: 110).isActive = true
        let stretch = NSButton(checkboxWithTitle: "fill pitch", target: self, action: #selector(stretchChanged(_:)))
        let insetX = NSSlider(value: 0, minValue: 0, maxValue: 25, target: self, action: #selector(insetXChanged(_:)))
        insetX.widthAnchor.constraint(equalToConstant: 80).isActive = true
        let insetY = NSSlider(value: 0, minValue: 0, maxValue: 25, target: self, action: #selector(insetYChanged(_:)))
        insetY.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let rowA = NSStackView(views: [label("frame"), framePopup, label("zoom"), zoomPopup,
                                       label("placement"), placement, clip, shades])
        rowA.spacing = 8
        let rowB = NSStackView(views: [label("dots: shape"), shape, label("size"), size, stretch,
                                       label("inset x"), insetX, label("y"), insetY])
        rowB.spacing = 8

        readout.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        readout.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [rowA, rowB, readout])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        return stack
    }

    @objc private func frameChanged(_ s: NSPopUpButton) { frameIndex = s.indexOfSelectedItem; refresh() }
    @objc private func zoomChanged(_ s: NSPopUpButton) {
        zoom = [1, 3, 6][s.indexOfSelectedItem]; rebuildPanes()
    }
    @objc private func placementChanged(_ s: NSPopUpButton) {
        opts.placement = Placement(rawValue: s.indexOfSelectedItem)!; refresh()
    }
    @objc private func clipChanged(_ s: NSButton) { opts.clipToCell = s.state == .on; refresh() }
    @objc private func shadesChanged(_ s: NSButton) { opts.shadesFromFont = s.state == .on; refresh() }
    @objc private func shapeChanged(_ s: NSPopUpButton) {
        opts.dots.shape = DotShape(rawValue: s.indexOfSelectedItem)!; refresh()
    }
    @objc private func sizeChanged(_ s: NSSlider) { opts.dots.sizePct = CGFloat(s.doubleValue) / 100; refresh() }
    @objc private func stretchChanged(_ s: NSButton) { opts.dots.stretch = s.state == .on; refresh() }
    @objc private func insetXChanged(_ s: NSSlider) { opts.dots.insetX = CGFloat(s.doubleValue) / 100; refresh() }
    @objc private func insetYChanged(_ s: NSSlider) { opts.dots.insetY = CGFloat(s.doubleValue) / 100; refresh() }

    // MARK: panes

    func rebuildPanes() {
        panesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        paneViews.removeAll()
        let grid = frames[frameIndex].grid
        let availableW = max(600, view.bounds.width - 40)

        for v in variants where v.enabled {
            let m = metrics(for: v.metricFont, scale: 2)
            let cols = Int(availableW / zoom / m.width)
            let rows = zoom == 1 ? cropRows : max(3, Int(CGFloat(cropRows) / zoom * 1.6))
            let pane = PaneView()
            pane.variant = v; pane.grid = grid; pane.cols = cols; pane.rows = rows
            pane.originCol = originCol; pane.originRow = originRow
            pane.zoom = zoom; pane.opts = opts
            pane.translatesAutoresizingMaskIntoConstraints = false
            pane.widthAnchor.constraint(equalToConstant: CGFloat(cols) * m.width * zoom).isActive = true
            pane.heightAnchor.constraint(equalToConstant: CGFloat(rows) * m.height * zoom).isActive = true

            let (adv, face) = brailleAdvance(for: v.metricFont)
            let title = NSTextField(labelWithString: String(
                format: "%d  %@   cell %.2f x %.2f pt   braille adv %.2f  [%@]",
                v.id, v.title, m.width, m.height, adv, face))
            title.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
            title.textColor = abs(adv - m.width) > 0.5 ? .systemOrange : .secondaryLabelColor

            let box = NSStackView(views: [title, pane])
            box.orientation = .vertical
            box.alignment = .leading
            box.spacing = 1
            panesStack.addArrangedSubview(box)
            paneViews.append(pane)
        }
        refresh()
    }

    func refresh() {
        let grid = frames[frameIndex].grid
        for p in paneViews {
            p.grid = grid; p.originCol = originCol; p.originRow = originRow; p.opts = opts
            p.needsDisplay = true
        }
        readout.stringValue = String(
            format: "origin col %d row %d   dots: %@ size %.0f%% %@ inset %.0f%%/%.0f%%   [1-6] variants  [arrows] pan  [z] zoom  [f] frame",
            originCol, originRow,
            ["round", "square", "rounded"][opts.dots.shape.rawValue],
            opts.dots.sizePct * 100, opts.dots.stretch ? "fill-pitch" : "uniform",
            opts.dots.insetX * 100, opts.dots.insetY * 100)
    }

    // MARK: keys

    override func keyDown(with event: NSEvent) {
        let fast = event.modifierFlags.contains(.shift) ? 8 : 1
        switch event.keyCode {
        case 123: originCol = max(0, originCol - fast)
        case 124: originCol += fast
        case 126: originRow = max(0, originRow - fast)
        case 125: originRow += fast
        default:
            guard let ch = event.charactersIgnoringModifiers?.first else { return }
            switch ch {
            case "1"..."6":
                let n = Int(String(ch))!
                if let idx = variants.firstIndex(where: { $0.id == n }) {
                    variants[idx].enabled.toggle(); rebuildPanes()
                }
                return
            case "z":
                zoom = zoom == 1 ? 3 : (zoom == 3 ? 6 : 1); rebuildPanes(); return
            case "f":
                frameIndex = (frameIndex + 1) % frames.count; rebuildPanes(); return
            default: return
            }
        }
        refresh()
    }

    override var acceptsFirstResponder: Bool { true }
}

// MARK: - Boot

func registerFont(_ path: String) -> CTFont? {
    let url = URL(fileURLWithPath: path) as CFURL
    CTFontManagerRegisterFontsForURL(url, .process, nil)
    guard let descs = CTFontManagerCreateFontDescriptorsFromURL(url) as? [CTFontDescriptor],
          let first = descs.first else { return nil }
    return CTFontCreateWithFontDescriptor(first, 16, nil)
}

let here = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let root = FileManager.default.fileExists(atPath: here.appendingPathComponent("fonts").path)
    ? here
    : URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

let sfMono = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular) as CTFont
func f(_ name: String) -> CTFont? { registerFont(root.appendingPathComponent("fonts/\(name)").path) }

var variants: [Variant] = [
    Variant(id: 1, title: "today: SF Mono + Apple Symbols fallback",
            treatment: .font(sfMono), metricFont: sfMono, enabled: true),
]
if let jm = f("JuliaMono-Regular.ttf") {
    variants.append(Variant(id: 2, title: "JuliaMono Regular", treatment: .font(jm), metricFont: jm, enabled: true))
}
if let jb = f("JuliaMono-Bold.ttf") {
    variants.append(Variant(id: 3, title: "JuliaMono Bold", treatment: .font(jb), metricFont: jb, enabled: false))
}
if let dv = f("DejaVuSansMNerdFontMono-Regular.ttf") {
    variants.append(Variant(id: 4, title: "DejaVuSansM Nerd Font Mono", treatment: .font(dv), metricFont: dv, enabled: true))
}
if let jbm = f("JetBrainsMonoNerdFontMono-Regular.ttf") {
    variants.append(Variant(id: 5, title: "JetBrainsMono Nerd Font Mono", treatment: .font(jbm), metricFont: jbm, enabled: false))
}
variants.append(Variant(id: 6, title: "procedural dots (renderer-drawn, SF Mono metrics)",
                        treatment: .procedural, metricFont: sfMono, enabled: true))

let framesDir = root.appendingPathComponent("frames")
let frameFiles = (try? FileManager.default.contentsOfDirectory(atPath: framesDir.path).sorted()) ?? []
var frames: [(name: String, grid: [[Cell]])] = frameFiles.compactMap { name in
    guard let text = try? String(contentsOf: framesDir.appendingPathComponent(name), encoding: .utf8)
    else { return nil }
    return (name, parseFrame(text))
}
if frames.isEmpty {
    FileHandle.standardError.write("no frames in \(framesDir.path)\n".data(using: .utf8)!)
    exit(1)
}

// Headless: `--png <dir> [frame] [col] [row] [cols] [rows] [zoom]` writes one
// PNG per variant, plus a stacked contact sheet, for pasting into the ticket.
if CommandLine.arguments.count > 2, CommandLine.arguments[1] == "--png" {
    let outDir = URL(fileURLWithPath: CommandLine.arguments[2])
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    func arg(_ i: Int, _ d: Int) -> Int {
        CommandLine.arguments.count > i ? Int(CommandLine.arguments[i]) ?? d : d
    }
    let fi = arg(3, 1), oc = arg(4, 30), orow = arg(5, 18)
    let cols = arg(6, 60), rows = arg(7, 10), zoom = CGFloat(arg(8, 1))
    let opts = Options()
    var images: [(String, CGImage)] = []
    for v in variants {
        let m = metrics(for: v.metricFont, scale: 2)
        let pxW = Int((CGFloat(cols) * m.width * 2).rounded())
        let pxH = Int((CGFloat(rows) * m.height * 2).rounded())
        guard let off = CGContext(data: nil, width: pxW, height: pxH, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        else { continue }
        off.scaleBy(x: 2, y: 2)
        renderGrid(ctx: off, grid: frames[min(fi, frames.count - 1)].grid,
                   originCol: oc, originRow: orow, cols: cols, rows: rows,
                   variant: v, m: m, opts: opts)
        guard var img = off.makeImage() else { continue }
        if zoom > 1, let big = CGContext(data: nil, width: Int(CGFloat(pxW) * zoom),
                                         height: Int(CGFloat(pxH) * zoom), bitsPerComponent: 8,
                                         bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) {
            big.interpolationQuality = .none
            big.draw(img, in: CGRect(x: 0, y: 0, width: CGFloat(pxW) * zoom, height: CGFloat(pxH) * zoom))
            if let z = big.makeImage() { img = z }
        }
        let name = "v\(v.id)-" + v.title.split(separator: " ").prefix(2).joined(separator: "-")
            .replacingOccurrences(of: ":", with: "")
        images.append((name, img))
        let rep = NSBitmapImageRep(cgImage: img)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: outDir.appendingPathComponent("\(name).png"))
        }
    }
    // Contact sheet: every variant stacked, each with its label.
    let labelH: CGFloat = 22 * zoom
    let sheetW = images.map { CGFloat($0.1.width) }.max() ?? 0
    let sheetH = images.reduce(0) { $0 + CGFloat($1.1.height) + labelH }
    if let sheet = CGContext(data: nil, width: Int(sheetW), height: Int(sheetH), bitsPerComponent: 8,
                             bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                             bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) {
        sheet.setFillColor(NSColor.black.cgColor)
        sheet.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))
        var y = sheetH
        for (i, (_, img)) in images.enumerated() {
            y -= labelH
            let v = variants[i]
            let (adv, face) = brailleAdvance(for: v.metricFont)
            let text = NSAttributedString(string: "\(v.id)  \(v.title)  ·  braille advance \(String(format: "%.1f", adv)) vs cell \(String(format: "%.1f", metrics(for: v.metricFont, scale: 2).width))  ·  \(face)", attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 11 * zoom, weight: .medium),
                .foregroundColor: NSColor.systemYellow,
            ])
            sheet.textPosition = CGPoint(x: 6, y: y + 6)
            CTLineDraw(CTLineCreateWithAttributedString(text), sheet)
            y -= CGFloat(img.height)
            sheet.draw(img, in: CGRect(x: 0, y: y, width: CGFloat(img.width), height: CGFloat(img.height)))
        }
        if let img = sheet.makeImage(),
           let data = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:]) {
            try? data.write(to: outDir.appendingPathComponent("contact-sheet.png"))
        }
    }
    print("wrote \(images.count + 1) png(s) to \(outDir.path)")
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let vc = MainVC()
vc.variants = variants
vc.frames = frames
let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1400, height: 900),
                   styleMask: [.titled, .closable, .resizable],
                   backing: .buffered, defer: false)
win.title = "PROTOTYPE — how should braille look? (#8)"
win.contentViewController = vc
win.center()
win.makeKeyAndOrderFront(nil)
win.makeFirstResponder(vc)
app.activate(ignoringOtherApps: true)
app.run()
