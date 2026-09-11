//  DiatonicHarmony.swift
//  Echoel — harmony intervals that KNOW THE KEY (#1252, S7 of PLAN_AUDIO_INPUT_2026-09-11).
//
//  WHY. The voice harmonizer (#841) adds two pitched copies at FIXED intervals (major third,
//  perfect fifth by default). A fixed major third above the sung E in C major is G♯ — outside
//  the key. Founder 2026-09-11: the voice should be adapted *"an die Stimmung"* — the mood of
//  the piece, which in this instrument is its KEY (`StudioDefaultKeys.rootIndex/.scale`, the
//  same definition `updateVoiceTune` already reads). This type answers one question: given the
//  sung note and the key, how many semitones up are the diatonic third and fifth?
//
//  RULE. The sung note is mapped to its NEAREST scale degree (ties resolve downward, so a
//  leading tone that is sung a little sharp still harmonises from below). The harmony notes are
//  the scale degrees `steps` above THAT degree, and the returned intervals are measured from the
//  SUNG pitch class — so a note sung a semitone off the scale still receives harmony ON the
//  scale, which is the whole point.
//
//  Foundation-only value logic; called at the ~15 Hz tune tick on the main actor, never in a
//  render block.

import Foundation

public enum DiatonicHarmony {

    /// Scale-degree steps for "a third" and "a fifth" above (0-based degree offsets).
    public static let thirdAndFifth = (2, 4)

    /// Semitone intervals (above the sung note) of the scale degrees `steps` above the sung
    /// note's nearest degree in `key`. Always positive, within 1…19.
    public static func intervals(aboveMidi midi: Int, in key: MusicalKey,
                                 steps: (Int, Int) = thirdAndFifth) -> (first: Int, second: Int) {
        let scale = key.scale.intervals
        guard !scale.isEmpty else { return (4, 7) }
        let sungRel = (((midi - key.root) % 12) + 12) % 12      // sung pitch class, relative to the tonic
        let degree = nearestDegreeIndex(to: sungRel, in: scale)
        func interval(_ step: Int) -> Int {
            let target = degree + step
            let octaves = target / scale.count
            let idx = target % scale.count
            let harmonyRel = scale[idx] + 12 * octaves
            let up = harmonyRel - sungRel
            return up > 0 ? up : up + 12
        }
        return (interval(steps.0), interval(steps.1))
    }

    /// MIDI note number for `hz` at concert pitch `a4Hz`, rounded to the nearest semitone.
    /// `nil` for a non-positive or non-finite input.
    public static func midi(forHz hz: Double, a4Hz: Double) -> Int? {
        guard hz > 0, hz.isFinite, a4Hz > 0, a4Hz.isFinite else { return nil }
        return Int((69 + 12 * log2(hz / a4Hz)).rounded())
    }

    /// Index of the scale degree nearest to `rel` (0…11); ties resolve to the LOWER degree.
    static func nearestDegreeIndex(to rel: Int, in scale: [Int]) -> Int {
        var best = 0
        var bestDistance = Int.max
        for (i, s) in scale.enumerated() {
            let d = min(abs(s - rel), 12 - abs(s - rel))   // circular distance
            if d < bestDistance || (d == bestDistance && s < scale[best] && s <= rel) {
                best = i
                bestDistance = d
            }
        }
        return best
    }
}
