// LaunchTake.swift
// Echoel — Arrange & Perform item 6 (P4a, founder 2026-10-16, "Record scenes into the
// arrangement"): the pure half of Session → Arrangement recording. While the song plays, every
// landed launch is logged as a SPAN — which part played on which track, from which tick to which —
// and when the take ends the spans become parts on the arrangement.
//
// What a span becomes, and why:
//   · A launched part loops from the launch boundary (`ClipLaunchEngine`, `launchedStartBar`): an
//     AUDIO part over its own length, a MIDI part over its WHOLE BARS — the lane pump cycles
//     `ceil(length / bar)` bars, so a 1.5-bar part is heard every 2 bars (`period`). A span is
//     written as copies of that part, one per loop, the last one cut where the span ended. Each
//     copy is `TimelineRegion.duplicated` — same clip, same offsets and gain, a new id — so the
//     recording points at the music it played and never copies a clip.
//   · A recorded part lands OVER the arranged parts it played instead of: a later-placed region
//     wins at the same start (`TimelineScheduling.activeRegion`, #1440), the same rule a MIDI take
//     follows. Undo takes the whole recording back in one step (`TimelineStore.pasteRegions`).
//   · A "stop" hands a track back to the arrangement, so it closes the span and writes nothing for
//     the time after it: the arrangement is already there.
//   · The take is written ONCE, when it ends. A take that runs across the song's wrap keeps each
//     pass (`wrap`); where a later pass covers what an earlier one recorded on the same track, the
//     later one is kept (`layered`). ⛔ Until the finesse review (2026-10-16) every wrap wrote its
//     pass at once: each write was a structural edit that cut every voice a step after the wrap,
//     stacked one more layer of copies per pass, and grew the Session grid under the player's
//     finger mid-performance.
//   · A span no longer than one transport step is not written: it was launched and stopped before
//     anything was heard.
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

    /// The spans closed in the current pass of the song.
    public private(set) var spans: [Span] = []
    /// The spans of every earlier pass, oldest first (P4c).
    private var earlierPasses: [[Span]] = []
    private var open: [UUID: Open] = [:]

    /// More copies than this in one recording are not written — a guard against a one-bar loop left
    /// running for hours, never a musical limit.
    public nonisolated static let maxRegions = 4096

    public init() {}

    /// Whether any track is playing a launched part right now.
    public var isOpen: Bool { !open.isEmpty }

    /// Whether the take holds anything to write: a span closed in any pass, or a part still playing.
    public var isEmpty: Bool { open.isEmpty && spans.isEmpty && earlierPasses.allSatisfy(\.isEmpty) }

    /// What a finished take writes: every pass, a later pass winning where it covers an earlier one.
    public var composed: [Span] { Self.layered(earlierPasses + [spans]) }

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

    /// The take ends (Stop, a locate, the cycle's jump): every playing part ends at `tick`. Sorted
    /// by track id so the result does not depend on dictionary order.
    public mutating func finish(atTick tick: Int) {
        for laneID in open.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            close(laneID: laneID, atTick: tick)
        }
    }

    /// P4c — the song wrapped at `loopTicks` (the launch timebase folds back by it). Every span ends
    /// there and the pass is kept for the end of the take; every part still playing goes on being
    /// recorded from its first loop boundary at or after the new 0 (its anchor folded back by
    /// `loopTicks`, its loop `periodOf` long). ⚠️ Between 0 and that boundary the part plays
    /// mid-loop; that stretch is not written, so the arrangement's part plays there on playback.
    /// A part whose period is unknown is not reopened.
    public mutating func wrap(atTick loopTicks: Int, periodOf: (UUID) -> Int?) {
        let playing = open
        finish(atTick: loopTicks)
        earlierPasses.append(spans)
        spans = []
        for laneID in playing.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard let still = playing[laneID], let period = periodOf(still.regionID), period > 0 else { continue }
            open[laneID] = Open(regionID: still.regionID,
                                startTick: Self.firstBoundary(anchor: still.startTick - loopTicks, length: period))
        }
    }

    /// The first tick at or after 0 where a part of `length`, anchored at `anchor`, starts a loop.
    public nonisolated static func firstBoundary(anchor: Int, length: Int) -> Int {
        guard length > 0 else { return Swift.max(0, anchor) }
        guard anchor < 0 else { return anchor }
        let loops = (-anchor + length - 1) / length
        return anchor + loops * length
    }

    /// How long one loop of a launched part lasts: an audio part its own length, a MIDI part its
    /// whole bars (the pump cycles `ceil(length / bar)` bars, `RegionNoteWindow.barSlices`). Pure.
    public nonisolated static func period(of region: TimelineRegion, kind: ClipKind) -> Int {
        guard region.lengthTicks > 0 else { return 0 }
        guard kind == .midi else { return region.lengthTicks }
        let bar = TimelineTime.ticksPerBar
        return ((region.lengthTicks + bar - 1) / bar) * bar
    }

    /// `period(of:kind:)` for the part `regionID` of `document`, nil when it is gone. Pure.
    public nonisolated static func period(ofRegion regionID: UUID, in document: TimelineDocument) -> Int? {
        guard let region = document.regions.first(where: { $0.id == regionID }),
              let lane = document.lanes.first(where: { $0.id == region.laneID }) else { return nil }
        return period(of: region, kind: lane.kind)
    }

    /// The passes as one list: each pass, oldest first, cuts what it covers out of the spans before
    /// it on the same track, then joins them. The result is sorted by start, then track. Pure.
    public nonisolated static func layered(_ passes: [[Span]]) -> [Span] {
        var kept: [Span] = []
        for pass in passes {
            for span in pass {
                kept = kept.flatMap { old -> [Span] in
                    guard old.laneID == span.laneID, old.startTick < span.endTick, span.startTick < old.endTick
                    else { return [old] }
                    var pieces: [Span] = []
                    if old.startTick < span.startTick {
                        pieces.append(Span(laneID: old.laneID, regionID: old.regionID,
                                           startTick: old.startTick, endTick: span.startTick))
                    }
                    if span.endTick < old.endTick {
                        // ⚠️ A piece cut from the FRONT starts mid-loop; its copies are placed from
                        // the cut, so on playback that stretch starts the part from its top.
                        pieces.append(Span(laneID: old.laneID, regionID: old.regionID,
                                           startTick: span.endTick, endTick: old.endTick))
                    }
                    return pieces
                }
                kept.append(span)
            }
        }
        return kept.sorted { ($0.startTick, $0.laneID.uuidString) < ($1.startTick, $1.laneID.uuidString) }
    }

    private mutating func close(laneID: UUID, atTick tick: Int) {
        guard let playing = open.removeValue(forKey: laneID) else { return }
        guard tick > playing.startTick else { return }
        spans.append(Span(laneID: laneID, regionID: playing.regionID,
                          startTick: playing.startTick, endTick: tick))
    }

    /// The parts a finished take writes into `document`: each span as copies of its part, one per
    /// loop (`period`), each as long as the part, the last cut at the span's end. A span whose part
    /// or track is gone writes nothing, and so does one no longer than a transport step.
    public nonisolated static func regions(for spans: [Span], in document: TimelineDocument) -> [TimelineRegion] {
        let lanes = Dictionary(document.lanes.map { ($0.id, $0.kind) }, uniquingKeysWith: { first, _ in first })
        var out: [TimelineRegion] = []
        for span in spans where span.endTick - span.startTick > TimelineTime.ticksPerTransportStep {
            guard let kind = lanes[span.laneID],
                  let source = document.regions.first(where: { $0.id == span.regionID }),
                  source.laneID == span.laneID, source.lengthTicks > 0 else { continue }
            let period = Self.period(of: source, kind: kind)
            var tick = span.startTick
            while tick < span.endTick {
                guard out.count < maxRegions else { return out }
                var copy = source.duplicated(atStartTick: tick)
                copy.lengthTicks = min(source.lengthTicks, span.endTick - tick)
                out.append(copy)
                tick += period
            }
        }
        return out
    }
}
