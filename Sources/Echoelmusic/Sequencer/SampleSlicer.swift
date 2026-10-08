// SampleSlicer.swift
// Echoel — Sequencer (GMMW GA-6: where a sample's hits are). Pure value math, Foundation only.
//
//     mono PCM → TempoOnsetEnvelope (the tempo detector's own onset rule, ≈200 Hz)
//              → every local peak over a threshold
//              → strongest first: each refined to where its attack starts; a cut within the
//                minimum gap of one already kept is the same hit
//              → slice points in FRAMES, sorted, the first always 0
//
// ⭐ WHY THIS EXISTS. A drum loop or a phrase dropped on a Sampler track plays as one block. Cutting
// it into its hits — the step every sampler workstation offers — needs the frames where the hits
// start. Onset math already exists for tempo (`TempoOnsetEnvelope`), so the slicer asks THAT rule
// instead of growing a second detector (#416): a change to what counts as an onset moves the tempo
// reading and the cuts together.
//
// ⚠️ NO CALLER YET, ON PURPOSE. Where the slice points live (beside the track's sample) and what a
// slice plays are GA-7 and a founder gate — this slice is the pure half, registered in
// `docs/dev/FEATURE_STATUS.md` §2c so it is not a lost core.
//
// ⚠️ THE THRESHOLDS ARE CHOSEN ON SYNTHETIC MATERIAL (clicks, decaying noise bursts, a steady tone);
// how they cut real loops is UNMEASURED. NEEDS-FOUNDER-VERIFY once a caller exists: slice a few
// real drum loops and phrases, say where a cut is missing or extra.
// ⚠️ A KNOWN SOFT SPOT, measured on synthetic material: a hit about 12 dB under a sustained pad is
// marginal — some are missed, and a found one can be cut up to one hop (≈5 ms) EARLY, because the
// pad's own rise passes for the attack. Early adds a little pad before the hit; it never loses the
// attack, which is the direction a cut must not err in.
//
// ⭐ THREE RULES THE GA-6 REVIEW (dsp-reviewer) CORRECTED, each pinned by its own fixture:
// · No gap rule among the PEAKS. A greedy "one peak per gap" let each louder hit of a rising roll
//   replace the last until one cut was left (0.3 / 0.6 / 1.0 at 45 ms read as ONE hit); the
//   strongest-first pass over FRAMES already decides which of two close hits is the cut.
// · The relative floor is taken from the loudest onset CAPPED at `referenceCap`. A rise out of
//   digital silence scores ≈10 whatever follows, so five zero frames before a loop raised the
//   floor over every hit in it and the loop came back uncut.
// · The attack is found in the FIRST DIFFERENCE, held over one hop, not in the level. Over a pad,
//   a bass, a DC offset or a kick's body the level is never quiet, so the cut ran back to the
//   window's start (7 ms early) or swallowed a snare 51 ms after a kick; and the level crosses zero
//   every half-cycle, so a tonal attack was cut a whole cycle late.
//
// Offline only — it allocates; never call it from a render callback.

import Foundation

enum SampleSlicer {

    /// The most slice points one sample gets, the start included. Past this, the strongest hits win.
    static let maxSlices = 32
    /// Two cuts closer than this are one hit (a flam, a crackle). 50 ms is a sixteenth at 300 BPM.
    static let minimumGapSeconds: Double = 0.05
    /// An onset must rise at least this much (log10 energy units summed over the full and the
    /// high-passed band — 0.5 ≈ 5 dB in one band) to be a hit at all, so steady material and a
    /// noise floor never cut.
    static let absoluteFloor: Double = 0.5
    /// …and at least this share of the loudest onset in the sample (capped, `referenceCap`), so a
    /// loud loop is cut at its hits rather than at every ghost note.
    static let relativeFloor: Double = 0.2
    /// The attack is found at the first sample whose rise reaches this share of the largest rise
    /// near the hit…
    static let transientShare: Float = 0.5
    /// …and the cut steps back while the hop before it still rises above this share, so a slice
    /// starts where the attack begins, not halfway up it.
    static let quietShare: Float = 0.1
    /// The longest stretch analysed; samples past it are not cut.
    static let maxSeconds: Double = 120
    /// The highest rate taken (768 kHz, the top of what audio interfaces offer). Above it a rate is
    /// a corrupt header, not audio — refused. (It is a plausibility limit, not an overflow guard:
    /// nothing here overflows below about 1e16 Hz. The first wording said otherwise.)
    static let maxSampleRate: Double = 768_000
    /// The loudest onset counted for `relativeFloor` is capped here (log10 units, as the envelope):
    /// an entry out of digital silence scores ≈10 and must not set the floor for every hit after it.
    /// At 4 the relative floor tops out at 0.8 — above the 0.6 the second hop of any steady entry
    /// scores, so a sustained entry still yields one cut, not two.
    static let referenceCap: Double = 4

