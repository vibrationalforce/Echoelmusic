import Foundation
import XCTest
@testable import EchoelCore

/// The songs a new song starts from. The JSON here pins the PRODUCT, not the format: a deliberate
/// change to a starter edits its golden in the same commit. The format's own pins are
/// `FormatGoldenTests`, whose files never change.
final class StarterProjectTests: XCTestCase {
    /// The n-th id a starter asks for, so its golden can name every id.
    private static func id(_ n: UInt8) -> UUID {
        UUID(uuid: (0x5A, 0x7A, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, n))
    }

    private func made(_ starter: StarterProject) throws -> Project {
        var next: UInt8 = 0
        return try starter.project {
            next += 1
            return Self.id(next)
        }
    }

    private let empty = Data("""
    {
      "formatVersion": 2,
      "name": "New Song",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "scenes": [ { "id": "5A7A0000-0000-4000-8000-000000000002", "name": "Scene 1" } ],
      "tracks": [
        {
          "id": "5A7A0000-0000-4000-8000-000000000001",
          "name": "Instrument 1",
          "kind": "instrument",
          "colorIndex": 0,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "instrument": { "device": "synth", "preset": "Init", "values": {} },
          "clips": [],
          "placements": [],
          "slots": []
        }
      ]
    }
    """.utf8)

    func testTheEmptyStarterIsOneInstrumentTrackAndOneScene() throws {
        XCTAssertEqual(try made(.empty), try ProjectCodec.decode(empty))
        XCTAssertEqual(StarterProject.empty.title, "Empty")
    }

    /// The engine and the app tell tracks apart by id across a song switch: a second new song that
    /// reused an id would inherit the first one's voice, armed track and plugin.
    func testTwoNewSongsShareNoId() throws {
        for starter in StarterProject.allCases {
            let first = try starter.project(), second = try starter.project()
            let firstIDs = Set(first.tracks.map(\.id.rawValue) + first.scenes.map(\.id.rawValue))
            let secondIDs = Set(second.tracks.map(\.id.rawValue) + second.scenes.map(\.id.rawValue))
            XCTAssertTrue(firstIDs.isDisjoint(with: secondIDs), "\(starter)")
        }
    }

    /// No generated notes: a starter is a place to play, and every one opens as a valid song.
    func testEveryStarterHoldsNoNoteAndPassesTheSongCheck() throws {
        for starter in StarterProject.allCases {
            let project = try starter.project()
            let notes = project.tracks.flatMap(\.clips).flatMap(\.notes)
            XCTAssertTrue(notes.isEmpty, "\(starter)")
            XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(project)), project, "\(starter)")
        }
    }
}
