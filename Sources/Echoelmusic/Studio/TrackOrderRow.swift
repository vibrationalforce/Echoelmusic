//
//  TrackOrderRow.swift
//  Echoelmusic — Studio (A4c: the Track page's Move up / Move down)
//
//  WHY THIS EXISTS. The tracks stood in the order they were made (founder 2026-10-16,
//  "Arrangement auf Ableton-Level", gap list item 4). The Track page of the inspector now carries
//  Move up and Move down; each tap is one `.laneOrder` Undo step through `TimelineStore.moveLane`.
//  A button is disabled where the move is refused (`LaneOrder.moved`): at the edge, next to the
//  bio track, or where it would hand the Echoel instrument to another track.
//
//  ⚠️ BUTTONS, NOT A DRAG, in v1 — a drag on the track column would fight the canvas's own
//  gestures, and the buttons are VoiceOver's way in at the same time.
//  ⚠️ COLD: it reads the piece's lane order, changed by a tap.
//
//  NEEDS-FOUNDER-VERIFY (A4c): three tracks Echoel · Synth · Audio, open the Audio track, Move up
//  → Echoel · Audio · Synth on the canvas and in the mixer; Undo → back. On the Synth track, Move up
//  next to Echoel is disabled when Synth is MIDI (it would take over the Echoel instrument).
//

import SwiftUI

/// The Track page's two order buttons.
struct TrackOrderRow: View {
    @Environment(TimelineStore.self) private var timeline
    let laneID: UUID

    var body: some View {
        HStack(spacing: 8) {
            step(String(localized: "Move up"), "arrow.up", by: -1)
            step(String(localized: "Move down"), "arrow.down", by: 1)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
    }

    private func step(_ title: String, _ symbol: String, by delta: Int) -> some View {
        let enabled = timeline.canMoveLane(id: laneID, by: delta)
        return Button {
            timeline.moveLane(id: laneID, by: delta)
        } label: {
            Label(title, systemImage: symbol)
                .font(EchoelTheme.font(13, .medium))
                .foregroundStyle(enabled ? EchoelTheme.text : EchoelTheme.dim)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .strokeBorder(EchoelTheme.borderStrong, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityHint(String(localized: "Changes the order of the tracks. With more tracks than voices, the upper ones sound."))
    }
}
