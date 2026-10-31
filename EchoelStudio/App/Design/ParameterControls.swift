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
            return value <= MixerStrip.volumeRange.lowerBound ? "−∞ dB" : NumberText.string(value, decimals: 1, unit: "dB")
        case .pan:
            let percent = Int((abs(value) * 100).rounded())
            return percent == 0 ? "C" : (value < 0 ? "L\(percent)" : "R\(percent)")
        case .bpm:
            return NumberText.string(value, decimalsUpTo: 2, unit: "BPM")
        case .hertz:
            return value >= 1_000 ? NumberText.string(value / 1_000, decimals: 2, unit: "kHz") : NumberText.string(value, decimals: 0, unit: "Hz")
        case .seconds:
            return value >= 1 ? NumberText.string(value, decimals: 2, unit: "s") : NumberText.string(value * 1_000, decimals: 0, unit: "ms")
        case .octaves:
            return NumberText.string(value, decimals: 1, unit: "oct")
        case .amount:
            return NumberText.string(value, decimals: 2)
        case .choice:
            return String(Int(value.rounded()))
        }
    }

    /// As `text(_:unit:)`, and a whole number shows whole: the sampler's root key is a note
    /// (C4), any other stepped number an integer, never "60.00".
    static func text(_ value: Double, descriptor: ParameterDescriptor) -> String {
        if descriptor.address.key == SynthParameter.samplerRoot.key {
            return NoteEditing.name(of: Int(value.rounded()))
        }
        if descriptor.taper == .stepped, descriptor.unit == .amount { return String(Int(value.rounded())) }
        return text(value, unit: descriptor.unit)
    }
}

/// A vertical fader. Drag anywhere on it to set the level (the console law puts 0 dB at
/// about 80 % of the travel); double-tap returns to 0 dB.
struct Fader: View {
    @Environment(ProjectStore.self) private var store
    @Environment(ParameterWriter.self) private var writer
    let address: ParameterAddress
    /// What an automation pass wrote under the finger, which the song's own value does not
    /// follow; the strip's level readout shows it too.
    @Binding var passed: Double?
    var height: CGFloat = 180

    private static let width: CGFloat = 44
    private static let thumbHeight: CGFloat = 12

    var body: some View {
        if let descriptor = store.project.descriptor(for: address), let stored = store.project.value(of: address) {
            let value = passed ?? stored
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
                        passed = writer.set(address, normalized: Double(n), gesture: true)
                    }
                    .onEnded { _ in
                        passed = nil
                        writer.endGesture()
                    }
            )
            .onTapGesture(count: 2) { writer.reset(address) }
            .accessibilityElement()
            .accessibilityLabel(descriptor.title)
            .accessibilityValue(ParameterFormat.text(value, unit: descriptor.unit))
            .accessibilityAdjustableAction { direction in
                let step = direction == .increment ? 0.02 : -0.02
                writer.set(address, normalized: position + step, gesture: false)
            }
            .midiLearnable(address)
        }
    }
}

/// A horizontal pan control: drag left or right from where it is; double-tap centres it.
struct PanControl: View {
    @Environment(ProjectStore.self) private var store
    @Environment(ParameterWriter.self) private var writer
    let address: ParameterAddress
    @State private var start: Double?
    /// What an automation pass wrote under the finger (see `Fader.passed`).
    @State private var passed: Double?

    private static let width: CGFloat = 64

    var body: some View {
        if let descriptor = store.project.descriptor(for: address), let stored = store.project.value(of: address) {
            let value = passed ?? stored
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
                        passed = writer.set(address, normalized: origin + Double(drag.translation.width / (Self.width * 2)), gesture: true)
                    }
                    .onEnded { _ in
                        start = nil
                        passed = nil
                        writer.endGesture()
                    }
            )
            .onTapGesture(count: 2) { writer.reset(address) }
            .accessibilityElement()
            .accessibilityLabel(descriptor.title)
            .accessibilityValue(ParameterFormat.text(value, unit: descriptor.unit))
            .accessibilityAdjustableAction { direction in
                writer.set(address, normalized: position + (direction == .increment ? 0.05 : -0.05), gesture: false)
            }
            .midiLearnable(address)
        }
    }
}

