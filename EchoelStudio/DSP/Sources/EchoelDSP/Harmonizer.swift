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
/// Beyond the three fixed intervals, a `Voicing` sets the voices from the sung note (the choir
/// styles, VOX): two side voices whose intervals depend on the note's pitch class — a diatonic
/// third is major on one note and minor on the next — or one held note in the middle, the ison.
/// The style's names and its music theory live in EchoelCore (`HarmonyStyle`); this processor only
/// plays the tables it is given.
///
/// Owned by the render thread: set `settings` and call `process` from that thread. Everything is
/// allocated in `init`.
public final class Harmonizer: @unchecked Sendable {
    /// How the voices are set.
    public enum Voicing: Equatable, Sendable {
        /// The three voices at `Settings.first`, `second` and `third`.
        case free
        /// Two voices, left and right. For a sung note nearest pitch class n (0 = C … 11 = B, with
        /// the A above middle C at `reference` hertz) the left one sings `left[n]` and the right one
        /// `right[n]` semitones from it; lanes 12 … 15 are unused. Until a pitch is heard, and
        /// through a consonant or a breath, each keeps the interval it had.
        case following(left: SIMD16<Float>, right: SIMD16<Float>, reference: Double)
        /// One voice in the middle that sings pitch class `root`: the input moved onto that note, so
        /// it holds it at the voice's own level while the melody moves. Its octave is the root at or
        /// below the first note heard; it moves when the melody goes more than a fifth below it or
        /// more than an octave and a fifth above, and it is chosen again after a pause.
        case ison(root: Int, reference: Double)
    }

    public struct Settings: Equatable, Sendable {
        /// Each voice's interval in semitones, −24 … 24, or nil when the voice is off.
        public var first: Double?
        public var second: Double?
        public var third: Double?
        /// The voices' level against the dry sound, 0 … 1.
        public var level: Double
        /// How far the second and third voice sit to the sides, 0 … 1.
        public var spread: Double
        /// How the voices are set; `.free` plays the three intervals above.
        public var voicing: Voicing

        public init(first: Double? = 7, second: Double? = nil, third: Double? = nil, level: Double = 0.5,
                    spread: Double = 0.5, voicing: Voicing = .free) {
            self.first = first
            self.second = second
            self.third = third
            self.level = level
            self.spread = spread
            self.voicing = voicing
        }

        public var clamped: Settings {
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            func interval(_ value: Double?) -> Double? {
                guard let value, value.isFinite else { return nil }
                return Swift.min(Swift.max(value, -24), 24)
            }
            func table(_ lanes: SIMD16<Float>) -> SIMD16<Float> {
                var out = SIMD16<Float>.zero
                for lane in 0..<12 {
                    let value = lanes[lane]
                    out[lane] = value.isFinite ? Swift.min(Swift.max(value, -24), 24) : 0
                }
                return out
            }
            let voicing: Voicing = switch self.voicing {
            case .free: .free
            case let .following(left, right, reference):
                .following(left: table(left), right: table(right), reference: clamp(reference, 400...480, 440))
            case let .ison(root, reference):
                .ison(root: ((root % 12) + 12) % 12, reference: clamp(reference, 400...480, 440))
            }
            return Settings(first: interval(first), second: interval(second), third: interval(third),
                            level: clamp(level, 0...1, 0.5), spread: clamp(spread, 0...1, 0.5), voicing: voicing)
        }
    }

    public var settings: Settings {
        didSet { settings = settings.clamped }
    }

    /// Seconds a free voice takes to fade in when it is switched on and out when it is switched
    /// off — and, around a change of voicing, the harmonies take to fade out before the new voicing
    /// takes over and to fade in after it. The dry sound goes on throughout. Before, a voice entered
    /// mid-waveform and a style chosen while the voice sounded stepped — Free to Organum by the
    /// whole level (click hunt, 2026-11-01).
    public static let changeFade = 0.005
    /// The voicing the voices sing now; `settings.voicing` takes over once the harmonies are out.
    private var heardVoicing: Voicing
    /// How open the harmonies are around a change of voicing, and each free voice around being
    /// switched on or off (0 … 1); each moves by `gateStep` per sample.
    private var voicingGate: Float = 1
    private var freeGates: (Float, Float, Float)
    /// The interval each free voice sang last, so a voice switched off fades out on its own note.
    private var freeIntervals: (Double, Double, Double)
    private let gateStep: Float

