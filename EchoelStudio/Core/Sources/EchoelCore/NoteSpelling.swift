import Foundation

/// One of the seven letters a note is written with, C … B.
public enum NoteLetter: Int, CaseIterable, Sendable {
    case c, d, e, f, g, a, b

    /// The pitch class the letter names with no accidental: C 0, D 2, E 4, F 5, G 7, A 9, B 11.
    public var naturalPitchClass: Int { Self.naturals[rawValue] }

    /// The letter `steps` letters above this one, round the seven: one above B is C.
    public func up(_ steps: Int) -> NoteLetter {
        NoteLetter(rawValue: ((rawValue + steps % 7) % 7 + 7) % 7) ?? .c
    }

    /// How many letters `other` lies above this one, 0 … 6.
    func steps(to other: NoteLetter) -> Int { ((other.rawValue - rawValue) % 7 + 7) % 7 }

    static let naturals = [0, 2, 4, 5, 7, 9, 11]
    /// The letter of each white key, by pitch class; nil for a black key.
    static let ofWhiteKey: [NoteLetter?] = [.c, nil, .d, nil, .e, .f, nil, .g, nil, .a, nil, .b]
}

/// A pitch class as it is written: a letter, raised (positive) or lowered (negative) by whole
/// semitones. F♯ is F + 1 and B♭ is B − 1; E♯, the seventh of F♯ major, is E + 1 and sounds as F.
public struct SpelledNote: Hashable, Sendable {
    public let letter: NoteLetter
    /// Semitones up (+) or down (−) from the letter: 1 a sharp, −2 a double flat.
    public let accidental: Int

    public init(_ letter: NoteLetter, _ accidental: Int = 0) {
        self.letter = letter
        self.accidental = accidental
    }

    /// The note on `letter` that sounds `pitchClass` (any whole number), its accidental counted
    /// the shorter way round (−6 … +5): pitch class 11 on C is C♭, 0 on B is B♯, 7 on F is F♯♯.
    public init(pitchClass: Int, on letter: NoteLetter) {
        let difference = (((pitchClass % 12) - letter.naturalPitchClass) % 12 + 12) % 12
        self.init(letter, difference > 5 ? difference - 12 : difference)
    }

    /// The pitch class the note sounds, 0 = C … 11 = B.
    public var pitchClass: Int { ((letter.naturalPitchClass + accidental % 12) % 12 + 12) % 12 }

    /// The names a pitch class has without a key — C, C♯, D, E♭, E, F, F♯, G, A♭, A, B♭, B, the
    /// list `MusicalContext.rootNames` writes — each black key as the key it is most often the
    /// tonic of writes it.
    static let common: [SpelledNote] = [
        SpelledNote(.c), SpelledNote(.c, 1), SpelledNote(.d), SpelledNote(.e, -1), SpelledNote(.e), SpelledNote(.f),
        SpelledNote(.f, 1), SpelledNote(.g), SpelledNote(.a, -1), SpelledNote(.a), SpelledNote(.b, -1), SpelledNote(.b),
    ]
}

/// How a song's key writes the twelve pitch classes (TH-3, 2026-11-27): the spelling follows the
/// key, so F♯ major's ii is G♯m and never A♭m, and C minor's Neapolitan is D♭ and never C♯ — the
/// two the theory audit measured. Display only: a song stores pitch classes and MIDI numbers, never
/// a spelling, so nothing here changes what plays or what is saved.
///
/// The rules, in order:
/// - A scale of seven notes writes each letter once, the way a key signature does: F♯ major is
///   F♯ G♯ A♯ B C♯ D♯ E♯, and G♯ harmonic minor raises its seventh to F♯♯.
/// - Every other tone — outside the scale, or in a scale that has not seven notes — is written as
///   the harmonic chromatic scale on the tonic writes it, 1 ♭2 2 ♭3 3 4 ♯4 5 ♭6 6 ♭7 7, each on
///   the letter of its step (`outside`). So D minor writes its leading tone C♯ and its major third
///   F♯, C♯ minor its leading tone B♯, C major its borrowed A♭ and B♭, E♭ major its borrowed C♭,
///   and the blues on C is C E♭ F F♯ G B♭. Where that would take two accidentals — the leading
///   tone may take two, G♯ minor's is F♯♯ — a white key keeps its letter and a black key takes its
///   common name; a white key at the tritone keeps its letter too (C in F♯ major, F in B blues),
///   where the ♯4 and the blues' ♭5 are read as often.
/// - A tonic on a black key is written the way that needs fewer accidentals in the scale (D♭ major,
///   five flats, not C♯ major, seven sharps); on a tie the major or minor key of the same tonality
///   decides (D♭ Mixolydian, because D♭ major beats C♯ major); on a tie there too, its common
///   name (F♯ major, E♭ minor). The earlier app's rule (`MusicalKey.prefersFlatSpelling`) chose
///   the same for every major and minor key but that last one, which it wrote D♯ minor, and
///   judged the other scales by the major or minor key signature alone.
/// - A song without a key (chromatic, a scale this build does not know, a root outside 0 … 11)
///   writes every pitch class by its common name (`MusicalContext.rootNames`).
public struct KeySpelling: Equatable, Sendable {
    /// Where a pitch class sits for the movable names: the step above their tonic, 0 (1, do) … 6
    /// (7, ti), and how many semitones it is raised (+) or lowered (−) from that step of the major
    /// scale — ♭3 is step 2 lowered by one.
    public struct Degree: Equatable, Sendable {
        public let step: Int
        public let alteration: Int

