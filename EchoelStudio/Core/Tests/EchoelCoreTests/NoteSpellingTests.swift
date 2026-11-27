import XCTest
@testable import EchoelCore

/// A key writes its notes as its key signature does (TH-3): one letter per degree in a scale of
/// seven, the tonic the shorter way round, and the two spellings the theory audit measured wrong
/// before (F♯ major's chords read "A♭m", C minor's Neapolitan "C♯") now right.
final class NoteSpellingTests: XCTestCase {
    private func names(_ key: KeySpelling, _ pitchClasses: [Int]) -> [String] {
        pitchClasses.map { (pitchClass: Int) -> String in NoteNaming.english.name(of: pitchClass, in: key) }
    }

    /// The scale's own tones, from the root up.
    private func scaleNames(root: Int, _ scale: Scale) -> [String] {
        names(KeySpelling(MusicalContext(root: root, scale: scale)), scale.intervals.sorted().map { (root + $0) % 12 })
    }

    func testAKeyOfSevenNotesWritesEachLetterOnce() {
        XCTAssertEqual(scaleNames(root: 5, .major), ["F", "G", "A", "B♭", "C", "D", "E"], "F major spells B♭, never A♯")
        XCTAssertEqual(scaleNames(root: 6, .major), ["F♯", "G♯", "A♯", "B", "C♯", "D♯", "E♯"], "F♯ major spells A♯ and E♯")
        XCTAssertEqual(scaleNames(root: 0, .minor), ["C", "D", "E♭", "F", "G", "A♭", "B♭"])
        let gFlatMajor = KeySpelling(tonic: SpelledNote(.g, -1), scale: .major)
        XCTAssertEqual(names(gFlatMajor, [6, 8, 10, 11, 1, 3, 5]), ["G♭", "A♭", "B♭", "C♭", "D♭", "E♭", "F"],
                       "G♭ major writes C♭")
        for scale in Scale.allCases where scale.intervals.count == 7 {
            for root in MusicalContext.rootRange {
                let key = KeySpelling(MusicalContext(root: root, scale: scale))
                let letters = scale.intervals.map { key.note((root + $0) % 12).letter }
                XCTAssertEqual(Set(letters).count, 7, "\(scale) on \(root): every letter once")
            }
        }
    }

    /// A black-key tonic takes the spelling with fewer accidentals; on a tie, the spelling of the
    /// major or minor key of the same tonality; on a tie there too, the key picker's name.
    func testTheTonicIsWrittenTheShorterWayRound() {
        XCTAssertEqual(MusicalContext(root: 1, scale: .major).title, "D♭ Major", "five flats, not seven sharps")
        XCTAssertEqual(MusicalContext(root: 1, scale: .minor).title, "C♯ Minor", "four sharps, not eight flats")
        XCTAssertEqual(MusicalContext(root: 8, scale: .minor).title, "G♯ Minor")
        XCTAssertEqual(MusicalContext(root: 6, scale: .lydian).title, "G♭ Lydian", "five flats, not seven sharps")
        XCTAssertEqual(MusicalContext(root: 6, scale: .major).title, "F♯ Major", "six against six: the picker's F♯")
        XCTAssertEqual(MusicalContext(root: 3, scale: .minor).title, "E♭ Minor", "six against six: the picker's E♭")
        XCTAssertEqual(MusicalContext(root: 1, scale: .mixolydian).title, "D♭ Mixolydian",
                       "six against six, so D♭ major's five flats decide")
        let gSharpHarmonic = MusicalContext(root: 8, scale: .harmonicMinor)
        XCTAssertEqual(gSharpHarmonic.title, "G♯ Harmonic Minor", "six against six, so G♯ minor decides, as for its minor")
        XCTAssertEqual(NoteNaming.english.name(of: 7, in: KeySpelling(gSharpHarmonic)), "F♯♯", "its seventh is F double sharp")
        XCTAssertEqual(MusicalContext(root: 3, scale: .harmonicMinor).title, "E♭ Harmonic Minor")
        for scale in Scale.allCases where scale != .chromatic {
            for root in MusicalContext.rootRange {
                let tonic = KeySpelling(MusicalContext(root: root, scale: scale)).tonic
                XCTAssertEqual(tonic?.pitchClass, root, "\(scale) on \(root)")
                XCTAssertLessThanOrEqual(Swift.abs(tonic?.accidental ?? 9), 1, "\(scale) on \(root): one accidental at most")
            }
        }
    }

