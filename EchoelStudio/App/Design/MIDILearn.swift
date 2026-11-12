import EchoelCore
import SwiftUI

/// MIDI Learn on any parameter control: while learning, a tap chooses the control as the target
/// (outlined in the accent colour) and the next knob or fader moved on the controller is mapped
/// to it. A mapped control carries a small outline and a menu entry to forget it.
private struct MIDILearnable: ViewModifier {
    @Environment(MIDIInput.self) private var midi
    let address: ParameterAddress
    /// The control's own name: while learning, VoiceOver says which control it chooses and what it
    /// is mapped to, not a bare "Not mapped" (W18, m21).
    let title: String

    func body(content: Content) -> some View {
        let mapped = midi.mapping(for: address)
        let isTarget = midi.isLearning && midi.learnTarget == address
        content
            .overlay {
                if midi.isLearning {
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .stroke(isTarget ? Theme.Color.accent : Theme.Color.border,
                                style: StrokeStyle(lineWidth: isTarget ? 2 : 1, dash: mapped == nil ? [4, 3] : []))
                        .contentShape(Rectangle())
                        .onTapGesture { midi.choose(address) }
                        .accessibilityLabel(title)
                        .accessibilityValue(mapped.map { "Mapped to \(Spoken.control($0))" } ?? "Not mapped")
                        .accessibilityHint(isTarget ? "Waits for a knob or fader on your MIDI device."
                                                    : "Chooses this control for the next knob or fader you move.")
                        .accessibilityAddTraits(isTarget ? [.isButton, .isSelected] : .isButton)
                }
            }
            .contextMenu {
                if let mapped {
                    Button("Forget \(mapped.description)", systemImage: "xmark") { midi.forget(address) }
                        .accessibilityLabel("Forget \(Spoken.control(mapped))")
                }
            }
    }
}

extension View {
    /// `title` is the control's name as VoiceOver says it ("Bass Volume", "Send to Return 1").
    func midiLearnable(_ address: ParameterAddress, title: String) -> some View {
        modifier(MIDILearnable(address: address, title: title))
    }
}

/// The transport's MIDI Learn switch, and what it is waiting for.
struct MIDILearnButton: View {
    @Environment(MIDIInput.self) private var midi

    var body: some View {
        Button {
            midi.setLearning(!midi.isLearning)
        } label: {
            Text("MIDI")
                .font(Theme.Font.label)
        }
        .buttonStyle(BarCellStyle(isActive: midi.isLearning, padsLabel: true))
        .accessibilityLabel("MIDI Learn")
        .accessibilityValue(midi.isLearning ? "On" : "Off")
        .accessibilityHint("Tap a control, then move a knob on your MIDI device.")
    }
}
