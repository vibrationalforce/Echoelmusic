// AudioLaneStemPlan.swift
// Echoel — the PURE placement plan for rendering ONE audio lane as a stem, offline,
// from its files and the `TimelineDocument` (ADR-008 K1: the preferred path for audio-lane
// stems, because a file plus a document is deterministic — unlike the generated voices, the
// body does not have to play it again).
//
// It answers exactly one question: "which stretch of which file sounds at which song time,
// on this lane?" — the same answer the LIVE player gives, by construction:
//   · the WINNER at each moment is `TimelineScheduling.activeRegion`, asked at the bounded
//     set of grid ticks where it can change (`candidateSampleTicks`) — never a second
//     overlap rule (#1440);
//   · a segment starts where `AudioLanePlayer.apply` would `.load` it, at that grid tick,
//     at the media position `AudioRegionPlayback.filePositionSeconds` gives there;
//   · it ends at its region's EXACT end (the live player schedules `endTick − tick`) or at
//     the next winner's grid tick, whichever comes first — a new `.load` replaces the sound;
//   · the media rate is `StretchPlan.resolve` with the timeline's capabilities, the call the
//     live player makes.
//
// ⚠️ PLACEMENT ONLY. Gain, mute, pan, fades, transpose, grain and launch overrides are NOT in
// this plan — the stem renderer applies them per segment (ADR-008 K2/G-B decide which). And it
// is FILE-LENGTH-AGNOSTIC like `AudioRegionPlayback`: the renderer clamps each segment against
// the real file length. No AVFoundation, no clock, no state.

import Foundation

public struct AudioLaneStemSegment: Equatable, Sendable {
    public let regionID: UUID
    public let clipID: UUID
    /// The grid tick at which the live player loads this segment.
    public let startTick: Int
    /// The tick at which it stops: its region's end, or the next winner's tick.
    public let endTick: Int
    /// Song seconds from tick 0 where it starts sounding.
    public let songStartSeconds: Double
    /// Song seconds it sounds for.
    public let songLengthSeconds: Double
    /// Seconds into its file where it starts.
    public let mediaFromSeconds: Double
    /// Media seconds consumed per song second (1 = unwarped).
    public let rate: Double
}

public enum AudioLaneStemPlan {

    /// The ordered segments `laneID` sounds over the whole song at `bpm`. `nativeBPM` is the
    /// live player's resolver (a clip's native tempo, 0 when unknown). Empty for a
    /// non-positive or non-finite tempo, or a lane with no schedulable region.
    public static func segments(in document: TimelineDocument, laneID: UUID, bpm: Double,
                                nativeBPM: (UUID) -> Double = { _ in 0 }) -> [AudioLaneStemSegment] {
        guard bpm.isFinite, bpm > 0 else { return [] }
        // The winner at every tick where it can change, with repeats of one winner collapsed:
        // the live player reads `.unchanged` there and does not restart.
        var changes: [(tick: Int, region: TimelineRegion)] = []
        for tick in TimelineScheduling.candidateSampleTicks(in: document, laneID: laneID) {
            guard let winner = TimelineScheduling.activeRegion(in: document, laneID: laneID, at: tick)
            else { continue }
            if changes.last?.region.id == winner.id { continue }
            changes.append((tick: tick, region: winner))
        }
        var out: [AudioLaneStemSegment] = []
        out.reserveCapacity(changes.count)
        for (i, change) in changes.enumerated() {
            let region = change.region
            let end = i + 1 < changes.count
                ? Swift.min(region.endTick, changes[i + 1].tick)
                : region.endTick
            guard end > change.tick else { continue }
            let plan = StretchPlan.resolve(mode: region.stretchMode,
                                           warpEnabled: region.warpEnabled,
                                           nativeBPM: nativeBPM(region.clipID),
                                           projectBPM: bpm,
                                           capabilities: StretchMode.timelineCapabilities)
            let from = AudioRegionPlayback.filePositionSeconds(for: region, atTick: change.tick,
                                                               bpm: bpm, stretchRate: plan.rate)
                ?? region.contentOffsetSeconds
            out.append(AudioLaneStemSegment(
                regionID: region.id, clipID: region.clipID, startTick: change.tick, endTick: end,
                songStartSeconds: TimelineTime.seconds(fromTicks: change.tick, bpm: bpm),
                songLengthSeconds: TimelineTime.seconds(fromTicks: end - change.tick, bpm: bpm),
                mediaFromSeconds: from, rate: plan.rate))
        }
        return out
    }

    /// Where one segment lands in a stem rendered at `sampleRate`, and which frames of its file
    /// (already read at `sampleRate`, `fileFrames` long) fill it. Destination frames are taken from
    /// the segment's TICKS, so a segment ending where the next begins shares that frame exactly —
    /// no one-sample gap or overlap from rounding two lengths separately. The file position floors,
    /// as `AudioRegionPlayback.startFrame` does for the live player. A file that ends early leaves
    /// the rest of the segment silent (the count shrinks), as the live player stops at EOF.
    ///
    /// nil when there is nothing to copy (bad rate or tempo, a position at or past the file's end,
    /// an empty span) — and when the segment is WARPED (`rate != 1`): a warped stem needs the
    /// stretcher, and a plain copy at the wrong speed would be a stem that does not match the song.
    /// The renderer must refuse that segment loudly rather than skip it.
    public static func frames(for segment: AudioLaneStemSegment, bpm: Double,
                              sampleRate: Double, fileFrames: Int) -> AudioLaneStemFrames? {
        guard segment.rate == 1, bpm.isFinite, bpm > 0, sampleRate.isFinite, sampleRate > 0,
              fileFrames > 0 else { return nil }
        func frame(_ tick: Int) -> Int {
            Int((TimelineTime.seconds(fromTicks: tick, bpm: bpm) * sampleRate).rounded())
        }
        let destination = frame(segment.startTick)
        let span = frame(segment.endTick) - destination
        let source = Swift.max(0, Int((segment.mediaFromSeconds * sampleRate).rounded(.down)))
        guard span > 0, source < fileFrames else { return nil }
        return AudioLaneStemFrames(destinationStart: destination, sourceStart: source,
                                   count: Swift.min(span, fileFrames - source))
    }
}

/// One copy instruction for an unwarped stem segment: `count` frames from the file at
/// `sourceStart` into the stem at `destinationStart`.
public struct AudioLaneStemFrames: Equatable, Sendable {
    public let destinationStart: Int
    public let sourceStart: Int
    public let count: Int
}
