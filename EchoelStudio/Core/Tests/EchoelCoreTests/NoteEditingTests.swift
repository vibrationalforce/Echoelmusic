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

    // MARK: Add Note (VoiceOver writes without a finger on the grid)

    private func added(_ command: Command?) -> [Note] {
        guard case let .addNotes(_, notes)? = command else { return [] }
        return notes
    }

    func testAddNoteInAnEmptyClipWritesC4AtTheStart() {
        let c = clip()
        let notes = added(NoteEditing.addAfterLast(in: c, grid: step))
        XCTAssertEqual(notes.map(\.pitch), [60])
        XCTAssertEqual(notes.map(\.start), [0])
        XCTAssertEqual(notes.map(\.length), [step])
    }

    func testAddNoteFollowsTheLastNoteOneStepLaterAtItsPitch() {
        let first = Note(pitch: 64, start: 0, length: step)
        let notes = added(NoteEditing.addAfterLast(in: clip([first]), grid: step))
        XCTAssertEqual(notes.map(\.pitch), [64])
        XCTAssertEqual(notes.map(\.start), [step])
        let line = clip([first] + notes)
        XCTAssertEqual(added(NoteEditing.addAfterLast(in: line, grid: step)).map(\.start), [2 * step],
                       "done again, it writes the next note of a line")
    }

    func testAddNoteStartsAfterTheNoteThatEndsLastOnTheNextGridLine() {
        let long = Note(pitch: 60, start: 0, length: 960)
        let short = Note(pitch: 67, start: 240, length: 240)
        let after = added(NoteEditing.addAfterLast(in: clip([long, short]), grid: step))
        XCTAssertEqual(after.map(\.start), [960], "a short later note does not hide the long one still sounding")
        XCTAssertEqual(after.map(\.pitch), [60])
        let offGrid = Note(pitch: 62, start: 0, length: 250)
        XCTAssertEqual(added(NoteEditing.addAfterLast(in: clip([offGrid]), grid: step)).map(\.start), [480],
                       "an end off the grid goes to the next grid line, never onto the note")
        let chord = [Note(pitch: 60, start: 0, length: 240), Note(pitch: 64, start: 0, length: 240)]
        XCTAssertEqual(added(NoteEditing.addAfterLast(in: clip(chord), grid: step)).map(\.pitch), [64],
                       "of notes ending together, the one written last")
    }

    func testAddNoteHasNoRoomAfterANoteThatEndsTheClip() {
        XCTAssertNil(NoteEditing.addAfterLast(in: clip([Note(pitch: 60, start: bar - step, length: step)]), grid: step))
        XCTAssertNil(NoteEditing.addAfterLast(in: clip([Note(pitch: 60, start: 0, length: bar * 2)]), grid: step))
        XCTAssertNil(NoteEditing.addAfterLast(in: clip([Note(pitch: 60, start: 0, length: bar - 100)]), grid: step),
                     "the next grid line is the clip's end")
        let odd = Clip(name: "odd", length: 1_000, notes: [Note(pitch: 60, start: 0, length: 960)])
        XCTAssertEqual(added(NoteEditing.addAfterLast(in: odd, grid: 960)).map(\.length), [40],
                       "a last step shorter than the grid gets what is left, as a tap there does")
    }

    func testAddNoteProducesACommandTheDoorAccepts() throws {
        var project = Project()
        let track = TrackID(), clipID = ClipID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clipID, name: "C", length: bar).apply(to: &project)
        for _ in 0..<3 {
            let current = try XCTUnwrap(project.clip(clipID))
            try XCTUnwrap(NoteEditing.addAfterLast(in: current, grid: step)).apply(to: &project)
        }
        XCTAssertEqual(try XCTUnwrap(project.clip(clipID)).notes.map(\.start), [0, step, 2 * step])
    }

    // MARK: The note's actions

    func testANudgeMovesExactlyThatFarOrNotAtAll() throws {
        let c = clip()
        let recorded = Note(pitch: 60, start: 1_937, length: 200)
        let up = try XCTUnwrap(NoteEditing.nudged(recorded, semitones: 12, in: c))
        XCTAssertEqual(up.pitch, 72)
        XCTAssertEqual(up.start, 1_937, "a pitch change keeps a recorded note's timing")
        XCTAssertEqual(up.id, recorded.id)
        XCTAssertEqual(try XCTUnwrap(NoteEditing.nudged(recorded, byTicks: step, in: c)).start, 1_937 + step)
        XCTAssertNil(NoteEditing.nudged(recorded, byTicks: bar, in: c), "a bar later leaves a one-bar clip")
        XCTAssertNil(NoteEditing.nudged(recorded, byTicks: -bar, in: c))
        XCTAssertNil(NoteEditing.nudged(Note(pitch: 120, start: 0, length: step), semitones: 12, in: c),
                     "an octave up from C9 leaves the keyboard; it does not stop short at G9")
        XCTAssertNil(NoteEditing.nudged(Note(pitch: 5, start: 0, length: step), semitones: -12, in: c))
        XCTAssertEqual(NoteEditing.nudged(Note(pitch: 127, start: 0, length: step), semitones: -1, in: c)?.pitch, 126)
    }

    func testLongerAndShorterChangeTheLengthByWholeSteps() throws {
        let c = clip()
        let note = Note(pitch: 60, start: 960, length: step)
        let longer = try XCTUnwrap(NoteEditing.resized(note, bySteps: 1, grid: step, in: c))
        XCTAssertEqual(longer.length, 2 * step)
        XCTAssertEqual(try XCTUnwrap(NoteEditing.resized(longer, bySteps: -1, grid: step, in: c)).length, step)
        XCTAssertNil(NoteEditing.resized(note, bySteps: -1, grid: step, in: c), "one step is the shortest")
        XCTAssertNil(NoteEditing.resized(Note(pitch: 60, start: bar - step, length: step), bySteps: 1, grid: step, in: c),
                     "the clip ends there")
        XCTAssertNil(NoteEditing.resized(Note(pitch: 60, start: 0, length: 100), bySteps: -1, grid: step, in: c),
                     "Shorter never makes a note longer")
    }

    // MARK: Said aloud

    func testPositionsAreSaidInBarsAndBeats() {
        func said(_ tick: Tick, _ signature: TimeSignature = .common, grid: Tick? = nil) -> String {
            NoteEditing.spokenPosition(tick, signature: signature, grid: grid ?? step)
        }
        XCTAssertEqual(said(0), "bar 1, beat 1")
        XCTAssertEqual(said(1_920), "bar 1, beat 3")
        XCTAssertEqual(said(2_160), "bar 1, beat 3, plus one sixteenth")
        XCTAssertEqual(said(2_400), "bar 1, beat 3, plus 2 sixteenths")
        XCTAssertEqual(said(bar), "bar 2, beat 1")
        XCTAssertEqual(said(2_880, TimeSignature(3, 4)), "bar 2, beat 1")
        XCTAssertEqual(said(1_937), "about bar 1, beat 3", "a recorded note is said at the nearest grid line")
        XCTAssertEqual(said(2_147), "about bar 1, beat 3, plus one sixteenth")
        XCTAssertEqual(said(320, grid: 320), "bar 1, beat 1, plus one eighth triplet")
        XCTAssertEqual(said(640, TimeSignature(6, 8), grid: 320), "bar 1, beat 2, plus one sixteenth triplet",
                       "a triplet line past an eighth-note beat")
    }

    func testLengthsAreSaidInGridSteps() {
        XCTAssertEqual(NoteEditing.spokenLength(step, grid: step), "one sixteenth")
        XCTAssertEqual(NoteEditing.spokenLength(3 * step, grid: step), "3 sixteenths")
        XCTAssertEqual(NoteEditing.spokenLength(960, grid: 960), "one quarter")
        XCTAssertEqual(NoteEditing.spokenLength(640, grid: 320), "2 eighth triplets")
        XCTAssertEqual(NoteEditing.spokenLength(227, grid: step), "about one sixteenth")
        XCTAssertEqual(NoteEditing.spokenLength(100, grid: step), "less than one sixteenth")
    }

    func testANoteIsSaidWithItsPlaceLengthAndVelocity() {
        let note = Note(pitch: 60, velocity: 100, start: 1_920, length: 240)
        XCTAssertEqual(NoteEditing.spokenDetails(of: note, signature: .common, grid: step),
                       "bar 1, beat 3, one sixteenth long, velocity 100")
    }

    func testADrumStepIsSaidWithItsBeatAndInALongerClipItsBar() {
        func said(_ index: Int, bars: Tick = 1) -> String {
            NoteEditing.spokenStep(index, step: step, signature: .common, clipLength: bars * bar)
        }
        XCTAssertEqual(said(0), "step 1, beat 1")
        XCTAssertEqual(said(4), "step 5, beat 2")
        XCTAssertEqual(said(5), "step 6, beat 2")
        XCTAssertEqual(said(20, bars: 2), "step 21, bar 2, beat 2")
        XCTAssertEqual(said(0, bars: 2), "step 1, bar 1, beat 1")
    }
}
