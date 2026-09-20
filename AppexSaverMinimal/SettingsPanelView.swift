//
//  SettingsPanelView.swift
//  Host app only.
//
//  The panel that floats over the live saver render, and the model behind it.
//
//  The look is the one #26 settled by eye: a centred sheet, ~460 pt wide on
//  light material, draggable by its title row; the braille source, then the
//  two fractions as sliders with numeric readouts; the frame rate as a
//  "Smooth motion" switch that says what it costs; and a bottom row with Hide
//  at the left, Discard and a prominent Accept at the right. Exit is the
//  close glyph in the title row, with Escape as its accelerator.
//
//  What the panel cannot do for itself — move, hide, exit — it asks the
//  surface for through closures. It is a subview whose frame the surface
//  owns, and Hide is an input policy on the surface, not a view state here.
//

#if canImport(SwiftTerm)

import SwiftUI

/// The staged settings, and the three things that can be done with them.
///
/// Every edit stages into the `SaverSettingsStore` behind each screen's
/// render, which pushes it straight into that view and writes nothing
/// anywhere. Only `accept()` touches the defaults domain — which is what
/// makes a running saver instance elsewhere see nothing until the user
/// commits.
///
/// There is one store per screen rather than one shared by all of them,
/// because a store carries a single callback per group — the shape the
/// extension needs, where one instance has one view. Sharing one store
/// across screens would silently drive only whichever render attached last.
/// The stores are stepped in lockstep, so any of them answers for all.
@MainActor
final class SettingsPanelModel: ObservableObject {

    @Published var source: BrailleSource { didSet { stageIfChanged() } }
    @Published var dotSizeFraction: CGFloat { didSet { stageIfChanged() } }
    @Published var cornerFraction: CGFloat { didSet { stageIfChanged() } }
    @Published var frameRate: FrameRate { didSet { stageIfChanged() } }

    /// Whether there is anything to Accept or Discard. Read from the store
    /// rather than tracked here, so it cannot disagree with what is staged.
    @Published private(set) var isDirty: Bool = false

    private let stores: [SaverSettingsStore]
    /// Any store answers for all of them; they are always staged together.
    private var reference: SaverSettingsStore { stores[0] }
    /// Set while the model is writing its own published values, so the
    /// `didSet` cascade that causes does not stage four times.
    private var isRepopulating = false

    init(stores: [SaverSettingsStore]) {
        precondition(!stores.isEmpty, "the panel needs at least the screen it is drawn on")
        self.stores = stores
        let current = stores[0].effective
        source = current.braille.source
        dotSizeFraction = current.braille.dotSizeFraction
        cornerFraction = current.braille.cornerFraction
        frameRate = current.frameRate
        isDirty = stores[0].isDirty
    }

    /// The values as the panel currently shows them.
    var staged: SaverSettings {
        SaverSettings(
            braille: BrailleSettings(source: source,
                                     dotSizeFraction: dotSizeFraction,
                                     cornerFraction: cornerFraction),
            frameRate: frameRate)
    }

    /// Commits to the domain. Stays open: tuning is iterative — commit a dot
    /// size, keep looking, nudge it again.
    ///
    /// The staged values are deliberately *not* cleared here. The store drops
    /// them when its own cross-process observation reports the domain has
    /// caught up, so the effective values never move and the render is never
    /// redrawn by an Accept.
    func accept() {
        SaverSettingsWriter.write(staged)
        isDirty = reference.isDirty
    }

    /// Throws away everything since the last Accept. Stays open.
    func discard() {
        for store in stores { store.discardStaged() }
        repopulate(from: reference.effective)
    }

    private func stageIfChanged() {
        guard !isRepopulating else { return }
        let values = staged
        for store in stores { store.stage(values) }
        isDirty = reference.isDirty
    }

    private func repopulate(from settings: SaverSettings) {
        isRepopulating = true
        source = settings.braille.source
        dotSizeFraction = settings.braille.dotSizeFraction
        cornerFraction = settings.braille.cornerFraction
        frameRate = settings.frameRate
        isRepopulating = false
        isDirty = reference.isDirty
    }
}

struct SettingsPanelView: View {

    @ObservedObject var model: SettingsPanelModel
    /// Closes the surface. Exit drops anything unsaved without asking, which
    /// is safe precisely because Discard is sitting next to it.
    var onExit: () -> Void
    /// Takes the panel away until the next input; the surface decides what
    /// counts as input and brings it back.
    var onHide: () -> Void
    /// A drag of the title row, as a delta in the window's coordinates. The
    /// panel cannot move itself: it is a subview whose frame the surface owns.
    var onDrag: (CGPoint) -> Void