/// A number you drag or type — the earlier instrument's value field. Label above, value below,
/// a thin bar for where it sits in its range. Drag up or down: slowly for fine steps, quickly to
/// cover the range (`DragPrecision`), with a tick under the finger at either end and at the
/// default. Tap to type it on Echoel's number pad (when the page hosts one); double-tap for the
/// default. The one numeric control for every parameter that is not a fader or a pan; a
/// parameter with named values is a picker instead.
struct ParameterField: View {
    @Environment(ProjectStore.self) private var store
    @Environment(ParameterWriter.self) private var writer
    @Environment(NumberPadController.self) private var pad: NumberPadController?
    let address: ParameterAddress
    /// The drag in progress: the control position it has reached and the translation last read.
    @State private var drag: (position: Double, translation: CGFloat)?
    /// What an automation pass wrote under the finger (see `Fader.passed`).
    @State private var passed: Double?

    /// Points of vertical travel for the full range at full speed.
    private static let travel: CGFloat = 240

    var body: some View {
        if let descriptor = store.project.descriptor(for: address), let stored = store.project.value(of: address) {
            field(descriptor, value: passed ?? stored)
        }
    }

    private var owner: String { "\(address)" }

    private var isTyped: Bool { pad?.request?.owner == owner }

    @ViewBuilder private func field(_ descriptor: ParameterDescriptor, value: Double) -> some View {
        let position = descriptor.normalized(value)
        let engaged = drag != nil || isTyped
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title(descriptor))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .lineLimit(1)
            Text(ParameterFormat.text(value, descriptor: descriptor))
                .font(Theme.Font.value)
                .foregroundStyle(engaged ? Theme.Color.accent : Theme.Color.text)
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
        // A control's boundary (3.6:1), the accent while it is held or typed into.
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium)
            .strokeBorder(engaged ? Theme.Color.accent : Theme.Color.borderStrong, lineWidth: 1))
        .animation(Theme.Motion.quick, value: engaged)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { gesture in
                    let reached = drag ?? (position: position, translation: 0)
                    let moved = gesture.translation.height - reached.translation
                    let scale = DragPrecision.scale(speed: Double(gesture.velocity.height))
                    let next = Swift.min(Swift.max(reached.position - Double(moved / Self.travel) * scale, 0), 1)
                    drag = (position: next, translation: gesture.translation.height)
                    passed = writer.set(address, normalized: next, gesture: true)
                }
                .onEnded { _ in
                    drag = nil
                    passed = nil
                    writer.endGesture()
                }
        )
        .onTapGesture(count: 2) { writer.reset(address) }
        .onTapGesture { openPad(descriptor, value: value) }
        .sensoryFeedback(.selection, trigger: value) { old, new in
            drag != nil && DragPrecision.reachesDetent(from: old, to: new, standard: descriptor.defaultValue,
                                                       range: descriptor.range)
        }
        .accessibilityElement()
        .accessibilityLabel(title(descriptor))
        .accessibilityValue(ParameterFormat.text(value, descriptor: descriptor))
        .accessibilityAdjustableAction { direction in
            let step = Self.step(descriptor)
            writer.set(address, normalized: position + (direction == .increment ? step : -step), gesture: false)
        }
        .accessibilityAction(named: "Type a Value") { openPad(descriptor, value: value) }
        .midiLearnable(address)
    }

    /// The pad for this field, typed in the unit a musician reads (ms, %, Hz).
    private func openPad(_ descriptor: ParameterDescriptor, value: Double) {
        pad?.type(address, descriptor: descriptor, value: value, title: title(descriptor), owner: owner, writer: writer)
    }

    /// One VoiceOver swipe: one whole step of a stepped value (a semitone of the root key), else
    /// 2 % of the travel.
    private static func step(_ descriptor: ParameterDescriptor) -> Double {
        let span = descriptor.range.upperBound - descriptor.range.lowerBound
        return descriptor.taper == .stepped && span > 0 ? 1 / span : 0.02
    }

    /// The parameter's own name, without the track name the descriptor carries for lists.
    private func title(_ descriptor: ParameterDescriptor) -> String {
        if let target = address.key.sendTarget { return store.project.track(target).map { "→ \($0.name)" } ?? descriptor.title }
        return SynthParameter.builtIn(address.key)?.title ?? descriptor.title
    }
}

extension NumberPadController {
    /// Opens the pad for a song parameter; the typed value goes through the writer, like a drag,
    /// as one undo step. A named choice is not typed (it is a picker), so nothing opens.
    func type(_ address: ParameterAddress, descriptor: ParameterDescriptor, value: Double, title: String,
              owner: String, writer: ParameterWriter) {
        guard let format = NumberEntryFormat(descriptor) else { return }
        open(NumberPadRequest(owner: owner, title: title, format: format, range: descriptor.range,
                              value: value, standard: descriptor.defaultValue) { typed in
            writer.set(address, to: typed, coalescingKey: nil)
            writer.endGesture()
        })
    }
}
