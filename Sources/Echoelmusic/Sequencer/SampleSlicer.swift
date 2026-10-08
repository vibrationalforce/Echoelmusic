// SampleSlicer.swift
// Echoel — Sequencer (GMMW GA-6: where a sample's hits are). Pure value math, Foundation only.
//
//     mono PCM → TempoOnsetEnvelope (the tempo detector's own onset rule, ≈200 Hz)
//              → peaks over a threshold, one per minimum gap
//              → each peak refined to the first loud sample of its transient
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
    /// …and at least this share of the loudest onset in the sample, so a loud loop is cut at its
    /// hits rather than at every ghost note.
    static let relativeFloor: Double = 0.2
    /// The transient is found at the first sample reaching this share of its peak…
    static let transientShare: Float = 0.5
    /// …and the cut steps back over its rising edge to the last sample under this share, so a
    /// slice starts at the attack, not halfway up it.
    static let quietShare: Float = 0.1
    /// The longest stretch analysed; samples past it are not cut.
    static let maxSeconds: Double = 120
    /// The highest rate taken (768 kHz, the top of what audio interfaces offer). Past it, a hop or
    /// a gap in frames would no longer fit an `Int` — refused rather than trapped.
    static let maxSampleRate: Double = 768_000

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
        let peaks = peakHops(values, minimumGapHops: Swift.max(1, Int((minimumGapSeconds * envelope.rate).rounded(.up))))
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

    /// Envelope indices that are local maxima over the threshold, at most one per gap (the
    /// stronger one wins; on a tie, the earlier).
    static func peakHops(_ values: [Double], minimumGapHops: Int) -> [Int] {
        guard let loudest = values.max(), loudest.isFinite else { return [] }
        let threshold = Swift.max(absoluteFloor, relativeFloor * loudest)
        guard loudest >= threshold else { return [] }
        var accepted: [Int] = []
        for i in values.indices {
            let v = values[i]
            guard v.isFinite, v >= threshold else { continue }
            if i > values.startIndex, values[i - 1] > v { continue }
            if i + 1 < values.endIndex, values[i + 1] >= v { continue }
            if let last = accepted.last, i - last < minimumGapHops {
                if v > values[last] { accepted[accepted.count - 1] = i }
                continue
            }
            accepted.append(i)
        }
        return accepted
    }

    /// Where the hit near envelope hop `hop` starts: the first frame reaching `transientShare` of
    /// the loudest finite sample there, stepped back over the rising edge while the sample before
    /// is above `quietShare`. The window is the hop before through the hop after, because the
    /// first-difference band can carry a transient into the next hop.
    static func transientStart(in samples: [Float], hop: Int, hopLength: Int) -> Int {
        let length = Swift.max(1, hopLength)
        let low = Swift.max(0, (hop - 1) * length)
        let high = Swift.min(samples.count, (hop + 2) * length)
        guard low < high else { return Swift.min(Swift.max(0, hop * length), Swift.max(0, samples.count - 1)) }
        var peak: Float = 0
        for i in low..<high {
            let x = samples[i]
            if x.isFinite, abs(x) > peak { peak = abs(x) }
        }
        guard peak > 0 else { return hop * length }
        let level = peak * transientShare
        let quiet = peak * quietShare
        guard let reached = (low..<high).first(where: { samples[$0].isFinite && abs(samples[$0]) >= level }) else {
            return hop * length
        }
        var start = reached
        while start > low, samples[start - 1].isFinite, abs(samples[start - 1]) > quiet {
            start -= 1
        }
        return start
    }
}
