import XCTest
@testable import EchoelCore

/// Two edits at the one door (`ProjectStore.perform`), on a song that holds more than a tempo: a
/// tempo change touches the tempo and nothing else and is one undo step; a pan the door refuses
/// leaves the song AND an open redo exactly as they were.
final class TempoAndPanAtTheDoorTests: XCTestCase {
    /// The Four Tracks starter plus a note, a pan and a tempo change later in the song, so a stray
    /// write anywhere would show.
    private func song() throws -> (project: Project, keys: TrackID) {
        var project = try StarterProject.fourTracks.project()
        let keys = try XCTUnwrap(project.tracks.first?.id)
        let clip = ClipID()
        try Command.createClip(track: keys, id: clip, name: "Riff", length: 3_840).apply(to: &project)
        try Command.addNotes(clip, [Note(pitch: 64, start: 480, length: 240)]).apply(to: &project)
        try Command.placeClip(track: keys, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        try Command.setPan(.track(keys), pan: -0.25).apply(to: &project)
        try Command.setTempoChange(at: 4 * 3_840, bpm: 90).apply(to: &project)
        return (project, keys)
    }

    func testATempoChangeAltersOnlyTheTempoAndOneUndoBringsTheSongBack() async throws {
        let s = try song()
        try await MainActor.run {
            let store = ProjectStore(project: s.project)
            try store.perform(.setTempo(bpm: 97))
            var expected = s.project
            expected.tempo = 97
            XCTAssertEqual(store.project, expected, "every other part of the song is as it was")
            XCTAssertEqual(store.project.tempoChanges, s.project.tempoChanges, "the later tempo change stays")
            XCTAssertEqual(store.undoStack.count, 1, "one step")
            store.undo()
            XCTAssertEqual(store.project, s.project, "one undo and the song is back, whole")
            XCTAssertFalse(store.canUndo)
            XCTAssertTrue(store.canRedo)
        }
    }

    func testAPanTheDoorRefusesLeavesTheSongAndTheOpenRedoAsTheyWere() async throws {
        let s = try song()
        try await MainActor.run {
            let store = ProjectStore(project: s.project)
            try store.perform(.setPan(.track(s.keys), pan: 0.5))
            store.undo()
            let before = store.project, redo = store.redoStack, undo = store.undoStack
            XCTAssertEqual(redo.count, 1, "a redo is open")

            for bad in [1.5, -1.0001, Double.nan, Double.infinity, -Double.infinity] {
                XCTAssertThrowsError(try store.perform(.setPan(.track(s.keys), pan: bad)), "pan \(bad)")
                XCTAssertThrowsError(try store.perform(.setPan(.master, pan: bad)), "master pan \(bad)")
                XCTAssertEqual(store.project, before, "pan \(bad): the song is untouched")
                XCTAssertEqual(store.redoStack, redo, "pan \(bad): the redo is still there")
                XCTAssertEqual(store.undoStack, undo, "pan \(bad): no step")
            }
            store.redo()
            XCTAssertEqual(store.project.tracks.first?.mixer.pan, 0.5, "and the redo still brings the pan back")
        }
    }
}
