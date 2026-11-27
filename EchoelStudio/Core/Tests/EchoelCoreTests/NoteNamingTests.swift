import XCTest
@testable import EchoelCore

/// The reader's note names (TH-3, TH-3b): English, German, fixed do and sargam, then movable do
/// and jianpu numbers — each tested on concrete notes, each spoken in plain words.
final class NoteNamingTests: XCTestCase {
    private func key(_ root: Int, _ scale: Scale = .chromatic) -> KeySpelling {
        KeySpelling(MusicalContext(root: root, scale: scale))
    }

    private func names(_ naming: NoteNaming, _ key: KeySpelling, _ pitchClasses: [Int],
                       minorTonic: MinorTonic = .doBased) -> [String] {
        pitchClasses.map { (pitchClass: Int) -> String in naming.name(of: pitchClass, in: key, minorTonic: minorTonic) }
    }

    /// The scale's own tones, from the root up.
    private func scaleTones(_ root: Int, _ scale: Scale) -> [Int] {
        scale.intervals.sorted().map { (root + $0) % 12 }
    }

    func testEnglishWritesSharpsAndFlatsAsTheKeyDoes() {
        XCTAssertEqual(names(.english, key(5, .major), [10]), ["B♭"])
        XCTAssertEqual(names(.english, key(6, .major), [5]), ["E♯"])
        XCTAssertEqual(NoteNaming.english.spokenName(of: 6, in: key(6, .major)), "F sharp")
        XCTAssertEqual(NoteNaming.english.spokenName(of: 10, in: key(5, .major)), "B flat")
        XCTAssertEqual(NoteNaming.english.spokenName(of: 7, in: key(8, .harmonicMinor)), "F double sharp")
        XCTAssertEqual(NoteNaming.english.name(of: SpelledNote(.b, -2)), "B♭♭")
    }

    /// German calls B♮ H and B♭ B, and writes the accidentals as -is and -es: Fis, Es, As.
    func testGermanCallsTheNaturalBHAndTheFlatB() {
        XCTAssertEqual(names(.german, key(0), [10, 11]), ["B", "H"])
        XCTAssertEqual(names(.german, key(0), Array(0...11)),
                       ["C", "Cis", "D", "Es", "E", "F", "Fis", "G", "As", "A", "B", "H"])
        XCTAssertEqual(names(.german, key(6, .major), scaleTones(6, .major)), ["Fis", "Gis", "Ais", "H", "Cis", "Dis", "Eis"])
        XCTAssertEqual(names(.german, key(3, .major), scaleTones(3, .major)), ["Es", "F", "G", "As", "B", "C", "D"])
        let gFlatMajor = KeySpelling(tonic: SpelledNote(.g, -1), scale: .major)
        XCTAssertEqual(names(.german, gFlatMajor, scaleTones(6, .major)), ["Ges", "As", "B", "Ces", "Des", "Es", "F"])
        XCTAssertEqual(names(.german, key(8, .harmonicMinor), [7]), ["Fisis"])
        let written: [(SpelledNote, String)] = [
            (SpelledNote(.c, -1), "Ces"), (SpelledNote(.e, -1), "Es"), (SpelledNote(.a, -1), "As"), (SpelledNote(.b, -1), "B"),
            (SpelledNote(.b, 1), "His"), (SpelledNote(.e, 1), "Eis"), (SpelledNote(.c, 2), "Cisis"),
            (SpelledNote(.e, -2), "Eses"), (SpelledNote(.a, -2), "Asas"), (SpelledNote(.b, -2), "Heses"),
        ]
        for (note, expected) in written { XCTAssertEqual(NoteNaming.german.name(of: note), expected) }
        XCTAssertEqual(NoteNaming.german.spokenName(of: 11, in: key(0)), "H")
    }

    /// Fixed do names the pitch, so the seventh is Si, never the movable Ti.
    func testFixedDoNamesThePitch() {
        XCTAssertEqual(names(.solfege, key(0), [0, 7, 11]), ["Do", "Sol", "Si"])
        XCTAssertEqual(names(.solfege, key(6, .major), scaleTones(6, .major)), ["Fa♯", "Sol♯", "La♯", "Si", "Do♯", "Re♯", "Mi♯"])
        XCTAssertEqual(names(.solfege, key(3, .major), scaleTones(3, .major)), ["Mi♭", "Fa", "Sol", "La♭", "Si♭", "Do", "Re"])
        XCTAssertEqual(NoteNaming.solfege.spokenName(of: 6, in: key(6, .major)), "Fa sharp")
    }

