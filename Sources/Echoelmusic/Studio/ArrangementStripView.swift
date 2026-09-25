//
//  ArrangementStripView.swift
//  Echoelmusic — Studio (WA4.5: the song on one scale — the pure geometry)
//
//  WHY THIS EXISTS. WA4.5 drew one thin strip per track under its row; WA4 path 4 replaced
//  the strips with `ArrangeCanvasView`, which draws every track on the same scale and makes a
//  part selectable. What stays here is the PURE half both used — where each part sits on the
//  song's scale — so the canvas has exactly one geometry rule (#416). The file keeps its name
//  because the guards and the census cite it; the `View` that gave it that name is gone.
//
//  ⚠️ OVERLAP IS DRAWN THE WAY IT IS HEARD. Blocks come in `TrackParts.parts` order — start,
//  then placement — so a later-starting part sits ON TOP of the one it overlaps, which is
//  exactly who `TimelineScheduling.activeRegion` lets play (#1440). No second rule.
//

import Foundation

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
