//
//  TrackCopyButton.swift
//  Echoelmusic — Studio (A7: duplicate a track)
//
//  WHY THIS EXISTS. "Duplicate track" — try a variation without losing the original (founder
//  2026-10-16, "Arrangement auf Ableton-Level"). The Track page of the inspector carries it under
//  Move up / Move down; one tap is one Undo step through `TimelineStore.duplicateLane`, and the copy
//  is selected so its page opens next. What a copy is, and why the Echoel and bio tracks cannot be
//  copied: `Sequencer/TrackCopy.swift`.
//
//  NEEDS-FOUNDER-VERIFY (A7): a synth track with two parts and a curve → "Duplicate track" → a
//  track "<name> copy" stands below it with the same parts, sound and curve, and is selected; play
//  → both sound; Undo → the copy is gone; on the Echoel track the button is not there.
//

import SwiftUI

/// The Track page's "Duplicate track" button. Draws nothing where a copy is refused.
struct TrackCopyButton: View {
    @Environment(TimelineStore.self) private var timeline
    @Environment(WorkstationSelection.self) private var selection
    let laneID: UUID

    var body: some View {
        if TrackCopy.offered(laneID, in: timeline.document) {
            Button {
                if let copy = timeline.duplicateLane(id: laneID) {
                    selection.selectTrack(copy)
                }
            } label: {
                Label(String(localized: "Duplicate track"), systemImage: "plus.square.on.square")
                    .font(EchoelTheme.font(13, .medium))
                    .foregroundStyle(EchoelTheme.text)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
                    .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                        .strokeBorder(EchoelTheme.borderStrong, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(String(localized: "Adds a copy of this track below it, with its parts, sound and curves."))
        }
    }
}