        public init(step: Int, alteration: Int) {
            self.step = step
            self.alteration = alteration
        }
    }

    /// The key's root as a pitch class, 0 = C … 11 = B; the tonic's, when there is one. Without a key
    /// the song's root is still where sargam's Sa and movable do's do sit.
    public let root: Int
    /// The tonic as the key writes it; nil for a song without a key.
    public let tonic: SpelledNote?
    /// The scale the notes are written for; `.chromatic` for a song without a key.
    public let scale: Scale
    /// How the key writes each pitch class, 0 = C … 11 = B.
    public let notes: [SpelledNote]

    /// The spelling of the song's key.
    public init(_ context: MusicalContext) {
        let folded = ((context.root % 12) + 12) % 12
        guard context.scale != .chromatic, MusicalContext.rootRange.contains(context.root) else {
            self.init(root: folded, tonic: nil, scale: .chromatic, notes: SpelledNote.common)
            return
        }
        self.init(tonic: Self.tonic(on: folded, scale: context.scale), scale: context.scale)
    }

    /// The spelling of `scale` on a tonic written as given — G♭ major, where the song's key would
    /// write F♯ major.
    public init(tonic: SpelledNote, scale: Scale) {
        self.init(root: tonic.pitchClass, tonic: tonic, scale: scale, notes: Self.notes(tonic: tonic, scale: scale))
    }

    private init(root: Int, tonic: SpelledNote?, scale: Scale, notes: [SpelledNote]) {
        self.root = root
        self.tonic = tonic
        self.scale = scale
        self.notes = notes
    }

    /// How the key writes `pitchClass`, which may be any whole number.
    public func note(_ pitchClass: Int) -> SpelledNote {
        notes[((pitchClass % 12) + 12) % 12]
    }

    /// The note the movable names call 1 and do: the tonic, or for a key of minor tonality read
    /// la-based the major key a minor third above, whose 6 (la) the tonic is. Without a key, the
    /// song's root by its common name.
    public func movableTonic(_ minorTonic: MinorTonic) -> SpelledNote {
        guard let tonic else { return SpelledNote.common[root] }
        guard minorTonic == .laBased, scale.hasMinorTonality else { return tonic }
        return SpelledNote(pitchClass: tonic.pitchClass + 3, on: tonic.letter.up(2))
    }

    /// Where `pitchClass` sits for the movable names. A tone of a seven-note scale is the step of
    /// the scale it is; any other tone the step of the harmonic chromatic scale on the tonic
    /// (1 ♭2 2 ♭3 3 4 ♯4 5 ♭6 6 ♭7 7), and so is every tone without a key, counted from the root.
    /// The step is never taken from the letter the key writes, so the movable names depend only on
    /// the scale and the interval above the tonic and read alike in every key: F♯ major's E♯ is 7,
    /// C Lydian's F♯ ♯4, C♯ minor's B♯ 7 and, la-based, ♯5, as A minor's G♯ is.
    public func degree(of pitchClass: Int, minorTonic: MinorTonic = .doBased) -> Degree {
        let folded = ((pitchClass % 12) + 12) % 12
        let interval = ((folded - root) % 12 + 12) % 12
        let steps = scale.intervals.sorted()
        let fromTonic = tonic != nil && steps.count == 7
            ? (steps.firstIndex(of: interval) ?? Self.stepOfInterval[interval])
            : Self.stepOfInterval[interval]
        guard tonic != nil, minorTonic == .laBased, scale.hasMinorTonality else {
            return Degree(step: fromTonic, alteration: interval - Self.majorSteps[fromTonic])
        }
        // La-based, the tonic is 6 of the major key a minor third up: its 1 lies two steps and three
        // semitones above the tonic, five steps and nine semitones below.
        let step = (fromTonic + 5) % 7
        var alteration = (interval + 9) % 12 - Self.majorSteps[step]
        if alteration > 5 { alteration -= 12 }
        if alteration < -6 { alteration += 12 }
        return Degree(step: step, alteration: alteration)
    }

