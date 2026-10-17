import EchoelCore
import SwiftUI

/// MIDI Learn on any parameter control: while learning, a tap chooses the control as the target
/// (outlined in the accent colour) and the next knob or fader moved on the controller is mapped
/// to it. A mapped control carries a small outline and a menu entry to forget it.
private struct MIDILearnable: ViewModifier {
    @Environment(MIDIInput.self) private var midi
    let address: ParameterAddress

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
                        .accessibilityLabel(mapped.map { "Mapped to \($0.description)" } ?? "Not mapped")
                        .accessibilityHint("Move a control on your MIDI device to map it here")
                        .accessibilityAddTraits(.isButton)
                }
            }
            .contextMenu {
                if let mapped {
                    Button("Forget \(mapped.description)", systemImage: "xmark") { midi.forget(address) }
                }
            }
    }
}

extension View {
    func midiLearnable(_ address: ParameterAddress) -> some View {
        modifier(MIDILearnable(address: address))
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
        .buttonStyle(ToolButtonStyle(isActive: midi.isLearning))
        .accessibilityLabel("MIDI Learn")
        .accessibilityValue(midi.isLearning ? "On" : "Off")
        .accessibilityHint("Tap a control, then move a knob on your MIDI device")
    }
}
