import XCTest
@testable import EchoelCore

/// The arpeggiator (EDIT-2): which held note each step plays, where the steps fall, and how the
/// plan plays a track's clips through it.
final class ArpeggioTests: XCTestCase {
    private let q = MusicalTime.ticksPerQuarter
    private var sixteenth: Tick { q / 4 }

    private func sequence(_ order: ArpOrder, count: Int, octaves: Int = 1, steps: Int, seed: UInt32 = 1) -> [Int] {
        (0..<steps).map { (step: Int) -> Int in
            let choice = ArpPattern.pick(step: step, count: count, octaves: octaves, order: order, seed: seed)
            return choice.index + choice.octave * 10
        }
    }

    func testEveryOrderWalksTheHeldNotesAsItsNameSays() {
        XCTAssertEqual(sequence(.up, count: 3, steps: 7), [0, 1, 2, 0, 1, 2, 0])
        XCTAssertEqual(sequence(.down, count: 3, steps: 4), [2, 1, 0, 2])
        XCTAssertEqual(sequence(.upDown, count: 3, steps: 9), [0, 1, 2, 1, 0, 1, 2, 1, 0], "the turn plays no note twice")
        XCTAssertEqual(sequence(.downUp, count: 3, steps: 5), [2, 1, 0, 1, 2])
        XCTAssertEqual(sequence(.asPlayed, count: 3, steps: 4), [0, 1, 2, 0], "an index into the notes as pressed")
        XCTAssertEqual(sequence(.up, count: 2, octaves: 2, steps: 5), [0, 1, 10, 11, 0], "two octaves, then again")
        XCTAssertEqual(sequence(.upDown, count: 1, steps: 3), [0, 0, 0], "one note is one note")
        XCTAssertEqual(sequence(.down, count: 2, octaves: 3, steps: 6), [21, 20, 11, 10, 1, 0])
    }

    func testTheRandomOrderIsTheSameForTheSameSeedAndOnlyPlaysHeldNotes() {
        let a = sequence(.random, count: 4, octaves: 2, steps: 64, seed: 7)
        XCTAssertEqual(a, sequence(.random, count: 4, octaves: 2, steps: 64, seed: 7), "every pass and every export alike")
        XCTAssertNotEqual(a, sequence(.random, count: 4, octaves: 2, steps: 64, seed: 8))
        XCTAssertTrue(a.allSatisfy { [0, 1, 2, 3, 10, 11, 12, 13].contains($0) })
        XCTAssertGreaterThan(Set(a).count, 4, "it is not stuck on a few notes")
    }

    func testAnOctaveAboveTheRangeFoldsBack() {
        XCTAssertEqual(ArpPattern.pitch(60, octave: 2), 84)
        XCTAssertEqual(ArpPattern.pitch(120, octave: 1), 120, "132 folds back to 120")
        XCTAssertEqual(ArpPattern.pitch(127, octave: 3), 127)
    }

    func testTheStepsCountFromEveryBarLine() {
        let common = MeterMap(signature: .common)
        XCTAssertEqual(ArpGrid.start(atOrAfter: 0, step: q, meter: common), 0)
        XCTAssertEqual(ArpGrid.start(atOrAfter: 1, step: q, meter: common), q)
        // 7/8 then 4/4: the last quarter of the 7/8 bar is an eighth, the next bar starts on its downbeat.
        let odd = MeterMap(signature: TimeSignature(7, 8), changes: [TimeSignatureChange(tick: 7 * q / 2, signature: .common)])
        XCTAssertEqual(ArpGrid.start(atOrAfter: 3 * q + 1, step: q, meter: odd), 7 * q / 2, "the bar line, not 4 quarters")
        XCTAssertEqual(ArpGrid.end(ofStepAt: 3 * q, step: q, meter: odd), 7 * q / 2, "a short last step")
        XCTAssertEqual(ArpGrid.end(ofStepAt: 7 * q / 2, step: q, meter: odd), 9 * q / 2)
        XCTAssertEqual(ArpGrid.noteLength(from: 0, to: 240, gate: 0.5), 120)
        XCTAssertEqual(ArpGrid.noteLength(from: 0, to: 2, gate: 0.05), 1, "never shorter than a tick")
    }

