import EchoelCore
import XCTest
@testable import EchoelEngine

/// MIDI Time Code (W17-TC): the label arithmetic, the two wire forms, the generator on the
/// engine's sample counter, and the chase.
final class MIDITimecodeTests: XCTestCase {
    private let rate = 48_000.0

    // MARK: - Drop-frame

    func testDropFrameMinuteOneBeginsAtFrameTwoAndMinuteTenAtFrameZero() {
        let df = MTCRate.fps29_97DropFrame
        XCTAssertEqual(Timecode(frameCount: 1_799, rate: df), Timecode(hours: 0, minutes: 0, seconds: 59, frames: 29))
        XCTAssertEqual(Timecode(frameCount: 1_800, rate: df), Timecode(hours: 0, minutes: 1, seconds: 0, frames: 2),
                       "00 and 01 of minute 1 are dropped")
        XCTAssertEqual(Timecode(frameCount: 17_981, rate: df), Timecode(hours: 0, minutes: 9, seconds: 59, frames: 29))
        XCTAssertEqual(Timecode(frameCount: 17_982, rate: df), Timecode(hours: 0, minutes: 10, seconds: 0, frames: 0),
                       "every tenth minute keeps its 00")
        XCTAssertEqual(Timecode(frameCount: 107_892, rate: df), Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0))
        XCTAssertNil(Timecode(hours: 0, minutes: 1, seconds: 0, frames: 0).frameCount(rate: df), "a dropped label is none")
        XCTAssertNil(Timecode(hours: 0, minutes: 1, seconds: 0, frames: 1).frameCount(rate: df))
        XCTAssertEqual(Timecode(hours: 0, minutes: 10, seconds: 0, frames: 0).frameCount(rate: df), 17_982)
        XCTAssertEqual(Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0).frameCount(rate: .fps30), 108_000)
        XCTAssertEqual(Timecode(hours: 0, minutes: 1, seconds: 0, frames: 2).text(rate: df), "00:01:00;02")
    }

    func testEveryFrameOfADayRoundTripsThroughItsLabel() {
        for rate in MTCRate.allCases {
            var count: Int64 = 0
            // Every frame of the first eleven minutes, then one in 97 to the end of the day.
            while count < rate.framesPerDay {
                let label = Timecode(frameCount: count, rate: rate)
                XCTAssertEqual(label.frameCount(rate: rate), count, "\(rate) \(count)")
                count += count < 20_000 ? 1 : 97
            }
            XCTAssertEqual(Timecode(frameCount: rate.framesPerDay, rate: rate), Timecode(hours: 0, minutes: 0, seconds: 0, frames: 0),
                           "24 hours wraps")
        }
    }

    // MARK: - Quarter frames

    func testQuarterFramesRoundTripForEveryRate() {
        let labels = [Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0), Timecode(hours: 23, minutes: 59, seconds: 59, frames: 23),
                      Timecode(hours: 17, minutes: 42, seconds: 31, frames: 22), Timecode(hours: 0, minutes: 10, seconds: 0, frames: 0)]
        for rate in MTCRate.allCases {
            for label in labels {
                var decoder = MTCQuarterFrameDecoder()
                var decoded: MTCQuarterFrameDecoder.Decoded?
                for piece in 0..<8 {
                    let data = MTCQuarterFrame.data(piece: piece, of: label, rate: rate)
                    XCTAssertEqual(Int(data >> 4), piece)
                    decoded = decoder.receive(data)
                    if piece < 7 { XCTAssertNil(decoded) }
                }
                XCTAssertEqual(decoded, .init(timecode: label, rate: rate), "\(rate) \(label)")
            }
        }
    }

    func testAQuarterFrameOutOfOrderStartsTheSequenceOver() {
        let label = Timecode(hours: 1, minutes: 2, seconds: 3, frames: 4)
        let pieces = (0..<8).map { MTCQuarterFrame.data(piece: $0, of: label, rate: .fps25) }
        var decoder = MTCQuarterFrameDecoder()
        for data in pieces[0..<3] { XCTAssertNil(decoder.receive(data)) }
        for data in pieces[4..<8] { XCTAssertNil(decoder.receive(data)) } // piece 3 lost
        for data in pieces[0..<7] { XCTAssertNil(decoder.receive(data)) }
        XCTAssertEqual(decoder.receive(pieces[7])?.timecode, label)
    }

    func testTheLastPieceCarriesTheRateCode() {
        let label = Timecode(hours: 16, minutes: 0, seconds: 0, frames: 0)
        XCTAssertEqual(MTCQuarterFrame.data(piece: 7, of: label, rate: .fps24), 0x71)
        XCTAssertEqual(MTCQuarterFrame.data(piece: 7, of: label, rate: .fps25), 0x73)
        XCTAssertEqual(MTCQuarterFrame.data(piece: 7, of: label, rate: .fps29_97DropFrame), 0x75)
        XCTAssertEqual(MTCQuarterFrame.data(piece: 7, of: label, rate: .fps30), 0x77)
    }

    // MARK: - Full frame

    func testTheFullFrameIsTheTenBytesOfTheSpec() {
        let frame = MTCFullFrame(timecode: Timecode(hours: 1, minutes: 2, seconds: 3, frames: 4), rate: .fps25)
        XCTAssertEqual(frame.bytes, [0xF0, 0x7F, 0x7F, 0x01, 0x01, 0x21, 0x02, 0x03, 0x04, 0xF7])
        let df = MTCFullFrame(timecode: Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0), rate: .fps29_97DropFrame)
        XCTAssertEqual(df.bytes[5], 0x41)
        let thirty = MTCFullFrame(timecode: Timecode(hours: 23, minutes: 0, seconds: 0, frames: 0), rate: .fps30)
        XCTAssertEqual(thirty.bytes[5], 0x77)
    }

    func testTheFullFramesPacketsAreReadBack() {
        for rate in MTCRate.allCases {
            let frame = MTCFullFrame(timecode: Timecode(hours: 10, minutes: 20, seconds: 30, frames: rate.nominal - 1), rate: rate)
            let words = frame.universalPackets
            XCTAssertEqual(words.0 >> 28, 0x3, "System Exclusive 7-bit")
            XCTAssertEqual((words.0 >> 20) & 0xF, 1, "start")
            XCTAssertEqual((words.2 >> 20) & 0xF, 3, "end")
            var reader = MTCSysExReader()
            XCTAssertNil(reader.read(words.0, words.1))
            XCTAssertEqual(reader.read(words.2, words.3), frame)
        }
    }

    func testTheSysExReaderSkipsOtherMessages() {
        var reader = MTCSysExReader()
        // A complete identity request (7E 7F 06 01): not MTC.
        let identity = UInt32(0x3) << 28 | 4 << 16 | 0x7E << 8 | 0x7F
        XCTAssertNil(reader.read(identity, 0x0601_0000))
        // An end without a start.
        XCTAssertNil(reader.read(UInt32(0x3) << 28 | 0x3 << 20 | 2 << 16, 0))
        // A long message continuing past eight bytes.
        let frame = MTCFullFrame(timecode: Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0), rate: .fps25).universalPackets
        XCTAssertNil(reader.read(frame.0, frame.1))
        XCTAssertNil(reader.read(UInt32(0x3) << 28 | 0x2 << 20 | 6 << 16, 0))
        XCTAssertNil(reader.read(frame.2, frame.3))
    }

    // MARK: - Generator

    func testTheGeneratorSendsFourQuarterFramesAFrameOnTheSampleCounter() {
        for mtc in MTCRate.allCases {
            var generator = MTCGenerator(sampleRate: rate)
            let start = Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0).frameCount(rate: mtc) ?? 0
            generator.configure(rate: mtc, startFrames: start)
            let ring = TimecodeRing()
            // One second in blocks of 256, as the render thread sees it.
            var from: Int64 = 0
            var times: [Int64] = []
            var data: [UInt8] = []
            while from < 48_000 {
                generator.sendQuarterFrames(from: from, to: Swift.min(from + 256, 48_000), into: ring, hostTime: 0, chunkStart: 0)
                while let message = ring.pop() {
                    times.append(from + Int64(message.frame))
                    data.append(message.data)
                }
                from += 256
            }
            XCTAssertEqual(Double(times.count), (4 * mtc.framesPerSecond).rounded(.up), "\(mtc)")
            XCTAssertEqual(times.first, 0, "piece 0 of 01:00:00:00 at the song's first sample")
            for (index, time) in times.enumerated() {
                let exact = Double(index) * rate / (4 * mtc.framesPerSecond)
                XCTAssertEqual(Double(time), exact.rounded(.up), accuracy: 0.5)
            }
            var decoder = MTCQuarterFrameDecoder()
            let decoded = data.compactMap { decoder.receive($0) }
            XCTAssertEqual(decoded.first?.timecode, Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0))
            XCTAssertEqual(decoded.dropFirst().first?.timecode, Timecode(frameCount: start + 2, rate: mtc))
        }
    }

    func testTheGeneratorPicksUpMidSequenceAfterALocate() {
        var generator = MTCGenerator(sampleRate: rate)
        generator.configure(rate: .fps25, startFrames: 90_000)
        let ring = TimecodeRing()
        // 1.5 frames in: quarter frame 6 of the first sequence.
        generator.sendQuarterFrames(from: 2_880, to: 2_881, into: ring, hostTime: 0, chunkStart: 0)
        XCTAssertEqual(ring.pop()?.data, MTCQuarterFrame.data(piece: 6, of: Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0), rate: .fps25))
        XCTAssertEqual(generator.frameCount(atSample: 48_000), 90_025)
    }

    func testTheEngineSendsAFullFrameAtAStartAndALocateAndQuarterFramesOnlyWhilePlaying() {
        let engine = EngineCore(sampleRate: rate)
        engine.setClickEnabled(false)
        let project = Project(tempo: 120)
        let slots = SlotAssigner(capacity: engine.slotCapacity)
        engine.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                      sampleRate: rate, generation: 1, outputChannels: 2))
        render(engine, frames: 4_800)
        XCTAssertNil(engine.timecodeOut.pop(), "nothing is timed while MTC out is off")

        engine.setTimecodeOut(rate: .fps25, startFrames: 90_000)
        render(engine, frames: 256)
        XCTAssertEqual(engine.timecodeOut.pop()?.fullFrame?.timecode, Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0),
                       "switching it on tells the receiver where the song stands")
        XCTAssertNil(engine.timecodeOut.pop(), "no quarter frames while stopped")

        engine.play()
        render(engine, frames: 48_000)
        var messages: [TimecodeMessage] = []
        while let message = engine.timecodeOut.pop() { messages.append(message) }
        XCTAssertEqual(messages.first?.status, 0xF0, "a start begins with a full frame")
        XCTAssertEqual(messages.filter { $0.status == MTCQuarterFrame.status }.count, 100)

        engine.seek(toSample: 96_000)
        render(engine, frames: 256)
        XCTAssertEqual(engine.timecodeOut.pop()?.fullFrame?.timecode, Timecode(hours: 1, minutes: 0, seconds: 2, frames: 0))

        engine.stop()
        while engine.timecodeOut.pop() != nil {}
        render(engine, frames: 256)
        XCTAssertEqual(engine.timecodeOut.pop()?.fullFrame?.timecode, Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0),
                       "Stop goes home, and says so")
        XCTAssertNil(engine.timecodeOut.pop())

        engine.setTimecodeOut(rate: nil, startFrames: 0)
        engine.play()
        render(engine, frames: 4_800)
        XCTAssertNil(engine.timecodeOut.pop(), "off again: nothing")
    }

    private func render(_ engine: EngineCore, frames: Int) {
        var left = [Float](repeating: 0, count: 256), right = [Float](repeating: 0, count: 256)
        var done = 0
        while done < frames {
            let n = Swift.min(256, frames - done)
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    engine.render(frameCount: n, left: lp, right: rp)
                }
            }
            done += n
        }
    }

    // MARK: - Chase

    /// A sender at 25 fps from 01:00:00:00, its quarter frames arriving on time from `seconds`.
    private func quarterFrames(fromFrame frame: Int64, quarters: Int, rate mtc: MTCRate = .fps25) -> [(UInt8, Double)] {
        var generator = MTCGenerator(sampleRate: 48_000)
        generator.configure(rate: mtc, startFrames: 0)
        return (0..<quarters).map { (index: Int) -> (UInt8, Double) in
            let quarter = frame * 4 + Int64(index)
            return (generator.data(ofQuarter: quarter), Double(quarter) / (4 * mtc.framesPerSecond))
        }
    }

    func testTheChaseLocatesAtAFullFrame() {
        var chase = MTCChase(start: Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0))
        let frame = MTCFullFrame(timecode: Timecode(hours: 1, minutes: 0, seconds: 10, frames: 0), rate: .fps25)
        XCTAssertEqual(chase.receiveFullFrame(frame), .locate(seconds: 10))
        XCTAssertFalse(chase.isRunning)
        let early = MTCFullFrame(timecode: Timecode(hours: 0, minutes: 59, seconds: 0, frames: 0), rate: .fps25)
        XCTAssertEqual(chase.receiveFullFrame(early), .locate(seconds: 0), "before the song: its start")
    }

    func testTheChaseFollowsTheQuarterFramesAtTheTimeTheLastPieceArrived() throws {
        var chase = MTCChase(start: Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0))
        var follows: [MTCChase.Action] = []
        for (data, time) in quarterFrames(fromFrame: 90_250, quarters: 16) {
            if let action = chase.receiveQuarterFrame(data, at: time) { follows.append(action) }
        }
        XCTAssertEqual(follows.count, 2, "one per eight pieces")
        guard case .follow(let seconds, let at) = try XCTUnwrap(follows.first) else { return XCTFail("not a follow") }
        // Piece 7 of the sequence of 01:00:10:00 is sent 1.75 frames later, at 10.07 s of song.
        XCTAssertEqual(at, (90_250 * 4 + 7) / 100, accuracy: 1e-9)
        XCTAssertEqual(seconds, at - 3_600, accuracy: 1e-9, "the song stands where the sender is")
        XCTAssertTrue(chase.isRunning)
        XCTAssertEqual(chase.rate, .fps25)
    }

    func testTheChaseFollowsDropFrameOnTheClock() throws {
        var chase = MTCChase(start: Timecode(hours: 1, minutes: 0, seconds: 0, frames: 0))
        var last: MTCChase.Action?
        for (data, time) in quarterFrames(fromFrame: 107_892 + 1_800, quarters: 8, rate: .fps29_97DropFrame) {
            last = chase.receiveQuarterFrame(data, at: time) ?? last
        }
        guard case .follow(let seconds, let at) = try XCTUnwrap(last) else { return XCTFail("not a follow") }
        XCTAssertEqual(seconds, at - Double(107_892) * 1.001 / 30, accuracy: 1e-9)
        XCTAssertEqual(seconds, 1_801.75 * 1.001 / 30, accuracy: 1e-9)
    }

    func testTheChaseStopsWhenFourFramesPassWithoutAQuarterFrame() {
        var chase = MTCChase(start: Timecode(hours: 0, minutes: 0, seconds: 0, frames: 0))
        let frames = quarterFrames(fromFrame: 100, quarters: 8)
        for (data, time) in frames { _ = chase.receiveQuarterFrame(data, at: time) }
        let last = frames[7].1
        XCTAssertNil(chase.check(at: last + 3.9 / 25), "under four frames: still running")
        XCTAssertEqual(chase.check(at: last + 4.1 / 25), .stop)
        XCTAssertFalse(chase.isRunning)
        XCTAssertNil(chase.check(at: last + 10), "stopped once")
    }

    func testTheChaseNudgesWithinTheToleranceAndJumpsBeyondIt() {
        var chase = MTCChase(start: Timecode(hours: 0, minutes: 0, seconds: 0, frames: 0), toleranceFrames: 2)
        for (data, time) in quarterFrames(fromFrame: 0, quarters: 8) { _ = chase.receiveQuarterFrame(data, at: time) }
        XCTAssertEqual(chase.correction(gap: 0.001), .nudge(seconds: 0), "jitter is left alone")
        XCTAssertEqual(chase.correction(gap: 0.02), .nudge(seconds: 0.01))
        XCTAssertEqual(chase.correction(gap: -0.079), .nudge(seconds: -0.0395), "just inside two frames at 25 fps")
        XCTAssertEqual(chase.correction(gap: 0.081), .relocate)
        XCTAssertEqual(chase.correction(gap: -1), .relocate)
        XCTAssertEqual(chase.correction(gap: .nan), .nudge(seconds: 0))
    }
}
