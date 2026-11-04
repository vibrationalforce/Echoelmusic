import Foundation

/// What a mixdown measures, offline, from start to end: the integrated loudness and true peak
/// (BS.1770, `LoudnessMeter`), the level of each octave band of the mid signal, the spectral
/// tilt those bands make, and the stereo image — correlation, the side's level against the
/// mid's, the correlation below 150 Hz and how much quieter the mix plays summed to mono.
///
/// Every number is measured, nothing is estimated or learned: the same samples give the same
/// report on every device. Silent stretches (a 100 ms hop below −70 dBFS) do not count toward
/// the band levels, so a song with a long silent intro is not read as quiet in every band.
public struct MixAnalysis: Equatable, Sendable {
    /// The octave bands' centres in Hz (ISO 266 preferred values).
    public static let bandCenters: [Double] = [31.5, 63, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
    /// The bands the tilt is fitted over: 125 Hz to 8 kHz, where a mix's balance is heard; the
    /// lowest and highest octaves move with the arrangement more than with the mix.
    public static let tiltBands: ClosedRange<Int> = 2...8
    /// A hop below this mean square (−70 dBFS) is silence and leaves the band levels alone.
    static let silentHop = 1e-7

    /// Integrated loudness in LUFS; −∞ for silence.
    public let integratedLoudness: Double
    /// The louder channel's true peak in dBTP; −∞ for silence.
    public let truePeak: Double
    /// The mid signal's level in each band of `bandCenters`, in dBFS (mean square over the hops
    /// that sound); −∞ for a band with nothing in it.
    public let bandLevels: [Double]
    /// The slope of a straight line fitted through `bandLevels` over `tiltBands`, in dB per
    /// octave; nil with fewer than three bands that sound.
    public let tilt: Double?
    /// The correlation of left and right, −1…1; nil when a channel is silent.
    public let correlation: Double?
    /// The same below 150 Hz, where a mix that is not mono loses its low end on one speaker or a
    /// phone; nil when nothing sounds there.
    public let lowCorrelation: Double?
    /// The side's level against the mid's in dB: −∞ for a mono mix, 0 when they are equal.
    public let sideToMid: Double?
    /// How much quieter the mix plays summed to mono, in dB (0 for a mono mix, −∞ for left = −right).
    public let monoLoss: Double?
    public let frameCount: Int

    public init(integratedLoudness: Double, truePeak: Double, bandLevels: [Double], tilt: Double?,
                correlation: Double?, lowCorrelation: Double?, sideToMid: Double?, monoLoss: Double?,
                frameCount: Int) {
        self.integratedLoudness = integratedLoudness
        self.truePeak = truePeak
        self.bandLevels = bandLevels
        self.tilt = tilt
        self.correlation = correlation
        self.lowCorrelation = lowCorrelation
        self.sideToMid = sideToMid
        self.monoLoss = monoLoss
        self.frameCount = frameCount
    }

    /// Whether anything sounded loud enough to be measured.
    public var isSilent: Bool { !integratedLoudness.isFinite }

    /// The mean-square level of the bands in `range` together, in dBFS; −∞ when none sounds.
    public func level(ofBands range: ClosedRange<Int>) -> Double {
        let power = range.reduce(0.0) { sum, index in
            guard bandLevels.indices.contains(index), bandLevels[index].isFinite else { return sum }
            return sum + Foundation.pow(10, bandLevels[index] / 10)
        }
        return power > 0 ? 10 * Foundation.log10(power) : -.infinity
    }

    /// The least-squares slope of `levels` against log2 of the band centres over `tiltBands`.
    static func fitTilt(_ levels: [Double]) -> Double? {
        var xs: [Double] = [], ys: [Double] = []
        for index in tiltBands where levels.indices.contains(index) && levels[index].isFinite {
            xs.append(Foundation.log2(bandCenters[index]))
            ys.append(levels[index])
        }
        guard xs.count >= 3 else { return nil }
        let n = Double(xs.count)
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        var sxy = 0.0, sxx = 0.0
        for (x, y) in zip(xs, ys) {
            sxy += (x - mx) * (y - my)
            sxx += (x - mx) * (x - mx)
        }
        return sxx > 0 ? sxy / sxx : nil
    }
}

/// Two tracks whose strongest octave is the same, at levels close enough that one hides the
/// other there. A hint for the mix, never a change: which one should give way is the musician's.
public struct MaskingHint: Equatable, Sendable {
    /// The index into `MixAnalysis.bandCenters`.
    public let band: Int
    /// The indices of the stems, as handed to `MaskingHint.find`, loudest first.
    public let stems: [Int]
    /// The difference between the loudest and the quietest of them in that band, in dB.
    public let spread: Double

