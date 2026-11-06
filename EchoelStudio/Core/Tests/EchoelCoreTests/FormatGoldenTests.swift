import Foundation
import XCTest
@testable import EchoelCore

/// The song format as `docs/FORMAT.md` describes it. These files are written by hand, the way
/// the builds of each format wrote them; each must keep opening for as long as its format is
/// supported. A change that breaks one is a format change: bump `Project.currentFormatVersion`
/// and migrate, never edit the golden file to match. Format 2 (2026-10-20) changed how an
/// address is stored; every format-1 file here opens unchanged. Format 3 (2026-10-28) adds the
/// required `modRoutes`; every format-1 and format-2 file opens with none. Format 4 (2026-10-29)
/// adds video tracks and video media files; every older file opens unchanged and has neither.
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

    /// Format 4: a video track showing two parts of one take, beside an audio file that states no kind.
    private let formatFour = Data("""
    {
      "formatVersion": 4,
      "name": "Filmed",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "media": [
        { "id": "3ED10000-0000-4000-8000-000000000002", "name": "Take 1", "kind": "video",
          "path": "Media/3ED10000-0000-4000-8000-000000000002.mov", "frameCount": 480000, "sampleRate": 48000 },
        { "id": "3ED10000-0000-4000-8000-000000000003", "name": "Loop",
          "path": "Media/3ED10000-0000-4000-8000-000000000003.wav", "frameCount": 96000, "sampleRate": 48000 }
      ],
      "scenes": [],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-00000000000A",
          "name": "Video 1",
          "kind": "video",
          "colorIndex": 7,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "regions": [
            { "id": "4E610000-0000-4000-8000-000000000002", "media": "3ED10000-0000-4000-8000-000000000002",
              "start": 0, "offset": 0, "length": 96000 },
            { "id": "4E610000-0000-4000-8000-000000000003", "media": "3ED10000-0000-4000-8000-000000000002",
              "start": 7680, "offset": 192000, "length": 288000 }
          ]
        }
      ],
      "modRoutes": []
    }
    """.utf8)

    /// Format 4 with a region's optional fades, level and warp (AUD-2, 2026-11-04): added inside
    /// format 4, so an earlier format-4 build opens the file and plays the region plain.
    private let formatFourRegionEdits = Data("""
    {
      "formatVersion": 4,
      "name": "Faded",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "media": [
        { "id": "3ED10000-0000-4000-8000-000000000005", "name": "Drums",
          "path": "Media/3ED10000-0000-4000-8000-000000000005.wav", "frameCount": 96000, "sampleRate": 48000 }
      ],
      "scenes": [],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-00000000000B",
          "name": "Drums",
          "kind": "audio",
          "colorIndex": 1,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "regions": [
            { "id": "4E610000-0000-4000-8000-000000000005", "media": "3ED10000-0000-4000-8000-000000000005",
              "start": 0, "offset": 0, "length": 96000,
              "fadeIn": 4800, "fadeOut": 9600, "fadeInCurve": "equalPower", "fadeOutCurve": "sCurve",
              "gainDB": -6, "nativeBPM": 100, "followsTempo": true }
          ]
        }
      ],
      "modRoutes": []
    }
    """.utf8)

    /// Format 4 with a video part's optional colour correction (COLOR, 2026-11-05): added inside
    /// format 4, so an earlier format-4 build opens the file and shows the part as its file is. The
    /// second part names only two values; the others read as standard.
    private let formatFourGrade = Data("""
    {
      "formatVersion": 4,
      "name": "Graded",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "media": [
        { "id": "3ED10000-0000-4000-8000-000000000009", "name": "Take 2", "kind": "video",
          "path": "Media/3ED10000-0000-4000-8000-000000000009.mov", "frameCount": 480000, "sampleRate": 48000 }
      ],
      "scenes": [],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-000000000010",
          "name": "Video 1",
          "kind": "video",
          "colorIndex": 7,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "regions": [
            { "id": "4E610000-0000-4000-8000-000000000009", "media": "3ED10000-0000-4000-8000-000000000009",
              "start": 0, "offset": 0, "length": 96000,
              "grade": { "exposure": 0.5, "contrast": 1.2, "saturation": 0.9, "temperature": -0.25, "tint": 0.1,
                         "lift": 0.02, "gamma": 1.1, "gain": 0.95 } },
            { "id": "4E610000-0000-4000-8000-00000000000A", "media": "3ED10000-0000-4000-8000-000000000009",
              "start": 7680, "offset": 192000, "length": 96000,
              "grade": { "exposure": -1, "saturation": 1.5 } }
          ]
        }
      ],
      "modRoutes": []
    }
    """.utf8)

    /// Format 4 with a region's optional bake (W3, 2026-11-04): added inside format 4, so an earlier
    /// format-4 build opens the file and plays the baked file as an ordinary region.
    private let formatFourBake = Data("""
    {
      "formatVersion": 4,
      "name": "Tuned",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "media": [
        { "id": "3ED10000-0000-4000-8000-000000000006", "name": "Voice",
          "path": "Media/3ED10000-0000-4000-8000-000000000006.wav", "frameCount": 96000, "sampleRate": 48000 },
        { "id": "3ED10000-0000-4000-8000-000000000007", "name": "Voice (tuned)",
          "path": "Media/3ED10000-0000-4000-8000-000000000007.wav", "frameCount": 48000, "sampleRate": 48000 }
      ],
      "scenes": [],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-00000000000F",
          "name": "Voice",
          "kind": "audio",
          "colorIndex": 2,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "regions": [
            { "id": "4E610000-0000-4000-8000-000000000007", "media": "3ED10000-0000-4000-8000-000000000007",
              "start": 960, "offset": 0, "length": 48000,
              "bake": { "source": "3ED10000-0000-4000-8000-000000000006", "sourceOffset": 12000,
                        "pitchCorrection": { "strength": 0.8, "retune": 0.02 },
                        "texture": { "size": 0.05, "density": 0.7, "scatter": 0.1, "pitch": 7, "seed": 99 } } }
          ]
        }
      ],
      "modRoutes": []
    }
    """.utf8)

    /// Format 4 with a track's optional arpeggiator (EDIT-2, 2026-11-04): added inside format 4, so
    /// an earlier format-4 build opens the file and plays the notes as written. The second track
    /// names a rate and an order of a later build: kept, played as a sixteenth, up.
    private let formatFourArpeggio = Data("""
    {
      "formatVersion": 4,
      "name": "Arp",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "scenes": [],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-00000000000C",
          "name": "Keys",
          "kind": "instrument",
          "colorIndex": 0,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "arpeggio": { "on": true, "rate": "eighthTriplet", "order": "upDown", "octaves": 2, "gate": 0.75,
                        "latch": true, "seed": 7 }
        },
        {
          "id": "7A000000-0000-4000-8000-00000000000D",
          "name": "Later",
          "kind": "instrument",
          "colorIndex": 1,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "arpeggio": { "on": false, "rate": "fiveTuplet", "order": "spiral", "octaves": 1, "gate": 0.5,
                        "latch": false, "seed": 1 }
        }
      ],
      "modRoutes": []
    }
    """.utf8)

    /// Format 4 with a sampler whose file is cut into pads (the break slicer, 2026-11-04): an
    /// optional instrument field added inside format 4, so an earlier format-4 build opens the file
    /// and its sampler plays the whole file across the keys.
    private let formatFourSlices = Data("""
    {
      "formatVersion": 4,
      "name": "Break",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "media": [
        { "id": "3ED10000-0000-4000-8000-000000000007", "name": "Amen",
          "path": "Media/3ED10000-0000-4000-8000-000000000007.wav", "frameCount": 96000, "sampleRate": 48000 }
      ],
      "scenes": [],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-00000000000F",
          "name": "Break",
          "kind": "instrument",
          "colorIndex": 2,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "instrument": { "device": "sampler", "preset": "Init", "values": { "drums.kick.tune": -3, "drums.hatModel": 1 },
                          "sample": "3ED10000-0000-4000-8000-000000000007",
                          "slices": [ { "start": 0 }, { "start": 12000, "tune": -2 }, { "start": 48000, "reverse": true } ] }
        }
      ],
      "modRoutes": []
    }
    """.utf8)

    /// Format 4 with a synth that cuts its wavetable from a file of the song (2026-11-04): an
    /// optional instrument field added inside format 4, so an earlier format-4 build opens the file
    /// and its synth plays the engine it knows.
    private let formatFourWavetable = Data("""
    {
      "formatVersion": 4,
      "name": "Table",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "media": [
        { "id": "3ED10000-0000-4000-8000-000000000006", "name": "Voice",
          "path": "Media/3ED10000-0000-4000-8000-000000000006.wav", "frameCount": 96000, "sampleRate": 48000 }
      ],
      "scenes": [],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-00000000000E",
          "name": "Table",
          "kind": "instrument",
          "colorIndex": 3,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "instrument": { "device": "synth", "preset": "Init", "values": { "synth.engine": 9, "synth.character": 0.4 },
                          "wavetable": { "media": "3ED10000-0000-4000-8000-000000000006", "frames": 24 } }
        }
      ],
      "modRoutes": []
    }
    """.utf8)

    /// Format 4 with a synth on the texture engine (A10, 2026-11-04): four synth values added inside
    /// format 4 and the engine's index appended (10), so every earlier index holds.
    private let formatFourTexture = Data("""
    {
      "formatVersion": 4,
      "name": "Cells",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "scenes": [],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-00000000000F",
          "name": "Cells",
          "kind": "instrument",
          "colorIndex": 5,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "instrument": { "device": "synth", "preset": "Cell Texture",
                          "values": { "synth.engine": 10, "synth.character": 0.55, "synth.textureRule": 2,
                                      "synth.textureDensity": 0.75, "synth.textureRate": 12, "synth.textureSeed": 4711 } }
        }
      ],
      "modRoutes": []
    }
    """.utf8)

    /// Format 4 with a synth on the DDSP engine and a spectral profile (2026-11-06): one synth value
    /// added inside format 4; a song without it plays profile 0, the sound before profiles.
    private let formatFourDDSPProfile = Data("""
    {
      "formatVersion": 4,
      "name": "Bowed",
      "tempo": 96,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "scenes": [],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-000000000010",
          "name": "Bowed",
          "kind": "instrument",
          "colorIndex": 2,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "instrument": { "device": "synth", "preset": "Init",
                          "values": { "synth.engine": 6, "synth.character": 0.7, "synth.ddspProfile": 5 } }
        }
      ],
      "modRoutes": []
    }
    """.utf8)

    /// Format 4 with markers on the timeline (PRO-W1, 2026-11-04): an optional song field added
    /// inside format 4, so an earlier format-4 build opens the file and shows no markers.
    private let formatFourMarkers = Data("""
    {
      "formatVersion": 4,
      "name": "Marked",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "markers": [ { "tick": 0, "name": "Intro" }, { "tick": 15360, "name": "Drop" } ],
      "scenes": [],
      "tracks": [],
      "modRoutes": []
    }
    """.utf8)

    /// Format 4 with routes from the phone's own motion (Recovery 9, 2026-11-04): four source names
    /// added at the end inside format 4. An earlier format-4 build refuses this song, as it refuses
    /// any source it does not know (`docs/FORMAT.md`).
    private let formatFourMotion = Data("""
    {
      "formatVersion": 4,
      "name": "Tilted",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "scenes": [],
      "tracks": [],
      "modRoutes": [
        { "id": "40D00000-0000-4000-8000-000000000011", "source": "body.motion.tiltX", "target": "master/mixer.pan",
          "depth": 1, "curve": "linear", "polarity": "bipolar", "enabled": true },
        { "id": "40D00000-0000-4000-8000-000000000012", "source": "body.motion.tiltY", "target": "master/mixer.volume",
          "depth": 0.5, "curve": "linear", "polarity": "bipolar", "enabled": true },
        { "id": "40D00000-0000-4000-8000-000000000013", "source": "body.motion.rotation", "target": "master/mixer.pan",
          "depth": -0.25, "curve": "square", "polarity": "bipolar", "enabled": false },
        { "id": "40D00000-0000-4000-8000-000000000014", "source": "body.motion.energy", "target": "master/mixer.volume",
          "depth": -0.5, "curve": "linear", "polarity": "unipolar", "enabled": true }
      ]
    }
    """.utf8)

    /// Format 4 with a light show (CUES, 2026-11-05): an optional song field added inside format 4,
    /// so an earlier format-4 build opens the file and shows no rig.
    private let formatFourLighting = Data("""
    {
      "formatVersion": 4,
      "name": "Lit",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "lighting": {
        "fixtures": [
          { "id": "F1C70000-0000-4000-8000-000000000001", "name": "Head 1", "profile": "movingHead",
            "universe": 1, "address": 1 },
          { "id": "F1C70000-0000-4000-8000-000000000002", "name": "Strobe 1", "profile": "strobe",
            "universe": 1, "address": 9 },
          { "id": "F1C70000-0000-4000-8000-000000000003", "name": "Haze", "profile": "fogMachine",
            "universe": 2, "address": 1 }
        ],
        "cues": [
          { "id": "C0E00000-0000-4000-8000-000000000001", "name": "Open", "fade": 2,
            "values": [ { "fixture": "F1C70000-0000-4000-8000-000000000001",
                          "values": { "pan": 0.25, "tilt": 0.75, "dimmer": 1, "red": 1, "laterKey": 0.5 } } ] },
          { "id": "C0E00000-0000-4000-8000-000000000002", "name": "Song", "fade": 0, "look": "song", "values": [] }
        ],
        "placements": [ { "tick": 0, "cue": "C0E00000-0000-4000-8000-000000000001" },
                        { "tick": 7680, "cue": "C0E00000-0000-4000-8000-000000000002" } ]
      },
      "scenes": [],
      "tracks": [],
      "modRoutes": []
    }
    """.utf8)

    /// Format 4 with subtitles (SUBS, 2026-11-05): an optional song field added inside format 4,
    /// so an earlier format-4 build opens the file and shows none.
    private let formatFourSubtitles = Data("""
    {
      "formatVersion": 4,
      "name": "Spoken",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "subtitles": [
        { "id": "5B700000-0000-4000-8000-000000000001", "start": 0, "end": 2880, "text": "Hello and welcome" },
        { "id": "5B700000-0000-4000-8000-000000000002", "start": 3840, "end": 7680,
          "text": "The quick brown fox jumps over the lazy dog" }
      ],
      "scenes": [],
      "tracks": [],
      "modRoutes": []
    }
    """.utf8)

    /// Format 4 with a take folder (Recovery 4, 2026-11-04): an optional track field added inside
    /// format 4, so an earlier format-4 build opens the file and plays both takes as plain regions.
    private let formatFourTakes = Data("""
    {
      "formatVersion": 4,
      "name": "Comped",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "media": [
        { "id": "3ED10000-0000-4000-8000-000000000007", "name": "Take 1",
          "path": "Media/3ED10000-0000-4000-8000-000000000007.wav", "frameCount": 96000, "sampleRate": 48000 },
        { "id": "3ED10000-0000-4000-8000-000000000008", "name": "Take 2",
          "path": "Media/3ED10000-0000-4000-8000-000000000008.wav", "frameCount": 96000, "sampleRate": 48000 }
      ],
      "scenes": [],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-00000000000D",
          "name": "Vocal",
          "kind": "audio",
          "colorIndex": 2,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "regions": [
            { "id": "4E610000-0000-4000-8000-000000000007", "media": "3ED10000-0000-4000-8000-000000000007",
              "start": 0, "offset": 0, "length": 96000 },
            { "id": "4E610000-0000-4000-8000-000000000008", "media": "3ED10000-0000-4000-8000-000000000008",
              "start": 0, "offset": 0, "length": 96000 }
          ],
          "takeGroups": [
            { "id": "7A6E0000-0000-4000-8000-000000000001",
              "takes": [ "4E610000-0000-4000-8000-000000000007", "4E610000-0000-4000-8000-000000000008" ],
              "comp": [ { "start": 0, "end": 1920, "take": "4E610000-0000-4000-8000-000000000007" },
                        { "start": 1920, "end": 3840, "take": "4E610000-0000-4000-8000-000000000008" } ] }
          ]
        }
      ],
      "modRoutes": []
    }
    """.utf8)

    /// A song from the future (FWD, 2026-11-05): written the way a later format-4 build writes it,
    /// with names this build does not know — a modulation source, a curve, a synth parameter, and
    /// an insert type — where leaving them out of the playback is safe. It opens, keeps all five
    /// inactive and writes them back byte for byte (`docs/FORMAT.md`, "Reading newer songs").
    static let formatFourFromTheFuture = Data("""
    {
      "formatVersion": 4,
      "name": "Tomorrow",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "masterInserts": [
        { "id": "1F500000-0000-4000-8000-000000000001", "isBypassed": false,
          "plugin": { "type": 1635083896, "subtype": 1699041589, "manufacturer": 1164142703,
                      "name": "Echoel EQ", "manufacturerName": "Echoel" } },
        { "id": "1F500000-0000-4000-8000-000000000002", "isBypassed": false, "sidechain": { "source": "kick", "amount": 0.75 },
          "plugin": { "type": 1635085673, "subtype": 1698787952, "manufacturer": 1164142703,
                      "name": "Echoel Arp", "manufacturerName": "Echoel" } }
      ],
      "scenes": [],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-0000000000F1",
          "name": "Keys",
          "kind": "instrument",
          "colorIndex": 2,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [], "placements": [], "slots": [],
          "inserts": [
            { "id": "1F500000-0000-4000-8000-000000000003", "isBypassed": true,
              "plugin": { "type": 1635085673, "subtype": 1698787952, "manufacturer": 1164142703,
                          "name": "Echoel Arp", "manufacturerName": "Echoel" } }
          ]
        }
      ],
      "modRoutes": [
        { "id": "40D00000-0000-4000-8000-0000000000F1", "source": "body.heartRate", "target": "master/mixer.pan",
          "depth": 0.25, "curve": "square", "polarity": "bipolar", "enabled": true },
        { "id": "40D00000-0000-4000-8000-0000000000F2", "source": "body.motion.gaze", "target": "master/mixer.volume",
          "depth": -0.5, "curve": "linear", "polarity": "unipolar", "enabled": true, "smoothing": 0.2 },
        { "id": "40D00000-0000-4000-8000-0000000000F3", "source": "lfo.1", "target": "master/mixer.pan",
          "depth": 1, "curve": "sine", "polarity": "bipolar", "enabled": true },
        { "id": "40D00000-0000-4000-8000-0000000000F4", "source": "macro.1",
          "target": "track/7A000000-0000-4000-8000-0000000000F1/synth.shimmer",
          "depth": 0.5, "curve": "linear", "polarity": "unipolar", "enabled": false }
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
        for data in [earliest, current, formatOneAddresses, formatTwo, laterNames, formatTwoMedia, formatThree, formatFour,
                     formatFourRegionEdits, formatFourArpeggio, formatFourMarkers, formatFourTakes, formatFourLighting,
                     formatFourTexture, formatFourBake, formatFourMotion, formatFourGrade, formatFourSubtitles,
                     formatFourDDSPProfile, Self.formatFourFromTheFuture] {
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

    /// Recovery 9: a song opens with its motion routes and writes the four names back unchanged.
    func testASongOpensWithItsMotionRoutes() throws {
        let project = try ProjectCodec.decode(formatFourMotion)
        XCTAssertEqual(project.modRoutes.map(\.source), [.motionTiltX, .motionTiltY, .motionRotation, .motionEnergy])
        XCTAssertEqual(project.modRoutes.map(\.target), [.masterPan, .masterVolume, .masterPan, .masterVolume])
        XCTAssertEqual(project.modRoutes.map(\.enabled), [true, true, false, true])
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(project)) as? [String: Any])
        let routes = try XCTUnwrap(root["modRoutes"] as? [[String: Any]])
        XCTAssertEqual(routes.compactMap { $0["source"] as? String },
                       ["body.motion.tiltX", "body.motion.tiltY", "body.motion.rotation", "body.motion.energy"])
        XCTAssertEqual(root["formatVersion"] as? Int, 4, "added inside format 4, no new number")
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

    /// An unknown source or curve is never guessed (M13, M15): since FWD (2026-11-05) the route is
    /// kept inactive and the song opens. A route that lacks a key, or has a depth outside −1 … 1, is
    /// damage and still refuses the song.
    func testARouteWithAnUnknownNameIsKeptInactiveAndADamagedOneRefuses() throws {
        let text = try XCTUnwrap(String(data: formatThree, encoding: .utf8))
        for (from, to) in [("\"body.heartRate\"", "\"eeg\""), ("\"square\"", "\"magic\""), ("\"bipolar\"", "\"tripolar\"")] {
            let later = Data(text.replacingOccurrences(of: from, with: to).utf8)
            XCTAssertNotEqual(later, formatThree, "the replacement must land")
            let project = try ProjectCodec.decode(later)
            XCTAssertEqual(project.modRoutes.map(\.source), [.macro1], to)
            XCTAssertEqual(project.keptRouteCount, 1, to)
        }
        for (from, to) in [("\"enabled\": true", "\"on\": true"), ("\"depth\": 0.25", "\"depth\": 3")] {
            let later = text.replacingOccurrences(of: from, with: to).replacingOccurrences(of: "\"body.heartRate\"", with: "\"eeg\"")
            XCTAssertThrowsError(try ProjectCodec.decode(Data(later.utf8)), to)
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
        // "video" stood here until format 4 made it a kind; the rule is the same for the next one.
        let later = String(decoding: earliest, as: UTF8.self)
            .replacingOccurrences(of: "\"kind\": \"instrument\"", with: "\"kind\": \"hologram\"")
        XCTAssertNotEqual(Data(later.utf8), earliest, "the replacement must land")
        XCTAssertThrowsError(try ProjectCodec.decode(Data(later.utf8)))
    }

    // MARK: - Video (format 4)

    func testAFormatFourFileOpensWithItsVideoTrack() throws {
        let project = try ProjectCodec.decode(formatFour)
        let video = try XCTUnwrap(project.tracks.first)
        XCTAssertEqual(video.kind, .video)
        XCTAssertEqual(video.regions.map(\.start), [0, 7_680])
        XCTAssertEqual(video.regions.map(\.offset), [0, 192_000])
        XCTAssertEqual(project.media.map(\.kind), [.video, .audio], "a file that states no kind is audio")
        XCTAssertTrue(project.audibleMedia.isEmpty, "a picture is not sound")
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(project)) as? [String: Any])
        let media = try XCTUnwrap(root["media"] as? [[String: Any]])
        XCTAssertEqual(Set(try XCTUnwrap(media.first).keys), ["id", "name", "kind", "path", "frameCount", "sampleRate"])
        XCTAssertEqual(Set(try XCTUnwrap(media.last).keys), ["id", "name", "path", "frameCount", "sampleRate"])
    }

    /// Video belongs to format 4: an older file that carries a video track or a video file is
    /// refused, never opened as if an older build had written it.
    func testVideoBelongsToFormatFourAndOnlyThere() throws {
        let three = String(decoding: formatFour, as: UTF8.self)
            .replacingOccurrences(of: "\"formatVersion\": 4", with: "\"formatVersion\": 3")
        XCTAssertNotEqual(Data(three.utf8), formatFour, "the replacement must land")
        XCTAssertThrowsError(try ProjectCodec.decode(Data(three.utf8)))
        let mediaOnly = Data("""
        { "formatVersion": 3, "name": "Odd", "tempo": 120, "timeSignature": { "numerator": 4, "denominator": 4 },
          "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false }, "scenes": [], "tracks": [],
          "media": [ { "id": "3ED10000-0000-4000-8000-000000000004", "name": "Clip", "kind": "video",
                       "path": "Media/clip.mov", "frameCount": 48000, "sampleRate": 48000 } ],
          "modRoutes": [] }
        """.utf8)
        XCTAssertThrowsError(try ProjectCodec.decode(mediaOnly))
        let unknownKind = String(decoding: formatFour, as: UTF8.self)
            .replacingOccurrences(of: "\"kind\": \"video\",", with: "\"kind\": \"hologram\",")
        XCTAssertNotEqual(Data(unknownKind.utf8), formatFour, "the replacement must land")
        XCTAssertThrowsError(try ProjectCodec.decode(Data(unknownKind.utf8)), "a media kind this build does not know")
    }

    func testARegionOpensWithItsFadesLevelAndWarp() throws {
        let project = try ProjectCodec.decode(formatFourRegionEdits)
        let region = try XCTUnwrap(project.tracks.first?.regions.first)
        XCTAssertEqual(region.fadeIn, 4_800)
        XCTAssertEqual(region.fadeOut, 9_600)
        XCTAssertEqual(region.fadeInCurve, .equalPower)
        XCTAssertEqual(region.fadeOutCurve, .sCurve)
        XCTAssertEqual(region.gainDB, -6)
        XCTAssertEqual(region.nativeBPM, 100)
        XCTAssertEqual(region.warpBPM, 100)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(project)) as? [String: Any])
        let tracks = try XCTUnwrap(root["tracks"] as? [[String: Any]])
        let stored = try XCTUnwrap((tracks.first?["regions"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(stored.keys), ["id", "media", "start", "offset", "length", "fadeIn", "fadeOut", "fadeInCurve",
                                          "fadeOutCurve", "gainDB", "nativeBPM", "followsTempo"])
        for data in [formatTwoMedia, formatFour] {
            for track in try ProjectCodec.decode(data).tracks {
                XCTAssertTrue(track.regions.allSatisfy { $0.fadeIn == nil && $0.fadeOut == nil && $0.gainDB == nil
                    && $0.nativeBPM == nil && $0.followsTempo == nil }, "an older region plays plain")
            }
        }
    }

    func testARegionOpensWithItsBakeAndRevertsToItsOriginal() throws {
        var project = try ProjectCodec.decode(formatFourBake)
        let track = try XCTUnwrap(project.tracks.first)
        let region = try XCTUnwrap(track.regions.first)
        let bake = try XCTUnwrap(region.bake)
        XCTAssertEqual(bake.sourceOffset, 12_000)
        XCTAssertEqual(bake.pitchCorrection, RegionBaking.PitchCorrection(strength: 0.8, retune: 0.02))
        XCTAssertEqual(bake.texture, RegionBaking.GrainTexture(size: 0.05, density: 0.7, scatter: 0.1, pitch: 7, seed: 99))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(project)) as? [String: Any])
        let tracks = try XCTUnwrap(root["tracks"] as? [[String: Any]])
        let stored = try XCTUnwrap((tracks.first?["regions"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(stored.keys), ["id", "media", "start", "offset", "length", "bake"])
        try Command.revertRegionBake(track: track.id, region.id).apply(to: &project)
        let reverted = try XCTUnwrap(project.tracks.first?.regions.first)
        XCTAssertEqual(reverted.media, bake.source)
        XCTAssertEqual(reverted.offset, 12_000)
        for data in [formatTwoMedia, formatFour, formatFourRegionEdits] {
            for track in try ProjectCodec.decode(data).tracks {
                XCTAssertTrue(track.regions.allSatisfy { $0.bake == nil }, "an older region is not baked")
            }
        }
    }

    func testAVideoPartOpensWithItsColorCorrection() throws {
        let project = try ProjectCodec.decode(formatFourGrade)
        let parts = try XCTUnwrap(project.tracks.first?.regions)
        XCTAssertEqual(parts.first?.grade, ColorGrade(exposure: 0.5, contrast: 1.2, saturation: 0.9, temperature: -0.25,
                                                      tint: 0.1, lift: 0.02, gamma: 1.1, gain: 0.95))
        XCTAssertEqual(parts.last?.grade, ColorGrade(exposure: -1, saturation: 1.5), "a value it leaves out is standard")
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(project)) as? [String: Any])
        let tracks = try XCTUnwrap(root["tracks"] as? [[String: Any]])
        let stored = try XCTUnwrap((tracks.first?["regions"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(stored.keys), ["id", "media", "start", "offset", "length", "grade"])
        // A value outside its range, or a correction on an audio part, refuses the song.
        let outside = Data(String(decoding: formatFourGrade, as: UTF8.self)
            .replacingOccurrences(of: "\"gamma\": 1.1", with: "\"gamma\": 9").utf8)
        XCTAssertThrowsError(try ProjectCodec.decode(outside))
        for data in [formatTwoMedia, formatFour, formatFourRegionEdits, formatFourBake] {
            for track in try ProjectCodec.decode(data).tracks {
                XCTAssertTrue(track.regions.allSatisfy { $0.grade == nil }, "an older part shows its file as it is")
            }
        }
    }

    func testATrackOpensWithItsArpeggiator() throws {
        let project = try ProjectCodec.decode(formatFourArpeggio)
        let arp = try XCTUnwrap(project.tracks.first?.arpeggio)
        XCTAssertEqual(arp, Arpeggio(isOn: true, rate: .eighthTriplet, order: .upDown, octaves: 2, gate: 0.75, latch: true, seed: 7))
        let later = try XCTUnwrap(project.tracks.last?.arpeggio)
        XCTAssertEqual(later.rate, .sixteenth, "a rate of a later build plays as a sixteenth")
        XCTAssertEqual(later.order, .up, "an order of a later build plays up")
        XCTAssertEqual(later.unrecognizedRate, "fiveTuplet")
        XCTAssertEqual(later.unrecognizedOrder, "spiral")
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(project)) as? [String: Any])
        let tracks = try XCTUnwrap(root["tracks"] as? [[String: Any]])
        let stored = try XCTUnwrap(tracks.last?["arpeggio"] as? [String: Any])
        XCTAssertEqual(Set(stored.keys), ["on", "rate", "order", "octaves", "gate", "latch", "seed"])
        XCTAssertEqual(stored["rate"] as? String, "fiveTuplet", "the later name is saved back unchanged")
        XCTAssertEqual(stored["order"] as? String, "spiral")
        for data in [earliest, current, formatTwo, formatTwoMedia, formatThree, formatFour, formatFourRegionEdits] {
            let older = try ProjectCodec.decode(data)
            XCTAssertTrue(older.tracks.allSatisfy { $0.arpeggio == nil }, "an older song plays its notes as written")
            let written = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(older)) as? [String: Any])
            for track in try XCTUnwrap(written["tracks"] as? [[String: Any]]) {
                XCTAssertNil(track["arpeggio"], "a track without an arpeggiator writes no key")
            }
        }
    }

    func testASamplerOpensWithItsSlicesAndTheKitWithItsSound() throws {
        let project = try ProjectCodec.decode(formatFourSlices)
        let instrument = try XCTUnwrap(project.tracks.first?.instrument)
        XCTAssertEqual(instrument.slices, [SampleSlice(start: 0), SampleSlice(start: 12_000, tune: -2),
                                           SampleSlice(start: 48_000, reverse: true)])
        XCTAssertEqual(instrument.value(.drumsHatModel), 1)
        XCTAssertEqual(instrument.value(SynthParameter.drumsPieceRows[0]), -3, "drums.kick.tune")
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(project)), project)
        for data in [earliest, current, formatTwo, formatTwoMedia, formatThree, formatFour, formatFourWavetable] {
            for track in try ProjectCodec.decode(data).tracks {
                XCTAssertNil(track.instrument.slices, "an older sampler plays its file across the keys")
                for row in InstrumentDevice.drums.parameters {
                    XCTAssertEqual(track.instrument.value(row), row.songDefault, "an older kit sounds as it always did")
                }
            }
        }
        // Slices that do not rise refuse the song.
        let falling = String(decoding: formatFourSlices, as: UTF8.self).replacingOccurrences(of: "\"start\": 48000", with: "\"start\": 6000")
        XCTAssertNotEqual(Data(falling.utf8), formatFourSlices, "the replacement must land")
        XCTAssertThrowsError(try ProjectCodec.decode(Data(falling.utf8)))
    }

    func testASynthOpensWithItsWavetable() throws {
        let project = try ProjectCodec.decode(formatFourWavetable)
        let instrument = try XCTUnwrap(project.tracks.first?.instrument)
        let media = try XCTUnwrap(project.media.first?.id)
        XCTAssertEqual(instrument.wavetable, WavetableSource(media: media, frames: 24))
        XCTAssertEqual(instrument.heardWavetable, media)
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(project)), project)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(project)) as? [String: Any])
        let stored = try XCTUnwrap((root["tracks"] as? [[String: Any]])?.first?["instrument"] as? [String: Any])
        XCTAssertEqual(Set(stored.keys), ["device", "preset", "values", "wavetable"])
        for data in [earliest, current, formatTwo, formatTwoMedia, formatThree, formatFour] {
            for track in try ProjectCodec.decode(data).tracks {
                XCTAssertNil(track.instrument.wavetable, "an older synth plays the shapes it knows")
            }
        }
        // A wavetable naming a file the song lacks, or too many cycles, refuses the song.
        let missing = String(decoding: formatFourWavetable, as: UTF8.self)
            .replacingOccurrences(of: "\"media\": \"3ED10000-0000-4000-8000-000000000006\", \"frames\"",
                                  with: "\"media\": \"3ED10000-0000-4000-8000-0000000000FF\", \"frames\"")
        XCTAssertNotEqual(Data(missing.utf8), formatFourWavetable, "the replacement must land")
        XCTAssertThrowsError(try ProjectCodec.decode(Data(missing.utf8)))
        let many = String(decoding: formatFourWavetable, as: UTF8.self).replacingOccurrences(of: "\"frames\": 24", with: "\"frames\": 65")
        XCTAssertNotEqual(Data(many.utf8), formatFourWavetable, "the replacement must land")
        XCTAssertThrowsError(try ProjectCodec.decode(Data(many.utf8)))
    }

    func testASynthOpensOnTheTextureEngineWithItsAutomaton() throws {
        let project = try ProjectCodec.decode(formatFourTexture)
        let instrument = try XCTUnwrap(project.tracks.first?.instrument)
        XCTAssertEqual(instrument.value(.engine), 10)
        XCTAssertEqual(SynthParameter.engine.choices[10], "Texture")
        XCTAssertEqual(instrument.value(.textureRule), 2)
        XCTAssertEqual(SynthParameter.textureRule.choices[2], "110", "the index names Wolfram's rule 110")
        XCTAssertEqual(instrument.value(.textureDensity), 0.75)
        XCTAssertEqual(instrument.value(.textureRate), 12)
        XCTAssertEqual(instrument.value(.textureSeed), 4711)
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(project)), project)
        // A song without the texture's values plays their defaults.
        let lead = try XCTUnwrap(ProjectCodec.decode(current).tracks.first?.instrument)
        XCTAssertEqual(lead.value(.textureRule), 0)
        XCTAssertEqual(lead.value(.textureDensity), 0.6)
        XCTAssertEqual(lead.value(.textureRate), 8)
        XCTAssertEqual(lead.value(.textureSeed), 0)
        // A rule, an engine or a seed past its range refuses the song.
        for (from, to) in [("\"synth.textureRule\": 2", "\"synth.textureRule\": 8"),
                           ("\"synth.engine\": 10", "\"synth.engine\": 11"),
                           ("\"synth.textureSeed\": 4711", "\"synth.textureSeed\": 10000"),
                           ("\"synth.textureRate\": 12", "\"synth.textureRate\": 41")] {
            let broken = String(decoding: formatFourTexture, as: UTF8.self).replacingOccurrences(of: from, with: to)
            XCTAssertNotEqual(Data(broken.utf8), formatFourTexture, "the replacement must land")
            XCTAssertThrowsError(try ProjectCodec.decode(Data(broken.utf8)), to)
        }
    }

    func testASynthOpensOnTheDDSPEngineWithItsProfile() throws {
        let project = try ProjectCodec.decode(formatFourDDSPProfile)
        let instrument = try XCTUnwrap(project.tracks.first?.instrument)
        XCTAssertEqual(instrument.value(.engine), 6)
        XCTAssertEqual(SynthParameter.engine.choices[6], "DDSP")
        XCTAssertEqual(instrument.value(.ddspProfile), 5)
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(project)), project)
        // A song without a profile plays profile 0.
        let lead = try XCTUnwrap(ProjectCodec.decode(current).tracks.first?.instrument)
        XCTAssertEqual(lead.value(.ddspProfile), 0)
        // A profile past its list refuses the song.
        for (from, to) in [("\"synth.ddspProfile\": 5", "\"synth.ddspProfile\": 10"),
                           ("\"synth.ddspProfile\": 5", "\"synth.ddspProfile\": -1")] {
            let broken = String(decoding: formatFourDDSPProfile, as: UTF8.self).replacingOccurrences(of: from, with: to)
            XCTAssertNotEqual(Data(broken.utf8), formatFourDDSPProfile, "the replacement must land")
            XCTAssertThrowsError(try ProjectCodec.decode(Data(broken.utf8)), to)
        }
    }

    func testASongOpensWithItsMarkersAndAnOlderOneWithNone() throws {
        let project = try ProjectCodec.decode(formatFourMarkers)
        XCTAssertEqual(project.markers, [Marker(tick: 0, name: "Intro"), Marker(tick: 15_360, name: "Drop")])
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(project)) as? [String: Any])
        let stored = try XCTUnwrap(root["markers"] as? [[String: Any]])
        XCTAssertEqual(stored.count, 2)
        XCTAssertEqual(Set(stored[0].keys), ["tick", "name"])
        for data in [earliest, current, formatTwo, formatTwoMedia, formatThree, formatFour, formatFourWavetable] {
            let older = try ProjectCodec.decode(data)
            XCTAssertTrue(older.markers.isEmpty, "an older song has no markers")
            let written = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(older)) as? [String: Any])
            XCTAssertNil(written["markers"], "a song without markers writes no key")
        }
        // Markers out of order, on one tick twice, past the song's end or without a name refuse the song.
        let text = String(decoding: formatFourMarkers, as: UTF8.self)
        for (from, to) in [("\"tick\": 15360", "\"tick\": 0"), ("\"tick\": 15360", "\"tick\": 99999999999"),
                           ("\"name\": \"Drop\"", "\"name\": \"  \""), ("\"tick\": 0,", "\"tick\": -1,")] {
            let broken = text.replacingOccurrences(of: from, with: to)
            XCTAssertNotEqual(broken, text, "the replacement must land")
            XCTAssertThrowsError(try ProjectCodec.decode(Data(broken.utf8)), "\(to)")
        }
    }

    func testASongOpensWithItsLightShowAndAnOlderOneWithNone() throws {
        let project = try ProjectCodec.decode(formatFourLighting)
        let lighting = project.lighting
        XCTAssertEqual(lighting.fixtures.map(\.profile), [.movingHead, .strobe, nil])
        XCTAssertEqual(lighting.fixtures[2].profileName, "fogMachine", "a profile this build does not know is kept")
        let head = lighting.fixtures[0].id
        XCTAssertEqual(lighting.cues[0].value(.pan, of: head), 0.25)
        XCTAssertEqual(lighting.cues[0].values[0].values["laterKey"], 0.5, "an attribute this build does not know is kept")
        XCTAssertTrue(lighting.cues[1].followsSong)
        XCTAssertEqual(lighting.placements.map(\.tick), [0, 7_680])
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(project)) as? [String: Any])
        let stored = try XCTUnwrap(root["lighting"] as? [String: Any])
        XCTAssertEqual(Set(stored.keys), ["fixtures", "cues", "placements"])
        XCTAssertEqual((stored["fixtures"] as? [[String: Any]])?[2]["profile"] as? String, "fogMachine")
        XCTAssertNil((stored["cues"] as? [[String: Any]])?[0]["look"], "a snapshot cue writes no look")
        for data in [earliest, current, formatTwo, formatTwoMedia, formatThree, formatFour, formatFourMarkers] {
            let older = try ProjectCodec.decode(data)
            XCTAssertTrue(older.lighting.isEmpty, "an older song has no light show")
            let written = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(older)) as? [String: Any])
            XCTAssertNil(written["lighting"], "a song without a light show writes no key")
        }
        // Overlapping fixtures, a channel past 512, a value past 1, a placement naming no cue, a
        // cue naming no fixture, or placements out of order refuse the song.
        let text = String(decoding: formatFourLighting, as: UTF8.self)
        for (from, to) in [("\"address\": 9", "\"address\": 8"), ("\"address\": 9", "\"address\": 512"),
                           ("\"red\": 1", "\"red\": 1.5"), ("\"tick\": 7680", "\"tick\": 0"),
                           ("\"cue\": \"C0E00000-0000-4000-8000-000000000002\"", "\"cue\": \"C0E00000-0000-4000-8000-000000000009\""),
                           ("\"fixture\": \"F1C70000-0000-4000-8000-000000000001\"", "\"fixture\": \"F1C70000-0000-4000-8000-000000000009\""),
                           ("\"fade\": 2", "\"fade\": -1"), ("\"universe\": 2", "\"universe\": 65")] {
            let broken = text.replacingOccurrences(of: from, with: to)
            XCTAssertNotEqual(broken, text, "the replacement must land")
            XCTAssertThrowsError(try ProjectCodec.decode(Data(broken.utf8)), "\(to)")
        }
    }

    func testASongOpensWithItsSubtitlesAndAnOlderOneWithNone() throws {
        let project = try ProjectCodec.decode(formatFourSubtitles)
        XCTAssertEqual(project.subtitles.map(\.start), [0, 3_840])
        XCTAssertEqual(project.subtitles.map(\.end), [2_880, 7_680])
        XCTAssertEqual(project.subtitles.map(\.text), ["Hello and welcome", "The quick brown fox jumps over the lazy dog"])
        XCTAssertEqual(Subtitles.srt(for: project), """
        1
        00:00:00,000 --> 00:00:01,500
        Hello and welcome

        2
        00:00:02,000 --> 00:00:04,000
        The quick brown fox jumps over the lazy
        dog


        """)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(project)) as? [String: Any])
        let stored = try XCTUnwrap(root["subtitles"] as? [[String: Any]])
        XCTAssertEqual(stored.count, 2)
        XCTAssertEqual(Set(stored[0].keys), ["id", "start", "end", "text"])
        for data in [earliest, current, formatTwo, formatTwoMedia, formatThree, formatFour, formatFourMarkers, formatFourLighting] {
            let older = try ProjectCodec.decode(data)
            XCTAssertTrue(older.subtitles.isEmpty, "an older song has no subtitles")
            let written = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(older)) as? [String: Any])
            XCTAssertNil(written["subtitles"], "a song without subtitles writes no key")
        }
        // Cues that overlap, end before they start, carry an empty text, a line break or three
        // lines, or share an id refuse the song.
        let text = String(decoding: formatFourSubtitles, as: UTF8.self)
        for (from, to) in [("\"start\": 3840", "\"start\": 2000"), ("\"end\": 2880", "\"end\": 0"),
                           ("\"Hello and welcome\"", "\"  \""), ("\"Hello and welcome\"", "\"Hello\\nwelcome\""),
                           ("\"Hello and welcome\"", "\"" + Array(repeating: "word", count: 20).joined(separator: " ") + "\""),
                           ("000000000002", "000000000001")] {
            let broken = text.replacingOccurrences(of: from, with: to)
            XCTAssertNotEqual(broken, text, "the replacement must land")
            XCTAssertThrowsError(try ProjectCodec.decode(Data(broken.utf8)), "\(to)")
        }
    }

    func testATrackOpensWithItsTakeFolderAndAnOlderOneWithNone() throws {
        let project = try ProjectCodec.decode(formatFourTakes)
        let folder = try XCTUnwrap(project.tracks.first?.takeGroups.first)
        let a = try XCTUnwrap(UUID(uuidString: "4E610000-0000-4000-8000-000000000007"))
        let b = try XCTUnwrap(UUID(uuidString: "4E610000-0000-4000-8000-000000000008"))
        XCTAssertEqual(folder.takes, [a, b])
        XCTAssertEqual(folder.comp, [CompSegment(start: 0, end: 1_920, take: a), CompSegment(start: 1_920, end: 3_840, take: b)])
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(project)) as? [String: Any])
        let track = try XCTUnwrap((root["tracks"] as? [[String: Any]])?.first)
        let stored = try XCTUnwrap((track["takeGroups"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(stored.keys), ["id", "takes", "comp"])
        XCTAssertEqual(Set(try XCTUnwrap((stored["comp"] as? [[String: Any]])?.first).keys), ["start", "end", "take"])
        for data in [earliest, current, formatTwo, formatTwoMedia, formatThree, formatFour, formatFourRegionEdits] {
            let older = try ProjectCodec.decode(data)
            XCTAssertTrue(older.tracks.allSatisfy { $0.takeGroups.isEmpty }, "an older song has no take folders")
            let written = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(older)) as? [String: Any])
            for stored in try XCTUnwrap(written["tracks"] as? [[String: Any]]) {
                XCTAssertNil(stored["takeGroups"], "a track without takes writes no key")
            }
        }
        // A comp naming a take of no folder, or stretches that overlap, refuse the song.
        let text = String(decoding: formatFourTakes, as: UTF8.self)
        for (from, to) in [("\"start\": 1920, \"end\": 3840, \"take\": \"4E610000-0000-4000-8000-000000000008\"",
                            "\"start\": 1920, \"end\": 3840, \"take\": \"4E610000-0000-4000-8000-0000000000FF\""),
                           ("\"start\": 1920, \"end\": 3840", "\"start\": 1000, \"end\": 3840")] {
            let broken = text.replacingOccurrences(of: from, with: to)
            XCTAssertNotEqual(broken, text, "the replacement must land")
            XCTAssertThrowsError(try ProjectCodec.decode(Data(broken.utf8)), to)
        }
    }

    func testAnOlderSongOpensWithNoVideo() throws {
        for data in [earliest, current, formatTwo, formatTwoMedia, formatThree] {
            let project = try ProjectCodec.decode(data)
            XCTAssertFalse(project.tracks.contains { $0.kind == .video })
            XCTAssertTrue(project.media.allSatisfy { $0.kind == .audio })
        }
    }
}