    /// A chord's tones as the key writes them: the root as the key writes its pitch class, every
    /// other tone of a named chord on the letter its interval has above the root — the third, the
    /// fifth, a second or a fourth for a suspended chord — so a triad is three letters a third
    /// apart: E♯ G♯ B in F♯ major, D♯ F♯♯ A♯ for G♯ harmonic minor's dominant, C♭ E♭ G♭ for E♭
    /// major's ♭VI. For the chords `ChordSuggest` offers in a seven-note key of the major and minor
    /// families every tone of the scale then reads as the key writes it, except where the key could
    /// put the root on its step's letter only with two accidentals and wrote its white key instead
    /// (D♭ major's ♭VI is A C♯ E, never B♭♭ D♭ F♭; `NoteSpellingTests` lists all five). In every
    /// key, a tone of the scale whose letter would take two accidentals or more keeps the key's
    /// spelling: E whole tone's A♯+ is A♯ D F♯, and no chord is ever written with three. A stack
    /// that is no named chord (`ChordSuggest.Quality`) writes each tone as the key does. Takes any
    /// whole numbers.
    public func chordSpelling(of pitchClasses: [Int]) -> [SpelledNote] {
        let folded = pitchClasses.map { ((($0 % 12) + 12) % 12) }
        guard let first = folded.first else { return [] }
        let written = note(first)
        let above = folded.map { (($0 - first) % 12 + 12) % 12 }
        guard ChordSuggest.Quality.allCases.contains(where: { $0.intervals == above }) else {
            return folded.map(note)
        }
        return zip(folded, above).map { (tone: (pitchClass: Int, interval: Int)) -> SpelledNote in
            let spelled = SpelledNote(pitchClass: tone.pitchClass, on: written.letter.up(Self.letterOfChordInterval[tone.interval]))
            guard Swift.abs(spelled.accidental) > 1,
                  scale.intervals.contains(((tone.pitchClass - root) % 12 + 12) % 12) else { return spelled }
            return note(tone.pitchClass)
        }
    }

    // MARK: The rules

    /// The semitones of the major scale's steps above its tonic.
    static let majorSteps = [0, 2, 4, 5, 7, 9, 11]
    /// How many letters above a named chord's root each interval is written: the second and fourth
    /// of a suspended chord, the third, the fifth — the diminished and the augmented one too — and,
    /// for a chord with a seventh, the seventh, the diminished seventh's double flat included.
    static let letterOfChordInterval = [0, 1, 1, 2, 2, 3, 4, 4, 4, 6, 6, 6]
    /// The step each interval above the tonic is in the harmonic chromatic scale: the minor
    /// second, minor third, augmented fourth, minor sixth and minor seventh for the five intervals
    /// the major scale lacks (the altered degrees of sargam, komal Re Ga Dha Ni and tivra Ma).
    static let stepOfInterval = [0, 1, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6]

    /// How a tonic on `root` is written for `scale`: a white key by its letter; a black key the way
    /// with fewer accidentals in the scale, then in the major or minor scale of the same tonality,
    /// then by its common name.
    static func tonic(on root: Int, scale: Scale) -> SpelledNote {
        let common = SpelledNote.common[root]
        guard common.accidental != 0 else { return common }
        let sharp = SpelledNote(pitchClass: root, on: NoteLetter.ofWhiteKey[(root + 11) % 12] ?? .c)
        let flat = SpelledNote(pitchClass: root, on: NoteLetter.ofWhiteKey[(root + 1) % 12] ?? .c)
        for judged in [scale, scale.hasMinorTonality ? Scale.minor : Scale.major] {
            let sharps = accidentals(tonic: sharp, scale: judged)
            let flats = accidentals(tonic: flat, scale: judged)
            if sharps != flats { return sharps < flats ? sharp : flat }
        }
        return common
    }