    public var bandCenter: Double { MixAnalysis.bandCenters[band] }

    /// A band counts as a stem's own when it lies within this many dB of the stem's loudest band.
    public static let dominantWithin = 3.0
    /// Stems sharing a band mask each other when their levels there lie within this many dB.
    public static let closeWithin = 6.0
    /// The bands considered: 63 Hz to 8 kHz.
    public static let bands: ClosedRange<Int> = 1...8

    /// The hints for stems measured each on its own (`MixAnalysis.bandLevels`), by band.
    public static func find(stems: [[Double]]) -> [MaskingHint] {
        let dominant: [Set<Int>] = stems.map { levels in
            let sounding = bands.filter { levels.indices.contains($0) && levels[$0].isFinite && levels[$0] > -70 }
            guard let top = sounding.map({ levels[$0] }).max() else { return [] }
            return Set(sounding.filter { levels[$0] >= top - dominantWithin })
        }
        var hints: [MaskingHint] = []
        for band in bands {
            let sharing = stems.indices.filter { dominant[$0].contains(band) }
                .sorted { stems[$0][band] != stems[$1][band] ? stems[$0][band] > stems[$1][band] : $0 < $1 }
            guard sharing.count >= 2, let loudest = sharing.first.map({ stems[$0][band] }) else { continue }
            let close = sharing.filter { loudest - stems[$0][band] <= closeWithin }
            guard close.count >= 2, let quietest = close.last.map({ stems[$0][band] }) else { continue }
            hints.append(MaskingHint(band: band, stems: close, spread: loudest - quietest))
        }
        return hints
    }
}

/// Measures a stereo signal block by block into a `MixAnalysis`. Offline only: it keeps the
/// loudness meter's per-block values. `bandsOnly` skips loudness and stereo, for a stem whose
/// bands are all a masking hint needs.
public struct MixAnalyzer: Sendable {
    private let sampleRate: Double
    private let bandsOnly: Bool
    private var meter: LoudnessMeter
    private var bands: [BandSection]
    private var lowLeft: BandSection
    private var lowRight: BandSection
    private let hop: Int
    private var hopFill = 0
    private var hopPower = 0.0
    private var hopBands: [Double]
    private var bandSums: [Double]
    private var soundingHops = 0
    private var ll = 0.0, rr = 0.0, lr = 0.0, mm = 0.0, ss = 0.0
    private var lowLL = 0.0, lowRR = 0.0, lowLR = 0.0
    private var frames = 0

    public init(sampleRate: Double, bandsOnly: Bool = false) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.sampleRate = rate
        self.bandsOnly = bandsOnly
        meter = LoudnessMeter(sampleRate: rate)
        bands = MixAnalysis.bandCenters.map { BandSection(bandPassAt: $0, sampleRate: rate) }
        lowLeft = BandSection(lowPassAt: 150, sampleRate: rate)
        lowRight = BandSection(lowPassAt: 150, sampleRate: rate)
        hop = Swift.max(1, Int((rate / 10).rounded()))
        hopBands = Array(repeating: 0, count: MixAnalysis.bandCenters.count)
        bandSums = hopBands
    }

    public mutating func process(left l: UnsafePointer<Float>, right r: UnsafePointer<Float>, count: Int) {
        guard count > 0 else { return }
        if !bandsOnly { meter.process(left: l, right: r, count: count) }
        for i in 0..<count {
            let a = l[i].isFinite ? Double(l[i]) : 0, b = r[i].isFinite ? Double(r[i]) : 0
            let mid = (a + b) / 2
            for index in bands.indices {
                let y = bands[index].process(mid)
                hopBands[index] += y * y
            }
            hopPower += mid * mid
            if !bandsOnly {
                let side = (a - b) / 2
                ll += a * a; rr += b * b; lr += a * b; mm += mid * mid; ss += side * side
                let x = lowLeft.process(a), y = lowRight.process(b)
                lowLL += x * x; lowRR += y * y; lowLR += x * y
            }
            hopFill += 1
            if hopFill == hop { closeHop() }
        }
        frames += count
    }

