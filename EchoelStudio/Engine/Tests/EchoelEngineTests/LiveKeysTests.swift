import EchoelCore
import Foundation
import XCTest
@testable import EchoelEngine

/// The held keys of the live instrument: every release ends the note its press started, and no
/// slot ever hears a pitch struck twice without a release between.
final class LiveKeysTests: XCTestCase {
    private typealias Message = LiveKeys.Message

    private func on(_ pitch: UInt8, slot: Int = 0, channel: UInt8 = 0, velocity: UInt8 = 100) -> Message {
        Message(slot: slot, channel: channel, pitch: pitch, velocity: velocity)
    }

    private func off(_ pitch: UInt8, slot: Int = 0, channel: UInt8 = 0) -> Message {
        Message(slot: slot, channel: channel, pitch: pitch, velocity: 0)
    }

    /// C major: every key to the nearest pitch in the scale, a tie to the lower one.
    private let cMajor: [UInt8] = (0...127).map { (pitch: Int) -> UInt8 in UInt8(MusicalContext(scale: .major).nearest(pitch)) }

    /// The lock holds a melodic instrument's keys in the key and scale, and leaves alone what has
    /// nothing to hold: a drum kit, whose keys pick drums, and a scale that frames nothing.
    func testTheLockHoldsAMelodicInstrumentInTheScaleAndLeavesDrumsAlone() throws {
        let major = MusicalContext(scale: .major)
        let table = try XCTUnwrap(LiveKeys.lock(for: major, device: .synth))
        XCTAssertEqual(table, cMajor)
        XCTAssertEqual(table[61], 60, "C♯ to C: a tie goes down")
        XCTAssertEqual(table[66], 65)
        XCTAssertEqual(table[64], 64)
        XCTAssertEqual(LiveKeys.lock(for: MusicalContext(root: 2, scale: .major), device: .sampler)?[60], 59,
                       "in D major C lies between B and C♯: the lower wins")
        XCTAssertNotNil(LiveKeys.lock(for: major, device: .plugin))
        XCTAssertNil(LiveKeys.lock(for: major, device: .drums))
        XCTAssertNil(LiveKeys.lock(for: major, device: .unrecognized))
        XCTAssertNil(LiveKeys.lock(for: MusicalContext(root: 5), device: .synth), "chromatic holds nothing")
        let later = try JSONDecoder().decode(MusicalContext.self, from: Data(
            #"{"root":0,"scale":"bebop","tuning":"edo12","concertPitch":440,"swing":0}"#.utf8))
        XCTAssertNil(LiveKeys.lock(for: later, device: .synth), "a scale this build does not know holds nothing")

        var keys = LiveKeys(lock: table)
        XCTAssertEqual(Array(keys.press(channel: 0, key: 61, velocity: 100, slot: 0)), [on(60)])
        XCTAssertEqual(Array(keys.release(channel: 0, key: 61)), [off(60)])
    }

    func testAKeyReleasedAfterTheLiveTrackChangedEndsTheNoteItStarted() {
        var keys = LiveKeys()
        XCTAssertEqual(Array(keys.press(channel: 0, key: 60, velocity: 100, slot: 0)), [on(60)])
        XCTAssertEqual(Array(keys.press(channel: 0, key: 64, velocity: 90, slot: 1)), [on(64, slot: 1, velocity: 90)])
        XCTAssertEqual(Array(keys.release(channel: 0, key: 60)), [off(60)], "in slot 0, where it began")
        XCTAssertEqual(Array(keys.release(channel: 0, key: 64)), [off(64, slot: 1)])
        XCTAssertEqual(keys.press(channel: 0, key: 62, velocity: 0, slot: 0).count, 0, "velocity 0 is a release")
    }

    func testAReleaseEndsThePitchThePressSoundedWhateverTheKeyMapsToNow() {
        var keys = LiveKeys(lock: cMajor)
        XCTAssertEqual(Array(keys.press(channel: 0, key: 61, velocity: 100, slot: 0)), [on(60)], "C♯ sounds C")
        keys.lock = nil
        XCTAssertEqual(Array(keys.release(channel: 0, key: 61)), [off(60)], "not 61, which never sounded")
    }

    /// Two keys on one pitch share the note: the second strikes it again, the first release is
    /// silent, the last one ends it.
    func testTwoKeysOnOnePitchStrikeItAgainAndTheLastReleaseEndsIt() {
        var keys = LiveKeys(lock: cMajor)
        XCTAssertEqual(Array(keys.press(channel: 0, key: 60, velocity: 100, slot: 0)), [on(60)])
        XCTAssertEqual(Array(keys.press(channel: 0, key: 61, velocity: 80, slot: 0)), [off(60), on(60, velocity: 80)])
        XCTAssertEqual(keys.release(channel: 0, key: 60).count, 0, "C♯ still holds C")
        XCTAssertEqual(Array(keys.release(channel: 0, key: 61)), [off(60)])

        // The instrument hears no channel, so the same pitch from two channels is one note too.
        var channels = LiveKeys()
        XCTAssertEqual(Array(channels.press(channel: 0, key: 60, velocity: 100, slot: 0)), [on(60)])
        XCTAssertEqual(Array(channels.press(channel: 3, key: 60, velocity: 100, slot: 0)), [off(60, channel: 3), on(60, channel: 3)])
        XCTAssertEqual(channels.release(channel: 3, key: 60).count, 0)
        XCTAssertEqual(Array(channels.release(channel: 0, key: 60)), [off(60)])

        // In two slots it is two notes.
        var slots = LiveKeys()
        _ = slots.press(channel: 0, key: 60, velocity: 100, slot: 0)
        XCTAssertEqual(Array(slots.press(channel: 1, key: 60, velocity: 100, slot: 1)), [on(60, slot: 1, channel: 1)])
    }

    func testAKeyStruckAgainWithoutAReleaseEndsWhatItHeldFirst() {
        var keys = LiveKeys(lock: cMajor)
        _ = keys.press(channel: 0, key: 61, velocity: 100, slot: 0)
        keys.lock = nil
        XCTAssertEqual(Array(keys.press(channel: 0, key: 61, velocity: 100, slot: 0)), [off(60), on(61)])
        // Also when the live track changed in between: the first slot's note is not left sounding.
        XCTAssertEqual(Array(keys.press(channel: 0, key: 61, velocity: 100, slot: 2)), [off(61), on(61, slot: 2)])
        XCTAssertEqual(Array(keys.release(channel: 0, key: 61)), [off(61, slot: 2)])
    }

    func testAReleaseOfAKeyNeverPressedSendsNothing() {
        var keys = LiveKeys()
        XCTAssertEqual(keys.release(channel: 0, key: 60).count, 0)
        _ = keys.press(channel: 0, key: 60, velocity: 100, slot: 0)
        keys.reset()
        XCTAssertEqual(keys.release(channel: 0, key: 60).count, 0, "a new core has none of the old one's notes")
        var short = LiveKeys(lock: [60])
        XCTAssertEqual(Array(short.press(channel: 0, key: 61, velocity: 100, slot: 0)), [on(61)],
                       "a table that is not 128 long plays every key as itself")
    }

    /// Any sequence of presses, releases, scale changes and live-track changes: no slot hears a
    /// pitch struck while it sounds, never a release of a pitch that is not sounding, and once every
    /// key is up nothing sounds.
    func testEverySlotsPitchesStayPairedWhateverIsPlayed() {
        var keys = LiveKeys()
        var held = Set<Int>()
        var sounding = Set<Int>()
        var seed: UInt64 = 0x5EED
        func next(_ bound: Int) -> Int {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((seed >> 33) % UInt64(bound))
        }
        func check(_ output: LiveKeys.Output) {
            for message in output {
                let note = message.slot * 128 + Int(message.pitch)
                if message.velocity > 0 {
                    XCTAssertTrue(sounding.insert(note).inserted, "struck while it sounds: \(message)")
                } else {
                    XCTAssertNotNil(sounding.remove(note), "released while silent: \(message)")
                }
            }
        }
        let pentatonic = MusicalContext(root: 2, scale: .minorPentatonic)
        let dPentatonic: [UInt8] = (0...127).map { (pitch: Int) -> UInt8 in UInt8(pentatonic.nearest(pitch)) }
        let tables: [[UInt8]?] = [nil, cMajor, dPentatonic]
        for _ in 0..<5_000 {
            let channel = UInt8(next(3)), key = UInt8(55 + next(12)), slot = next(3)
            switch next(10) {
            case 0: keys.lock = tables[next(tables.count)]
            case 1...5:
                check(keys.press(channel: channel, key: key, velocity: UInt8(1 + next(127)), slot: slot))
                held.insert(Int(channel) * 128 + Int(key))
            default:
                check(keys.release(channel: channel, key: key))
                held.remove(Int(channel) * 128 + Int(key))
            }
        }
        for key in held.sorted() { check(keys.release(channel: UInt8(key / 128), key: UInt8(key % 128))) }
        XCTAssertTrue(sounding.isEmpty, "still sounding once every key is up: \(sounding.sorted())")
    }

    /// Two keys on one pitch pressed in one buffer reach the take at one position, as on, off, on:
    /// it records the one held note the musician heard, ending with the last release.
    func testTwoKeysOnOnePitchPressedTogetherRecordOneHeldNote() throws {
        var keys = LiveKeys(lock: cMajor)
        var take = MIDITake()
        func record(_ output: LiveKeys.Output, at tick: Tick) {
            for message in output {
                if message.velocity > 0 {
                    take.noteOn(pitch: Int(message.pitch), velocity: Int(message.velocity), at: tick)
                } else {
                    take.noteOff(pitch: Int(message.pitch), at: tick)
                }
            }
        }
        let first = keys.press(channel: 0, key: 60, velocity: 100, slot: 0)
        let second = keys.press(channel: 0, key: 61, velocity: 90, slot: 0)
        record(first, at: 0)
        record(second, at: 0)
        record(keys.release(channel: 0, key: 60), at: 480)
        record(keys.release(channel: 0, key: 61), at: 720)
        let clip = try XCTUnwrap(take.clip(endingAt: 3_840, bar: 3_840))
        XCTAssertEqual(clip.notes.map(\.pitch), [60])
        XCTAssertEqual(clip.notes.map { $0.start + $0.length }, [720])
    }

    /// What the take keeps is what was heard: two keys on one pitch record two notes of that
    /// pitch, the second ending with the last release, and nothing at the key's own pitch.
    func testATakeOfTheLatchedNotesNeverOutlastsTheLastRelease() throws {
        var keys = LiveKeys(lock: cMajor)
        var take = MIDITake()
        func record(_ output: LiveKeys.Output, at tick: Tick) {
            for message in output {
                if message.velocity > 0 {
                    take.noteOn(pitch: Int(message.pitch), velocity: Int(message.velocity), at: tick)
                } else {
                    take.noteOff(pitch: Int(message.pitch), at: tick)
                }
            }
        }
        record(keys.press(channel: 0, key: 60, velocity: 100, slot: 0), at: 0)
        record(keys.press(channel: 0, key: 61, velocity: 100, slot: 0), at: 240)
        record(keys.release(channel: 0, key: 60), at: 480)
        record(keys.release(channel: 0, key: 61), at: 720)
        let clip = try XCTUnwrap(take.clip(endingAt: 3_840, bar: 3_840))
        XCTAssertEqual(clip.notes.map(\.pitch), [60, 60])
        XCTAssertEqual(clip.notes.map(\.start), [0, 240])
        XCTAssertEqual(clip.notes.map { $0.start + $0.length }, [240, 720])
    }
}
