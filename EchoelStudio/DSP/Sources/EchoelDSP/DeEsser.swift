import Foundation

/// A de-esser: it listens to the top of a voice — the "s", "sh" and "t" between 3 and 12 kHz —
/// and, while that band is louder than its threshold, turns down only the highs above its
/// frequency, by at most its range. The vowels below pass as they came in. Written new for Echoel
/// Studio, as a value of settings and a render-thread processor like `DynamicEQ`.
///
/// **Detector.** Per side, two Butterworth `ZDFStage` high-passes at Frequency in a row (24 dB
/// per octave, Linkwitz-Riley): a vowel's harmonics under 2 kHz reach it about 45 dB down at the
/// default 6.5 kHz. The louder side's peak is followed with a fast attack (`attackSeconds`) and a
/// short release (`releaseSeconds`), in dB, and the reduction is how far it sits over the
/// threshold, never more than Range: the band is held at the threshold until Range runs out.
/// One reduction for both sides, so the stereo image does not lean.
///
/// **Split.** The reduction acts through a complementary split of the input: one `ZDFStage` per
/// side splits it into `low + k·band + high`, which is the input again, and the output is
/// `low + A·k·band + A²·high` with `A² = 10^(−reduction / 20)` — the high split turned down by the
/// reduction, the band between by half of it in dB, the low split untouched (the second-order
/// high shelf of the TPT form, its corner at Frequency·√A so the shelf's middle stays at
/// Frequency). It is written as `x + (A − 1)·k·band + (A² − 1)·high`, so with no reduction — under
/// the threshold, or Range 0 — the output IS the input, sample for sample, not an allpass of it.
///
/// **Listen** plays what the detector hears instead, to find the frequency by ear.
///
/// No look-ahead: the latency is 0. Frequency glides per sample; the reduction moves with the
/// follower. A sample that is not a number empties the processor and comes out as silence. Owned
/// by the render thread: set `settings` and call `process` from that thread. Nothing allocates.
public final class DeEsser: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// Hz the detector listens above and the highs are split at, 3000 … 12000.
        public var frequency: Double
        /// dBFS of the detected band's peak where the reduction starts, −60 … 0.
        public var threshold: Double
        /// The most the highs are turned down, dB, 0 … 24.
        public var range: Double
        /// Play the detected band instead of the voice.
        public var listen: Bool

        public init(frequency: Double = 6_500, threshold: Double = -30, range: Double = 6, listen: Bool = false) {
            self.frequency = frequency
            self.threshold = threshold
            self.range = range
            self.listen = listen
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ limits: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, limits.lowerBound), limits.upperBound) : fallback
            }
            return Settings(frequency: clamp(frequency, 3_000...12_000, base.frequency),
                            threshold: clamp(threshold, -60...0, base.threshold),
                            range: clamp(range, 0...24, base.range), listen: listen)
        }
    }

    /// The detector's attack: fast, so the start of an "s" is caught.
    static let attackSeconds = 0.0005
    /// The detector's release: short, so the vowel after the "s" is not dulled.
    static let releaseSeconds = 0.06

    public var settings: Settings {
        didSet {
            settings = settings.clamped
            update()
            // Set before the first block, a value takes effect at once: the effect loads as stored.
            if !hasRun { gNow = gTarget }
        }
    }

    public let sampleRate: Double
    /// The reduction of the highs right now, in dB (0 or less), for a meter.
    public private(set) var reduction: Float = 0

    // Per side: the detector's two high-passes, then the split.
    private var detectLeftA = ZDFStage(), detectLeftB = ZDFStage(), splitLeft = ZDFStage()
    private var detectRightA = ZDFStage(), detectRightB = ZDFStage(), splitRight = ZDFStage()
    private var gTarget: Float = 0, gNow: Float = 0
    private var threshold: Float = 0, range: Float = 0
    private var listen = false
    /// The detected band's followed peak, linear.
    private var level: Float = 0
    private let attackCoefficient: Float
    private let releaseCoefficient: Float
    private let glide: Float
    private var hasRun = false

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        glide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        attackCoefficient = Float(1 - Foundation.exp(-1 / (Self.attackSeconds * self.sampleRate)))
        releaseCoefficient = Float(1 - Foundation.exp(-1 / (Self.releaseSeconds * self.sampleRate)))
        self.settings = settings.clamped
        update()
        gNow = gTarget
    }

    private func update() {
        let s = settings
        gTarget = ZDFStage.g(s.frequency, sampleRate: sampleRate)
        threshold = Float(s.threshold)
        range = Float(s.range)
        listen = s.listen
    }

    /// Empties the filters and the follower.
    public func reset() {
        emptyFilters()
        gNow = gTarget
        level = 0
        reduction = 0
    }

    private func emptyFilters() {
        detectLeftA.reset()
        detectLeftB.reset()
        splitLeft.reset()
        detectRightA.reset()
        detectRightB.reset()
        splitRight.reset()
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        guard frames > 0 else { return }
        hasRun = true
        let k = ZDFStage.butterworth
        var g = gNow, follower = level, gain = reduction
        // The filters as locals for the loop, written back after it.
        var leftA = detectLeftA, leftB = detectLeftB, leftSplit = splitLeft
        var rightA = detectRightA, rightB = detectRightB, rightSplit = splitRight
        for i in 0..<frames {
            g = Compressor.glided(g, toward: gTarget, by: glide)
            let inLeft = left[i], inRight = right[i]
            var outLeft: Float = 0, outRight: Float = 0
            if inLeft.isFinite, inRight.isFinite {
                let heardLeft = leftB.process(leftA.process(inLeft, g: g, k: k).high, g: g, k: k).high
                let heardRight = rightB.process(rightA.process(inRight, g: g, k: k).high, g: g, k: k).high
                let peak = Swift.max(Swift.abs(heardLeft), Swift.abs(heardRight))
                follower += (peak - follower) * (peak > follower ? attackCoefficient : releaseCoefficient)
                let over = 20 * log10f(Swift.max(follower, 1e-6)) - threshold
                let cut = Swift.min(Swift.max(over, 0), range)
                gain = -cut
                // A = 10^(−cut / 40): the high split gets A², the band between it A.
                let a: Float = cut > 0 ? Foundation.powf(10, -cut / 40) : 1
                let gSplit = g * a.squareRoot()
                let splitL = leftSplit.process(inLeft, g: gSplit, k: k)
                let splitR = rightSplit.process(inRight, g: gSplit, k: k)
                if listen {
                    outLeft = heardLeft
                    outRight = heardRight
                } else if cut > 0 {
                    outLeft = inLeft + (a - 1) * k * splitL.band + (a * a - 1) * splitL.high
                    outRight = inRight + (a - 1) * k * splitR.band + (a * a - 1) * splitR.high
                } else {
                    outLeft = inLeft
                    outRight = inRight
                }
            }
            guard outLeft.isFinite, outRight.isFinite, follower.isFinite, inLeft.isFinite, inRight.isFinite else {
                // Not a number in or out: empty everything, and this sample is silence.
                leftA.reset()
                leftB.reset()
                leftSplit.reset()
                rightA.reset()
                rightB.reset()
                rightSplit.reset()
                follower = 0
                gain = 0
                left[i] = 0
                right[i] = 0
                continue
            }
            left[i] = outLeft
            right[i] = outRight
        }
        detectLeftA = leftA
        detectLeftB = leftB
        splitLeft = leftSplit
        detectRightA = rightA
        detectRightB = rightB
        splitRight = rightSplit
        gNow = g
        level = follower
        reduction = gain
    }
}
