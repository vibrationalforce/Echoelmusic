import Foundation

/// Up to three harmony voices over the dry sound, each the input played at a fixed interval
/// above or below it. Ported from the earlier app's `EchoelHarmonizer` (two voices, a two-tap
/// delay-line shifter): the voices now splice on whole periods of the input (`SpliceHead`, with a
/// `PitchTracker` listening), so a held note keeps its harmonies clean instead of combing, and a
/// third voice is there for a full triad.
///
/// The dry sound passes at full level and never moves; the voices are added at `level`, the first
/// in the middle and the other two `spread` to the left and the right. Each voice runs
/// `SpliceHead.delaySeconds` behind the dry sound, which reads as a second singer rather than an
/// echo. The intervals are semitones here; their names belong to the song's side
/// (`HarmonyInterval` in EchoelCore), as the founder asked: harmonies, not semitone steps.
///
/// Owned by the render thread: set `settings` and call `process` from that thread. Everything is
/// allocated in `init`.
public final class Harmonizer: @unchecked Sendable {
    public struct Settings: Equatable, Sendable {
        /// Each voice's interval in semitones, −24 … 24, or nil when the voice is off.
        public var first: Double?
        public var second: Double?
        public var third: Double?
        /// The voices' level against the dry sound, 0 … 1.
        public var level: Double
        /// How far the second and third voice sit to the sides, 0 … 1.
        public var spread: Double

        public init(first: Double? = 7, second: Double? = nil, third: Double? = nil, level: Double = 0.5,
                    spread: Double = 0.5) {
            self.first = first
            self.second = second
            self.third = third
            self.level = level
            self.spread = spread
        }

        public var clamped: Settings {
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            func interval(_ value: Double?) -> Double? {
                guard let value, value.isFinite else { return nil }
                return Swift.min(Swift.max(value, -24), 24)
            }
            return Settings(first: interval(first), second: interval(second), third: interval(third),
                            level: clamp(level, 0...1, 0.5), spread: clamp(spread, 0...1, 0.5))
        }
    }

    public var settings: Settings {
        didSet { settings = settings.clamped }
    }

    public let sampleRate: Double
    private let tracker: PitchTracker
    private let history: StereoHistory
    private var heads: (SpliceHead, SpliceHead, SpliceHead)
    private var levelNow: Float
    private let levelGlide: Float

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        tracker = PitchTracker(sampleRate: self.sampleRate)
        history = StereoHistory(seconds: 0.08, sampleRate: self.sampleRate)
        let head = SpliceHead(sampleRate: self.sampleRate)
        heads = (head, head, head)
        levelGlide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        self.settings = settings.clamped
        levelNow = Float(self.settings.level)
    }

    /// Empties the delay and forgets the pitch.
    public func reset() {
        tracker.reset()
        history.reset()
        heads.0.reset()
        heads.1.reset()
        heads.2.reset()
        levelNow = Float(settings.level)
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let s = settings
        let ratios = (Self.ratio(s.first), Self.ratio(s.second), Self.ratio(s.third))
        let side = Float(s.spread)
        // Linear balance: the middle voice is at unity on both sides.
        let secondGains = (Swift.min(1, 1 + side), Swift.min(1, 1 - side))
        let thirdGains = (Swift.min(1, 1 - side), Swift.min(1, 1 + side))
        let levelTarget = Float(s.level)
        var level = levelNow
        for i in 0..<frames {
            let inLeft = left[i].isFinite ? left[i] : 0
            let inRight = right[i].isFinite ? right[i] : 0
            tracker.push(0.5 * (inLeft + inRight))
            history.push(inLeft, inRight)
            level = Compressor.glided(level, toward: levelTarget, by: levelGlide)
            let period = tracker.period
            var wetLeft: Float = 0
            var wetRight: Float = 0
            if let ratio = ratios.0 {
                heads.0.advance(ratio: ratio, period: period)
                let voice = heads.0.read(history)
                wetLeft += voice.0
                wetRight += voice.1
            }
            if let ratio = ratios.1 {
                heads.1.advance(ratio: ratio, period: period)
                let voice = heads.1.read(history)
                wetLeft += voice.0 * secondGains.0
                wetRight += voice.1 * secondGains.1
            }
            if let ratio = ratios.2 {
                heads.2.advance(ratio: ratio, period: period)
                let voice = heads.2.read(history)
                wetLeft += voice.0 * thirdGains.0
                wetRight += voice.1 * thirdGains.1
            }
            let outLeft = inLeft + wetLeft * level
            let outRight = inRight + wetRight * level
            guard outLeft.isFinite, outRight.isFinite else {
                reset()
                left[i] = 0
                right[i] = 0
                level = levelNow
                continue
            }
            left[i] = outLeft
            right[i] = outRight
        }
        levelNow = level
    }

    private static func ratio(_ semitones: Double?) -> Double? {
        guard let semitones else { return nil }
        return Foundation.pow(2, semitones / 12)
    }
}
