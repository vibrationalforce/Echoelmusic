import EchoelCore
import XCTest
@testable import EchoelEngine

/// The first MIDI take on the "Four Tracks" starter, with every default left as it is: its one
/// placed clip (the empty one-bar "Beat") makes the song one bar long, and it plays no note. So
/// the take runs freely instead of folding into that bar, and sixteen bars played are a sixteen-bar
/// clip. The app reads the same functions when a take begins (`AudioEngine` publish: the loop to
/// the larger of the plan's end and `Arranging.placedEnd`; `LoopRecording.midiTakeRunsFreely`).
final class StarterFirstTakeTests: XCTestCase {
    private let rate = 48_000.0

    func testTheFirstTakeOnTheFourTracksStarterIsAsLongAsWhatWasPlayed() throws {
        var project = try StarterProject.fourTracks.project()
        let meter = project.meterMap
        let bar = meter.ticksPerBar(at: 0)
        let time = TimeConversion(bpm: project.tempo, sampleRate: rate)
        let keys = try XCTUnwrap(project.tracks.first, "Keys comes first")
        XCTAssertEqual(keys.name, "Keys")

        XCTAssertFalse(project.arrangementHasSound, "the starter holds no note")
        let songEnd = Swift.max(PlaybackPlan(compiling: project).songEnd, Arranging.placedEnd(of: project))
        let loop = Arranging.songLoop(songEnd: songEnd, meter: meter)
        XCTAssertEqual(loop, 0..<bar, "the empty Beat makes a one-bar song")
        let passes = LoopRecording.recordsPasses(over: loop, meter: meter)
        XCTAssertFalse(passes, "one bar is too short to record passes over")
        let free = LoopRecording.midiTakeRunsFreely(songSounds: project.arrangementHasSound, recordsPasses: passes)
        XCTAssertTrue(free)
        XCTAssertFalse(LoopRecording.loopRuns(isOn: true, freeTake: false, freeMIDITake: free, over: loop,
                                              meter: meter, timecodeRuns: false),
                       "the loop rests under the take, so the playhead never wraps")

        // One note on the first beat of each of sixteen bars, a quarter long; Stop at the end of bar 16.
        var events: [LoopRecording.Event] = []
        for index in 0..<16 {
            let on = time.sample(at: Tick(index) * bar)
            let off = time.sample(at: Tick(index) * bar + MusicalTime.ticksPerQuarter)
            events.append(.init(moment: .init(sample: on, played: on), status: 0x90, data1: 60, data2: 100))
            events.append(.init(moment: .init(sample: off, played: off), status: 0x80, data1: 60, data2: 0))
        }
        let stop = time.sample(at: 16 * bar)
        let taken = LoopRecording.midiPasses(events, from: .init(sample: 0, played: 0), to: .init(sample: stop, played: stop),
                                             wraps: [], loop: loop, latency: 0, time: time, meter: meter)
        XCTAssertEqual(taken.count, 1, "one clip, not sixteen bars folded into one")
        let clip = try XCTUnwrap(taken.first)
        XCTAssertEqual(clip.start, 0)
        XCTAssertEqual(clip.length, 16 * bar, "as long as what was played")
        XCTAssertEqual(clip.notes.count, 16)
        XCTAssertEqual(clip.notes.last?.start, 15 * bar, "the last note stays in bar 16")

        for command in LoopRecording.midiCommands(taken, track: keys.id, firstNumber: 1) {
            try command.apply(to: &project)
        }
        XCTAssertEqual(Arranging.songBars(of: project), 16, "Arrange then counts sixteen bars")
        let afterTake = Swift.max(PlaybackPlan(compiling: project).songEnd, Arranging.placedEnd(of: project))
        XCTAssertEqual(Arranging.songLoop(songEnd: afterTake, meter: meter), 0..<(16 * bar),
                       "and the song loops all sixteen")
    }
}