    private func song(_ notes: [Note], arpeggio: Arpeggio?, clipLength: Tick? = nil) throws -> (Project, TrackID) {
        var project = Project()
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "C", length: clipLength ?? 4 * q).apply(to: &project)
        try Command.addNotes(clip, notes).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        if let arpeggio { try Command.setArpeggio(track, arpeggio).apply(to: &project) }
        return (project, track)
    }

    private func ons(_ events: [PlaybackPlan.NoteEvent]) -> [(Tick, UInt8, UInt8)] {
        events.compactMap { event in
            if case .noteOn(let velocity) = event.kind { return (event.tick, event.pitch, velocity) }
            return nil
        }
    }

    func testAHeldChordPlaysOneNoteAStepWithItsOwnVelocity() throws {
        let chord = [Note(pitch: 64, velocity: 90, start: 0, length: q), Note(pitch: 60, velocity: 100, start: 0, length: q),
                     Note(pitch: 67, velocity: 80, start: 0, length: q)]
        let (project, _) = try song(chord, arpeggio: Arpeggio(rate: .sixteenth, order: .up, gate: 0.5))
        let events = try XCTUnwrap(PlaybackPlan(compiling: project).tracks.first).events
        let played = ons(events)
        XCTAssertEqual(played.map(\.0), [0, 240, 480, 720])
        XCTAssertEqual(played.map(\.1), [60, 64, 67, 60])
        XCTAssertEqual(played.map(\.2), [100, 90, 80, 100])
        let offs = events.filter { $0.kind == .noteOff }.map(\.tick)
        XCTAssertEqual(offs, [120, 360, 600, 840], "half of every step")
        XCTAssertTrue(Set(played.map(\.1)).isSubset(of: [60, 64, 67]), "no note the player did not hold")
    }

    func testOffTheArpeggiatorAndAbsentPlayTheNotesAsWritten() throws {
        let chord = [Note(pitch: 60, start: 0, length: q), Note(pitch: 64, start: 0, length: q)]
        let (plain, _) = try song(chord, arpeggio: nil)
        var off = Arpeggio()
        off.isOn = false
        let (switchedOff, _) = try song(chord, arpeggio: off)
        XCTAssertEqual(PlaybackPlan(compiling: plain).tracks.first?.events, PlaybackPlan(compiling: switchedOff).tracks.first?.events)
        XCTAssertEqual(ons(try XCTUnwrap(PlaybackPlan(compiling: plain).tracks.first).events).count, 2)
    }

    func testALateKeyStartsOnTheNextStepAndAsPlayedKeepsThePressOrder() throws {
        let notes = [Note(pitch: 72, start: 10, length: q), Note(pitch: 60, start: 300, length: q)]
        let (project, _) = try song(notes, arpeggio: Arpeggio(rate: .sixteenth, order: .asPlayed))
        let played = ons(try XCTUnwrap(PlaybackPlan(compiling: project).tracks.first).events)
        XCTAssertEqual(played.first?.0, 240, "the phrase waits for the grid")
        XCTAssertEqual(Array(played.map(\.1).prefix(4)), [72, 60, 72, 60], "72 was pressed first")
    }

    func testLatchHoldsTheChordUntilThePlacementEnds() throws {
        let tap = [Note(pitch: 60, start: 0, length: 10), Note(pitch: 67, start: 0, length: 10)]
        let (project, _) = try song(tap, arpeggio: Arpeggio(rate: .quarter, latch: true), clipLength: 4 * q)
        let played = ons(try XCTUnwrap(PlaybackPlan(compiling: project).tracks.first).events)
        XCTAssertEqual(played.map(\.0), [0, q, 2 * q, 3 * q], "held to the end of the clip, no further")
        XCTAssertEqual(played.map(\.1), [60, 67, 60, 67])
        let (plain, _) = try song(tap, arpeggio: Arpeggio(rate: .quarter, latch: false))
        XCTAssertEqual(ons(try XCTUnwrap(PlaybackPlan(compiling: plain).tracks.first).events).count, 1, "without latch: one step")
    }

    func testANewChordOnReleasedKeysReplacesTheLatchedOne() throws {
        let notes = [Note(pitch: 60, start: 0, length: 10), Note(pitch: 72, start: 2 * q, length: 10)]
        let (project, _) = try song(notes, arpeggio: Arpeggio(rate: .quarter, latch: true))
        let played = ons(try XCTUnwrap(PlaybackPlan(compiling: project).tracks.first).events)
        XCTAssertEqual(played.map(\.1), [60, 60, 72, 72])
    }

    func testALaunchedClipArpeggiatesInsideItsLength() throws {
        let chord = [Note(pitch: 60, start: 0, length: 4 * q), Note(pitch: 64, start: 0, length: 4 * q)]
        let (project, _) = try song(chord, arpeggio: Arpeggio(rate: .quarter, gate: 1), clipLength: 2 * q + q / 2)
        let loop = try XCTUnwrap(PlaybackPlan(compiling: project).tracks.first?.clips.first)
        XCTAssertEqual(ons(loop.events).map(\.0), [0, q, 2 * q])
        XCTAssertTrue(loop.events.allSatisfy { $0.tick <= loop.length }, "nothing sounds past the loop")
    }

    func testTheArpeggioIsOneUndoStepAndValidatedAtTheDoor() async throws {
        try await MainActor.run {
            let store = ProjectStore()
            let track = TrackID(), audio = TrackID()
            try store.perform(.addTrack(id: track, name: "Keys", kind: .instrument, index: nil))
            try store.perform(.addTrack(id: audio, name: "Vox", kind: .audio, index: nil))
            try store.perform(.setArpeggio(track, Arpeggio(order: .down, octaves: 3)))
            XCTAssertEqual(store.undoTitle, "Arpeggiator")
            XCTAssertEqual(store.project.track(track)?.arpeggio?.octaves, 3)
            store.undo()
            XCTAssertNil(store.project.track(track)?.arpeggio)
            XCTAssertThrowsError(try store.perform(.setArpeggio(track, Arpeggio(octaves: 5))))
            XCTAssertThrowsError(try store.perform(.setArpeggio(track, Arpeggio(gate: .nan))))
            XCTAssertThrowsError(try store.perform(.setArpeggio(track, Arpeggio(seed: -1))))
            XCTAssertThrowsError(try store.perform(.setArpeggio(audio, Arpeggio())), "an audio track has no notes")
            XCTAssertNil(store.project.track(track)?.arpeggio, "a refused setting changes nothing")
        }
    }

    func testTheSettingsReachThePlansSource() throws {
        let (project, track) = try song([Note(pitch: 60, start: 0, length: q)], arpeggio: nil)
        var arpeggiated = project
        try Command.setArpeggio(track, Arpeggio()).apply(to: &arpeggiated)
        XCTAssertNotEqual(PlaybackPlan.Source(project), PlaybackPlan.Source(arpeggiated), "switching it on compiles again")
        var signed = arpeggiated
        try Command.setTimeSignature(TimeSignature(3, 4)).apply(to: &signed)
        XCTAssertNotEqual(PlaybackPlan.Source(arpeggiated), PlaybackPlan.Source(signed), "its steps count in bars")
    }
}
