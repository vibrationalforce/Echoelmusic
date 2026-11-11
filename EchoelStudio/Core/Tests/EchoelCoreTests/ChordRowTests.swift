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

    func testAnIndexOutsideTheRowSoundsNothing() {
        for index in [-1, 7, 8, Int.max, Int.min] {
            XCTAssertNil(ChordRow.press(index, in: cMajor, after: nil), "\(index)")
        }
        XCTAssertNil(ChordRow.press(5, in: MusicalContext(root: 0, scale: .majorPentatonic), after: nil),
                     "a pentatonic key has five chords")
        XCTAssertNotNil(ChordRow.press(4, in: MusicalContext(root: 0, scale: .majorPentatonic), after: nil))
    }
}
