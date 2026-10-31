import Foundation

/// Pitch correction: the sung or played note is pulled onto the nearest pitch the settings allow
/// — the song's key and scale, in its tone system, at its concert pitch. A `PitchTracker` hears
/// the fundamental of the input every ~5 ms; the nearest allowed pitch becomes the target, and a
/// `SpliceHead` plays the input at the ratio that lands it there. `speed` is how long the voice
/// takes to arrive: 0 snaps at once (the hard, stepped sound), a few tens of milliseconds keeps a
/// slide or a vibrato audible on its way.
///
/// Held notes stay still. A target is kept until another allowed pitch is clearly nearer (by a
/// fifth of a semitone), so a voice hovering between two notes does not flip between them; a held
/// note reads a near-constant ratio, and the head splices in phase (`SpliceHead`), so nothing
/// chirps. Where the tracker hears no pitch for 30 ms — a consonant, a breath — the correction
/// glides back to none. The output is the corrected sound alone, `SpliceHead.delaySeconds` behind
/// the input. Ported from the earlier app's monitor-only corrector (YIN, then snap to the scale);
/// its rebuilt monitor graph is not ported — this is a processor on an insert, nothing more.
///
/// Owned by the render thread: set `settings` and call `process` from that thread. Everything is
/// allocated in `init`.
public final class PitchCorrector: @unchecked Sendable {
    public struct Settings: Equatable, Sendable {
        /// Bit `n` set: pitch class `n` (0 = C … 11 = B) is a target. No bit set corrects nothing.
        public var allowed: UInt16
        /// How far each pitch class (0 = C … 11 = B) sits from twelve equal steps, in cents; the
        /// last four lanes are unused.
        public var cents: SIMD16<Float>
        /// The A above middle C, in hertz, 400 … 480.
        public var reference: Double
        /// Seconds to arrive at the target, 0 … 0.5.
        public var speed: Double
        /// How much of the correction is applied, 0 … 1.
        public var amount: Double

        public init(allowed: UInt16 = 0x0FFF, cents: SIMD16<Float> = .zero, reference: Double = 440,
                    speed: Double = 0.04, amount: Double = 1) {
            self.allowed = allowed
            self.cents = cents
            self.reference = reference
            self.speed = speed
            self.amount = amount
        }

        public var clamped: Settings {
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            var deviations = cents
            for lane in 0..<16 {
                let value = deviations[lane]
                deviations[lane] = lane < 12 && value.isFinite ? Swift.min(Swift.max(value, -100), 100) : 0
            }
            return Settings(allowed: allowed & 0x0FFF, cents: deviations, reference: clamp(reference, 400...480, 440),
                            speed: clamp(speed, 0...0.5, 0.04), amount: clamp(amount, 0...1, 1))
        }

        /// The allowed pitch classes of a scale given by its steps above `root` (0 = C).
        public static func mask(root: Int, steps: some Sequence<Int>) -> UInt16 {
            var mask: UInt16 = 0
            for step in steps { mask |= 1 << UInt16(((root + step) % 12 + 12) % 12) }
            return mask
        }
    }

    /// The largest correction, in semitones: half the widest gap of any scale, and a little more.
    public static let reach = 2.0
    /// How much nearer another pitch must be before the held target lets go, in semitones.
    public static let hysteresis = 0.2
    /// How long without a pitch before the correction lets go, in seconds.
    public static let release = 0.03

    public var settings: Settings {
        didSet { settings = settings.clamped }
    }

    public let sampleRate: Double
    /// The correction applied now, in semitones.
    public private(set) var correction: Double = 0

    private let tracker: PitchTracker
    private let history: StereoHistory
    private var head: SpliceHead
    /// The note held as target (a MIDI number), or none.
    private var target: Int?
    private var wanted: Double = 0
    private var period: Double = 0
    private var silentAnalyses = 0

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        tracker = PitchTracker(sampleRate: self.sampleRate)
        history = StereoHistory(seconds: 0.08, sampleRate: self.sampleRate)
        head = SpliceHead(sampleRate: self.sampleRate)
        self.settings = settings.clamped
    }

    /// Forgets what it heard and empties the delay.
    public func reset() {
        tracker.reset()
        history.reset()
        head.reset()
        target = nil
        wanted = 0
        correction = 0
        period = 0
        silentAnalyses = 0
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let glide = settings.speed < 0.001 ? 1 : 1 - Foundation.exp(-1 / (settings.speed * sampleRate))
        let amount = settings.amount
        let patience = Int(Self.release * sampleRate) / tracker.hop + 1
        for i in 0..<frames {
            let inLeft = left[i].isFinite ? left[i] : 0
            let inRight = right[i].isFinite ? right[i] : 0
            if tracker.push(0.5 * (inLeft + inRight)) { listen(patience: patience) }
            correction += (wanted - correction) * glide
            let ratio = Foundation.pow(2, correction * amount / 12)
            history.push(inLeft, inRight)
            head.advance(ratio: ratio, period: period)
            let (outLeft, outRight) = head.read(history)
            guard outLeft.isFinite, outRight.isFinite else {
                reset()
                left[i] = 0
                right[i] = 0
                continue
            }
            left[i] = outLeft
            right[i] = outRight
        }
    }

    /// After an analysis: the new target and the correction that reaches it.
    private func listen(patience: Int) {
        guard tracker.period > 0 else {
            silentAnalyses += 1
            if silentAnalyses >= patience {
                wanted = 0
                target = nil
                period = 0
            }
            return
        }
        silentAnalyses = 0
        period = tracker.period
        let note = 69 + 12 * Foundation.log2(tracker.frequency / settings.reference)
        guard note.isFinite, let chosen = choose(near: note) else {
            wanted = 0
            target = nil
            return
        }
        target = chosen
        wanted = Swift.min(Swift.max(pitch(of: chosen) - note, -Self.reach), Self.reach)
    }

    /// The nearest allowed note to `note`, keeping the held one unless another is clearly nearer.
    private func choose(near note: Double) -> Int? {
        let allowed = settings.allowed
        guard allowed != 0 else { return nil }
        let base = Int(note.rounded(.down))
        var best: Int?
        var bestDistance = Double.greatestFiniteMagnitude
        for candidate in (base - 4)...(base + 5) where isAllowed(candidate, allowed) {
            let distance = abs(note - pitch(of: candidate))
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }
        if let held = target, isAllowed(held, allowed), abs(note - pitch(of: held)) <= bestDistance + Self.hysteresis {
            return held
        }
        return best
    }

    @inline(__always)
    private func isAllowed(_ note: Int, _ allowed: UInt16) -> Bool {
        allowed & (1 << UInt16(((note % 12) + 12) % 12)) != 0
    }

    /// Where a note sits in the tone system, as a fractional MIDI number.
    @inline(__always)
    private func pitch(of note: Int) -> Double {
        Double(note) + Double(settings.cents[((note % 12) + 12) % 12]) / 100
    }
}
