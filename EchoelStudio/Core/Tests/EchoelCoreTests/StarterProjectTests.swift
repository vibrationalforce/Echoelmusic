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

    private let fourTracks = Data("""
    {
      "formatVersion": 2,
      "name": "New Song",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "scenes": [ { "id": "5A7A0000-0000-4000-8000-000000000007", "name": "Scene 1" } ],
      "tracks": [
        {
          "id": "5A7A0000-0000-4000-8000-000000000001",
          "name": "Keys",
          "kind": "instrument",
          "colorIndex": 0,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "instrument": { "device": "synth", "preset": "Soft Keys", "values": { "synth.waveform": 3, "synth.cutoff": 2500, "synth.resonance": 0.2, "synth.filterAmount": 1, "synth.filterDecay": 0.6, "synth.attack": 0.004, "synth.decay": 0.8, "synth.sustain": 0.3, "synth.release": 0.5, "synth.level": 0.3 } },
          "clips": [],
          "placements": [],
          "slots": []
        },
        {
          "id": "5A7A0000-0000-4000-8000-000000000002",
          "name": "Bass",
          "kind": "instrument",
          "colorIndex": 1,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "instrument": { "device": "synth", "preset": "Sub Bass", "values": { "synth.waveform": 0, "synth.cutoff": 300, "synth.resonance": 0.1, "synth.filterAmount": 0.5, "synth.filterDecay": 0.3, "synth.attack": 0.003, "synth.decay": 0.3, "synth.sustain": 0.9, "synth.release": 0.12, "synth.level": 0.35 } },
          "clips": [],
          "placements": [],
          "slots": []
        },
        {
          "id": "5A7A0000-0000-4000-8000-000000000003",
          "name": "Lead",
          "kind": "instrument",
          "colorIndex": 2,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "instrument": { "device": "synth", "preset": "Square Lead", "values": { "synth.waveform": 2, "synth.cutoff": 1800, "synth.resonance": 0.4, "synth.filterAmount": 2, "synth.filterDecay": 0.4, "synth.attack": 0.005, "synth.decay": 0.3, "synth.sustain": 0.7, "synth.release": 0.25, "synth.level": 0.22 } },
          "clips": [],
          "placements": [],
          "slots": []
        },
        {
          "id": "5A7A0000-0000-4000-8000-000000000004",
          "name": "Drums",
          "kind": "instrument",
          "colorIndex": 3,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "instrument": { "device": "drums", "preset": "Init", "values": {} },
          "clips": [ { "id": "5A7A0000-0000-4000-8000-000000000005", "name": "Beat", "length": 3840, "notes": [] } ],
          "placements": [ { "id": "5A7A0000-0000-4000-8000-000000000006", "clip": "5A7A0000-0000-4000-8000-000000000005", "start": 0 } ],
          "slots": []
        }
      ]
    }
    """.utf8)

    /// Keys first: a plugged-in keyboard plays the first instrument track, and the kit plays drum keys only.
    func testTheFourTrackStarterIsKeysBassLeadAndAnEmptyBeat() throws {
        XCTAssertEqual(try made(.fourTracks), try ProjectCodec.decode(fourTracks))
        XCTAssertEqual(StarterProject.fourTracks.title, "Four Tracks")
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
