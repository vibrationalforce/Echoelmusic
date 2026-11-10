import EchoelCore
import Observation
import SwiftUI
import UIKit

/// One value to type: what the field shows, in the parameter's own units, and where the typed
/// number goes. The pad converts to the units a musician types (ms, %, Hz) and back.
struct NumberPadRequest: Identifiable {
    let id = UUID()
    /// The field that asked, so it can show that it is being typed into.
    let owner: String
    let title: String
    let format: NumberEntryFormat
    let range: ClosedRange<Double>
    let value: Double
    let standard: Double?
    let commit: @MainActor (Double) -> Void
}

/// Who is typing, for one page. Not a presentation: the pad docks at the bottom of the page that
/// hosts it, like a keyboard, so a field inside a sheet types without a sheet of its own (Law 7).
@MainActor
@Observable
final class NumberPadController {
    private(set) var request: NumberPadRequest?
    /// What VoiceOver was on when the pad opened — the field that asked for it — so closing the
    /// pad gives that field its focus back instead of dropping it somewhere on the page
    /// (accessibility audit 2026-11-01, M6). Every field that types opens the pad here, so none
    /// of them needs to know.
    @ObservationIgnored private var focusBeforeOpening: Any?

    func open(_ request: NumberPadRequest) {
        focusBeforeOpening = UIAccessibility.isVoiceOverRunning
            ? UIAccessibility.focusedElement(using: .notificationVoiceOver) : nil
        self.request = request
    }

    func close() {
        request = nil
        guard let field = focusBeforeOpening else { return }
        focusBeforeOpening = nil
        UIAccessibility.post(notification: .layoutChanged, argument: field)
    }
}

extension View {
    /// Gives the fields on this page a number pad, docked at its bottom edge.
    func numberPadHost() -> some View {
        modifier(NumberPadHost())
    }
}

private struct NumberPadHost: ViewModifier {
    @State private var controller = NumberPadController()

    func body(content: Content) -> some View {
        content
            .environment(controller)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let request = controller.request {
                    NumberPad(request: request, close: controller.close)
                        .id(request.id)
                        .transition(.opacity)
                }
            }
            .animation(Theme.Motion.quick, value: controller.request?.id)
    }
}

/// Echoel's own number pad, from the earlier instrument: the typed number large, its unit and
/// range below the title, a Default key, and the keys — 7 8 9 · 4 5 6 · 1 2 3 · − 0 ⌫ · + , OK.
/// − makes the value negative and + positive (the system decimal pad has no sign key); − is off
/// where the range cannot go below zero, the separator where the value is whole. With VoiceOver,
/// focus moves to the number when the pad opens, every key says the number it made, and closing
/// returns focus to the field (accessibility audit 2026-11-01, M6, m18).
struct NumberPad: View {
    let request: NumberPadRequest
    let close: () -> Void
    @State private var entry: NumberEntry
    @AccessibilityFocusState private var numberFocused: Bool

    init(request: NumberPadRequest, close: @escaping () -> Void) {
        self.request = request
        self.close = close
        _entry = State(initialValue: request.format.entry(for: request.range))
    }

