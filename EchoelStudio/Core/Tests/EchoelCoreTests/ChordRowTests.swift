import XCTest
@testable import EchoelCore

/// The row of chord buttons on the play screen: the key's own chords in order, and what one finger
/// on one of them sounds.
final class ChordRowTests: XCTestCase {
    private let cMajor = MusicalContext(root: 0, scale: .major)
    private let aMinor = MusicalContext(root: 9, scale: .minor)

    func testTheRowHoldsTheSevenChordsOfTheKeyInOrder() {
        XCTAssertEqual(ChordRow.entries(in: cMajor).map(\.label), ["C", "Dm", "Em", "F", "G", "Am", "B°"])
        XCTAssertEqual(ChordRow.entries(in: aMinor).map(\.label), ["Am", "B°", "C", "Dm", "Em", "F", "G"])
        XCTAssertEqual(ChordRow.entries(in: cMajor).map(\.chord.rootDegree), Array(0..<7))
        XCTAssertTrue(ChordRow.entries(in: cMajor).allSatisfy { !$0.chord.borrowed }, "no borrowed chord in this row")
        XCTAssertEqual(ChordRow.entries(in: aMinor).map(\.label), ChordRow.entries(in: aMinor).map(\.chord.name),
                       "a button shows the chord's name")
    }

