import EchoelCore
import SwiftUI
import UIKit

/// A number shown exactly (2026-11-27): its compact form where room is short — it ends in "…"
/// whenever digits are left out — and, on a long press, the full value in a menu that copies it. A
/// repeating digit carries a bar (0,53̅). VoiceOver reads the full value, the repeating digits in
/// words, after `name` when one is given.
struct ExactValueText: View {
    let text: ExactText
    let unit: String
    let name: String?
    let font: Font
    let color: Color

    init(_ text: ExactText, unit: String = "", name: String? = nil, font: Font = Theme.Font.value,
         color: Color = Theme.Color.text) {
        self.text = text
        self.unit = unit
        self.name = name
        self.font = font
        self.color = color
    }

    private var suffix: String { unit.isEmpty ? "" : " " + unit }

    var body: some View {
        Text(text.compact + suffix)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .contextMenu { ExactValueMenu(text: text, unit: unit) }
            .accessibilityLabel((name.map { $0 + ", " } ?? "") + text.spoken + suffix)
    }
}

/// What a long press on an exact value shows: the full value, and Copy.
struct ExactValueMenu: View {
    let text: ExactText
    let unit: String

    var body: some View {
        let full = text.full + (unit.isEmpty ? "" : " " + unit)
        Section(full) {
            Button("Copy \(full)", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = full
            }
        }
    }
}

/// A read-only exact value in a list row: its name on the left, the value on the right.
struct ExactValueRow: View {
    let title: String
    let text: ExactText
    let unit: String

    init(_ title: String, _ text: ExactText, unit: String = "") {
        self.title = title
        self.text = text
        self.unit = unit
    }

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            Text(title)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
            Spacer(minLength: Theme.Space.s)
            ExactValueText(text, unit: unit, name: title, color: Theme.Color.textSecondary)
        }
        .frame(minHeight: Theme.Size.touch)
    }
}