    private mutating func closeHop() {
        if hopPower / Double(hop) > MixAnalysis.silentHop {
            for index in bandSums.indices { bandSums[index] += hopBands[index] }
            soundingHops += 1
        }
        for index in hopBands.indices { hopBands[index] = 0 }
        hopPower = 0
        hopFill = 0
    }

    /// The report for everything processed so far. A hop not yet closed is left out.
    public var analysis: MixAnalysis {
        let samples = Double(soundingHops * hop)
        let levels: [Double] = bandSums.map { sum in
            samples > 0 && sum > 0 ? 10 * Foundation.log10(sum / samples) : -.infinity
        }
        func correlate(_ xy: Double, _ xx: Double, _ yy: Double) -> Double? {
            let denominator = (xx * yy).squareRoot()
            return denominator > 1e-20 ? Swift.min(Swift.max(xy / denominator, -1), 1) : nil
        }
        let loud = bandsOnly ? LoudnessMeter.silent : meter.integratedLoudness
        let peak = bandsOnly ? LoudnessMeter.silent : meter.truePeak
        let sideToMid: Double? = bandsOnly || mm <= 0 ? nil : (ss > 0 ? 10 * Foundation.log10(ss / mm) : -.infinity)
        let stereo = (ll + rr) / 2
        let monoLoss: Double? = bandsOnly || stereo <= 0 ? nil : (mm > 0 ? 10 * Foundation.log10(mm / stereo) : -.infinity)
        return MixAnalysis(integratedLoudness: loud, truePeak: peak, bandLevels: levels,
                           tilt: MixAnalysis.fitTilt(levels),
                           correlation: bandsOnly ? nil : correlate(lr, ll, rr),
                           lowCorrelation: bandsOnly ? nil : correlate(lowLR, lowLL, lowRR),
                           sideToMid: sideToMid, monoLoss: monoLoss, frameCount: frames)
    }
}

/// Two identical RBJ biquads in a row, in double precision: an octave band-pass (constant 0 dB
/// peak, Q √2) or a Butterworth low-pass. Analysis only — it never sits in a signal path.
struct BandSection: Sendable {
    private var b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    private var z = (0.0, 0.0, 0.0, 0.0)

    init(bandPassAt hz: Double, sampleRate: Double) {
        let w = 2 * Double.pi * Swift.min(hz, sampleRate * 0.45) / sampleRate
        let alpha = sin(w) / (2 * 2.0.squareRoot())
        let a0 = 1 + alpha
        set(b0: alpha / a0, b1: 0, b2: -alpha / a0, a1: -2 * cos(w) / a0, a2: (1 - alpha) / a0)
    }

    init(lowPassAt hz: Double, sampleRate: Double) {
        let w = 2 * Double.pi * Swift.min(hz, sampleRate * 0.45) / sampleRate
        let alpha = sin(w) / (2 * 0.5.squareRoot())
        let c = cos(w), a0 = 1 + alpha
        set(b0: (1 - c) / 2 / a0, b1: (1 - c) / a0, b2: (1 - c) / 2 / a0, a1: -2 * c / a0, a2: (1 - alpha) / a0)
    }

    private mutating func set(b0: Double, b1: Double, b2: Double, a1: Double, a2: Double) {
        (self.b0, self.b1, self.b2, self.a1, self.a2) = (b0, b1, b2, a1, a2)
    }

    mutating func process(_ x: Double) -> Double {
        let y1 = b0 * x + z.0
        z.0 = b1 * x - a1 * y1 + z.1
        z.1 = b2 * x - a2 * y1
        let y2 = b0 * y1 + z.2
        z.2 = b1 * y1 - a1 * y2 + z.3
        z.3 = b2 * y1 - a2 * y2
        return y2
    }
}