    /// How many accidentals the scale's own tones carry on `tonic`; a double counts two.
    static func accidentals(tonic: SpelledNote, scale: Scale) -> Int {
        let written = notes(tonic: tonic, scale: scale)
        return scale.intervals.reduce(0) { sum, interval in
            sum + Swift.abs(written[(tonic.pitchClass + interval) % 12].accidental)
        }
    }

    /// Every pitch class written for `scale` on `tonic`: a seven-note scale one letter per step,
    /// everything else by `outside`, and the tonic as given.
    static func notes(tonic: SpelledNote, scale: Scale) -> [SpelledNote] {
        var written = (0..<12).map { outside($0, tonic: tonic) }
        let steps = scale.intervals.sorted()
        if steps.count == 7 {
            for (index, interval) in steps.enumerated() {
                let pitchClass = (tonic.pitchClass + interval) % 12
                written[pitchClass] = SpelledNote(pitchClass: pitchClass, on: tonic.letter.up(index))
            }
        }
        written[tonic.pitchClass] = tonic
        return written
    }

    /// A pitch class not written by a seven-note scale, 0 … 11: on the letter of its step in the
    /// harmonic chromatic scale on the tonic (`stepOfInterval`) when that takes one accidental at
    /// most, two for the leading tone — so E♯ in F♯ minor, B♯ in C♯ minor, F♯♯ in G♯ minor, C♭ in
    /// E♭ major. Otherwise, and for a white key at the tritone, a white key keeps its letter (D♭
    /// major's D, not E♭♭; F♯ major's C, not B♯) and a black key takes its common name.
    static func outside(_ pitchClass: Int, tonic: SpelledNote) -> SpelledNote {
        let interval = ((pitchClass - tonic.pitchClass) % 12 + 12) % 12
        let white = NoteLetter.ofWhiteKey[pitchClass]
        if let white, interval == 6 { return SpelledNote(white) }
        let written = SpelledNote(pitchClass: pitchClass, on: tonic.letter.up(stepOfInterval[interval]))
        if Swift.abs(written.accidental) <= (interval == 11 ? 2 : 1) { return written }
        return white.map { SpelledNote($0) } ?? SpelledNote.common[pitchClass]
    }
}

extension Scale {
    /// A minor third over the root and no major third: the tonality whose relative major is a minor
    /// third up — the rule `ChordSuggest.isMinor` chooses the borrowed chords by, and the earlier
    /// app's `isMinorTonality`.
    var hasMinorTonality: Bool { intervals.contains(3) && !intervals.contains(4) }
}

extension MusicalContext {
    /// How the song's key writes its notes.
    public var spelling: KeySpelling { KeySpelling(self) }

    /// The twelve roots, 0 = C … 11 = B, each as a key in `scale` writes its tonic — the key
    /// picker's rows, so a row reads as the key's title does: D♭ under Major, C♯ under Minor, G♭
    /// under Lydian. Without a scale (chromatic, or one this build does not know) the common names,
    /// `rootNames`. A movable naming writes letters here, as it does in the title.
    public static func tonicNames(for scale: Scale, naming: NoteNaming = .english) -> [String] {
        let letters = naming.isMovable ? NoteNaming.english : naming
        return rootRange.map { (root: Int) -> String in
            letters.name(of: KeySpelling(MusicalContext(root: root, scale: scale)).tonic ?? SpelledNote.common[root])
        }
    }

    /// The frame as a reader with `naming` writes it: "F♯ Major", "Fis Major", "Fa♯ Major". A
    /// movable naming counts its names from the tonic, so it writes the key in letters and says
    /// where its 1, Sa or do sits, as jianpu prints "1=♭E": "D Minor (1=F)" la-based, "D Minor
    /// (Sa=D)". Chromatic frames nothing; a movable naming still says where it counts from.
    public func title(naming: NoteNaming, minorTonic: MinorTonic = .doBased) -> String {
        let key = KeySpelling(self)
        let base: String
        if let tonic = key.tonic {
            let tonicName = naming.isMovable ? NoteNaming.english.name(of: tonic) : naming.name(of: tonic)
            base = "\(tonicName) \(scale.title)"
        } else {
            base = Scale.chromatic.title
        }
        guard naming.isMovable else { return base }
        let one = key.movableTonic(naming == .sargam ? .doBased : minorTonic)
        let written = naming == .numbered
            ? NoteNaming.marks(one.accidental) + NoteNaming.letters[one.letter.rawValue]
            : NoteNaming.english.name(of: one)
        let syllable = naming == .numbered ? "1" : (naming == .sargam ? "Sa" : "do")
        return "\(base) (\(syllable)=\(written))"
    }
}
