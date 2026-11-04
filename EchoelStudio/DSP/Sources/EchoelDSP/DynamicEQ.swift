import Foundation

/// A dynamic EQ of two bands: each band is a bell that stays flat while its own frequencies are
/// quiet and cuts (or lifts) them as they grow louder than its threshold — a harsh 3 kHz or a
/// boomy 250 Hz tamed only where it happens, the rest of the sound left as it is. Written new for
/// Echoel Studio (ECHOELTOOLS catalog B10), as a value of settings and a render-thread processor
/// like `Chorus`.
///
/// Each band is one `ZDFStage` per side: its band-pass is both what the band listens to (the
/// louder side's peak, followed in dB with the attack and release) and what it changes (the bell
/// `x + (A − 1)·k·band`, whose peak gain is exactly `A`). The band reaches its full Range 12 dB
/// above its threshold and moves in proportion below that, so Range is the most it ever
/// changes. The bands run side by side on the same input. Frequency and width glide per sample,
/// and the gain follows the envelope, which moves no faster than the attack. One bad sample
/// empties the bands and comes out as silence. Owned by the render thread: set `settings` and
/// call `process` from that thread. Nothing allocates.
public final class DynamicEQ: @unchecked Sendable {
    public struct Band: Equatable, Codable, Sendable {
        /// Hz, 20 … 20000.
        public var frequency: Double
        /// 0.3 … 8.
        public var q: Double
        /// dBFS of the band's own level where it starts to act, −60 … 0.
        public var threshold: Double
        /// dB at 12 dB over the threshold: −18 (cut) … 18 (lift).
        public var range: Double

        public init(frequency: Double, q: Double = 1, threshold: Double = -24, range: Double = -6) {
            self.frequency = frequency
            self.q = q
            self.threshold = threshold
            self.range = range
        }

        func clamped(_ base: Band) -> Band {
            func clamp(_ value: Double, _ limits: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, limits.lowerBound), limits.upperBound) : fallback
            }
            return Band(frequency: clamp(frequency, 20...20_000, base.frequency), q: clamp(q, 0.3...8, base.q),
                        threshold: clamp(threshold, -60...0, base.threshold), range: clamp(range, -18...18, base.range))
        }
    }

    public struct Settings: Equatable, Codable, Sendable {
        public var low: Band
        public var high: Band
        /// Seconds, 0.1 ms … 200 ms.
        public var attack: Double
        /// Seconds, 10 ms … 2 s.
        public var release: Double

        public init(low: Band = Band(frequency: 250), high: Band = Band(frequency: 3_000),
                    attack: Double = 0.005, release: Double = 0.15) {
            self.low = low
            self.high = high
            self.attack = attack
            self.release = release
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ limits: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, limits.lowerBound), limits.upperBound) : fallback
            }
            return Settings(low: low.clamped(base.low), high: high.clamped(base.high),
                            attack: clamp(attack, 0.0001...0.2, base.attack), release: clamp(release, 0.01...2, base.release))
        }
    }

    /// How far over the threshold a band reaches its full range, in dB.
    static let fullMeasure: Float = 12

    public var settings: Settings {
        didSet {
            settings = settings.clamped
            update()
        }
    }

    public let sampleRate: Double
    /// The two bands' gain right now in dB, low first, for a meter.
    public private(set) var gains = SIMD2<Float>(repeating: 0)
    private var stages = [ZDFStage](repeating: ZDFStage(), count: 4)
    private var gTarget = SIMD2<Float>(repeating: 0), gNow = SIMD2<Float>(repeating: 0)
    private var kTarget = SIMD2<Float>(repeating: 0), kNow = SIMD2<Float>(repeating: 0)
    private var thresholds = SIMD2<Float>(repeating: 0), ranges = SIMD2<Float>(repeating: 0)
    /// The bands' followed peaks, linear.
    private var levels = SIMD2<Float>(repeating: 0)
    private var attackCoefficient: Float = 0, releaseCoefficient: Float = 0
    private let glide: Float

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        glide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        self.settings = settings.clamped
        update()
        gNow = gTarget
        kNow = kTarget
    }

    private func update() {
        let s = settings
        gTarget = SIMD2(ZDFStage.g(s.low.frequency, sampleRate: sampleRate), ZDFStage.g(s.high.frequency, sampleRate: sampleRate))
        kTarget = SIMD2(Float(1 / s.low.q), Float(1 / s.high.q))
        thresholds = SIMD2(Float(s.low.threshold), Float(s.high.threshold))
        ranges = SIMD2(Float(s.low.range), Float(s.high.range))
        attackCoefficient = Float(1 - Foundation.exp(-1 / (s.attack * sampleRate)))
        releaseCoefficient = Float(1 - Foundation.exp(-1 / (s.release * sampleRate)))
    }

    /// Empties the bands and their followers.
    public func reset() {
        for index in stages.indices { stages[index].reset() }
        gNow = gTarget
        kNow = kTarget
        levels = .zero
        gains = .zero
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        var g = gNow, k = kNow, level = levels
        var gain = gains
        let full = Self.fullMeasure
        stages.withUnsafeMutableBufferPointer { stage in
            for i in 0..<frames {
                for band in 0..<2 {
                    g[band] = Compressor.glided(g[band], toward: gTarget[band], by: glide)
                    k[band] = Compressor.glided(k[band], toward: kTarget[band], by: glide)
                }
                let inLeft = left[i], inRight = right[i]
                guard inLeft.isFinite, inRight.isFinite else {
                    for index in stage.indices { stage[index].reset() }
                    level = .zero
                    left[i] = 0
                    right[i] = 0
                    continue
                }
                var outLeft = inLeft, outRight = inRight
                for band in 0..<2 {
                    // `k · band` is the band-pass of unity peak: what the band hears and what it changes.
                    let bandLeft = k[band] * stage[band].process(inLeft, g: g[band], k: k[band]).band
                    let bandRight = k[band] * stage[2 + band].process(inRight, g: g[band], k: k[band]).band
                    let peak = Swift.max(Swift.abs(bandLeft), Swift.abs(bandRight))
                    level[band] += (peak - level[band]) * (peak > level[band] ? attackCoefficient : releaseCoefficient)
                    let heard = 20 * log10f(Swift.max(level[band], 1e-6))
                    let over = Swift.min(Swift.max(heard - thresholds[band], 0), full)
                    gain[band] = ranges[band] * over / full
                    let amount = gain[band] == 0 ? 0 : Foundation.powf(10, gain[band] / 20) - 1
                    outLeft += amount * bandLeft
                    outRight += amount * bandRight
                }
                guard outLeft.isFinite, outRight.isFinite else {
                    for index in stage.indices { stage[index].reset() }
                    level = .zero
                    left[i] = 0
                    right[i] = 0
                    continue
                }
                left[i] = outLeft
                right[i] = outRight
            }
        }
        gNow = g
        kNow = k
        levels = level
        gains = gain
    }
}
