import EchoelCore
import XCTest
@testable import EchoelEngine

/// The count-in before Record: counted in the render clock, so its clicks and the downbeat fall on
/// exact samples whatever the buffer size, and the take starts on bar 1 beat 1.
final class CountInTests: XCTestCase {
    private let rate = 48_000.0

    private func oneBar(_ project: Project) throws -> CountIn {
        try XCTUnwrap(CountIn(bars: 1, at: 0, tempoMap: project.tempoMap, meterMap: project.meterMap, sampleRate: rate))
    }

    // MARK: The arithmetic

    func testOneBarAt120BPMInFourFourIsFourBeatsOfHalfASecond() throws {
        let project = Project(tempo: 120)
        let countIn = try oneBar(project)
        XCTAssertEqual(countIn.beats, 4)
        XCTAssertEqual(countIn.beatSamples, 24_000)
        XCTAssertEqual(countIn.preRollSamples, 96_000)
        XCTAssertEqual(countIn.onsets, [0, 24_000, 48_000, 72_000])
        let accents: [Bool] = (0..<4).map { (beat: Int) -> Bool in countIn.isAccented(beat: beat) }
        XCTAssertEqual(accents, [true, false, false, false], "the bar's first click is the accented one")
        XCTAssertEqual(countIn.beatsLeft(remaining: 96_000), 4)
        XCTAssertEqual(countIn.beatsLeft(remaining: 72_001), 4)
        XCTAssertEqual(countIn.beatsLeft(remaining: 72_000), 3)
        XCTAssertEqual(countIn.beatsLeft(remaining: 1), 1)
        XCTAssertEqual(countIn.beatsLeft(remaining: 0), 0)

        let two = try XCTUnwrap(CountIn(bars: 2, at: 0, tempoMap: project.tempoMap, meterMap: project.meterMap,
                                        sampleRate: rate))
        XCTAssertEqual(two.beats, 8)
        XCTAssertNil(CountIn(bars: 0, at: 0, tempoMap: project.tempoMap, meterMap: project.meterMap, sampleRate: rate),
                     "Off counts nothing in")
    }

    func testEveryLengthOnTheMenuHasATitleAndOffIsTheFirst() {
        XCTAssertEqual(CountIn.Length.allCases.map(\.rawValue), [0, 1, 2])
        XCTAssertEqual(Set(CountIn.Length.allCases.map(\.title)).count, 3)
    }

    // MARK: The render clock

    func testAOneBarCountInClicksFourTimesBeforeSongSampleZeroAndTheTakeStartsOnBarOne() throws {
        let project = Project(tempo: 120)
        let core = try playingCore(project)
        let begin = LoopRecording.Moment(sample: core.positionSample, played: core.playedFrames)
        let countIn = try oneBar(project)
        core.startCountIn(countIn)
        XCTAssertTrue(core.countsIn, "Record's count-in holds the recorder from the moment it is asked for")

        // 333 frames a buffer: the downbeat falls inside one, never on a buffer's edge.
        let before = render(core, frames: Int(countIn.preRollSamples), block: 333)
        XCTAssertEqual(onsets(in: before), [0, 24_000, 48_000, 72_000], "four clicks, each on its beat's sample")
        XCTAssertFalse(core.countsIn, "the count-in is over on its last sample")
        XCTAssertEqual(core.positionSample, 0, "the playhead waited at bar 1 through the count-in")
        XCTAssertEqual(core.playedFrames, begin.played, "nothing of the song played before the downbeat")

        // A note played on the downbeat, and one a beat later.
        var events = [LoopRecording.Event(moment: LoopRecording.Moment(sample: core.positionSample, played: core.playedFrames),
                                          status: 0x90, data1: 60, data2: 100)]
        let after = render(core, frames: 24_000, block: 333)
        XCTAssertEqual(core.positionSample, 24_000, "the song started on the downbeat's exact sample")
        XCTAssertEqual(core.playedFrames, begin.played + 24_000)
        XCTAssertEqual(onsets(in: after).first, 0, "the song's own click comes on song sample 0, after the count-in")
        let beatTwo = LoopRecording.Moment(sample: core.positionSample, played: core.playedFrames)
        events.append(LoopRecording.Event(moment: beatTwo, status: 0x80, data1: 60, data2: 0))
        events.append(LoopRecording.Event(moment: beatTwo, status: 0x90, data1: 62, data2: 100))
        _ = render(core, frames: 24_000, block: 333)
        let end = LoopRecording.Moment(sample: core.positionSample, played: core.playedFrames)
        events.append(LoopRecording.Event(moment: end, status: 0x80, data1: 62, data2: 0))

        let time = TimeConversion(tempoMap: project.tempoMap, sampleRate: rate)
        let passes = LoopRecording.midiPasses(events, from: begin, to: end, wraps: [], loop: nil, latency: 0,
                                              time: time, meter: project.meterMap)
        let take = try XCTUnwrap(passes.first)
        XCTAssertEqual(passes.count, 1)
        XCTAssertEqual(take.start, 0, "the take is placed at bar 1")
        let starts: [Tick] = take.notes.map { (note: Note) -> Tick in take.start + note.start }.sorted()
        XCTAssertEqual(starts, [0, MusicalTime.ticksPerQuarter], "the first note on bar 1 beat 1, the next on beat 2")
    }

