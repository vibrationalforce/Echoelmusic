import EchoelCore
import XCTest
@testable import EchoelKernels

/// What a kernel says about a host's ramps is what it does with one.
final class KernelRampTests: XCTestCase {
    private let kernels: [any InstrumentKernel.Type] = [SynthKernel.self, DrumKernel.self, SamplerKernel.self]

    /// For every address of every instrument: a kernel that says it ramps moves only part of the
    /// way in the first 512 frames of a one-second ramp; one that says it does not is at the end
    /// value at once. A choice never ramps.
    func testAKernelRampsExactlyWhereItSaysItCan() {
        let left = UnsafeMutablePointer<Float>.allocate(capacity: 512)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: 512)
        defer {
            left.deallocate()
            right.deallocate()
        }
        for kernelType in kernels {
            for (address, parameter) in kernelType.parameters.enumerated() {
                let kernel = kernelType.init(sampleRate: 48_000, maximumFrames: 512)
                let start = Float(parameter.defaultValue)
                let upper = Float(parameter.range.upperBound)
                let goal = start == upper ? Float(parameter.range.lowerBound) : upper
                kernel.rampParameter(address, to: goal, frames: 48_000)
                kernel.render(frames: 512, left: left, right: right, gain: 1)
                let moved = kernel.parameter(address)
                let glides = moved != goal
                XCTAssertEqual(kernelType.canRamp(address), glides, "\(kernelType) \(parameter.identifier)")
                if glides {
                    XCTAssertTrue(Swift.min(start, goal) < moved && moved < Swift.max(start, goal),
                                  "\(kernelType) \(parameter.identifier) on its way")
                }
                if !parameter.choices.isEmpty {
                    XCTAssertFalse(kernelType.canRamp(address), "\(kernelType) \(parameter.identifier) is a choice")
                }
            }
        }
    }

    /// The synth glides its numbers; the drums and the sampler take every ramp's end at once, and
    /// an address past the list never ramps.
    func testOnlyTheSynthsNumbersRamp() {
        let cutoff = SynthKernel.parameters.firstIndex { $0.identifier == "synth_cutoff" } ?? -1
        XCTAssertTrue(SynthKernel.canRamp(cutoff))
        XCTAssertFalse(SynthKernel.canRamp(SynthKernel.parameters.count))
        XCTAssertFalse(SynthKernel.canRamp(-1))
        XCTAssertFalse(DrumKernel.parameters.indices.contains { DrumKernel.canRamp($0) })
        XCTAssertFalse(SamplerKernel.parameters.indices.contains { SamplerKernel.canRamp($0) })
    }
}
