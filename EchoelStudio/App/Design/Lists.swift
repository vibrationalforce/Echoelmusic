import SwiftUI

/// The building blocks every sheet uses, so a settings page, the store, About and Connections
/// read as the studio and not as the Settings app: a black ground, rows on `surface`, hairline
/// separators, the brand face, the one accent only on what is on or chosen.
///
/// A page writes `List { EchoelSection("Title") { … } }.echoelList()`; inside a section, text is
/// `ParagraphText` (what a thing is) or `NoteText` (a quieter explanation, a warning, an error),
/// a read-only value is `ValueRow`, and a typed name or address is a `TextField` with
/// `.echoelInput()`. A number is never typed into a text field — it is a `ParameterField` on the
/// Echoel number pad.
extension View {
    /// Puts a `List` or `Form` on the studio's ground: no system grey, the brand face, rows at
    /// least one touch target high, Echoel's switch, the accent as tint (a picker's chosen value,
    /// a link), and a navigation bar of the same black.
    func echoelList() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.Color.background)
            .environment(\.defaultMinListRowHeight, Theme.Size.touch)
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Color.text)
            .tint(Theme.Color.accent)
            .toggleStyle(EchoelToggleStyle())
            .toolbarBackground(Theme.Color.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }

    /// A text field in Echoel's look — for words (a name, an address, a stream key), never for
    /// a number: the boundary of a control, the brand face, one touch target high.
    func echoelInput() -> some View {
        self
            .textFieldStyle(.plain)
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Color.text)
            .padding(.horizontal, Theme.Space.s)
            .frame(minHeight: Theme.Size.touch)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.Color.surfaceRaised))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .strokeBorder(Theme.Color.borderStrong, lineWidth: 1))
    }
}

/// A section of an Echoel list: rows on `surface` with hairline separators, the title in the
/// brand face as written (no forced capitals), an optional note under it.
struct EchoelSection<Content: View>: View {
    let title: String?
    let footer: String?
    let content: Content

    init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        Section {
            Group { content }
                .listRowBackground(Theme.Color.surface)
                .listRowSeparatorTint(Theme.Color.border)
        } header: {
            if let title {
                Text(title)
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .textCase(nil)
            }
        } footer: {
            if let footer {
                NoteText(footer)
            }
        }
    }
}

/// A sentence that explains: what a thing is, what happens when it is on.
struct ParagraphText: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Color.text)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, Theme.Space.xs)
    }
}

/// A quieter line under a control. Its tone says what kind: a plain note, a warning (orange),
/// or something that went wrong (red) — and the words always say it too, colour is never the
/// only cue.
struct NoteText: View {
    enum Tone {
        case note, warning, problem
    }

    let text: String
    var tone: Tone = .note

    init(_ text: String, tone: Tone = .note) {
        self.text = text
        self.tone = tone
    }

    var body: some View {
        Text(text)
            .font(Theme.Font.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, Theme.Space.xs)
    }

    private var color: Color {
        switch tone {
        case .note: Theme.Color.textSecondary
        case .warning: Theme.Color.warning
        case .problem: Theme.Color.record
        }
    }
}

/// A read-only value: its name on the left, the value on the right in tabular figures. One
/// element for VoiceOver ("Sample rate, 48 kHz").
struct ValueRow: View {
    let title: String
    let value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            Text(title)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
            Spacer(minLength: Theme.Space.s)
            Text(value)
                .font(Theme.Font.value)
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: Theme.Size.touch)
        .accessibilityElement(children: .combine)
    }
}

/// A plain action in a list row: its words in the text colour (red for a destructive one),
/// dimmed while pressed or disabled — no system blue, no grey highlight, no scaling. Set per
/// button (`.buttonStyle(EchoelRowButtonStyle())`), not for the whole list: a list-wide button
/// style would also restyle its navigation links.
struct EchoelRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        EchoelRowButtonFace(configuration: configuration)
    }
}

private struct EchoelRowButtonFace: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(Theme.Font.body)
            .foregroundStyle(configuration.role == .destructive ? Theme.Color.record : Theme.Color.text)
            .frame(minHeight: Theme.Size.touch)
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? Theme.Motion.pressedOpacity : 1) : 0.4)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
    }
}