    /// The measured defects: F♯ major's row read "F♯ A♭m B♭m B C♯ E♭m F°", C minor's Neapolitan "C♯".
    func testTheChordsOfAKeyAreWrittenInIt() {
        let fSharpMajor = MusicalContext(root: 6, scale: .major)
        XCTAssertEqual(ChordRow.entries(in: fSharpMajor).map(\.label), ["F♯", "G♯m", "A♯m", "B", "C♯", "D♯m", "E♯°"])
        XCTAssertEqual(ChordRow.entries(in: fSharpMajor).map(\.chord.spokenName),
                       ["F sharp major", "G sharp minor", "A sharp minor", "B major", "C sharp major", "D sharp minor",
                        "E sharp diminished"])
        let cMinor = MusicalContext(root: 0, scale: .minor)
        XCTAssertEqual(ChordSuggest.candidates(in: cMinor).filter(\.borrowed).map(\.name), ["G", "C", "D♭"],
                       "the Neapolitan is D♭")
        let neapolitan = ChordSuggest.candidates(in: cMinor).last
        XCTAssertEqual(neapolitan?.spelling, [SpelledNote(.d, -1), SpelledNote(.f), SpelledNote(.a, -1)])
        XCTAssertEqual(ChordSuggest.outsideNames(of: try XCTUnwrap(neapolitan), in: cMinor), ["D♭"])
        let eFlatMajor = MusicalContext(root: 3, scale: .major)
        XCTAssertEqual(ChordRow.entries(in: eFlatMajor).map(\.label), ["E♭", "Fm", "Gm", "A♭", "B♭", "Cm", "D°"])
        let dominant = ChordRow.entries(in: MusicalContext(root: 8, scale: .harmonicMinor)).first { $0.chord.rootDegree == 4 }
        XCTAssertEqual(dominant?.chord.spelling, [SpelledNote(.d, 1), SpelledNote(.f, 2), SpelledNote(.a, 1)],
                       "G♯ harmonic minor's dominant is D♯–F♯♯–A♯: three letters a third apart")
        XCTAssertEqual(dominant?.label, "D♯")
        // A borrowed chord stands on the letter of its step: E♭ major's ♭VI is C♭ E♭ G♭, never
        // B D♯ F♯ with the key's own E♭ written D♯, and C♯ minor's dominant carries B♯.
        let borrowed: [(MusicalContext, String, [String])] = [
            (eFlatMajor, "C♭", ["C♭", "E♭", "G♭"]),
            (MusicalContext(root: 8, scale: .major), "F♭", ["F♭", "A♭", "C♭"]),
            (MusicalContext(root: 1, scale: .major), "C♭", ["C♭", "E♭", "G♭"]),
            (MusicalContext(root: 3, scale: .minor), "F♭", ["F♭", "A♭", "C♭"]),
            (MusicalContext(root: 10, scale: .minor), "C♭", ["C♭", "E♭", "G♭"]),
            (MusicalContext(root: 6, scale: .lydian), "C♭m", ["C♭", "E♭♭", "G♭"]),
            (MusicalContext(root: 6, scale: .lydian), "F♭", ["F♭", "A♭", "C♭"]),
            (MusicalContext(root: 1, scale: .minor), "G♯", ["G♯", "B♯", "D♯"]),
        ]
        for (context, name, tones) in borrowed {
            let chord = ChordSuggest.candidates(in: context).first { $0.borrowed && $0.name == name }
            XCTAssertEqual(chord?.spelling.map { NoteNaming.english.name(of: $0) }, tones, "\(context.title) \(name)")
        }
    }