    /// Sargam sits Sa on the song's root and names the twelve steps above it, komal ♭ and tivra ♯:
    /// a degree of the raga, never a spelling, so a sharp key and a flat key read alike.
    func testSargamCountsFromSaOnTheRoot() {
        XCTAssertEqual(names(.sargam, key(2, .major), [2, 9, 8, 3]), ["Sa", "Pa", "Ma♯", "Re♭"])
        XCTAssertEqual(names(.sargam, key(0), Array(0...11)),
                       ["Sa", "Re♭", "Re", "Ga♭", "Ga", "Ma", "Ma♯", "Pa", "Dha♭", "Dha", "Ni♭", "Ni"])
        XCTAssertEqual(NoteNaming.sargam.name(of: 2, in: key(2)), "Sa", "a song without a scale still has its root")
        let fSharp = key(6, .major), gFlat = KeySpelling(tonic: SpelledNote(.g, -1), scale: .major)
        XCTAssertEqual(names(.sargam, fSharp, Array(0...11)), names(.sargam, gFlat, Array(0...11)), "no flat column")
        XCTAssertEqual(NoteNaming.sargam.spokenName(of: 1, in: key(0)), "komal Re")
        XCTAssertEqual(NoteNaming.sargam.spokenName(of: 6, in: key(0)), "tivra Ma")
        XCTAssertEqual(NoteNaming.sargam.name(ofPitch: 62, in: key(2, .major)), "Sa")
        XCTAssertEqual(NoteNaming.sargam.name(ofPitch: 74, in: key(2, .major)), "S\u{0307}a", "upper octave: a dot above")
        XCTAssertEqual(NoteNaming.sargam.name(ofPitch: 50, in: key(2, .major)), "S\u{0323}a", "lower octave: a dot below")
        XCTAssertEqual(NoteNaming.sargam.spokenName(ofPitch: 50, in: key(2, .major)), "Sa, 1 octave down")
    }

    /// Movable do sings the key's steps: do-based minor lowers mi, la and ti; la-based minor sings
    /// la on the tonic.
    func testMovableDoSingsTheSteps() {
        XCTAssertEqual(names(.movableDo, key(0, .major), scaleTones(0, .major)), ["do", "re", "mi", "fa", "so", "la", "ti"])
        XCTAssertEqual(names(.movableDo, key(0, .minor), scaleTones(0, .minor)), ["do", "re", "me", "fa", "so", "le", "te"])
        XCTAssertEqual(names(.movableDo, key(0, .minor), scaleTones(0, .minor), minorTonic: .laBased),
                       ["la", "ti", "do", "re", "mi", "fa", "so"])
        XCTAssertEqual(names(.movableDo, key(9, .harmonicMinor), scaleTones(9, .harmonicMinor), minorTonic: .laBased),
                       ["la", "ti", "do", "re", "mi", "fa", "si"])
        XCTAssertEqual(names(.movableDo, key(2, .dorian), scaleTones(2, .dorian), minorTonic: .laBased),
                       ["la", "ti", "do", "re", "mi", "fi", "so"])
        XCTAssertEqual(names(.movableDo, key(5, .lydian), scaleTones(5, .lydian)), ["do", "re", "mi", "fi", "so", "la", "ti"])
        XCTAssertEqual(names(.movableDo, key(0, .major), [1, 3, 6, 8, 10]), ["ra", "me", "fi", "le", "te"])
    }

