import Foundation

/// A stereo phaser: six first-order allpass stages whose break frequency a sine sweeps between
/// 300 Hz and 2.2 kHz, the right side against the left, with feedback around the chain — the
/// moving notches of a classic phaser. Ported from the earlier app's `EchoelPhaser`
/// (EchoelModFX) for Echoel Studio 1.0, as a value of settings and a render-thread processor
/// like `Chorus`.
///
/// The mix glides in ~10 ms instead of stepping. One bad sample empties the stages rather than
/// ringing in them. Owned by the render thread: set `settings` and call `process` from that
/// thread. The stages are allocated in `init`; nothing allocates after that.
public final class Phaser: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// The sweep's speed in Hz, 0.05 … 8.
        public var rate: Double
        /// How much of the range it sweeps, 0 … 1 (0: parked in the middle).
        public var depth: Double
        /// How much of the output goes round again, 0 … 0.95.
        public var feedback: Double
        /// Dry 0 … wet 1.
        public var mix: Double

        public init(rate: Double = 0.4, depth: Double = 0.7, feedback: Double = 0.3, mix: Double = 0.5) {
            self.rate = rate
            self.depth = depth
            self.feedback = feedback
            self.mix = mix
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(rate: clamp(rate, 0.05...8, base.rate), depth: clamp(depth, 0...1, base.depth),
                            feedback: clamp(feedback, 0...0.95, base.feedback), mix: clamp(mix, 0...1, base.mix))
        }
    }

    public static let stages = 6
    /// The sweep's range in Hz; the top never passes 0.45 of the sample rate.
    public static let lowestHz = 300.0
    public static let highestHz = 2_200.0

    public var settings: Settings {
        didSet { settings = settings.clamped }
    }

    public let sampleRate: Double
    private let stateLeft: UnsafeMutablePointer<Float>
    private let stateRight: UnsafeMutablePointer<Float>
    private var lastLeft: Float = 0
    private var lastRight: Float = 0
    /// The sine's phase, 0 ..< 1.
    private var phase: Double = 0
    private var wetNow: Float
    private let mixGlide: Float

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        stateLeft = .allocate(capacity: Self.stages)
        stateLeft.initialize(repeating: 0, count: Self.stages)
        stateRight = .allocate(capacity: Self.stages)
        stateRight.initialize(repeating: 0, count: Self.stages)
        mixGlide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        self.settings = settings.clamped
        wetNow = Float(self.settings.mix)
    }

    deinit {
        stateLeft.deallocate()
        stateRight.deallocate()
    }

    /// Empties the stages and starts the sweep over.
    public func reset() {
        stateLeft.update(repeating: 0, count: Self.stages)
        stateRight.update(repeating: 0, count: Self.stages)
        lastLeft = 0
        lastRight = 0
        phase = 0
        wetNow = Float(settings.mix)
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let step = settings.rate / sampleRate
        let depth = settings.depth
        let feedback = Float(settings.feedback)
        let low = Self.lowestHz
        let high = Swift.min(sampleRate * 0.45, Self.highestHz)
        let wetTarget = Float(settings.mix)
        var wet = wetNow
        for i in 0..<frames {
            wet = Compressor.glided(wet, toward: wetTarget, by: mixGlide)
            let sway = Foundation.sin(2 * Double.pi * phase) * 0.5 + 0.5
            phase += step
            if phase >= 1 { phase -= 1 }
            let coefficientLeft = coefficient(at: sway, depth: depth, low: low, high: high)
            let coefficientRight = coefficient(at: 1 - sway, depth: depth, low: low, high: high)
            let inLeft = left[i], inRight = right[i]
            let wetLeft = chain(inLeft, coefficientLeft, feedback, stateLeft, &lastLeft)
            let wetRight = chain(inRight, coefficientRight, feedback, stateRight, &lastRight)
            let outLeft = inLeft * (1 - wet) + wetLeft * wet
            let outRight = inRight * (1 - wet) + wetRight * wet
            guard outLeft.isFinite, outRight.isFinite else {
                reset()
                left[i] = 0
                right[i] = 0
                wet = wetNow
                continue
            }
            left[i] = outLeft
            right[i] = outRight
        }
        wetNow = wet
    }

    /// The allpass coefficient for a sweep position 0 … 1.
    @inline(__always)
    private func coefficient(at position: Double, depth: Double, low: Double, high: Double) -> Float {
        let centre = low + (high - low) * (position * depth + (1 - depth) * 0.5)
        let t = Foundation.tan(Double.pi * centre / sampleRate)
        return Float((t - 1) / (t + 1))
    }

    @inline(__always)
    private func chain(_ input: Float, _ a: Float, _ feedback: Float, _ state: UnsafeMutablePointer<Float>,
                       _ last: inout Float) -> Float {
        var signal = input + last * feedback
        for stage in 0..<Self.stages {
            let output = a * signal + state[stage]
            state[stage] = signal - a * output
            signal = output
        }
        last = signal
        return signal
    }
}
