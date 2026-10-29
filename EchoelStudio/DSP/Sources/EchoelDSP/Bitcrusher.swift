import Foundation

/// A stereo bitcrusher: each sample is held for `downsample` samples (the sample rate falls by
/// that factor) and rounded to `2^bits − 1` steps — the grain of early samplers and game
/// consoles — then blended with the dry sound. Ported from the earlier app's `EchoelBitcrush`
/// (EchoelLoFiFX) for Echoel Studio 1.0, as a value of settings and a render-thread processor
/// like `Chorus`.
///
/// The mix glides in ~10 ms instead of stepping. A bad sample comes out as silence and is never
/// held. Owned by the render thread: set `settings` and call `process` from that thread. Nothing
/// allocates.
public final class Bitcrusher: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// The bit depth, 1 … 16 (16: nearly transparent).
        public var bits: Double
        /// How many samples each held sample lasts, 1 … 64 (1: the full rate).
        public var downsample: Double
        /// Dry 0 … crushed 1.
        public var mix: Double

        public init(bits: Double = 8, downsample: Double = 4, mix: Double = 1) {
            self.bits = bits
            self.downsample = downsample
            self.mix = mix
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(bits: clamp(bits, 1...16, base.bits), downsample: clamp(downsample, 1...64, base.downsample),
                            mix: clamp(mix, 0...1, base.mix))
        }

        /// The number of rounding steps either side of zero.
        public var levels: Float { Float(Foundation.pow(2, bits) - 1) }
        /// The hold length in whole samples.
        public var hold: Int { Int(downsample.rounded()) }
    }

    public var settings: Settings {
        didSet { settings = settings.clamped }
    }

    public let sampleRate: Double
    private var heldLeft: Float = 0
    private var heldRight: Float = 0
    private var countdown = 0
    private var wetNow: Float
    private let glide: Float

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        glide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        let start = settings.clamped
        self.settings = start
        wetNow = Float(start.mix)
    }

    /// Forgets the held sample.
    public func reset() {
        heldLeft = 0
        heldRight = 0
        countdown = 0
        wetNow = Float(settings.mix)
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let levels = settings.levels
        let hold = settings.hold
        let wetTarget = Float(settings.mix)
        var wet = wetNow
        for i in 0..<frames {
            wet = Compressor.glided(wet, toward: wetTarget, by: glide)
            let inLeft = left[i], inRight = right[i]
            guard inLeft.isFinite, inRight.isFinite else {
                reset()
                left[i] = 0
                right[i] = 0
                wet = wetNow
                continue
            }
            if countdown <= 0 {
                heldLeft = (inLeft * levels).rounded() / levels
                heldRight = (inRight * levels).rounded() / levels
                countdown = hold
            }
            countdown -= 1
            left[i] = inLeft * (1 - wet) + heldLeft * wet
            right[i] = inRight * (1 - wet) + heldRight * wet
        }
        wetNow = wet
    }
}