    /// Jianpu numbers the steps 1 … 7 from the tonic, the accidental before the number, an octave
    /// up a dot above and down a dot below.
    func testJianpuNumbersTheStepsAndDotsTheOctaves() {
        let dMajor = key(2, .major)
        XCTAssertEqual(NoteNaming.numbered.name(of: 2, in: dMajor), "1")
        XCTAssertEqual(NoteNaming.numbered.name(ofPitch: 62, in: dMajor), "1")
        XCTAssertEqual(NoteNaming.numbered.name(ofPitch: 61, in: dMajor), "7\u{0323}", "C♯4 is the 7 below D4: a dot below")
        XCTAssertEqual(NoteNaming.numbered.name(ofPitch: 73, in: dMajor), "7")
        XCTAssertEqual(NoteNaming.numbered.name(ofPitch: 74, in: dMajor), "1\u{0307}")
        XCTAssertEqual(NoteNaming.numbered.name(ofPitch: 86, in: dMajor), "1\u{0307}\u{0307}", "two octaves, two dots")
        XCTAssertEqual(NoteNaming.numbered.spokenName(ofPitch: 61, in: dMajor), "7, 1 octave down")
        XCTAssertEqual(names(.numbered, key(0, .minor), scaleTones(0, .minor)), ["1", "2", "♭3", "4", "5", "♭6", "♭7"])
        XCTAssertEqual(names(.numbered, key(0, .minor), scaleTones(0, .minor), minorTonic: .laBased),
                       ["6", "7", "1", "2", "3", "4", "5"], "minor on 6")
        XCTAssertEqual(names(.numbered, key(9, .harmonicMinor), [8], minorTonic: .laBased), ["♯5"])
        XCTAssertEqual(names(.numbered, key(5, .lydian), [11]), ["♯4"])
        XCTAssertEqual(names(.numbered, key(11, .locrian), [5]), ["♭5"])
        XCTAssertEqual(names(.numbered, key(0, .major), [6, 10]), ["♯4", "♭7"])
        XCTAssertEqual(NoteNaming.numbered.spokenName(of: 6, in: key(0, .major)), "sharp 4")
        XCTAssertEqual(NoteNaming.numbered.name(ofPitch: 69, in: key(9, .minor), minorTonic: .laBased), "6",
                       "la-based, A minor counts from C4: A4 is the middle 6")
    }

    /// In a key on a sharp tonic the leading tone is written a letter below the tonic (E♯ in F♯
    /// minor, B♯ in C♯ minor), so the movable names call it 7 and ti a dot below the tonic's
    /// octave, and la-based ♯5 and si.
    func testTheLeadingToneOfASharpMinorKeyIsSevenAndTi() {
        let fSharpMinor = key(6, .minor)
        XCTAssertEqual(NoteNaming.english.name(of: 5, in: fSharpMinor), "E♯")
        XCTAssertEqual(NoteNaming.english.name(ofPitch: 65, in: fSharpMinor), "E♯4")
        XCTAssertEqual(NoteNaming.numbered.name(ofPitch: 65, in: fSharpMinor), "7\u{0323}", "the 7 below F♯4")
        XCTAssertEqual(NoteNaming.movableDo.name(ofPitch: 65, in: fSharpMinor), "t\u{0323}i")
        XCTAssertEqual(NoteNaming.numbered.name(ofPitch: 66, in: fSharpMinor), "1")
        XCTAssertEqual(NoteNaming.numbered.name(of: 5, in: fSharpMinor, minorTonic: .laBased), "♯5")
        XCTAssertEqual(NoteNaming.movableDo.name(of: 5, in: fSharpMinor, minorTonic: .laBased), "si")
        let cSharpMinor = key(1, .minor)
        XCTAssertEqual(NoteNaming.english.name(ofPitch: 60, in: cSharpMinor), "B♯3")
        XCTAssertEqual(NoteNaming.movableDo.name(ofPitch: 60, in: cSharpMinor), "t\u{0323}i", "middle C is the ti below C♯4")
        XCTAssertEqual(NoteNaming.numbered.name(ofPitch: 60, in: cSharpMinor, minorTonic: .laBased), "♯5\u{0323}",
                       "la-based, C♯ minor counts from E4")
        let gSharpMinor = key(8, .minor)
        XCTAssertEqual(NoteNaming.english.name(of: 7, in: gSharpMinor), "F♯♯")
        XCTAssertEqual(NoteNaming.numbered.name(of: 7, in: gSharpMinor), "7")
        XCTAssertEqual(NoteNaming.movableDo.name(of: 7, in: gSharpMinor, minorTonic: .laBased), "si")
        XCTAssertEqual(NoteNaming.movableDo.name(of: 11, in: key(3, .major)), "le", "E♭ major's C♭ is ♭6, as C major's A♭")
    }

