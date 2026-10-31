import EchoelCore
import EchoelEngine
import EchoelHost
import EchoelKernels
import SwiftUI

/// The controls of one of Echoel's standard effects on an insert: every parameter as a value
/// field. They move the effect through the same path as a plugin's own interface, so automation
/// writing and MIDI learn reach them.
struct StandardEffectPanel: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(ProjectStore.self) private var store
    @Environment(ParameterWriter.self) private var writer
    /// The track the insert sits on, or the master.
    let owner: ParameterAddress.Owner
    let insert: InsertID
    let effect: StandardEffect

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            if effect == .compressor || effect == .limiter { ReductionMeter(slot: .insert(insert)) }
            if effect == .pitchCorrection { songKeyButton }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Theme.Space.s)],
                      alignment: .leading, spacing: Theme.Space.s) {
                ForEach(EffectKernel.parameters(for: effect), id: \.address) { parameter in
                    let address = ParameterAddress(owner, .plugin(PluginParameter(.insert(insert),
                                                                                  address: UInt64(parameter.address))))
                    if parameter.unit == .choice {
                        EffectChoiceField(address: address, parameter: parameter)
                    } else {
                        EffectParameterField(address: address, parameter: parameter)
                    }
                }
            }
            if !engine.plugins.isLoaded(.insert(insert)) {
                Text("Loading…")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
    }
}

extension StandardEffectPanel {
    /// Sets the correction's key, scale, tone system and concert A to the song's own frame, through
    /// the writer like a hand on each control. The effect keeps its values afterwards: a song whose
    /// key changes later asks for another tap, so a correction never moves under a take by itself.
    var songKeyButton: some View {
        let context = store.project.context
        return Button {
            useSongKey(context)
        } label: {
            Text("Use Song Key · \(context.title)")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.text)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.Color.surface))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .strokeBorder(Theme.Color.borderStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Sets key, scale, tone system and concert A from the song")
    }

    private func useSongKey(_ context: MusicalContext) {
        let wanted: [String: Float] = [
            "key": Float(context.root),
            "scale": Float(Scale.allCases.firstIndex(of: context.scale) ?? 0),
            "tuning": Float(TuningSystem.library.firstIndex { $0.id == context.tuning } ?? 0),
            "reference": Float(context.concertPitch),
        ]
        for parameter in EffectKernel.parameters(for: .pitchCorrection) {
            guard let value = wanted[parameter.identifier] else { continue }
            let low = parameter.range.lowerBound, high = parameter.range.upperBound
            let position = high > low ? Swift.min(Swift.max((value - low) / (high - low), 0), 1) : 0
            let address = ParameterAddress(owner, .plugin(PluginParameter(.insert(insert),
                                                                          address: UInt64(parameter.address))))
            writer.set(address, normalized: Double(position), gesture: false)
        }
    }
}

/// The compressor's gain reduction, read in its own leaf so the panel above it stays still.
private struct ReductionMeter: View {
    @Environment(AudioEngine.self) private var engine
    let slot: PluginHost.Slot

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 15)) { _ in
            let reduction = engine.plugins.standardEffect(slot)?.gainReduction ?? 0
            HStack(spacing: Theme.Space.s) {
                Text("Reduction")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                GeometryReader { geometry in
                    ZStack(alignment: .trailing) {
                        Rectangle().fill(Theme.Color.surfaceRaised)
                        Rectangle().fill(Theme.Color.accent)
                            .frame(width: geometry.size.width * CGFloat(min(-reduction, 24) / 24))
                    }
                }
                .frame(height: 6)
                Text(String(format: "%.1f dB", reduction))
                    .font(Theme.Font.caption.monospacedDigit())
                    .foregroundStyle(Theme.Color.text)
                    .frame(width: 64, alignment: .trailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Gain reduction")
            .accessibilityValue(String(format: "%.1f decibels", reduction))
        }
    }
}

