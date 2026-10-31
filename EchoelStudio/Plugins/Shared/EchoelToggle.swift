import SwiftUI

/// The one switch style. The system switch is a green pill with a sliding knob; Echoel's is a
/// small rectangle with the earlier instrument's radius: bio-green when on (the accent means
/// "active"), a raised surface with a control boundary when off. The knob does not slide — it
/// fades from one end to the other, because motion here is opacity and colour only. Colour is
/// never the only cue: the knob's end says on or off, and VoiceOver hears a switch with its value.
///
/// It lives in `Plugins/Shared` and draws from `EchoelBrand`, so the app and the AUv3 extension
/// compile the same switch (`project.yml`: the app lists it by path) — a toggle in a host's plugin
/// window is the Studio's toggle.
///
/// Set once for a page with `.echoelList()` (or `.toggleStyle(EchoelToggleStyle())`). A toggle
/// inside a `Menu` is drawn by the system as a checkmark row, and that is right.
struct EchoelToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        EchoelToggleRow(configuration: configuration)
    }
}

/// The row a toggle draws: its label, then the switch, the whole row one touch target.
private struct EchoelToggleRow: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: EchoelBrand.Space.m) {
                configuration.label
                    .font(EchoelBrand.Font.body)
                    .foregroundStyle(EchoelBrand.Color.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                EchoelSwitch(isOn: configuration.isOn)
            }
            .frame(minHeight: EchoelBrand.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

/// The switch itself, drawn from the theme.
struct EchoelSwitch: View {
    let isOn: Bool

    private static let width: CGFloat = 46
    private static let height: CGFloat = 26
    private static let inset: CGFloat = 3

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: EchoelBrand.Radius.medium)
                .fill(isOn ? EchoelBrand.Color.accent : EchoelBrand.Color.surfaceRaised)
            RoundedRectangle(cornerRadius: EchoelBrand.Radius.medium)
                .strokeBorder(EchoelBrand.Color.borderStrong, lineWidth: 1)
                .opacity(isOn ? 0 : 1)
            HStack(spacing: 0) {
                knob.opacity(isOn ? 0 : 1)
                Spacer(minLength: 0)
                knob.opacity(isOn ? 1 : 0)
            }
            .padding(Self.inset)
        }
        .frame(width: Self.width, height: Self.height)
        .animation(EchoelBrand.Motion.quick, value: isOn)
        .accessibilityHidden(true)
    }

    private var knob: some View {
        RoundedRectangle(cornerRadius: EchoelBrand.Radius.small)
            .fill(isOn ? EchoelBrand.Color.onAccent : EchoelBrand.Color.textSecondary)
            .frame(width: Self.height - 2 * Self.inset, height: Self.height - 2 * Self.inset)
    }
}
