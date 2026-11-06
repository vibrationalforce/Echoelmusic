import AudioToolbox
import EchoelCore
import EchoelKernels
import XCTest
@testable import EchoelHost

/// What an instrument plugin's tree tells a host.
final class InstrumentParameterTreeTests: XCTestCase {
    private let kernels: [any InstrumentKernel.Type] = [SynthKernel.self, DrumKernel.self, SamplerKernel.self]

    /// One node per parameter at its address and default; `.flag_CanRamp` exactly where the kernel
    /// glides a ramp, never on a choice, which reaches the host as an indexed list of its names.
    func testTheTreeFlagsARampOnlyWhereTheKernelGlidesOne() throws {
        for kernel in kernels {
            let tree = InstrumentParameterTree.make(for: kernel)
            XCTAssertEqual(tree.allParameters.count, kernel.parameters.count, "\(kernel)")
            for (address, parameter) in kernel.parameters.enumerated() {
                let node = try XCTUnwrap(tree.parameter(withAddress: AUParameterAddress(address)), "\(kernel) \(address)")
                XCTAssertEqual(node.identifier, parameter.identifier)
                XCTAssertEqual(node.value, AUValue(parameter.defaultValue), parameter.identifier)
                XCTAssertEqual(node.flags.contains(.flag_CanRamp), kernel.canRamp(address), parameter.identifier)
                XCTAssertTrue(node.flags.contains(.flag_IsWritable), parameter.identifier)
                if parameter.choices.isEmpty {
                    XCTAssertNil(node.valueStrings, parameter.identifier)
                } else {
                    XCTAssertEqual(node.unit, .indexed, parameter.identifier)
                    XCTAssertEqual(node.valueStrings, parameter.choices, parameter.identifier)
                    XCTAssertFalse(node.flags.contains(.flag_CanRamp), "\(parameter.identifier) is a choice")
                }
            }
        }
    }

    /// The synth's cutoff glides; nothing of the drums or the sampler does.
    func testTheSynthsCutoffRampsAndTheDrumsDoNot() throws {
        let synth = InstrumentParameterTree.make(for: SynthKernel.self)
        let cutoff = try XCTUnwrap(SynthKernel.parameters.firstIndex { $0.identifier == "synth_cutoff" })
        let node = try XCTUnwrap(synth.parameter(withAddress: AUParameterAddress(cutoff)))
        XCTAssertTrue(node.flags.contains(.flag_CanRamp))
        XCTAssertEqual(node.unit, .hertz)
        let drums = InstrumentParameterTree.make(for: DrumKernel.self)
        XCTAssertFalse(drums.allParameters.contains { $0.flags.contains(.flag_CanRamp) })
    }
}
