import XCTest
@testable import EchoelCore

/// A chord labelled by its name in the reader's note names, or by the step of the key its root
/// stands on — Roman numerals or Nashville numbers (TH-3b). The chord row keeps names.
final class ChordLabelTests: XCTestCase {
    private func labels(_ chords: [ChordSuggest.Chord], _ style: ChordLabel, naming: NoteNaming = .english,
                        in context: MusicalContext, minorTonic: MinorTonic = .doBased) -> [String] {
        let key = KeySpelling(context)
        return chords.map { (chord: ChordSuggest.Chord) -> String in
            chord.label(style, naming: naming, in: key, minorTonic: minorTonic)
        }
    }

    private func scaleChords(_ context: MusicalContext) -> [ChordSuggest.Chord] {
        ChordSuggest.candidates(in: context).filter { !$0.borrowed }
    }

    private func borrowedChords(_ context: MusicalContext) -> [ChordSuggest.Chord] {
        ChordSuggest.candidates(in: context).filter(\.borrowed)
    }

    func testRomanNumeralsCountFromTheTonicAgainstTheMajorScale() {
        let cMajor = MusicalContext(root: 0, scale: .major)
        XCTAssertEqual(labels(scaleChords(cMajor), .roman, in: cMajor), ["I", "ii", "iii", "IV", "V", "vi", "vii°"])
        XCTAssertEqual(labels(borrowedChords(cMajor), .roman, in: cMajor), ["iv", "♭VI", "♭VII"])
        let aMinor = MusicalContext(root: 9, scale: .minor)
        XCTAssertEqual(labels(scaleChords(aMinor), .roman, in: aMinor), ["i", "ii°", "♭III", "iv", "v", "♭VI", "♭VII"])
        XCTAssertEqual(labels(borrowedChords(aMinor), .roman, in: aMinor), ["V", "I", "♭II"],
                       "V, the Picardy tonic and the Neapolitan")
        XCTAssertEqual(labels(borrowedChords(aMinor), .roman, in: aMinor, minorTonic: .laBased), ["V", "I", "♭II"],
                       "Roman numerals always count from the tonic")
        let fSharpMajor = MusicalContext(root: 6, scale: .major)
        XCTAssertEqual(labels(scaleChords(fSharpMajor), .roman, in: fSharpMajor), ["I", "ii", "iii", "IV", "V", "vi", "vii°"])
        let cLydian = MusicalContext(root: 0, scale: .lydian)
        XCTAssertEqual(labels(scaleChords(cLydian), .roman, in: cLydian), ["I", "II", "iii", "♯iv°", "V", "vi", "vii"])
        let aHarmonic = MusicalContext(root: 9, scale: .harmonicMinor)
        XCTAssertEqual(labels(scaleChords(aHarmonic), .roman, in: aHarmonic), ["i", "ii°", "♭III+", "iv", "V", "♭VI", "vii°"])
        let eFlatMajor = MusicalContext(root: 3, scale: .major)
        XCTAssertEqual(labels(borrowedChords(eFlatMajor), .roman, in: eFlatMajor), ["iv", "♭VI", "♭VII"],
                       "E♭ major's C♭ is its ♭VI, as A♭ is C major's")
        let cSharpMinor = MusicalContext(root: 1, scale: .minor)
        XCTAssertEqual(labels(borrowedChords(cSharpMinor), .roman, in: cSharpMinor), ["V", "I", "♭II"])
    }

