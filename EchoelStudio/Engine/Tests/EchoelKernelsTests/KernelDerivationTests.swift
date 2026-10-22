import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelKernels

/// Every built-in kernel publishes its device's Core table, mapped through one rule, and starts at
/// the table's defaults. The literal values a host stores are pinned separately
/// (`KernelParameterContractTests`); this pins where they come from.
final class KernelDerivationTests: XCTestCase {
    private func assertDerived(_ published: [InstrumentKernelParameter], from device: InstrumentDevice,
                               file: StaticString = #filePath, line: UInt = #line) {
        let table = device.parameters
        XCTAssertEqual(published.count, table.count, "\(device)", file: file, line: line)
        for (kernel, row) in zip(published, table) {
            XCTAssertEqual(kernel.identifier, row.key.rawValue.replacingOccurrences(of: ".", with: "_"), file: file, line: line)
            XCTAssertEqual(kernel.title, row.title, file: file, line: line)
            XCTAssertEqual(kernel.unit, row.unit, file: file, line: line)
            XCTAssertEqual(kernel.range, row.range, file: file, line: line)
            XCTAssertEqual(kernel.defaultValue, row.defaultValue, file: file, line: line)
            XCTAssertEqual(kernel.choices, row.choices, file: file, line: line)
        }
    }

    func testEachKernelPublishesItsDevicesTable() {
        assertDerived(SynthKernel.parameters, from: .synth)
        assertDerived(DrumKernel.parameters, from: .drums)
        assertDerived(SamplerKernel.parameters, from: .sampler)
    }

    func testEachKernelStartsAtTheTablesDefaults() {
        let kernels: [any InstrumentKernel] = [SynthKernel(sampleRate: 48_000, maximumFrames: 512),
                                               DrumKernel(sampleRate: 48_000, maximumFrames: 512),
                                               SamplerKernel(sampleRate: 48_000, maximumFrames: 512)]
        for kernel in kernels {
            let parameters = type(of: kernel).parameters
            for (address, parameter) in parameters.enumerated() {
                XCTAssertEqual(kernel.parameter(address), Float(parameter.defaultValue), parameter.identifier)
            }
        }
    }

    /// The kernel at its table's defaults against a bare `Sampler`, which plays `SamplerPatch()`:
    /// the note is held, then let go long before the sample ends, so the attack, the level, the
    /// root key, the release and the mode (a one-shot would ignore the note-off) are all heard.
    /// Decay and sustain come from `SamplerPatch()` itself, not from the table.
    func testTheSamplerAtTheTablesDefaultsPlaysExactlyTheDefaultSamplerPatch() throws {
        let tone: [Float] = (0..<48_000).map { (index: Int) -> Float in Float(index % 48) / 48 - 0.5 }
        let buffer = try XCTUnwrap(SampleBuffer(samples: tone, sampleRate: 48_000))
        let held = 2_000, released = 12_000

        let kernel = SamplerKernel(sampleRate: 48_000, maximumFrames: 4_096)
        kernel.load(buffer)
        func render(_ frames: Int) -> [Float] {
            var left = [Float](repeating: 0, count: frames), right = left
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    kernel.render(frames: frames, left: lp, right: rp, gain: 1)
                }
            }
            return left
        }
        _ = render(16)
        kernel.receive(status: 0x90, 64, 100)
        var played = render(held)
        kernel.receive(status: 0x80, 64, 0)
        played += render(released)

        var sampler = Sampler(sampleRate: 48_000)
        sampler.setSample(buffer)
        var lead = [Float](repeating: 0, count: 16)
        lead.withUnsafeMutableBufferPointer { sampler.render(into: $0) }
        sampler.noteOn(pitch: 64, velocity: 100)
        var expected = [Float](repeating: 0, count: held + released)
        expected.withUnsafeMutableBufferPointer { all in
            sampler.render(into: UnsafeMutableBufferPointer(rebasing: all[0..<held]))
            sampler.noteOff(pitch: 64)
            sampler.render(into: UnsafeMutableBufferPointer(rebasing: all[held...]))
        }

        let first = zip(played, expected).enumerated().first { $0.element.0 != $0.element.1 }?.offset
        XCTAssertNil(first, "first differing frame")
        XCTAssertGreaterThan(expected.map { abs($0) }.max() ?? 0, 0.1, "the reference plays")
        XCTAssertEqual(expected.suffix(1_000).map { abs($0) }.max() ?? 1, 0,
                       "the release ends inside the render, well before the sample does")
    }
}
