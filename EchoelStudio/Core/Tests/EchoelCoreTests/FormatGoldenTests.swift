import Foundation
import XCTest
@testable import EchoelCore

/// The song format as `docs/FORMAT.md` describes it. These files are written by hand, the way
/// the earliest format-1 builds and today's build wrote them; each must keep opening for as long
/// as format 1 is supported. A change that breaks one is a format change: bump
/// `Project.currentFormatVersion` and migrate, never edit the golden file to match.
final class FormatGoldenTests: XCTestCase {
    /// The first format-1 shape: only the keys those builds wrote.
    private let earliest = Data("""
    {
      "formatVersion": 1,
      "name": "First",
      "tempo": 96,
      "timeSignature": { "numerator": 3, "denominator": 4 },
      "master": { "volumeDB": -3, "pan": 0, "isMuted": false, "isSoloed": false },
      "scenes": [ { "id": "5CE7E000-0000-4000-8000-000000000001", "name": "A" } ],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-000000000001",
          "name": "Keys",
          "kind": "instrument",
          "colorIndex": 2,
          "mixer": { "volumeDB": 0, "pan": -0.5, "isMuted": false, "isSoloed": false },
          "clips": [
            {
              "id": "C1000000-0000-4000-8000-000000000001",
              "name": "Verse",
              "length": 3840,
              "notes": [
                { "id": "40000000-0000-4000-8000-000000000001", "pitch": 60, "velocity": 100, "start": 0, "length": 960 }
              ]
            }
          ],
          "placements": [
            { "id": "B1000000-0000-4000-8000-000000000001", "clip": "C1000000-0000-4000-8000-000000000001", "start": 2880 }
          ],
          "slots": [
            { "scene": "5CE7E000-0000-4000-8000-000000000001", "clip": "C1000000-0000-4000-8000-000000000001" }
          ]
        }
      ]
    }
    """.utf8)

    /// Today's additions on top: tempo changes, a stored sound, controllers in a clip, a return.
    private let current = Data("""
    {
      "formatVersion": 1,
      "name": "Now",
      "tempo": 120,
      "tempoChanges": [ { "tick": 7680, "bpm": 90 } ],
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "masterInserts": [],
      "media": [],
      "midiMappings": [],
      "automation": [],
      "scenes": [],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-000000000002",
          "name": "Lead",
          "kind": "instrument",
          "colorIndex": 0,
          "mixer": { "volumeDB": -6, "pan": 0, "isMuted": false, "isSoloed": true },
          "instrument": { "device": "synth", "preset": "Init", "values": { "synth.cutoff": 1200, "some.future.key": 3 } },
          "clips": [
            {
              "id": "C1000000-0000-4000-8000-000000000002",
              "name": "Bend",
              "length": 3840,
              "notes": [],
              "controls": [
                { "id": "CC000000-0000-4000-8000-000000000001", "kind": { "controller": { "number": 64 } }, "start": 0, "value": 127 },
                { "id": "CC000000-0000-4000-8000-000000000002", "kind": { "pitchBend": {} }, "start": 480, "value": 12000 }
              ]
            }
          ],
          "placements": [],
          "slots": [],
          "regions": [],
          "inserts": [],
          "sends": [],
          "monitor": "auto"
        },
        {
          "id": "7A000000-0000-4000-8000-000000000003",
          "name": "Space",
          "kind": "returnTrack",
          "colorIndex": 5,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": []
        }
      ]
    }
    """.utf8)

    func testTheEarliestFormatOneFileStillOpens() throws {
        let project = try ProjectCodec.decode(earliest)
        XCTAssertEqual(project.name, "First")
        XCTAssertEqual(project.timeSignature, TimeSignature(3, 4))
        XCTAssertEqual(project.master.volumeDB, -3)
        XCTAssertTrue(project.tempoChanges.isEmpty && project.media.isEmpty && project.masterInserts.isEmpty)
        let keys = try XCTUnwrap(project.tracks.first)
        XCTAssertEqual(keys.instrument, InstrumentSettings(), "a song from before sounds were stored plays the default synth")
        XCTAssertEqual(keys.monitor, .auto)
        XCTAssertEqual(keys.clips.first?.notes.first?.pitch, 60)
        XCTAssertTrue(keys.clips.first?.controls.isEmpty ?? false)
        XCTAssertEqual(keys.placements.first?.start, 2_880)
        XCTAssertEqual(keys.slots.count, 1)
    }

    func testTodaysFileOpensWithEveryField() throws {
        let project = try ProjectCodec.decode(current)
        XCTAssertEqual(project.tempoChanges, [TempoChange(tick: 7_680, bpm: 90)])
        let lead = project.tracks[0]
        XCTAssertEqual(lead.instrument.value(.cutoff), 1_200)
        XCTAssertEqual(lead.instrument.values["some.future.key"], 3, "a key this build does not know is kept")
        XCTAssertEqual(lead.clips[0].controls.map(\.kind), [.controller(number: 64), .pitchBend])
        XCTAssertEqual(project.tracks[1].kind, .returnTrack)
    }

    func testEveryGoldenFileSurvivesARoundTrip() throws {
        for data in [earliest, current] {
            let project = try ProjectCodec.decode(data)
            XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(project)), project)
        }
    }

    /// The keys the encoder writes are the ones `docs/FORMAT.md` lists. A new field is fine once
    /// it is documented there; a renamed or vanished one is a format change.
    func testTheEncoderWritesTheDocumentedKeys() throws {
        let project = try ProjectCodec.decode(current)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(project)) as? [String: Any])
        XCTAssertEqual(Set(root.keys), ["formatVersion", "name", "tempo", "tempoChanges", "timeSignature", "tracks",
                                        "scenes", "master", "masterInserts", "media", "midiMappings", "automation"])
        let tracks = try XCTUnwrap(root["tracks"] as? [[String: Any]])
        XCTAssertEqual(Set(tracks[0].keys), ["id", "name", "kind", "colorIndex", "mixer", "clips", "placements", "slots",
                                             "instrument", "regions", "inserts", "sends", "monitor"])
        let clip = try XCTUnwrap((tracks[0]["clips"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(clip.keys), ["id", "name", "length", "notes", "controls"])
        let control = try XCTUnwrap((clip["controls"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(control.keys), ["id", "kind", "start", "value"])
    }
}
