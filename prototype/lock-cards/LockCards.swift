// PROTOTYPE ONLY — compares possible saver backing treatments behind an
// approximate, observed-position schematic of the macOS lock UI.
import AppKit
import CoreGraphics
import CoreText

let canvas = CGSize(width: 3840, height: 2160)
let pointScale: CGFloat = 2

// Observed screenshot geometry in 1920 × 1080 points. Adjust here if a later
// real lock-screen capture changes the measured bounds.
let clockCard = CGRect(x: 745, y: 86, width: 430, height: 192)
let authCard = CGRect(x: 840, y: 850, width: 240, height: 167)
let dateFrame = CGRect(x: 0, y: 104, width: 1920, height: 29)
let clockInkTop: CGFloat = 146
let avatarCenter = CGPoint(x: 960, y: 895)
let avatarDiameter: CGFloat = 50
let nameFrame = CGRect(x: 0, y: 935, width: 1920, height: 20)
let passwordFrame = CGRect(x: 880, y: 967, width: 160, height: 28)

enum Treatment: CaseIterable {
    case untreated, cards, softBacking
    var title: String {
        switch self { case .untreated: return "A  Untreated"; case .cards: return "B  Separate cards"; case .softBacking: return "C  Soft backing" }
    }
    var fileStem: String {
        switch self { case .untreated: return "untreated"; case .cards: return "separate-cards"; case .softBacking: return "soft-backing" }
    }
    var caption: String {
        switch self {
        case .untreated: return "No saver-drawn backing"
        case .cards: return "Charcoal cards · 65% alpha · 16 pt radius"
        case .softBacking: return "Broad feathered dark pools · no hard edge"
        }
    }
}

func makeContext(_ size: CGSize) -> CGContext {
    let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    return context
}

func topLeftSpace(_ context: CGContext, size: CGSize) {
    context.translateBy(x: 0, y: size.height)
    context.scaleBy(x: 1, y: -1)
}

func fill(_ context: CGContext, _ color: NSColor, _ rect: CGRect) {
    context.setFillColor(color.cgColor); context.fill(rect)
}

func scaled(_ rect: CGRect) -> CGRect { rect.applying(CGAffineTransform(scaleX: pointScale, y: pointScale)) }
func scaled(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x * pointScale, y: point.y * pointScale) }
func screenRect(_ rect: CGRect) -> CGRect { CGRect(x: rect.minX, y: 1080 - rect.maxY, width: rect.width, height: rect.height) }
func screenPoint(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x, y: 1080 - point.y) }

func drawRounded(_ context: CGContext, rect: CGRect, radius: CGFloat, color: NSColor) {
    context.setFillColor(color.cgColor)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()
}

func drawPool(_ context: CGContext, rect: CGRect) {
    // Nested translucent rounded forms make a deliberately broad, edge-free pool.
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let maxRadius = max(rect.width, rect.height) * 0.72
    let colors = [NSColor(calibratedWhite: 0.015, alpha: 0.58).cgColor, NSColor(calibratedWhite: 0.01, alpha: 0.35).cgColor, NSColor(calibratedWhite: 0.01, alpha: 0.0).cgColor] as CFArray
    let locations: [CGFloat] = [0, 0.48, 1]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations)!
    context.saveGState()
    context.scaleBy(x: rect.width / rect.height, y: 1)
    let adjusted = CGPoint(x: center.x * rect.height / rect.width, y: center.y)
    context.drawRadialGradient(gradient, startCenter: adjusted, startRadius: 0, endCenter: adjusted, endRadius: maxRadius * rect.height / rect.width, options: [.drawsAfterEndLocation])
    context.restoreGState()
}

func drawText(_ context: CGContext, _ text: String, frame: CGRect, size: CGFloat, weight: NSFont.Weight, alignment: NSTextAlignment = .center, color: NSColor = .white, flipped: Bool = false) {
    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = alignment; paragraph.lineBreakMode = .byClipping
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
    let attr = NSAttributedString(string: text, attributes: attributes)
    let nsContext = NSGraphicsContext(cgContext: context, flipped: flipped)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = nsContext
    attr.draw(with: frame, options: [.usesLineFragmentOrigin, .usesFontLeading])
    NSGraphicsContext.restoreGraphicsState()
}

