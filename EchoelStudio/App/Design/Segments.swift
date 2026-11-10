import SwiftUI

/// One name in a row of `EchoelSegments`.
struct SegmentOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String

    var id: Value { value }

    init(_ value: Value, _ title: String) {
        self.value = value
        self.title = title
    }
}

/// A choice between a few named values, in the app's own look: one row of equal cells inside a
/// control's boundary, the chosen cell an off-white tile under a black label — the language of the
/// bar of views and of a switched-on button. It stands where the system's segmented control stood,
/// which was the one grey pill left on pages that are otherwise Echoel's.
///
/// For two to five short names. A longer list is a menu (the Sound page's engine), never a row
/// that squeezes its words. The title is not drawn — the row's place says what is chosen, as the
/// system's control did — and is what VoiceOver calls the group.
struct EchoelSegments<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [SegmentOption<Value>]
    @Environment(\.isEnabled) private var isEnabled

    init(_ title: String, selection: Binding<Value>, options: [SegmentOption<Value>]) {
        self.title = title
        _selection = selection
        self.options = options
    }

    var body: some View {
        // Laid on the boundary's colour with a hairline between, so the gaps draw the dividers.
        HStack(spacing: Theme.Space.hairline) {
            ForEach(options) { option in
                cell(option)
            }
        }
        .background(Theme.Color.borderStrong)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .strokeBorder(Theme.Color.borderStrong, lineWidth: 1)
        )
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func cell(_ option: SegmentOption<Value>) -> some View {
        let isChosen = option.value == selection
        return Button {
            selection = option.value
        } label: {
            Text(option.title)
                .font(Theme.Font.label)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, Theme.Space.xs)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
        }
        .buttonStyle(SegmentCellStyle(isChosen: isChosen))
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

/// A cell of `EchoelSegments`: the chosen one is the off-white tile, the others the raised
/// surface; a press dims it, nothing moves.
private struct SegmentCellStyle: ButtonStyle {
    let isChosen: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isChosen ? Theme.Color.onAccent : Theme.Color.text)
            .background(isChosen ? Theme.Color.text : Theme.Color.surfaceRaised)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? Theme.Motion.pressedOpacity : 1)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
            .accessibilityShowsLargeContentViewer()
    }
}
