import Foundation
import XCTest
@testable import EchoelCore

/// What Siri and Shortcuts may change in the song (PRO-W1 slice 1): ordinary commands, one undo step.
final class ShortcutCommandsTests: XCTestCase {
    func testATempoRequestIsTheTempoCommandAndAnAbsurdOneIsRefused() throws {
        let project = Project()
        XCTAssertEqual(try ShortcutCommands.setTempo(128, in: project), [.setTempo(bpm: 128)])
        XCTAssertThrowsError(try ShortcutCommands.setTempo(5, in: project))
        XCTAssertThrowsError(try ShortcutCommands.setTempo(.nan, in: project))
    }

    func testANewTrackOfEachKindIsNamedAndAddedAsOneUndoStep() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            for choice in ShortcutCommands.TrackChoice.allCases {
                let commands = try ShortcutCommands.addTrack(choice, in: store.project)
                try store.perform(commands, title: "Add \(choice.baseName) Track")
            }
            let tracks = store.project.tracks
            XCTAssertEqual(tracks.map(\.name), ["Instrument 1", "Drums 1", "Audio 1", "Video 1"])
            XCTAssertEqual(tracks.map(\.kind), [.instrument, .instrument, .audio, .video])
            XCTAssertEqual(tracks[1].instrument.device, .drums)
            XCTAssertEqual(store.undoStack.count, 4, "each request is one step")
            XCTAssertEqual(ShortcutCommands.defaultName(for: .audio, in: store.project), "Audio 2")
            store.undo()
            XCTAssertEqual(store.project.tracks.count, 3)
            let named = try ShortcutCommands.addTrack(.audio, name: "  Vox ", in: store.project)
            try store.perform(named, title: "Add Track")
            XCTAssertEqual(store.project.tracks.last?.name, "Vox")
        }
    }

    func testAFullSongRefusesAnotherTrackOfThatKind() throws {
        var project = Project()
        for _ in 0..<Track.limit(for: .video) {
            for command in try ShortcutCommands.addTrack(.video, in: project) { try command.apply(to: &project) }
        }
        XCTAssertThrowsError(try ShortcutCommands.addTrack(.video, in: project))
    }

    func testAKeyRequestChangesOnlyWhatDiffers() throws {
        var project = Project()
        let commands = try ShortcutCommands.setKey(root: 2, scale: .minor, in: project)
        XCTAssertEqual(commands, [.setKeyRoot(2), .setScale(.minor)])
        for command in commands { try command.apply(to: &project) }
        XCTAssertEqual(try ShortcutCommands.setKey(root: 7, scale: .minor, in: project), [.setKeyRoot(7)])
        XCTAssertThrowsError(try ShortcutCommands.setKey(root: 2, scale: .minor, in: project), "already in D minor")
        XCTAssertThrowsError(try ShortcutCommands.setKey(root: 12, scale: .major, in: project))
    }

    func testASceneIsNamedByItsNumber() throws {
        var project = Project()
        let first = SceneID(), second = SceneID()
        try Command.addScene(id: first, name: "Verse", index: nil).apply(to: &project)
        try Command.addScene(id: second, name: "Chorus", index: nil).apply(to: &project)
        XCTAssertEqual(try ShortcutCommands.scene(number: 2, in: project), second)
        XCTAssertThrowsError(try ShortcutCommands.scene(number: 3, in: project)) { error in
            XCTAssertEqual((error as? ShortcutCommands.Failure)?.description, "There is no scene 3; the song has 2.")
        }
        XCTAssertThrowsError(try ShortcutCommands.scene(number: 0, in: project))
    }
}
