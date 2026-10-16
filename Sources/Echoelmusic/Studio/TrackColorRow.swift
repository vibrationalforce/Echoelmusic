//
//  TrackColorRow.swift
//  Echoelmusic — Studio (A4b: the person chooses a track's colour)
//
//  WHY THIS EXISTS. Every track wears its instrument's colour (`EchoelTheme.TrackHue.of`), so two
//  synth tracks look the same and nobody can mark "the lead" by colour — Live and Logic let you
//  pick it (founder 2026-10-16, "Arrangement auf Ableton-Level", gap list item 4). The Track page
//  of the inspector now carries a "Colour" menu: Automatic (the instrument's colour) or one of the
//  seven track hues. The canvas head, every part, the mixer strip and the audio editor wear it.
//
//  ⚠️ A NAMED CHOICE, so a menu `Picker` — the `EchoelValueField` law is for numbers.
//  ⚠️ DISPLAY ONLY: `TimelineDocument.structurallyEqual` leaves the colour out, so recolouring a
//  playing track re-attacks no voice. One writer, `TimelineStore.setLaneColor`.
//  ⚠️ Never the body's green, and never on the bio track — that one IS the body's colour.
//
//  NEEDS-FOUNDER-VERIFY (A4b): open a synth track's Track page, Colour → Orchid → its head and
//  parts on the canvas and its mixer strip turn orchid; Automatic → back to teal.
//

import SwiftUI

/// The pure half: the menu's words.
enum TrackColorChoice {

    /// The menu entry for a colour, nil = Automatic. Pure.
    nonisolated static func label(_ color: TrackColor?) -> String {
        switch color {
        case nil:          return String(localized: "Automatic")
        case .teal?:       return String(localized: "Teal")
        case .blue?:       return String(localized: "Blue")
        case .sand?:       return String(localized: "Sand")
        case .terracotta?: return String(localized: "Terracotta")
        case .violet?:     return String(localized: "Violet")
        case .slate?:      return String(localized: "Slate")
        case .orchid?:     return String(localized: "Orchid")
        }
    }

    /// Whether a track can be recoloured: every track but the bio one. Pure.
    nonisolated static func offered(_ laneID: UUID, in document: TimelineDocument) -> Bool {
        guard let lane = document.lanes.first(where: { $0.id == laneID }) else { return false }
        return !lane.isBio
    }
}

/// The Track page's "Colour" menu.
struct TrackColorRow: View {
    @Environment(TimelineStore.self) private var timeline
    let laneID: UUID

    var body: some View {
        let current = timeline.document.lanes.first(where: { $0.id == laneID })?.color
        VStack(alignment: .leading, spacing: 4) {
            Text("Colour")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            Picker(String(localized: "Colour"), selection: Binding(
                get: { current },
                set: { timeline.setLaneColor(id: laneID, $0) })) {
                Text(TrackColorChoice.label(nil)).tag(TrackColor?.none)
                ForEach(TrackColor.allCases, id: \.self) { color in
                    Text(TrackColorChoice.label(color)).tag(TrackColor?.some(color))
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel(String(localized: "Track colour"))
        }
    }
}