    /// The movable names depend only on the scale and the interval above the tonic: every key of a
    /// scale reads as the same scale on C, in both readings of a minor key.
    func testTheMovableNamesReadAlikeInEveryKey() {
        for scale in Scale.allCases {
            let onC = key(0, scale)
            for root in MusicalContext.rootRange {
                let spelled = key(root, scale)
                for minorTonic in MinorTonic.allCases {
                    for interval in 0..<12 {
                        for naming in NoteNaming.allCases where naming.isMovable {
                            XCTAssertEqual(naming.name(of: root + interval, in: spelled, minorTonic: minorTonic),
                                           naming.name(of: interval, in: onC, minorTonic: minorTonic),
                                           "\(scale) on \(root), \(minorTonic), +\(interval), \(naming)")
                            XCTAssertEqual(naming.spokenName(of: root + interval, in: spelled, minorTonic: minorTonic),
                                           naming.spokenName(of: interval, in: onC, minorTonic: minorTonic))
                        }
                    }
                }
            }
        }
    }

    /// Every jianpu number, movable-do syllable and sargam name reads back to the pitch it names, in
    /// every key and both readings: its step and marks give the semitones above 1, do or Sa, and
    /// its dots the octave from the one that starts on that note written in octave 4.
    func testEveryMovableNameReadsBackToItsPitch() {
        var keys = Scale.allCases.flatMap { (scale: Scale) -> [KeySpelling] in
            MusicalContext.rootRange.map { key($0, scale) }
        }
        keys.append(KeySpelling(tonic: SpelledNote(.c, -1), scale: .major))
        keys.append(KeySpelling(tonic: SpelledNote(.g, -1), scale: .minor))
        for spelled in keys {
            for minorTonic in MinorTonic.allCases {
                let one = spelled.movableTonic(minorTonic)
                let sa = spelled.movableTonic(.doBased)
                for pitch in Note.pitchRange {
                    let jianpu = NoteNaming.numbered.name(ofPitch: pitch, in: spelled, minorTonic: minorTonic)
                    XCTAssertEqual(readJianpu(jianpu, from: one), pitch, "\(spelled.scale) on \(spelled.root), \(minorTonic): \(jianpu)")
                    let syllable = NoteNaming.movableDo.name(ofPitch: pitch, in: spelled, minorTonic: minorTonic)
                    XCTAssertEqual(readMovableDo(syllable, from: one), pitch, "\(spelled.scale) on \(spelled.root), \(minorTonic): \(syllable)")
                    let sargam = NoteNaming.sargam.name(ofPitch: pitch, in: spelled, minorTonic: minorTonic)
                    XCTAssertEqual(readSargam(sargam, from: sa), pitch, "\(spelled.scale) on \(spelled.root): \(sargam)")
                }
            }
        }
    }

    /// A fixed name carries the octave of its letter, as scientific pitch notation counts it: in
    /// C♯ harmonic minor middle C is B♯3, in G♭ major the B below it C♭4.
    func testAFullNameCarriesTheOctaveOfItsLetter() {
        let cSharpHarmonic = key(1, .harmonicMinor)
        XCTAssertEqual(NoteNaming.english.name(ofPitch: 60, in: cSharpHarmonic), "B♯3")
        XCTAssertEqual(NoteNaming.german.name(ofPitch: 60, in: cSharpHarmonic), "His3")
        XCTAssertEqual(NoteNaming.solfege.name(ofPitch: 60, in: cSharpHarmonic), "Si♯3")
        XCTAssertEqual(NoteNaming.english.spokenName(ofPitch: 60, in: cSharpHarmonic), "B sharp 3")
        let gFlatMajor = KeySpelling(tonic: SpelledNote(.g, -1), scale: .major)
        XCTAssertEqual(NoteNaming.english.name(ofPitch: 59, in: gFlatMajor), "C♭4")
        XCTAssertEqual(NoteNaming.english.name(ofPitch: 0, in: key(0, .major)), "C-1")
        XCTAssertEqual(NoteNaming.english.spokenName(ofPitch: 0, in: key(0, .major)), "C minus 1")
        for pitch in Note.pitchRange where !NoteEditing.isBlackKey(pitch) {
            XCTAssertEqual(NoteNaming.english.name(ofPitch: pitch, in: key(0, .major)), NoteEditing.name(of: pitch),
                           "a white key in C major reads as the piano roll writes it")
        }
    }

