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

/// A tone system: ascending pitches in cents within one repeating period (1200 = an octave).
/// Ported from the earlier app's `TuningSystem` without its pitch-correction half.
///
/// HONESTY: the world tunings are REPRESENTATIVE. Maqām, gamelan and Japanese tunings vary by
/// region, ensemble and instrument; there is no single canonical table. The values follow widely
/// cited theory and are approximations. No claim of any kind is attached to any tuning.
public struct TuningSystem: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    /// Ascending cent offsets within one period; the first is 0.
    public let degreesCents: [Double]
    public let periodCents: Double

    public init(id: String, name: String, degreesCents: [Double], periodCents: Double = 1200) {
        self.id = id
        self.name = name
        self.degreesCents = degreesCents
        self.periodCents = periodCents
    }

    static func equal(_ steps: Int, id: String, name: String) -> TuningSystem {
        TuningSystem(id: id, name: name, degreesCents: (0..<steps).map { Double($0) * 1200 / Double(steps) })
    }

    public static let equalTemperament = equal(12, id: "edo12", name: "12 equal (standard)")

    /// Twelve equal steps first: the safe default.
    public static let library: [TuningSystem] = [
        equalTemperament,
        equal(24, id: "edo24", name: "24 equal (quarter tones)"),
        equal(19, id: "edo19", name: "19 equal"),
        equal(31, id: "edo31", name: "31 equal"),
        TuningSystem(id: "just-major", name: "Just intonation, major",
                     degreesCents: [0, 203.910, 386.314, 498.045, 701.955, 884.359, 1088.269]),
        TuningSystem(id: "just-minor", name: "Just intonation, minor",
                     degreesCents: [0, 203.910, 315.641, 498.045, 701.955, 813.686, 1017.596]),
        TuningSystem(id: "pythagorean", name: "Pythagorean",
                     degreesCents: [0, 203.910, 407.820, 498.045, 701.955, 905.865, 1109.775]),
        TuningSystem(id: "meantone-quarter", name: "Quarter-comma meantone",
                     degreesCents: [0, 76.0, 193.2, 310.3, 386.3, 503.4, 579.5, 696.6, 772.6, 889.7, 1006.8, 1082.9]),
        TuningSystem(id: "maqam-rast", name: "Maqām Rāst (24-equal theory)",
                     degreesCents: [0, 200, 350, 500, 700, 900, 1050]),
        TuningSystem(id: "maqam-bayati", name: "Maqām Bayātī (24-equal theory)",
                     degreesCents: [0, 150, 300, 500, 700, 800, 1000]),
        TuningSystem(id: "maqam-hijaz", name: "Maqām Ḥijāz", degreesCents: [0, 100, 400, 500, 700, 800, 1000]),
        TuningSystem(id: "gamelan-slendro", name: "Gamelan sléndro (about 5 equal)", degreesCents: [0, 240, 480, 720, 960]),
        TuningSystem(id: "gamelan-pelog", name: "Gamelan pélog (representative)",
                     degreesCents: [0, 120, 270, 540, 670, 785, 950]),
        TuningSystem(id: "hirajoshi", name: "Hirajōshi", degreesCents: [0, 200, 300, 700, 800]),
        TuningSystem(id: "bohlen-pierce", name: "Bohlen–Pierce (non-octave)",
                     degreesCents: (0..<13).map { Double($0) * 1901.955 / 13 }, periodCents: 1901.955),
    ]

    /// The system with `id`, or twelve equal steps.
    public static func named(_ id: String) -> TuningSystem {
        library.first { $0.id == id } ?? equalTemperament
    }

    /// The cents from twelve equal steps of the system degree nearest a note `semitones` above
    /// the root. Zero for twelve equal steps, and for a system that does not repeat at the
    /// octave, which has no twelve-note retuning.
    func centsDeviation(forSemitone semitones: Int) -> Double {
        guard abs(periodCents - 1200) < 1, !degreesCents.isEmpty else { return 0 }
        let target = Double(((semitones % 12) + 12) % 12) * 100
        var best = 0.0
        var bestDelta = Double.greatestFiniteMagnitude
        for cents in degreesCents where abs(cents - target) < bestDelta {
            bestDelta = abs(cents - target)
            best = cents
        }
        return best - target
    }

    /// The deviation of each absolute pitch class (0 = C … 11 = B) with the system's 1/1 on `root`.
    func pitchClassCents(root: Int) -> [Double] {
        (0..<12).map { centsDeviation(forSemitone: $0 - root) }
    }
}
