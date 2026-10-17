import EchoelCore
import SwiftUI

/// The controls every continuous parameter uses — fader and pan today, knobs and value
/// fields later. Each one addresses its parameter by `ParameterAddress` and writes through
/// `Command.setParameter`, so a fader, a MIDI controller and the agent change a value the
/// same way, with the same validation and undo. A drag is one undo step.
enum ParameterFormat {
    static func text(_ value: Double, unit: ParameterUnit) -> String {
        switch unit {
        case .decibel:
            return value <= MixerStrip.volumeRange.lowerBound ? "−∞ dB" : String(format: "%.1f dB", value)
        case .pan:
            let percent = Int((abs(value) * 100).rounded())
            return percent == 0 ? "C" : (value < 0 ? "L\(percent)" : "R\(percent)")
        case .bpm:
            return String(format: "%.1f BPM", value)
        case .hertz:
            return value >= 1_000 ? String(format: "%.2f kHz", value / 1_000) : String(format: "%.0f Hz", value)
        case .seconds:
            return value >= 1 ? String(format: "%.2f s", value) : String(format: "%.0f ms", value * 1_000)
        case .octaves:
            return String(format: "%.1f oct", value)
        case .amount:
            return String(format: "%.2f", value)
        case .choice:
            return String(Int(value.rounded()))
        }
    }
}

private extension ProjectStore {
    func set(_ address: ParameterAddress, normalized: Double, gesture: Bool) {
        guard let descriptor = project.descriptor(for: address),
              let command = Command.setParameter(address, to: descriptor.value(forNormalized: normalized)) else { return }
        try? perform(command, coalescingKey: gesture ? "parameter.\(address.description)" : nil)
    }

    func reset(_ address: ParameterAddress) {
        guard let descriptor = project.descriptor(for: address),
              let command = Command.setParameter(address, to: descriptor.defaultValue) else { return }
        try? perform(command)
    }
}

/// A vertical fader. Drag anywhere on it to set the level (the console law puts 0 dB at
/// about 80 % of the travel); double-tap returns to 0 dB.
struct Fader: View {
    @Environment(ProjectStore.self) private var store
    let address: ParameterAddress
    var height: CGFloat = 180

    private static let width: CGFloat = 44
    private static let thumbHeight: CGFloat = 12

    var body: some View {
        if let descriptor = store.project.descriptor(for: address), let value = store.project.value(of: address) {
            let position = descriptor.normalized(value)
            let unity = descriptor.normalized(descriptor.defaultValue)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(Theme.Color.surfaceRaised)
                    .frame(width: 6)
                Rectangle()
                    .fill(Theme.Color.border)
                    .frame(width: 18, height: 1)
                    .offset(y: -CGFloat(unity) * (height - Self.thumbHeight) - Self.thumbHeight / 2)
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(Theme.Color.text)
                    .frame(width: Self.width - 8, height: Self.thumbHeight)
                    .offset(y: -CGFloat(position) * (height - Self.thumbHeight))
            }
            .frame(width: Self.width, height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { drag in
                        let n = 1 - (drag.location.y - Self.thumbHeight / 2) / (height - Self.thumbHeight)
                        store.set(address, normalized: Double(n), gesture: true)
                    }
                    .onEnded { _ in store.endGesture() }
            )
            .onTapGesture(count: 2) { store.reset(address) }
            .accessibilityElement()
            .accessibilityLabel(descriptor.title)
            .accessibilityValue(ParameterFormat.text(value, unit: descriptor.unit))
            .accessibilityAdjustableAction { direction in
                let step = direction == .increment ? 0.02 : -0.02
                store.set(address, normalized: position + step, gesture: false)
            }
            .midiLearnable(address)
        }
    }
}

/// A horizontal pan control: drag left or right from where it is; double-tap centres it.
struct PanControl: View {
    @Environment(ProjectStore.self) private var store
    let address: ParameterAddress
    @State private var start: Double?

    private static let width: CGFloat = 64

    var body: some View {
        if let descriptor = store.project.descriptor(for: address), let value = store.project.value(of: address) {
            let position = descriptor.normalized(value)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .fill(Theme.Color.surfaceRaised)
                Rectangle()
                    .fill(Theme.Color.accent)
                    .frame(width: abs(CGFloat(position) - 0.5) * Self.width, height: 4)
                    .offset(x: CGFloat(Swift.min(position, 0.5)) * Self.width)
                Rectangle()
                    .fill(Theme.Color.border)
                    .frame(width: 1, height: 12)
                    .offset(x: Self.width / 2)
            }
            .frame(width: Self.width, height: Theme.Size.touch / 2)
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { drag in
                        let origin = start ?? position
                        start = origin
                        store.set(address, normalized: origin + Double(drag.translation.width / (Self.width * 2)), gesture: true)
                    }
                    .onEnded { _ in
                        start = nil
                        store.endGesture()
                    }
            )
            .onTapGesture(count: 2) { store.reset(address) }
            .accessibilityElement()
            .accessibilityLabel(descriptor.title)
            .accessibilityValue(ParameterFormat.text(value, unit: descriptor.unit))
            .accessibilityAdjustableAction { direction in
                store.set(address, normalized: position + (direction == .increment ? 0.05 : -0.05), gesture: false)
            }
            .midiLearnable(address)
        }
    }
}

/// A number you drag: label above, value below; drag up or down to change it (finer as the
/// finger moves away sideways is a later refinement), double-tap for the default. The one
/// numeric control for every parameter that is not a fader or a pan.
struct ParameterField: View {
    @Environment(ProjectStore.self) private var store
    let address: ParameterAddress
    @State private var start: Double?

    /// Points of vertical travel for the full range.
    private static let travel: CGFloat = 240

    var body: some View {
        if let descriptor = store.project.descriptor(for: address), let value = store.project.value(of: address) {
            let position = descriptor.normalized(value)
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(title(descriptor))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .lineLimit(1)
                Text(ParameterFormat.text(value, unit: descriptor.unit))
                    .font(Theme.Font.value)
                    .foregroundStyle(Theme.Color.text)
                    .lineLimit(1)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.Color.surfaceRaised)
                        Rectangle().fill(Theme.Color.accent)
                            .frame(width: geometry.size.width * CGFloat(position))
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
                        let origin = start ?? position
                        start = origin
                        store.set(address, normalized: origin - Double(drag.translation.height / Self.travel), gesture: true)
                    }
                    .onEnded { _ in
                        start = nil
                        store.endGesture()
                    }
            )
            .onTapGesture(count: 2) { store.reset(address) }
            .accessibilityElement()
            .accessibilityLabel(title(descriptor))
            .accessibilityValue(ParameterFormat.text(value, unit: descriptor.unit))
            .accessibilityAdjustableAction { direction in
                store.set(address, normalized: position + (direction == .increment ? 0.02 : -0.02), gesture: false)
            }
            .midiLearnable(address)
        }
    }

    /// The parameter's own name, without the track name the descriptor carries for lists.
    private func title(_ descriptor: ParameterDescriptor) -> String {
        if let target = address.key.sendTarget { return store.project.track(target).map { "→ \($0.name)" } ?? descriptor.title }
        return SynthParameter.named(address.key)?.title ?? descriptor.title
    }
}
