import EchoelCore
import XCTest
@testable import EchoelEngine

/// The ruler's locate: where Stop returns (the cue) and that a seek to a bar plays that bar.
final class LocateTests: XCTestCase {
    private let rate = 48_000.0
    private let bar = MusicalTime.ticksPerBar(.common)

    // MARK: The cue

    func testAStopWhilePlayingReturnsToTheCueAndASecondStopToBarOne() {
        var cue = PlayStartCue()
        XCTAssertEqual(cue.stop(whilePlaying: true), 0, "without a cue Stop goes back to bar 1")
        cue.set(2 * bar)
        XCTAssertEqual(cue.stop(whilePlaying: true), 2 * bar, "the first Stop goes back to the cue")
        XCTAssertEqual(cue.tick, 2 * bar, "and keeps it for the next Play")
        XCTAssertEqual(cue.stop(whilePlaying: true), 2 * bar)
        XCTAssertEqual(cue.stop(whilePlaying: false), 0, "a Stop while stopped goes back to bar 1")
        XCTAssertNil(cue.tick, "and forgets the cue")
        XCTAssertEqual(cue.stop(whilePlaying: true), 0)
    }

    func testTheCueStaysInsideWhatASongHolds() {
        var cue = PlayStartCue()
        cue.set(-480)
        XCTAssertEqual(cue.tick, 0)
        cue.set(.max)
        XCTAssertEqual(cue.tick, MusicalTime.maximumTick)
        cue.clear()
        XCTAssertNil(cue.tick)
    }

    // MARK: Locating plays the bar it names

    func testAfterASeekToBarThreeTheFirstNoteHeardIsBarThreesNote() throws {
        var project = Project(tempo: 120)
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "C", length: 4 * bar).apply(to: &project)
        // One quarter note at the start of each bar: 60 in bar 1, 62, 64, 65 in bar 4.
        let pitches: [Int] = [60, 62, 64, 65]
        var notes: [Note] = []
        for (index, pitch) in pitches.enumerated() {
            notes.append(Note(pitch: pitch, start: Tick(index) * bar, length: MusicalTime.ticksPerQuarter))
        }
        try Command.addNotes(clip, notes).apply(to: &project)
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)

        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: project)
        let slot = try XCTUnwrap(slots.slots[track])
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project,
                                    slots: slots.slots, sampleRate: rate, generation: 1))
        render(core, frames: 256)
        core.setNoteOut(slot: slot)
        while core.noteOut.pop() != nil {}

        // The seek the ruler's locate makes (`AudioEngine.seek(toTick:)`), stopped, then Play.
        let barThree = TimeConversion(tempoMap: project.tempoMap, sampleRate: rate).sample(at: 2 * bar)
        XCTAssertEqual(barThree, 192_000, "120 BPM in 4/4: a bar is two seconds")
        core.seek(toSample: barThree)
        core.play()
        render(core, frames: 24_000)
        var heard: [UInt8] = []
        while let message = core.noteOut.pop() {
            if message.status == 0x90 { heard.append(message.data1) }
        }
        XCTAssertEqual(heard.first, 64, "bar 3's note, not bar 1's")
        XCTAssertFalse(heard.contains(60) || heard.contains(62), "nothing before the locate plays")
        XCTAssertGreaterThan(core.positionSample, barThree, "the song plays on from bar 3")
    }

    private func render(_ core: EngineCore, frames: Int, block: Int = 256) {
        var left = [Float](repeating: 0, count: block)
        var right = [Float](repeating: 0, count: block)
        var done = 0
        while done < frames {
            let count = Swift.min(block, frames - done)
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    core.render(frameCount: count, left: lp, right: rp)
                }
            }
            done += count
        }
    }
}
