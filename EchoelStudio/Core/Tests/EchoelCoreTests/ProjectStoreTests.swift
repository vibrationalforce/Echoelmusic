import XCTest
@testable import EchoelCore

final class ProjectStoreTests: XCTestCase {
    func testEveryCommandIsOneUndoStepWithItsTitle() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            try store.perform(.setTempo(bpm: 140))
            try store.perform(.renameProject(name: "Night Drive"))
            XCTAssertEqual(store.undoTitle, "Rename Song")
            store.undo()
            XCTAssertEqual(store.project.name, "Untitled")
            XCTAssertEqual(store.project.tempo, 140)
            XCTAssertEqual(store.redoTitle, "Rename Song")
            store.undo()
            XCTAssertEqual(store.project.tempo, Tempo.defaultBPM)
            XCTAssertFalse(store.canUndo)
            store.redo()
            store.redo()
            XCTAssertEqual(store.project.name, "Night Drive")
            XCTAssertFalse(store.canRedo)
        }
    }

    // `async throws` although nothing is thrown at runtime: the closure passed to the
    // rethrowing `MainActor.run` is INFERRED throwing because `XCTAssertThrowsError(try …)`
    // holds a `try` syntactically inside its body (Linux run #4, Swift 6.2.4, 2026-10-19).
    func testAFailedCommandInAGroupChangesNothing() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            let track = TrackID()
            XCTAssertThrowsError(try store.perform([
                .addTrack(id: track, name: "Drums", kind: .instrument, index: nil),
                .setTempo(bpm: 5),
            ], title: "Setup"))
            XCTAssertTrue(store.project.tracks.isEmpty)
            XCTAssertFalse(store.canUndo)
        }
    }

    func testAGroupUndoesInOneStep() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            let track = TrackID(), clip = ClipID()
            try store.perform([
                .addTrack(id: track, name: "Drums", kind: .instrument, index: nil),
                .createClip(track: track, id: clip, name: "Beat", length: 3_840),
                .placeClip(track: track, id: PlacementID(), clip: clip, start: 0),
            ], title: "New Drum Track")
            XCTAssertEqual(store.undoStack.count, 1)
            store.undo()
            XCTAssertEqual(store.project, Project())
        }
    }

    func testAbsorbedStateIsNoStepKeepsRedoAndSurvivesUndo() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            let track = TrackID()
            try store.perform(.addTrack(id: track, name: "Keys", kind: .instrument, index: nil))
            try store.perform(.setTempo(bpm: 140))
            try store.perform(.renameProject(name: "Night"))
            store.undo()
            try store.absorb([.setTrackColor(track, colorIndex: 3)])
            XCTAssertEqual(store.undoStack.count, 2, "no step of its own")
            XCTAssertEqual(store.redoTitle, "Rename Song", "and redo is kept")
            store.redo()
            XCTAssertEqual(store.project.name, "Night")
            XCTAssertEqual(store.project.tracks.first?.colorIndex, 3, "redo keeps the absorbed state")
            store.undo()
            store.undo()
            XCTAssertEqual(store.project.tracks.first?.colorIndex, 3, "so does undo")
            store.undo()
            XCTAssertTrue(store.project.tracks.isEmpty, "a step before the track existed stays as it was")
            XCTAssertThrowsError(try store.absorb([.setTrackColor(TrackID(), colorIndex: 1)]))
        }
    }

    /// A plugin's settings belong to the plugin they were captured from: absorbing them never
    /// writes them into a step where the track held another plugin — Choose Plugin's before on
    /// undo, its after on redo (review 2026-10-23).
    func testAbsorbedPluginSettingsStayWithTheirPlugin() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            let track = TrackID()
            let first = PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("Mini"),
                                        manufacturer: PluginComponent.code("Acme"), name: "Mini", manufacturerName: "Acme")
            let second = PluginComponent(type: PluginComponent.code("aumu"), subtype: PluginComponent.code("Maxi"),
                                         manufacturer: PluginComponent.code("Acme"), name: "Maxi", manufacturerName: "Acme")
            let firstSettings = Data([1])
            let secondSettings = Data([2])
            let laterFirstSettings = Data([3])
            try store.perform(.addTrack(id: track, name: "Keys", kind: .instrument, index: nil))
            try store.perform(.setInstrumentPlugin(track, first))
            try store.absorb([.setPluginState(track, firstSettings)])
            try store.perform(.setInstrumentPlugin(track, second))
            try store.absorb([.setPluginState(track, secondSettings)])
            XCTAssertEqual(store.project.tracks.first?.instrument.pluginState, secondSettings)
            store.undo()
            XCTAssertEqual(store.project.tracks.first?.instrument.plugin, first)
            XCTAssertEqual(store.project.tracks.first?.instrument.pluginState, firstSettings,
                           "the first plugin comes back with its own settings")
            try store.absorb([.setPluginState(track, laterFirstSettings)])
            store.redo()
            XCTAssertEqual(store.project.tracks.first?.instrument.plugin, second)
            XCTAssertEqual(store.project.tracks.first?.instrument.pluginState, secondSettings,
                           "and the second with its own on redo")
            store.undo()
            XCTAssertEqual(store.project.tracks.first?.instrument.pluginState, laterFirstSettings)
        }
    }

    func testACommandThatChangesNothingAddsNoStep() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            try store.perform(.setTempo(bpm: Tempo.defaultBPM))
            XCTAssertFalse(store.canUndo)
        }
    }

    func testAFaderDragUndoesInOneStepAndTheNextDragIsItsOwn() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            for db in stride(from: -1.0, through: -12.0, by: -1.0) {
                try store.perform(.setVolume(.master, db: db), coalescingKey: "master.volume")
            }
            store.endGesture()
            try store.perform(.setVolume(.master, db: -3), coalescingKey: "master.volume")
            XCTAssertEqual(store.undoStack.count, 2)
            store.undo()
            XCTAssertEqual(store.project.master.volumeDB, -12)
            store.undo()
            XCTAssertEqual(store.project.master.volumeDB, 0)
        }
    }

    func testANewEditClearsRedo() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            try store.perform(.setTempo(bpm: 100))
            store.undo()
            try store.perform(.setTempo(bpm: 90))
            XCTAssertFalse(store.canRedo)
        }
    }

    func testUndoKeepsAtMostTheLimit() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            store.undoLimit = 3
            for bpm in [100.0, 101, 102, 103, 104] {
                try store.perform(.setTempo(bpm: bpm))
            }
            XCTAssertEqual(store.undoStack.count, 3)
            store.undo(); store.undo(); store.undo()
            XCTAssertEqual(store.project.tempo, 101)
        }
    }

    func testOpeningAProjectClearsHistory() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            try store.perform(.setTempo(bpm: 100))
            let before = store.documentGeneration
            store.open(Project(name: "Other"))
            XCTAssertFalse(store.canUndo)
            XCTAssertEqual(store.project.name, "Other")
            XCTAssertEqual(store.documentGeneration, before + 1, "work started on the old song can tell")
        }
    }
}
