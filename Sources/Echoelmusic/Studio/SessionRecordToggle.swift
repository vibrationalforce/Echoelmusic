// SessionRecordToggle.swift
// Echoel — Arrange & Perform item 6 (P4b, founder 2026-10-16, "Record scenes into the
// arrangement"): the door of Session → Arrangement recording, in the Session grid's header.
//
// ⚠️ WHY ITS OWN FILE. `SessionLaunchView` launches through the player and persists nothing
// (`TheSessionLaunchesWhatTheSongPlaysTests`); this leaf writes only the player's cold switch.
// The parts themselves are written by the app (`launchTakeSink` → the store's paste writer).
//
// NEEDS-FOUNDER-VERIFY (P4b): two tracks with two parts each, Session, switch "Record to
// arrangement" on, Play, launch scene 1, after two bars scene 2, after two more Stop → Arrange
// shows the launched parts on both tracks where they played, over the parts under them; one Undo
// takes the whole recording back; with the switch off nothing is written.

import SwiftUI

/// "Record to arrangement": while on, the launches that land are written into the arrangement.
@MainActor
struct SessionRecordToggle: View {
    @Environment(TimelineRegionPlayer.self) private var player

    var body: some View {
        Toggle(isOn: Binding(get: { player.recordsLaunches },
                             set: { player.recordsLaunches = $0 })) {
            Text("Record to arrangement")
                .font(EchoelTheme.font(12, .semibold))
                .foregroundStyle(EchoelTheme.text)
        }
        .toggleStyle(.switch)
        .tint(EchoelTheme.recording)
        .frame(minHeight: 44)
        .accessibilityHint("While on, the parts you launch are written into the arrangement where they played. Stop ends the recording; Undo takes it back.")
    }
}
