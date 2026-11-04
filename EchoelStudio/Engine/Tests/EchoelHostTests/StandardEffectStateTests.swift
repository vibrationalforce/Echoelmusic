import AVFoundation
import EchoelCore
import EchoelDSP
@testable import EchoelKernels
import XCTest
@testable import EchoelHost

/// A state Echoel writes without loading the unit (the master suggestion's) plays in the unit
/// exactly as the kernel plays those values — live and export both load the insert this way.
final class StandardEffectStateTests: XCTestCase {
    private func unit(_ effect: StandardEffect) throws -> StandardEffectUnit {
        try StandardEffectUnit(componentDescription: StandardEffectUnit.audioComponent(effect.component))
    }

    private func settings(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    private func render(_ unit: StandardEffectUnit, _ input: [Float]) -> [Float] {
        let effect = HostedEffect(render: unit.renderBlock, sampleRate: 48_000, maximumFrames: 4_096, owner: unit)
        var left = input, right = input
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let a = l.baseAddress, let b = r.baseAddress else { return }
                var done = 0
                while done < l.count {
                    let n = Swift.min(256, l.count - done)
                    effect.process(frames: n, left: a + done, right: b + done)
                    done += n
                }
            }
        }
        return left
    }

    private func render(_ kernel: EffectKernel, _ input: [Float]) -> [Float] {
        var left = input, right = input
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let a = l.baseAddress, let b = r.baseAddress else { return }
                var done = 0
                while done < l.count {
                    let n = Swift.min(256, l.count - done)
                    kernel.process(left: a + done, right: b + done, frames: n)
                    done += n
                }
            }
        }
        return left
    }

    func testAnIdentifierStatePlaysAsTheKernelPlaysItsValues() throws {
        let values: [String: Float] = ["gain": 9, "ceiling": -1, "release": 0.1]
        let data = try XCTUnwrap(StandardEffectSettings.state(values, for: .limiter))
        let u = try unit(.limiter)
        u.fullStateForDocument = try settings(data)
        try u.allocateRenderResources()
        let kernel = EffectKernel(effect: .limiter, sampleRate: 48_000)
        for setting in StandardEffectSettings.values(in: data, for: .limiter) {
            kernel.setParameter(setting.address, setting.value)
            XCTAssertEqual(u.parameterTree?.parameter(withAddress: AUParameterAddress(setting.address))?.value,
                           setting.value, "the tree shows what plays")
        }
        let input = (0..<9_600).map { (index: Int) -> Float in Float(sin(Double(index) * 0.05)) * 0.6 }
        XCTAssertEqual(render(u, input), render(kernel, input))
    }

    func testTheStateAUnitHandsOutCarriesItsValuesByIdentifier() throws {
        let u = try unit(.equalizer)
        try u.allocateRenderResources()
        u.parameterTree?.parameter(withAddress: 2)?.value = 3.5
        let state = try XCTUnwrap(u.fullStateForDocument)
        let values = StandardEffectSettings.values(in: state, for: .equalizer)
        XCTAssertEqual(values.first { $0.address == 2 }?.value, 3.5)
        let copy = try unit(.equalizer)
        copy.fullStateForDocument = state
        XCTAssertEqual(copy.parameterTree?.parameter(withAddress: 2)?.value, 3.5, "it opens as it was")
    }

    func testAStateWithoutIdentifiersStillOpens() throws {
        let u = try unit(.compressor)
        try u.allocateRenderResources()
        u.parameterTree?.parameter(withAddress: 0)?.value = -30
        var state = try XCTUnwrap(u.fullStateForDocument)
        state.removeValue(forKey: StandardEffectSettings.valuesKey)
        let copy = try unit(.compressor)
        copy.fullStateForDocument = state
        XCTAssertEqual(copy.parameterTree?.parameter(withAddress: 0)?.value ?? 0, -30, accuracy: 0.001,
                       "a state saved before the identifiers restores through the base")
    }
}
