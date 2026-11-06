import EchoelCore
import EchoelKernels
import SwiftUI

/// The vocal strip on a track's effects page: one value field per process of the vocal chain the
/// track carries — De-Ess, Level, Air, Space (`VocalStrip`). Each field moves the values of its
/// effect that decide that process, live while the finger moves, and lifting the finger stores
/// the effect's settings in the song as one undo step. A field shows where the sound is, read
/// from the effect itself, so a value changed in the effect's own panel moves it too.
struct VocalStripSection: View {
    let track: TrackID
    let strip: VocalStrip
    /// The narrowest column, as on the effect panel: it grows with the text (W18, M10).
    @ScaledMetric(relativeTo: .body) private var columnWidth: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("Vocal Strip — one control per step of the chain")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: columnWidth), spacing: Theme.Space.s)],
                      alignment: .leading, spacing: Theme.Space.s) {
                ForEach(strip.faders) { fader in
                    VocalStripField(track: track, fader: fader)
                }
            }
        }
    }
}

/// What one strip field writes: the effect's values through the writer, as a hand on each of
/// them, and on letting go the effect's settings into the song as one undo step.
@MainActor
private struct VocalStripWriter {
    let writer: ParameterWriter
    let plugins: PluginHost
    let store: ProjectStore
    let track: TrackID
    let fader: VocalStrip.Fader

    /// Moves the effect to the strip's `place` (0…1).
    func set(_ place: Double, gesture: Bool) {
        let parameters = EffectKernel.parameters(for: fader.control.effect)
        for setting in fader.control.settings(at: Float(place)) {
            guard let parameter = parameters.first(where: { $0.identifier == setting.identifier }) else { continue }
            let low = parameter.range.lowerBound, high = parameter.range.upperBound
            let position = high > low ? Swift.min(Swift.max((setting.value - low) / (high - low), 0), 1) : 0
            writer.set(address(of: parameter), normalized: Double(position), gesture: gesture)
        }
    }

    /// The gesture is over: the effect's settings go into the song as one step.
    func commit() {
        writer.endGesture()
        plugins.store(into: store, only: .insert(fader.insert), title: fader.control.actionTitle)
    }

    func address(of parameter: EffectParameter) -> ParameterAddress {
        ParameterAddress(.track(track), .plugin(PluginParameter(.insert(fader.insert), address: UInt64(parameter.address))))
    }
}

/// One strip control, drawn as the effect panel's value fields are: label above, value, a bar.
/// Drag up or down — slowly for fine steps — or tap to type it on the number pad, in percent.
private struct VocalStripField: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(ProjectStore.self) private var store
    @Environment(ParameterWriter.self) private var writer
    @Environment(NumberPadController.self) private var pad: NumberPadController?
    let track: TrackID
    let fader: VocalStrip.Fader
    /// The drag in progress: the place it has reached and the translation last read.
    @State private var drag: (place: Double, translation: CGFloat)?

    private static let travel: CGFloat = 240

    var body: some View {
        // The values live in the effect, not the song: read them in this leaf, often enough to
        // follow automation, MIDI and the effect's own panel (Law 6).
        TimelineView(.periodic(from: .now, by: 1.0 / 15)) { _ in
            field(shown: currentPlace())
        }
    }

    private var strip: VocalStripWriter {
        VocalStripWriter(writer: writer, plugins: engine.plugins, store: store, track: track, fader: fader)
    }

    private var owner: String { "vocalStrip.\(fader.insert).\(fader.control.title)" }

    /// Where the sound is: from the loaded effect, else from the settings the song stores.
    private func currentPlace() -> Double? {
        let writing = strip
        let parameters = EffectKernel.parameters(for: fader.control.effect)
        let live = fader.control.position(from: { identifier in
            guard let parameter = parameters.first(where: { $0.identifier == identifier }),
                  let position = engine.plugins.position(of: writing.address(of: parameter)) else { return nil }
            let low = parameter.range.lowerBound, high = parameter.range.upperBound
            return low + Float(position) * (high - low)
        })
        if let live { return Double(live) }
        guard let insert = store.project.track(track)?.inserts.first(where: { $0.id == fader.insert }),
              let stored = fader.control.position(in: insert) else { return nil }
        return Double(stored)
    }

    @ViewBuilder private func field(shown: Double?) -> some View {
        let place = drag?.place ?? shown ?? 0
        let engaged = drag != nil || pad?.request?.owner == owner
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(fader.control.title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .lineLimit(1)
            Text(shown == nil && drag == nil ? "—" : text(place))
                .font(Theme.Font.value)
                .foregroundStyle(shown == nil ? Theme.Color.textSecondary : (engaged ? Theme.Color.accent : Theme.Color.text))
                .lineLimit(1)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.Color.surfaceRaised)
                    Rectangle().fill(Theme.Color.accent).frame(width: geometry.size.width * CGFloat(place))
                }
            }
            .frame(height: 3)
            .accessibilityHidden(true)
        }
        .padding(Theme.Space.s)
        .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.Color.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium)
            .strokeBorder(engaged ? Theme.Color.accent : Theme.Color.borderStrong, lineWidth: 1))
        .animation(Theme.Motion.quick, value: engaged)
        .contentShape(Rectangle())
        .gesture(dragGesture(from: place))
        .onTapGesture { openPad(place) }
        .accessibilityElement()
        .accessibilityLabel(fader.control.title)
        .accessibilityValue(shown == nil ? "Not loaded" : text(place))
        .accessibilityHint(fader.control.summary)
        .accessibilityAdjustableAction { direction in
            let moved = Swift.min(Swift.max(place + (direction == .increment ? 0.05 : -0.05), 0), 1)
            strip.set(moved, gesture: false)
            strip.commit()
        }
        // VoiceOver's double-tap types the value, like the effect panel's fields.
        .accessibilityAction { openPad(place) }
        .accessibilityAction(named: "Type a Value") { openPad(place) }
    }

    private func dragGesture(from place: Double) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { gesture in
                let reached = drag ?? (place: place, translation: 0)
                let moved = gesture.translation.height - reached.translation
                let scale = DragPrecision.scale(speed: Double(gesture.velocity.height))
                let next = Swift.min(Swift.max(reached.place - Double(moved / Self.travel) * scale, 0), 1)
                drag = (place: next, translation: gesture.translation.height)
                strip.set(next, gesture: true)
            }
            .onEnded { _ in
                drag = nil
                strip.commit()
            }
    }

    private func openPad(_ place: Double) {
        guard let pad else { return }
        let writing = strip
        pad.open(NumberPadRequest(owner: owner, title: fader.control.title,
                                  format: NumberEntryFormat(scale: 100, decimals: 0, unit: "%"), range: 0...1,
                                  value: place, standard: nil) { typed in
            let target = typed.isFinite ? Swift.min(Swift.max(typed, 0), 1) : 0
            writing.set(target, gesture: false)
            writing.commit()
        })
    }

    private func text(_ place: Double) -> String {
        NumberText.string(place * 100, decimals: 0, unit: "%")
    }
}