func drawLockUI(_ context: CGContext) {
    drawText(context, "Tue 22 Sep", frame: screenRect(dateFrame), size: 28, weight: .regular)
    // Position the actual clock ink, not its taller AppKit line box, so its
    // observed top and the card's padding mean the same thing in every variant.
    let base = NSFont.systemFont(ofSize: 150, weight: .bold)
    let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 150) } ?? base
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "19:24", attributes: [.font: font, .foregroundColor: NSColor.white]))
    let ink = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
    context.saveGState()
    context.textMatrix = .identity
    context.textPosition = CGPoint(x: 960 - ink.midX, y: 1080 - clockInkTop - ink.maxY)
    CTLineDraw(line, context)
    context.restoreGState()
    let c = screenPoint(avatarCenter)
    context.setFillColor(NSColor(calibratedWhite: 1, alpha: 0.92).cgColor)
    context.fillEllipse(in: CGRect(x: c.x - 25, y: c.y - 25, width: 50, height: 50))
    context.setFillColor(NSColor(calibratedWhite: 0.25, alpha: 0.86).cgColor)
    context.fillEllipse(in: CGRect(x: c.x - 8, y: c.y - 15, width: 16, height: 16))
    context.fillEllipse(in: CGRect(x: c.x - 15, y: c.y + 3, width: 30, height: 22))
    drawText(context, "User", frame: screenRect(nameFrame), size: 16, weight: .medium)
    let password = screenRect(passwordFrame)
    drawRounded(context, rect: password, radius: 14, color: NSColor(calibratedWhite: 0.10, alpha: 0.60))
    context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.34).cgColor); context.setLineWidth(1)
    context.addPath(CGPath(roundedRect: password.insetBy(dx: 0.5, dy: 0.5), cornerWidth: 13.5, cornerHeight: 13.5, transform: nil)); context.strokePath()
    drawText(context, "Enter Password", frame: password.insetBy(dx: 8, dy: 5), size: 12, weight: .regular, color: NSColor(calibratedWhite: 1, alpha: 0.72))
}

func sampledEdgeColor(_ image: NSImage) -> NSColor? {
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, count: CGFloat = 0
    let x = max(0, rep.pixelsWide - 2), y = max(0, rep.pixelsHigh - 2)
    for point in [(x, y), (x, 1), (1, y)] {
        guard let color = rep.colorAt(x: point.0, y: point.1)?.usingColorSpace(.deviceRGB) else { continue }
        r += color.redComponent; g += color.greenComponent; b += color.blueComponent; count += 1
    }
    return count > 0 ? NSColor(deviceRed: r / count, green: g / count, blue: b / count, alpha: 1) : nil
}

func render(frameURL: URL, treatment: Treatment) -> CGImage {
    let context = makeContext(canvas)
    let frameName = frameURL.deletingPathExtension().lastPathComponent
    let image = NSImage(contentsOf: frameURL)
    // Native-sized 3800 × 2128 frames leave a small neutral remainder. Parchment
    // uses its sampled edge tone so the comparison does not invent a black seam.
    let remainder = frameName == "parchment" ? image.flatMap(sampledEdgeColor) ?? NSColor(calibratedWhite: 0.86, alpha: 1) : NSColor(calibratedWhite: 0.075, alpha: 1)
    fill(context, remainder, CGRect(origin: .zero, size: canvas))
    if let image, let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        // Native-sized source is top-left aligned rather than stretched.
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
    }
    // Bitmap contexts already address the exported PNG from its visual top edge.
    // Only scale the observed 1920 × 1080-point schematic into the 2× frame.
    context.scaleBy(x: pointScale, y: pointScale)
    switch treatment {
    case .untreated: break
    case .cards:
        drawRounded(context, rect: screenRect(clockCard), radius: 16, color: NSColor(calibratedWhite: 0.02, alpha: 0.65))
        drawRounded(context, rect: screenRect(authCard), radius: 16, color: NSColor(calibratedWhite: 0.02, alpha: 0.65))
    case .softBacking:
        drawPool(context, rect: screenRect(clockCard.insetBy(dx: -78, dy: -52)))
        drawPool(context, rect: screenRect(authCard.insetBy(dx: -64, dy: -48)))
    }
    drawLockUI(context)
    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

func drawImage(_ context: CGContext, _ image: CGImage, in rect: CGRect) {
    // Contact-sheet contexts are deliberately top-left flipped for AppKit labels;
    // compensate only the embedded PNG, so source frames retain their orientation.
    context.saveGState()
    context.translateBy(x: rect.minX, y: rect.minY + rect.height)
    context.scaleBy(x: 1, y: -1)
    context.draw(image, in: CGRect(origin: .zero, size: rect.size))
    context.restoreGState()
}

