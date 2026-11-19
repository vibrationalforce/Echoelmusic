import Foundation
import XCTest
@testable import EchoelCore

final class ChordVoicingTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)

    private func clip(_ chords: [[Int]]) -> Clip {
        var notes: [Note] = []
        for (index, chord) in chords.enumerated() {
            for pitch in chord { notes.append(Note(pitch: pitch, start: Tick(index) * bar, length: bar)) }
        }
        return Clip(name: "C", length: Tick(chords.count) * bar, notes: notes)
    }

    private func pitches(after kind: ChordVoicing.Kind, of written: Clip, chosen: Set<NoteID> = []) -> [[Int]] {
        var out = written
        if case .updateNotes(_, let changed)? = ChordVoicing.voiced(written, chosen: chosen, kind: kind).command {
            for note in changed {
                if let index = out.notes.firstIndex(where: { $0.id == note.id }) { out.notes[index] = note }
            }
        }
        return Revoice.chords(in: out).map { $0.map(\.pitch) }
    }

    func testEachVoicingMovesOneNoteByAnOctave() {
        let c = clip([[60, 64, 67]])
        XCTAssertEqual(pitches(after: .invertUp, of: c), [[64, 67, 72]])
        XCTAssertEqual(pitches(after: .invertDown, of: c), [[55, 60, 64]])
        XCTAssertEqual(pitches(after: .open, of: c), [[60, 67, 76]])
        XCTAssertEqual(pitches(after: .dropTwo, of: c), [[52, 60, 67]])
    }

    func testDropThreeNeedsFourNotes() {
        XCTAssertNil(ChordVoicing.voiced(clip([[60, 64, 67]]), kind: .dropThree).command)
        XCTAssertEqual(pitches(after: .dropThree, of: clip([[60, 64, 67, 71]])), [[52, 60, 67, 71]])
    }

    func testNothingLeavesTheRangeOrDoublesANote() {
        XCTAssertNil(ChordVoicing.voiced(clip([[120, 124, 127]]), kind: .invertUp).command, "127 + 12 is out of range")
        XCTAssertNil(ChordVoicing.voiced(clip([[60, 72, 76]]), kind: .invertUp).command, "72 is already in the chord")
    }

    func testOnlyPitchesChangeAndAChosenNoteVoicesOnlyItsChord() {
        let c = clip([[60, 64, 67], [65, 69, 72]])
        let chosen = Set(c.notes.filter { $0.pitch == 69 }.map(\.id))
        let result = ChordVoicing.voiced(c, chosen: chosen, kind: .invertUp)
        XCTAssertEqual(result.chordCount, 1)
        guard case .updateNotes(_, let changed)? = result.command else { return XCTFail("one chord moves") }
        XCTAssertEqual(changed.count, 1)
        let before = c.notes.first { $0.id == changed[0].id }
        XCTAssertEqual(changed[0].start, before?.start)
        XCTAssertEqual(changed[0].length, before?.length)
        XCTAssertEqual(changed[0].velocity, before?.velocity)
        XCTAssertEqual(changed[0].pitch, 77)
        XCTAssertEqual(ChordVoicing.message(result, kind: .invertUp), "Invert Up: 1 chord re-voiced.")
    }

    func testPairsAreNoChord() {
        let result = ChordVoicing.voiced(clip([[60, 64]]), kind: .open)
        XCTAssertNil(result.command)
        XCTAssertEqual(ChordVoicing.message(result, kind: .open), "Open needs a chord of 3 or more notes together.")
    }
}