    func testRecordDuringTheCountInCallsItOffWithNothingPlayed() throws {
        let project = Project(tempo: 120)
        let core = try playingCore(project)
        core.startCountIn(try oneBar(project))
        let counted = render(core, frames: 30_000, block: 256)
        XCTAssertEqual(onsets(in: counted), [0, 24_000])
        XCTAssertTrue(core.countsIn)

        core.cancelCountIn()
        let rest = render(core, frames: 120_000, block: 256)
        XCTAssertEqual(onsets(in: rest), [], "no click after the cancel")
        XCTAssertFalse(core.countsIn)
        XCTAssertFalse(core.transportPlays, "the song does not start")
        XCTAssertEqual(core.positionSample, 0)
        XCTAssertEqual(core.playedFrames, 0, "nothing played, so nothing could be recorded")
    }

    func testACountInAskedForWhilePlayingIsIgnored() throws {
        let project = Project(tempo: 120)
        let core = try playingCore(project)
        core.play()
        _ = render(core, frames: 4_800, block: 256)
        core.startCountIn(try oneBar(project))
        _ = render(core, frames: 4_800, block: 256)
        XCTAssertFalse(core.countsIn)
        XCTAssertEqual(core.positionSample, 9_600, "the song plays on without a pause")
    }

    // MARK: Helpers

    /// A core holding an empty song at bar 1, stopped, its click on.
    private func playingCore(_ project: Project) throws -> EngineCore {
        let core = EngineCore(sampleRate: rate)
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project,
                                    slots: [:], sampleRate: rate, generation: 1))
        _ = render(core, frames: 256, block: 256)
        XCTAssertEqual(core.positionSample, 0)
        return core
    }

    /// Where each click starts in `samples`: a click is a sine from phase 0, so its first sample is
    /// silent and the second is not; a start is a sound after a long silence.
    private func onsets(in samples: [Float]) -> [Int] {
        var found: [Int] = []
        var quiet = Int.max / 2
        for (index, value) in samples.enumerated() {
            if value != 0 {
                if quiet >= 1_000 { found.append(Swift.max(0, index - 1)) }
                quiet = 0
            } else {
                quiet += 1
            }
        }
        return found
    }

    /// Renders `frames` in buffers of `block` and returns the left channel.
    private func render(_ core: EngineCore, frames: Int, block: Int) -> [Float] {
        var out: [Float] = []
        out.reserveCapacity(frames)
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
            out.append(contentsOf: left[0..<count])
            done += count
        }
        return out
    }
}
