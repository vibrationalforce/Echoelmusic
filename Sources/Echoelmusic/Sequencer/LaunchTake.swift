// LaunchTake.swift
// Echoel — Arrange & Perform item 6 (P4a, founder 2026-10-16, "Record scenes into the
// arrangement"): the pure half of Session → Arrangement recording. While the song plays, every
// landed launch is logged as a SPAN — which part played on which track, from which tick to which —
// and when the take ends the spans become parts on the arrangement.
//
// What a span becomes, and why:
//   · A launched part loops over its own length from the launch boundary (`ClipLaunchEngine`,
//     `launchedStartBar`), so a span of n loops is written as n copies of that part laid end to
//     end, the last one cut where the span ended. Each copy is `TimelineRegion.duplicated` — same
//     clip, same offsets and gain, a new id — so the recording points at the music it played and
//     never copies a clip.
//   · A recorded part lands OVER the arranged parts it played instead of: a later-placed region
//     wins at the same start (`TimelineScheduling.activeRegion`, #1440), the same rule a MIDI take
//     follows. Undo takes the whole recording back in one step (`TimelineStore.pasteRegions`).
//   · A "stop" hands a track back to the arrangement, so it closes the span and writes nothing for
//     the time after it: the arrangement is already there.
//
// ⚠️ This file decides nothing about WHEN a take starts or ends, and holds no clock. The player
// feeds it the boundary ticks of its own launch transitions (P4b).

import Foundation

/// A Session → Arrangement recording: the launches that landed while it ran.
public struct LaunchTake: Equatable, Sendable {

    /// One part playing on one track over `[startTick, endTick)`.
    public struct Span: Equatable, Sendable {
        public let laneID: UUID
        public let regionID: UUID
        public let startTick: Int
        public let endTick: Int
    }

    private struct Open: Equatable, Sendable {
        let regionID: UUID
        let startTick: Int
    }

    public private(set) var spans: [Span] = []
    private var open: [UUID: Open] = [:]

    /// More copies than this in one recording are not written — a guard against a one-bar loop left
    /// running for hours, never a musical limit.
    public nonisolated static let maxRegions = 4096

    public init() {}

    /// Whether any track is playing a launched part right now.
    public var isOpen: Bool { !open.isEmpty }

    /// A launch landed: `regionID` starts on `laneID` at `tick`. A part already playing on that
    /// track ends there (a switch).
    public mutating func started(laneID: UUID, regionID: UUID, atTick tick: Int) {
        close(laneID: laneID, atTick: tick)
        open[laneID] = Open(regionID: regionID, startTick: max(0, tick))
    }

    /// A stop landed: `laneID` goes back to the arrangement at `tick`.
    public mutating func stopped(laneID: UUID, atTick tick: Int) {
        close(laneID: laneID, atTick: tick)
    }

    /// The take ends (Stop, or the song wraps): every playing part ends at `tick`. Sorted by track
    /// id so the result does not depend on dictionary order.
    public mutating func finish(atTick tick: Int) {
        for laneID in open.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            close(laneID: laneID, atTick: tick)
        }
    }

    /// P4c — the song wrapped at `loopTicks` (the launch timebase folds back by it). Every span
    /// ends there and is RETURNED — the caller writes this pass now, so the next pass is placed
    /// later and wins where the two overlap — and every part still playing goes on being recorded
    /// from its first loop boundary at or after the new 0 (its anchor folded back by `loopTicks`).
    /// ⚠️ Between 0 and that boundary the part plays mid-loop; that stretch is not written, so the
    /// arrangement's part plays there on playback. A part whose length is unknown is not reopened.
    public mutating func wrap(atTick loopTicks: Int, lengthOf: (UUID) -> Int?) -> [Span] {
        let playing = open
        finish(atTick: loopTicks)
        let pass = spans
        spans = []
        for laneID in playing.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard let still = playing[laneID], let length = lengthOf(still.regionID), length > 0 else { continue }
            open[laneID] = Open(regionID: still.regionID,
                                startTick: Self.firstBoundary(anchor: still.startTick - loopTicks, length: length))
        }
        return pass
    }

    /// The first tick at or after 0 where a part of `length`, anchored at `anchor`, starts a loop.
    public nonisolated static func firstBoundary(anchor: Int, length: Int) -> Int {
        guard length > 0 else { return Swift.max(0, anchor) }
        guard anchor < 0 else { return anchor }
        let loops = (-anchor + length - 1) / length
        return anchor + loops * length
    }

    private mutating func close(laneID: UUID, atTick tick: Int) {
        guard let playing = open.removeValue(forKey: laneID) else { return }
        guard tick > playing.startTick else { return }
        spans.append(Span(laneID: laneID, regionID: playing.regionID,
                          startTick: playing.startTick, endTick: tick))
    }

    /// The parts a finished take writes into `document`: each span as copies of its part, end to
    /// end, the last cut at the span's end. A span whose part or track is gone writes nothing.
    public nonisolated static func regions(for spans: [Span], in document: TimelineDocument) -> [TimelineRegion] {
        let lanes = Set(document.lanes.map(\.id))
        var out: [TimelineRegion] = []
        for span in spans where lanes.contains(span.laneID) {
            guard let source = document.regions.first(where: { $0.id == span.regionID }),
                  source.laneID == span.laneID, source.lengthTicks > 0 else { continue }
            var tick = span.startTick
            while tick < span.endTick {
                guard out.count < maxRegions else { return out }
                var copy = source.duplicated(atStartTick: tick)
                copy.lengthTicks = min(source.lengthTicks, span.endTick - tick)
                out.append(copy)
                tick += source.lengthTicks
            }
        }
        return out
    }
}
