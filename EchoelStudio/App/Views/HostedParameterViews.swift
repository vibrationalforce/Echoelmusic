import EchoelCore
import EchoelHost
import SwiftUI

/// The parameters of a hosted unit that brings no interface of its own, as value fields (the
/// look of `ParameterField`): a field per number, a menu per named choice. They move the unit
/// through the writer like a plugin's own knobs, so automation writing and MIDI learn reach them.
/// The list is read on a load; each value is read in its own field.
struct HostedParameterGrid: View {
    @Environment(AudioEngine.self) private var engine
    let slot: PluginHost.Slot
    /// The narrowest column, as on the Sound page: it grows with the text, so the fields go to one
    /// column at large sizes instead of cutting their words.
    @ScaledMetric(relativeTo: .body) private var columnWidth: CGFloat = 150

    var body: some View {
        let host = engine.plugins
        let rows = host.parameterRows(slot)
        if rows.isEmpty {
            Text("It has no parameters to set here.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: columnWidth), spacing: Theme.Space.s)],
                      alignment: .leading, spacing: Theme.Space.s) {
                ForEach(rows) { row in
                    if let address = host.parameterAddress(row.address, in: slot) {
                        cell(row, address: address)
                    }
                }
            }
        }
    }

    @ViewBuilder private func cell(_ row: HostedParameters.Row, address: ParameterAddress) -> some View {
        if row.choices.isEmpty {
            HostedParameterField(address: address, row: row)
        } else {
            HostedChoiceField(address: address, row: row)
        }
    }
}

/// The box every field of the grid sits in: label above, value below.
private struct HostedFieldFace: View {
    let title: String
    let value: String
    let place: Double?
    var engaged = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .lineLimit(2)
            Text(value)
                .font(Theme.Font.value)
                .foregroundStyle(place == nil ? Theme.Color.textSecondary : (engaged ? Theme.Color.accent : Theme.Color.text))
                .lineLimit(1)
            if let place {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.Color.surfaceRaised)
                        Rectangle().fill(Theme.Color.accent).frame(width: geometry.size.width * CGFloat(place))
                    }
                }
                .frame(height: 3)
                .accessibilityHidden(true)
            }
        }
        .padding(Theme.Space.s)
        .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.Color.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium)
            .strokeBorder(engaged ? Theme.Color.accent : Theme.Color.borderStrong, lineWidth: 1))
        .animation(Theme.Motion.quick, value: engaged)
    }
}

/// One number of the unit: drag up or down — slowly for fine steps — or tap to type it on the
/// number pad. The value lives in the unit, so this leaf reads it, often enough to follow
/// automation and MIDI; nothing above it is redrawn.
private struct HostedParameterField: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(ParameterWriter.self) private var writer
    @Environment(NumberPadController.self) private var pad: NumberPadController?
    let address: ParameterAddress
    let row: HostedParameters.Row
    /// The drag in progress: the place it has reached and the translation last read.
    @State private var drag: (place: Double, translation: CGFloat)?

    private static let travel: CGFloat = 240

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 15)) { _ in
            field(position: engine.plugins.position(of: address))
        }
    }

    private var owner: String { "\(address)" }

    @ViewBuilder private func field(position: Double?) -> some View {
        let place = position ?? 0
        let shown = row.value(atPosition: place) ?? row.range.lowerBound
        let engaged = drag != nil || pad?.request?.owner == owner
        HostedFieldFace(title: row.name, value: position == nil ? "–" : text(shown), place: position, engaged: engaged)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { gesture in
                        let reached = drag ?? (place: place, translation: 0)
                        let moved = gesture.translation.height - reached.translation
                        let scale = DragPrecision.scale(speed: Double(gesture.velocity.height))
                        let next = Swift.min(Swift.max(reached.place - Double(moved / Self.travel) * scale, 0), 1)
                        drag = (place: next, translation: gesture.translation.height)
                        writer.set(address, normalized: next, gesture: true)
                    }
                    .onEnded { _ in
                        drag = nil
                        writer.endGesture()
                    }
            )
            .onTapGesture { openPad(shown) }
            .accessibilityElement()
            .accessibilityLabel(row.name)
            .accessibilityValue(position == nil ? "Not loaded" : text(shown))
            .accessibilityAdjustableAction { direction in
                let moved = Swift.min(Swift.max(place + (direction == .increment ? 0.02 : -0.02), 0), 1)
                writer.set(address, normalized: moved, gesture: false)
            }
            // VoiceOver's double-tap is the tap's own action: type the value.
            .accessibilityAction { openPad(shown) }
            .accessibilityAction(named: "Type a Value") { openPad(shown) }
            .midiLearnable(address, title: row.name)
    }

    /// Two places for a small span, none for a wide one: "0.50", "-6.0 dB", "1200 Hz".
    private var decimals: Int {
        let span = row.range.upperBound - row.range.lowerBound
        return span <= 2 ? 2 : (span <= 100 ? 1 : 0)
    }

    private func text(_ value: Float) -> String {
        row.unitName.isEmpty ? NumberText.string(Double(value), decimals: decimals)
            : NumberText.string(Double(value), decimals: decimals, unit: row.unitName)
    }

    /// The pad in the unit's own numbers; what is typed is clamped to the range on the way in.
    private func openPad(_ shown: Float) {
        guard let pad else { return }
        let target = address
        let writer = writer
        let range = row.range
        let lower = Double(range.lowerBound), upper = Double(range.upperBound)
        pad.open(NumberPadRequest(owner: owner, title: row.name,
                                  format: NumberEntryFormat(scale: 1, decimals: decimals, unit: row.unitName),
                                  range: lower...upper, value: Double(shown), standard: nil) { typed in
            guard typed.isFinite, upper > lower else { return }
            writer.set(target, normalized: Swift.min(Swift.max((typed - lower) / (upper - lower), 0), 1), gesture: false)
            writer.endGesture()
        })
    }
}

/// One named choice of the unit, as a menu with the current one checked. The choice is read from
/// the unit when the menu is built and in its label, never watched.
private struct HostedChoiceField: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(ParameterWriter.self) private var writer
    let address: ParameterAddress
    let row: HostedParameters.Row
    /// Counts this field's picks, so the menu is built again with the choice just made checked.
    @State private var picks = 0

    var body: some View {
        let chosen = currentChoice(after: picks)
        Menu {
            ForEach(row.choices.indices, id: \.self) { index in
                Button { pick(index) } label: {
                    if row.choices[index] == chosen {
                        Label(row.choices[index], systemImage: "checkmark")
                    } else {
                        Text(row.choices[index])
                    }
                }
            }
        } label: {
            TimelineView(.periodic(from: .now, by: 1.0 / 15)) { _ in
                let choice = currentChoice(after: picks)
                HostedFieldFace(title: row.name, value: choice ?? "–", place: nil)
                    .accessibilityValue(choice ?? "Not loaded")
            }
        }
        .accessibilityLabel(row.name)
        .midiLearnable(address, title: row.name)
    }

    /// The unit's choice now, or nil before it loads. `picks` only ties the read to the last pick.
    private func currentChoice(after picks: Int) -> String? {
        guard picks >= 0, let position = engine.plugins.position(of: address), let value = row.value(atPosition: position)
        else { return nil }
        return row.choice(at: value)
    }

    private func pick(_ index: Int) {
        guard let position = row.position(ofChoice: index) else { return }
        writer.set(address, normalized: position, gesture: false)
        picks &+= 1
    }
}
