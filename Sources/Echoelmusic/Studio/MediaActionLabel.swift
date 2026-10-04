// MediaActionLabel.swift
// Echoel — the one button face of the media cards ("Choose Photo", "Apply to Visuals", "Undo").
//
// WHY A VIEW TYPE AND NOT A HELPER METHOD ON THE CARD. `PhotoSeedCard` and `VideoSeedCard` are
// `@MainActor` structs, so a private `func actionLabel(...) -> some View` on them is a main-actor-
// isolated method. `PhotosPicker(selection:matching:)` builds its label in a closure that is NOT
// main-actor-isolated, and returning a non-Sendable `some View` from an isolated method into that
// closure is a hard error under Swift 6 — both gates were red on exactly that line
// (`PhotoSeedCard.swift:151`, `VideoSeedCard.swift:177`, run 36351836760). The `Button` label
// closures never saw it because SwiftUI builds those on the main actor.
//
// A `View` STRUCT has no such boundary: its initialiser is nonisolated and stores two `String`s
// (implicitly `Sendable`), and its `body` runs on the main actor like every other view. No
// `nonisolated`, no `@preconcurrency`, no `@unchecked Sendable` — the type simply sits where the
// isolation wants it. The two cards carried a byte-identical copy of this helper each; one type
// replaces both.
#if canImport(SwiftUI)
import SwiftUI

struct MediaActionLabel: View {
    // E4-15 (2026-09-30): drawn as a catalog KEY below — `Text(String)` spelled the three media actions
    // verbatim on a German phone. Stays `String` so the `MediaActionLabel(title: "…")` sites and
    // the guards that count them do not move.
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(EchoelTheme.font(13, .semibold))
            Text(LocalizedStringKey(title)).font(EchoelTheme.font(13, .semibold))
        }
        .foregroundStyle(EchoelTheme.text)
        .padding(.horizontal, 14)
        .frame(minWidth: 92, minHeight: 44)
        .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
            .strokeBorder(EchoelTheme.border, lineWidth: 1))
        .contentShape(Rectangle())
    }
}
#endif
