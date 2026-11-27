import Foundation

/// How a reader writes notes (TH-3, TH-3b, 2026-11-27): a choice of the reader's device, never of
/// the song — the theory and tuning audits both put it there — so two people open the same song in
/// their own names. Display only: a song stores pitch classes and MIDI numbers, and a file name or
/// a MIDI file never consults this.
///
/// Fixed namings name the pitch, as the key writes it (`KeySpelling`): English, German, fixed do.
/// Movable namings name the step of the key: sargam (Sa on the song's root, the earlier app had it
/// fixed on C), movable do and jianpu numbers; for these a minor key can count from its own tonic or
/// la-based from its relative major (`MinorTonic`). Carnatic svaras (whose names depend on the
/// scale), Japanese and Korean letters are not here yet.
///
/// The RAW VALUES ARE STORED: the app keeps the reader's choice by its raw value, and the first
/// four are the earlier app's (`music.noteNaming`), so a reader who chose German there keeps H.
/// Never rename a case; a new naming goes at the end (`StoredNamesTests`).
public enum NoteNaming: String, CaseIterable, Sendable {
    /// C D E F G A B with ♯ and ♭, the international default.
    case english
    /// C D E F G A H, B♭ called B, the accidentals written -is and -es: Fis, Es, As. German- and
    /// Central-European practice, in full; the earlier app kept C♯ and E♭ beside its B and H.
    case german
    /// Do Re Mi Fa Sol La Si, fixed do: the syllable names the pitch, so the seventh is Si and never
    /// the movable Ti. Romance-language and much of East Asian practice.
    case solfege
    /// Sa Re Ga Ma Pa Dha Ni, Hindustani sargam, on the song's root: komal (lowered) Re, Ga, Dha
    /// and Ni carry ♭, tivra (raised) Ma carries ♯ — marks that stay visible at a glance and in
    /// capitals, where the printed convention marks them by letter case. A step of the raga, never
    /// a spelling, so a sharp key and a flat key read alike. Sa and Pa never carry a mark.
    case sargam
    /// do re mi fa so la ti, movable do: the steps of the key, raised di ri fi si li, lowered ra me
    /// se le te.
    case movableDo
    /// 1 2 3 4 5 6 7, jianpu: the steps of the key, the accidental before the number (♯4, ♭7), an
    /// octave up a dot above and down a dot below.
    case numbered

    /// The reader's choice as stored; anything this build does not know reads as English, so a
    /// value from a later build still names every note.
    public init(stored raw: String?) {
        self = raw.flatMap(NoteNaming.init(rawValue:)) ?? .english
    }

    /// What the reader picks from; each shows its first names, so the choice is legible without
    /// knowing the word. Never "solfeggio": that word belongs to frequency claims the language law
    /// bans.
    public var title: String {
        switch self {
        case .english: "C D E (English)"
        case .german: "C D E … H (German)"
        case .solfege: "Do Re Mi (fixed do)"
        case .sargam: "Sa Re Ga (sargam)"
        case .movableDo: "do re mi (movable do)"
        case .numbered: "1 2 3 (jianpu)"
        }
    }

    /// Whether the names count the steps of the key rather than name the pitch.
    public var isMovable: Bool {
        switch self {
        case .english, .german, .solfege: false
        case .sargam, .movableDo, .numbered: true
        }
    }

    // MARK: Names

    /// The name of `pitchClass` (any whole number) in `key`.
    public func name(of pitchClass: Int, in key: KeySpelling, minorTonic: MinorTonic = .doBased) -> String {
        switch self {
        case .english, .german, .solfege:
            return name(of: key.note(pitchClass))
        case .sargam:
            return Self.sargamNames[Self.interval(pitchClass, above: key.root)]
        case .movableDo, .numbered:
            return movableName(key.degree(of: pitchClass, minorTonic: minorTonic))
        }
    }

    /// The same, as VoiceOver says it: "F sharp", "komal Re", "sharp 4".
    public func spokenName(of pitchClass: Int, in key: KeySpelling, minorTonic: MinorTonic = .doBased) -> String {
        switch self {
        case .english, .german, .solfege:
            return spokenName(of: key.note(pitchClass))
        case .sargam:
            return Self.spokenSargamNames[Self.interval(pitchClass, above: key.root)]
        case .movableDo:
            return movableName(key.degree(of: pitchClass, minorTonic: minorTonic))
        case .numbered:
            let degree = key.degree(of: pitchClass, minorTonic: minorTonic)
            return Self.spokenMarks(degree.alteration, before: true) + "\(degree.step + 1)"
        }
    }

