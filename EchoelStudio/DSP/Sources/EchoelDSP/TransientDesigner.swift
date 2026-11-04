import Foundation

/// A transient designer: makes the start of every note harder or softer and its body and tail
/// longer or shorter, independently of the level the note is played at. Written new for Echoel
/// Studio (ECHOELTOOLS catalog B10), as a value of settings and a render-thread processor like
/// `Chorus`.
///
/// Two pairs of envelope followers on the louder side (one gain for both, so the image never
/// leans). The attack pair: a fast follower (0.5 ms up) against a slow one (25 ms up), both falling
/// in 60 ms — while a note starts the fast one runs ahead, and how far, in dB, is the transient.
/// The sustain pair: a follower that falls slowly (400 ms) against one that falls fast (40 ms),
/// both rising in 1 ms — while a note dies the slow one stays above, and that is the tail. Each
/// measure is limited to 12 dB; Attack and Sustain give the gain in dB at that full measure, so
/// +6 dB attack lifts a hard start by up to 6 dB and leaves a held tone, where both pairs agree,
/// untouched. The gain glides in about 1 ms and the output in ~10 ms. Level-independent because
/// the followers are compared as a ratio. One bad sample empties the followers and comes out as
/// silence. Owned by the render thread: set `settings` and call `process` from that thread.
/// Nothing allocates.
public final class TransientDesigner: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// dB at a full transient, −24 … 24.
        public var attack: Double
        /// dB at a full tail, −24 … 24.
        public var sustain: Double
        /// dB, −24 … 12.
        public var output: Double

        public init(attack: Double = 0, sustain: Double = 0, output: Double = 0) {
            self.attack = attack
            self.sustain = sustain
            self.output = output
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(attack: clamp(attack, -24...24, base.attack), sustain: clamp(sustain, -24...24, base.sustain),
                            output: clamp(output, -24...12, base.output))
        }
    }

    /// The largest transient or tail a follower pair measures, in dB.
    static let fullMeasure: Float = 12

    public var settings: Settings {
        didSet { settings = settings.clamped }
    }

    public let sampleRate: Double
    private let fastUp: Float, slowUp: Float, attackDown: Float
    private let sustainUp: Float, slowDown: Float, fastDown: Float
    private let gainGlide: Float, outputGlide: Float
    private var attackFast: Float = 0, attackSlow: Float = 0
    private var tailSlow: Float = 0, tailFast: Float = 0
    /// The shaping gain in dB as it plays now.
    private var shapeNow: Float = 0
    private var outputNow: Float

    private static func coefficient(_ seconds: Double, _ rate: Double) -> Float {
        Float(1 - Foundation.exp(-1 / (seconds * rate)))
    }

    public init(sampleRate: Double, settings: Settings = Settings()) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.sampleRate = rate
        fastUp = Self.coefficient(0.0005, rate)
        slowUp = Self.coefficient(0.025, rate)
        attackDown = Self.coefficient(0.06, rate)
        sustainUp = Self.coefficient(0.001, rate)
        slowDown = Self.coefficient(0.4, rate)
        fastDown = Self.coefficient(0.04, rate)
        gainGlide = Self.coefficient(0.001, rate)
        outputGlide = Self.coefficient(Compressor.gainGlideSeconds, rate)
        let start = settings.clamped
        self.settings = start
        outputNow = Float(Foundation.pow(10, start.output / 20))
    }

    /// Empties the followers.
    public func reset() {
        attackFast = 0
        attackSlow = 0
        tailSlow = 0
        tailFast = 0
        shapeNow = 0
        outputNow = Float(Foundation.pow(10, settings.output / 20))
    }

    @inline(__always)
    private static func follow(_ value: Float, _ input: Float, up: Float, down: Float) -> Float {
        value + (input - value) * (input > value ? up : down)
    }

    /// How far `above` stands over `below`, in dB, from 0 to the full measure.
    @inline(__always)
    private static func measure(_ above: Float, over below: Float) -> Float {
        guard above > 1e-6 else { return 0 }
        let ratio = above / Swift.max(below, 1e-6)
        guard ratio > 1 else { return 0 }
        return Swift.min(20 * log10f(ratio), fullMeasure)
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let attackPerDB = Float(settings.attack) / Self.fullMeasure
        let sustainPerDB = Float(settings.sustain) / Self.fullMeasure
        let outputTarget = Float(Foundation.pow(10, settings.output / 20))
        var shape = shapeNow, output = outputNow
        for i in 0..<frames {
            let inLeft = left[i], inRight = right[i]
            guard inLeft.isFinite, inRight.isFinite else {
                reset()
                shape = 0
                output = outputNow
                left[i] = 0
                right[i] = 0
                continue
            }
            let level = Swift.max(Swift.abs(inLeft), Swift.abs(inRight))
            attackFast = Self.follow(attackFast, level, up: fastUp, down: attackDown)
            attackSlow = Self.follow(attackSlow, level, up: slowUp, down: attackDown)
            tailSlow = Self.follow(tailSlow, level, up: sustainUp, down: slowDown)
            tailFast = Self.follow(tailFast, level, up: sustainUp, down: fastDown)
            let wanted = attackPerDB * Self.measure(attackFast, over: attackSlow)
                + sustainPerDB * Self.measure(tailSlow, over: tailFast)
            shape = Compressor.glided(shape, toward: wanted, by: gainGlide)
            output = Compressor.glided(output, toward: outputTarget, by: outputGlide)
            let gain = (shape == 0 ? 1 : Foundation.powf(10, shape / 20)) * output
            left[i] = inLeft * gain
            right[i] = inRight * gain
        }
        shapeNow = Swift.abs(shape) < 1e-6 ? 0 : shape
        outputNow = Swift.abs(output - outputTarget) < 1e-7 ? outputTarget : output
    }
}