    /// The sheet's width (#26: ~460 pt) and corner radius.
    static let width: CGFloat = 460
    static let cornerRadius: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleRow
                .padding(.bottom, 16)
            braille
            Divider().padding(.vertical, 14)
            frameRate
            Divider().padding(.vertical, 14)
            buttons
        }
        .padding(22)
        .frame(width: Self.width)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
    }

    /// Handle glyph, title, close glyph. The handle and the title are the
    /// drag region; the close glyph is a button of its own outside it, so a
    /// press on it can never start a drag.
    private var titleRow: some View {
        HStack {
            ZStack {
                DragHandle(onDrag: onDrag)
                HStack {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.tertiary)
                    Text("Screensaver Settings")
                        .font(.title3.weight(.semibold))
                    Spacer()
                }
                // Neither the glyph nor the title takes a click, so the handle
                // beneath them gets every press in the row.
                .allowsHitTesting(false)
            }
            Button(action: onExit) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Exit (Esc)")
        }
    }

    private var braille: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                Text("Braille")
                    .gridColumnAlignment(.trailing)
                Picker("Braille", selection: $model.source) {
                    ForEach(BrailleSource.allCases, id: \.self) { source in
                        Text(Self.name(for: source)).tag(source)
                    }
                }
                .labelsHidden()
                .frame(width: 220)
            }
            // Both fractions are disabled for a font source: they drive the
            // renderer's own dot drawing, which a face turns off entirely.
            GridRow {
                Text("Dot size")
                fraction($model.dotSizeFraction, in: BrailleSettings.dotSizeFractionRange)
            }
            GridRow {
                Text("Corner")
                fraction($model.cornerFraction, in: BrailleSettings.cornerFractionRange)
            }
        }
    }

    private func fraction(_ value: Binding<CGFloat>,
                          in range: ClosedRange<CGFloat>) -> some View {
        HStack {
            Slider(value: value, in: range)
                .disabled(model.source != .procedural)
            Text(String(format: "%.2f", value.wrappedValue))
                .font(.caption.monospacedDigit())
                .frame(width: 36, alignment: .trailing)
        }
    }

    /// The frame rate as a switch. The cost is stated because this is a
    /// power control, not a taste one: 60 fps is roughly a full core against
    /// 30's half, continuously, for as long as the saver is up (#24). The
    /// wording is #26's.
    private var frameRate: some View {
        Toggle(isOn: smoothMotion) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Smooth motion")
                Text("60 fps. Uses about a full CPU core the whole time the saver is up; off, 30 fps uses about half.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
    }

    private var smoothMotion: Binding<Bool> {
        Binding(get: { model.frameRate == .sixty },
                set: { model.frameRate = $0 ? .sixty : .thirty })
    }

    private var buttons: some View {
        HStack {
            Button("Hide", action: onHide)
            Text("until the next input")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Discard") { model.discard() }
                .disabled(!model.isDirty)
            Button("Accept") { model.accept() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!model.isDirty)
        }
    }

    private static func name(for source: BrailleSource) -> String {
        switch source {
        case .procedural: return "Drawn"
        case .juliaMonoBold: return "JuliaMono Bold"
        case .jetBrainsMonoNerdFontMono: return "JetBrainsMono NFM"
        }
    }
}

// MARK: - Dragging

/// The region of the title row a drag starts in. An AppKit view rather than
/// a SwiftUI gesture, because the thing being moved is the hosting view the
/// gesture would be measured in: its coordinate space moves with every
/// step of the drag, where the window's does not.
private struct DragHandle: NSViewRepresentable {
    var onDrag: (CGPoint) -> Void

    func makeNSView(context: Context) -> DragHandleView {
        let view = DragHandleView()
        view.onDrag = onDrag
        return view
    }

    func updateNSView(_ view: DragHandleView, context: Context) {
        view.onDrag = onDrag
    }
}

private final class DragHandleView: NSView {
    var onDrag: ((CGPoint) -> Void)?
    private var last: NSPoint = .zero

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        last = event.locationInWindow
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        let now = event.locationInWindow
        onDrag?(CGPoint(x: now.x - last.x, y: now.y - last.y))
        last = now
    }

    override func mouseUp(with event: NSEvent) {
        NSCursor.pop()
    }
}

#endif
