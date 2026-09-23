// TempoDetector.swift
// Echoel — the native tempo of a piece of AUDIO. Pure value math (Foundation only), so every
// decision below is driven by the blocking bundle on synthetic PCM without a file or a device.
//
//     mono PCM → TempoOnsetEnvelope (≈200 Hz onset strength)
//              → TempoDetector.estimate → DetectedTempo? (bpm · confidence · loop bars)
//
// ⭐ WHY THIS EXISTS (founder 2026-09-23, "WARP / NATIVE BPM: Approved"). The warp ENGINE was
// already whole: `EchoelmusicApp` injects `clip.nativeBPM` into `AudioLanePlayer`, which asks
// `StretchPlan.resolve` for a rate whenever a region is warped. What was missing was a
// PRODUCER — every imported clip carried `nativeBPM = 0`, so no region could ever warp. The
// only prior "estimate" in the repo, `AudioClipFactory.nativeBPM(forDurationSeconds:bpm:)`,
// never looks at the audio: it assumes the file is a whole-bar loop NEAR THE SESSION TEMPO and
// derives a tempo from its length. For anything that is not such a loop it returns a number
// with no evidence behind it. This type listens.
//
// ⛔ A DETECTED TEMPO IS NOT THE SESSION TEMPO, and nothing here can make it one. The result
// is a property of the MEDIA; the transport keeps its five enumerated T1 sources. Whoever
// wires a caller writes `Clip.nativeBPM` through `ClipStore`, never `Transport`.
//
// ⚠️ CONFIDENCE IS A HEURISTIC, NOT A PROBABILITY. It is the mean normalised autocorrelation of
// the onset envelope at the first `combDepth` multiples of the chosen beat period. Its floor
// was chosen from a MEASURED tradeoff on synthetic material, written at the constant; real
// recordings are UNMEASURED here and are a device question.
//
// THE ALGORITHM (each step is a decision a calibration run forced — see the constants):
//   1. Onset strength: per ~5 ms hop, log energy of the signal AND of its first difference
//      (a cheap high-pass, so hats and transients count), each averaged over a 4-hop frame,
//      half-wave-rectified frame-to-frame rise, summed.
//   2. Conditioning: 5-tap smoothing (human timing spreads a peak across hops), minus a
//      centred 1 s moving mean (a slow envelope must not autocorrelate at every lag).
//   3. Unbiased autocorrelation, normalised to 1 at lag 0.
//   4. Coarse pick over 40…240 BPM with a log-normal preference around 120 BPM.
//   5. Octave fold DOWN only, into [120/√2, 120·√2).
//   6. Refinement within ±2 % by a comb over the first four multiples of the period.
//   7. Confidence = mean autocorrelation over those multiples (a pulse, not an interval).
//   8. Loop snap: a file whose length is within 2 % of a power-of-two bar count at the found
//      tempo takes the EXACT tempo that length implies.

import Foundation

/// A tempo estimate for a piece of audio. Detected, never authored.
public struct DetectedTempo: Sendable, Equatable {
    /// Beats per minute, folded below `TempoDetector.foldCeilingBPM`.
    public var bpm: Double
    /// Mean normalised autocorrelation at the beat period's first multiples, 0…1.
    public var confidence: Double
    /// The other octave reading of the same pulse (×2 below 120 BPM, ÷2 at or above).
    ///
    /// ⚠️ THE OCTAVE IS A CONVENTION, NOT A MEASUREMENT. A 70 BPM groove with eighth-note hats
    /// and a 140 BPM groove are the same onset pattern; no autocorrelation can tell them apart.
    /// Step 5 makes the choice a stated rule, and this field hands the other reading to the
    /// person who knows which one they meant.
    public var octaveAlternativeBPM: Double
    /// Whole bars the media spans at `bpm`, when its length fits a power-of-two bar count —
    /// in which case `bpm` is the exact tempo that length implies. nil otherwise.
    public var loopBars: Int?
    /// Length of the whole media in seconds (not only the analysed window).
    public var mediaDurationSeconds: Double

    public init(bpm: Double, confidence: Double, octaveAlternativeBPM: Double,
                loopBars: Int?, mediaDurationSeconds: Double) {
        self.bpm = bpm
        self.confidence = confidence
        self.octaveAlternativeBPM = octaveAlternativeBPM
        self.loopBars = loopBars
        self.mediaDurationSeconds = mediaDurationSeconds
    }

