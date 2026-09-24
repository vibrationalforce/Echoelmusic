import Foundation

/// ITU-R BS.1770-4 / EBU R128 loudness meter — K-weighted, gated.
/// Provides the full professional set:
///   • Momentary (400 ms) and Short-term (3 s) sliding-window loudness, LUFS
///   • Integrated (gated, whole-program) loudness, LUFS
///   • Loudness Range (LRA, EBU TECH 3342), LU
///
/// Audio-thread safe: every buffer (ring buffers, running sums) is pre-allocated
/// at init; the per-sample path does only filtering and O(1) running-sum updates.
/// Integrated/LRA use bounded **loudness histograms** (libebur128 technique) so
/// memory is constant regardless of measurement length, and they are recomputed
/// only at the gating-block cadence (100 ms / 1 s), not per sample.
///
/// K-weighting is DERIVED PER SAMPLE RATE from the BS.1770 filter design (a high
/// shelf and the RLB high-pass, each by the bilinear transform — the derivation used
/// by libebur128), once, in `init`. At 48 kHz it reproduces the standard's published
/// coefficient table to double precision. Supported rates: `supportedSampleRates`.
/// At any other rate the meter DEGRADES EXPLICITLY — `supportsSampleRate` is false,
/// nothing is measured and every reading stays at the floor — rather than filtering
/// with coefficients that belong to a different rate (E3).
///
/// ⛔ Until E3 (2026-09-24) the canonical 48 kHz coefficients were used at EVERY rate,
/// and the old doc here called that "a close approximation". Measured at 44.1 kHz it
/// read +1.13 dB at 20 Hz, +0.39 dB at 60 Hz and +0.33 dB at 1.5 kHz too high — a
/// bass-dependent error, on the Master readout whenever the hardware granted 44.1 kHz.
/// Guard: `TheLoudnessMeterIsSampleRateCorrectTests`.
///
/// RATE CHANGE: the rate is fixed for the life of an instance (`let`). A new rate
/// means a NEW meter — which is what `AudioEngine.installMeterTap` does on every
/// (re)install, after `removeTap` — so filter state is never carried from one set of
/// coefficients to another. `reset()` clears state at the same rate.
///
/// Reference: ITU-R BS.1770-4; EBU R128; EBU TECH 3341/3342.
public final class EchoelLoudnessMeter: @unchecked Sendable {

    public static let floorLUFS: Float = -120

    /// Sample rates the K-weighting derivation is validated for: every rate in this range
    /// stays within 0.05 dB of the standard's 48 kHz response from 20 Hz to 20 kHz (and
    /// within 0.01 dB at 44.1 kHz). Below it the shelf sits too close to Nyquist; above
    /// it the Float filter loses the low end (+0.32 dB at 20 Hz measured at 384 kHz).
    public static let supportedSampleRates: ClosedRange<Float> = 44_100...192_000

    /// The rate this meter was built for.
    public let sampleRate: Float
    /// False when `sampleRate` is outside `supportedSampleRates` (or not finite): the
    /// meter then measures nothing and reads the floor — an explicit "no reading", never
    /// a reading filtered with another rate's coefficients.
    public let supportsSampleRate: Bool

    public private(set) var momentaryLUFS: Float = floorLUFS
    public private(set) var shortTermLUFS: Float = floorLUFS
    /// Gated integrated loudness over the whole measurement (since the last
    /// `reset()`), LUFS. Equals `floorLUFS` until enough gated blocks exist.
    public private(set) var integratedLUFS: Float = floorLUFS
    /// Loudness Range (LRA) in LU — P95 − P10 of the gated short-term
    /// distribution (EBU TECH 3342). `0` until enough data exists.
    public private(set) var loudnessRange: Float = 0

    // MARK: - K-weighting biquads (per channel)

    private var kL1: Biquad
    private var kL2: Biquad
    private var kR1: Biquad
    private var kR2: Biquad

    // MARK: - Sliding windows (squared, K-weighted)

    private var mRing: [Float]
    private var sRing: [Float]
    private let mLen: Int
    private let sLen: Int
    private var mIdx = 0
    private var sIdx = 0
    private var mSum: Double = 0
    private var sSum: Double = 0

    // MARK: - Gating histograms (bounded memory)

