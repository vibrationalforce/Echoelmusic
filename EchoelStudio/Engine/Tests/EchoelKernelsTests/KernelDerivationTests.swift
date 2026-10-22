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

    func testTheSamplerAtTheTablesDefaultsPlaysExactlyTheDefaultSamplerPatch() throws {
        let tone: [Float] = (0..<4_800).map { (index: Int) -> Float in Float(index % 48) / 48 - 0.5 }
        let buffer = try XCTUnwrap(SampleBuffer(samples: tone, sampleRate: 48_000))
        let frames = 4_000

        let kernel = SamplerKernel(sampleRate: 48_000, maximumFrames: 4_096)
        kernel.load(buffer)
        var left = [Float](repeating: 0, count: 16), right = left
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                kernel.render(frames: 16, left: lp, right: rp, gain: 1)
            }
        }
        kernel.receive(status: 0x90, 64, 100)
        var played = [Float](repeating: 0, count: frames), other = played
        played.withUnsafeMutableBufferPointer { l in
            other.withUnsafeMutableBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                kernel.render(frames: frames, left: lp, right: rp, gain: 1)
            }
        }

        var sampler = Sampler(sampleRate: 48_000)
        sampler.setSample(buffer)
        sampler.setPatch(SamplerPatch())
        var lead = [Float](repeating: 0, count: 16)
        lead.withUnsafeMutableBufferPointer { sampler.render(into: $0) }
        sampler.noteOn(pitch: 64, velocity: 100)
        var expected = [Float](repeating: 0, count: frames)
        expected.withUnsafeMutableBufferPointer { sampler.render(into: $0) }

        let first = zip(played, expected).enumerated().first { $0.element.0 != $0.element.1 }?.offset
        XCTAssertNil(first, "first differing frame")
        XCTAssertGreaterThan(expected.map { abs($0) }.max() ?? 0, 0.1, "the reference plays")
    }
}
