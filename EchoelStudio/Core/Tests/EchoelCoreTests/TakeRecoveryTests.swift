import XCTest
@testable import EchoelCore

final class TakeRecoveryTests: XCTestCase {
    private let saved = Date(timeIntervalSince1970: 1_000_000)

    private func later(_ seconds: Double) -> Date { saved.addingTimeInterval(seconds) }

    /// Only `<UUID>.caf` files written after the document, that the song does not hold, are lost
    /// takes — oldest first. An older file was let go on purpose (an Undo, a deleted region), an
    /// import keeps its own name, and a take the song names is not lost.
    func testALostTakeIsATakeFileNewerThanTheSongThatTheSongDoesNotName() throws {
        let kept = MediaID()
        var project = Project()
        try Command.addMedia(MediaFile(id: kept, name: "Take 1", path: "Media/\(kept).caf",
                                       frameCount: 48_000, sampleRate: 48_000)).apply(to: &project)
        let first = MediaID()
        let second = MediaID()
        let undone = MediaID()
        let files = [
            TakeRecovery.FolderFile(name: "\(second).caf", modified: later(9)),
            TakeRecovery.FolderFile(name: "\(kept).caf", modified: later(5)),
            TakeRecovery.FolderFile(name: "\(undone).caf", modified: later(-60)),
            TakeRecovery.FolderFile(name: "\(first).caf", modified: later(3)),
            TakeRecovery.FolderFile(name: "drums.wav", modified: later(4)),
            TakeRecovery.FolderFile(name: "not-a-uuid.caf", modified: later(4)),
        ]
        let found = TakeRecovery.orphans(in: project, files: files, documentModified: saved)
        XCTAssertEqual(found.map(\.id), [first, second])
        XCTAssertEqual(found.map(\.path), ["Media/\(first).caf", "Media/\(second).caf"])
        XCTAssertEqual(TakeRecovery.orphans(in: project, files: files, documentModified: nil).map(\.id),
                       [undone, first, second], "without a document date every lost-looking take counts")
    }

    /// The takes come back on one new audio track, back to back from the start, as one list of
    /// commands the door accepts; a take without a usable length is left out.
    func testLostTakesComeBackOnOneNewTrackBackToBack() throws {
        var project = Project()
        try Command.setTempo(bpm: 120).apply(to: &project)
        let first = TakeRecovery.Take(id: MediaID(), path: "Media/a.caf", frameCount: 96_000, sampleRate: 48_000)
        let empty = TakeRecovery.Take(id: MediaID(), path: "Media/b.caf", frameCount: 0, sampleRate: 48_000)
        let second = TakeRecovery.Take(id: MediaID(), path: "Media/c.caf", frameCount: 44_100, sampleRate: 44_100)
        let track = TrackID()
        let commands = try XCTUnwrap(TakeRecovery.commands(for: project, takes: [first, empty, second], track: track))
        for command in commands { try command.apply(to: &project) }

        let recovered = try XCTUnwrap(project.tracks.first { $0.id == track })
        XCTAssertEqual(recovered.kind, .audio)
        XCTAssertEqual(recovered.name, TakeRecovery.trackName)
        XCTAssertEqual(recovered.regions.map(\.media), [first.id, second.id])
        XCTAssertEqual(recovered.regions.first?.start, 0)
        XCTAssertEqual(recovered.regions.last?.start, project.tempoMap.tick(atSeconds: 2), "after two seconds of the first take")
        XCTAssertEqual(project.media.map(\.name), ["Recovered Take 1", "Recovered Take 2"])
        XCTAssertNil(project.mediaFile(empty.id))

        XCTAssertNil(TakeRecovery.commands(for: project, takes: [empty]), "nothing usable, nothing to do")
        XCTAssertNil(TakeRecovery.commands(for: project, takes: [first]), "a take the song holds now is not added twice")
    }
}
