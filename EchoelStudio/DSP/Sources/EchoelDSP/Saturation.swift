import Foundation

/// A stereo saturation: the sound drives a tanh curve with a small bias, so it gains odd
/// harmonics from the curve and even ones from its asymmetry — the warmth of a tube or a
/// transformer rather than a fuzz — then a tone filter rounds off the top and the result blends
/// with the dry sound (parallel saturation keeps the transients). Ported from the earlier app's
/// saturation stage and tone filter (`EchoelFXChain.saturate`) for Echoel Studio 1.0, as a value
/// of settings and a render-thread processor like `Chorus`.
///
/// A makeup factor holds the level roughly steady as the drive rises. The bias would leave a
/// small offset on the wet sound; a 10 Hz DC blocker takes it out. Drive and mix glide in ~10 ms
/// instead of stepping. One bad sample empties the filters rather than ringing in them. Owned by
/// the render thread: set `settings` and call `process` from that thread. Nothing allocates.
public final class Saturation: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// How hard the curve is driven, 0 … 1 (0: the curve's gentle knee only).
        public var drive: Double
        /// How much top end stays, 0 … 1 (0: about 1 kHz, 1: about 20 kHz).
        public var tone: Double
        /// Dry 0 … saturated 1.
        public var mix: Double

        public init(drive: Double = 0.4, tone: Double = 0.85, mix: Double = 0.6) {
            self.drive = drive
            self.tone = tone
            self.mix = mix
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(drive: clamp(drive, 0...1, base.drive), tone: clamp(tone, 0...1, base.tone),
                            mix: clamp(mix, 0...1, base.mix))
        }
    }

    /// The tone filter's corner at `tone` 0 … 1, in Hz, never past 0.45 of the sample rate.
    public static func toneHertz(_ tone: Double, sampleRate: Double) -> Double {
        Swift.min(1_000 * Foundation.pow(20, tone), 0.45 * sampleRate)
    }

    public var settings: Settings {
        didSet {
            settings = settings.clamped
            toneCoefficient = Self.coefficient(settings.tone, sampleRate)
        }
    }

    public let sampleRate: Double
    private let glide: Float
    private let blockerPole: Float
    private var toneCoefficient: Float = 1
    private var driveNow: Float
    private var wetNow: Float
    private var blockerInLeft: Float = 0
    private var blockerInRight: Float = 0
    private var blockerOutLeft: Float = 0
    private var blockerOutRight: Float = 0
    private var lowLeft: Float = 0
    private var lowRight: Float = 0

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        glide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        blockerPole = Float(1 - 2 * Double.pi * 10 / self.sampleRate)
        let start = settings.clamped
        self.settings = start
        driveNow = Float(start.drive)
        wetNow = Float(start.mix)
        toneCoefficient = Self.coefficient(start.tone, self.sampleRate)
    }

    private static func coefficient(_ tone: Double, _ sampleRate: Double) -> Float {
        Float(1 - Foundation.exp(-2 * Double.pi * toneHertz(tone, sampleRate: sampleRate) / sampleRate))
    }

    /// Empties the filters.
    public func reset() {
        blockerInLeft = 0
        blockerInRight = 0
        blockerOutLeft = 0
        blockerOutRight = 0
        lowLeft = 0
        lowRight = 0
        driveNow = Float(settings.drive)
        wetNow = Float(settings.mix)
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let driveTarget = Float(settings.drive)
        let wetTarget = Float(settings.mix)
        let toneAmount = toneCoefficient
        var drive = driveNow
        var wet = wetNow
        for i in 0..<frames {
            drive = Compressor.glided(drive, toward: driveTarget, by: glide)
            wet = Compressor.glided(wet, toward: wetTarget, by: glide)
            let gain = 1 + drive * 3
            let bias = 0.12 * drive
            let offset = tanh(bias)
            let makeup = 1 / (1 + drive * 1.4)
            let inLeft = left[i], inRight = right[i]
            let curvedLeft = (tanh(inLeft * gain + bias) - offset) * makeup
            let curvedRight = (tanh(inRight * gain + bias) - offset) * makeup
            let blockedLeft = curvedLeft - blockerInLeft + blockerPole * blockerOutLeft
            let blockedRight = curvedRight - blockerInRight + blockerPole * blockerOutRight
            blockerInLeft = curvedLeft
            blockerInRight = curvedRight
            blockerOutLeft = blockedLeft
            blockerOutRight = blockedRight
            lowLeft += toneAmount * (blockedLeft - lowLeft)
            lowRight += toneAmount * (blockedRight - lowRight)
            let outLeft = inLeft * (1 - wet) + lowLeft * wet
            let outRight = inRight * (1 - wet) + lowRight * wet
            guard outLeft.isFinite, outRight.isFinite else {
                reset()
                left[i] = 0
                right[i] = 0
                drive = driveNow
                wet = wetNow
                continue
            }
            left[i] = outLeft
            right[i] = outRight
        }
        driveNow = drive
        wetNow = wet
    }
}
