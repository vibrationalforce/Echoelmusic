import EchoelCore
import XCTest
@testable import EchoelEngine

final class SynthKernelTests: XCTestCase {
    private func render(_ kernel: SynthKernel, frames: Int, gain: Float = 1) -> ([Float], [Float]) {
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

    private func peak(_ samples: [Float]) -> Float { samples.map(abs).max() ?? 0 }

    func testANoteSoundsOnBothChannelsAndAllNotesOffReleasesIt() {
        let kernel = SynthKernel(sampleRate: 48_000)
        XCTAssertEqual(peak(render(kernel, frames: 512).0), 0)
        kernel.receive(status: 0x90, 60, 100)
        let (left, right) = render(kernel, frames: 4_800)
        XCTAssertGreaterThan(peak(left), 0.01)
        XCTAssertEqual(left, right)
        kernel.receive(status: 0xB0, 123, 0)
        _ = render(kernel, frames: 48_000)
        XCTAssertEqual(peak(render(kernel, frames: 512).0), 0, "released and decayed")
    }

    func testParametersAreClampedAndChangeTheSound() {
        let kernel = SynthKernel(sampleRate: 48_000)
        let level = SynthKernel.parameters.firstIndex { $0.key == SynthParameter.level.key } ?? -1
        kernel.setParameter(level, 5)
        XCTAssertEqual(kernel.parameter(level), 1)
        kernel.setParameter(level, .nan)
        XCTAssertEqual(kernel.parameter(level), 1)
        kernel.receive(status: 0x90, 60, 127)
        let loud = peak(render(kernel, frames: 4_800).0)
        kernel.setParameter(level, 0)
        _ = render(kernel, frames: 4_800)            // the level glides down (5 ms)
        XCTAssertLessThan(peak(render(kernel, frames: 960).0), 1e-6)
        XCTAssertGreaterThan(loud, 0)
    }

    func testDemoGainScalesTheOutput() {
        let kernel = SynthKernel(sampleRate: 48_000)
        kernel.receive(status: 0x90, 60, 100)
        XCTAssertEqual(peak(render(kernel, frames: 2_048, gain: 0).0), 0)
    }
}