    /// A MIDI pitch by name and octave. A fixed name carries the octave of its letter, as
    /// scientific pitch notation counts it (middle C is C4; in C♯ harmonic minor it is B♯3). A
    /// movable name is marked by octaves from the one that starts on its tonic written in octave
    /// 4 (D4 for 1=D): a dot above per octave up, a dot below per octave down.
    public func name(ofPitch pitch: Int, in key: KeySpelling, minorTonic: MinorTonic = .doBased) -> String {
        if !isMovable { return name(ofPitch: pitch, writtenAs: key.note(pitch)) }
        return Self.dotted(name(of: pitch, in: key, minorTonic: minorTonic),
                           octaves: movableOctave(of: pitch, in: key, minorTonic: minorTonic))
    }

    /// The same, as VoiceOver says it: "B sharp 3", "C minus 1", "Sa, 1 octave down".
    public func spokenName(ofPitch pitch: Int, in key: KeySpelling, minorTonic: MinorTonic = .doBased) -> String {
        let spoken = spokenName(of: pitch, in: key, minorTonic: minorTonic)
        if !isMovable {
            let octave = Self.octave(of: pitch, writtenAs: key.note(pitch))
            return spoken + (octave < 0 ? " minus \(-octave)" : " \(octave)")
        }
        let octaves = movableOctave(of: pitch, in: key, minorTonic: minorTonic)
        guard octaves != 0 else { return spoken }
        return spoken + ", \(Swift.abs(octaves)) octave\(Swift.abs(octaves) == 1 ? "" : "s") \(octaves > 0 ? "up" : "down")"
    }

    /// A MIDI pitch written as `note`, with the octave of its letter: "D♭4", "B♯3". A movable
    /// naming has no letters and writes English.
    public func name(ofPitch pitch: Int, writtenAs note: SpelledNote) -> String {
        name(of: note) + "\(Self.octave(of: pitch, writtenAs: note))"
    }

    /// A written note in this naming's letters; a movable naming has none and writes English.
    public func name(of note: SpelledNote) -> String {
        switch self {
        case .german: Self.germanName(note)
        case .solfege: Self.solfegeLetters[note.letter.rawValue] + Self.marks(note.accidental)
        case .english, .sargam, .movableDo, .numbered: Self.letters[note.letter.rawValue] + Self.marks(note.accidental)
        }
    }

    /// A written note as VoiceOver says it: "F sharp", "B double flat"; German names are words already.
    public func spokenName(of note: SpelledNote) -> String {
        switch self {
        case .german: Self.germanName(note)
        case .solfege: Self.solfegeLetters[note.letter.rawValue] + Self.spokenMarks(note.accidental, before: false)
        case .english, .sargam, .movableDo, .numbered:
            Self.letters[note.letter.rawValue] + Self.spokenMarks(note.accidental, before: false)
        }
    }

    // MARK: Tables

    static let letters = ["C", "D", "E", "F", "G", "A", "B"]
    private static let solfegeLetters = ["Do", "Re", "Mi", "Fa", "Sol", "La", "Si"]
    private static let germanLetters = ["C", "D", "E", "F", "G", "A", "H"]
    /// -es after a consonant, -s after a vowel, and B♭ is B.
    private static let germanFlats = ["Ces", "Des", "Es", "Fes", "Ges", "As", "B"]
    private static let germanDoubleFlats = ["Ceses", "Deses", "Eses", "Feses", "Geses", "Asas", "Heses"]
    /// The twelve steps above Sa.
    private static let sargamNames = ["Sa", "Re♭", "Re", "Ga♭", "Ga", "Ma", "Ma♯", "Pa", "Dha♭", "Dha", "Ni♭", "Ni"]
    private static let spokenSargamNames = ["Sa", "komal Re", "Re", "komal Ga", "Ga", "Ma", "tivra Ma", "Pa", "komal Dha",
                                            "Dha", "komal Ni", "Ni"]
    /// Movable do's syllables by interval above do: going up (raised) and coming down (lowered).
    private static let risingSyllables = ["do", "di", "re", "ri", "mi", "fa", "fi", "so", "si", "la", "li", "ti"]
    private static let fallingSyllables = ["do", "ra", "re", "me", "mi", "fa", "se", "so", "le", "la", "te", "ti"]

    /// ♯ or ♭ once per semitone: a double sharp is ♯♯ and a double flat ♭♭, two marks every font
    /// has, where the single signs 𝄪 and 𝄫 come from a block few fonts carry.
    static func marks(_ accidental: Int) -> String {
        accidental >= 0 ? String(repeating: "♯", count: accidental) : String(repeating: "♭", count: -accidental)
    }

