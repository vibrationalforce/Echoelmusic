import Foundation

/// Mid/side processing: the sound split into its mid (what left and right share) and its side
/// (where they differ), each with its own level, the side widened or narrowed, tilted brighter or
/// darker around 1 kHz, and kept mono below a chosen frequency. Written new for Echoel Studio
/// (ECHOELTOOLS catalog B10), as a value of settings and a render-thread processor like `Chorus`;
/// `StereoWidth` stays the one-knob width, this is the desk's M/S strip.
///
/// Mono-safe by construction: everything but Mid Gain works on the side alone, and the side
/// cancels in a mono sum, so folding the output to mono plays the mid at its own gain whatever
/// width, side gain, tilt and mono frequency do. The side's tilt splits it at 1 kHz
/// (a critically damped `ZDFStage` lowpass and the rest): the low part down by half the tilt,
/// the rest up by it, so 0 dB is flat, and Mono Below a second-order Butterworth highpass on the side (20 Hz, its
/// lowest, passes everything that plays). Gains glide in ~10 ms, the mono frequency per sample.
/// A bad sample comes out as silence. Owned by the render thread: set `settings` and call
/// `process` from that thread. Nothing allocates.
public final class MidSide: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// The side's scale: 0 (mono) … 1 (unchanged) … 2 (twice the side).
        public var width: Double
        /// dB, −24 … 12.
        public var midGain: Double
        /// dB, −24 … 12.
        public var sideGain: Double
        /// dB of the side's tilt around 1 kHz, −6 (darker) … 6 (brighter).
        public var tilt: Double
        /// Hz below which the side is taken out, 20 … 500.
        public var monoBelow: Double

        public init(width: Double = 1, midGain: Double = 0, sideGain: Double = 0, tilt: Double = 0, monoBelow: Double = 20) {
            self.width = width
            self.midGain = midGain
            self.sideGain = sideGain
            self.tilt = tilt
            self.monoBelow = monoBelow
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(width: clamp(width, 0...2, base.width), midGain: clamp(midGain, -24...12, base.midGain),
                            sideGain: clamp(sideGain, -24...12, base.sideGain), tilt: clamp(tilt, -6...6, base.tilt),
                            monoBelow: clamp(monoBelow, 20...500, base.monoBelow))
        }
    }

    /// The tilt's pivot.
    static let pivot = 1_000.0

    public var settings: Settings {
        didSet { settings = settings.clamped }
    }

    public let sampleRate: Double
    private var tiltStage = ZDFStage()
    private var monoStage = ZDFStage()
    private let tiltG: Float
    private let glide: Float
    private var midNow: Float, sideNow: Float, lowNow: Float, highNow: Float, monoGNow: Float

    private struct Targets {
        var mid: Float, side: Float, low: Float, high: Float, monoG: Float
    }

    private func targets() -> Targets {
        let s = settings
        let half = s.tilt / 2
        return Targets(mid: Float(Foundation.pow(10, s.midGain / 20)),
                       side: Float(s.width * Foundation.pow(10, s.sideGain / 20)),
                       low: Float(Foundation.pow(10, -half / 20)), high: Float(Foundation.pow(10, half / 20)),
                       monoG: ZDFStage.g(s.monoBelow, sampleRate: sampleRate))
    }

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        glide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        tiltG = ZDFStage.g(Self.pivot, sampleRate: self.sampleRate)
        let start = settings.clamped
        self.settings = start
        midNow = 1
        sideNow = 1
        lowNow = 1
        highNow = 1
        monoGNow = 0
        let t = targets()
        midNow = t.mid
        sideNow = t.side
        lowNow = t.low
        highNow = t.high
        monoGNow = t.monoG
    }

    public func reset() {
        tiltStage.reset()
        monoStage.reset()
        let t = targets()
        midNow = t.mid
        sideNow = t.side
        lowNow = t.low
        highNow = t.high
        monoGNow = t.monoG
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let t = targets()
        var mid = midNow, side = sideNow, low = lowNow, high = highNow, monoG = monoGNow
        let k = ZDFStage.butterworth
        for i in 0..<frames {
            mid = Compressor.glided(mid, toward: t.mid, by: glide)
            side = Compressor.glided(side, toward: t.side, by: glide)
            low = Compressor.glided(low, toward: t.low, by: glide)
            high = Compressor.glided(high, toward: t.high, by: glide)
            monoG = Compressor.glided(monoG, toward: t.monoG, by: glide)
            let inLeft = left[i], inRight = right[i]
            guard inLeft.isFinite, inRight.isFinite else {
                tiltStage.reset()
                monoStage.reset()
                left[i] = 0
                right[i] = 0
                continue
            }
            let m = (inLeft + inRight) * 0.5 * mid
            var s = (inLeft - inRight) * 0.5
            s = monoStage.process(s, g: monoG, k: k).high
            // The low part and the rest add up to the side itself, so a tilt of 0 dB is exactly flat.
            let split = tiltStage.process(s, g: tiltG, k: 2)
            s = (split.low * low + (s - split.low) * high) * side
            let outLeft = m + s, outRight = m - s
            guard outLeft.isFinite, outRight.isFinite else {
                tiltStage.reset()
                monoStage.reset()
                left[i] = 0
                right[i] = 0
                continue
            }
            left[i] = outLeft
            right[i] = outRight
        }
        midNow = mid
        sideNow = side
        lowNow = low
        highNow = high
        monoGNow = monoG
    }
}