    /// A number outside MIDI's range is still named, as its pitch class in its octave, without a trap
    /// and without a mark per octave beyond the ten MIDI needs.
    func testAPitchOutsideMIDIsRangeIsNamedWithoutATrap() {
        for naming in NoteNaming.allCases {
            for spelled in [key(0, .major), key(8, .harmonicMinor), key(3), KeySpelling(tonic: SpelledNote(.c, -1), scale: .major)] {
                for pitch in [Int.min, Int.min + 1, -1_000, -1, 128, 1_000, Int.max - 1, Int.max] {
                    let written = naming.name(ofPitch: pitch, in: spelled, minorTonic: .laBased)
                    XCTAssertFalse(written.isEmpty, "\(naming) \(pitch)")
                    XCTAssertLessThanOrEqual(written.unicodeScalars.count, 30, "\(naming) \(pitch): \(written)")
                    XCTAssertFalse(naming.spokenName(ofPitch: pitch, in: spelled).isEmpty)
                    XCTAssertEqual(naming.name(of: pitch, in: spelled), naming.name(of: ((pitch % 12) + 12) % 12, in: spelled))
                }
            }
        }
        XCTAssertEqual(NoteNaming.english.name(ofPitch: -1, in: key(0, .major)), "B-2")
        XCTAssertEqual(NoteNaming.english.name(ofPitch: 128, in: key(0, .major)), "A♭9", "C major's ♭6")
    }

    /// VoiceOver hears every name in plain words: no ♯, ♭ or combining dot, letters and spaces
    /// (and, for jianpu and an octave, digits and a comma).
    func testEverySpokenNameIsPlainWords() {
        let keys = Scale.allCases.flatMap { (scale: Scale) -> [KeySpelling] in
            MusicalContext.rootRange.map { KeySpelling(MusicalContext(root: $0, scale: scale)) }
        }
        let letters = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ ")
        let digits = Set("0123456789,")
        for naming in NoteNaming.allCases {
            for spelled in keys {
                for minorTonic in MinorTonic.allCases {
                    for pitchClass in 0..<12 {
                        let spoken = naming.spokenName(of: pitchClass, in: spelled, minorTonic: minorTonic)
                        XCTAssertFalse(spoken.isEmpty)
                        let allowed = naming == .numbered ? letters.union(digits) : letters
                        XCTAssertTrue(spoken.allSatisfy(allowed.contains), "\(naming): \(spoken)")
                    }
                    for pitch in [0, 47, 60, 61, 75, 127] {
                        let spoken = naming.spokenName(ofPitch: pitch, in: spelled, minorTonic: minorTonic)
                        XCTAssertTrue(spoken.allSatisfy(letters.union(digits).contains), "\(naming): \(spoken)")
                    }
                }
            }
        }
    }

    func testEveryNamingHasATitleAndAStoredValueFallsBackToEnglish() {
        XCTAssertEqual(NoteNaming.allCases.map(\.title),
                       ["C D E (English)", "C D E … H (German)", "Do Re Mi (fixed do)", "Sa Re Ga (sargam)",
                        "do re mi (movable do)", "1 2 3 (jianpu)"])
        XCTAssertFalse(NoteNaming.allCases.contains { $0.title.lowercased().contains("solfeggio") },
                       "fixed do is never titled with the word of the banned frequency claims")
        XCTAssertEqual(NoteNaming.allCases.filter(\.isMovable), [.sargam, .movableDo, .numbered])
        XCTAssertEqual(NoteNaming(stored: "german"), .german)
        XCTAssertEqual(NoteNaming(stored: "a-naming-from-a-later-build"), .english)
        XCTAssertEqual(NoteNaming(stored: nil), .english)
        XCTAssertEqual(MinorTonic(stored: "laBased"), .laBased)
        XCTAssertEqual(MinorTonic(stored: nil), .doBased)
        XCTAssertEqual(MinorTonic.allCases.map(\.title), ["Minor on 1 (do-based)", "Minor on 6 (la-based)"])
    }

