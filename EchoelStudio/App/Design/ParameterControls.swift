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
        }
    }
}
