import EchoelCore
import EchoelEngine
import EchoelKernels
import SwiftUI

/// The controls of one of Echoel's standard effects on an insert: every parameter as a value
/// field. They move the effect through the same path as a plugin's own interface, so automation
/// writing and MIDI learn reach them.
struct StandardEffectPanel: View {
    @Environment(AudioEngine.self) private var engine
    /// The track the insert sits on, or the master.
    let owner: ParameterAddress.Owner
    let insert: InsertID
    let effect: StandardEffect

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            if effect == .compressor { ReductionMeter(slot: .insert(insert)) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Theme.Space.s)],
                      alignment: .leading, spacing: Theme.Space.s) {
                ForEach(EffectKernel.parameters(for: effect), id: \.address) { parameter in
                    EffectParameterField(
                        address: ParameterAddress(owner, .plugin(PluginParameter(.insert(insert), address: UInt64(parameter.address)))),
                        parameter: parameter)
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

/// One effect parameter: label, value, a bar; drag up or down to change it, double-tap for the
/// default, tap a switch to flip it. Frequencies move on a logarithmic scale, as an ear hears
/// them; the song still stores the position along the parameter's own travel.
private struct EffectParameterField: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(ParameterWriter.self) private var writer
    let address: ParameterAddress
    let parameter: EffectParameter
    @State private var start: Double?

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
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(parameter.title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .lineLimit(1)
            Text(text(shown))
                .font(Theme.Font.value)
                .foregroundStyle(position == nil ? Theme.Color.textSecondary : Theme.Color.text)
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
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Color.border, lineWidth: 1))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { drag in
                    guard parameter.unit != .boolean else { return }
                    let origin = start ?? place
                    start = origin
                    let moved = Swift.min(Swift.max(origin - Double(drag.translation.height / Self.travel), 0), 1)
                    writer.set(address, normalized: self.position(of: self.value(atCurve: moved)), gesture: true)
                }
                .onEnded { _ in
                    start = nil
                    writer.endGesture()
                }
        )
        .onTapGesture(count: 2) {
            writer.set(address, normalized: self.position(of: parameter.defaultValue), gesture: false)
            writer.endGesture()
        }
        .onTapGesture {
            guard parameter.unit == .boolean else { return }
            writer.set(address, normalized: shown >= 0.5 ? 0 : 1, gesture: false)
        }
        .accessibilityElement()
        .accessibilityLabel(parameter.title)
        .accessibilityValue(text(shown))
        .accessibilityAdjustableAction { direction in
            let step = parameter.unit == .boolean ? 1 : 0.02
            let moved = Swift.min(Swift.max(place + (direction == .increment ? step : -step), 0), 1)
            writer.set(address, normalized: self.position(of: self.value(atCurve: moved)), gesture: false)
        }
        .midiLearnable(address)
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
        }
    }
}
