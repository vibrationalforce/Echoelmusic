import Foundation

/// A stereo brick-wall limiter: for finite input no output sample passes the ceiling, and the
/// gain that keeps it there moves continuously instead of flat-topping the wave. Ported from the
/// earlier app's `EchoelLimiter` (EchoelDynamics) for Echoel Studio 1.0, as a value of settings
/// and a render-thread processor like `Compressor`.
///
/// Three stages, each for a measured reason in the earlier app (#194, #199, #231 there):
/// - a PEAK ENVELOPE that follows a rise at once and decays on its own constant (40 ms), not on
///   the release — reading the raw sample springs back at every zero crossing and brings the
///   hard-clip grit back; decaying on the release made a nominal release take twice as long;
/// - a gain that falls in ~0.5 ms and recovers on the release, both one-poles, so the gain is
///   a continuous signal;
/// - a guard that takes the envelope's target where the smoothed gain has not arrived yet. It
///   divides by the ENVELOPE, never by the sample, so it scales the wave rather than clipping it,
///   and it is what makes the ceiling absolute (to one rounding step).
///
/// A sample-peak limiter, not a true-peak one. Non-finite input comes out as silence and leaves
/// the limiter's state untouched. Owned by the render thread: set `settings` and call `process`
/// from that thread. Nothing allocates.
public final class Limiter: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// Gain into the limiter in dB, 0 … 24: how hard it is pushed.
        public var gain: Double
        /// The ceiling in dBFS, −24 … 0.
        public var ceiling: Double
        /// How long the gain takes to recover, in seconds, 0.005 … 1.
        public var release: Double

        public init(gain: Double = 0, ceiling: Double = -0.3, release: Double = 0.06) {
            self.gain = gain
            self.ceiling = ceiling
            self.release = release
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(gain: clamp(gain, 0...24, base.gain), ceiling: clamp(ceiling, -24...0, base.ceiling),
                            release: clamp(release, 0.005...1, base.release))
        }
    }

    /// How fast the gain may fall, in seconds.
    public static let attackSeconds = 0.0005
    /// The detector's decay, in seconds — deliberately not the release (see the type's doc).
    public static let detectorSeconds = 0.04

    public var settings: Settings {
        didSet {
            settings = settings.clamped
            derive()
        }
    }

    public let sampleRate: Double
    private let attackCoefficient: Float
    private let detectorDecay: Float
    private var releaseCoefficient: Float = 0
    private var ceilingLinear: Float = 1
    private var inputTarget: Float = 1
    private var inputNow: Float = 1
    private let inputGlide: Float
    private var envelope: Float = 0
    private var gainNow: Float = 1

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        attackCoefficient = Float(1 - Foundation.exp(-1 / (Self.attackSeconds * self.sampleRate)))
        detectorDecay = Float(Foundation.exp(-1 / (Self.detectorSeconds * self.sampleRate)))
        inputGlide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        self.settings = settings.clamped
        derive()
        inputNow = inputTarget
    }

    /// The gain reduction in dB (0 or less), for a meter.
    public var reduction: Float { 20 * log10(Swift.max(gainNow, 1e-7)) }

    /// Forgets the envelope and the reduction.
    public func reset() {
        envelope = 0
        gainNow = 1
        inputNow = inputTarget
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let ceiling = ceilingLinear
        var input = inputNow
        var env = envelope
        var gain = gainNow
        for i in 0..<frames {
            let rawLeft = left[i], rawRight = right[i]
            guard rawLeft.isFinite, rawRight.isFinite else {
                left[i] = 0
                right[i] = 0
                continue
            }
            input = Compressor.glided(input, toward: inputTarget, by: inputGlide)
            let inLeft = rawLeft * input, inRight = rawRight * input
            let peak = Swift.max(Swift.abs(inLeft), Swift.abs(inRight))
            // Flush the decaying envelope before the max, never after: `env >= peak` is what the
            // guard below rests on.
            var decayed = env * detectorDecay
            if decayed < 1e-20 { decayed = 0 }
            env = peak > decayed ? peak : decayed
            let target = env > ceiling ? ceiling / env : 1
            let coefficient = target < gain ? attackCoefficient : releaseCoefficient
            var next = gain + (target - gain) * coefficient
            if peak * next > ceiling { next = target }
            gain = next
            left[i] = inLeft * gain
            right[i] = inRight * gain
        }
        inputNow = input
        envelope = env
        gainNow = gain
    }

    private func derive() {
        ceilingLinear = Float(Foundation.pow(10, settings.ceiling / 20))
        inputTarget = Float(Foundation.pow(10, settings.gain / 20))
        releaseCoefficient = Float(1 - Foundation.exp(-1 / (settings.release * sampleRate)))
    }
}
