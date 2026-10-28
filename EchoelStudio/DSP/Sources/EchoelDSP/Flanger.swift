import Foundation

/// A stereo flanger: each side reads a very short delay line (3 ms, swaying ±2 ms on a triangle,
/// the right side against the left) and feeds part of it back, so the comb of notches sweeps —
/// the jet sound. Ported from the earlier app's `EchoelFlanger` (EchoelModFX) for Echoel Studio
/// 1.0, as a value of settings and a render-thread processor like `Chorus`.
///
/// The mix glides in ~10 ms instead of stepping. One bad sample empties the lines rather than
/// ringing in them. Owned by the render thread: set `settings` and call `process` from that
/// thread. The lines are allocated in `init`; nothing allocates after that.
public final class Flanger: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// The sway's speed in Hz, 0.05 … 8.
        public var rate: Double
        /// How far it sways, 0 … 1 (1: ±2 ms around the 3 ms centre).
        public var depth: Double
        /// How much of the delayed sound goes round again, −0.95 … 0.95; negative flips its sign.
        public var feedback: Double
        /// Dry 0 … wet 1.
        public var mix: Double

        public init(rate: Double = 0.25, depth: Double = 0.7, feedback: Double = 0.5, mix: Double = 0.5) {
            self.rate = rate
            self.depth = depth
            self.feedback = feedback
            self.mix = mix
        }

        /// Every value inside its range; a non-finite value takes the default (for feedback that
        /// matters: clamping NaN to the lower bound would be the loudest setting, −0.95).
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(rate: clamp(rate, 0.05...8, base.rate), depth: clamp(depth, 0...1, base.depth),
                            feedback: clamp(feedback, -0.95...0.95, base.feedback), mix: clamp(mix, 0...1, base.mix))
        }
    }

    /// The centre of the sway and its widest swing, in seconds.
    public static let centreSeconds = 0.003
    public static let spreadSeconds = 0.002

    public var settings: Settings {
        didSet { settings = settings.clamped }
    }

    public let sampleRate: Double
    private let capacity: Int
    private let lineLeft: UnsafeMutablePointer<Float>
    private let lineRight: UnsafeMutablePointer<Float>
    private var write = 0
    /// The triangle's phase, 0 ..< 1.
    private var phase: Double = 0
    private var wetNow: Float
    private let mixGlide: Float

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        capacity = Int(self.sampleRate * (Self.centreSeconds + Self.spreadSeconds)) + 4
        lineLeft = .allocate(capacity: capacity)
        lineLeft.initialize(repeating: 0, count: capacity)
        lineRight = .allocate(capacity: capacity)
        lineRight.initialize(repeating: 0, count: capacity)
        mixGlide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        self.settings = settings.clamped
        wetNow = Float(self.settings.mix)
    }

    deinit {
        lineLeft.deallocate()
        lineRight.deallocate()
    }

    /// Empties the lines and starts the sway over.
    public func reset() {
        lineLeft.update(repeating: 0, count: capacity)
        lineRight.update(repeating: 0, count: capacity)
        phase = 0
        wetNow = Float(settings.mix)
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let step = settings.rate / sampleRate
        let centre = Self.centreSeconds * sampleRate
        let swing = settings.depth * Self.spreadSeconds * sampleRate
        let feedback = Float(settings.feedback)
        let wetTarget = Float(settings.mix)
        var wet = wetNow
        for i in 0..<frames {
            wet = Compressor.glided(wet, toward: wetTarget, by: mixGlide)
            // Triangle −1 … 1.
            let sway = (phase < 0.5 ? 4 * phase - 1 : 3 - 4 * phase) * swing
            phase += step
            if phase >= 1 { phase -= 1 }
            let inLeft = left[i], inRight = right[i]
            let delayedLeft = read(lineLeft, distance: centre + sway)
            let delayedRight = read(lineRight, distance: centre - sway)
            lineLeft[write] = inLeft + delayedLeft * feedback
            lineRight[write] = inRight + delayedRight * feedback
            write = write + 1 < capacity ? write + 1 : 0
            let outLeft = inLeft * (1 - wet) + delayedLeft * wet
            let outRight = inRight * (1 - wet) + delayedRight * wet
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

    /// The line `distance` samples behind the next write, linearly interpolated.
    @inline(__always)
    private func read(_ line: UnsafeMutablePointer<Float>, distance: Double) -> Float {
        let back = Swift.min(Swift.max(distance, 1), Double(capacity - 2))
        var position = Double(write) - back
        if position < 0 { position += Double(capacity) }
        let index = Int(position)
        let fraction = Float(position - Double(index))
        let next = index + 1 < capacity ? index + 1 : 0
        return line[index] + (line[next] - line[index]) * fraction
    }
}
