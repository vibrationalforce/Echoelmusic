import XCTest
@testable import EchoelCore

final class StepEditingTests: XCTestCase {
    private let step = NoteEditing.Grid.sixteenth.rawValue
    private let kick = 36

    private func project() throws -> (Project, ClipID) {
        var project = Project()
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "Drums", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "Beat",
                               length: MusicalTime.ticksPerBar(.common)).apply(to: &project)
        return (project, clip)
    }

    private func clip(_ p: Project, _ id: ClipID) throws -> Clip { try XCTUnwrap(p.clip(id)) }

    func testAOneBarClipHasSixteenSixteenths() throws {
        let (p, id) = try project()
        XCTAssertEqual(StepEditing.stepCount(of: try clip(p, id), step: step), 16)
        XCTAssertEqual(StepEditing.stepCount(of: try clip(p, id), step: 0), 1)
    }

    func testTogglingAStepOnAddsOneStepLongHitAndOffRemovesIt() throws {
        var (p, id) = try project()
        try XCTUnwrap(StepEditing.toggle(in: try clip(p, id), pitch: kick, step: 4, step: step)).apply(to: &p)
        let note = try XCTUnwrap(try clip(p, id).notes.first)
        XCTAssertEqual(note.pitch, kick)
        XCTAssertEqual(note.start, 4 * step)
        XCTAssertEqual(note.length, step)
        XCTAssertEqual(note.velocity, StepEditing.normalVelocity)
        XCTAssertNotNil(StepEditing.hit(in: try clip(p, id), pitch: kick, step: 4, step: step))
        XCTAssertNil(StepEditing.hit(in: try clip(p, id), pitch: 38, step: 4, step: step), "other lanes stay off")

        try XCTUnwrap(StepEditing.toggle(in: try clip(p, id), pitch: kick, step: 4, step: step)).apply(to: &p)
        XCTAssertTrue(try clip(p, id).notes.isEmpty)
    }

    func testAnOffGridHitShowsInItsStepAndATapClearsIt() throws {
        var (p, id) = try project()
        try Command.addNotes(id, [Note(pitch: kick, start: 2 * step + 13, length: 30)]).apply(to: &p)
        XCTAssertNotNil(StepEditing.hit(in: try clip(p, id), pitch: kick, step: 2, step: step))
        try XCTUnwrap(StepEditing.toggle(in: try clip(p, id), pitch: kick, step: 2, step: step)).apply(to: &p)
        XCTAssertTrue(try clip(p, id).notes.isEmpty)
    }

    func testStepsOutsideTheClipDoNothing() throws {
        let (p, id) = try project()
        let c = try clip(p, id)
        XCTAssertNil(StepEditing.toggle(in: c, pitch: kick, step: 16, step: step))
        XCTAssertNil(StepEditing.toggle(in: c, pitch: kick, step: -1, step: step))
        XCTAssertNil(StepEditing.toggle(in: c, pitch: 128, step: 0, step: step))
    }

    func testAccentFlipsTheVelocityBothWays() throws {
        var (p, id) = try project()
        XCTAssertNil(StepEditing.toggleAccent(in: try clip(p, id), pitch: kick, step: 0, step: step))
        try XCTUnwrap(StepEditing.toggle(in: try clip(p, id), pitch: kick, step: 0, step: step)).apply(to: &p)
        try XCTUnwrap(StepEditing.toggleAccent(in: try clip(p, id), pitch: kick, step: 0, step: step)).apply(to: &p)
        XCTAssertEqual(try clip(p, id).notes.first?.velocity, StepEditing.accentVelocity)
        try XCTUnwrap(StepEditing.toggleAccent(in: try clip(p, id), pitch: kick, step: 0, step: step)).apply(to: &p)
        XCTAssertEqual(try clip(p, id).notes.first?.velocity, StepEditing.normalVelocity)
    }

    func testClearingALaneLeavesTheOthers() throws {
        var (p, id) = try project()
        for (pitch, s) in [(kick, 0), (kick, 8), (38, 4)] {
            try XCTUnwrap(StepEditing.toggle(in: try clip(p, id), pitch: pitch, step: s, step: step)).apply(to: &p)
        }
        try XCTUnwrap(StepEditing.clearLane(in: try clip(p, id), pitch: kick)).apply(to: &p)
        XCTAssertEqual(try clip(p, id).notes.map(\.pitch), [38])
        XCTAssertNil(StepEditing.clearLane(in: try clip(p, id), pitch: kick))
    }

    func testTheKitIsGeneralMIDIAndHasNoDuplicates() {
        let pitches = DrumLane.standardKit.map(\.pitch)
        XCTAssertEqual(Set(pitches).count, pitches.count)
        XCTAssertEqual(DrumLane.standardKit.last?.pitch, 36, "the kick sits at the bottom")
        XCTAssertTrue(pitches.allSatisfy(Note.pitchRange.contains))
    }
}