    /// The marks in words, after a letter (" sharp") or before a number ("sharp ").
    static func spokenMarks(_ accidental: Int, before: Bool) -> String {
        let word: String
        switch accidental {
        case 0: return ""
        case 1: word = "sharp"
        case -1: word = "flat"
        case 2: word = "double sharp"
        case -2: word = "double flat"
        default: word = Array(repeating: accidental > 0 ? "sharp" : "flat", count: Swift.abs(accidental)).joined(separator: " ")
        }
        return before ? word + " " : " " + word
    }

    private static func germanName(_ note: SpelledNote) -> String {
        let index = note.letter.rawValue
        switch note.accidental {
        case 0: return germanLetters[index]
        case 1...: return germanLetters[index] + String(repeating: "is", count: note.accidental)
        case -1: return germanFlats[index]
        default: return germanDoubleFlats[index] + String(repeating: "es", count: -note.accidental - 2)
        }
    }

    /// Movable do's syllable or jianpu's number for a step of the key.
    private func movableName(_ degree: KeySpelling.Degree) -> String {
        guard self == .movableDo else { return Self.marks(degree.alteration) + "\(degree.step + 1)" }
        let interval = Self.interval(KeySpelling.majorSteps[degree.step] + degree.alteration, above: 0)
        return (degree.alteration >= 0 ? Self.risingSyllables : Self.fallingSyllables)[interval]
    }

    /// How many octaves a movable name lies above (+) or below (−) the octave that starts on its
    /// 1, do or Sa written in octave 4. A step with its marks always lies 0 … 11 semitones above
    /// that note (`KeySpelling.degree`), so the dots alone carry the octave and every name reads
    /// back to its pitch. Counted from the pitch's own octave, so no whole number overflows.
    private func movableOctave(of pitch: Int, in key: KeySpelling, minorTonic: MinorTonic) -> Int {
        let one = self == .sargam ? (key.tonic ?? SpelledNote.common[key.root]) : key.movableTonic(minorTonic)
        let start = 60 + one.letter.naturalPitchClass + one.accidental
        let offset: Int
        if self == .sargam {
            offset = Self.interval(pitch, above: one.pitchClass)
        } else {
            let degree = key.degree(of: pitch, minorTonic: minorTonic)
            offset = KeySpelling.majorSteps[degree.step] + degree.alteration
        }
        let withinOctave = ((pitch % 12) + 12) % 12
        return Self.floorDivision(pitch, by: 12) + Self.floorDivision(withinOctave - start - offset, by: 12)
    }

    /// The scientific octave of `pitch` written as `note`: the octave of the letter, so B♯3 is 60
    /// and C♭4 is 59. Counted from the pitch's own octave, so no whole number overflows.
    static func octave(of pitch: Int, writtenAs note: SpelledNote) -> Int {
        floorDivision(pitch, by: 12) - 1 - floorDivision(note.letter.naturalPitchClass + note.accidental, by: 12)
    }

    /// `name` with a dot above (U+0307) per octave up or below (U+0323) per octave down, on its
    /// first letter or digit — never more than ten, all MIDI's eleven octaves need.
    static func dotted(_ name: String, octaves: Int) -> String {
        guard octaves != 0 else { return name }
        let dots = String(repeating: octaves > 0 ? "\u{0307}" : "\u{0323}", count: Swift.min(Swift.abs(octaves), 10))
        guard let first = name.firstIndex(where: { $0.isLetter || $0.isNumber }) else { return name + dots }
        let after = name.index(after: first)
        return String(name[..<after]) + dots + String(name[after...])
    }

    /// `pitch` above `base` within the octave, 0 … 11, for any two whole numbers.
    private static func interval(_ pitch: Int, above base: Int) -> Int {
        ((((pitch % 12) - (base % 12)) % 12) + 12) % 12
    }

    private static func floorDivision(_ value: Int, by divisor: Int) -> Int {
        let quotient = value / divisor
        return value % divisor < 0 ? quotient - 1 : quotient
    }
}

/// How the movable names count a minor key (TH-3b): from its own tonic, as 1 and do (do-based), or
/// from its relative major, so its tonic is 6 and la (la-based) — the two readings jianpu and
/// movable do both have. A key of major tonality counts from its tonic either way; sargam's Sa is
/// always the tonic; Roman numerals always count from the tonic. A reader's choice, kept by raw value.
public enum MinorTonic: String, CaseIterable, Sendable {
    case doBased, laBased

    /// The reader's choice as stored; anything else is do-based.
    public init(stored raw: String?) {
        self = raw.flatMap(MinorTonic.init(rawValue:)) ?? .doBased
    }

    public var title: String {
        switch self {
        case .doBased: "Minor on 1 (do-based)"
        case .laBased: "Minor on 6 (la-based)"
        }
    }
}
