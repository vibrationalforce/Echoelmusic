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
                regionID: region.id, clipID: region.clipID, startTick: change.tick,
                songStartSeconds: TimelineTime.seconds(fromTicks: change.tick, bpm: bpm),
                songLengthSeconds: TimelineTime.seconds(fromTicks: end - change.tick, bpm: bpm),
                mediaFromSeconds: from, rate: plan.rate))
        }
        return out
    }
}
