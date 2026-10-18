import EchoelCore
import XCTest
@testable import EchoelEngine

final class DrumKernelTests: XCTestCase {
    private func render(_ kernel: DrumKernel, frames: Int, gain: Float = 1) -> ([Float], [Float]) {
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                kernel.render(frames: frames, left: lp, right: rp, gain: gain)
            }
        }
        return (left, right)
    }

    private func peak(_ samples: [Float]) -> Float { samples.map { abs($0) }.max() ?? 0 }

    func testAKickOnNote36SoundsOnBothChannelsAndAnUnmappedNoteDoesNot() {
        let kernel = DrumKernel(sampleRate: 48_000)
        kernel.receive(status: 0x90, 20, 100)
        XCTAssertEqual(peak(render(kernel, frames: 4_800).0), 0, "note 20 is no drum")
        kernel.receive(status: 0x99, 36, 120)
        let (left, right) = render(kernel, frames: 4_800)
        XCTAssertGreaterThan(peak(left), 0.05)
        XCTAssertEqual(left, right)
        kernel.receive(status: 0x89, 36, 0)
        XCTAssertGreaterThan(peak(render(kernel, frames: 480).0), 0, "a note-off does not cut a one-shot")
        kernel.receive(status: 0xB9, 120, 0)
        XCTAssertEqual(peak(render(kernel, frames: 480).0), 0, "all sound off silences it")
    }

    func testTheLevelIsClampedAndTheDemoGainSilences() {
        let kernel = DrumKernel(sampleRate: 48_000)
        XCTAssertEqual(DrumKernel.parameters.count, 1)
        kernel.setParameter(0, 3)
        XCTAssertEqual(kernel.parameter(0), 1)
        kernel.setParameter(0, .nan)
        XCTAssertEqual(kernel.parameter(0), 1)
        kernel.setParameter(0, 0)
        _ = render(kernel, frames: 4_800)              // the level glides down
        kernel.receive(status: 0x90, 38, 127)
        XCTAssertLessThan(peak(render(kernel, frames: 2_400).0), 1e-4)
        kernel.setParameter(0, 1)
        kernel.receive(status: 0x90, 38, 127)
        XCTAssertEqual(peak(render(kernel, frames: 2_400, gain: 0).0), 0)
    }
}
