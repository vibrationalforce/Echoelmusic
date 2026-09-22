// AudioClipFactory.swift
// Echoelmusic — Sequencer
//
// PURE landing helper: turns an imported audio file (file reference + measured
// duration) into a Clip(kind:.audio) + a TimelineRegion sized to a musical bar
// grid, so the audio-import path drops a clip onto a lane through ONE tested seam.
// No AVFoundation, no file I/O here — the caller measures
// the duration on device (AVAsset) and passes it in. All logic is deterministic:
// no Date()/random/UUID() inside the math (callers pass fixed IDs in tests).

import Foundation

public enum AudioClipFactory {

    /// Number of beats per bar assumed by the bar/tempo heuristics (4/4).
    public static let beatsPerBar = TimelineTime.beatsPerBar   // 4

    /// An `.audio` clip referencing `mediaRef`. The import path stores an
    /// ABSOLUTE path (into the App Group `Media/Audio` dir) so the timeline's
    /// resolver — `URL(fileURLWithPath:)` + `fileExists` — finds the file
    /// directly; do NOT switch this to a relative/last-path-component ref
    /// without also changing that resolver.
    public static func clip(name: String, mediaRef: String, colorIndex: Int = 0,
                            nativeDurationSeconds: Double? = nil) -> Clip {
        Clip(name: name, colorIndex: colorIndex, kind: .audio, mediaRef: mediaRef,
             nativeDurationSeconds: nativeDurationSeconds)
    }

    /// Best-guess bar length for an audio clip of `durationSeconds` at `bpm`,
    /// snapped to a power of two (1/2/4/8) via `TempoMatch.guessBars` so a
    /// well-cut loop lands on an integer-bar boundary with no manual entry.
    /// Falls back to `1` bar for non-positive / un-guessable inputs — a clip is
    /// never zero bars long.
    public static func guessBars(forDurationSeconds durationSeconds: Double,
                                 bpm: Double,
                                 candidates: [Int] = [1, 2, 4, 8]) -> Int {
        guard durationSeconds > 0, bpm > 0 else { return 1 }
        let guessed = TempoMatch.guessBars(durationSeconds: durationSeconds,
                                           masterBPM: bpm,
                                           beatsPerBar: beatsPerBar,
                                           candidates: candidates)
        return max(1, guessed ?? 1)
    }

    /// The implied native tempo (BPM) of an audio clip of `durationSeconds`,
    /// derived from its guessed integer-bar length. Falls back to `bpm` (treat
    /// the clip as already at the master tempo) when it can't be guessed —
    /// never returns 0, so callers can divide by it safely.
    public static func nativeBPM(forDurationSeconds durationSeconds: Double,
                                 bpm: Double) -> Double {
        guard durationSeconds > 0, bpm > 0 else { return max(bpm, 0) }
        let bars = guessBars(forDurationSeconds: durationSeconds, bpm: bpm)
        return TempoMatch.nativeBPM(durationSeconds: durationSeconds,
                                    bars: bars,
                                    beatsPerBar: beatsPerBar) ?? bpm
    }

    /// A region placing an audio clip of `durationSeconds` at `startTick` on
    /// `laneID`, sized to a whole number of bars. The bar count is derived from
    /// `durationSeconds` and the clip's own `nativeBPM` (rounded to the nearest
    /// bar, ≥ 1), so `lengthTicks == bars * TimelineTime.ticksPerBar` — the clip
    /// occupies an honest musical span on the grid. `contentOffsetSeconds` trims
    /// into the media (default 0 = from the top). `bpm` is accepted for signature
    /// parity with the caller but does not affect the tick length
    /// (bars are a musical count, not a wall-clock one).
    public static func region(forDurationSeconds durationSeconds: Double,
                              bpm: Double,
                              laneID: UUID,
                              clipID: UUID,
                              startTick: Int,
                              nativeBPM: Double,
                              contentOffsetSeconds: Double = 0,
                              gain: Float = 1,
                              warpEnabled: Bool = false,
                              stretchMode: StretchMode = .clean) -> TimelineRegion {
        let bars = barCount(forDurationSeconds: durationSeconds, nativeBPM: nativeBPM)
        let lengthTicks = bars * TimelineTime.ticksPerBar
        return TimelineRegion(laneID: laneID,
                              clipID: clipID,
                              startTick: max(0, startTick),
                              lengthTicks: lengthTicks,
                              contentOffsetSeconds: max(0, contentOffsetSeconds),
                              gain: gain,
                              warpEnabled: warpEnabled,
                              stretchMode: stretchMode)
    }