func makeContactSheet(rows: [(String, [CGImage])], output: URL) {
    let cellW: CGFloat = 960, screenH: CGFloat = 540, headH: CGFloat = 58, footH: CGFloat = 42, rowGap: CGFloat = 26
    let size = CGSize(width: cellW * 3, height: (headH + screenH + footH) * 2 + rowGap)
    let c = makeContext(size); topLeftSpace(c, size: size); fill(c, NSColor(calibratedWhite: 0.055, alpha: 1), CGRect(origin: .zero, size: size))
    for (rowIndex, row) in rows.enumerated() {
        let y = CGFloat(rowIndex) * (headH + screenH + footH + rowGap)
        for column in 0..<3 {
            let x = CGFloat(column) * cellW
            fill(c, NSColor(calibratedWhite: 0.095, alpha: 1), CGRect(x: x, y: y, width: cellW, height: headH))
            drawText(c, Treatment.allCases[column].title, frame: CGRect(x: x + 24, y: y + 17, width: cellW - 48, height: 28), size: 23, weight: .semibold, alignment: .left, flipped: true)
            drawImage(c, row.1[column], in: CGRect(x: x, y: y + headH, width: cellW, height: screenH))
            drawText(c, row.0 + "  ·  " + Treatment.allCases[column].caption + "  ·  Controls are approximations at observed positions, not real macOS rendering.", frame: CGRect(x: x + 24, y: y + headH + screenH + 11, width: cellW - 48, height: 22), size: 10, weight: .regular, alignment: .left, color: NSColor(calibratedWhite: 1, alpha: 0.74), flipped: true)
        }
    }
    writePNG(c.makeImage()!, to: output)
}

func makeAuthCropSheet(rows: [(String, [CGImage])], output: URL) {
    let source = CGRect(x: 1480, y: 1580, width: 880, height: 580)
    let scale: CGFloat = 1.25, cellW = source.width * scale, cropH = source.height * scale, headH: CGFloat = 56, footH: CGFloat = 38, rowGap: CGFloat = 24
    let size = CGSize(width: cellW * 3, height: (headH + cropH + footH) * 2 + rowGap)
    let c = makeContext(size); topLeftSpace(c, size: size); fill(c, NSColor(calibratedWhite: 0.055, alpha: 1), CGRect(origin: .zero, size: size))
    for (rowIndex, row) in rows.enumerated() {
        let y = CGFloat(rowIndex) * (headH + cropH + footH + rowGap)
        for column in 0..<3 {
            let x = CGFloat(column) * cellW
            fill(c, NSColor(calibratedWhite: 0.095, alpha: 1), CGRect(x: x, y: y, width: cellW, height: headH))
            drawText(c, row.0 + " · " + Treatment.allCases[column].title, frame: CGRect(x: x + 22, y: y + 16, width: cellW - 44, height: 26), size: 20, weight: .semibold, alignment: .left, flipped: true)
            c.saveGState(); c.clip(to: CGRect(x: x, y: y + headH, width: cellW, height: cropH)); drawImage(c, row.1[column], in: CGRect(x: x - source.minX * scale, y: y + headH - source.minY * scale, width: canvas.width * scale, height: canvas.height * scale)); c.restoreGState()
            drawText(c, "Approximate observed auth position · schematic control", frame: CGRect(x: x + 22, y: y + headH + cropH + 9, width: cellW - 44, height: 20), size: 13, weight: .regular, alignment: .left, color: NSColor(calibratedWhite: 1, alpha: 0.70), flipped: true)
        }
    }
    writePNG(c.makeImage()!, to: output)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let frames = root.appendingPathComponent("frames")
let shots = root.appendingPathComponent("shots")
try! FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true)
var sheetRows: [(String, [CGImage])] = []
for frameName in ["dense", "opal", "parchment"] {
    let rendered = Treatment.allCases.map { treatment -> CGImage in
        let image = render(frameURL: frames.appendingPathComponent(frameName + ".png"), treatment: treatment)
        writePNG(image, to: shots.appendingPathComponent(frameName + "-" + treatment.fileStem + ".png"))
        return image
    }
    let label = frameName == "parchment" ? "Bright theme study" : frameName.capitalized + " frame"
    sheetRows.append((label, rendered))
}
let comparisonRows = [sheetRows[0], sheetRows[2]]
makeContactSheet(rows: comparisonRows, output: shots.appendingPathComponent("contact-sheet.png"))
makeAuthCropSheet(rows: comparisonRows, output: shots.appendingPathComponent("auth-crop-sheet.png"))
print("Rendered \(shots.path)")