    /// Whether this estimate may be used as a clip's native tempo. See `TempoDetector.isKnown`.
    public var isKnown: Bool { TempoDetector.isKnown(self) }
}

/// Streaming onset-strength envelope. Feed mono samples in any chunk size; the result does not
/// depend on how the stream was cut (the first-difference and the frame both carry across calls).
public struct TempoOnsetEnvelope: Sendable {
    /// Target envelope rate in Hz. The actual rate is `sampleRate / hop`.
    public static let targetRate: Double = 200
    /// Hops averaged into one energy frame (~20 ms).
    ///
    /// ⚠️ LOAD-BEARING, measured: with ONE hop, ~5 ms of a 220 Hz tone spans a non-integer
    /// number of cycles, so the per-hop energy of a STEADY tone oscillates. A sustained pad
    /// with no onsets at all then scored confidence 0.42. Four hops: 0.000.
    public static let frameHops = 4
    /// Log-energy floor (−80 dB) so digital silence has no onsets.
    static let energyFloor: Double = 1e-8

    public let hop: Int
    public let rate: Double
    public let maxCount: Int
    public private(set) var values: [Double] = []

    private var hopFill = 0
    private var hopFull: Double = 0
    private var hopHigh: Double = 0
    private var previousSample: Double = 0
    private var recentFull: [Double] = []
    private var recentHigh: [Double] = []
    private var lastLogFull: Double?
    private var lastLogHigh: Double?

    /// nil for a non-finite or non-positive sample rate. `maxSeconds` bounds memory and time.
    public init?(sampleRate: Double, maxSeconds: Double) {
        guard sampleRate.isFinite, sampleRate > 0, maxSeconds.isFinite, maxSeconds > 0 else { return nil }
        let h = Swift.max(1, Int((sampleRate / Self.targetRate).rounded(.toNearestOrEven)))
        hop = h
        rate = sampleRate / Double(h)
        maxCount = Swift.max(1, Int((maxSeconds * rate).rounded(.down)))
        values.reserveCapacity(Swift.min(maxCount, 1 << 16))
    }

    /// True once `maxSeconds` of envelope has been collected; further samples are ignored.
    public var isFull: Bool { values.count >= maxCount }

    public mutating func append(_ samples: some Sequence<Float>) {
        for sample in samples {
            guard !isFull else { return }
            let x = sample.isFinite ? Double(sample) : 0
            let d = x - previousSample
            previousSample = x
            hopFull += x * x
            hopHigh += d * d
            hopFill += 1
            if hopFill == hop { closeHop() }
        }
    }

    private mutating func closeHop() {
        let n = Double(hop)
        recentFull.append(hopFull / n)
        recentHigh.append(hopHigh / n)
        if recentFull.count > Self.frameHops { recentFull.removeFirst() }
        if recentHigh.count > Self.frameHops { recentHigh.removeFirst() }
        hopFull = 0
        hopHigh = 0
        hopFill = 0

        let frameFull = recentFull.reduce(0, +) / Double(recentFull.count)
        let frameHigh = recentHigh.reduce(0, +) / Double(recentHigh.count)
        let logFull = Foundation.log10(Swift.max(frameFull, Self.energyFloor))
        let logHigh = Foundation.log10(Swift.max(frameHigh, Self.energyFloor))
        var onset = 0.0
        if let lastFull = lastLogFull, let lastHigh = lastLogHigh {
            onset = Swift.max(0, logFull - lastFull) + Swift.max(0, logHigh - lastHigh)
        }
        lastLogFull = logFull
        lastLogHigh = logHigh
        values.append(onset)
    }
}

/// Estimates the native tempo of audio from its onset envelope. Offline only — never call this
/// from a render callback (it allocates and runs an O(n · lags) autocorrelation).
public enum TempoDetector {

    /// Bumped whenever a change here can move an estimate for the same audio.
    public static let algorithmVersion = 1