/// A parameter whose values have names (a harmony interval, a scale): a menu of the names, never
/// a number. The menu stays still; only its label reads the unit, in its own leaf, so automation
/// moving the value cannot close the menu while it is open (Law 6).
private struct EffectChoiceField: View {
    @Environment(ParameterWriter.self) private var writer
    let address: ParameterAddress
    let parameter: EffectParameter

    var body: some View {
        Menu {
            ForEach(parameter.choices.indices, id: \.self) { index in
                Button(parameter.choices[index]) { pick(index) }
            }
        } label: {
            EffectChoiceLabel(address: address, parameter: parameter)
        }
        .accessibilityLabel(parameter.title)
        .midiLearnable(address)
    }

    private func pick(_ index: Int) {
        let last = Swift.max(parameter.choices.count - 1, 1)
        writer.set(address, normalized: Double(index) / Double(last), gesture: false)
    }
}

/// The current choice, read from the unit in this leaf.
private struct EffectChoiceLabel: View {
    @Environment(AudioEngine.self) private var engine
    let address: ParameterAddress
    let parameter: EffectParameter

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 15)) { _ in
            let low = parameter.range.lowerBound, high = parameter.range.upperBound
            let position = engine.plugins.position(of: address)
            let value = position.map { low + Float($0) * (high - low) } ?? parameter.defaultValue
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(parameter.title)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .lineLimit(1)
                Text(parameter.choice(at: value) ?? "")
                    .font(Theme.Font.value)
                    .foregroundStyle(position == nil ? Theme.Color.textSecondary : Theme.Color.text)
                    .lineLimit(1)
            }
            .padding(Theme.Space.s)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.Color.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .strokeBorder(Theme.Color.borderStrong, lineWidth: 1))
            .accessibilityValue(parameter.choice(at: value) ?? "")
        }
    }
}

