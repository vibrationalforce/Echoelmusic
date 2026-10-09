// VideoLanePlan.swift
// Echoel — Sequencer
//
// GMMW VV-7 (founder 2026-10-04, E12: "play the video track first"): the PURE plan for a
// picture lane — which video part a lane shows at a transport tick, where in its file, how long
// it still runs, and how a player that has drifted off the song clock gets back onto it. No
// AVFoundation, no clock, no state.
//
// ⭐ ONE CLOCK. The song clock is the transport `PatternEngine` drives, the one every lane rides.
// This file never asks a player what time it is and keeps no time of its own: it maps a tick the
// transport hands it to a file position, and it compares a position a player REPORTS with the one
// that tick demands. ⚠️ THE EXECUTOR DOES NOT EXIST YET (VV-8): nothing plays a picture lane today,
// and `.video` stays out of `ClipKind.timelineEngineKinds` until something does — the label moves
// with the engine, never ahead of it (#1438). Nor does a PRODUCER: nothing in `Sources/` makes a
// picture lane or a video clip yet, so engine and producer are two open facts, not one.
//
// ⭐ PRECEDENCE IS NOT DEFINED HERE (#1440). Which part a lane shows is
// `TimelineScheduling.activeRegion`, asked directly (`shot(in:…)`) or through `videoLaneEvents`,
// which asks it. This file never walks the document's regions itself — a second walk would be a
// second answer to "which of two overlapping parts wins", and the two would drift.
//
// ⭐ WHERE IN THE FILE IS NOT DEFINED HERE EITHER (#416). `AudioRegionPlayback.filePositionSeconds`
// already owns "the part's file offset plus the song seconds since it began". A picture part runs at
// rate 1 — a stretched picture is out of scope — so it is asked with an explicit `stretchRate: 1`,
// not the default, because a default that no call site writes appears in no diff (#431).
//
// ⭐ THE FILE ANSWER IS THE RESOLVER'S (#1439). A part shows only if the injected resolver — the
// same `(clipID) -> URL?` shape `AudioLanePlayer` takes, backed by `MediaLibrary.resolveRef` at its
// construction site — finds its file. A part whose file is gone, or whose clip is not a video,
// shows NOTHING rather than a stale frame from the part before it.
//
// ⚠️ THE KIND CHECK IS DELIBERATE, and it differs from the audio and MIDI engines on purpose. Those
// are kind-blind by design (`TimelineRegionPlayer` records a `clip.kind` guard there as a rejected
// second definition): any clip on their lane goes to their sink. A picture player cannot show a
// `.wav`, so a non-video clip on a picture lane is nothing to show — dark, not an error.
//
// ⚠️ MUTE IS NOT DECIDED HERE. The deleted video-lane player hid a muted picture lane (`isMuted`
// only — never solo or level — with a note to revisit it with the founder). This plan ignores mute;
// which of the three a picture lane honours is VV-8's question, and a founder one.
//
// ⭐ THE RESYNC RAMP is ported from `VideoResyncPolicy` (built 2026-07-13; the judder fix `56ba9c2`,
// 2026-07-16; deleted with the old video-lane engine in `2f86a6b`, 2026-07-25). Its one hard-won
// rule survives unchanged: the rate correction starts at ZERO at the deadband edge. The first
// version jumped from rate 1 straight to a ~1.7 % slew the moment drift crossed one frame, and at
// the correction cadence drift hovering at the edge flipped the rate in and out — a visible
// shimmer. Correcting only the drift BEYOND the deadband makes the rate continuous with `hold`.
// Two things did not come along: the `dt` argument (the old law never read it) and the
// "region switched or wrapped" flag — a part change, a locate or a cycle wrap is a NEW SHOT that
// the executor primes from `shot(in:…)`, never an input to the drift correction.

import Foundation

public enum VideoLanePlan {

