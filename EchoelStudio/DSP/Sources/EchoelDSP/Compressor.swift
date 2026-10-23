import Foundation

/// A stereo-linked feed-forward compressor: the louder side drives one gain for both, so the
/// stereo image never leans. Soft knee, attack and release in the dB domain, makeup gain and a
/// dry/wet mix for parallel compression.
///
/// Owned by the render thread. Nothing allocates.
public struct Compressor: Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// dBFS, −60 … 0.
        public var threshold: Double = -18
        /// 1 … 20 (20 is a limiter in all but name).
        public var ratio: Double = 4
        /// Seconds, 0.1 ms … 200 ms.
        public var attack: Double = 0.01
        /// Seconds, 10 ms … 2 s.
        public var release: Double = 0.15
        /// dB of knee width, 0 … 24.
        public var knee: Double = 6
        /// dB, 0 … 24.
        public var makeup: Double = 0
        /// Dry 0 … compressed 1.
        public var mix: Double = 1

        public init() {}

        public var clamped: Settings {
            var s = self
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            s.threshold = clamp(threshold, -60...0, base.threshold)
            s.ratio = clamp(ratio, 1...20, base.ratio)
            s.attack = clamp(attack, 0.0001...0.2, base.attack)
            s.release = clamp(release, 0.01...2, base.release)
            s.knee = clamp(knee, 0...24, base.knee)
            s.makeup = clamp(makeup, 0...24, base.makeup)
            s.mix = clamp(mix, 0...1, base.mix)
            return s
        }
    }

    public var settings: Settings {
        didSet {
            settings = settings.clamped
            update()
        }
    }

    public let sampleRate: Double
    /// The gain reduction right now, in dB (0 or less), for a meter.
    public private(set) var reduction: Float = 0
    private var attackCoefficient: Float = 0
    private var releaseCoefficient: Float = 0
    private var threshold: Float = 0
    private var slope: Float = 0
    private var knee: Float = 0
    private var makeup: Float = 1
    private var wet: Float = 1
    /// Makeup and mix as they sound now: a change glides there in ~10 ms instead of stepping the
    /// output in one sample — a MIDI knob on Makeup moves in 0.19 dB steps, a zipper without it
    /// (audit 2026-10-23). Until the first sample runs, a setting takes effect at once.
    private var makeupNow: Float = 1
    private var wetNow: Float = 1
    private var hasRun = false
    private let glide: Float
    static let gainGlideSeconds = 0.01

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        glide = Float(1 - Foundation.exp(-1 / (Self.gainGlideSeconds * self.sampleRate)))
        self.settings = settings.clamped
        update()
    }

    private mutating func update() {
        let s = settings
        attackCoefficient = Float(1 - Foundation.exp(-1 / (s.attack * sampleRate)))
        releaseCoefficient = Float(1 - Foundation.exp(-1 / (s.release * sampleRate)))
        threshold = Float(s.threshold)
        slope = Float(1 / s.ratio - 1)
        knee = Float(s.knee)
        makeup = Float(Foundation.pow(10, s.makeup / 20))
        wet = Float(s.mix)
        if !hasRun {
            makeupNow = makeup
            wetNow = wet
        }
    }

    public mutating func reset() {
        reduction = 0
        hasRun = false
        makeupNow = makeup
        wetNow = wet
    }

    /// The reduction in dB the gain computer asks for at `level` dBFS — before attack/release.
    public func target(at level: Float) -> Float {
        let over = level - threshold
        if knee > 0, 2 * Swift.abs(over) <= knee {
            let x = over + knee / 2
            return slope * x * x / (2 * knee)
        }
        return over > 0 ? slope * over : 0
    }

    /// Processes `frames` samples in place.
    public mutating func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        var env = reduction.isFinite ? reduction : 0
        var makeupGain = makeupNow, wetAmount = wetNow
        if frames > 0 { hasRun = true }
        for i in 0..<frames {
            let l = left[i].isFinite ? left[i] : 0, r = right[i].isFinite ? right[i] : 0
            let peak = Swift.max(Swift.abs(l), Swift.abs(r))
            let level = 20 * log10f(Swift.max(peak, 1e-9))
            let wanted = target(at: level)
            // More reduction follows at the attack, less at the release.
            env += (wanted - env) * (wanted < env ? attackCoefficient : releaseCoefficient)
            makeupGain = Self.glided(makeupGain, toward: makeup, by: glide)
            wetAmount = Self.glided(wetAmount, toward: wet, by: glide)
            let gain = env == 0 ? makeupGain : Foundation.powf(10, env / 20) * makeupGain
            let dry = 1 - wetAmount
            left[i] = l * dry + l * gain * wetAmount
            right[i] = r * dry + r * gain * wetAmount
        }
        // Arrived: hold the setting itself, so a settled compressor plays it exactly.
        makeupNow = Swift.abs(makeup - makeupGain) < 1e-6 ? makeup : makeupGain
        wetNow = Swift.abs(wet - wetAmount) < 1e-6 ? wet : wetAmount
        reduction = Swift.abs(env) < 1e-6 ? 0 : env
    }

    /// One sample of a gain glide toward `target`. A Float glide stops moving a few hundred ulps
    /// short of its target — 3.98101 for 12 dB of makeup, 0.99999 for a full mix — and an
    /// "arrived" check at that distance never fires; where it stops, it takes the target
    /// (review 2026-10-23). Shared by the delay's and the reverb's mix.
    @inline(__always)
    static func glided(_ value: Float, toward goal: Float, by amount: Float) -> Float {
        let next = value + (goal - value) * amount
        return next == value ? goal : next
    }
}
