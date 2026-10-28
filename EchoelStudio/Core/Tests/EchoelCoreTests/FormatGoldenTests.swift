import Foundation
import XCTest
@testable import EchoelCore

/// The song format as `docs/FORMAT.md` describes it. These files are written by hand, the way
/// the builds of each format wrote them; each must keep opening for as long as its format is
/// supported. A change that breaks one is a format change: bump `Project.currentFormatVersion`
/// and migrate, never edit the golden file to match. Format 2 (2026-10-20) changed how an
/// address is stored; every format-1 file here opens unchanged. Format 3 (2026-10-28) adds the
/// required `modRoutes`; every format-1 and format-2 file opens with none.
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

    /// The last format-1 shape on top of that: tempo changes, a stored sound, controllers in a
    /// clip, a return.
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

    /// Format 1 with controllers and lanes, in the shape those builds wrote for an address:
    /// the compiler's coding of the owner (`{"track": {"_0": …}}`) plus the key.
    private let formatOneAddresses = Data("""
    {
      "formatVersion": 1,
      "name": "Mapped",
      "tempo": 110,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "scenes": [],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-000000000004",
          "name": "Pad",
          "kind": "instrument",
          "colorIndex": 1,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "sends": [ { "target": "7A000000-0000-4000-8000-000000000005", "levelDB": -12 } ]
        },
        {
          "id": "7A000000-0000-4000-8000-000000000005",
          "name": "Room",
          "kind": "returnTrack",
          "colorIndex": 4,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": []
        }
      ],
      "midiMappings": [
        { "control": { "channel": 0, "number": 7 }, "target": { "owner": { "master": {} }, "key": "mixer.volume" } },
        { "control": { "channel": 0, "number": 74 },
          "target": { "owner": { "track": { "_0": "7A000000-0000-4000-8000-000000000004" } }, "key": "synth.cutoff" } }
      ],
      "automation": [
        { "target": { "owner": { "track": { "_0": "7A000000-0000-4000-8000-000000000004" } }, "key": "mixer.volume" },
          "points": [ { "tick": 0, "value": -6 }, { "tick": 3840, "value": 0, "curve": 0.5 } ] },
        { "target": { "owner": { "track": { "_0": "7A000000-0000-4000-8000-000000000004" } },
                      "key": "mixer.send/7A000000-0000-4000-8000-000000000005" },
          "points": [ { "tick": 0, "value": -24, "curve": 0 } ] },
        { "target": { "owner": { "master": {} }, "key": "mixer.pan" }, "points": [ { "tick": 1920, "value": 0.25, "curve": 0 } ] }
      ]
    }
    """.utf8)

    /// The same song as format 2 writes it: an address is its text form.
    private let formatTwo = Data("""
    {
      "formatVersion": 2,
      "name": "Mapped",
      "tempo": 110,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "scenes": [],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-000000000004",
          "name": "Pad",
          "kind": "instrument",
          "colorIndex": 1,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "sends": [ { "target": "7A000000-0000-4000-8000-000000000005", "levelDB": -12 } ]
        },
        {
          "id": "7A000000-0000-4000-8000-000000000005",
          "name": "Room",
          "kind": "returnTrack",
          "colorIndex": 4,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": []
        }
      ],
      "midiMappings": [
        { "control": { "channel": 0, "number": 7 }, "target": "master/mixer.volume" },
        { "control": { "channel": 0, "number": 74 }, "target": "track/7A000000-0000-4000-8000-000000000004/synth.cutoff" }
      ],
      "automation": [
        { "target": "track/7A000000-0000-4000-8000-000000000004/mixer.volume",
          "points": [ { "tick": 0, "value": -6, "curve": 0 }, { "tick": 3840, "value": 0, "curve": 0.5 } ] },
        { "target": "track/7A000000-0000-4000-8000-000000000004/mixer.send/7A000000-0000-4000-8000-000000000005",
          "points": [ { "tick": 0, "value": -24, "curve": 0 } ] },
        { "target": "master/mixer.pan", "points": [ { "tick": 1920, "value": 0.25, "curve": 0 } ] }
      ]
    }
    """.utf8)

    /// A song from a later build, with a scale and a monitoring mode this build does not know.
    private let laterNames = Data("""
    {
      "formatVersion": 2,
      "name": "Later",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "context": { "root": 9, "scale": "hirajoshi", "tuning": "edo12", "concertPitch": 440, "swing": 0 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "scenes": [],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-000000000006",
          "name": "Voice",
          "kind": "audio",
          "colorIndex": 3,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "monitor": "tape"
        }
      ]
    }
    """.utf8)

    /// Media, audio on the timeline and in a session slot, effects with saved state, a plugin
    /// instrument, a sampler, an interface output and input. Plugin codes are the four ASCII
    /// characters as one big-endian integer: `aufx` is 1635083896.
    private let formatTwoMedia = Data("""
    {
      "formatVersion": 2,
      "name": "Media",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "masterInserts": [
        { "id": "15E00000-0000-4000-8000-000000000002",
          "plugin": { "type": 1635083896, "subtype": 1819112562, "manufacturer": 1096967012,
                      "name": "Limiter", "manufacturerName": "Maker" },
          "isBypassed": false }
      ],
      "media": [
        { "id": "3ED10000-0000-4000-8000-000000000001", "name": "Loop",
          "path": "Media/3ED10000-0000-4000-8000-000000000001.wav", "frameCount": 96000, "sampleRate": 48000 }
      ],
      "scenes": [ { "id": "5CE7E000-0000-4000-8000-000000000002", "name": "A" } ],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-000000000007",
          "name": "Loop",
          "kind": "audio",
          "colorIndex": 6,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [
            { "id": "C1000000-0000-4000-8000-000000000003", "name": "Loop", "length": 7680, "notes": [],
              "audio": { "media": "3ED10000-0000-4000-8000-000000000001", "offset": 0, "length": 96000 } }
          ],
          "placements": [],
          "slots": [ { "scene": "5CE7E000-0000-4000-8000-000000000002", "clip": "C1000000-0000-4000-8000-000000000003" } ],
          "regions": [
            { "id": "4E610000-0000-4000-8000-000000000001", "media": "3ED10000-0000-4000-8000-000000000001",
              "start": 3840, "offset": 48000, "length": 24000 }
          ],
          "inserts": [
            { "id": "15E00000-0000-4000-8000-000000000003",
              "plugin": { "type": 1635083896, "subtype": 1684368505, "manufacturer": 1096967012,
                          "name": "Delay", "manufacturerName": "Maker" },
              "state": "AAEC", "isBypassed": true }
          ],
          "input": 2,
          "monitor": "in"
        },
        {
          "id": "7A000000-0000-4000-8000-000000000008",
          "name": "Keys",
          "kind": "instrument",
          "colorIndex": 0,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "instrument": { "device": "plugin", "preset": "Init", "values": {},
                          "plugin": { "type": 1635085685, "subtype": 1886285617, "manufacturer": 1096967012,
                                      "name": "Piano", "manufacturerName": "Maker" },
                          "pluginState": "AQID" },
          "output": 2
        },
        {
          "id": "7A000000-0000-4000-8000-000000000009",
          "name": "Chops",
          "kind": "instrument",
          "colorIndex": 2,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "instrument": { "device": "sampler", "preset": "Init", "values": {},
                          "sample": "3ED10000-0000-4000-8000-000000000001" }
        }
      ]
    }
    """.utf8)


    /// Format 3: the same as format 2 plus the required `modRoutes`.
    private let formatThree = Data("""
    {
      "formatVersion": 3,
      "name": "Routed",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "scenes": [],
      "tracks": [],
      "modRoutes": [
        { "id": "40D00000-0000-4000-8000-000000000001", "source": "body.heartRate", "target": "master/mixer.pan",
          "depth": 0.25, "curve": "square", "polarity": "bipolar", "enabled": true },
        { "id": "40D00000-0000-4000-8000-000000000002", "source": "macro.1", "target": "master/mixer.volume",
          "depth": -0.5, "curve": "linear", "polarity": "unipolar", "enabled": false }
      ]
    }
    """.utf8)

    private let pad = TrackID(UUID(uuidString: "7A000000-0000-4000-8000-000000000004") ?? UUID())
    private let room = TrackID(UUID(uuidString: "7A000000-0000-4000-8000-000000000005") ?? UUID())


    func testTheEarliestFormatOneFileStillOpens() throws {
        let project = try ProjectCodec.decode(earliest)
        XCTAssertEqual(project.context, MusicalContext(), "a song from before the musical context frames nothing")
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

    func testTheLastFormatOneFileOpensWithEveryField() throws {
        let project = try ProjectCodec.decode(current)
        XCTAssertEqual(project.tempoChanges, [TempoChange(tick: 7_680, bpm: 90)])
        let lead = project.tracks[0]
        XCTAssertEqual(lead.instrument.value(.cutoff), 1_200)
        XCTAssertEqual(lead.instrument.values["some.future.key"], 3, "a key this build does not know is kept")
        XCTAssertEqual(lead.clips[0].controls.map(\.kind), [.controller(number: 64), .pitchBend])
        XCTAssertEqual(project.tracks[1].kind, .returnTrack)
    }

    func testEveryGoldenFileSurvivesARoundTrip() throws {
        for data in [earliest, current, formatOneAddresses, formatTwo, laterNames, formatTwoMedia, formatThree] {
            let project = try ProjectCodec.decode(data)
            XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(project)), project)
        }
    }

    /// The keys the encoder writes are the ones `docs/FORMAT.md` lists. A new field is fine once
    /// it is documented there; a renamed or vanished one is a format change.
    func testTheEncoderWritesTheDocumentedKeys() throws {
        let project = try ProjectCodec.decode(current)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(project)) as? [String: Any])
        XCTAssertEqual(Set(root.keys), ["formatVersion", "name", "tempo", "tempoChanges", "timeSignature", "context",
                                        "tracks", "scenes", "master", "masterInserts", "media", "midiMappings",
                                        "automation", "modRoutes"])
        let context = try XCTUnwrap(root["context"] as? [String: Any])
        XCTAssertEqual(Set(context.keys), ["root", "scale", "tuning", "concertPitch", "swing"])
        let tracks = try XCTUnwrap(root["tracks"] as? [[String: Any]])
        XCTAssertEqual(Set(tracks[0].keys), ["id", "name", "kind", "colorIndex", "mixer", "clips", "placements", "slots",
                                             "instrument", "regions", "inserts", "sends", "monitor"])
        let clip = try XCTUnwrap((tracks[0]["clips"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(clip.keys), ["id", "name", "length", "notes", "controls"])
        let control = try XCTUnwrap((clip["controls"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(control.keys), ["id", "kind", "start", "value"])
    }

    // MARK: - Modulation routes (format 3)

    func testAFormatThreeFileOpensWithItsRoutes() throws {
        let project = try ProjectCodec.decode(formatThree)
        XCTAssertEqual(project.modRoutes.map(\.source), [.heartRate, .macro1])
        XCTAssertEqual(project.modRoutes.map(\.target), [.masterPan, .masterVolume])
        XCTAssertEqual(project.modRoutes.map(\.depth), [0.25, -0.5])
        XCTAssertEqual(project.modRoutes.map(\.curve), [.square, .linear])
        XCTAssertEqual(project.modRoutes.map(\.polarity), [.bipolar, .unipolar])
        XCTAssertEqual(project.modRoutes.map(\.enabled), [true, false])
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(project)) as? [String: Any])
        let route = try XCTUnwrap((root["modRoutes"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(route.keys), ["id", "source", "target", "depth", "curve", "polarity", "enabled"])
    }

    /// G-A migration F01/F02: an older song opens with no routes and changes in nothing else.
    func testAnOlderSongOpensWithNoRoutes() throws {
        for data in [earliest, formatTwo, formatTwoMedia] {
            XCTAssertEqual(try ProjectCodec.decode(data).modRoutes, [])
        }
    }

    /// F08 and F09: format 3 without routes, and an older file that carries some, are refused.
    func testRoutesBelongToFormatThreeAndOnlyThere() throws {
        let withoutRoutes = Data("""
        { "formatVersion": 3, "name": "Bare", "tempo": 120, "timeSignature": { "numerator": 4, "denominator": 4 },
          "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false }, "scenes": [], "tracks": [] }
        """.utf8)
        XCTAssertThrowsError(try ProjectCodec.decode(withoutRoutes))
        let olderWithRoutes = Data("""
        { "formatVersion": 2, "name": "Odd", "tempo": 120, "timeSignature": { "numerator": 4, "denominator": 4 },
          "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false }, "scenes": [], "tracks": [],
          "modRoutes": [] }
        """.utf8)
        XCTAssertThrowsError(try ProjectCodec.decode(olderWithRoutes))
    }

    /// An unknown source or curve refuses the song rather than being guessed (M13, M15).
    func testARouteWithAnUnknownNameRefusesTheSong() throws {
        for (from, to) in [("\"body.heartRate\"", "\"eeg\""), ("\"square\"", "\"magic\"")] {
            let text = try XCTUnwrap(String(data: formatThree, encoding: .utf8))
            XCTAssertThrowsError(try ProjectCodec.decode(Data(text.replacingOccurrences(of: from, with: to).utf8)), to)
        }
    }

    // MARK: - Addresses (format 2) and names a build does not know

    func testAFormatOneFileKeepsItsControllersAndLanes() throws {
        let project = try ProjectCodec.decode(formatOneAddresses)
        XCTAssertEqual(project.formatVersion, Project.currentFormatVersion, "an older file is read into today's shape")
        XCTAssertEqual(project.midiMappings.map(\.target), [.masterVolume, ParameterAddress(.track(pad), SynthParameter.cutoff.key)])
        XCTAssertEqual(project.midiMappings.map(\.control), [MIDIControl(channel: 0, number: 7), MIDIControl(channel: 0, number: 74)])
        XCTAssertEqual(project.automation.map(\.target), [.volume(pad), .send(pad, to: room), .masterPan])
        XCTAssertEqual(project.automation[0].points, [AutomationPoint(tick: 0, value: -6), AutomationPoint(tick: 3_840, value: 0, curve: 0.5)])
    }

    func testAFormatTwoFileIsTheSameSong() throws {
        XCTAssertEqual(try ProjectCodec.decode(formatTwo), try ProjectCodec.decode(formatOneAddresses))
    }

    /// Saving an older song writes today's number over today's shape — never format 1's number
    /// over format 2's addresses, which a format-1 build would then fail to read.
    func testAnOlderSongIsSavedInTodaysShape() throws {
        // Values through a plain Decodable: JSONSerialization's number types differ between platforms.
        struct Target: Decodable { let target: String }
        struct Saved: Decodable { let formatVersion: Int; let midiMappings: [Target]; let automation: [Target] }
        let data = try ProjectCodec.encode(ProjectCodec.decode(formatOneAddresses))
        let saved = try JSONDecoder().decode(Saved.self, from: data)
        XCTAssertEqual(saved.formatVersion, Project.currentFormatVersion)
        XCTAssertEqual(saved.midiMappings.map(\.target),
                       ["master/mixer.volume", "track/7A000000-0000-4000-8000-000000000004/synth.cutoff"])
        XCTAssertEqual(saved.automation.map(\.target), [
            "track/7A000000-0000-4000-8000-000000000004/mixer.volume",
            "track/7A000000-0000-4000-8000-000000000004/mixer.send/7A000000-0000-4000-8000-000000000005",
            "master/mixer.pan",
        ])
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let mapping = try XCTUnwrap((root["midiMappings"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(mapping.keys), ["control", "target"])
        let lane = try XCTUnwrap((root["automation"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(lane.keys), ["target", "points"])
    }

    func testEveryAddressReadsBackFromItsTextForm() throws {
        let insert = InsertID(UUID(uuidString: "15E00000-0000-4000-8000-000000000001") ?? UUID())
        let addresses: [ParameterAddress] = [
            .tempo, .scale, .masterVolume, .masterPan, .volume(pad), .pan(pad), .send(pad, to: room),
            .plugin(pad, PluginParameter(.instrument, address: 7)),
            .plugin(pad, PluginParameter(.insert(insert), address: 4_294_967_296)),
        ]
        for address in addresses {
            XCTAssertEqual(ParameterAddress(text: address.description), address, address.description)
        }
        for text in ["", "tempo", "bus/mixer.volume", "track/", "track/not-a-uuid/mixer.volume",
                     "track/7A000000-0000-4000-8000-000000000004"] {
            XCTAssertNil(ParameterAddress(text: text), text)
        }
    }

    func testAnAddressThatIsNotOneRefusesTheSong() throws {
        let broken = String(decoding: formatTwo, as: UTF8.self)
            .replacingOccurrences(of: "\"target\": \"master/mixer.pan\"", with: "\"target\": \"bus/mixer.pan\"")
        XCTAssertNotEqual(Data(broken.utf8), formatTwo, "the replacement must land")
        XCTAssertThrowsError(try ProjectCodec.decode(Data(broken.utf8)))
    }

    /// One rule for a name this build does not know (`docs/FORMAT.md`, Versioning): where the
    /// field only chooses how the song plays, the song opens, the name plays as the field's
    /// fallback and is written back unchanged; the track kind decides what a track holds and has
    /// no fallback, so a new kind comes with a new format number.
    func testANameFromALaterBuildIsKeptAndPlaysAsTheFallback() throws {
        let project = try ProjectCodec.decode(laterNames)
        XCTAssertEqual(project.context.scale, .chromatic, "an unknown scale frames nothing")
        XCTAssertEqual(project.context.unrecognizedScale, "hirajoshi")
        XCTAssertEqual(project.context.root, 9)
        let voice = try XCTUnwrap(project.tracks.first)
        XCTAssertEqual(voice.monitor, .auto, "an unknown monitoring mode behaves as the default")
        XCTAssertEqual(voice.unrecognizedMonitor, "tape")

        struct Context: Decodable { let scale: String }
        struct Monitored: Decodable { let monitor: String }
        struct Saved: Decodable { let context: Context; let tracks: [Monitored] }
        let saved = try JSONDecoder().decode(Saved.self, from: ProjectCodec.encode(project))
        XCTAssertEqual(saved.context.scale, "hirajoshi", "saved again, the name is still there for the build that knows it")
        XCTAssertEqual(saved.tracks.map(\.monitor), ["tape"])

        var picked = project
        picked.context.scale = .dorian
        picked.tracks[0].monitor = .off
        XCTAssertNil(picked.context.unrecognizedScale, "choosing a scale replaces the unknown one")
        XCTAssertNil(picked.tracks[0].unrecognizedMonitor)
        XCTAssertEqual(picked.context.scale, .dorian)
    }

    // MARK: - Media, regions, effects and plugins (format 2)

    func testAFileWithMediaRegionsEffectsAndPluginsOpens() throws {
        let project = try ProjectCodec.decode(formatTwoMedia)
        let media = MediaID(UUID(uuidString: "3ED10000-0000-4000-8000-000000000001") ?? UUID())
        let file = try XCTUnwrap(project.media.first)
        XCTAssertEqual(file.id, media)
        XCTAssertEqual(file.frameCount, 96_000)
        XCTAssertEqual(file.sampleRate, 48_000)
        XCTAssertEqual(file.url(in: URL(fileURLWithPath: "/Song.echoel"))?.lastPathComponent,
                       "3ED10000-0000-4000-8000-000000000001.wav")

        let loop = project.tracks[0]
        XCTAssertEqual(loop.kind, .audio)
        XCTAssertEqual(loop.regions.map(\.start), [3_840])
        XCTAssertEqual(loop.regions.first?.offset, 48_000)
        XCTAssertEqual(loop.regions.first?.length, 24_000)
        XCTAssertEqual(loop.clips.first?.audio, ClipAudio(media: media, offset: 0, length: 96_000))
        XCTAssertEqual(loop.slots.count, 1)
        XCTAssertEqual(loop.input, 2)
        XCTAssertEqual(loop.monitor, .input)
        let delay = try XCTUnwrap(loop.inserts.first)
        XCTAssertEqual(delay.plugin.type, PluginComponent.code("aufx"))
        XCTAssertEqual(delay.plugin.subtype, PluginComponent.code("dely"))
        XCTAssertEqual(delay.plugin.role, .effect)
        XCTAssertEqual(delay.state, Data([0, 1, 2]), "a plugin's own state is base64")
        XCTAssertTrue(delay.isBypassed)
        XCTAssertEqual(project.masterInserts.map(\.plugin.name), ["Limiter"])

        let keys = project.tracks[1]
        XCTAssertEqual(keys.instrument.device, .plugin)
        XCTAssertEqual(keys.instrument.plugin?.role, .instrument)
        XCTAssertEqual(keys.instrument.pluginState, Data([1, 2, 3]))
        XCTAssertEqual(keys.output, 2, "outputs 3/4 of the interface")
        XCTAssertEqual(project.tracks[2].instrument.device, .sampler)
        XCTAssertEqual(project.tracks[2].instrument.sample, media)
    }

    /// The keys of media, regions, effects and plugins are the ones `docs/FORMAT.md` lists.
    func testTheEncoderWritesTheDocumentedMediaAndPluginKeys() throws {
        let saved = try ProjectCodec.encode(ProjectCodec.decode(formatTwoMedia))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        let file = try XCTUnwrap((root["media"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(file.keys), ["id", "name", "path", "frameCount", "sampleRate"])
        let tracks = try XCTUnwrap(root["tracks"] as? [[String: Any]])
        let region = try XCTUnwrap((tracks[0]["regions"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(region.keys), ["id", "media", "start", "offset", "length"])
        let clip = try XCTUnwrap((tracks[0]["clips"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(try XCTUnwrap(clip["audio"] as? [String: Any]).keys), ["media", "offset", "length"])
        let insert = try XCTUnwrap((tracks[0]["inserts"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(insert.keys), ["id", "plugin", "state", "isBypassed"])
        let plugin = try XCTUnwrap(insert["plugin"] as? [String: Any])
        XCTAssertEqual(Set(plugin.keys), ["type", "subtype", "manufacturer", "name", "manufacturerName"])
        let instrument = try XCTUnwrap(tracks[1]["instrument"] as? [String: Any])
        XCTAssertEqual(Set(instrument.keys), ["device", "preset", "values", "plugin", "pluginState"])
        XCTAssertEqual(Set(tracks[1].keys).intersection(["output", "input", "monitor"]), ["output", "monitor"])
    }

    func testATrackKindThisBuildDoesNotKnowRefusesTheSong() throws {
        let later = String(decoding: earliest, as: UTF8.self)
            .replacingOccurrences(of: "\"kind\": \"instrument\"", with: "\"kind\": \"video\"")
        XCTAssertNotEqual(Data(later.utf8), earliest, "the replacement must land")
        XCTAssertThrowsError(try ProjectCodec.decode(Data(later.utf8)))
    }
}
