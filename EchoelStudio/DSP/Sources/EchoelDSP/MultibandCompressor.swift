import Foundation

/// A three-band compressor: the sound split into low, mid and high at two crossovers, each band
/// compressed on its own threshold and ratio, and summed again with one makeup gain — so a
/// booming bass is held without the voice above it ducking. Written new for Echoel Studio
/// (ECHOELTOOLS catalog B10), as a value of settings and a render-thread processor like `Chorus`.
///
/// The crossovers are Linkwitz-Riley of the fourth order, two Butterworth `ZDFStage`s in a row
/// for each side of a split: their low and high outputs add up to an allpass, so with every
/// band uncompressed the bands sum back to the input's magnitude exactly. The low band also runs
/// through the second split's allpass, so all three bands share one phase and the sum stays
/// flat. Each band is a `Compressor` (stereo-linked, soft knee of 6 dB, its own envelope), with
/// one attack and release for all three. The crossover frequencies glide per sample and the
/// makeup in ~10 ms. One bad sample empties the filters and comes out as silence. Owned by the
/// render thread: set `settings` and call `process` from that thread. Its band buffers are
/// allocated in `init`; nothing allocates after that.
public final class MultibandCompressor: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// Hz between low and mid, 50 … 1000.
        public var lowCrossover: Double
        /// Hz between mid and high, 1000 … 12000.
        public var highCrossover: Double
        /// Per band, low first: dBFS −60 … 0.
        public var lowThreshold: Double
        public var midThreshold: Double
        public var highThreshold: Double
        /// Per band, low first: 1 … 20.
        public var lowRatio: Double
        public var midRatio: Double
        public var highRatio: Double
        /// Seconds, 0.1 ms … 200 ms, all bands.
        public var attack: Double
        /// Seconds, 10 ms … 2 s, all bands.
        public var release: Double
        /// dB, 0 … 24, after the sum.
        public var makeup: Double

        public init(lowCrossover: Double = 200, highCrossover: Double = 2_500,
                    lowThreshold: Double = -18, midThreshold: Double = -18, highThreshold: Double = -18,
                    lowRatio: Double = 3, midRatio: Double = 2, highRatio: Double = 2,
                    attack: Double = 0.01, release: Double = 0.15, makeup: Double = 0) {
            self.lowCrossover = lowCrossover
            self.highCrossover = highCrossover
            self.lowThreshold = lowThreshold
            self.midThreshold = midThreshold
            self.highThreshold = highThreshold
            self.lowRatio = lowRatio
            self.midRatio = midRatio
            self.highRatio = highRatio
            self.attack = attack
            self.release = release
            self.makeup = makeup
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(lowCrossover: clamp(lowCrossover, 50...1_000, base.lowCrossover),
                            highCrossover: clamp(highCrossover, 1_000...12_000, base.highCrossover),
                            lowThreshold: clamp(lowThreshold, -60...0, base.lowThreshold),
                            midThreshold: clamp(midThreshold, -60...0, base.midThreshold),
                            highThreshold: clamp(highThreshold, -60...0, base.highThreshold),
                            lowRatio: clamp(lowRatio, 1...20, base.lowRatio),
                            midRatio: clamp(midRatio, 1...20, base.midRatio),
                            highRatio: clamp(highRatio, 1...20, base.highRatio),
                            attack: clamp(attack, 0.0001...0.2, base.attack),
                            release: clamp(release, 0.01...2, base.release),
                            makeup: clamp(makeup, 0...24, base.makeup))
        }
    }

    public var settings: Settings {
        didSet {
            settings = settings.clamped
            update()
        }
    }

    public let sampleRate: Double
    /// The deepest of the three bands' gain reductions right now, in dB (0 or less), for a meter.
    public private(set) var reduction: Float = 0
    /// Frames the bands are split and compressed in at a time.
    static let chunk = 64
    private var low: Compressor
    private var mid: Compressor
    private var high: Compressor
    /// Six chunks: low, mid, high, each left then right.
    private let buffers: UnsafeMutablePointer<Float>
    /// Per side (left 0…3, right 4…7): the first split's shared stage, its low and its high
    /// second stage, the second split's shared stage, its low and its high second stage, and the
    /// low band's allpass — seven stages, the eighth unused.
    private var stages: [ZDFStage]
    private var g1Now: Float, g2Now: Float, g1Target: Float, g2Target: Float
    private var makeupNow: Float, makeupTarget: Float
    private let glide: Float

    public init(sampleRate: Double, settings: Settings = Settings()) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.sampleRate = rate
        glide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * rate)))
        low = Compressor(sampleRate: rate)
        mid = Compressor(sampleRate: rate)
        high = Compressor(sampleRate: rate)
        buffers = .allocate(capacity: 6 * Self.chunk)
        buffers.initialize(repeating: 0, count: 6 * Self.chunk)
        stages = [ZDFStage](repeating: ZDFStage(), count: 16)
        let start = settings.clamped
        g1Target = ZDFStage.g(start.lowCrossover, sampleRate: rate)
        g2Target = ZDFStage.g(start.highCrossover, sampleRate: rate)
        g1Now = g1Target
        g2Now = g2Target
        makeupTarget = Float(Foundation.pow(10, start.makeup / 20))
        makeupNow = makeupTarget
        self.settings = start
        update()
        makeupNow = makeupTarget
    }

    deinit {
        buffers.deallocate()
    }

    private static func band(_ threshold: Double, _ ratio: Double, _ s: Settings) -> Compressor.Settings {
        var band = Compressor.Settings()
        band.threshold = threshold
        band.ratio = ratio
        band.attack = s.attack
        band.release = s.release
        band.knee = 6
        band.makeup = 0
        band.mix = 1
        return band
    }

    private func update() {
        let s = settings
        let lowBand = Self.band(s.lowThreshold, s.lowRatio, s)
        let midBand = Self.band(s.midThreshold, s.midRatio, s)
        let highBand = Self.band(s.highThreshold, s.highRatio, s)
        if low.settings != lowBand { low.settings = lowBand }
        if mid.settings != midBand { mid.settings = midBand }
        if high.settings != highBand { high.settings = highBand }
        g1Target = ZDFStage.g(s.lowCrossover, sampleRate: sampleRate)
        g2Target = ZDFStage.g(s.highCrossover, sampleRate: sampleRate)
        makeupTarget = Float(Foundation.pow(10, s.makeup / 20))
    }

    /// Empties the filters and the bands' envelopes.
    public func reset() {
        for index in stages.indices { stages[index].reset() }
        low.reset()
        mid.reset()
        high.reset()
        reduction = 0
        g1Now = g1Target
        g2Now = g2Target
        makeupNow = makeupTarget
    }

    /// One side's three bands of one sample: stages `base ..< base + 7`.
    @inline(__always)
    private static func split(_ input: Float, _ stage: UnsafeMutableBufferPointer<ZDFStage>, base: Int,
                              g1: Float, g2: Float) -> (Float, Float, Float) {
        let k = ZDFStage.butterworth
        let first = stage[base].process(input, g: g1, k: k)
        let lowBand = stage[base + 1].process(first.low, g: g1, k: k).low
        let rest = stage[base + 2].process(first.high, g: g1, k: k).high
        let second = stage[base + 3].process(rest, g: g2, k: k)
        let midBand = stage[base + 4].process(second.low, g: g2, k: k).low
        let highBand = stage[base + 5].process(second.high, g: g2, k: k).high
        // The second split's allpass on the low band: LR4's low + high is (s² − √2·s + 1)/(s² + √2·s + 1).
        let lowAligned = lowBand - 2 * k * stage[base + 6].process(lowBand, g: g2, k: k).band
        return (lowAligned, midBand, highBand)
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let n = Self.chunk
        let lowLeft = buffers, lowRight = buffers + n, midLeft = buffers + 2 * n
        let midRight = buffers + 3 * n, highLeft = buffers + 4 * n, highRight = buffers + 5 * n
        var done = 0
        var deepest: Float = 0
        while done < frames {
            let count = Swift.min(n, frames - done)
            var g1 = g1Now, g2 = g2Now
            var bad = false
            stages.withUnsafeMutableBufferPointer { stage in
                for i in 0..<count {
                    g1 = Compressor.glided(g1, toward: g1Target, by: glide)
                    g2 = Compressor.glided(g2, toward: g2Target, by: glide)
                    let inLeft = left[done + i], inRight = right[done + i]
                    guard inLeft.isFinite, inRight.isFinite else {
                        bad = true
                        (lowLeft[i], midLeft[i], highLeft[i]) = (0, 0, 0)
                        (lowRight[i], midRight[i], highRight[i]) = (0, 0, 0)
                        continue
                    }
                    (lowLeft[i], midLeft[i], highLeft[i]) = Self.split(inLeft, stage, base: 0, g1: g1, g2: g2)
                    (lowRight[i], midRight[i], highRight[i]) = Self.split(inRight, stage, base: 8, g1: g1, g2: g2)
                }
            }
            g1Now = g1
            g2Now = g2
            low.process(left: lowLeft, right: lowRight, frames: count)
            mid.process(left: midLeft, right: midRight, frames: count)
            high.process(left: highLeft, right: highRight, frames: count)
            deepest = Swift.min(deepest, Swift.min(low.reduction, Swift.min(mid.reduction, high.reduction)))
            var gain = makeupNow
            for i in 0..<count {
                gain = Compressor.glided(gain, toward: makeupTarget, by: glide)
                let outLeft = (lowLeft[i] + midLeft[i] + highLeft[i]) * gain
                let outRight = (lowRight[i] + midRight[i] + highRight[i]) * gain
                if outLeft.isFinite, outRight.isFinite {
                    left[done + i] = outLeft
                    right[done + i] = outRight
                } else {
                    bad = true
                    left[done + i] = 0
                    right[done + i] = 0
                }
            }
            makeupNow = gain
            if bad {
                for index in stages.indices { stages[index].reset() }
                low.reset()
                mid.reset()
                high.reset()
            }
            done += count
        }
        reduction = deepest
    }
}
