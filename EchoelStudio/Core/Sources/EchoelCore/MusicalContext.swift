import Foundation

/// The musical frame of a song, set by the musician and by nothing else: key, scale, tone system,
/// concert pitch and swing. It replaces the genres of the earlier app, which decided tempo,
/// harmony, rhythm and sound all at once and boxed the music in (`docs/dev/NEUPLANUNG_2026-10-18.md`
/// §1). Nothing here writes a note. The scale helps the hands — a keyboard or pads can stay in
/// it — and the tone system retunes what is played; every field is a parameter like any other,
/// reachable from MIDI Learn and the agent.
///
/// The default frames nothing: C, chromatic, twelve equal steps at A = 440 Hz, straight time.
public struct MusicalContext: Codable, Equatable, Sendable {
    /// The tonic as a pitch class, 0 = C … 11 = B.
    public var root: Int
    /// A scale this build does not know reads as `.chromatic` (it frames nothing) and is kept
    /// under its own name until the musician picks another, so a later build still finds it.
    public var scale: Scale {
        get { Scale(rawValue: scaleName) ?? .chromatic }
        set { scaleName = newValue.rawValue }
    }
    /// The stored name of a scale this build does not know, if that is what the song holds.
    public var unrecognizedScale: String? { Scale(rawValue: scaleName) == nil ? scaleName : nil }
    private var scaleName: String
    /// A `TuningSystem.id`. An id this build does not know is kept and plays as twelve equal steps.
    public var tuning: String
    /// The A above middle C, in hertz.
    public var concertPitch: Double
    /// How late every second sixteenth note falls: 0 straight, 1 a full triplet feel (2 : 1).
    public var swing: Double

    private enum CodingKeys: String, CodingKey {
        case root, scaleName = "scale", tuning, concertPitch, swing
    }

    public init(root: Int = 0, scale: Scale = .chromatic, tuning: String = TuningSystem.equalTemperament.id,
                concertPitch: Double = 440, swing: Double = 0) {
        self.root = root
        self.scaleName = scale.rawValue
        self.tuning = tuning
        self.concertPitch = concertPitch
        self.swing = swing
    }

    public static let rootRange = 0...11
    public static let concertPitchRange: ClosedRange<Double> = 400...480
    public static let swingRange: ClosedRange<Double> = 0...1

    /// Concert pitches a musician can pick by name; a song stores only the number.
    public static let concertPitchPresets: [ConcertPitchPreset] = [
        ConcertPitchPreset("Standard 440 (ISO 16)", hertz: 440),
        ConcertPitchPreset("Orchestra 442", hertz: 442),
        ConcertPitchPreset("Baroque 415", hertz: 415),
        ConcertPitchPreset("Classical 430", hertz: 430),
        ConcertPitchPreset("Diapason normal 435 (1859)", hertz: 435),
        ConcertPitchPreset("Venetian 466", hertz: 466),
    ]
    public static let rootNames = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]

    /// The frame as the musician reads it: "D Dorian". Chromatic has no key to name and reads
    /// "Chromatic", and so does a scale this build does not know, which frames nothing either.
    public var title: String {
        guard scale != .chromatic, Self.rootNames.indices.contains(root) else { return Scale.chromatic.title }
        return "\(Self.rootNames[root]) \(scale.title)"
    }

    /// Whether a MIDI pitch belongs to the key and scale.
    public func contains(_ pitch: Int) -> Bool {
        let degree = ((pitch - root) % 12 + 12) % 12
        return scale.intervals.contains(degree)
    }

    /// What the key of `pitch` wears on a keyboard drawn on the screen. A chromatic song — and a
    /// scale this build does not know, which reads as chromatic — frames nothing, so no key is
    /// marked: a mark on every key would say nothing. A pitch outside MIDI's range wears none.
    public func keyMark(of pitch: Int) -> KeyMark {
        guard scale != .chromatic, (0...127).contains(pitch) else { return .unmarked }
        let degree = ((pitch - root) % 12 + 12) % 12
        if degree == 0 { return .root }
        return scale.intervals.contains(degree) ? .scaleTone : .unmarked
    }

    /// The nearest pitch in the key and scale; on a tie, the lower one. Stays within 0…127.
    public func nearest(_ pitch: Int) -> Int {
        let clamped = Swift.min(Swift.max(pitch, 0), 127)
        for distance in 0...6 {
            for candidate in [clamped - distance, clamped + distance] where (0...127).contains(candidate) {
                if contains(candidate) { return candidate }
            }
        }
        return clamped
    }

    /// How far each absolute pitch class (0 = C … 11 = B) sits from twelve equal steps in the
    /// song's tone system, in cents, measured from the key's root; plus the shift of concert
    /// pitch from 440 Hz. Twelve equal steps at 440 Hz is zero everywhere.
    public func centsTable() -> [Double] {
        let system = TuningSystem.named(tuning)
        let pitchShift = 1200 * Foundation.log2(concertPitch / 440)
        return system.pitchClassCents(root: root).map { $0 + pitchShift }
    }

    var isValid: Bool {
        Self.rootRange.contains(root) && concertPitch.isFinite && Self.concertPitchRange.contains(concertPitch)
            && swing.isFinite && Self.swingRange.contains(swing)
    }
}