    /// 0.1 LU bins spanning the absolute gate floor up to +10 LUFS.
    private static let histMinLUFS: Float = -70.0
    private static let histBinWidth: Float = 0.1
    private static let histBinCount = 801          // −70.0 … +10.0
    private var integratedHist: [Int]              // 400 ms blocks @ 100 ms hop
    private var lraHist: [Int]                     // 3 s short-term @ 1 s hop
    private let hopLen: Int                         // 100 ms in samples
    private let lraHopLen: Int                      // 1 s in samples
    private var hopRemaining: Int
    private var lraRemaining: Int
    private var totalSamples: Int = 0

    private static let offsetLUFS: Float = -0.691  // BS.1770 absolute offset

    public init(sampleRate: Float = 48000) {
        let supported = sampleRate.isFinite && Self.supportedSampleRates.contains(sampleRate)
        // An unsupported rate still gets finite, allocated windows (at 48 kHz) so nothing
        // below can trap on `Int(NaN)`; `supportsSampleRate` keeps them unused.
        let rate: Float = supported ? sampleRate : 48_000
        self.sampleRate = sampleRate
        self.supportsSampleRate = supported
        let k = Self.kWeighting(sampleRate: Double(rate))
        self.kL1 = Biquad(k.shelf)
        self.kL2 = Biquad(k.highPass)
        self.kR1 = Biquad(k.shelf)
        self.kR2 = Biquad(k.highPass)
        self.mLen = Swift.max(1, Int(0.4 * rate))
        self.sLen = Swift.max(1, Int(3.0 * rate))
        self.mRing = [Float](repeating: 0, count: mLen)
        self.sRing = [Float](repeating: 0, count: sLen)
        self.integratedHist = [Int](repeating: 0, count: Self.histBinCount)
        self.lraHist = [Int](repeating: 0, count: Self.histBinCount)
        self.hopLen = Swift.max(1, Int(0.1 * rate))
        self.lraHopLen = Swift.max(1, Int(1.0 * rate))
        self.hopRemaining = hopLen
        self.lraRemaining = lraHopLen
    }

    /// Frames per 100 ms gating hop at this meter's rate. An offline caller that feeds
    /// exactly this many frames per call puts every 400 ms block on the BS.1770 grid
    /// (the meter records at most one block per call).
    public var gatingHopFrames: Int { hopLen }

    // MARK: - K-weighting design (BS.1770)

    /// One normalised biquad section (a0 = 1).
    public struct KWeightingSection: Equatable, Sendable {
        public let b0: Double, b1: Double, b2: Double, a1: Double, a2: Double
    }

    /// The two K-weighting sections for `sampleRate`, designed by the bilinear transform
    /// from the analogue prototypes behind BS.1770 (stage 1: high shelf, ≈ +4 dB above
    /// ≈ 1.68 kHz; stage 2: RLB high-pass at ≈ 38 Hz). Parameters are the ones that
    /// reproduce the standard's 48 kHz table (libebur128). Pure, setup-time only — never
    /// called per sample.
    public static func kWeighting(sampleRate: Double) -> (shelf: KWeightingSection, highPass: KWeightingSection) {
        // Stage 1 — high shelf.
        let shelfF0 = 1681.974450955533
        let shelfGainDB = 3.999843853973347
        let shelfQ = 0.7071752369554196
        let k1 = tan(Double.pi * shelfF0 / sampleRate)
        let vh = pow(10.0, shelfGainDB / 20.0)
        let vb = pow(vh, 0.4996667741545416)
        let d1 = 1.0 + k1 / shelfQ + k1 * k1
        let shelf = KWeightingSection(b0: (vh + vb * k1 / shelfQ + k1 * k1) / d1,
                                      b1: 2.0 * (k1 * k1 - vh) / d1,
                                      b2: (vh - vb * k1 / shelfQ + k1 * k1) / d1,
                                      a1: 2.0 * (k1 * k1 - 1.0) / d1,
                                      a2: (1.0 - k1 / shelfQ + k1 * k1) / d1)
        // Stage 2 — RLB high-pass (numerator fixed at 1, −2, 1, as in the standard).
        let highPassF0 = 38.13547087602444
        let highPassQ = 0.5003270373238773
        let k2 = tan(Double.pi * highPassF0 / sampleRate)
        let d2 = 1.0 + k2 / highPassQ + k2 * k2
        let highPass = KWeightingSection(b0: 1.0, b1: -2.0, b2: 1.0,
                                         a1: 2.0 * (k2 * k2 - 1.0) / d2,
                                         a2: (1.0 - k2 / highPassQ + k2 * k2) / d2)
        return (shelf, highPass)
    }

