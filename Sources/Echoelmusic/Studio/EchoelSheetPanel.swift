//
//  EchoelSheetPanel.swift
//  Echoelmusic — Studio
//
//  One consistent NON-MODAL panel presentation for every tool/editor SHEET (Echoel
//  CI = one treatment everywhere). Instead of a hard full-screen modal that hides the
//  instrument, a sheet wearing `.echoelSheetPanel()`:
//    • opens at HALF height (.medium), where the instrument behind stays VISIBLE and
//      INTERACTIVE (pro-media HUD pattern — keep performing while a panel is open),
//    • drags up to full height (.large) when an editor wants the room.
//  ⭐ Founder 2026-10-01: "Viele Bereiche sind zu groß und füllen den Bildschirm aus." The
//  default was `.large` until then. Because the background is now live from the first frame,
//  the studio disables every other sheet/alert door while one of these is up
//  (`EchoelStudioView.panelSheetUp`) — the two-modals hang law.
//    • shows a grab handle so it reads as draggable/dismissable (WCAG 2.2: a visible
//      affordance, not a hidden gesture),
//    • backs with a semi-transparent solid (NOT glass/blur — Uncodixfy-compliant).
//
//  Evidence base: accessible physical computing + professional media production favour
//  persistent, non-modal, edge-reachable control surfaces over stacked modal screens.
//
//  Apply INSIDE a `.sheet { … }` content closure. Do NOT apply to views that manage
//  their OWN `presentationDetents` (e.g. LearnView) — double-declaring conflicts.
//

#if canImport(SwiftUI)
import SwiftUI

struct EchoelSheetPanelModifier: ViewModifier {
    /// Per-presentation detent; starts at half height so the work area stays visible and
    /// playable, and the user pulls it up when an editor needs the room.
    @State private var detent: PresentationDetent = .medium

    func body(content: Content) -> some View {
        content
            // ⛔ #1027 — a `.readableWidth()` cap stood here (#1025) and is removed on
            // founder order: he wants every view to FILL the screen. A sheet gets its
            // width from its presentation, and this modifier no longer takes any of it
            // away. The real portrait overflow was three rows inside `PatchbayView`,
            // repaired there (#1026).
            .presentationDetents([.medium, .large], selection: $detent)
            .presentationDragIndicator(.visible)
            .presentationBackground(EchoelTheme.bg.opacity(0.92))
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }
}

extension View {
    /// Present this sheet content as Echoel's consistent non-modal, draggable panel.
    /// (Not for views that set their own `presentationDetents`.)
    func echoelSheetPanel() -> some View { modifier(EchoelSheetPanelModifier()) }

}
#endif
