import XCTest
@testable import EchoelCore

final class ChordSuggestTests: XCTestCase {
    private let cMajor = MusicalContext(root: 0, scale: .major)
    private let aMinor = MusicalContext(root: 9, scale: .minor)

    func testTheScaleGivesOneTriadPerDegreeThenTheBorrowedOnes() {
        let chords = ChordSuggest.candidates(in: cMajor)
        XCTAssertEqual(chords.filter { !$0.borrowed }.map(\.name), ["C", "Dm", "Em", "F", "G", "Am", "B°"])
        XCTAssertEqual(chords.filter(\.borrowed).map(\.name), ["Fm", "A♭", "B♭"], "iv, ♭VI, ♭VII from the parallel minor")
        XCTAssertEqual(ChordSuggest.candidates(in: aMinor).filter(\.borrowed).map(\.name), ["E", "A", "B♭"],
                       "V, the Picardy tonic and the Neapolitan")
        XCTAssertTrue(ChordSuggest.candidates(in: MusicalContext()).isEmpty, "a song without a key has no chords")
    }

    func testFunctionOutranksSmoothnessAndTheCadenceResolves() throws {
        let g = try XCTUnwrap(ChordSuggest.candidates(in: cMajor).first { $0.name == "G" })
        let after = ChordSuggest.ranked(after: g, sounding: [55, 59, 62], in: cMajor)
        XCTAssertEqual(after.first?.function, .tonic, "after the dominant a tonic comes first")
        XCTAssertEqual(Array(after.prefix(3)).map(\.function), [.tonic, .tonic, .tonic])
        let opening = ChordSuggest.ranked(after: nil, sounding: [], in: cMajor)
        XCTAssertEqual(opening.first?.name, "C", "the tonic opens")
        for previous in ChordSuggest.candidates(in: cMajor) {
            XCTAssertEqual(ChordSuggest.ranked(after: previous, sounding: [], in: cMajor).first?.borrowed, false,
                           "a borrowed chord never ranks first")
        }
    }

    func testTheRankingIsDeterministic() {
        let a = ChordSuggest.ranked(after: nil, sounding: [60, 64, 67], in: aMinor)
        let b = ChordSuggest.ranked(after: nil, sounding: [60, 64, 67], in: aMinor)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, ChordSuggest.candidates(in: aMinor).count)
    }

    func testABorrowedChordSaysWhatLiesOutsideTheScale() throws {
        let flatSeven = try XCTUnwrap(ChordSuggest.candidates(in: cMajor).first { $0.name == "B♭" })
        XCTAssertEqual(ChordSuggest.outside(flatSeven, in: cMajor), [10])
        let f = try XCTUnwrap(ChordSuggest.candidates(in: cMajor).first { $0.name == "F" })
        XCTAssertTrue(ChordSuggest.outside(f, in: cMajor).isEmpty)
    }

    func testTheChordBeforeIsRecognisedFromItsNotes() {
        XCTAssertEqual(ChordSuggest.recognize([57, 60, 64], in: cMajor)?.name, "Am")
        XCTAssertEqual(ChordSuggest.recognize([64, 67, 72], in: cMajor)?.name, "C", "an inversion is the same chord")
        XCTAssertNil(ChordSuggest.recognize([61], in: cMajor))
        XCTAssertNil(ChordSuggest.recognize([], in: cMajor))
    }

    func testAPickLandsAfterTheLastNoteCloseToTheChordBefore() throws {
        var clip = Clip(name: "Keys", length: 2 * 3_840)
        XCTAssertEqual(ChordSuggest.position(in: clip, context: cMajor).start, 0)
        clip.notes = [60, 64, 67].map { Note(pitch: $0, velocity: 100, start: 0, length: 3_840) }
        let f = try XCTUnwrap(ChordSuggest.candidates(in: cMajor).first { $0.name == "F" })
        let command = try XCTUnwrap(ChordSuggest.insert(f, in: clip, context: cMajor, length: 3_840))
        guard case let .addNotes(id, notes) = command else { return XCTFail("\(command)") }
        XCTAssertEqual(id, clip.id)
        XCTAssertEqual(notes.map(\.start), [3_840, 3_840, 3_840])
        XCTAssertEqual(notes.map(\.pitch), [60, 65, 69], "C stays, E moves to F, G to A")
        XCTAssertTrue(notes.allSatisfy { $0.start + $0.length <= clip.length })
        clip.notes.append(contentsOf: notes)
        let full = ChordSuggest.insert(f, in: clip, context: cMajor, length: 3_840)
        XCTAssertNil(full, "no room after the last note")
    }

    func testEveryScaleWithAKeyRanksWithoutTrapping() {
        for scale in Scale.allCases where scale != .chromatic {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                let ranked = ChordSuggest.ranked(after: ChordSuggest.candidates(in: context).last, sounding: [0, 127], in: context)
                XCTAssertFalse(ranked.isEmpty, "\(scale)")
                for chord in ranked {
                    XCTAssertTrue(ChordSuggest.voicing(of: chord, after: [127]).allSatisfy(Note.pitchRange.contains))
                    XCTAssertTrue(ChordSuggest.voicing(of: chord, after: [0]).allSatisfy(Note.pitchRange.contains))
                }
            }
        }
    }
}