/// One effect parameter, as the value field (`ParameterField`): label, value, a bar; drag up or
/// down — slowly for fine steps — double-tap for the default, tap to type it on the number pad,
/// tap a switch to flip it. Frequencies move on a logarithmic scale, as an ear hears them; the
/// song still stores the position along the parameter's own travel.
private struct EffectParameterField: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(ParameterWriter.self) private var writer
    @Environment(NumberPadController.self) private var pad: NumberPadController?
    let address: ParameterAddress
    let parameter: EffectParameter
    /// The drag in progress: the place on the control it has reached and the translation last read.
    @State private var drag: (place: Double, translation: CGFloat)?

    private static let travel: CGFloat = 240

    var body: some View {
        // The value lives in the unit, not the song: read it in this leaf, often enough to follow
        // automation, MIDI and the plugin itself.
        TimelineView(.periodic(from: .now, by: 1.0 / 15)) { _ in
            field(position: engine.plugins.position(of: address))
        }
    }

    @ViewBuilder private func field(position: Double?) -> some View {
        let shown = value(at: position ?? self.position(of: parameter.defaultValue))
        let place = curve(of: shown)
        let engaged = drag != nil || pad?.request?.owner == owner
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(parameter.title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .lineLimit(1)
            Text(text(shown))
                .font(Theme.Font.value)
                .foregroundStyle(position == nil ? Theme.Color.textSecondary : (engaged ? Theme.Color.accent : Theme.Color.text))
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
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { gesture in
                    guard parameter.unit != .boolean else { return }
                    let reached = drag ?? (place: place, translation: 0)
                    let moved = gesture.translation.height - reached.translation
                    let scale = DragPrecision.scale(speed: Double(gesture.velocity.height))
                    let next = Swift.min(Swift.max(reached.place - Double(moved / Self.travel) * scale, 0), 1)
                    drag = (place: next, translation: gesture.translation.height)
                    writer.set(address, normalized: self.position(of: self.value(atCurve: next)), gesture: true)
                }
                .onEnded { _ in
                    drag = nil
                    writer.endGesture()
                }
        )
        .onTapGesture(count: 2) {
            writer.set(address, normalized: self.position(of: parameter.defaultValue), gesture: false)
            writer.endGesture()
        }
        .onTapGesture {
            guard parameter.unit == .boolean else { openPad(shown); return }
            writer.set(address, normalized: shown >= 0.5 ? 0 : 1, gesture: false)
        }
        .sensoryFeedback(.selection, trigger: shown) { old, new in
            drag != nil && DragPrecision.reachesDetent(from: old, to: new, standard: Double(parameter.defaultValue),
                                                       range: low...high)
        }
        .accessibilityElement()
        .accessibilityLabel(parameter.title)
        .accessibilityValue(text(shown))
        .accessibilityAdjustableAction { direction in
            let step = parameter.unit == .boolean ? 1 : 0.02
            let moved = Swift.min(Swift.max(place + (direction == .increment ? step : -step), 0), 1)
            writer.set(address, normalized: self.position(of: self.value(atCurve: moved)), gesture: false)
        }
        .accessibilityAction(named: "Type a Value") { openPad(shown) }
        .midiLearnable(address)
    }

    private var owner: String { "\(address)" }

    /// How the number pad reads this parameter: a time in ms, a frequency in Hz; a switch is not
    /// typed.
    private var entryFormat: NumberEntryFormat? {
        switch parameter.unit {
        case .hertz: NumberEntryFormat(scale: 1, decimals: high <= 1_000 ? 1 : 0, unit: "Hz")
        case .seconds: NumberEntryFormat(scale: 1_000, decimals: (high - low) * 1_000 < 100 ? 1 : 0, unit: "ms")
        case .decibels: NumberEntryFormat(scale: 1, decimals: 1, unit: "dB")
        case .ratio: NumberEntryFormat(scale: 1, decimals: parameter.identifier == "ratio" ? 1 : 2,
                                       unit: parameter.identifier == "ratio" ? ": 1" : "")
        case .amount: NumberEntryFormat(scale: 1, decimals: 2, unit: "")
        case .boolean, .choice: nil
        }
    }

    private func openPad(_ shown: Double) {
        guard let pad, let format = entryFormat else { return }
        let target = address
        let writer = writer
        let lower = low, upper = high
        pad.open(NumberPadRequest(owner: owner, title: parameter.title, format: format, range: lower...upper,
                                  value: shown, standard: Double(parameter.defaultValue)) { typed in
            let position = upper > lower ? Swift.min(Swift.max((typed - lower) / (upper - lower), 0), 1) : 0
            writer.set(target, normalized: position, gesture: false)
            writer.endGesture()
        })
    }

    private var low: Double { Double(parameter.range.lowerBound) }
    private var high: Double { Double(parameter.range.upperBound) }
    private var logarithmic: Bool { parameter.unit == .hertz && low > 0 }

    /// The value at a position (0…1) along the parameter's linear travel.
    private func value(at position: Double) -> Double { low + position * (high - low) }

    private func position(of value: Float) -> Double { position(of: Double(value)) }

    private func position(of value: Double) -> Double {
        high > low ? Swift.min(Swift.max((value - low) / (high - low), 0), 1) : 0
    }

    /// Where the value sits on the control: logarithmic for frequencies, linear otherwise.
    private func curve(of value: Double) -> Double {
        guard logarithmic else { return position(of: value) }
        return Swift.min(Swift.max(Foundation.log(Swift.max(value, low) / low) / Foundation.log(high / low), 0), 1)
    }

    private func value(atCurve curve: Double) -> Double {
        logarithmic ? low * Foundation.pow(high / low, curve) : value(at: curve)
    }

    private func text(_ value: Double) -> String {
        switch parameter.unit {
        case .hertz: ParameterFormat.text(value, unit: .hertz)
        case .seconds: ParameterFormat.text(value, unit: .seconds)
        case .decibels: String(format: "%+.1f dB", value)
        case .ratio: parameter.identifier == "ratio" ? String(format: "%.1f : 1", value) : String(format: "%.2f", value)
        case .amount: String(format: "%.2f", value)
        case .boolean: value >= 0.5 ? "On" : "Off"
        case .choice: parameter.choice(at: Float(value)) ?? ""
        }
    }
}
