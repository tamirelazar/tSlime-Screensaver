//
//  SettingsPanelView.swift
//  Host app only.
//
//  The panel that floats over the live saver render, and the model behind it.
//
//  **This panel's look is not decided here.** #26 settles the layout, where
//  the panel sits over the render, how the frame-rate control shows what it
//  costs, and how the three buttons are weighted against each other — by eye,
//  from candidates. What is below is the smallest panel that makes #21's
//  machinery demonstrable: every control wired, every button doing exactly
//  what it says, and nothing styled that a taste decision is going to move.
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Screensaver Settings")
                .font(.headline)

            braille
            Divider()
            frameRate
            Divider()
            buttons
        }
        .padding(20)
        .frame(width: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var braille: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Braille", selection: $model.source) {
                ForEach(BrailleSource.allCases, id: \.self) { source in
                    Text(Self.name(for: source)).tag(source)
                }
            }

            // Both fractions are disabled for a font source: they drive the
            // renderer's own dot drawing, which a face turns off entirely.
            fraction("Dot size", value: $model.dotSizeFraction,
                     in: BrailleSettings.dotSizeFractionRange)
            fraction("Corner", value: $model.cornerFraction,
                     in: BrailleSettings.cornerFractionRange)
        }
        .disabled(false)
    }

    @ViewBuilder
    private func fraction(_ label: String,
                          value: Binding<CGFloat>,
                          in range: ClosedRange<CGFloat>) -> some View {
        HStack {
            Text(label)
                .frame(width: 70, alignment: .leading)
            Slider(value: value, in: range)
                .disabled(model.source != .procedural)
            Text(String(format: "%.2f", value.wrappedValue))
                .font(.caption.monospacedDigit())
                .frame(width: 36, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var frameRate: some View {
        // The cost is stated because this is a power control, not a taste
        // one: 60 fps is roughly a full core against 30's half, continuously,
        // for as long as the saver is up (#24). How that is worded and laid
        // out is #26; that it is said at all is not negotiable.
        VStack(alignment: .leading, spacing: 6) {
            Picker("Frame rate", selection: $model.frameRate) {
                Text("30 fps — about half a core").tag(FrameRate.thirty)
                Text("60 fps — about a full core").tag(FrameRate.sixty)
            }
            .pickerStyle(.radioGroup)

            Text("Changing this restarts the animation; the last frame holds for about a third of a second.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var buttons: some View {
        HStack {
            Button("Exit", action: onExit)
            Spacer()
            Button("Discard") { model.discard() }
                .disabled(!model.isDirty)
            Button("Accept") { model.accept() }
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

#endif
