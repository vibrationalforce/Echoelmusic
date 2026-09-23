//
//  AudioTempoCorrection.swift
//  Echoelmusic — Sequencer
//
//  S1 (founder 2026-09-23, "all tasks"): correcting an imported file's OWN tempo — a one-tap
//  ×2 / ÷2 and a hand-entered value for a file the detector called "Tempo unclear".
//
//  ⭐ THE TEMPO IS A PROPERTY OF THE CLIP, and it is INAUDIBLE until Warp is on. A region
//  plays at rate 1.0 unless `warpEnabled` (`StretchPlan.resolve` reads that first), and
//  `AudioWarp.spanTicks(warped: false)` never reads `nativeBPM`. So correcting an unwarped
//  file changes nothing the listener hears and no part length — which is why this may run
//  while the song plays, unlike the Warp switch.
//
//  ⚠️ LOCKED WHILE A PART OF THE CLIP IS WARPED. A warped part's span was sized FROM this
//  tempo; changing it underneath would leave that span stale, and re-deriving it mid-song
//  touches a chain attached at prime time (the `AudioLanePlayer.prime` "review HIGH 2" law).
//  The Warp switch already re-derives the span from the corrected tempo when it is turned on,
//  so no second length writer exists. The lock needs `nativeBPM > 0` as well: a warped region
//  on a clip with no tempo (an older build) plays at rate 1.0 and shows no Warp switch, so a
//  lock there would name a control the user cannot find.
//
//  ⭐ TWO WRITERS OF `Clip.nativeBPM`, ONE RULE EACH. Detection (`adoptDetectedNativeBPM`)
//  writes only while the value is 0 (never-clobber); this authored path OVERRIDES — that is
//  its purpose. No provenance flag is needed: a detection that finishes after the user typed
//  a tempo is refused by never-clobber.
//
//  The range is `AudioClipRegion.nativeBPMRange`, forwarded, never restated (#416); the clamp
//  is `Clip.clampedNativeBPM`. ×2 / ÷2 are exact octaves and are OFFERED only when the result
//  stays in range — a clamped "×2" is not ×2.
//

import Foundation

public enum AudioTempoCorrection {

    /// The ONE native-tempo range. Computed: nothing stored, nothing to share (#1402).
    public static var bounds: ClosedRange<Double> { AudioClipRegion.nativeBPMRange }

    /// A tempo the clip may take, or nil for a non-finite or non-positive proposal ("not set"
    /// is not something this path writes). Clamped by the one clamp `Clip` owns.
    public static func accepted(_ proposed: Double) -> Double? {
        let bpm = Clip.clampedNativeBPM(proposed)
        return bpm > 0 ? bpm : nil
    }

    /// ×2 of a known tempo, or nil when unknown or out of range.
    public static func doubled(_ bpm: Double) -> Double? { octave(bpm, factor: 2) }

    /// ÷2 of a known tempo, or nil when unknown or out of range.
    public static func halved(_ bpm: Double) -> Double? { octave(bpm, factor: 0.5) }

    static func octave(_ bpm: Double, factor: Double) -> Double? {
        guard bpm.isFinite, bpm > 0 else { return nil }
        let target = bpm * factor
        return bounds.contains(target) ? target : nil
    }

    /// What the field shows before anything is set: the clip's tempo if known, else the song
    /// tempo clamped into range, else the range floor. Displayed only — never written by itself.
    public static func startingValue(nativeBPM: Double, songBPM: Double) -> Double {
        if nativeBPM.isFinite, nativeBPM > 0 { return nativeBPM }
        return accepted(songBPM) ?? bounds.lowerBound
    }

    /// True while a part of this clip is warped AND the clip has a tempo — the only case in
    /// which a part's span depends on the value (see the file header).
    public static func isLockedByWarp(clip: Clip, in document: TimelineDocument) -> Bool {
        guard clip.nativeBPM > 0 else { return false }
        return document.regions.contains { $0.clipID == clip.id && $0.warpEnabled }
    }

    /// The distinct AUDIO clips placed on one lane, in first-placement order. A clip placed
    /// twice is one row, because the tempo belongs to the file, not to the placement.
    public static func audioClips(onLane laneID: UUID, in document: TimelineDocument,
                                  clips: [Clip]) -> [Clip] {
        var seen = Set<UUID>()
        var ordered: [Clip] = []
        for region in document.regions where region.laneID == laneID {
            guard !seen.contains(region.clipID),
                  let clip = clips.first(where: { $0.id == region.clipID }),
                  clip.kind == .audio else { continue }
            seen.insert(clip.id)
            ordered.append(clip)
        }
        return ordered
    }

    /// The seam (the `AudioWarp.setWarp` shape): the decision here, the write in the store.
    /// Refuses, writing nothing, for an unknown clip or one locked by warp.
    @MainActor @discardableResult
    public static func setNativeBPM(_ bpm: Double, clipID: UUID,
                                    in document: TimelineDocument,
                                    clipStore: ClipStore) -> Bool {
        guard let clip = clipStore.clip(id: clipID),
              !isLockedByWarp(clip: clip, in: document) else { return false }
        return clipStore.setAuthoredNativeBPM(id: clipID, bpm)
    }
}
