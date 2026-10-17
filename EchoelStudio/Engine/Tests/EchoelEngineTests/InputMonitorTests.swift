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