    /// The key's title names its tonic, and every chord its root, as the key writes that pitch
    /// class; a chord's other tones are written on the letters their intervals have above the root
    /// (the next test says where that is the key's spelling too).
    func testTheTitleAndEveryChordRootAreWrittenAsTheKeyWritesThem() {
        for scale in Scale.allCases where scale != .chromatic {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                let key = KeySpelling(context)
                XCTAssertEqual(context.title, "\(NoteNaming.english.name(of: root, in: key)) \(scale.title)")
                for chord in ChordSuggest.candidates(in: context) {
                    guard let first = chord.pitchClasses.first, let written = chord.spelling.first else {
                        XCTFail("\(context.title): a chord has tones")
                        continue
                    }
                    XCTAssertEqual(written, key.note(first), "\(context.title) \(chord.name): the root as the key writes it")
                    XCTAssertEqual(chord.spelling.map(\.pitchClass), chord.pitchClasses, "\(context.title) \(chord.name)")
                    let most = chord.spelling.map { (note: SpelledNote) -> Int in Swift.abs(note.accidental) }.max() ?? 0
                    XCTAssertLessThanOrEqual(most, 2, "\(context.title) \(chord.name): never three accidentals")
                }
            }
        }
    }

    /// In a seven-note key a chord's root stands on the letter of its step, so every tone of the
    /// chord that belongs to the scale is written as the key writes it. The one exception is a root
    /// outside the scale that its step's letter could only carry with two accidentals: the key
    /// writes it as its white key and the chord is spelled from there, as a chord symbol is (D♭
    /// major's ♭VI is A C♯ E, not B♭♭ D♭ F♭). These are all of them.
    ///
    /// This holds for the seven-note scales of the major and minor families, the ones among the
    /// fourteen scales the song began with: their chords are three letters a third apart. The
    /// scales appended later (Enigmatic, Lydian Augmented, Marwa and others) also hold chords that
    /// are not, so a chord there may write a tone on another letter than the scale does (E♯ in the
    /// chord, F in the scale). For those the test above holds: the root as the key writes it, the
    /// right pitches, never three accidentals.
    func testInASevenNoteKeyAChordWritesTheScalesTonesAsTheKeyDoes() throws {
        var fromTheWhiteKey: [String] = []
        for scale in Scale.allCases.prefix(14) where scale.intervals.count == 7 {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                let key = KeySpelling(context)
                let tonic = try XCTUnwrap(key.tonic)
                for chord in ChordSuggest.candidates(in: context) {
                    let first = try XCTUnwrap(chord.pitchClasses.first)
                    let written = try XCTUnwrap(chord.spelling.first)
                    let onItsStep = SpelledNote(pitchClass: first, on: tonic.letter.up(chord.rootDegree))
                    guard written == onItsStep else {
                        XCTAssertFalse(context.contains(first), "\(context.title) \(chord.name): only a root outside the scale")
                        XCTAssertGreaterThanOrEqual(Swift.abs(onItsStep.accidental), 2, "\(context.title) \(chord.name)")
                        XCTAssertEqual(written.accidental, 0, "\(context.title) \(chord.name): its white key")
                        fromTheWhiteKey.append("\(context.title) \(chord.name)")
                        continue
                    }
                    for (pitchClass, note) in zip(chord.pitchClasses, chord.spelling) where context.contains(pitchClass) {
                        XCTAssertEqual(note, key.note(pitchClass), "\(context.title) \(chord.name): a tone of the scale")
                    }
                }
            }
        }
        XCTAssertEqual(fromTheWhiteKey, ["D♭ Major A", "D♭ Lydian A", "G♭ Lydian D", "D♭ Mixolydian A", "A♭ Melodic Minor A"])
        let flatSix = ChordSuggest.candidates(in: MusicalContext(root: 1, scale: .major)).first { $0.borrowed && $0.name == "A" }
        XCTAssertEqual(flatSix?.spelling, [SpelledNote(.a), SpelledNote(.c, 1), SpelledNote(.e)], "three letters a third apart")
    }

    /// In a scale that has not seven notes the chord letters can need two accidentals for a tone
    /// the scale writes with one or none; that tone keeps the key's spelling. E whole tone writes
    /// its augmented chord on A♯ as A♯ D F♯, never A♯ C♯♯ E♯♯.
    func testInAScaleOfOtherThanSevenNotesAToneOfTheScaleNeverTakesTwoAccidentals() {
        let eWholeTone = MusicalContext(root: 4, scale: .wholeTone)
        let augmented = ChordSuggest.candidates(in: eWholeTone).first { $0.name == "A♯+" }
        XCTAssertEqual(augmented?.spelling, [SpelledNote(.a, 1), SpelledNote(.d), SpelledNote(.f, 1)])
        XCTAssertEqual(ChordSuggest.candidates(in: eWholeTone).first { $0.name == "E+" }?.spelling,
                       [SpelledNote(.e), SpelledNote(.g, 1), SpelledNote(.b, 1)], "one sharp each stays on its letter")
        for scale in Scale.allCases where scale != .chromatic && scale.intervals.count != 7 {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                for chord in ChordSuggest.candidates(in: context) {
                    for (pitchClass, note) in zip(chord.pitchClasses, chord.spelling) where context.contains(pitchClass) {
                        XCTAssertLessThanOrEqual(Swift.abs(note.accidental), 1, "\(context.title) \(chord.name)")
                    }
                }
            }
        }
    }

    /// A tone outside the scale (and every tone of a scale that has not seven) is written as the
    /// harmonic chromatic scale on the tonic writes it, 1 ♭2 2 ♭3 3 4 ♯4 5 ♭6 6 ♭7 7, on its step's
    /// letter — up to one accidental, two for the leading tone; a white key at the tritone, or one
    /// that would need more, keeps its letter.
    func testAToneOutsideASevenNoteSpellingFollowsTheHarmonicChromaticScale() {
        let dMinor = KeySpelling(MusicalContext(root: 2, scale: .minor))
        XCTAssertEqual(names(dMinor, Array(0...11)),
                       ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "G♯", "A", "B♭", "B"],
                       "the leading tone C♯, the Neapolitan E♭, the major third F♯")
        XCTAssertEqual(names(KeySpelling(MusicalContext(root: 0, scale: .major)), [1, 3, 6, 8, 10]),
                       ["D♭", "E♭", "F♯", "A♭", "B♭"])
        XCTAssertEqual(names(KeySpelling(MusicalContext(root: 7, scale: .major)), [1, 3, 8, 10]), ["C♯", "E♭", "A♭", "B♭"])
        XCTAssertEqual(names(KeySpelling(MusicalContext(root: 6, scale: .minor)), [5]), ["E♯"], "F♯ minor's leading tone")
        XCTAssertEqual(names(KeySpelling(MusicalContext(root: 1, scale: .minor)), [0, 5]), ["B♯", "E♯"],
                       "C♯ minor's leading tone and major third")
        XCTAssertEqual(names(KeySpelling(MusicalContext(root: 8, scale: .minor)), [7]), ["F♯♯"],
                       "G♯ minor's leading tone takes two sharps")
        XCTAssertEqual(names(KeySpelling(MusicalContext(root: 3, scale: .major)), [4, 11]), ["F♭", "C♭"],
                       "E♭ major's ♭2 and ♭6")
        XCTAssertEqual(names(KeySpelling(MusicalContext(root: 1, scale: .major)), [2, 9]), ["D", "A"],
                       "E♭♭ and B♭♭ would take two flats: D♭ major keeps the white keys")
        XCTAssertEqual(names(KeySpelling(MusicalContext(root: 6, scale: .major)), [0, 2, 4, 7, 9]),
                       ["C", "D", "E", "G", "A"], "F♯ major's ♭2 ♭3 ♭6 ♭7 are white keys, and its tritone keeps its letter")
        XCTAssertEqual(names(KeySpelling(MusicalContext(root: 11, scale: .major)), [5]), ["F"], "B major's tritone too")
        XCTAssertEqual(scaleNames(root: 0, .minorPentatonic), ["C", "E♭", "F", "G", "B♭"])
        XCTAssertEqual(scaleNames(root: 0, .blues), ["C", "E♭", "F", "F♯", "G", "B♭"])
        XCTAssertEqual(scaleNames(root: 11, .blues), ["B", "D", "E", "F", "F♯", "A"])
        XCTAssertEqual(scaleNames(root: 6, .majorPentatonic), ["F♯", "G♯", "A♯", "C♯", "D♯"])
        XCTAssertEqual(scaleNames(root: 1, .majorPentatonic), ["D♭", "E♭", "F", "A♭", "B♭"])
        XCTAssertEqual(scaleNames(root: 0, .wholeTone), ["C", "D", "E", "F♯", "A♭", "B♭"])
        XCTAssertEqual(scaleNames(root: 4, .wholeTone), ["E", "F♯", "G♯", "A♯", "C", "D"])
    }

    /// The key picker lists each root as a key in the song's scale writes its tonic, so a row
    /// reads as the title does; without a scale it lists the common names.
    func testTheKeyPickerNamesEachRootAsTheTitleDoes() {
        XCTAssertEqual(MusicalContext.tonicNames(for: .major), ["C", "D♭", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"])
        XCTAssertEqual(MusicalContext.tonicNames(for: .minor), ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "G♯", "A", "B♭", "B"])
        XCTAssertEqual(MusicalContext.tonicNames(for: .lydian)[6], "G♭")
        XCTAssertEqual(MusicalContext.tonicNames(for: .chromatic), MusicalContext.rootNames)
        XCTAssertEqual(MusicalContext.tonicNames(for: .major, naming: .german)[10], "B", "B♭ major is B major in German")
        XCTAssertEqual(MusicalContext.tonicNames(for: .minor, naming: .numbered), MusicalContext.tonicNames(for: .minor),
                       "a movable naming keeps letters for the key")
        for scale in Scale.allCases where scale != .chromatic {
            let rows = MusicalContext.tonicNames(for: scale)
            XCTAssertEqual(rows.count, 12)
            for root in MusicalContext.rootRange {
                XCTAssertEqual("\(rows[root]) \(scale.title)", MusicalContext(root: root, scale: scale).title)
            }
        }
    }

    /// A song without a key — chromatic, or a scale this build does not know — names every pitch
    /// class by the key picker's list, whatever its root.
    func testASongWithoutAKeyUsesTheCommonNames() throws {
        for root in MusicalContext.rootRange {
            let key = KeySpelling(MusicalContext(root: root))
            XCTAssertNil(key.tonic)
            XCTAssertEqual(names(key, Array(0...11)), MusicalContext.rootNames, "root \(root)")
        }
        let later = try JSONDecoder().decode(MusicalContext.self, from: Data(
            #"{"root":2,"scale":"a-scale-from-a-later-build","tuning":"edo12","concertPitch":440,"swing":0}"#.utf8))
        XCTAssertEqual(names(KeySpelling(later), Array(0...11)), MusicalContext.rootNames)
        XCTAssertEqual(names(KeySpelling(MusicalContext(root: 12, scale: .major)), Array(0...11)), MusicalContext.rootNames,
                       "a root outside 0 … 11 names no key")
    }

    func testEveryWrittenNoteSoundsItsPitchClass() {
        for scale in Scale.allCases {
            for root in MusicalContext.rootRange {
                let key = KeySpelling(MusicalContext(root: root, scale: scale))
                for pitchClass in 0..<12 {
                    let written = key.note(pitchClass)
                    XCTAssertEqual(written.pitchClass, pitchClass, "\(scale) on \(root)")
                    XCTAssertLessThanOrEqual(Swift.abs(written.accidental), 2, "\(scale) on \(root), \(pitchClass)")
                }
                XCTAssertEqual(key.note(-1), key.note(11), "any whole number folds into the octave")
                XCTAssertEqual(key.note(Int.min), key.note(((Int.min % 12) + 12) % 12))
            }
        }
        XCTAssertEqual(SpelledNote(pitchClass: 11, on: .c), SpelledNote(.c, -1))
        XCTAssertEqual(SpelledNote(pitchClass: 0, on: .b), SpelledNote(.b, 1))
        XCTAssertEqual(SpelledNote(.e, 1).pitchClass, 5, "E♯ sounds as F")
        // Any whole number, without a trap.
        XCTAssertEqual(SpelledNote(pitchClass: Int.min, on: .c).pitchClass, ((Int.min % 12) + 12) % 12)
        XCTAssertEqual(NoteLetter.b.up(Int.max), NoteLetter.b.up(Int.max % 7))
        XCTAssertEqual(NoteLetter.c.up(-1), .b)
        let cMajor = KeySpelling(MusicalContext(root: 0, scale: .major))
        XCTAssertEqual(cMajor.chordSpelling(of: [Int.min, Int.max, 0]).map(\.pitchClass),
                       [Int.min, Int.max, 0].map { ((($0 % 12) + 12) % 12) })
        XCTAssertEqual(cMajor.chordSpelling(of: []), [])
    }

    /// Where a pitch class sits for the movable names: the step above the tonic and how far it is
    /// raised or lowered from that step of the major scale; la-based, a minor key counts from the
    /// major key a minor third above, whose 6 its tonic is.
    func testADegreeCountsFromTheTonicOrLaBasedFromItsRelativeMajor() {
        let cMinor = KeySpelling(MusicalContext(root: 0, scale: .minor))
        XCTAssertEqual(cMinor.degree(of: 3), KeySpelling.Degree(step: 2, alteration: -1), "E♭ is ♭3")
        XCTAssertEqual(cMinor.degree(of: 3, minorTonic: .laBased), KeySpelling.Degree(step: 0, alteration: 0), "E♭ is 1")
        XCTAssertEqual(cMinor.degree(of: 0, minorTonic: .laBased), KeySpelling.Degree(step: 5, alteration: 0), "C is 6")
        XCTAssertEqual(cMinor.movableTonic(.laBased), SpelledNote(.e, -1))
        let cMajor = KeySpelling(MusicalContext(root: 0, scale: .major))
        XCTAssertEqual(cMajor.degree(of: 0, minorTonic: .laBased), KeySpelling.Degree(step: 0, alteration: 0),
                       "a major key is never counted la-based")
        let fLydian = KeySpelling(MusicalContext(root: 5, scale: .lydian))
        XCTAssertEqual(fLydian.degree(of: 11), KeySpelling.Degree(step: 3, alteration: 1), "B is ♯4")
        let bLocrian = KeySpelling(MusicalContext(root: 11, scale: .locrian))
        XCTAssertEqual(bLocrian.degree(of: 5), KeySpelling.Degree(step: 4, alteration: -1), "F is ♭5")
        let none = KeySpelling(MusicalContext(root: 2))
        let steps: [Int] = [0, 1, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6]
        let alterations: [Int] = [0, -1, 0, -1, 0, 0, 1, 0, -1, 0, -1, 0]
        for interval in 0..<12 {
            XCTAssertEqual(none.degree(of: (2 + interval) % 12),
                           KeySpelling.Degree(step: steps[interval], alteration: alterations[interval]),
                           "without a key the steps count from the root: 1 ♭2 2 ♭3 3 4 ♯4 5 ♭6 6 ♭7 7")
        }
    }
}
