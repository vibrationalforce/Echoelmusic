import Foundation

/// A ring modulator: the sound is multiplied by a sine, so every frequency `f` in it becomes the
/// pair `f − carrier` and `f + carrier` and the original disappears — bells, metal, the voice of
/// a robot. Written new for Echoel Studio 1.0 (the earlier app named it and never rendered it,
/// ECHOELTOOLS catalog B9), as a value of settings and a render-thread processor like `Chorus`.
///
/// The mix glides in ~10 ms instead of stepping. A bad sample comes out as silence; the carrier
/// keeps its place. Owned by the render thread: set `settings` and call `process` from that
/// thread. Nothing allocates.
public final class RingModulator: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// The carrier sine in Hz, 1 … 5000.
        public var frequency: Double
        /// Dry 0 … modulated 1.
        public var mix: Double

        public init(frequency: Double = 440, mix: Double = 0.5) {
            self.frequency = frequency
            self.mix = mix
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(frequency: clamp(frequency, 1...5_000, base.frequency), mix: clamp(mix, 0...1, base.mix))
        }
    }

    public var settings: Settings {
        didSet { settings = settings.clamped }
    }

    public let sampleRate: Double
    /// The carrier's phase, 0 ..< 1.
    private var phase: Double = 0
    private var wetNow: Float
    private let glide: Float

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        glide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        let start = settings.clamped
        self.settings = start
        wetNow = Float(start.mix)
    }

    /// Starts the carrier over.
    public func reset() {
        phase = 0
        wetNow = Float(settings.mix)
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let step = Swift.min(settings.frequency / sampleRate, 0.5)
        let wetTarget = Float(settings.mix)
        var wet = wetNow
        for i in 0..<frames {
            wet = Compressor.glided(wet, toward: wetTarget, by: glide)
            let carrier = Float(Foundation.sin(2 * Double.pi * phase))
            phase += step
            if phase >= 1 { phase -= 1 }
            let inLeft = left[i], inRight = right[i]
            guard inLeft.isFinite, inRight.isFinite else {
                left[i] = 0
                right[i] = 0
                continue
            }
            left[i] = inLeft * (1 - wet) + inLeft * carrier * wet
            right[i] = inRight * (1 - wet) + inRight * carrier * wet
        }
        wetNow = wet
    }
}
