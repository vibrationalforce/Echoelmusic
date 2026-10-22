import EchoelCore
import XCTest
@testable import EchoelEngine

/// What a starter sounds like through the engine: nothing until the musician plays, and then every
/// track — a preset at level 0 or a device that plays nothing would leave one track silent.
final class StarterSoundTests: XCTestCase {
    func testEveryStarterIsSilentUntilSomethingIsPlayed() throws {
        for starter in StarterProject.allCases {
            XCTAssertEqual(OfflineRender.render(try starter.project(), tailSeconds: 0.5).peak, 0, "\(starter)")
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