    // MARK: - Process

    /// Measure a mono buffer (channel weight 1.0). Audio-thread safe.
    public func process(_ buf: [Float], frameCount: Int) {
        guard supportsSampleRate else { return }
        let n = Swift.min(frameCount, buf.count)
        guard n > 0 else { return }
        for i in 0..<n {
            let y = kL2.process(kL1.process(buf[i]))
            accumulate(Double(y * y))
        }
        updateReadings()
        tickGating(n)
    }

    /// Measure a stereo pair — sum of K-weighted channel powers (L,R weight 1.0).
    public func processStereo(left: [Float], right: [Float], frameCount: Int) {
        guard supportsSampleRate else { return }
        let n = Swift.min(frameCount, Swift.min(left.count, right.count))
        guard n > 0 else { return }
        for i in 0..<n {
            let yl = kL2.process(kL1.process(left[i]))
            let yr = kR2.process(kR1.process(right[i]))
            accumulate(Double(yl * yl + yr * yr))
        }
        updateReadings()
        tickGating(n)
    }

    /// Measure a stereo pair from raw channel pointers — no allocation, for use
    /// inside an `AVAudioEngine` tap callback. `right` may be nil for mono (the
    /// left channel is then used for both sides).
    public func processStereo(left: UnsafePointer<Float>, right: UnsafePointer<Float>?, frameCount n: Int) {
        guard supportsSampleRate else { return }
        guard n > 0 else { return }
        for i in 0..<n {
            let l = left[i]
            let r = right?[i] ?? l
            let yl = kL2.process(kL1.process(l))
            let yr = kR2.process(kR1.process(r))
            accumulate(Double(yl * yl + yr * yr))
        }
        updateReadings()
        tickGating(n)
    }

    public func reset() {
        kL1.reset(); kL2.reset(); kR1.reset(); kR2.reset()
        for i in 0..<mLen { mRing[i] = 0 }
        for i in 0..<sLen { sRing[i] = 0 }
        mIdx = 0; sIdx = 0; mSum = 0; sSum = 0
        for i in 0..<Self.histBinCount { integratedHist[i] = 0; lraHist[i] = 0 }
        hopRemaining = hopLen
        lraRemaining = lraHopLen
        totalSamples = 0
        momentaryLUFS = Self.floorLUFS
        shortTermLUFS = Self.floorLUFS
        integratedLUFS = Self.floorLUFS
        loudnessRange = 0
    }

    // MARK: - Internals

    @inline(__always)
    private func accumulate(_ sq: Double) {
        mSum += sq - Double(mRing[mIdx]); mRing[mIdx] = Float(sq)
        mIdx += 1; if mIdx >= mLen { mIdx = 0 }
        sSum += sq - Double(sRing[sIdx]); sRing[sIdx] = Float(sq)
        sIdx += 1; if sIdx >= sLen { sIdx = 0 }
    }

    @inline(__always)
    private func updateReadings() {
        momentaryLUFS = loudness(meanSquare: mSum / Double(mLen))
        shortTermLUFS = loudness(meanSquare: sSum / Double(sLen))
    }

    /// Advance the gating clocks; at each 100 ms boundary record a 400 ms block
    /// into the integrated histogram, and at each 1 s boundary record a 3 s
    /// short-term value into the LRA histogram, then recompute the gated metrics.
    @inline(__always)
    private func tickGating(_ n: Int) {
        totalSamples += n
        hopRemaining -= n
        if hopRemaining <= 0 {
            hopRemaining += hopLen
            if totalSamples >= mLen {           // 400 ms window is full
                addToHist(&integratedHist, momentaryLUFS)
                recomputeIntegrated()
            }
        }
        lraRemaining -= n
        if lraRemaining <= 0 {
            lraRemaining += lraHopLen
            if totalSamples >= sLen {           // 3 s window is full
                addToHist(&lraHist, shortTermLUFS)
                recomputeLRA()
            }
        }
    }