    /// How long a style's voice takes to move to a new interval, in seconds: quick enough to follow
    /// the melody, slow enough that the step is not a click.
    public static let intervalGlide = 0.015
    /// How long the ison takes to cancel the voice's own movement, in seconds.
    public static let isonGlide = 0.02
    /// How far the sung pitch must stray from the held note before another one is heard, in
    /// semitones beyond the half-way point: a voice between two notes does not flip between them.
    public static let hysteresis = 0.2
    /// How long without a pitch before the ison forgets its octave, in seconds: a breath between
    /// phrases, not a consonant.
    public static let isonPause = 0.25
    /// How long the voices go on after the input stops, in seconds: the farthest a voice's head
    /// reads behind the newest sample, and one cross-fade.
    public static var tailSeconds: Double { SpliceHead.farthest + SpliceHead.fadeSeconds }

    public let sampleRate: Double
    private let tracker: PitchTracker
    private let history: StereoHistory
    private var heads: (SpliceHead, SpliceHead, SpliceHead)
    private var levelNow: Float
    private let levelGlide: Float
    private let intervalPole: Double
    private let isonPole: Double
    private let gatePole: Float
    /// Analyses without a pitch in a row; enough of them make a pause.
    private var silentAnalyses = 0
    /// The note held as heard (a MIDI number), so a voice hovering between two keeps one.
    private var heldNote: Int?
    /// The side voices' intervals now and where they are going, in semitones.
    private var leftNow = 0.0, leftTarget = 0.0
    private var rightNow = 0.0, rightTarget = 0.0
    /// The ison's note (a fractional MIDI number), its shift from the sung note now and where it is
    /// going, and how open it is (0 … 1): closed until a note is chosen.
    private var isonNote: Double?
    private var isonNow = 0.0, isonTarget = 0.0
    private var isonGate: Float = 0

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        tracker = PitchTracker(sampleRate: self.sampleRate)
        history = StereoHistory(seconds: 0.08, sampleRate: self.sampleRate)
        let head = SpliceHead(sampleRate: self.sampleRate)
        heads = (head, head, head)
        levelGlide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        intervalPole = Foundation.exp(-1 / (Self.intervalGlide * self.sampleRate))
        isonPole = Foundation.exp(-1 / (Self.isonGlide * self.sampleRate))
        gatePole = Float(Foundation.exp(-1 / (0.005 * self.sampleRate)))
        gateStep = Float(1 / (Self.changeFade * self.sampleRate))
        let clamped = settings.clamped
        self.settings = clamped
        heardVoicing = clamped.voicing
        freeGates = Self.gates(clamped)
        freeIntervals = (clamped.first ?? 0, clamped.second ?? 0, clamped.third ?? 0)
        levelNow = Float(self.settings.level)
        retarget()
    }

    /// Empties the delay and forgets the pitch.
    public func reset() {
        tracker.reset()
        history.reset()
        heads.0.reset()
        heads.1.reset()
        heads.2.reset()
        levelNow = Float(settings.level)
        heldNote = nil
        silentAnalyses = 0
        heardVoicing = settings.voicing
        voicingGate = 1
        retarget()
    }

    /// A new voicing starts on its own intervals, not gliding from another style's: the side
    /// voices take the held note's (or C's, before one is heard), the ison chooses its octave again,
    /// the free voices that are on stand open (the voicing's own fade brings them in).
    private func retarget() {
        freeGates = Self.gates(settings)
        if case let .following(left, right, _) = heardVoicing {
            let lane = heldNote.map { (($0 % 12) + 12) % 12 } ?? 0
            leftTarget = Double(left[lane])
            rightTarget = Double(right[lane])
            leftNow = leftTarget
            rightNow = rightTarget
        }
        isonNote = nil
        isonNow = 0
        isonTarget = 0
        isonGate = 0
    }

    /// Processes `frames` samples in place. Around a change of voicing the block is played in two
    /// parts: the old voicing fading out, then — the harmonies silent — the new one fading in.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        var done = 0
        while done < frames {
            if settings.voicing != heardVoicing, voicingGate <= 0 {
                heardVoicing = settings.voicing
                retarget()
            }
            let fading = settings.voicing != heardVoicing
            var count = frames - done
            if fading {
                count = Swift.min(count, Swift.max(1, Int((voicingGate / gateStep).rounded(.up))))
            }
            sing(left: left + done, right: right + done, frames: count, fadingOut: fading)
            done += count
        }
    }

    /// The voices of `heardVoicing` over `frames` samples, the harmonies moving toward silence
    /// while `fadingOut`, else toward full.
    private func sing(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int,
                      fadingOut: Bool) {
        let s = settings
        let voicingTarget: Float = fadingOut ? 0 : 1
        let side = Float(s.spread)
        // Linear balance: the middle voice is at unity on both sides.
        let secondGains = (Swift.min(1, 1 + side), Swift.min(1, 1 - side))
        let thirdGains = (Swift.min(1, 1 - side), Swift.min(1, 1 + side))
        let levelTarget = Float(s.level)
        var level = levelNow
        let patience = Int(Self.isonPause * sampleRate) / tracker.hop + 1
        switch heardVoicing {
        case .free:
            if let interval = s.first { freeIntervals.0 = interval }
            if let interval = s.second { freeIntervals.1 = interval }
            if let interval = s.third { freeIntervals.2 = interval }
            let ratios = (Foundation.pow(2, freeIntervals.0 / 12), Foundation.pow(2, freeIntervals.1 / 12),
                          Foundation.pow(2, freeIntervals.2 / 12))
            let targets = Self.gates(s)
            for i in 0..<frames {
                let inLeft = left[i].isFinite ? left[i] : 0
                let inRight = right[i].isFinite ? right[i] : 0
                tracker.push(0.5 * (inLeft + inRight))
                history.push(inLeft, inRight)
                level = Compressor.glided(level, toward: levelTarget, by: levelGlide)
                voicingGate = Self.moved(voicingGate, toward: voicingTarget, by: gateStep)
                freeGates.0 = Self.moved(freeGates.0, toward: targets.0, by: gateStep)
                freeGates.1 = Self.moved(freeGates.1, toward: targets.1, by: gateStep)
                freeGates.2 = Self.moved(freeGates.2, toward: targets.2, by: gateStep)
                let period = tracker.period
                var wetLeft: Float = 0
                var wetRight: Float = 0
                if freeGates.0 > 0 {
                    heads.0.advance(ratio: ratios.0, period: period)
                    let voice = heads.0.read(history)
                    wetLeft += voice.0 * freeGates.0
                    wetRight += voice.1 * freeGates.0
                }
                if freeGates.1 > 0 {
                    heads.1.advance(ratio: ratios.1, period: period)
                    let voice = heads.1.read(history)
                    wetLeft += voice.0 * secondGains.0 * freeGates.1
                    wetRight += voice.1 * secondGains.1 * freeGates.1
                }
                if freeGates.2 > 0 {
                    heads.2.advance(ratio: ratios.2, period: period)
                    let voice = heads.2.read(history)
                    wetLeft += voice.0 * thirdGains.0 * freeGates.2
                    wetRight += voice.1 * thirdGains.1 * freeGates.2
                }
                let gain = level * voicingGate
                guard write(left, right, i, inLeft + wetLeft * gain, inRight + wetRight * gain) else {
                    level = levelNow
                    continue
                }
            }
        case let .following(leftTable, rightTable, reference):
            for i in 0..<frames {
                let inLeft = left[i].isFinite ? left[i] : 0
                let inRight = right[i].isFinite ? right[i] : 0
                if tracker.push(0.5 * (inLeft + inRight)), let lane = heardClass(reference: reference) {
                    leftTarget = Double(leftTable[lane])
                    rightTarget = Double(rightTable[lane])
                }
                history.push(inLeft, inRight)
                level = Compressor.glided(level, toward: levelTarget, by: levelGlide)
                voicingGate = Self.moved(voicingGate, toward: voicingTarget, by: gateStep)
                leftNow = leftTarget + (leftNow - leftTarget) * intervalPole
                rightNow = rightTarget + (rightNow - rightTarget) * intervalPole
                let period = tracker.period
                heads.1.advance(ratio: Foundation.pow(2, leftNow / 12), period: period)
                heads.2.advance(ratio: Foundation.pow(2, rightNow / 12), period: period)
                let one = heads.1.read(history), two = heads.2.read(history)
                let wetLeft = one.0 * secondGains.0 + two.0 * thirdGains.0
                let wetRight = one.1 * secondGains.1 + two.1 * thirdGains.1
                let gain = level * voicingGate
                guard write(left, right, i, inLeft + wetLeft * gain, inRight + wetRight * gain) else {
                    level = levelNow
                    continue
                }
            }
        case let .ison(root, reference):
            for i in 0..<frames {
                let inLeft = left[i].isFinite ? left[i] : 0
                let inRight = right[i].isFinite ? right[i] : 0
                if tracker.push(0.5 * (inLeft + inRight)) { holdIson(root: root, reference: reference, patience: patience) }
                history.push(inLeft, inRight)
                level = Compressor.glided(level, toward: levelTarget, by: levelGlide)
                voicingGate = Self.moved(voicingGate, toward: voicingTarget, by: gateStep)
                isonNow = isonTarget + (isonNow - isonTarget) * isonPole
                isonGate = (isonNote == nil ? 0 : 1) + (isonGate - (isonNote == nil ? 0 : 1)) * gatePole
                heads.0.advance(ratio: Foundation.pow(2, isonNow / 12), period: tracker.period)
                let voice = heads.0.read(history)
                let gain = level * isonGate * voicingGate
                guard write(left, right, i, inLeft + voice.0 * gain, inRight + voice.1 * gain) else {
                    level = levelNow
                    continue
                }
            }
        }
        levelNow = level
    }

    /// Writes one output pair; a pair that is not finite resets the harmonizer and writes silence.
    @inline(__always)
    private func write(_ left: UnsafeMutablePointer<Float>, _ right: UnsafeMutablePointer<Float>, _ i: Int,
                       _ outLeft: Float, _ outRight: Float) -> Bool {
        guard outLeft.isFinite, outRight.isFinite else {
            reset()
            left[i] = 0
            right[i] = 0
            return false
        }
        left[i] = outLeft
        right[i] = outRight
        return true
    }

    /// After an analysis: the pitch class the voice sings, with hysteresis, for the side voices;
    /// nil while there is no pitch.
    @inline(__always)
    private func heardClass(reference: Double) -> Int? {
        guard let note = sungNote(reference: reference) else { return nil }
        if let held = heldNote, Swift.abs(note - Double(held)) <= 0.5 + Self.hysteresis {
            return ((held % 12) + 12) % 12
        }
        let nearest = Int(note.rounded())
        heldNote = nearest
        return ((nearest % 12) + 12) % 12
    }

    /// After an analysis: the ison's octave and the shift that puts the sung note on it.
    @inline(__always)
    private func holdIson(root: Int, reference: Double, patience: Int) {
        guard let note = sungNote(reference: reference) else {
            if silentAnalyses >= patience { isonNote = nil }
            return
        }
        if let held = isonNote, note >= held - 7, note <= held + 19 {
            isonTarget = Swift.min(Swift.max(held - note, -24), 24)
            return
        }
        // The root at or below the sung note (a hair above counts as on it), entered without a glide.
        let rootBelow = Double(root) + 12 * ((note + 0.5 - Double(root)) / 12).rounded(.down)
        isonNote = rootBelow
        isonTarget = Swift.min(Swift.max(rootBelow - note, -24), 24)
        isonNow = isonTarget
    }

    /// The sung note as a fractional MIDI number, or nil while there is no pitch.
    @inline(__always)
    private func sungNote(reference: Double) -> Double? {
        guard tracker.period > 0 else {
            silentAnalyses += 1
            return nil
        }
        silentAnalyses = 0
        let note = 69 + 12 * Foundation.log2(tracker.frequency / reference)
        return note.isFinite ? note : nil
    }

    /// Which free voices are on: 1 for a voice with an interval, 0 for one without.
    private static func gates(_ settings: Settings) -> (Float, Float, Float) {
        (settings.first == nil ? 0 : 1, settings.second == nil ? 0 : 1, settings.third == nil ? 0 : 1)
    }

    /// A gate one `step` closer to its `target`, never past it.
    @inline(__always)
    private static func moved(_ gate: Float, toward target: Float, by step: Float) -> Float {
        gate < target ? Swift.min(target, gate + step) : Swift.max(target, gate - step)
    }
}
