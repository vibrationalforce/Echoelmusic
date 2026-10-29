import Foundation

/// A stereo tremolo: a sine moves the level between full and `1 − depth`; with pan on, the right
/// side moves against the left, so the sound swings from side to side (auto-pan). Ported from the
/// earlier app's `EchoelTremolo` (EchoelModFX) for Echoel Studio 1.0, as a value of settings and a
/// render-thread processor like `Chorus`.
///
/// The depth glides in ~10 ms instead of stepping. A bad sample comes out as silence; the sine
/// keeps its place. Owned by the render thread: set `settings` and call `process` from that
/// thread. Nothing allocates.
public final class Tremolo: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// The sine's speed in Hz, 0.1 … 20.
        public var rate: Double
        /// How far the level falls, 0 … 1 (1: down to silence).
        public var depth: Double
        /// The right side against the left: auto-pan.
        public var pan: Bool

        public init(rate: Double = 5, depth: Double = 0.5, pan: Bool = false) {
            self.rate = rate
            self.depth = depth
            self.pan = pan
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(rate: clamp(rate, 0.1...20, base.rate), depth: clamp(depth, 0...1, base.depth), pan: pan)
        }
    }

    public var settings: Settings {
        didSet { settings = settings.clamped }
    }

    public let sampleRate: Double
    /// The sine's phase, 0 ..< 1.
    private var phase: Double = 0
    private var depthNow: Float
    private let glide: Float

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        glide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        let start = settings.clamped
        self.settings = start
        depthNow = Float(start.depth)
    }

    /// Starts the sine over.
    public func reset() {
        phase = 0
        depthNow = Float(settings.depth)
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let step = settings.rate / sampleRate
        let pan = settings.pan
        let depthTarget = Float(settings.depth)
        var depth = depthNow
        for i in 0..<frames {
            depth = Compressor.glided(depth, toward: depthTarget, by: glide)
            let swing = Float(0.5 + 0.5 * Foundation.sin(2 * Double.pi * phase))
            phase += step
            if phase >= 1 { phase -= 1 }
            let gainLeft = 1 - depth * (1 - swing)
            let gainRight = pan ? 1 - depth * swing : gainLeft
            let inLeft = left[i], inRight = right[i]
            guard inLeft.isFinite, inRight.isFinite else {
                left[i] = 0
                right[i] = 0
                continue
            }
            left[i] = inLeft * gainLeft
            right[i] = inRight * gainRight
        }
        depthNow = depth
    }
}
