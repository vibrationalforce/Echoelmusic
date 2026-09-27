// PartNotePlayheadView.swift
// Echoel — design slice 9 (modes census 2026-09-26): the playhead inside the note grid.
//
// The Arrange canvas showed where the song was; the note grid under it did not, so a musician
// editing notes while the song played had to look up to find the beat. This leaf draws the same
// 1 pt line across the open part's grid, at the column the song is on.
//
// ⭐ WHY THIS IS ITS OWN FILE AND NOT A MEMBER OF `PartNoteEditor`. The note editor sits under
// the menu host and reads no transport, tempo or playhead — `TheSelectedPartsNotesAreEditedThrough
// OneWriterTests` bans `currentTick` and `player.` from that file whole. A position read there, or
// hoisted into the grid's body, would rebuild the grid 15 times a second and tear down its open
// controls (10.76.41/50). So the read lives HERE, inside a self-driving `TimelineView`, exactly as
// `ArrangePlayheadView` and `SongPositionReadout` do it; the grid hands over three cold numbers.
//
// ⚠️ `currentTick` is read INSIDE the `TimelineView` closure, per frame. Hoisted above it, the
// value would be read once and the line would not move — the shape `SongPositionReadout`'s
// review settled, copied here rather than reviewed here.
//
// ⚠️ THE LINE STEPS, IT DOES NOT GLIDE (review of e091712e5, LOW-7). The player advances
// `currentTick` once per transport step — 120 ticks, exactly one grid column — so the line
// jumps a column at a time — at most one per redraw while the song makes at most fifteen steps a
// second (225 BPM in sixteenths); between 225 and `Transport.maxTempo` (300) a redraw can land
// two columns on (review of c51b1645a, LOW-3). The fractional step below is exact arithmetic, and it is visible
// only for a part whose start sits off the 120-tick grid, where the line stands between two
// columns by the same fraction the part does.

import SwiftUI

/// The pure half: which column of a part's grid the song is on.
enum PartNotePlayhead {

    /// The playhead's position in grid STEPS (fractional, though the player's position moves a
    /// whole column at a time — see the file header), or nil
    /// when the song is not inside the part: before its start, at or past its end, or when the
    /// part has no length. Measured from the part's START, the grid's x = 0 — the notes the grid
    /// draws are windowed to the part (`ClipNoteEdit.visibleNotes`), not to the clip.
    nonisolated static func step(atTick tick: Int, partStartTick: Int, lengthTicks: Int) -> Double? {
        let perStep = Note.ticksPerStep
        guard lengthTicks > 0, perStep > 0 else { return nil }
        let into = tick - partStartTick
        guard into >= 0, into < lengthTicks else { return nil }
        return Double(into) / Double(perStep)
    }
}

/// The line itself: drawn only while the song plays and stands inside this part. It takes no
/// touches and is hidden from VoiceOver — the Workstation's song-position readout speaks where
/// the song is, and a moving line has nothing to say that it does not.
struct PartNotePlayheadView: View {

    @Environment(TimelineRegionPlayer.self) private var player

    let partStartTick: Int
    let lengthTicks: Int
    let stepWidth: CGFloat

    var body: some View {
        let playing = player.isPlaying
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !playing)) { _ in
            GeometryReader { _ in
                if playing,
                   let step = PartNotePlayhead.step(atTick: player.currentTick,
                                                    partStartTick: partStartTick,
                                                    lengthTicks: lengthTicks) {
                    Rectangle()
                        .fill(EchoelTheme.accent)
                        .frame(width: 1)
                        .offset(x: stepWidth * CGFloat(step))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