    public static let minBPM: Double = 40
    public static let maxBPM: Double = 240
    /// Centre and width of the log-normal preference used ONLY for the coarse pick.
    public static let preferredBPM: Double = 120
    public static let preferenceWidthOctaves: Double = 1
    /// Readings at or above this are halved. Below it nothing is doubled — see step 5.
    ///
    /// ⛔ FOLDING UP WAS THE FIRST DRAFT, AND IT WAS WRONG. For a pulse on quarter notes only,
    /// the doubled tempo's period lands BETWEEN beats, where there is no onset. Under the first
    /// confidence definition (one lag) that scored exactly 0 and every slow click track
    /// (70–82 BPM) was refused. Under the comb definition shipped here the same mutant scores
    /// 0.50 — half its multiples land on beats — and is reported KNOWN at DOUBLE the tempo,
    /// which is worse: a wrong number that passes. Halving is always supported, because every
    /// second beat is still a beat. The guard therefore pins the TEMPO of a slow pulse, not
    /// only its verdict.
    public static let foldCeilingBPM: Double = 120 * 2.0.squareRoot()
    /// Multiples of the beat period the refinement and the confidence look at.
    public static let combDepth = 4
    /// Shorter media returns nil — not enough periods to say anything.
    public static let minimumSeconds: Double = 1.5

    /// Below this confidence the estimate is UNKNOWN. [NEEDS-FOUNDER-VERIFY: import a handful
    /// of real loops and songs; if real grooves come back "Tempo unclear", this floor is too
    /// high — say which material.]
    ///
    /// ⭐ MEASURED, NOT CHOSEN (44.1 kHz, 120 draws per row, media 2–30 s, before the
    /// short-file rule below). Share of material NAMED a tempo it does not have / share of
    /// material REFUSED that has one, at floors 0.25 · 0.30 · 0.35:
    ///   free-rhythm melody     3.3 · 1.7 · 1.7 %      noise           3.3 · 2.5 · 0.8 %
    ///   speech-like bursts     3.3 · 3.3 · 1.7 %      random onsets   0.0 · 0.0 · 0.0 %
    ///   melody drawing from five fixed note lengths   15.8 · 10.0 · 5.8 %
    ///   drum loops (+noise, swing)   refused 0.0 · 0.0 · 0.0 %
    ///   single clicks, timing σ ≤ 10 ms   refused 0.0 · 0.0 · 0.0 %
    ///   single clicks, timing σ ≤ 20 ms   refused 7.5 · 15.8 · 30.8 %
    /// ⚠️ SYNTHETIC ONLY. What it cannot tell you: accuracy on mixed real music, on tempo that
    /// drifts, on odd meters. The five-length melody is the hardest negative because it
    /// genuinely repeats an interval; that it is not a PULSE is what step 7 measures.
    public static let confidenceFloor: Double = 0.3

    /// Media shorter than this is KNOWN only when it is also a whole loop (`loopBars != nil`).
    ///
    /// ⭐ MEASURED: under 4 s, conf ≥ 0.3 alone named a tempo for 20–40 % of noise, speech-like
    /// bursts and free melody — a few periods of anything autocorrelate by chance. Requiring
    /// the length to fit a power-of-two bar count dropped that to 0–2 %, refused 0 % of real
    /// 1–2-bar loops, and refused 97 % of arbitrary 2–4 s slices of a groove — which is the
    /// honest answer for a slice: too short to tell unless it IS a loop.
    public static let shortMediaSeconds: Double = 4
    public static let snapBarCounts: Set<Int> = [1, 2, 4, 8, 16, 32]
    public static let snapTolerance: Double = 0.02

    /// Normalised 5-tap smoothing kernel (Hann, 25 ms at 200 Hz).
    static let smoothingWeights: [Double] = [1.0 / 12, 3.0 / 12, 4.0 / 12, 3.0 / 12, 1.0 / 12]
    static let detrendSeconds: Double = 1

    /// The classification the rest of the app must ask — never `confidence` alone.
    public static func isKnown(_ tempo: DetectedTempo) -> Bool {
        guard tempo.bpm.isFinite, tempo.bpm > 0, tempo.confidence >= confidenceFloor else { return false }
        return tempo.mediaDurationSeconds >= shortMediaSeconds || tempo.loopBars != nil
    }

