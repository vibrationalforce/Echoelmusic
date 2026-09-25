//
//  ArrangementStripView.swift
//  Echoelmusic — Studio (WA4.5: the song at a glance — every track's parts on one scale)
//
//  WHY THIS EXISTS. The WA4 journey step SEE CONTENT. Since WA4.3 a track's parts are listed
//  under its inspector, one track at a time; nothing showed WHERE in the song each track
//  plays. This strip sits under every track row with parts: one block per part, placed on the
//  SAME scale for every track (the song's length in whole bars, `WorkstationSummary
//  .lengthBars`), so the rows line up into an arrangement overview.
//
//  ⚠️ OVERLAP IS DRAWN THE WAY IT IS HEARD. Parts are drawn in `TrackParts.parts` order —
//  start, then placement — so a later-starting part sits ON TOP of the one it overlaps, which
//  is exactly who `TimelineScheduling.activeRegion` lets play (#1440). No second rule.
//
//  ⚠️ NO PLAYHEAD, ON PURPOSE. The position is ~8 Hz state (`currentTick` is
//  `@ObservationIgnored` precisely so no view subscribes to it); drawing it here would make
//  every strip — and the Workstation body that hosts them — a hot reader (10.76.41/50). The
//  strip is a picture of the DOCUMENT and changes only on an edit.
//
//  Read-only: no tap, no drag, no write. Arranging stays in the inspector (WA4.3).
//

import SwiftUI

/// The pure half: where each part of a track sits on the song's scale, and how that is said.
enum ArrangementStrip {

    struct Block: Identifiable, Equatable, Sendable {
        let id: UUID
        /// Fraction of the song where the part starts, 0…1.
        let start: Double
        /// Fraction of the song the part spans, 0…1 − `start`.
        let width: Double
    }

    /// The shared scale: the song's length in whole bars, in ticks. Zero for an empty song.
    nonisolated static func songTicks(_ summary: WorkstationSummary) -> Int {
        summary.lengthBars * TimelineTime.ticksPerBar
    }

    /// One block per part on the lane, in draw order (later starts on top). Parts outside the
    /// scale are clamped to it; a part with no visible extent is left out rather than drawn
    /// as a sliver that claims a place it does not have.
    nonisolated static func blocks(onLane laneID: UUID, in document: TimelineDocument,
                                   songTicks: Int) -> [Block] {
        guard songTicks > 0 else { return [] }
        let scale = Double(songTicks)
        return TrackParts.parts(onLane: laneID, in: document).compactMap { part in
            let start = (Double(part.startTick) / scale).clamped(to: 0...1)
            let end = (Double(part.startTick + part.lengthTicks) / scale).clamped(to: 0...1)
            guard end > start else { return nil }
            return Block(id: part.id, start: start, width: end - start)
        }
    }

    /// What VoiceOver says for the strip: where the parts start, named the way the Session
    /// view and the parts list name them (`SessionGrid.label`, one label rule).
    nonisolated static func spoken(onLane laneID: UUID, in document: TimelineDocument) -> String {
        let parts = TrackParts.parts(onLane: laneID, in: document)
        guard !parts.isEmpty else { return "No parts" }
        let shown = parts.prefix(spokenLimit).map { SessionGrid.label(forTick: $0.startTick) }
        let rest = parts.count - shown.count
        let list = shown.joined(separator: ", ")
        return rest > 0 ? "Parts at \(list), and \(rest) more" : "Parts at \(list)"
    }

    /// Past this many, the sentence summarises instead of reading a whole song aloud.
    static let spokenLimit = 6
}

/// One track's parts across the song. A leaf with no observation of its own: the host hands it
/// the document it already read, so it re-renders only when the song is edited.
struct ArrangementStripView: View {

    let laneID: UUID
    let document: TimelineDocument
    let songTicks: Int

    var body: some View {
        let blocks = ArrangementStrip.blocks(onLane: laneID, in: document, songTicks: songTicks)
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .fill(EchoelTheme.fill)
                ForEach(blocks) { block in
                    RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                        .fill(EchoelTheme.dim)
                        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                            .strokeBorder(EchoelTheme.border, lineWidth: 1))
                        .frame(width: Swift.max(2, width * block.width))
                        .offset(x: width * block.start)
                }
            }
        }
        // A picture of data, not a control: a fixed height is right here (no text inside).
        .frame(height: 10)
        .accessibilityElement()
        .accessibilityLabel(ArrangementStrip.spoken(onLane: laneID, in: document))
    }
}
