import Foundation

/// A stereo chorus: each side reads a short delay line whose length a sine sways around 12 ms,
/// the right side against the left (the same sine inverted), and the swaying copies blend with
/// the dry sound — thickening, ensemble, width. Ported from the earlier app's `EchoelChorus`
/// (EchoelModFX) for Echoel Studio 1.0, as a value of settings and a render-thread processor
/// like `StereoDelay`.
///
/// The mix glides in ~10 ms instead of stepping. One bad sample empties the lines rather than
/// ringing in them. Owned by the render thread: set `settings` and call `process` from that
/// thread. The lines are allocated in `init`; nothing allocates after that.
public final class Chorus: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// The sway's speed in Hz, 0.05 … 8.
        public var rate: Double
        /// How far it sways, 0 … 1 (1: ±7 ms around the 12 ms centre).
        public var depth: Double
        /// Dry 0 … wet 1.
        public var mix: Double

        public init(rate: Double = 0.6, depth: Double = 0.5, mix: Double = 0.5) {
            self.rate = rate
            self.depth = depth
            self.mix = mix
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(rate: clamp(rate, 0.05...8, base.rate), depth: clamp(depth, 0...1, base.depth),
                            mix: clamp(mix, 0...1, base.mix))
        }
    }

    /// The centre of the sway and its widest swing, in seconds.
    public static let centreSeconds = 0.012
    public static let spreadSeconds = 0.007

    public var settings: Settings {
        didSet { settings = settings.clamped }
    }

    public let sampleRate: Double
    private let capacity: Int
    private let lineLeft: UnsafeMutablePointer<Float>
    private let lineRight: UnsafeMutablePointer<Float>
    private var write = 0
    /// The sine's phase, 0 ..< 1.
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
        let wetTarget = Float(settings.mix)
        var wet = wetNow
        for i in 0..<frames {
            wet = Compressor.glided(wet, toward: wetTarget, by: mixGlide)
            let sway = Foundation.sin(2 * Double.pi * phase) * swing
            phase += step
            if phase >= 1 { phase -= 1 }
            let inLeft = left[i], inRight = right[i]
            lineLeft[write] = inLeft
            lineRight[write] = inRight
            let delayedLeft = read(lineLeft, distance: centre + sway)
            let delayedRight = read(lineRight, distance: centre - sway)
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

    /// The line `distance` samples behind the newest sample, linearly interpolated.
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
