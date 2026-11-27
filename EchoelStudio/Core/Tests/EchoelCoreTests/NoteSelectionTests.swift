import XCTest
@testable import EchoelCore

/// The note editor's edits of the chosen notes: transpose, duplicate, legato — whole or not at all.
final class NoteSelectionTests: XCTestCase {
    private let quarter = MusicalTime.ticksPerQuarter

    private func clip(_ notes: [Note], bars: Tick = 2) -> Clip {
        Clip(name: "Notes", length: bars * 4 * MusicalTime.ticksPerQuarter, notes: notes)
    }

    func testTransposingMovesEveryNoteOrNone() throws {
        let notes = [Note(pitch: 60, start: 0, length: quarter), Note(pitch: 64, velocity: 90, start: quarter, length: quarter)]
        let up = try XCTUnwrap(NoteSelection.transposed(notes, by: 12))
        XCTAssertEqual(up.map(\.pitch), [72, 76])
        XCTAssertEqual(up.map(\.start), notes.map(\.start), "the time stays")
        XCTAssertEqual(up.map(\.velocity), notes.map(\.velocity))
        XCTAssertEqual(up.map(\.id), notes.map(\.id), "the same notes, moved")
        XCTAssertEqual(NoteSelection.transposed(notes, by: -1)?.map(\.pitch), [59, 63])
        XCTAssertNil(NoteSelection.transposed([Note(pitch: 120, start: 0, length: quarter)], by: 12), "off the keyboard: nothing moves")
        XCTAssertNil(NoteSelection.transposed([], by: 1))
        XCTAssertNil(NoteSelection.transposed(notes, by: 0))
    }

    func testDuplicatingRepeatsThePhraseRightAfterIt() throws {
        // A phrase of one bar: two quarters, then a half note.
        let notes = [Note(pitch: 60, start: 0, length: quarter), Note(pitch: 62, start: quarter, length: quarter),
                     Note(pitch: 64, start: 2 * quarter, length: 2 * quarter)]
        var ids = 0
        let copies = try XCTUnwrap(NoteSelection.duplicated(notes, in: clip(notes), newID: { ids += 1; return NoteID() }))
        XCTAssertEqual(copies.map(\.start), [4 * quarter, 5 * quarter, 6 * quarter], "one bar later")
        XCTAssertEqual(copies.map(\.pitch), [60, 62, 64])
        XCTAssertEqual(ids, 3, "each copy a new note")
        XCTAssertTrue(Set(copies.map(\.id)).isDisjoint(with: Set(notes.map(\.id))))
        // In a one-bar clip there is no room for the copy.
        XCTAssertNil(NoteSelection.duplicated(notes, in: clip(notes, bars: 1)))
        XCTAssertNil(NoteSelection.duplicated([], in: clip([])))
        // The door takes the copies.
        var project = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        let made = clip(notes)
        try Command.createClip(track: track, id: made.id, name: "Notes", length: made.length).apply(to: &project)
        try Command.addNotes(made.id, notes).apply(to: &project)
        try Command.addNotes(made.id, copies).apply(to: &project)
        XCTAssertEqual(project.track(track)?.clips.first?.notes.count, 6)
    }

    func testLegatoJoinsEachNoteToTheNextStart() throws {
        // A chord on beat 1, a short note on beat 3, the last note on beat 4.
        let chord = [Note(pitch: 60, start: 0, length: 120), Note(pitch: 64, start: 0, length: 240)]
        let middle = Note(pitch: 67, start: 2 * quarter, length: 120)
        let last = Note(pitch: 72, start: 3 * quarter, length: 100)
        let joined = try XCTUnwrap(NoteSelection.legato(chord + [middle, last]))
        let lengths = Dictionary(uniqueKeysWithValues: joined.map { ($0.id, $0.length) })
        XCTAssertEqual(lengths[chord[0].id], 2 * quarter, "the chord ends together, where the next note starts")
        XCTAssertEqual(lengths[chord[1].id], 2 * quarter)
        XCTAssertEqual(lengths[middle.id], quarter)
        XCTAssertNil(lengths[last.id], "the last note keeps its length")
        XCTAssertNil(NoteSelection.legato([last]), "nothing to join")
        let already = [Note(pitch: 60, start: 0, length: quarter), Note(pitch: 62, start: quarter, length: quarter)]
        XCTAssertNil(NoteSelection.legato(already), "already legato: no change")
    }
}
