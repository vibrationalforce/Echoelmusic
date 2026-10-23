import Foundation

/// A stereo delay: each side reads its own line `time` seconds back, the repeats darken through
/// a lowpass in the feedback path, and ping-pong sends the repeats from side to side.
///
/// A time change glides over ~50 ms, the way a tape delay bends, instead of jumping the read
/// head (which clicks). Feedback stops short of 1, so the line always dies away. One bad
/// sample resets the line rather than ringing in it for good.
///
/// Owned by the render thread: set `settings` and call `process` from that thread. The lines
/// are allocated in `init`; nothing allocates after that.
public final class StereoDelay: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// Seconds, 1 ms … `maximumSeconds`.
        public var time: Double
        /// 0 … 0.95.
        public var feedback: Double
        /// Dry 0 … wet 1.
        public var mix: Double
        /// Lowpass of the repeats in Hz, 500 … 20 000.
        public var damping: Double
        public var pingPong: Bool

        public init(time: Double = 0.375, feedback: Double = 0.35, mix: Double = 0.25, damping: Double = 6_000,
                    pingPong: Bool = false) {
            self.time = time
            self.feedback = feedback
            self.mix = mix
            self.damping = damping
            self.pingPong = pingPong
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(time: clamp(time, 0.001...StereoDelay.maximumSeconds, base.time),
                            feedback: clamp(feedback, 0...0.95, base.feedback),
                            mix: clamp(mix, 0...1, base.mix),
                            damping: clamp(damping, 500...20_000, base.damping),
                            pingPong: pingPong)
        }
    }

    public static let maximumSeconds = 2.0

    public var settings: Settings {
        didSet { settings = settings.clamped; update() }
    }

    public let sampleRate: Double
    private let capacity: Int
    private let lineLeft: UnsafeMutablePointer<Float>
    private let lineRight: UnsafeMutablePointer<Float>
    private var write = 0
    /// The read distance in samples, gliding towards `target`.
    private var distance: Double
    private var target: Double = 1
    private let glide: Double
    private var dampCoefficient: Float = 1
    private var dampLeft: Float = 0
    private var dampRight: Float = 0
    /// Until the first sample runs, a new time takes effect at once: a delay loaded with its
    /// settings must not sweep from the default into them.
    private var hasRun = false
    /// The mix as it sounds now: a change glides there in ~10 ms instead of stepping the output
    /// in one sample (audit 2026-10-23); before the first sample, at once, like the time.
    private var wetNow: Float = 0
    private let mixGlide: Float

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        capacity = Int(self.sampleRate * Self.maximumSeconds) + 4
        lineLeft = .allocate(capacity: capacity)
        lineLeft.initialize(repeating: 0, count: capacity)
        lineRight = .allocate(capacity: capacity)
        lineRight.initialize(repeating: 0, count: capacity)
        glide = 1 - Foundation.exp(-1 / (0.05 * self.sampleRate))
        mixGlide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        self.settings = settings.clamped
        distance = 1
        update()
        distance = target
    }

    deinit {
        lineLeft.deallocate()
        lineRight.deallocate()
    }

    /// Empties the lines: the repeats stop at once.
    public func reset() {
        lineLeft.update(repeating: 0, count: capacity)
        lineRight.update(repeating: 0, count: capacity)
        dampLeft = 0
        dampRight = 0
        distance = target
        hasRun = false
        wetNow = Float(settings.mix)
    }

    private func update() {
        target = Swift.min(Swift.max(settings.time * sampleRate, 1), Double(capacity - 3))
        dampCoefficient = Float(1 - Foundation.exp(-2 * Double.pi * settings.damping / sampleRate))
        if !hasRun {
            distance = target
            wetNow = Float(settings.mix)
        }
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let feedback = Float(settings.feedback)
        let wetTarget = Float(settings.mix)
        var wet = wetNow
        let pingPong = settings.pingPong
        if frames > 0 { hasRun = true }
        for i in 0..<frames {
            wet += (wetTarget - wet) * mixGlide
            let dry = 1 - wet
            distance += (target - distance) * glide
            var position = Double(write) - distance
            if position < 0 { position += Double(capacity) }
            let index = Int(position)
            let fraction = Float(position - Double(index))
            let next = index + 1 < capacity ? index + 1 : 0
            let delayedLeft = lineLeft[index] + (lineLeft[next] - lineLeft[index]) * fraction
            let delayedRight = lineRight[index] + (lineRight[next] - lineRight[index]) * fraction
            dampLeft += (delayedLeft - dampLeft) * dampCoefficient
            dampRight += (delayedRight - dampRight) * dampCoefficient
            let inLeft = left[i], inRight = right[i]
            let toLeft: Float, toRight: Float
            if pingPong {
                toLeft = (inLeft + inRight) * 0.5 + dampRight * feedback
                toRight = dampLeft * feedback
            } else {
                toLeft = inLeft + dampLeft * feedback
                toRight = inRight + dampRight * feedback
            }
            guard toLeft.isFinite, toRight.isFinite else {
                reset()
                left[i] = 0
                right[i] = 0
                continue
            }
            lineLeft[write] = toLeft
            lineRight[write] = toRight
            write = write + 1 < capacity ? write + 1 : 0
            left[i] = inLeft * dry + delayedLeft * wet
            right[i] = inRight * dry + delayedRight * wet
        }
        wetNow = Swift.abs(wetTarget - wet) < 1e-6 ? wetTarget : wet
        // Keep the decaying tail out of denormal range.
        if Swift.abs(dampLeft) < 1e-20 { dampLeft = 0 }
        if Swift.abs(dampRight) < 1e-20 { dampRight = 0 }
    }
}