    /// A label names the step of the key, so every key of a scale labels its chords as the same
    /// scale on C does — Roman numerals, and Nashville numbers in both readings of a minor key.
    func testTheLabelsReadAlikeInEveryKey() {
        for scale in Scale.allCases where scale != .chromatic {
            let onC = MusicalContext(root: 0, scale: scale)
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                for style in [ChordLabel.roman, .nashville] {
                    for minorTonic in MinorTonic.allCases {
                        XCTAssertEqual(labels(ChordSuggest.candidates(in: context), style, in: context, minorTonic: minorTonic),
                                       labels(ChordSuggest.candidates(in: onC), style, in: onC, minorTonic: minorTonic),
                                       "\(context.title) \(style) \(minorTonic)")
                    }
                }
            }
        }
    }

    func testNashvilleNumbersAndTheirMinorOnOneOrOnSix() {
        let cMajor = MusicalContext(root: 0, scale: .major)
        XCTAssertEqual(labels(scaleChords(cMajor), .nashville, in: cMajor), ["1", "2m", "3m", "4", "5", "6m", "7°"])
        XCTAssertEqual(labels(scaleChords(cMajor), .nashville, in: cMajor, minorTonic: .laBased),
                       ["1", "2m", "3m", "4", "5", "6m", "7°"], "a major key reads the same either way")
        XCTAssertEqual(labels(borrowedChords(cMajor), .nashville, in: cMajor), ["4m", "♭6", "♭7"])
        let aMinor = MusicalContext(root: 9, scale: .minor)
        XCTAssertEqual(labels(scaleChords(aMinor), .nashville, in: aMinor), ["1m", "2°", "♭3", "4m", "5m", "♭6", "♭7"])
        XCTAssertEqual(labels(scaleChords(aMinor), .nashville, in: aMinor, minorTonic: .laBased),
                       ["6m", "7°", "1", "2m", "3m", "4", "5"], "minor on 6: A minor counts from C")
        XCTAssertEqual(labels(borrowedChords(aMinor), .nashville, in: aMinor, minorTonic: .laBased), ["3", "6", "♭7"])
    }

    /// The name in each reader's note names; a movable naming names degrees, not chords, so its
    /// chords keep their letters (the Roman and Nashville options give them as steps).
    func testAChordIsNamedInTheReadersNoteNames() {
        let fSharpMajor = MusicalContext(root: 6, scale: .major)
        let chords = scaleChords(fSharpMajor)
        XCTAssertEqual(labels(chords, .name, naming: .german, in: fSharpMajor), ["Fis", "Gism", "Aism", "H", "Cis", "Dism", "Eis°"])
        XCTAssertEqual(labels(chords, .name, naming: .solfege, in: fSharpMajor),
                       ["Fa♯", "Sol♯m", "La♯m", "Si", "Do♯", "Re♯m", "Mi♯°"])
        for naming in NoteNaming.allCases where naming.isMovable {
            XCTAssertEqual(labels(chords, .name, naming: naming, in: fSharpMajor), chords.map(\.name), "\(naming)")
        }
        let eFlatMajor = MusicalContext(root: 3, scale: .major)
        XCTAssertEqual(labels(scaleChords(eFlatMajor), .name, naming: .german, in: eFlatMajor),
                       ["Es", "Fm", "Gm", "As", "B", "Cm", "D°"], "B is B♭ major in German")
        XCTAssertEqual(chords.map { $0.name(.english) }, chords.map(\.name))
        XCTAssertEqual(chords.first { $0.rootDegree == 1 }?.spokenName(.german), "Gis minor")
    }

    /// The chord row shows names, never a numeral, in every key.
    func testTheChordRowKeepsNames() {
        for scale in Scale.allCases where scale != .chromatic {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                for entry in ChordRow.entries(in: context) {
                    XCTAssertEqual(entry.label, entry.chord.label(.name, naming: .english, in: KeySpelling(context)))
                }
            }
        }
    }

    /// A stack the vocabulary has no name for lists its tones: by name in the key, as numbers of the
    /// key's steps in the Roman and Nashville styles.
    func testAStackWithoutANameListsItsTones() {
        let pentatonic = MusicalContext(root: 0, scale: .majorPentatonic)
        let key = KeySpelling(pentatonic)
        let stack = ChordSuggest.Chord(rootDegree: 0, alterations: [0, 0, 0], function: .tonic, borrowed: false,
                                       pitchClasses: [0, 4, 9], spelledIn: key)
        XCTAssertEqual(stack.name, "C-E-A")
        XCTAssertEqual(stack.label(.roman, in: key), "1-3-6")
        XCTAssertEqual(stack.label(.nashville, in: key), "1-3-6")
        XCTAssertEqual(stack.spokenName, "C, E, A")
        XCTAssertEqual(stack.spokenLabel(.roman, in: key), "1, 3, 6")
    }

    /// The notes a borrowed chord brings from outside the scale are named as the chord writes them,
    /// so the chord menu's line "D♭ — borrowed, D♭ outside the scale" never names a pitch two ways.
    func testTheOutsideNamesWriteTheRootAsTheChordsNameDoes() {
        for scale in Scale.allCases where scale != .chromatic {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                for chord in ChordSuggest.candidates(in: context) where chord.borrowed {
                    let outside = ChordSuggest.outsideNames(of: chord, in: context)
                    XCTAssertEqual(outside.count, ChordSuggest.outside(chord, in: context).count, "\(context.title) \(chord.name)")
                    guard let first = chord.pitchClasses.first, let written = chord.spelling.first, let quality = chord.quality,
                          !context.contains(first) else { continue }
                    let rootName = NoteNaming.english.name(of: written)
                    XCTAssertEqual(outside.first, rootName, "\(context.title) \(chord.name)")
                    XCTAssertEqual(chord.name, rootName + quality.symbol)
                }
            }
        }
    }

    /// VoiceOver says a label in words: "2 minor", "flat 6 major", "sharp 4 diminished".
    func testALabelIsSpokenInWords() {
        let cMajor = MusicalContext(root: 0, scale: .major)
        let key = KeySpelling(cMajor)
        XCTAssertEqual(scaleChords(cMajor).map { $0.spokenLabel(.roman, in: key) },
                       ["1 major", "2 minor", "3 minor", "4 major", "5 major", "6 minor", "7 diminished"])
        XCTAssertEqual(borrowedChords(cMajor).map { $0.spokenLabel(.nashville, in: key) },
                       ["4 minor", "flat 6 major", "flat 7 major"])
        let cLydian = MusicalContext(root: 0, scale: .lydian)
        XCTAssertEqual(scaleChords(cLydian).first { $0.rootDegree == 3 }?.spokenLabel(.roman, in: KeySpelling(cLydian)),
                       "sharp 4 diminished")
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ,")
        for scale in Scale.allCases where scale != .chromatic {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                let spelled = KeySpelling(context)
                for chord in ChordSuggest.candidates(in: context) {
                    for style in ChordLabel.allCases {
                        for naming in NoteNaming.allCases {
                            let spoken = chord.spokenLabel(style, naming: naming, in: spelled)
                            XCTAssertFalse(spoken.isEmpty, "\(context.title) \(chord.name)")
                            XCTAssertTrue(spoken.allSatisfy(allowed.contains), "\(context.title) \(style): \(spoken)")
                        }
                    }
                }
            }
        }
    }

    func testEveryStyleHasATitleAndAStoredValueFallsBackToNames() {
        XCTAssertEqual(ChordLabel.allCases.map(\.title), ["Names", "Roman numerals", "Nashville numbers"])
        XCTAssertEqual(ChordLabel(stored: "roman"), .roman)
        XCTAssertEqual(ChordLabel(stored: "a-style-from-a-later-build"), .name)
        XCTAssertEqual(ChordLabel(stored: nil), .name)
    }
}
