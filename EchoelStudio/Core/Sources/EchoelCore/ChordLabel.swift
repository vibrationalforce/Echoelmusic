import Foundation

/// How a chord is labelled (TH-3b, 2026-11-27): by its name in the reader's note names ("G♯m"),
/// or by the step of the key its root stands on — Roman numerals ("ii") or Nashville numbers
/// ("2m"). A reader's choice, kept by raw value; the chord row on the play screen always shows
/// names (`ChordRow`).
///
/// Both numbered styles count the steps against the major scale of the tonic, so a minor key's
/// third chord is ♭III and ♭3, and a borrowed chord says what it borrows: ♭VI, ♭VII, C minor's
/// Neapolitan ♭II. Roman numerals write a chord with a minor third and no major one in small
/// letters; Nashville numbers add the name's symbol (m, °, +) and can count a minor key from its
/// relative major (`MinorTonic`).
public enum ChordLabel: String, CaseIterable, Sendable {
    case name, roman, nashville

    /// The reader's choice as stored; anything else is names.
    public init(stored raw: String?) {
        self = raw.flatMap(ChordLabel.init(rawValue:)) ?? .name
    }

    public var title: String {
        switch self {
        case .name: "Names"
        case .roman: "Roman numerals"
        case .nashville: "Nashville numbers"
        }
    }
}

extension ChordSuggest.Chord {
    /// How the chord writes the tone `pitch` (any MIDI pitch of its pitch classes): A♭ in C
    /// major's ♭VI, never G♯. Nil for a pitch that is not one of its tones.
    public func spelledTone(_ pitch: Int) -> SpelledNote? {
        let wanted = ChordSuggest.pitchClass(pitch)
        return zip(pitchClasses, spelling).first { $0.0 == wanted }?.1
    }

    /// The chord's name in `naming`: "Gism" in German, "Sol♯m" in fixed do. A movable naming names
    /// steps, not chords, so its chords keep their letters, as jianpu song books print them;
    /// `label(.roman …)` gives them as steps. A stack without a name lists its tones: "C-E-A".
    public func name(_ naming: NoteNaming) -> String {
        let letters = naming.isMovable ? NoteNaming.english : naming
        guard let first = spelling.first else { return "" }
        guard let quality else { return spelling.map { letters.name(of: $0) }.joined(separator: "-") }
        return letters.name(of: first) + quality.symbol
    }

    /// The same as VoiceOver says it: "G sharp minor", "Gis minor"; another stack "C, E, A".
    public func spokenName(_ naming: NoteNaming) -> String {
        let letters = naming.isMovable ? NoteNaming.english : naming
        guard let first = spelling.first else { return "" }
        guard let quality else { return spelling.map { letters.spokenName(of: $0) }.joined(separator: ", ") }
        return letters.spokenName(of: first) + " " + quality.spokenName
    }

    /// The chord labelled in `style` in the key it was suggested in, `key`: its name in `naming`, or
    /// its root's step as a Roman numeral or a Nashville number. A stack without a name lists its
    /// tones — by name, or as the key's step numbers ("1-3-6").
    public func label(_ style: ChordLabel, naming: NoteNaming = .english, in key: KeySpelling,
                      minorTonic: MinorTonic = .doBased) -> String {
        if style == .name { return name(naming) }
        let counted = style == .roman ? MinorTonic.doBased : minorTonic
        guard let quality, let first = pitchClasses.first else {
            return pitchClasses.map { (tone: Int) -> String in
                let degree = key.degree(of: tone, minorTonic: counted)
                return NoteNaming.marks(degree.alteration) + "\(degree.step + 1)"
            }.joined(separator: "-")
        }
        let degree = key.degree(of: first, minorTonic: counted)
        let marks = NoteNaming.marks(degree.alteration)
        guard style == .roman else { return marks + "\(degree.step + 1)" + quality.symbol }
        // A minor third and no major one: a small numeral, which says "minor" already ("ii", "vii°").
        let small = quality.intervals.contains(3) && !quality.intervals.contains(4)
        let numeral = small ? Self.numerals[degree.step].lowercased() : Self.numerals[degree.step]
        let symbol = small && quality.symbol.hasPrefix("m") ? String(quality.symbol.dropFirst()) : quality.symbol
        return marks + numeral + symbol
    }

    /// The same as VoiceOver says it, a numeral as its number: "2 minor", "flat 6 major", "1, 3, 6".
    public func spokenLabel(_ style: ChordLabel, naming: NoteNaming = .english, in key: KeySpelling,
                            minorTonic: MinorTonic = .doBased) -> String {
        if style == .name { return spokenName(naming) }
        let counted = style == .roman ? MinorTonic.doBased : minorTonic
        let steps = pitchClasses.map { (tone: Int) -> String in
            let degree = key.degree(of: tone, minorTonic: counted)
            return NoteNaming.spokenMarks(degree.alteration, before: true) + "\(degree.step + 1)"
        }
        guard let quality, let root = steps.first else { return steps.joined(separator: ", ") }
        return root + " " + quality.spokenName
    }

    private static let numerals = ["I", "II", "III", "IV", "V", "VI", "VII"]
}

extension ChordSuggest {
    /// The names of a chord's tones outside the song's scale, as the chord writes them: "D♭" for
    /// C minor's Neapolitan — the pitch classes `outside` lists, by name.
    public static func outsideNames(of chord: Chord, in context: MusicalContext,
                                    naming: NoteNaming = .english) -> [String] {
        let letters = naming.isMovable ? NoteNaming.english : naming
        return zip(chord.pitchClasses, chord.spelling)
            .filter { !context.contains($0.0) }
            .map { letters.name(of: $0.1) }
    }
}