    /// What one picture lane shows: the part, its file, and where in that file at the planned tick.
    public struct Shot: Equatable, Sendable {
        public let laneID: UUID
        public let regionID: UUID
        public let clipID: UUID
        /// The resolved file — never a bare reference (#1439).
        public let url: URL
        /// Seconds into the FILE at the planned tick. Finite and ≥ 0 by construction.
        public let mediaSeconds: Double
        /// Song seconds from the planned tick to the part's end: when this lane goes dark unless
        /// another part takes over.
        public let remainingSeconds: Double
        /// True when the file has already run out at the planned tick: the lane holds the file's
        /// last frame, still, for the rest of the part. `mediaSeconds` then sits just inside that
        /// frame. A clip whose length was not measured at import never holds HERE; `resync` closes
        /// that gap with the length the player measured.
        public let holdsLastFrame: Bool
    }

    /// What a picture lane does at one transport step — the video twin of
    /// `TimelineScheduling.LaneEvent`, one per lane in `videoLaneIDs` order.
    public enum Command: Equatable, Sendable {
        /// The same part as the step before (or still a gap): leave the player alone. Drift is
        /// `resync`'s job, not a reload. Meaningful only between CONTIGUOUS steps — across a cycle
        /// wrap or a locate the same part can stay active and still need a new position, so the
        /// executor re-primes from `shot(in:…)` there instead of asking `commands`.
        case keep(laneID: UUID)
        /// A different part became active: load its file and run it from `mediaSeconds`.
        case show(Shot)
        /// No part, or a part with nothing to show (file gone, not a video): the lane goes dark.
        case clear(laneID: UUID)
    }

    /// How a running player gets back onto the song clock.
    public enum Resync: Equatable, Sendable {
        /// Within one frame: leave it — a seek here would only add a visible hitch.
        case hold
        /// Multiply the player's normal rate by this factor. Always within `1 ± maxSlew`, and it
        /// leaves `1` continuously at the deadband edge.
        case nudge(rate: Float)
        /// Too far to slew back in time (or a still frame that is wrong): jump to the expected
        /// file position.
        case seek(toSeconds: Double)
    }

    /// One frame at 30 fps. Drift up to this is held (the old policy's 0.033, written as what it is).
    public static let deadbandSeconds: Double = 1.0 / 30.0
    /// Drift beyond this cannot be slewed away in a useful time: seek instead.
    public static let seekBeyondSeconds: Double = 0.25
    /// The largest rate change a nudge may make (±3 %) — small enough not to read as a speed change.
    public static let maxSlew: Double = 0.03
    /// Rate change per second of drift BEYOND the deadband. 0.06 s of excess (0.093 s of drift)
    /// reaches `maxSlew`.
    public static let slewPerSecondOfDrift: Double = 0.5
    /// How far inside the file's end a held last frame sits, so a seek lands on a frame and not
    /// past the last one.
    public static let lastFrameMarginSeconds: Double = 0.0001

    /// The shot `laneID` shows at `tick` — for priming the lane when the transport starts,
    /// locates or wraps its cycle. `nil` when the lane is not a picture lane, the tick falls in a
    /// gap, or the active part has nothing to show.
    public static func shot(in document: TimelineDocument, laneID: UUID, at tick: Int, bpm: Double,
                            clip: (UUID) -> Clip?, resolveURL: (UUID) -> URL?) -> Shot? {
        guard document.videoLaneIDs.contains(laneID),
              let region = TimelineScheduling.activeRegion(in: document, laneID: laneID, at: tick) else {
            return nil
        }
        return shot(of: region, at: tick, bpm: bpm, clip: clip, resolveURL: resolveURL)
    }