    func testEveryPressSoundsThreeDifferentTonesOfItsChordOverItsRoot() throws {
        for scale in Scale.allCases where scale != .chromatic {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                let row = ChordRow.entries(in: context)
                XCTAssertFalse(row.isEmpty, context.title)
                for index in row.indices {
                    let chord = row[index].chord
                    let played = try XCTUnwrap(ChordRow.press(index, in: context, after: nil))
                    XCTAssertEqual(played.voices.count, 3, "\(context.title) \(chord.name)")
                    XCTAssertEqual(Set(played.voices).count, 3, "\(context.title) \(chord.name)")
                    XCTAssertEqual(Set(played.voices.map { ChordSuggest.pitchClass($0) }), Set(chord.pitchClasses))
                    XCTAssertEqual(played.voices, played.voices.sorted())
                    XCTAssertTrue(played.voices.allSatisfy(ChordRow.voiceRange.contains))
                    XCTAssertEqual(ChordSuggest.pitchClass(played.bass), chord.pitchClasses.first, "the bass is the root")
                    XCTAssertTrue(ChordRow.bassRange.contains(played.bass))
                    XCTAssertLessThan(played.bass, played.voices.first ?? Note.pitchRange.lowerBound)
                    XCTAssertEqual(played.notes, [played.bass] + played.voices)
                }
            }
        }
    }

    func testFAfterCKeepsTheCommonToneAndStepsTheOthers() throws {
        let c = try XCTUnwrap(ChordRow.press(0, in: cMajor, after: nil))
        XCTAssertEqual(c.voices, [60, 64, 67])
        XCTAssertEqual(c.bass, 48, "C3 under the voices")
        let f = try XCTUnwrap(ChordRow.press(3, in: cMajor, after: c))
        XCTAssertEqual(f.voices, [60, 65, 69], "C stays, E steps to F, G to A")
        XCTAssertEqual(f.bass, 41, "F2")
        XCTAssertEqual(ChordRow.press(3, in: cMajor, after: f), f, "the same chord again sounds the same")
    }

    /// What `ChordSuggest.voicing` gives a chord of a seven-tone major or minor key: a tone the
    /// chord before also holds keeps its pitch, and every other tone lands on a neighbour of a voice
    /// before, a whole tone away at most.
    func testInTheKeyCommonTonesStayAndTheOtherVoicesStepAtMostAWholeTone() throws {
        for context in [cMajor, aMinor] {
            let row = ChordRow.entries(in: context)
            for from in row.indices {
                let before = try XCTUnwrap(ChordRow.press(from, in: context, after: nil))
                for to in row.indices {
                    let next = try XCTUnwrap(ChordRow.press(to, in: context, after: before))
                    let classes = Set(row[to].chord.pitchClasses)
                    let label = "\(row[from].label) to \(row[to].label)"
                    for pitch in before.voices where classes.contains(ChordSuggest.pitchClass(pitch)) {
                        XCTAssertTrue(next.voices.contains(pitch), "\(label): the common tone \(pitch) stays")
                    }
                    for pitch in next.voices {
                        let step = before.voices.map { abs($0 - pitch) }.min() ?? Int.max
                        XCTAssertLessThanOrEqual(step, 2, "\(label): \(pitch)")
                    }
                }
            }
        }
    }

    /// With nothing pressed before, the voices sit around E4 (MIDI 64), within a tritone of it —
    /// the middle of the keyboard the play screen opens on, which starts at C3.
    func testAFirstPressSitsWithinATritoneOfE4() throws {
        for scale in Scale.allCases where scale != .chromatic {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                for index in ChordRow.entries(in: context).indices {
                    let played = try XCTUnwrap(ChordRow.press(index, in: context, after: nil))
                    XCTAssertTrue(played.voices.allSatisfy { (pitch: Int) -> Bool in abs(pitch - 64) <= 6 },
                                  "\(context.title) \(played.voices)")
                }
            }
        }
    }

    /// Down the circle of fifths and round again, a run of presses keeps leading the voices one
    /// way; the fold keeps them on the keys.
    func testALongRunOfPressesNeverLeavesTheVoiceRange() throws {
        for scale in Scale.allCases where scale != .chromatic {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                let count = ChordRow.entries(in: context).count
                var last: ChordRow.Press?
                for step in 0..<48 {
                    let played = try XCTUnwrap(ChordRow.press((step * 3) % count, in: context, after: last))
                    XCTAssertTrue(played.voices.allSatisfy(ChordRow.voiceRange.contains), "\(context.title) step \(step)")
                    XCTAssertEqual(Set(played.voices).count, 3)
                    last = played
                }
            }
        }
    }

    func testAPressAfterNotesOffTheKeyboardStillLandsInTheVoiceRange() throws {
        let stray = ChordRow.Press(voices: [-5, 0, 127, 300], bass: 40)
        let played = try XCTUnwrap(ChordRow.press(0, in: cMajor, after: stray))
        XCTAssertTrue(played.voices.allSatisfy(ChordRow.voiceRange.contains))
        XCTAssertEqual(Set(played.voices.map { ChordSuggest.pitchClass($0) }), [0, 4, 7])
        let silent = ChordRow.Press(voices: [], bass: 40)
        XCTAssertEqual(ChordRow.press(0, in: cMajor, after: silent), ChordRow.press(0, in: cMajor, after: nil),
                       "a press after nothing that sounded is a first press")
    }

    func testASongWithoutAKeyHasAnEmptyRow() throws {
        XCTAssertTrue(ChordRow.entries(in: MusicalContext()).isEmpty, "chromatic")
        XCTAssertNil(ChordRow.press(0, in: MusicalContext(), after: nil))
        let later = try JSONDecoder().decode(MusicalContext.self, from: Data(
            #"{"root":2,"scale":"bebop","tuning":"edo12","concertPitch":440,"swing":0}"#.utf8))
        XCTAssertTrue(ChordRow.entries(in: later).isEmpty, "a scale this build does not know frames nothing")
        XCTAssertTrue(ChordRow.entries(in: MusicalContext(root: 12, scale: .major)).isEmpty, "a root outside 0 … 11 names no key")
        XCTAssertTrue(ChordRow.entries(in: MusicalContext(root: -1, scale: .major)).isEmpty)
    }

    /// VoiceOver says a chord in words, as the button writes it short.
    func testAChordIsSpokenInWords() {
        XCTAssertEqual(ChordRow.entries(in: cMajor).map(\.chord.spokenName),
                       ["C major", "D minor", "E minor", "F major", "G major", "A minor", "B diminished"])
        let fSharpMajor = MusicalContext(root: 6, scale: .major)
        XCTAssertEqual(ChordRow.entries(in: fSharpMajor).first?.chord.spokenName, "F sharp major")
        let eFlatMinor = MusicalContext(root: 3, scale: .minor)
        XCTAssertEqual(ChordRow.entries(in: eFlatMinor).first?.chord.spokenName, "E flat minor")
        for scale in Scale.allCases where scale != .chromatic {
            for entry in ChordRow.entries(in: MusicalContext(root: 0, scale: scale)) {
                XCTAssertFalse(entry.chord.spokenName.isEmpty, "\(scale) \(entry.label)")
                XCTAssertFalse(entry.chord.spokenName.contains("♯") || entry.chord.spokenName.contains("♭"))
            }
        }
    }

    /// A seventh and every other quality are spoken in words too, on any root: "G dominant seventh",
    /// "B half-diminished seventh", "F sharp minor major seventh".
    func testASeventhIsSpokenInWords() throws {
        let sevenths = ChordSuggest.vocabulary(in: cMajor, qualities: ChordSuggest.Quality.sevenths)
        XCTAssertEqual(sevenths.first { $0.name == "G7" }?.spokenName, "G dominant seventh")
        XCTAssertEqual(sevenths.first { $0.name == "Bø7" }?.spokenName, "B half-diminished seventh")
        XCTAssertEqual(sevenths.first { $0.name == "D7sus4" }?.spokenName, "D dominant seventh suspended fourth")
        for quality in ChordSuggest.Quality.allCases {
            let chord = ChordSuggest.Chord(rootDegree: 0, alterations: quality.intervals.map { _ in 0 }, function: .tonic,
                                           borrowed: false, pitchClasses: quality.intervals.map { ($0 + 6) % 12 },
                                           spelledIn: KeySpelling(MusicalContext()))
            XCTAssertEqual(chord.quality, quality)
            XCTAssertEqual(chord.name, "F♯" + quality.symbol)
            XCTAssertEqual(chord.spokenName, "F sharp " + quality.spokenName)
        }
        let nameless = ChordSuggest.Chord(rootDegree: 0, alterations: [0, 0, 0], function: .tonic, borrowed: false,
                                          pitchClasses: [0, 4, 9], spelledIn: KeySpelling(MusicalContext()))
        XCTAssertNil(nameless.quality)
        XCTAssertEqual(nameless.name, "C-E-A", "a stack without a name lists its tones")
        XCTAssertEqual(nameless.spokenName, "C, E, A")
    }

    /// Every button of every key names a chord whose tones all lie in the scale, one per degree at
    /// most, the degrees rising — in pentatonic and other scales too (TH-5). Until 2026-11-27 both
    /// pentatonic rows held only stacks without a name, such as C-E-A.
    func testEveryButtonNamesAChordOfTheScale() {
        for scale in Scale.allCases where scale != .chromatic {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                let steps = scale.intervals.sorted()
                let row = ChordRow.entries(in: context)
                XCTAssertFalse(row.isEmpty, context.title)
                let degrees = row.map(\.chord.rootDegree)
                XCTAssertEqual(degrees, degrees.sorted(), context.title)
                XCTAssertEqual(Set(degrees).count, degrees.count, "\(context.title): one chord per degree")
                for entry in row {
                    let label = "\(context.title) \(entry.label)"
                    let quality = entry.chord.quality
                    XCTAssertNotNil(quality, label)
                    XCTAssertTrue(quality.map { ChordSuggest.Quality.triads.contains($0) } ?? false, "\(label): a triad")
                    XCTAssertTrue(ChordSuggest.outside(entry.chord, in: context).isEmpty, label)
                    XCTAssertEqual(entry.chord.pitchClasses.first, ChordSuggest.pitchClass(root + steps[entry.chord.rootDegree]), label)
                }
            }
        }
    }

    /// C major pentatonic plays C, Dsus2, Gsus2 and Am, the first triad each degree holds; its E has no
    /// button, because no triad of the vocabulary sits on E inside the scale. A minor pentatonic, the
    /// same notes, plays the same four chords from A.
    func testAPentatonicRowNamesItsChords() throws {
        let cMajorPentatonic = MusicalContext(root: 0, scale: .majorPentatonic)
        XCTAssertEqual(ChordRow.entries(in: cMajorPentatonic).map(\.label), ["C", "Dsus2", "Gsus2", "Am"])
        XCTAssertEqual(ChordRow.entries(in: cMajorPentatonic).map(\.chord.rootDegree), [0, 1, 3, 4])
        XCTAssertEqual(ChordRow.entries(in: MusicalContext(root: 9, scale: .minorPentatonic)).map(\.label),
                       ["Am", "C", "Dsus2", "Gsus2"])
        let sus = try XCTUnwrap(ChordRow.press(1, in: cMajorPentatonic, after: nil))
        XCTAssertEqual(Set(sus.voices.map { ChordSuggest.pitchClass($0) }), [2, 4, 9], "D, E and A")
        XCTAssertEqual(sus.bass, 50, "D3 under the voices")
    }

    /// A row of more than seven buttons stands in lines of at most seven, as even as they come, each a
    /// run of the row's order; the row of every key fits, and some need a second line.
    func testALongRowStandsInEvenLinesOfAtMostSeven() {
        XCTAssertEqual(ChordRow.lines(count: 0), [])
        XCTAssertEqual(ChordRow.lines(count: -3), [])
        XCTAssertEqual(ChordRow.lines(count: 4), [0..<4])
        XCTAssertEqual(ChordRow.lines(count: 7), [0..<7])
        XCTAssertEqual(ChordRow.lines(count: 8), [0..<4, 4..<8])
        XCTAssertEqual(ChordRow.lines(count: 9), [0..<5, 5..<9])
        XCTAssertEqual(ChordRow.lines(count: 10), [0..<5, 5..<10])
        XCTAssertEqual(ChordRow.lines(count: 15), [0..<5, 5..<10, 10..<15])
        var longest = 0
        for scale in Scale.allCases {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                let count = ChordRow.entries(in: context).count
                let laidOut = ChordRow.lines(count: count)
                XCTAssertEqual(laidOut.flatMap { (line: Range<Int>) -> [Int] in Array(line) }, Array(0..<count),
                               "\(context.title): every button once, in order")
                let lengths = laidOut.map(\.count)
                XCTAssertLessThanOrEqual(lengths.max() ?? 0, ChordRow.longestLine, context.title)
                XCTAssertLessThanOrEqual((lengths.max() ?? 0) - (lengths.min() ?? 0), 1, "\(context.title): even lines")
                longest = Swift.max(longest, count)
            }
        }
        XCTAssertGreaterThan(longest, ChordRow.longestLine, "some key's row needs a second line")
    }

    func testAnIndexOutsideTheRowSoundsNothing() {
        for index in [-1, 7, 8, Int.max, Int.min] {
            XCTAssertNil(ChordRow.press(index, in: cMajor, after: nil), "\(index)")
        }
        XCTAssertNil(ChordRow.press(4, in: MusicalContext(root: 0, scale: .majorPentatonic), after: nil),
                     "C major pentatonic has four chords: none sits on its E")
        XCTAssertNotNil(ChordRow.press(3, in: MusicalContext(root: 0, scale: .majorPentatonic), after: nil))
    }
}
