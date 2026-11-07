import Foundation

/// The tempo a piece of audio was played at — what warp stretches a region from (W-1). Ported from
/// the earlier app's proven detector (`Sources/Echoelmusic/Core/TempoDetector.swift`, guarded there
/// by `TheDetectedTempoIsHonestTests`): the same steps, constants and confidence floor, plus one
/// floor on a rise (`TempoOnsetEnvelope.riseFloor`) so a held tone is not heard as a pulse.
/// The warp engine needs a native tempo, and nothing produced one; this listens for it.
///
///     mono samples → TempoOnsetEnvelope (≈200 Hz onset strength)
///                  → TempoDetector.estimate → DetectedTempo? (bpm · confidence · loop bars)
///
/// A detected tempo is a property of the media, never the song's tempo: whoever uses it writes a
/// region's native tempo through the one door. Confidence is a heuristic, not a probability — the
/// mean normalised autocorrelation of the onset envelope at the first `combDepth` multiples of the
/// beat period. Its floor was measured on synthetic material; real recordings are a device question.
///
/// The steps:
///   1. Onset strength: per ~5 ms hop, log energy of the signal and of its first difference (a
///      cheap high-pass, so hats and transients count), each averaged over a 4-hop frame,
///      half-wave-rectified frame-to-frame rise, summed; a rise under `riseFloor` is none.
///   2. Conditioning: 5-tap smoothing, minus a centred 1 s moving mean.
///   3. Unbiased autocorrelation, normalised to 1 at lag 0.
///   4. Coarse pick over 40…240 BPM with a log-normal preference around 120 BPM.
///   5. Octave fold down only, into [120/√2, 120·√2).
///   6. Refinement within ±2 % by a comb over the first four multiples of the period.
///   7. Confidence = mean autocorrelation over those multiples (a pulse, not an interval).
///   8. Loop snap: media within 2 % of a power-of-two bar count at the found tempo takes the exact
///      tempo that length implies.
///
/// Offline only: it allocates and runs an O(n · lags) autocorrelation. Never on the render thread.
public struct DetectedTempo: Sendable, Equatable {
    /// Beats per minute, folded below `TempoDetector.foldCeilingBPM`.
    public var bpm: Double
    /// Mean normalised autocorrelation at the beat period's first multiples, 0…1.
    public var confidence: Double
    /// The other octave reading of the same pulse (×2 below 120 BPM, ÷2 at or above). The octave
    /// is a convention, not a measurement: a 70 BPM groove with eighth-note hats and a 140 BPM
    /// groove are the same onset pattern.
    public var octaveAlternativeBPM: Double
    /// Whole bars the media spans at `bpm`, when its length fits a power-of-two bar count — in
    /// which case `bpm` is the exact tempo that length implies. nil otherwise.
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

    /// Whether this estimate may be used as a native tempo. See `TempoDetector.isKnown`.
    public var isKnown: Bool { TempoDetector.isKnown(self) }
}

/// Streaming onset-strength envelope. Feed mono samples in any chunk size; the result does not
/// depend on how the stream was cut (the first difference and the frame carry across calls).
public struct TempoOnsetEnvelope: Sendable {
    /// Target envelope rate in Hz. The actual rate is `sampleRate / hop`.
    public static let targetRate: Double = 200
    /// Hops averaged into one energy frame (~20 ms). With one hop, ~5 ms of a steady tone spans a
    /// non-integer number of cycles and its energy oscillates: a sustained pad scored confidence
    /// 0.42 in the earlier app's measurement. Four hops: 0.000.
    public static let frameHops = 4
    /// Log-energy floor (−80 dB) so digital silence has no onsets.
    static let energyFloor: Double = 1e-8
    /// A frame-to-frame rise below this (the two log10 terms summed, about 2 dB) is no onset.
    /// New in the port, measured on its mirror at 48 kHz: a held sine's frame energy ripples
    /// periodically wherever 20 ms is not a whole number of its cycles — up to 0.07 for a 55 Hz
    /// tone — and the ripple autocorrelates like a pulse. Without this floor a held 440 Hz or
    /// 41.2 Hz sine was named a tempo (confidence 0.79 and 0.90); with it neither is, and click,
    /// kick and drum-loop fixtures read the same tempo and confidence as before. Hats ~25 dB under
    /// a held chord still read 128.01 BPM at confidence 0.94.
    static let riseFloor: Double = 0.2

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