    /// Slice points of `samples` in frames: sorted, unique, the first always 0, at most
    /// `maxSlices`. Silence or a sample with no hit gives `[0]`. nil for a non-finite,
    /// non-positive or implausibly high sample rate. Non-finite samples count as silence.
    static func slicePoints(samples: [Float], sampleRate: Double) -> [Int]? {
        guard sampleRate.isFinite, sampleRate > 0, sampleRate <= maxSampleRate,
              var envelope = TempoOnsetEnvelope(sampleRate: sampleRate, maxSeconds: maxSeconds) else {
            return nil
        }
        envelope.append(samples)
        let values = envelope.values
        let hop = envelope.hop
        let peaks = peakHops(values)
        let ranked = peaks.sorted { values[$0] != values[$1] ? values[$0] > values[$1] : $0 < $1 }
        let minimumGapFrames = Swift.max(1, Int((minimumGapSeconds * sampleRate).rounded(.up)))

        var points: [Int] = [0]
        for hopIndex in ranked {
            guard points.count < maxSlices else { break }
            let frame = transientStart(in: samples, hop: hopIndex, hopLength: hop)
            // A cut close to the start or to a stronger cut is the same hit.
            guard !points.contains(where: { abs($0 - frame) < minimumGapFrames }) else { continue }
            points.append(frame)
        }
        return points.sorted()
    }

    /// Envelope indices that are local maxima over the threshold — EVERY one. Which of two close
    /// peaks becomes the cut is decided strongest-first in `slicePoints`, never here (header). A
    /// plateau of equal values counts once, at its first hop.
    static func peakHops(_ values: [Double]) -> [Int] {
        guard let loudest = values.max(), loudest.isFinite else { return [] }
        let threshold = Swift.max(absoluteFloor, relativeFloor * Swift.min(loudest, referenceCap))
        guard loudest >= threshold else { return [] }
        var peaks: [Int] = []
        for i in values.indices {
            let v = values[i]
            guard v.isFinite, v >= threshold else { continue }
            if i > values.startIndex, values[i - 1] >= v { continue }
            if i + 1 < values.endIndex, values[i + 1] > v { continue }
            peaks.append(i)
        }
        return peaks
    }

    /// Where the hit near envelope hop `hop` starts. Read in the RISE — the first difference
    /// |x[n] − x[n−1]| — because a pad, a bass or a DC offset holds a level but does not rise:
    /// the first frame whose rise reaches `transientShare` of the window's largest, stepped back
    /// while the hop ending just before it still rises above `quietShare` (held over one hop, so a
    /// tonal attack is one rise, not one per half-cycle). The window is the hop before through the
    /// hop after, because the first-difference band can carry a transient into the next hop and a
    /// hit starting late in a hop over a bed peaks one hop later.
    static func transientStart(in samples: [Float], hop: Int, hopLength: Int) -> Int {
        let length = Swift.max(1, hopLength)
        let low = Swift.max(0, (hop - 1) * length)
        let high = Swift.min(samples.count, (hop + 2) * length)
        guard low < high else { return Swift.min(Swift.max(0, hop * length), Swift.max(0, samples.count - 1)) }
        // One hop behind the window as well, so the hold at its first frames sees what came before.
        let reach = Swift.max(0, low - length)
        var rises = [Float](repeating: 0, count: high - reach)
        for n in reach..<high { rises[n - reach] = rise(in: samples, at: n) }
        var peak: Float = 0
        for n in low..<high where rises[n - reach] > peak { peak = rises[n - reach] }
        guard peak > 0 else { return hop * length }
        let level = peak * transientShare
        let quiet = peak * quietShare
        guard let reached = (low..<high).first(where: { rises[$0 - reach] >= level }) else {
            return hop * length
        }
        // The latest frame, at or before each one, whose rise is above `quiet` (Int.min: none yet).
        var latestLoud = [Int](repeating: Int.min, count: rises.count)
        var latest = Int.min
        for k in rises.indices {
            if rises[k] > quiet { latest = reach + k }
            latestLoud[k] = latest
        }
        var start = reached
        while start > low, start - 1 >= reach, latestLoud[start - 1 - reach] >= start - length {
            start -= 1
        }
        return start
    }

    /// |x[n] − x[n−1]|: a non-finite sample counts as silence, and so does the one before the first.
    private static func rise(in samples: [Float], at n: Int) -> Float {
        guard n >= 0, n < samples.count else { return 0 }
        let x = samples[n].isFinite ? samples[n] : 0
        let previous: Float = n > 0 && samples[n - 1].isFinite ? samples[n - 1] : 0
        return abs(x - previous)
    }
}