/// A scale as the semitone steps above its root. Stored by name in the song; never rename a case.
/// What a key on the screen shows of the song's key: its root, another tone of its scale, or
/// nothing. Shown, never enforced — the key lock is a switch of its own (`LiveKeys`).
public enum KeyMark: Equatable, Sendable {
    case root
    case scaleTone
    case unmarked
}

public enum Scale: String, Codable, CaseIterable, Sendable {
    case chromatic, major, minor, dorian, phrygian, lydian, mixolydian, locrian
    case harmonicMinor, melodicMinor, majorPentatonic, minorPentatonic, blues, wholeTone

    public var intervals: Set<Int> {
        switch self {
        case .chromatic: Set(0...11)
        case .major: [0, 2, 4, 5, 7, 9, 11]
        case .minor: [0, 2, 3, 5, 7, 8, 10]
        case .dorian: [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: [0, 1, 3, 5, 7, 8, 10]
        case .lydian: [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: [0, 2, 4, 5, 7, 9, 10]
        case .locrian: [0, 1, 3, 5, 6, 8, 10]
        case .harmonicMinor: [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor: [0, 2, 3, 5, 7, 9, 11]
        case .majorPentatonic: [0, 2, 4, 7, 9]
        case .minorPentatonic: [0, 3, 5, 7, 10]
        case .blues: [0, 3, 5, 6, 7, 10]
        case .wholeTone: [0, 2, 4, 6, 8, 10]
        }
    }

    public var title: String {
        switch self {
        case .chromatic: "Chromatic"
        case .major: "Major"
        case .minor: "Minor"
        case .dorian: "Dorian"
        case .phrygian: "Phrygian"
        case .lydian: "Lydian"
        case .mixolydian: "Mixolydian"
        case .locrian: "Locrian"
        case .harmonicMinor: "Harmonic Minor"
        case .melodicMinor: "Melodic Minor"
        case .majorPentatonic: "Major Pentatonic"
        case .minorPentatonic: "Minor Pentatonic"
        case .blues: "Blues"
        case .wholeTone: "Whole Tone"
        }
    }
}

/// A named concert pitch: the historical and orchestral standards. Pitches derived from planetary
/// orbits stood here until 2026-11-06 and are gone from the menu (decision 2026-11-06, language law: no
/// esoteric framing); a song that stores one keeps its number and sounds as before, because a song
/// stores only the hertz.
public struct ConcertPitchPreset: Equatable, Sendable {
    public let title: String
    public let hertz: Double

    public init(_ title: String, hertz: Double) {
        self.title = title
        self.hertz = hertz
    }
}

/// A tone system: ascending pitches in cents within one repeating period (1200 = an octave), worked
/// out once from what the system is — pure ratios, an equal division, a chain of tempered fifths or
/// a published table (`Definition`) — so that no table is a hand-rounded copy of its definition
/// (TH-2, 2026-11-27). Ported from the earlier app's `TuningSystem` without its pitch-correction
/// half.
///
/// The twelve keys of an octave play it: each key plays the degree nearest it, the 1/1 an octave up
/// among them (`centsDeviation`). A system of five or seven degrees therefore gives several keys the
/// same pitch, and one of more than twelve plays only twelve of its steps (`reachesEveryStep`).
///
/// HONESTY: the world tunings are REPRESENTATIVE. Maqām, gamelan and Japanese tunings vary by
/// region, ensemble and instrument; there is no single canonical table. The values follow widely
/// cited theory and are approximations. No claim of any kind is attached to any tuning.
public struct TuningSystem: Equatable, Sendable, Identifiable {
    /// What a tone system is. Its degrees are worked out from this once, in `Double` arithmetic, so
    /// one that a `Double` cannot hold comes out rounded, by far less than the billionth of a cent
    /// the tests allow (under a trillionth, measured on Linux); the octave is 1200 exactly.
    public enum Definition: Equatable, Sendable {
        /// `steps` equal steps of the frequency ratio `period` — 2 is the octave, 3 the tritave of
        /// Bohlen–Pierce: step k lies k/steps of the way up.
        case equal(steps: Int, period: Rational)
        /// Pure frequency ratios above the 1/1 within the octave, ascending from 1/1.
        case ratios([Rational])
        /// A chain of equal fifths, from `below` fifths under the 1/1 to `above` fifths over it, each
        /// brought into the octave. The fifth is the ratio `base` raised to `exponent`: quarter-comma
        /// meantone's is 5 to the 1/4, so four fifths make two octaves and a pure 5/4.
        case fifths(base: Rational, exponent: Rational, below: Int, above: Int)
        /// Cents as a source gives them, ascending from 0: a representative table, or theory written
        /// in cents.
        case cents([Double], period: Double)
    }

    public let id: String
    public let name: String
    /// What the system is; the degrees and the period are worked out from it.
    public let definition: Definition
    /// Ascending cent offsets within one period; the first is 0.
    public let degreesCents: [Double]
    public let periodCents: Double

    public init(id: String, name: String, definition: Definition) {
        self.id = id
        self.name = name
        self.definition = definition
        let derived = Self.degreesAndPeriod(of: definition)
        degreesCents = derived.degrees
        periodCents = derived.period
    }

    /// A system given as cents, such as a published table.
    public init(id: String, name: String, degreesCents: [Double], periodCents: Double = 1200) {
        self.init(id: id, name: name, definition: .cents(degreesCents, period: periodCents))
    }

    static func equal(_ steps: Int, id: String, name: String) -> TuningSystem {
        TuningSystem(id: id, name: name, definition: .equal(steps: steps, period: 2))
    }

    public static let equalTemperament = equal(12, id: "edo12", name: "12 equal (standard)")

    /// Twelve equal steps first: the safe default.
    public static let library: [TuningSystem] = [
        equalTemperament,
        equal(24, id: "edo24", name: "24 equal (quarter tones)"),
        equal(19, id: "edo19", name: "19 equal"),
        equal(31, id: "edo31", name: "31 equal"),
        TuningSystem(id: "just-major", name: "Just intonation, major",
                     definition: .ratios([1, .constant(9, 8), .constant(5, 4), .constant(4, 3), .constant(3, 2),
                                          .constant(5, 3), .constant(15, 8)])),
        TuningSystem(id: "just-minor", name: "Just intonation, minor",
                     definition: .ratios([1, .constant(9, 8), .constant(6, 5), .constant(4, 3), .constant(3, 2),
                                          .constant(8, 5), .constant(9, 5)])),
        TuningSystem(id: "pythagorean", name: "Pythagorean",
                     definition: .ratios([1, .constant(9, 8), .constant(81, 64), .constant(4, 3), .constant(3, 2),
                                          .constant(27, 16), .constant(243, 128)])),
        // Fifths a quarter of the syntonic comma (81/80) narrower than 3/2, from E♭ to G♯.
        TuningSystem(id: "meantone-quarter", name: "Quarter-comma meantone",
                     definition: .fifths(base: 5, exponent: .constant(1, 4), below: 3, above: 8)),
        TuningSystem(id: "maqam-rast", name: "Maqām Rāst (24-equal theory)",
                     degreesCents: [0, 200, 350, 500, 700, 900, 1050]),
        TuningSystem(id: "maqam-bayati", name: "Maqām Bayātī (24-equal theory)",
                     degreesCents: [0, 150, 300, 500, 700, 800, 1000]),
        TuningSystem(id: "maqam-hijaz", name: "Maqām Ḥijāz", degreesCents: [0, 100, 400, 500, 700, 800, 1000]),
        TuningSystem(id: "gamelan-slendro", name: "Gamelan sléndro (about 5 equal)",
                     definition: .equal(steps: 5, period: 2)),
        TuningSystem(id: "gamelan-pelog", name: "Gamelan pélog (representative)",
                     degreesCents: [0, 120, 270, 540, 670, 785, 950]),
        TuningSystem(id: "hirajoshi", name: "Hirajōshi", degreesCents: [0, 200, 300, 700, 800]),
        TuningSystem(id: "bohlen-pierce", name: "Bohlen–Pierce (non-octave)",
                     definition: .equal(steps: 13, period: 3)),
        // Ancient Greek: two tetrachords a 9/8 tone apart, as Archytas (28/27 · 8/7 · 9/8) and
        // Ptolemy's intense diatonic (16/15 · 9/8 · 10/9) give them; the ratios are documented.
        TuningSystem(id: "archytas-diatonic", name: "Archytas diatonic (ancient Greek)",
                     definition: .ratios([1, .constant(28, 27), .constant(32, 27), .constant(4, 3), .constant(3, 2),
                                          .constant(14, 9), .constant(16, 9)])),
        TuningSystem(id: "ptolemy-intense-diatonic", name: "Ptolemy intense diatonic (ancient Greek)",
                     definition: .ratios([1, .constant(16, 15), .constant(6, 5), .constant(4, 3), .constant(3, 2),
                                          .constant(8, 5), .constant(9, 5)])),
    ]

    /// The system with `id`, or twelve equal steps.
    public static func named(_ id: String) -> TuningSystem {
        library.first { $0.id == id } ?? equalTemperament
    }

    /// Two values in cents closer than this are the same: a key's distances to two degrees (a tie,
    /// which the lower degree wins), or a deviation and zero. A key can sit exactly midway between
    /// two degrees — the F♯ key between 4/3 and 3/2, which together make the octave — and worked out
    /// from the ratios its two distances then differ only in the last bit of a logarithm, which must
    /// not choose the note, nor choose it differently on another platform. A billionth of a cent is
    /// far below any difference anyone hears and far above that rounding.
    static let sameCents = 1e-9

    /// Whether the period is the octave, within a cent: only such a system retunes the twelve keys.
    var repeatsAtTheOctave: Bool { Swift.abs(periodCents - 1200) < 1 }

    /// How many of its steps the twelve keys of an octave play, each key the degree nearest it. Every
    /// system of the library with up to twelve degrees has all of them on keys, 19, 24 and 31 equal
    /// have twelve, and a system that does not repeat at the octave has none: the keys play twelve
    /// equal steps instead (Bohlen–Pierce).
    public var stepsTheKeysReach: Int {
        guard repeatsAtTheOctave, !degreesCents.isEmpty else { return 0 }
        var reached = Set<Int>()
        for key in 0..<12 { reached.insert(nearestDegree(to: Self.keyCents(key)).index) }
        return reached.count
    }

    /// Whether the twelve keys reach every step of the system. False for 19, 24 and 31 equal, which
    /// have more steps than an octave has keys, and for Bohlen–Pierce, which does not repeat at the
    /// octave: such a system needs a key for each of its steps, which the keyboard does not have yet,
    /// and the picker can say what the keys play instead.
    public var reachesEveryStep: Bool {
        let reached = stepsTheKeysReach
        return reached > 0 && reached == degreesCents.count
    }

    /// Whether the twelve keys play exactly twelve equal steps in this system, from any root: twelve
    /// equal itself; 24 equal, whose steps nearest the keys are the semitones, so no quarter tone
    /// sounds; and a system that does not repeat at the octave, which retunes nothing.
    public var playsAsTwelveEqual: Bool {
        (0..<12).allSatisfy { (key: Int) -> Bool in
            Swift.abs(centsDeviation(forSemitone: key)) <= Self.sameCents
        }
    }

    /// The cents from twelve equal steps of the system degree nearest a note `semitones` above the
    /// root, the 1/1 an octave up among them: a key near the octave plays the tonic above when that
    /// is nearer than the highest degree (TH-1, 2026-11-27; until then the B key fell to the highest
    /// degree, 140 cents down in sléndro and 300 in Hirajōshi). On a tie the lower degree. Zero for
    /// twelve equal steps, and for a system that does not repeat at the octave, which has no
    /// twelve-note retuning.
    func centsDeviation(forSemitone semitones: Int) -> Double {
        guard repeatsAtTheOctave, !degreesCents.isEmpty else { return 0 }
        let target = Self.keyCents(semitones)
        return nearestDegree(to: target).cents - target
    }

    /// The deviation of each absolute pitch class (0 = C … 11 = B) with the system's 1/1 on `root`.
    func pitchClassCents(root: Int) -> [Double] {
        (0..<12).map { centsDeviation(forSemitone: $0 - root) }
    }

    /// The degree nearest `target` cents above the 1/1: its index (0 also for the 1/1 above) and
    /// its cents (the period for the 1/1 above). Degrees are tried from the bottom up, and a later
    /// one wins only when it is nearer by more than `sameCents`, so a tie goes to the lower.
    private func nearestDegree(to target: Double) -> (index: Int, cents: Double) {
        var best = (index: 0, cents: 0.0)
        var bestDistance = Double.infinity
        for (index, degree) in degreesCents.enumerated() {
            let distance = Swift.abs(degree - target)
            guard distance < bestDistance - Self.sameCents else { continue }
            best = (index, degree)
            bestDistance = distance
        }
        if Swift.abs(periodCents - target) < bestDistance - Self.sameCents { best = (0, periodCents) }
        return best
    }

    /// A key `semitones` above the root, in cents within the octave: 0, 100 … 1100.
    private static func keyCents(_ semitones: Int) -> Double {
        Double(((semitones % 12) + 12) % 12) * 100
    }

    /// The size of a frequency ratio in cents, 1200 · log2 of it. The octave is 1200 exactly,
    /// whatever the platform's logarithm rounds.
    static func cents(of ratio: Rational) -> Double {
        ratio == 2 ? 1200 : 1200 * Foundation.log2(ratio.doubleValue)
    }

    /// The degrees and the period a definition describes.
    static func degreesAndPeriod(of definition: Definition) -> (degrees: [Double], period: Double) {
        switch definition {
        case .equal(let steps, let period):
            let span = cents(of: period)
            let degrees = (0..<Swift.max(steps, 0)).map { (step: Int) -> Double in
                Double(step) * span / Double(steps)
            }
            return (degrees, span)
        case .ratios(let ratios):
            return (ratios.map(cents(of:)), 1200)
        case .fifths(let base, let exponent, let below, let above):
            let fifth = cents(of: base) * exponent.doubleValue
            let chain = stride(from: -below, through: above, by: 1).map { (count: Int) -> Double in
                let raised = Double(count) * fifth
                return raised - 1200 * (raised / 1200).rounded(.down)
            }
            return (chain.sorted(), 1200)
        case .cents(let degrees, let period):
            return (degrees, period)
        }
    }
}