    /// nil when there is nothing to analyse: too short, a degenerate rate, or no onsets at all.
    public static func estimate(envelope: [Double],
                                envelopeRate: Double,
                                mediaDurationSeconds: Double) -> DetectedTempo? {
        guard envelopeRate.isFinite, envelopeRate > 0,
              mediaDurationSeconds.isFinite, mediaDurationSeconds >= minimumSeconds,
              envelope.count > 2 else { return nil }

        let e = condition(envelope, rate: envelopeRate)
        let n = e.count
        let ac0 = e.reduce(0) { $0 + $1 * $1 }
        guard ac0.isFinite, ac0 > 0 else { return nil }

        let wanted = Int((Double(combDepth) * 60 * envelopeRate / minBPM).rounded(.up)) + 2
        let maxLag = Swift.min(wanted, n - 1)
        var ac = [Double](repeating: 0, count: maxLag + 1)
        for lag in 0...maxLag {
            var sum = 0.0
            for t in 0..<(n - lag) { sum += e[t] * e[t + lag] }
            ac[lag] = sum / Double(n - lag) * Double(n) / ac0
        }

        func period(_ bpm: Double) -> Double { 60 * envelopeRate / bpm }

        // Coarse pick, weighted by the preference.
        var coarse = 0.0
        var coarseScore = -Double.infinity
        for i in 0...2000 {
            let bpm = minBPM + 0.1 * Double(i)
            guard bpm <= maxBPM + 1e-9 else { break }
            let p = period(bpm)
            guard p + 1 < Double(ac.count) else { continue }
            let score = interpolate(ac, at: p) * preference(bpm)
            if score > coarseScore { coarse = bpm; coarseScore = score }
        }
        guard coarse > 0 else { return nil }
        while coarse >= foldCeilingBPM { coarse /= 2 }

        // Refine with the comb.
        var refined = coarse
        var best = -Double.infinity
        let low = coarse * 0.98
        let high = coarse * 1.02
        var step = 0
        while true {
            let bpm = low + 0.01 * Double(step)
            guard bpm < high else { break }
            let s = comb(ac, period: period(bpm)).reduce(0, +)
            if s > best { refined = bpm; best = s }
            step += 1
        }

        let terms = comb(ac, period: period(refined)).map { Swift.min(1, Swift.max(0, $0)) }
        let confidence = terms.isEmpty ? 0 : terms.reduce(0, +) / Double(terms.count)

        var bpm = refined
        var loopBars: Int?
        let barSeconds = 60.0 * Double(TimelineTime.beatsPerBar)
        let bars = mediaDurationSeconds * bpm / barSeconds
        let nearest = Int(bars.rounded(.toNearestOrEven))
        if snapBarCounts.contains(nearest), Swift.abs(bars / Double(nearest) - 1) < snapTolerance {
            bpm = barSeconds * Double(nearest) / mediaDurationSeconds
            loopBars = nearest
        }

        let alternative = bpm < preferredBPM ? bpm * 2 : bpm / 2
        return DetectedTempo(bpm: bpm, confidence: confidence, octaveAlternativeBPM: alternative,
                             loopBars: loopBars, mediaDurationSeconds: mediaDurationSeconds)
    }

    // MARK: - Pieces

    /// Smooth, then subtract a centred moving mean (zero-padded at the edges).
    static func condition(_ env: [Double], rate: Double) -> [Double] {
        let n = env.count
        let w = smoothingWeights
        let half = w.count / 2
        var smooth = [Double](repeating: 0, count: n)
        for i in 0..<n {
            var s = 0.0
            for j in 0..<w.count {
                let k = i + half - j
                if k >= 0, k < n { s += env[k] * w[j] }
            }
            smooth[i] = s
        }

        let length = Swift.max(1, Int((rate * detrendSeconds).rounded(.toNearestOrEven)))
        let after = (length - 1) / 2
        let before = length - 1 - after
        var prefix = [Double](repeating: 0, count: n + 1)
        for i in 0..<n { prefix[i + 1] = prefix[i] + smooth[i] }
        var out = [Double](repeating: 0, count: n)
        for i in 0..<n {
            let lo = Swift.max(0, i - before)
            let hi = Swift.min(n - 1, i + after)
            let mean = (prefix[hi + 1] - prefix[lo]) / Double(length)
            out[i] = smooth[i] - mean
        }
        return out
    }

    /// Autocorrelation at the first `combDepth` multiples of `period` that fit.
    static func comb(_ ac: [Double], period: Double) -> [Double] {
        var out: [Double] = []
        var k = 1
        while k <= combDepth, Double(k) * period + 1 < Double(ac.count) {
            out.append(interpolate(ac, at: Double(k) * period))
            k += 1
        }
        return out
    }

    static func interpolate(_ ac: [Double], at lag: Double) -> Double {
        guard lag.isFinite else { return 0 }
        let i = Int(lag.rounded(.down))
        guard i >= 0, i + 1 < ac.count else { return 0 }
        let f = lag - Double(i)
        return ac[i] * (1 - f) + ac[i + 1] * f
    }

    static func preference(_ bpm: Double) -> Double {
        let z = Foundation.log2(bpm / preferredBPM) / preferenceWidthOctaves
        return Foundation.exp(-0.5 * z * z)
    }
}
