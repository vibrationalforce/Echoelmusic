// AudioWarp.swift
// Echoel — #C1 (founder 2026-09-23: "WARP / NATIVE BPM: Approved.")
//
// WHAT THIS IS. The switch that lets an imported part follow the SONG's tempo instead of
// playing at the speed it was recorded — the missing writer of `TimelineRegion.warpEnabled`.
// The engine was whole before this file existed: `AudioLanePlayer` asks `StretchPlan.resolve`
// for a rate on every start and preloads the warp chain at prime time. What never existed was
// a production path that could set the flag, so every region played at rate 1.0.
//
// ⭐ IT IS DECIDED HERE AND APPLIED ELSEWHERE — THE `AudioImport` SEAM, AGAIN. `changes(…)`
// is pure over a `TimelineDocument` and `[Clip]` values, so every rule below is drivable in
// the blocking bundle without a store, a file or a device. `setWarp(…)` is the one impure
// step: it hands the result to `TimelineStore.setRegionWarp`, which applies it as ONE undo
// step. `WorkstationView` hands the stores over and messages neither — the shape
// `TheWorkstationHasADoorTests` claim F already names as the legal one.
//
// ⚠️ ONLY A PART WITH A KNOWN NATIVE TEMPO CAN WARP. "Warp to what?" has no answer for a clip
// whose `nativeBPM` is 0, and the engine agrees (`StretchPlan.resolve` returns rate 1.0 for
// it). Since #B2 the only writer of that field is the detected-tempo adoption, which writes
// KNOWN estimates only — so a switch that appears here appears because a detection was
// confident, and a part whose tempo stayed unclear offers no switch rather than a dead one.
//
// ⚠️ THE PART'S LENGTH FOLLOWS ITS STATE, because a flag alone would be half a warp. A warped
// part consumes media `rate`× as fast as song time passes, so a part sized for the recorded
// speed would either stop early and fall silent or cut the loop. The span is the file's
// length divided by the rate the ENGINE will play (`StretchPlan.resolve`, asked, not
// re-derived), in whole bars at the song tempo. Unwarped that is exactly what the import
// placed (`unwarpedRegion`, rate 1). Warped, while the tempo ratio stays inside
// `TempoMatch.rateRange`, it equals the file's bars at its NATIVE tempo — independent of the
// song tempo, the useful property: a warped 4-bar loop spans 4 bars at any tempo, including
// a flow tempo that follows the body. Outside that range the rate is clamped and the span
// follows the clamped rate instead.
// ⚠️ ONLY A WHOLE-FILE PART IS RESIZED (content offset 0). Nothing in this build can trim a
// part, but an older build's editor could, and a trimmed window is an authored length this
// switch must not overwrite: it keeps its length and changes only its rate.
//
// ⛔ WHAT IT DOES NOT DO. It never touches the session tempo, never moves a part, never
// writes a clip, and never changes `stretchMode` — the timeline default (`.clean`) is the
// only algorithm a user reaches, and choosing between them is a later, separate power.

import Foundation

public enum AudioWarp {

    /// What the switch on one audio track shows. `.unavailable` means no part on the track
    /// has a known native tempo, and the surface shows NO switch for it (a control that can
    /// only refuse is the decorative kind this surface was told not to grow).
    public enum LaneState: Equatable, Sendable {
        case unavailable
        case off
        case on
        /// Some eligible parts are warped and some are not — an older build could leave a
        /// track like that. The switch reads "Mixed" and a tap warps them all.
        case mixed
    }

    /// One part's new state. Built only by `changes(…)`; applied only by
    /// `TimelineStore.setRegionWarp`.
    public struct Change: Equatable, Sendable {
        public let regionID: UUID
        public let warpEnabled: Bool
        public let lengthTicks: Int
    }

    /// The parts on `laneID` that CAN warp: an audio part on an audio track whose clip carries
    /// a known native tempo. Document order.
    public static func eligibleRegions(laneID: UUID,
                                       in document: TimelineDocument,
                                       clips: [Clip]) -> [TimelineRegion] {
        guard document.lanes.contains(where: { $0.id == laneID && $0.kind == .audio }) else {
            return []
        }
        return document.regions.filter { region in
            guard region.laneID == laneID,
                  let clip = clips.first(where: { $0.id == region.clipID }) else { return false }
            return clip.kind == .audio && clip.nativeBPM.isFinite && clip.nativeBPM > 0
        }
    }

    public static func state(laneID: UUID,
                             in document: TimelineDocument,
                             clips: [Clip]) -> LaneState {
        let parts = eligibleRegions(laneID: laneID, in: document, clips: clips)
        guard !parts.isEmpty else { return .unavailable }
        let warped = parts.filter { $0.warpEnabled }.count
        if warped == 0 { return .off }
        return warped == parts.count ? .on : .mixed
    }

    /// Every eligible part on `laneID` that would CHANGE if warping were set to `enabled` —
    /// empty when the switch would do nothing, so the caller writes nothing (no undo spam).
    public static func changes(warp enabled: Bool,
                               laneID: UUID,
                               in document: TimelineDocument,
                               clips: [Clip],
                               bpm: Double) -> [Change] {
        eligibleRegions(laneID: laneID, in: document, clips: clips).compactMap {
            (region: TimelineRegion) -> Change? in
            guard let clip = clips.first(where: { $0.id == region.clipID }) else { return nil }
            let length = spanTicks(for: region, clip: clip, warped: enabled, bpm: bpm)
            guard region.warpEnabled != enabled || region.lengthTicks != length else { return nil }
            return Change(regionID: region.id, warpEnabled: enabled, lengthTicks: length)
        }
    }

    /// The length a part spans in the given state — the whole file in whole bars for a
    /// whole-file part, its own length otherwise (see the header). Never below one bar, never
    /// from a non-finite tempo or duration.
    public static func spanTicks(for region: TimelineRegion,
                                 clip: Clip,
                                 warped: Bool,
                                 bpm: Double) -> Int {
        guard region.contentOffsetSeconds == 0,
              let seconds = clip.nativeDurationSeconds, seconds.isFinite, seconds > 0,
              bpm.isFinite, bpm > 0 else {
            return region.lengthTicks
        }
        // The rate the ENGINE will play — asked, not re-derived (#416). `TempoMatch` clamps it
        // to 0.25…4, so "the file's bars at its native tempo" is only the same number while
        // the ratio stays inside that range; outside it, the part must span what the clamped
        // rate actually consumes, or it ends early (silence) or late (cut).
        let rate = StretchPlan.resolve(mode: region.stretchMode,
                                       warpEnabled: warped,
                                       nativeBPM: clip.nativeBPM,
                                       projectBPM: bpm,
                                       capabilities: StretchMode.timelineCapabilities).rate
        guard rate.isFinite, rate > 0 else { return region.lengthTicks }
        return AudioClipFactory.coveringBars(forDurationSeconds: seconds / rate, bpm: bpm)
            * TimelineTime.ticksPerBar
    }

    /// The switch. The surface calls this and nothing else; the write is the store's.
    @MainActor
    public static func setWarp(_ enabled: Bool,
                               laneID: UUID,
                               timeline: TimelineStore,
                               clipStore: ClipStore,
                               bpm: Double) {
        let plan = changes(warp: enabled, laneID: laneID, in: timeline.document,
                           clips: clipStore.filledClips, bpm: bpm)
        guard !plan.isEmpty else { return }
        timeline.setRegionWarp(plan)
    }
}