    @inline(__always)
    private func addToHist(_ hist: inout [Int], _ loudnessLUFS: Float) {
        // Below the absolute gate (−70 LUFS) or non-finite → not counted.
        guard loudnessLUFS.isFinite, loudnessLUFS > Self.histMinLUFS else { return }
        var idx = Int((loudnessLUFS - Self.histMinLUFS) / Self.histBinWidth)
        if idx < 0 { idx = 0 }
        if idx >= Self.histBinCount { idx = Self.histBinCount - 1 }
        hist[idx] += 1
    }

    @inline(__always)
    private func binCenter(_ i: Int) -> Float {
        Self.histMinLUFS + (Float(i) + 0.5) * Self.histBinWidth
    }

    /// K-weighted mean-square (energy) corresponding to a loudness value.
    @inline(__always)
    private func energy(_ loudnessLUFS: Float) -> Double {
        pow(10.0, (Double(loudnessLUFS) + 0.691) / 10.0)
    }

    /// Two-pass gated integrated loudness (absolute −70 LUFS, then relative
    /// −10 LU below the ungated mean), per BS.1770-4.
    private func recomputeIntegrated() {
        var sumE = 0.0; var n = 0
        for i in 0..<Self.histBinCount where integratedHist[i] > 0 {
            sumE += energy(binCenter(i)) * Double(integratedHist[i]); n += integratedHist[i]
        }
        guard n > 0 else { integratedLUFS = Self.floorLUFS; return }
        let relGate = loudness(meanSquare: sumE / Double(n)) - 10.0
        var sumE2 = 0.0; var n2 = 0
        for i in 0..<Self.histBinCount where integratedHist[i] > 0 && binCenter(i) >= relGate {
            sumE2 += energy(binCenter(i)) * Double(integratedHist[i]); n2 += integratedHist[i]
        }
        integratedLUFS = n2 > 0 ? loudness(meanSquare: sumE2 / Double(n2)) : Self.floorLUFS
    }

    /// Loudness Range = P95 − P10 of the gated short-term distribution
    /// (absolute −70 LUFS, relative −20 LU below the ungated mean), EBU TECH 3342.
    private func recomputeLRA() {
        var sumE = 0.0; var n = 0
        for i in 0..<Self.histBinCount where lraHist[i] > 0 {
            sumE += energy(binCenter(i)) * Double(lraHist[i]); n += lraHist[i]
        }
        guard n > 0 else { loudnessRange = 0; return }
        let relGate = loudness(meanSquare: sumE / Double(n)) - 20.0

        var total = 0
        for i in 0..<Self.histBinCount where lraHist[i] > 0 && binCenter(i) >= relGate {
            total += lraHist[i]
        }
        guard total > 0 else { loudnessRange = 0; return }

        let p10Target = Swift.max(1, Int((Double(total) * 0.10).rounded(.up)))
        let p95Target = Swift.max(1, Int((Double(total) * 0.95).rounded(.up)))
        var cum = 0
        var p10 = Self.floorLUFS
        var p95 = Self.floorLUFS
        var got10 = false
        for i in 0..<Self.histBinCount where lraHist[i] > 0 && binCenter(i) >= relGate {
            cum += lraHist[i]
            if !got10 && cum >= p10Target { p10 = binCenter(i); got10 = true }
            if cum >= p95Target { p95 = binCenter(i); break }
        }
        loudnessRange = Swift.max(0, p95 - p10)
    }

    @inline(__always)
    private func loudness(meanSquare: Double) -> Float {
        guard meanSquare > 1e-12 else { return Self.floorLUFS }
        return Self.offsetLUFS + 10.0 * Float(log10(meanSquare))
    }

    // MARK: - Biquad (Direct Form II transposed)

    private struct Biquad {
        let b0: Float, b1: Float, b2: Float, a1: Float, a2: Float
        var s1: Float = 0
        var s2: Float = 0

        @inline(__always)
        mutating func process(_ x: Float) -> Float {
            let y = b0 * x + s1
            s1 = b1 * x + s2 - a1 * y
            s2 = b2 * x - a2 * y
            return y
        }

        mutating func reset() { s1 = 0; s2 = 0 }

        /// Built once from a designed section; the per-sample path runs in Float.
        init(_ c: KWeightingSection) {
            b0 = Float(c.b0); b1 = Float(c.b1); b2 = Float(c.b2)
            a1 = Float(c.a1); a2 = Float(c.a2)
        }
    }
}