    /// nil for a sample rate that is not a positive number up to 1 MHz, or a `maxSeconds` that is
    /// not one up to a day. `maxSeconds` bounds memory and time.
    public init?(sampleRate: Double, maxSeconds: Double) {
        guard sampleRate.isFinite, sampleRate > 0, sampleRate <= 1_000_000,
              maxSeconds.isFinite, maxSeconds > 0, maxSeconds <= 86_400 else { return nil }
        let samplesPerHop = Swift.max(1, Int((sampleRate / Self.targetRate).rounded(.toNearestOrEven)))
        hop = samplesPerHop
        rate = sampleRate / Double(samplesPerHop)
        maxCount = Swift.max(1, Int((maxSeconds * rate).rounded(.down)))
        values.reserveCapacity(Swift.min(maxCount, 1 << 16))
    }

    /// True once `maxSeconds` of envelope has been collected; further samples are ignored.
    public var isFull: Bool { values.count >= maxCount }

    /// Non-finite samples count as silence.
    public mutating func append(_ samples: some Sequence<Float>) {
        for sample in samples {
            guard !isFull else { return }
            let x = sample.isFinite ? Double(sample) : 0
            let difference = x - previousSample
            previousSample = x
            hopFull += x * x
            hopHigh += difference * difference
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
            if onset < Self.riseFloor { onset = 0 }
        }
        lastLogFull = logFull
        lastLogHigh = logHigh
        values.append(onset)
    }
}

/// Estimates the native tempo of audio from its onset envelope. Offline only.
public enum TempoDetector {
    public static let minBPM: Double = 40
    public static let maxBPM: Double = 240
    /// Centre and width of the log-normal preference used only for the coarse pick.
    public static let preferredBPM: Double = 120
    public static let preferenceWidthOctaves: Double = 1
    /// Readings at or above this are halved; below it nothing is doubled. Folding up as well was
    /// the earlier app's first draft and wrong: for a pulse on quarter notes only, the doubled
    /// period lands between beats, half its comb multiples still land on beats, and a slow click
    /// track was reported known at double its tempo. Halving is always supported.
    public static let foldCeilingBPM: Double = 120 * 2.0.squareRoot()
    /// Multiples of the beat period the refinement and the confidence look at.
    public static let combDepth = 4
    /// Shorter media returns nil — not enough periods to say anything.
    public static let minimumSeconds: Double = 1.5
    /// Below this confidence the estimate is unknown. Measured in the earlier app (44.1 kHz, 120
    /// draws per row, synthetic only): at 0.3, noise, speech-like bursts and free melody are named
    /// a tempo 0.8–3.3 % of the time, drum loops and clicks with timing σ ≤ 10 ms are refused 0 %.
    public static let confidenceFloor: Double = 0.3
    /// Media shorter than this is known only when it is also a whole loop (`loopBars != nil`): a
    /// few periods of anything autocorrelate by chance.
    public static let shortMediaSeconds: Double = 4
    public static let snapBarCounts: Set<Int> = [1, 2, 4, 8, 16, 32]
    public static let snapTolerance: Double = 0.02
    /// The longest stretch analysed; longer media is analysed from its middle — an intro or outro
    /// is the part of a song most likely to have no beat.
    public static let analysisSeconds: Double = 90

    /// Normalised 5-tap smoothing kernel (Hann, 25 ms at 200 Hz).
    static let smoothingWeights: [Double] = [1.0 / 12, 3.0 / 12, 4.0 / 12, 3.0 / 12, 1.0 / 12]
    static let detrendSeconds: Double = 1

    /// The classification the rest of the app must ask — never `confidence` alone.
    public static func isKnown(_ tempo: DetectedTempo) -> Bool {
        guard tempo.bpm.isFinite, tempo.bpm > 0, tempo.confidence >= confidenceFloor else { return false }
        return tempo.mediaDurationSeconds >= shortMediaSeconds || tempo.loopBars != nil
    }

    /// The tempo of `samples` (mono, at `sampleRate`) when it is known, else nil: too short, no
    /// onsets, no steady pulse (noise, a held tone), or `isCancelled` said stop. Up to
    /// `analysisSeconds` from the middle are analysed; the loop snap uses the whole length, in bars
    /// of `beatsPerBar` quarter notes.
    public static func detect(_ samples: [Float], sampleRate: Double, beatsPerBar: Double = 4,
                              isCancelled: () -> Bool = { false }) -> DetectedTempo? {
        detect(frameCount: samples.count, sampleRate: sampleRate, beatsPerBar: beatsPerBar,
               isCancelled: isCancelled) { samples[$0] }
    }

    /// As `detect(_:sampleRate:…)`, over a decoded sample — a stereo one's two sides averaged —
    /// read where it is, so a long file is not copied to be heard.
    public static func detect(_ buffer: SampleBuffer, beatsPerBar: Double = 4,
                              isCancelled: () -> Bool = { false }) -> DetectedTempo? {
        detect(frameCount: buffer.frameCount, sampleRate: buffer.sampleRate, beatsPerBar: beatsPerBar,
               isCancelled: isCancelled) { buffer.mono($0) }
    }