    /// The key as each reader writes it; a movable naming counts from the tonic, so it names the
    /// key in letters and says where its 1, Sa or do sits.
    func testTheKeyTitleInEveryNaming() {
        let fSharpMajor = MusicalContext(root: 6, scale: .major)
        XCTAssertEqual(fSharpMajor.title(naming: .english), "F♯ Major")
        XCTAssertEqual(fSharpMajor.title(naming: .german), "Fis Major")
        XCTAssertEqual(fSharpMajor.title(naming: .solfege), "Fa♯ Major")
        XCTAssertEqual(fSharpMajor.title(naming: .numbered), "F♯ Major (1=♯F)", "jianpu writes the key 1=♯F")
        XCTAssertEqual(MusicalContext(root: 3, scale: .major).title(naming: .numbered), "E♭ Major (1=♭E)")
        let dMinor = MusicalContext(root: 2, scale: .minor)
        XCTAssertEqual(dMinor.title(naming: .numbered), "D Minor (1=D)")
        XCTAssertEqual(dMinor.title(naming: .numbered, minorTonic: .laBased), "D Minor (1=F)")
        XCTAssertEqual(dMinor.title(naming: .movableDo, minorTonic: .laBased), "D Minor (do=F)")
        XCTAssertEqual(dMinor.title(naming: .sargam, minorTonic: .laBased), "D Minor (Sa=D)", "Sa is always the tonic")
        XCTAssertEqual(MusicalContext(root: 11, scale: .minor).title(naming: .german), "H Minor")
        XCTAssertEqual(MusicalContext(root: 10, scale: .major).title(naming: .german), "B Major", "B is B♭ in German")
        XCTAssertEqual(MusicalContext(root: 4).title(naming: .german), "Chromatic")
        XCTAssertEqual(MusicalContext(root: 4).title(naming: .sargam), "Chromatic (Sa=E)",
                       "without a key the movable names still count from the root")
        XCTAssertEqual(fSharpMajor.title, fSharpMajor.title(naming: .english))
    }

    // MARK: Reading a movable name back

    private static let risingSyllables = ["do", "di", "re", "ri", "mi", "fa", "fi", "so", "si", "la", "li", "ti"]
    private static let fallingSyllables = ["do", "ra", "re", "me", "mi", "fa", "se", "so", "le", "la", "te", "ti"]
    private static let sargamSteps = ["Sa", "Re♭", "Re", "Ga♭", "Ga", "Ma", "Ma♯", "Pa", "Dha♭", "Dha", "Ni♭", "Ni"]

    /// The name without its dots, and the octaves they mark: one up per dot above, one down per dot below.
    private func undotted(_ name: String) -> (plain: String, octaves: Int) {
        var plain = ""
        var octaves = 0
        for scalar in name.unicodeScalars {
            switch scalar {
            case "\u{0307}": octaves += 1
            case "\u{0323}": octaves -= 1
            default: plain.unicodeScalars.append(scalar)
            }
        }
        return (plain, octaves)
    }

    /// The MIDI pitch of `one` (1, do or Sa) in octave 4, as its letter's octave counts it.
    private func octaveFour(_ one: SpelledNote) -> Int { 60 + one.letter.naturalPitchClass + one.accidental }

    private func readJianpu(_ name: String, from one: SpelledNote) -> Int? {
        let (plain, octaves) = undotted(name)
        guard let number = Int(String(plain.filter(\.isNumber))), (1...7).contains(number) else { return nil }
        let marks = plain.filter { $0 == "♯" }.count - plain.filter { $0 == "♭" }.count
        return octaveFour(one) + 12 * octaves + KeySpelling.majorSteps[number - 1] + marks
    }

    private func readMovableDo(_ name: String, from one: SpelledNote) -> Int? {
        let (plain, octaves) = undotted(name)
        guard let semitones = Self.risingSyllables.firstIndex(of: plain) ?? Self.fallingSyllables.firstIndex(of: plain) else {
            return nil
        }
        return octaveFour(one) + 12 * octaves + semitones
    }

    private func readSargam(_ name: String, from sa: SpelledNote) -> Int? {
        let (plain, octaves) = undotted(name)
        guard let semitones = Self.sargamSteps.firstIndex(of: plain) else { return nil }
        return octaveFour(sa) + 12 * octaves + semitones
    }
}