    /// Every picture lane's command for the transport moving `fromTick` → `toTick`, in lane order —
    /// for one contiguous step. A wrap or a locate is a new shot, primed from `shot(in:…)`, the way
    /// `AudioLanePlayer` re-primes on wrap and relocate.
    /// A `.load` from the scheduler becomes `.show` when the part has something to show and
    /// `.clear` when it does not — so the lane never keeps the PREVIOUS part's picture over a part
    /// whose file is missing.
    public static func commands(in document: TimelineDocument, fromTick: Int, toTick: Int, bpm: Double,
                                clip: (UUID) -> Clip?, resolveURL: (UUID) -> URL?) -> [Command] {
        TimelineScheduling.videoLaneEvents(in: document, fromTick: fromTick, toTick: toTick).map { scheduled in
            switch scheduled.event {
            case .unchanged:
                return .keep(laneID: scheduled.laneID)
            case .clear:
                return .clear(laneID: scheduled.laneID)
            case .load(let region):
                guard let next = shot(of: region, at: toTick, bpm: bpm, clip: clip, resolveURL: resolveURL) else {
                    return .clear(laneID: scheduled.laneID)
                }
                return .show(next)
            }
        }
    }

    /// The correction for a player showing `observedSeconds` of the file while the song clock
    /// expects `shot.mediaSeconds`. Drift > 0 means the picture is AHEAD (slow down, rate < 1);
    /// drift < 0 means it is BEHIND (speed up, rate > 1). A still last frame is never nudged —
    /// it is either right (hold) or wrong (seek).
    ///
    /// `itemSeconds` is the length the PLAYER measured for its item, or nil while it does not know.
    /// It closes the one gap `shot` cannot: a clip whose length was not measured at import never
    /// holds there, so past the file's end the plan keeps asking for positions the file does not
    /// have — and a player stopped at its end would be sought past it on every correction. Past
    /// `itemSeconds` the lane holds the item's last frame instead, exactly as a measured clip does.
    /// Required, never defaulted: a default no call site writes appears in no diff (#431).
    public static func resync(_ shot: Shot, observedSeconds: Double, itemSeconds: Double?) -> Resync {
        var expected = shot.mediaSeconds
        var still = shot.holdsLastFrame
        if !still, let held = lastFrame(at: expected, fileSeconds: itemSeconds) {
            expected = held
            still = true
        }
        guard observedSeconds.isFinite else { return .seek(toSeconds: expected) }
        let drift = observedSeconds - expected
        let size = abs(drift)
        if size <= deadbandSeconds { return .hold }
        if still || size > seekBeyondSeconds { return .seek(toSeconds: expected) }
        let slew = ((size - deadbandSeconds) * slewPerSecondOfDrift).clamped(to: 0...maxSlew)
        return .nudge(rate: Float(drift > 0 ? 1 - slew : 1 + slew))
    }

    /// The one place a part becomes a shot: both entry points above come here, so priming and
    /// stepping can never disagree about what a part shows.
    private static func shot(of region: TimelineRegion, at tick: Int, bpm: Double,
                             clip: (UUID) -> Clip?, resolveURL: (UUID) -> URL?) -> Shot? {
        guard bpm.isFinite, bpm > 0,
              let media = clip(region.clipID), media.kind == .video,
              let url = resolveURL(region.clipID),
              let position = AudioRegionPlayback.filePositionSeconds(for: region, atTick: tick, bpm: bpm,
                                                                     stretchRate: 1),
              position.isFinite else { return nil }
        let remaining = TimelineTime.seconds(fromTicks: region.endTick - tick, bpm: bpm)
        if let held = lastFrame(at: position, fileSeconds: media.nativeDurationSeconds) {
            return Shot(laneID: region.laneID, regionID: region.id, clipID: region.clipID, url: url,
                        mediaSeconds: held, remainingSeconds: remaining, holdsLastFrame: true)
        }
        return Shot(laneID: region.laneID, regionID: region.id, clipID: region.clipID, url: url,
                    mediaSeconds: position, remainingSeconds: remaining, holdsLastFrame: false)
    }

    /// Where the held last frame sits when a file of `fileSeconds` has run out at `position`, or
    /// nil while it still runs or its length is unknown — the one definition `shot` (the length
    /// measured at import) and `resync` (the length the player measured) both ask.
    private static func lastFrame(at position: Double, fileSeconds: Double?) -> Double? {
        guard let fileSeconds, fileSeconds.isFinite, fileSeconds > 0, position >= fileSeconds else { return nil }
        return Swift.max(0, fileSeconds - lastFrameMarginSeconds)
    }
}