    /// Whole bars that COVER `durationSeconds` at `bpm` — ceil, floored at 1.
    ///
    /// ⭐ WHY THIS EXISTS BESIDE `barCount`, WHICH ROUNDS (Audio Import V1). `barCount` is
    /// built for a WELL-CUT LOOP whose native tempo is known: rounding to the nearest bar is
    /// how a 3,97-bar loop lands on 4 and plays in time. An UNWARPED import has no native
    /// tempo — the founder's decision 7 for this slice is `nativeBPM = 0`, do not estimate —
    /// so there is no loop to snap to, and rounding DOWN silently truncates the tail: a
    /// 5-second file at 120 bpm is 2,5 bars, `barCount` says 2, and the last second is
    /// simply never scheduled. Half the durations in a uniform distribution round down, so
    /// this is the everyday case, not an edge one.
    ///
    /// ⚠️ THE COST OF COVERING IS SILENCE, NOT SOUND, and that asymmetry is the argument.
    /// A region LONGER than its media plays the media and then nothing — inaudible. A region
    /// SHORTER than its media loses audio the user imported. One of those two is a bug.
    ///
    /// ⚠️ A DEGENERATE `bpm` RETURNS 1, IT DOES NOT SUBSTITUTE A TEMPO. `TimelineTime.ticks`
    /// is already NaN/inf-safe and returns 0 for a non-positive or non-finite tempo; quietly
    /// swapping in a default here would be an invisible musical decision made by a helper.
    /// The one production caller passes `TimelineRegionPlayer.preflightTempo`, which mirrors
    /// the clamped transport tempo, so the fallback is unreachable from the door.
    public static func coveringBars(forDurationSeconds durationSeconds: Double,
                                    bpm: Double) -> Int {
        let ticks = TimelineTime.ticks(fromSeconds: durationSeconds, bpm: bpm)
        guard ticks > 0, TimelineTime.ticksPerBar > 0 else { return 1 }
        let bars = (Double(ticks) / Double(TimelineTime.ticksPerBar)).rounded(.up)
        return max(1, Int(bars))
    }

    /// The region an UNWARPED audio import places: whole bars that COVER the media, at
    /// `startTick` on `laneID`. `warpEnabled` and `stretchMode` keep their initialiser
    /// defaults (`false` / `.clean`), which `StretchPlan.resolve` turns into rate 1.0 — the
    /// media plays at its recorded speed, which is what "unwarped" means.
    ///
    /// ⚠️ IT IS NOT `region(forDurationSeconds:…)` WITH A DIFFERENT ROUNDING. That one takes
    /// a `nativeBPM` and derives the span from it; this one has no native tempo to take, and
    /// passing the SESSION tempo into that parameter would read, correctly, as a BPM
    /// estimate — the exact thing founder decision 7 forbids. Two questions, two functions.
    public static func unwarpedRegion(forDurationSeconds durationSeconds: Double,
                                      bpm: Double,
                                      laneID: UUID,
                                      clipID: UUID,
                                      startTick: Int) -> TimelineRegion {
        let bars = coveringBars(forDurationSeconds: durationSeconds, bpm: bpm)
        return TimelineRegion(laneID: laneID,
                              clipID: clipID,
                              startTick: max(0, startTick),
                              lengthTicks: bars * TimelineTime.ticksPerBar)
    }

    /// Whole-bar count for `durationSeconds` at `nativeBPM`, rounded to the
    /// nearest bar and floored at 1. Pure; guards non-positive inputs.
    static func barCount(forDurationSeconds durationSeconds: Double,
                         nativeBPM: Double) -> Int {
        guard durationSeconds > 0, nativeBPM > 0, beatsPerBar > 0 else { return 1 }
        let bars = durationSeconds * nativeBPM / (60.0 * Double(beatsPerBar))
        return max(1, Int(bars.rounded()))
    }
}
