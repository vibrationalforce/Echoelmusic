import EchoelCore
import XCTest
@testable import EchoelEngine

final class InputMonitorTests: XCTestCase {
    private let rate = 48_000.0
    private let centre = Float(0.5).squareRoot()

    private func engine(_ project: Project, monitoring: [TrackID: Int]) -> EngineCore {
        let engine = EngineCore(sampleRate: rate)
        engine.setClickEnabled(false)
        engine.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: [:],
                                      sampleRate: rate, generation: 1, monitoring: monitoring))
        return engine
    }

    /// Writes `frames` of `value` on input `channel`, then renders as many.
    private func pass(_ engine: EngineCore, channel: Int, value: Float, frames: Int) -> [Float] {
        let input = [Float](repeating: value, count: frames)
        input.withUnsafeBufferPointer { b in
            if let base = b.baseAddress { engine.inputs.write(channel: channel, base, count: frames) }
        }
        var left = [Float](repeating: 0, count: frames), right = left
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                engine.render(frameCount: frames, left: lp, right: rp)
            }
        }
        return left
    }

    func testAMonitoredTrackPlaysItsInputThroughItsStripEvenWhileStopped() throws {
        var p = Project()
        let vocal = TrackID(), other = TrackID()
        try Command.addTrack(id: vocal, name: "Vocal", kind: .audio, index: nil).apply(to: &p)
        try Command.addTrack(id: other, name: "Guitar", kind: .audio, index: nil).apply(to: &p)
        let core = engine(p, monitoring: [vocal: 2])
        XCTAssertTrue(core.inputs.isWanted(2))
        XCTAssertFalse(core.inputs.isWanted(0), "an input nothing plays is not copied")
        _ = pass(core, channel: 2, value: 0.5, frames: 256)
        let heard = pass(core, channel: 2, value: 0.5, frames: 256)
        XCTAssertEqual(heard[255], 0.5 * centre, accuracy: 1e-4, "at the track's centre gain, transport stopped")

        try Command.setMute(vocal, true).apply(to: &p)
        let silent = engine(p, monitoring: [vocal: 2])
        for _ in 0..<4 { _ = pass(silent, channel: 2, value: 0.5, frames: 256) }
        XCTAssertTrue(pass(silent, channel: 2, value: 0.5, frames: 256).allSatisfy { $0 == 0 }, "its strip rules the input")
    }

    /// After Stop the song's tails ring out at the gains where it stopped, but a monitored input
    /// is new sound: it is heard at the playhead's level again (review 2026-10-23). The vocal's
    /// volume falls from 0 dB at bar 1 to silence at bar 2; stopped in bar 3, the playhead goes
    /// home to bar 1.
    func testAMonitoredInputAfterStopIsHeardAtThePlayheadsLevel() throws {
        var p = Project(tempo: 120)
        let vocal = TrackID()
        try Command.addTrack(id: vocal, name: "Vocal", kind: .audio, index: nil).apply(to: &p)
        try Command.setAutomation(.volume(vocal), points: [
            AutomationPoint(tick: 0, value: 0),
            AutomationPoint(tick: MusicalTime.ticksPerBar(.common), value: MixerStrip.volumeRange.lowerBound),
        ]).apply(to: &p)
        let core = engine(p, monitoring: [vocal: 2])
        core.play()
        for _ in 0..<48 { _ = pass(core, channel: 2, value: 0.5, frames: 4_096) }   // 196,608 samples: bar 3
        XCTAssertEqual(pass(core, channel: 2, value: 0.5, frames: 256)[255], 0, "silent where the lane ends")
        core.stop()
        for _ in 0..<4 { _ = pass(core, channel: 2, value: 0.5, frames: 256) }
        XCTAssertEqual(pass(core, channel: 2, value: 0.5, frames: 256)[255], 0.5 * centre, accuracy: 1e-4,
                       "the input is heard at bar 1's level")
    }

    /// One block of `frames` on each input of `values`, inside one block of the input callback,
    /// then as many rendered; returns both sides.
    private func passPair(_ engine: EngineCore, _ values: [Int: Float], frames: Int) -> (left: [Float], right: [Float]) {
        engine.inputs.writeBlock {
            for (channel, value) in values.sorted(by: { $0.key < $1.key }) {
                let input = [Float](repeating: value, count: frames)
                input.withUnsafeBufferPointer { b in
                    if let base = b.baseAddress { engine.inputs.write(channel: channel, base, count: frames) }
                }
            }
        }
        var left = [Float](repeating: 0, count: frames), right = left
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                engine.render(frameCount: frames, left: lp, right: rp)
            }
        }
        return (left, right)
    }

    func testAStereoMonitoredTrackPlaysItsLeftInputLeftAndItsRightInputRight() throws {
        var p = Project()
        let keys = TrackID()
        try Command.addTrack(id: keys, name: "Keys", kind: .audio, index: nil).apply(to: &p)
        let engine = EngineCore(sampleRate: rate)
        engine.setClickEnabled(false)
        engine.publish(EngineSnapshot(plan: PlaybackPlan(compiling: p), project: p, slots: [:], sampleRate: rate,
                                      generation: 1, monitoring: [keys: 2], monitoringRight: [keys: 3]))
        XCTAssertTrue(engine.inputs.isWanted(2))
        XCTAssertTrue(engine.inputs.isWanted(3), "both sides of the pair are copied")
        _ = passPair(engine, [2: 0.5, 3: 0.25], frames: 256)
        let heard = passPair(engine, [2: 0.5, 3: 0.25], frames: 256)
        XCTAssertEqual(heard.left[255], 0.5 * centre, accuracy: 1e-4, "input 3 on the left at the centre gain")
        XCTAssertEqual(heard.right[255], 0.25 * centre, accuracy: 1e-4, "input 4 on the right")

        try Command.setPan(.track(keys), pan: -1).apply(to: &p)
        engine.publish(EngineSnapshot(plan: PlaybackPlan(compiling: p), project: p, slots: [:], sampleRate: rate,
                                      generation: 2, monitoring: [keys: 2], monitoringRight: [keys: 3]))
        for _ in 0..<8 { _ = passPair(engine, [2: 0.5, 3: 0.25], frames: 256) }
        let left = passPair(engine, [2: 0.5, 3: 0.25], frames: 256)
        XCTAssertEqual(left.right[255], 0, accuracy: 1e-4, "panned hard left, the pan is a balance: the right side is gone")
        XCTAssertGreaterThan(left.left[255], 0.4, "and the left side stays")
    }

    func testAPairPastTheMonitoredInputsIsNotHeardAtAll() throws {
        var p = Project()
        let keys = TrackID(), voice = TrackID()
        try Command.addTrack(id: keys, name: "Keys", kind: .audio, index: nil).apply(to: &p)
        try Command.addTrack(id: voice, name: "Voice", kind: .audio, index: nil).apply(to: &p)
        let snapshot = EngineSnapshot(plan: PlaybackPlan(compiling: p), project: p, slots: [:], sampleRate: rate,
                                      generation: 1, monitoring: [keys: 15, voice: 4],
                                      monitoringRight: [keys: InputMonitor.channelLimit, voice: 4])
        let lanes = Dictionary(uniqueKeysWithValues: snapshot.audioLanes.map { ($0.track, $0) })
        XCTAssertEqual(lanes[keys]?.monitor, -1, "never half a pair")
        XCTAssertEqual(lanes[keys]?.monitorRight, -1)
        XCTAssertEqual(lanes[voice]?.monitor, 4, "a right side equal to the left is the one input")
        XCTAssertEqual(lanes[voice]?.monitorRight, -1)
        XCTAssertEqual(snapshot.inputGroups, [1 << 4])
    }

    func testInputsSharedBetweenPairsAndSingleInputsAreReadAsOneGroup() throws {
        var p = Project()
        let ids = (0..<4).map { _ in TrackID() }
        for (n, id) in ids.enumerated() {
            try Command.addTrack(id: id, name: "Track \(n)", kind: .audio, index: nil).apply(to: &p)
        }
        // 2 alone, the pair 2/3, the pair 6/7 and 7 alone: two groups, no input read twice.
        let snapshot = EngineSnapshot(plan: PlaybackPlan(compiling: p), project: p, slots: [:], sampleRate: rate,
                                      generation: 1, monitoring: [ids[0]: 2, ids[1]: 2, ids[2]: 6, ids[3]: 7],
                                      monitoringRight: [ids[1]: 3, ids[2]: 7])
        XCTAssertEqual(snapshot.inputGroups, [1 << 2 | 1 << 3, 1 << 6 | 1 << 7])
    }

    /// Writes the next `count` of a ramp that counts on from `from`, on each of `channels`.
    private func ramp(_ monitor: InputMonitor, _ channels: [Int], from: Int, count: Int) {
        let samples = (0..<count).map { (i: Int) -> Float in Float(from + i) }
        for channel in channels {
            samples.withUnsafeBufferPointer { b in
                if let base = b.baseAddress { monitor.write(channel: channel, base, count: count) }
            }
        }
    }

    /// Reads one chunk of the group of inputs 0 and 1; returns both.
    private func readPair(_ monitor: InputMonitor, frames: Int) -> (left: [Float], right: [Float]) {
        var both = [Float](repeating: 9, count: 2 * frames)
        both.withUnsafeMutableBufferPointer { b in
            guard let base = b.baseAddress else { return }
            monitor.read(group: 0b11, into: base, stride: frames, frames: frames)
        }
        return (Array(both[..<frames]), Array(both[frames...]))
    }

    func testAPairLinesUpOnItsNewestSamplesWhateverOneSideHeldBefore() {
        let monitor = InputMonitor()
        monitor.want([1])
        ramp(monitor, [1], from: 10_000, count: 300)   // what an earlier monitor of input 2 left
        monitor.want([0, 1])
        monitor.writeBlock { ramp(monitor, [0, 1], from: 0, count: 256) }
        let first = readPair(monitor, frames: 256)
        XCTAssertEqual(first.left, first.right, "the pair plays sample for sample from its first chunk")
        XCTAssertEqual(first.left[0], 0)
        var next = 256
        for _ in 0..<20 {
            monitor.writeBlock { ramp(monitor, [0, 1], from: next, count: 256) }
            next += 256
            let chunk = readPair(monitor, frames: 256)
            XCTAssertEqual(chunk.left, chunk.right)
        }
    }

    func testABlockHalfWrittenNeitherShiftsNorStartsThePair() {
        let monitor = InputMonitor()
        monitor.want([0, 1])
        // Not lined up yet, and the callback has written the left of a block but not its right:
        // the pair waits a chunk in silence instead of lining up on a block the right lacks.
        var inside: (left: [Float], right: [Float]) = ([], [])
        monitor.writeBlock {
            ramp(monitor, [0], from: 0, count: 256)
            inside = readPair(monitor, frames: 256)
            ramp(monitor, [1], from: 0, count: 256)
        }
        XCTAssertTrue(inside.left.allSatisfy { $0 == 0 } && inside.right.allSatisfy { $0 == 0 })
        var next = 256
        var heard = 0
        for round in 0..<20 {
            // Lined up, a chunk read halfway through a block plays only what both sides hold.
            monitor.writeBlock {
                ramp(monitor, [0], from: next, count: 256)
                if round.isMultiple(of: 3) {
                    let chunk = readPair(monitor, frames: 256)
                    XCTAssertEqual(chunk.left, chunk.right)
                    heard += chunk.left.filter { $0 != 0 }.count
                }
                ramp(monitor, [1], from: next, count: 256)
            }
            next += 256
            let chunk = readPair(monitor, frames: 256)
            XCTAssertEqual(chunk.left, chunk.right, "round \(round)")
            heard += chunk.left.filter { $0 != 0 }.count
        }
        XCTAssertGreaterThan(heard, 0, "the pair is heard once it is lined up")
        monitor.writeBlock { ramp(monitor, [0, 1], from: next, count: 256) }
        next += 256
        var alone = [Float](repeating: 0, count: 256)
        alone.withUnsafeMutableBufferPointer { b in
            if let base = b.baseAddress { monitor.read(channel: 0, into: base, frames: 256) }
        }
        // Input 1 read alone has given up a chunk input 2 still holds: the next pair read lines up again.
        monitor.writeBlock { ramp(monitor, [0, 1], from: next, count: 256) }
        let again = readPair(monitor, frames: 256)
        XCTAssertEqual(again.left, again.right)
        XCTAssertEqual(again.left.last, Float(next + 255), "lined up on the newest samples")
    }

    /// A block that reaches one side of a lined-up pair and not the other — here the right was not
    /// wanted for a moment, as in a snapshot the render never took — does not shift it for good.
    func testABlockOnlyOneSideGotDoesNotShiftThePairForGood() {
        let monitor = InputMonitor()
        monitor.want([0, 1])
        monitor.writeBlock { ramp(monitor, [0, 1], from: 0, count: 256) }
        XCTAssertEqual(readPair(monitor, frames: 256).left.first, 0)
        monitor.want([0])
        monitor.writeBlock { ramp(monitor, [0, 1], from: 256, count: 256) }
        _ = readPair(monitor, frames: 256)
        monitor.want([0, 1])
        var next = 512
        for _ in 0..<4 {
            monitor.writeBlock { ramp(monitor, [0, 1], from: next, count: 256) }
            next += 256
            let chunk = readPair(monitor, frames: 256)
            XCTAssertEqual(chunk.left, chunk.right)
        }
    }

    private func write(_ monitor: InputMonitor, _ samples: [Float]) {
        samples.withUnsafeBufferPointer { b in
            if let base = b.baseAddress { monitor.write(channel: 0, base, count: b.count) }
        }
    }

    private func read(_ monitor: InputMonitor, into out: inout [Float]) -> Int {
        out.withUnsafeMutableBufferPointer { b in
            guard let base = b.baseAddress else { return 0 }
            return monitor.read(channel: 0, into: base, frames: b.count)
        }
    }

    func testTheDelayNeverGrowsAndAMissingBlockIsSilence() {
        let monitor = InputMonitor()
        monitor.want([0])
        let burst = [Float](repeating: 1, count: 4_000)
        write(monitor, burst)
        var out = [Float](repeating: 9, count: 256)
        XCTAssertEqual(read(monitor, into: &out), 256)
        // What waits after a read is at most the slack: the input is never heard later than that.
        let waiting = (0..<20).reduce(0) { total, _ in
            total + read(monitor, into: &out)
        }
        XCTAssertLessThanOrEqual(waiting, InputMonitor.slack)
        out = [Float](repeating: 9, count: 256)
        XCTAssertEqual(read(monitor, into: &out), 0)
        XCTAssertTrue(out.allSatisfy { $0 == 0 }, "nothing arrived, so silence — not the last block again")
        monitor.want([])
        write(monitor, Array(burst[..<256]))
        XCTAssertEqual(read(monitor, into: &out), 0, "an input nobody plays is not kept")
    }
}
