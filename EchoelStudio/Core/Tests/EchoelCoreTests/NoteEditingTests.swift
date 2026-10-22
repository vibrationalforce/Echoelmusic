import XCTest
@testable import EchoelCore

final class NoteEditingTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)
    private let step = NoteEditing.Grid.sixteenth.rawValue

    private func clip(_ notes: [Note] = []) -> Clip {
        Clip(name: "C", length: bar, notes: notes)
    }

    func testSnappingRoundsDownToTheGrid() {
        XCTAssertEqual(NoteEditing.snap(479, to: 240), 240)
        XCTAssertEqual(NoteEditing.snap(480, to: 240), 480)
        XCTAssertEqual(NoteEditing.snap(-5, to: 240), 0)
        XCTAssertEqual(NoteEditing.snap(77, to: 0), 77)
        XCTAssertEqual(NoteEditing.Grid.allCases.map(\.rawValue).filter { 960 % $0 != 0 }, [], "every grid divides a beat")
    }

    func testATapOnEmptySpaceAddsOneSnappedStep() throws {
        let c = clip()
        let command = try XCTUnwrap(NoteEditing.tap(in: c, pitch: 60, tick: 500, grid: step))
        guard case let .addNotes(id, notes) = command else { return XCTFail("\(command)") }
        XCTAssertEqual(id, c.id)
        XCTAssertEqual(notes.map(\.start), [480])
        XCTAssertEqual(notes.map(\.length), [step])
        XCTAssertEqual(notes.map(\.pitch), [60])
    }

    func testATapOnANoteRemovesIt() throws {
        let note = Note(pitch: 64, start: 0, length: 960)
        let c = clip([note])
        XCTAssertEqual(NoteEditing.tap(in: c, pitch: 64, tick: 900, grid: step), .removeNotes(c.id, [note.id]))
        XCTAssertNotEqual(NoteEditing.tap(in: c, pitch: 64, tick: 960, grid: step), .removeNotes(c.id, [note.id]),
                          "the note ends before tick 960")
    }

    func testTapsOutsideTheClipOrKeyboardDoNothing() {
        let c = clip()
        XCTAssertNil(NoteEditing.tap(in: c, pitch: 128, tick: 0, grid: step))
        XCTAssertNil(NoteEditing.tap(in: c, pitch: -1, tick: 0, grid: step))
        XCTAssertNil(NoteEditing.tap(in: c, pitch: 60, tick: bar, grid: step))
        XCTAssertNil(NoteEditing.tap(in: c, pitch: 60, tick: -1, grid: step))
    }

    func testANoteAddedAtTheClipEndIsShortenedToFit() throws {
        let c = Clip(name: "odd", length: 1_000)
        let command = try XCTUnwrap(NoteEditing.tap(in: c, pitch: 60, tick: 999, grid: 960))
        guard case let .addNotes(_, notes) = command else { return XCTFail() }
        XCTAssertEqual(notes.first?.start, 960)
        XCTAssertEqual(notes.first?.length, 40)
        var project = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: "K", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: c.id, name: c.name, length: c.length).apply(to: &project)
        XCTAssertNoThrow(try command.apply(to: &project), "the produced command passes validation")
    }

    func testMovingSnapsAndStaysInsideTheClipAndKeyboard() {
        let c = clip()
        let note = Note(pitch: 120, start: 240, length: 240)
        let right = NoteEditing.moved(note, byTicks: 130, semitones: 12, grid: step, in: c)
        XCTAssertEqual(right.start, 480)                  // 370 → nearest step
        XCTAssertEqual(right.pitch, 127)
        let left = NoteEditing.moved(note, byTicks: -10_000, semitones: -200, grid: step, in: c)
        XCTAssertEqual(left.start, 0)
        XCTAssertEqual(left.pitch, 0)
        XCTAssertEqual(NoteEditing.moved(note, byTicks: 99_999, semitones: 0, grid: step, in: c).start, bar - 1)
        XCTAssertEqual(left.id, note.id)
    }

    func testResizingSnapsTheEndAndKeepsAMinimum() {
        let c = clip()
        let note = Note(pitch: 60, start: 960, length: 240)
        XCTAssertEqual(NoteEditing.resized(note, toEnd: 1_700, grid: step, in: c).length, 720)
        XCTAssertEqual(NoteEditing.resized(note, toEnd: 0, grid: step, in: c).length, step)
        XCTAssertEqual(NoteEditing.resized(note, toEnd: 99_999, grid: step, in: c).length, bar - 960)
    }

    /// Grabbing a 1/16 note's right edge and dragging right keeps lengthening it on every event:
    /// the choice is made from the note as the drag found it, never from the grown note.
    func testADragOnTheRightEdgeStaysAResizeWhileTheNoteGrows() {
        let origin = Note(pitch: 60, start: 0, length: step)
        let points = 28.0 / Double(step)
        func takesTheEnd(_ x: Double, _ note: Note) -> Bool {
            NoteEditing.dragTakesTheEnd(of: note, startX: x, pointsPerTick: points, edgeWidth: 14, minimumWidth: 6)
        }
        XCTAssertTrue(takesTheEnd(20, origin), "inside the 14-point edge")
        XCTAssertFalse(takesTheEnd(10, origin), "the body moves")
        let grown = NoteEditing.resized(origin, toEnd: 2 * step, grid: step, in: clip())
        XCTAssertEqual(grown.length, 2 * step)
        XCTAssertFalse(takesTheEnd(20, grown), "measured on the grown note, the same grab would read as a move")
        XCTAssertTrue(takesTheEnd(20, origin), "so the drag asks the note it started on, and stays a resize")
        XCTAssertTrue(takesTheEnd(4, Note(pitch: 60, start: 0, length: 1)), "a sliver of a note: half of its least width is the edge")
    }

    func testNoteNamesAndKeys() {
        XCTAssertEqual(NoteEditing.name(of: 60), "C4")
        XCTAssertEqual(NoteEditing.name(of: 69), "A4")
        XCTAssertEqual(NoteEditing.name(of: 0), "C-1")
        XCTAssertTrue(NoteEditing.isBlackKey(61))
        XCTAssertFalse(NoteEditing.isBlackKey(64))
    }
}
