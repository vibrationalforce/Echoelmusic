import EchoelCore
import XCTest
@testable import EchoelEngine

/// What a starter sounds like through the engine: nothing until the musician plays, and then every
/// track — a preset at level 0 or a device that plays nothing would leave one track silent.
final class StarterSoundTests: XCTestCase {
    /// A starter holds no note, so it renders no length — which is why its export doors stay
    /// closed — and one note is enough to open them and fill the file.
    func testAStarterRendersNothingUntilANoteIsPlacedAndTheExportCheckAgrees() throws {
        for starter in StarterProject.allCases {
            var song = try starter.project()
            XCTAssertFalse(song.arrangementHasSound, "\(starter)")
            XCTAssertEqual(OfflineRender.render(song, tailSeconds: 0.5).frameCount, 0, "\(starter)")

            let track = try XCTUnwrap(song.tracks.first { $0.kind == .instrument })
            let clip = ClipID()
            try Command.createClip(track: track.id, id: clip, name: "C", length: 3_840).apply(to: &song)
            try Command.addNotes(clip, [Note(pitch: 60, start: 0, length: 960)]).apply(to: &song)
            try Command.placeClip(track: track.id, id: PlacementID(), clip: clip, start: 0).apply(to: &song)
            XCTAssertTrue(song.arrangementHasSound, "\(starter)")
            XCTAssertGreaterThan(OfflineRender.render(song, tailSeconds: 0.5).frameCount, 0, "\(starter)")
        }
    }

    func testEveryTrackOfEveryStarterSoundsWithOneNote() throws {
        for starter in StarterProject.allCases {
            let project = try starter.project()
            for track in project.tracks where track.kind == .instrument {
                var song = project
                // A kick on the drum kit, middle C anywhere else.
                let pitch = track.instrument.device == .drums ? 36 : 60
                let note = Note(pitch: pitch, start: 0, length: 960)
                if let clip = track.clips.first {
                    try Command.addNotes(clip.id, [note]).apply(to: &song)
                } else {
                    let clip = ClipID()
                    try Command.createClip(track: track.id, id: clip, name: "C", length: 3_840).apply(to: &song)
                    try Command.addNotes(clip, [note]).apply(to: &song)
                    try Command.placeClip(track: track.id, id: PlacementID(), clip: clip, start: 0).apply(to: &song)
                }
                XCTAssertGreaterThan(OfflineRender.render(song, tailSeconds: 0.5).peak, 0.001, "\(starter) \(track.name)")
            }
        }
    }
}
