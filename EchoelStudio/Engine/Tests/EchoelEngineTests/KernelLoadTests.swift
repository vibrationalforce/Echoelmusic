import EchoelCore
import EchoelDSP
@testable import EchoelKernels
import Foundation
import XCTest

/// What a kernel costs on the render thread (AUD, 2026-11-01): sixteen held voices of a synth
/// engine, rendered in 512-frame blocks, as a share of the time those frames last. A share above
/// one is a render that cannot keep up — the device drops out and crackles.
///
/// Measured on 2026-11-01 in a release build (`swift test -c release -Xswiftc -enable-testing`,
/// one x86-64 core, Linux): classic 1.0 %, supersaw 5.7 %, FM 1.9 %, sub 1.4 %, morph 2.3 %,
/// mallet 5.7 %, the kit 0.7 %, the sampler 0.3 %, every effect under 1.5 % — and the DDSP engine
/// 3,455 % before its partial loop was written over plain floats, 28 % after: one DDSP voice took
/// 37 µs a sample, where a sample lasts 21 µs. A debug build is slower throughout and this test
/// runs in one in CI, so it compares the engines with each other rather than with the clock:
/// DDSP stood at 503 classic voices' cost there, and stood at 33. Since it stops at the partials
/// below Nyquist (2026-11-04, Linux): 29 → 27 classic voices' cost in a debug build for this
/// chord; in a release build 36 % → 31 % of real time for it, and 45 % → 6 % for sixteen notes
/// from key 90 up.
final class KernelLoadTests: XCTestCase {
    private let rate = 48_000.0

    /// The best of three runs of `seconds` of sixteen held voices on `engine`, in seconds.
    private func cost(of engine: SynthEngine, seconds: Double = 0.25, lowestKey: Int = 40, keyStep: Int = 3) -> Double {
        guard let index = SynthEngine.allCases.firstIndex(of: engine) else { return .infinity }
        var best = Double.infinity
        for _ in 0..<3 {
            let kernel = SynthKernel(sampleRate: rate, maximumFrames: 4_096)
            kernel.setParameter(10, Float(index))
            for key in 0..<16 { kernel.receive(status: 0x90, UInt8(Swift.min(127, lowestKey + key * keyStep)), 100) }
            let left = UnsafeMutablePointer<Float>.allocate(capacity: 512)
            let right = UnsafeMutablePointer<Float>.allocate(capacity: 512)
            defer {
                left.deallocate()
                right.deallocate()
            }
            kernel.render(frames: 512, left: left, right: right, gain: 1)
            let blocks = Int(seconds * rate) / 512
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<blocks { kernel.render(frames: 512, left: left, right: right, gain: 1) }
            best = Swift.min(best, Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9)
        }
        return best
    }

    func testADDSPVoiceCostsNoMoreThanAHundredClassicOnes() {
        let classic = cost(of: .classic)
        let ddsp = cost(of: .ddsp)
        XCTAssertGreaterThan(classic, 0)
        XCTAssertLessThan(ddsp / classic, 100, "DDSP at \(ddsp / classic) classic voices' cost")
    }

    /// A partial at or above Nyquist is silent, and the DDSP stops computing there: sixteen notes
    /// from key 90 up (1.5 … 8.4 kHz, 2 … 15 partials) cost a fraction of sixteen from key 40 (up
    /// to 64). Before, all sixty-four partials ran for every note and the high chord cost as much
    /// as the low one — more, measured: 45 % against 36 % of real time (release, 2026-11-04).
    func testTheDDSPComputesOnlyThePartialsBelowNyquist() {
        let low = cost(of: .ddsp)
        let high = cost(of: .ddsp, lowestKey: 90, keyStep: 2)
        XCTAssertLessThan(high, low * 0.5, "high \(high) s, low \(low) s")
    }
}
