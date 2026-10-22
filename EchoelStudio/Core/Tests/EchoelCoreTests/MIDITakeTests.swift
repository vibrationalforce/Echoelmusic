import XCTest
@testable import EchoelCore

final class MIDITakeTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)

    private func describe(_ notes: [Note]) -> [String] {
        notes.map { "\($0.pitch)@\($0.start)+\($0.length) v\($0.velocity)" }
    }

    func testAPlayedNoteBecomesANoteInAClipOnItsBar() throws {
        var take = MIDITake()
        take.noteOn(pitch: 60, velocity: 90, at: bar + 480)
        take.noteOff(pitch: 60, at: bar + 960)
        let clip = try XCTUnwrap(take.clip(endingAt: bar + 1_000, bar: bar))
        XCTAssertEqual(clip.start, bar)
        XCTAssertEqual(clip.length, bar)
        XCTAssertEqual(describe(clip.notes), ["60@480+480 v90"])
    }

    func testTheClipRunsWholeBarsPastTheLastNote() throws {
        var take = MIDITake()
        take.noteOn(pitch: 60, velocity: 100, at: 100)
        take.noteOff(pitch: 60, at: 2 * bar + 10)
        let clip = try XCTUnwrap(take.clip(endingAt: 3 * bar, bar: bar))
        XCTAssertEqual(clip.start, 0)
        XCTAssertEqual(clip.length, 3 * bar)
    }

    func testAKeyStillHeldEndsWhereTheTakeStops() throws {
        var take = MIDITake()
        take.noteOn(pitch: 64, velocity: 80, at: 0)
        let clip = try XCTUnwrap(take.clip(endingAt: 720, bar: bar))
        XCTAssertEqual(describe(clip.notes), ["64@0+720 v80"])
    }

    func testAKeyStruckAgainEndsTheNoteBefore() throws {
        var take = MIDITake()
        take.noteOn(pitch: 60, velocity: 100, at: 0)
        take.noteOn(pitch: 60, velocity: 50, at: 240)
        take.noteOff(pitch: 60, at: 480)
        let clip = try XCTUnwrap(take.clip(endingAt: 480, bar: bar))
        XCTAssertEqual(describe(clip.notes), ["60@0+240 v100", "60@240+240 v50"])
    }

    func testVelocityZeroIsANoteOffAndAStrayOffIsIgnored() throws {
        var take = MIDITake()
        take.noteOff(pitch: 61, at: 10)
        take.noteOn(pitch: 60, velocity: 100, at: 0)
        take.noteOn(pitch: 60, velocity: 0, at: 120)
        let clip = try XCTUnwrap(take.clip(endingAt: 500, bar: bar))
        XCTAssertEqual(describe(clip.notes), ["60@0+120 v100"])
    }

    func testANoteOnAndOffAtOneTickStillLastsATick() throws {
        var take = MIDITake()
        take.noteOn(pitch: 60, velocity: 100, at: 50)
        take.noteOff(pitch: 60, at: 50)
        XCTAssertEqual(try XCTUnwrap(take.clip(endingAt: 60, bar: bar)).notes.first?.length, 1)
    }

    /// Two keys the scale lock maps to one pitch, pressed in one buffer, arrive as on, off, on at
    /// one position: the take keeps the held note, not a one-tick remnant beside it. A note played
    /// and released on one tick and not struck again still lasts a tick.
    func testANoteEndedAndStruckAgainOnOneTickIsOneHeldNote() throws {
        var take = MIDITake()
        take.noteOn(pitch: 60, velocity: 100, at: 240)
        take.noteOff(pitch: 60, at: 240)
        take.noteOn(pitch: 60, velocity: 90, at: 240)
        take.noteOn(pitch: 64, velocity: 80, at: 240)
        take.noteOff(pitch: 64, at: 240)
        take.noteOff(pitch: 60, at: 960)
        let clip = try XCTUnwrap(take.clip(endingAt: 960, bar: bar))
        XCTAssertEqual(describe(clip.notes), ["60@240+720 v90", "64@240+1 v80"])

        // Two such remnants: removing the first must not lose track of the second.
        var chord = MIDITake()
        for pitch in [60, 62] {
            chord.noteOn(pitch: pitch, velocity: 100, at: 0)
            chord.noteOff(pitch: pitch, at: 0)
        }
        for pitch in [60, 62] { chord.noteOn(pitch: pitch, velocity: 100, at: 0) }
        let held = try XCTUnwrap(chord.clip(endingAt: 480, bar: bar))
        XCTAssertEqual(describe(held.notes), ["60@0+480 v100", "62@0+480 v100"])
    }

    func testNothingPlayedIsNoClip() {
        var take = MIDITake()
        take.noteOn(pitch: 200, velocity: 100, at: 0)
        XCTAssertTrue(take.isEmpty)
        XCTAssertNil(take.clip(endingAt: bar, bar: bar))
    }

    func testTheWheelAndPedalAreKeptInClipTime() throws {
        var take = MIDITake()
        take.control(.controller(number: 64), value: 127, at: bar - 100)   // pedal down before the clip's bar
        take.control(.pitchBend, value: 9_000, at: bar - 50)
        take.control(.pitchBend, value: 10_000, at: bar - 10)
        take.noteOn(pitch: 60, velocity: 100, at: bar + 10)
        take.control(.pitchBend, value: 12_000, at: bar + 200)
        take.noteOff(pitch: 60, at: bar + 400)
        take.control(.controller(number: 64), value: 0, at: 3 * bar)       // after the clip ends
        take.control(.controller(number: 123), value: 0, at: bar + 300)    // a channel-mode message
        take.control(.pitchBend, value: 20_000, at: bar + 300)             // out of range
        let clip = try XCTUnwrap(take.clip(endingAt: 3 * bar + 10, bar: bar))
        XCTAssertEqual(clip.start, bar)
        XCTAssertEqual(clip.controls.map { "\($0.kind) \($0.start) \($0.value)" },
                       ["controller(number: 64) 0 127", "pitchBend 0 10000", "pitchBend 200 12000"],
                       "a move before the bar is set at its start with its last value; one past the end is dropped")
    }

    func testTheResultIsAValidClip() throws {
        var take = MIDITake()
        take.noteOn(pitch: 60, velocity: 300, at: 5 * bar + 7)
        take.noteOff(pitch: 60, at: 5 * bar + 100)
        let clip = try XCTUnwrap(take.clip(endingAt: 6 * bar, bar: bar))
        var project = Project()
        let track = TrackID(), id = ClipID()
        try Command.addTrack(id: track, name: "K", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: id, name: "Take", length: clip.length).apply(to: &project)
        try Command.addNotes(id, clip.notes).apply(to: &project)
        try Command.setControls(id, clip.controls).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: id, start: clip.start).apply(to: &project)
        XCTAssertEqual(project.tracks[0].clips[0].notes.first?.velocity, 127)
    }
}