    private static func detect(frameCount: Int, sampleRate: Double, beatsPerBar: Double,
                               isCancelled: () -> Bool, sample: (Int) -> Float) -> DetectedTempo? {
        guard sampleRate.isFinite, sampleRate > 0, frameCount > 0,
              var envelope = TempoOnsetEnvelope(sampleRate: sampleRate, maxSeconds: analysisSeconds) else { return nil }
        let window = Int((analysisSeconds * sampleRate).rounded(.down))
        var first = frameCount > window ? (frameCount - window) / 2 : 0
        let chunkSize = 16_384
        var chunk = [Float](repeating: 0, count: chunkSize)
        while first < frameCount, !envelope.isFull {
            if isCancelled() { return nil }
            let stop = Swift.min(frameCount, first + chunkSize)
            for index in first..<stop { chunk[index - first] = sample(index) }
            envelope.append(chunk[0..<(stop - first)])
            first = stop
        }
        guard let tempo = estimate(envelope: envelope.values, envelopeRate: envelope.rate,
                                   mediaDurationSeconds: Double(frameCount) / sampleRate,
                                   beatsPerBar: beatsPerBar),
              tempo.isKnown else { return nil }
        return tempo
    }

    /// nil when there is nothing to analyse: too short, a degenerate rate, or no onsets at all.
    /// The result may be unknown (`isKnown`); `detect` returns only known ones. A bar is
    /// `beatsPerBar` quarter notes, 0.5…64.
    public static func estimate(envelope: [Double], envelopeRate: Double, mediaDurationSeconds: Double,
                                beatsPerBar: Double = 4) -> DetectedTempo? {
        guard envelopeRate.isFinite, envelopeRate > 0, envelopeRate <= 100_000,
              mediaDurationSeconds.isFinite, mediaDurationSeconds >= minimumSeconds, mediaDurationSeconds <= 1e9,
              beatsPerBar.isFinite, beatsPerBar >= 0.5, beatsPerBar <= 64, envelope.count > 2 else { return nil }

        let conditioned = condition(envelope, rate: envelopeRate)
        let n = conditioned.count
        let energy = conditioned.reduce(0) { $0 + $1 * $1 }
        guard energy.isFinite, energy > 0 else { return nil }

        let wanted = Int((Double(combDepth) * 60 * envelopeRate / minBPM).rounded(.up)) + 2
        let maxLag = Swift.min(wanted, n - 1)
        var ac = [Double](repeating: 0, count: maxLag + 1)
        for lag in 0...maxLag {
            var sum = 0.0
            for t in 0..<(n - lag) { sum += conditioned[t] * conditioned[t + lag] }
            ac[lag] = sum / Double(n - lag) * Double(n) / energy
        }

        // Coarse pick, weighted by the preference.
        var coarse = 0.0
        var coarseScore = -Double.infinity
        for i in 0...2000 {
            let bpm = minBPM + 0.1 * Double(i)
            guard bpm <= maxBPM + 1e-9 else { break }
            let lag = period(bpm, rate: envelopeRate)
            guard lag + 1 < Double(ac.count) else { continue }
            let score = interpolate(ac, at: lag) * preference(bpm)
            if score > coarseScore {
                coarse = bpm
                coarseScore = score
            }
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
            let sum = comb(ac, period: period(bpm, rate: envelopeRate)).reduce(0, +)
            if sum > best {
                refined = bpm
                best = sum
            }
            step += 1
        }

        let terms = comb(ac, period: period(refined, rate: envelopeRate)).map { Swift.min(1, Swift.max(0, $0)) }
        let confidence = terms.isEmpty ? 0 : terms.reduce(0, +) / Double(terms.count)

        var bpm = refined
        var loopBars: Int?
        let barSeconds = 60.0 * beatsPerBar
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

    static func period(_ bpm: Double, rate: Double) -> Double { 60 * rate / bpm }

    /// Smooth, then subtract a centred moving mean (zero-padded at the edges).
    static func condition(_ envelope: [Double], rate: Double) -> [Double] {
        let n = envelope.count
        let weights = smoothingWeights
        let half = weights.count / 2
        var smooth = [Double](repeating: 0, count: n)
        for i in 0..<n {
            var sum = 0.0
            for j in 0..<weights.count {
                let k = i + half - j
                if k >= 0, k < n { sum += envelope[k] * weights[j] }
            }
            smooth[i] = sum
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
        let fraction = lag - Double(i)
        return ac[i] * (1 - fraction) + ac[i + 1] * fraction
    }

    static func preference(_ bpm: Double) -> Double {
        let z = Foundation.log2(bpm / preferredBPM) / preferenceWidthOctaves
        return Foundation.exp(-0.5 * z * z)
    }
}
