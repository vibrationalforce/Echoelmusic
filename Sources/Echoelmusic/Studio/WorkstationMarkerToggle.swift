//
//  WorkstationMarkerToggle.swift
//  Echoelmusic — Studio (A5: the Marker button)
//
//  WHY THIS EXISTS. Every big DAW names places in a song — Live's locators, Logic's markers
//  (founder 2026-10-16: "einen einfachen Arrangement-Modus … auf Ableton-Level"). The piece now
//  carries markers (`TimelineDocument.markers`); this is the door. ONE button in the Workstation's
//  pinned transport row, beside Cycle:
//  · on a bar without a marker: adds "Marker n" on the bar Play starts from (the ruler's line);
//  · on a bar with one: removes it.
//  The ruler draws every marker, and a tap there sets Play to that bar — the ruler's own tap.
//
//  ⚠️ ONE WRITER, ONE STEP. The tap calls `TimelineStore.toggleMarker` once — one `.markers`
//  Undo step — and nothing else in the app writes the markers (`TheMarkersNameBarsOfThePieceTests`).
//
//  ⚠️ COLD. It reads the piece and the cue, each changed by a tap or an edit — never `currentTick`.
//
//  NEEDS-FOUNDER-VERIFY (A5): tap the ruler on bar 5, tap the Marker button → a mark stands on
//  bar 5 of the ruler; tap the button again → it goes. Undo after either → the previous state.
//

import SwiftUI

/// The pure half: what a tap on the Marker button does, in words.
enum MarkerChoice {

    /// The marker on the bar of `tick`, or nil. Pure.
    nonisolated static func marker(atTick tick: Int, in markers: [TimelineMarker]) -> TimelineMarker? {
        let bar = TimelineMarker.barTick(tick)
        return markers.first { TimelineMarker.barTick($0.tick) == bar }
    }

    /// What the ruler says for the bar Play starts from: the bar, and the marker's name when that
    /// bar carries one — the marker is otherwise never spoken (review UI#5). Pure.
    nonisolated static func rulerValue(forTick tick: Int, in markers: [TimelineMarker]) -> String {
        let bar = SessionGrid.label(forTick: tick)
        guard let marker = marker(atTick: tick, in: markers) else { return bar }
        return bar + String(localized: ", marker ") + marker.name
    }

    /// The button's VoiceOver hint — one sentence per state. Pure.
    nonisolated static func hint(hasMarkerHere: Bool) -> String {
        hasMarkerHere
            ? String(localized: "Removes the marker on the bar Play starts from.")
            : String(localized: "Adds a marker on the bar Play starts from.")
    }
}

/// The transport row's Marker button: name the bar Play starts from, or clear its marker.
struct WorkstationMarkerToggle: View {
    @Environment(TimelineStore.self) private var timeline
    /// Only `cueTick` — cold (a tap on the ruler).
    @Environment(TimelineRegionPlayer.self) private var player

    var body: some View {
        let document = timeline.document
        let start = TimelineRegionPlayer.playStartTick(forCue: player.cueTick, in: document)
        let here = MarkerChoice.marker(atTick: start, in: document.markers)
        Button {
            timeline.toggleMarker(atTick: start)
        } label: {
            Image(systemName: here == nil ? "flag" : "flag.fill")
                .font(EchoelTheme.font(13, .semibold))
                // The inverted monochrome tile when this bar carries a marker — the look Click and
                // Cycle wear; never green, which is the body's signal.
                .foregroundStyle(here == nil ? EchoelTheme.text : EchoelTheme.onPrimary)
                .frame(minWidth: 44, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .fill(here == nil ? EchoelTheme.fill : EchoelTheme.text))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .strokeBorder(here == nil ? EchoelTheme.borderStrong : Color.clear, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Marker"))
        .accessibilityValue(here?.name ?? String(localized: "Off"))
        .accessibilityAddTraits(.isToggle)
        .accessibilityHint(MarkerChoice.hint(hasMarkerHere: here != nil))
    }
}