    private static let separator = Locale.current.decimalSeparator ?? "."

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            header
            keys
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity)
        .background(Theme.Color.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Color.border).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Number pad, \(request.title)")
        .accessibilityAction(.escape, close)
        // The pad docks like a keyboard, out of VoiceOver's path: take its focus to the number,
        // once the pad has faded in and the number is there to take it.
        .task {
            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            numberFocused = true
        }
        // A key changes the number, not the key VoiceOver is on: say the number it made.
        .onChange(of: entry.text) {
            // Normal priority: the next key cuts it short, so fast typing never queues old numbers.
            Theme.Accessibility.announce(Announcement(typedNumber, priority: .normal))
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack(spacing: Theme.Space.s) {
                // Wraps instead of cutting a long name off at large text sizes (m18).
                Text(request.title)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Cancel", action: close)
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Color.text)
                    .frame(minHeight: Theme.Size.touch)
            }
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
                Text(shownNumber)
                    .font(Theme.Font.display)
                    .foregroundStyle(entry.isEmpty ? Theme.Color.textSecondary : Theme.Color.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityLabel(entry.isEmpty ? "Current value \(withUnit(shownNumber))"
                                                      : "Typed \(withUnit(shownNumber))")
                    .accessibilityFocused($numberFocused)
                if !request.format.unit.isEmpty {
                    Text(request.format.unit)
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 0)
                if let standard = request.standard { defaultKey(standard) }
            }
            Text(rangeText)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textTertiary)
        }
    }

    private var shownNumber: String {
        if entry.isEmpty { return number(request.format.display(request.value)) }
        return entry.text.replacingOccurrences(of: ".", with: Self.separator)
    }

    /// What a key's press says: the number typed so far, or — all of it deleted — the value OK
    /// would keep.
    private var typedNumber: String {
        entry.isEmpty ? "Current value \(withUnit(shownNumber))" : withUnit(shownNumber)
    }

    private func withUnit(_ number: String) -> String {
        request.format.unit.isEmpty ? number : "\(number) \(request.format.unit)"
    }

    private var rangeText: String {
        let range = request.format.displayRange(request.range)
        let unit = request.format.unit.isEmpty ? "" : " \(request.format.unit)"
        return "Range \(number(range.lowerBound)) to \(number(range.upperBound))\(unit)"
    }

    private func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(request.format.decimals)).grouping(.never))
    }

    private func defaultKey(_ standard: Double) -> some View {
        let shown = request.format.display(standard)
        let current = NumberEntry.snapped(request.format.display(request.value), to: entry.range, decimals: entry.decimals)
        let atDefault = entry.value(else: current) == NumberEntry.snapped(shown, to: entry.range, decimals: entry.decimals)
        return Button {
            entry.show(shown)
        } label: {
            Label("Default \(number(shown))", systemImage: "arrow.counterclockwise")
                .font(Theme.Font.caption)
                .foregroundStyle(atDefault ? Theme.Color.textTertiary : Theme.Color.text)
                .padding(.horizontal, Theme.Space.s)
                .frame(minHeight: Theme.Size.touch)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.Color.surfaceRaised))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).strokeBorder(Theme.Color.borderStrong, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(atDefault)
        .accessibilityLabel("Default \(number(shown)) \(request.format.unit)")
        .accessibilityHint("Types the default; OK confirms it.")
    }

    // MARK: Keys

    private var keys: some View {
        Grid(horizontalSpacing: Theme.Space.s, verticalSpacing: Theme.Space.s) {
            GridRow { digit(7); digit(8); digit(9) }
            GridRow { digit(4); digit(5); digit(6) }
            GridRow { digit(1); digit(2); digit(3) }
            GridRow {
                key(enabled: entry.allowsNegative, label: "Make Negative", action: { entry.setNegative(true) }) {
                    Image(systemName: "minus")
                }
                digit(0)
                key(label: "Delete", action: { entry.deleteLast() }) { Image(systemName: "delete.left") }
            }
            GridRow {
                key(enabled: entry.allowsNegative, label: "Make Positive", action: { entry.setNegative(false) }) {
                    Image(systemName: "plus")
                }
                key(enabled: entry.allowsDecimal, label: "Decimal Separator", action: { entry.typeDecimal() }) {
                    Text(Self.separator)
                }
                key(primary: true, label: "OK, set \(request.title)", action: commit) { Text("OK") }
            }
        }
    }

    private func digit(_ value: Int) -> some View {
        key(label: String(value), action: { entry.type(value) }) { Text(String(value)) }
    }

    private func key<Face: View>(enabled: Bool = true, primary: Bool = false, label: String,
                                  action: @escaping () -> Void, @ViewBuilder _ face: () -> Face) -> some View {
        Button(action: action) {
            face()
                .font(Theme.Font.valueLarge)
                .foregroundStyle(primary ? Theme.Color.onAccent : Theme.Color.text)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
                // OK is the pad's main action, so it is the off-white tile: the pad opens from every
                // number in the app, and the green is kept for what the body and the song do.
                .background(RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .fill(primary ? Theme.Color.text : Theme.Color.surfaceRaised))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .strokeBorder(Theme.Color.borderStrong, lineWidth: primary ? 0 : 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(NumberKeyStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func commit() {
        if !entry.isEmpty {
            let typed = entry.value(else: request.format.display(request.value))
            request.commit(request.format.parameter(fromDisplay: typed))
        }
        close()
    }
}

/// A key dims while pressed and when it cannot be used; it never scales.
private struct NumberKeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        NumberKeyFace(configuration: configuration)
    }
}

private struct NumberKeyFace: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? Theme.Motion.pressedOpacity : 1) : 0.35)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
    }
}
