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

    /// The best of three runs of `seconds` of a stereo tone through `effect` at its defaults, in seconds.
    private func cost(of effect: StandardEffect, seconds: Double = 0.25) -> Double {
        var best = Double.infinity
        for _ in 0..<3 {
            let kernel = EffectKernel(effect: effect, sampleRate: rate)
            let left = UnsafeMutablePointer<Float>.allocate(capacity: 512)
            let right = UnsafeMutablePointer<Float>.allocate(capacity: 512)
            defer {
                left.deallocate()
                right.deallocate()
            }
            func fill() {
                for i in 0..<512 {
                    let x = Float(sin(Double(i) * 0.0288)) * 0.4
                    left[i] = x
                    right[i] = x * 0.8
                }
            }
            let blocks = Int(seconds * rate) / 512
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<blocks {
                fill()
                kernel.process(left: left, right: right, frames: 512)
            }
            best = Swift.min(best, Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9)
        }
        return best
    }

    /// The four effects of ECHOELTOOLS B9/B10 (formant filter, transient designer, mid/side,
    /// multiband) each cost at most a few compressors: the multiband is three of them plus fourteen
    /// filter stages, the others are lighter. Measured 2026-11-04 (Linux, one x86-64 core), in
    /// compressors' cost — debug: formant 3.1, transient 2.4, mid/side 1.4, multiband 8.4;
    /// release: 1.3, 1.1, 0.8, 4.9. Compared with the compressor, not the clock, because CI runs a
    /// debug build; the bound leaves twice the multiband's debug cost for a slower runner.
    func testTheNewEffectsCostNoMoreThanAFewCompressors() {
        let compressor = cost(of: .compressor)
        XCTAssertGreaterThan(compressor, 0)
        for effect in [StandardEffect.formantFilter, .transientDesigner, .midSide, .multibandCompressor, .dynamicEQ] {
            let share = cost(of: effect) / compressor
            XCTAssertLessThan(share, 16, "\(effect.rawValue) at \(share) compressors' cost")
        }
    }

    /// The multiband clipper clips at four times the rate: per side, three bands raised and the sum
    /// brought down through 99- and 23-tap halfband stages, nine filter stages and a 32-sample
    /// look-ahead — more than the bound above allows for. Its bound is an estimate, UNMEASURED
    /// (written without a toolchain): roughly four times the multiband compressor's work per
    /// sample. The share is in the message; tighten the bound from the first CI run.
    func testTheMultibandClipperCostsNoMoreThanAFewDozenCompressors() {
        let compressor = cost(of: .compressor)
        XCTAssertGreaterThan(compressor, 0)
        let share = cost(of: .multibandClipper) / compressor
        XCTAssertLessThan(share, 64, "multibandClipper at \(share) compressors' cost")
    }
}
