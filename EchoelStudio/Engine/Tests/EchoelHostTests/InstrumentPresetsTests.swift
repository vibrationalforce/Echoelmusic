import AudioToolbox
import EchoelCore
import EchoelKernels
import XCTest
@testable import EchoelHost

/// A host's preset menu for the synth plugin, and what choosing an entry does.
final class InstrumentPresetsTests: XCTestCase {
    /// A tree over a synth kernel, wired as the plugin's unit wires it.
    private func tree(over kernel: SynthKernel) -> AUParameterTree {
        let nodes = SynthKernel.parameters.enumerated().map { index, parameter in
            AUParameterTree.createParameter(
                withIdentifier: parameter.identifier, name: parameter.title, address: AUParameterAddress(index),
                min: AUValue(parameter.range.lowerBound), max: AUValue(parameter.range.upperBound), unit: .generic,
                unitName: nil, flags: [.flag_IsReadable, .flag_IsWritable], valueStrings: nil, dependentParameters: nil)
        }
        let tree = AUParameterTree.createTree(withChildren: nodes)
        tree.implementorValueObserver = { parameter, value in kernel.setParameter(Int(parameter.address), value) }
        tree.implementorValueProvider = { parameter in kernel.parameter(Int(parameter.address)) }
        return tree
    }

    /// The menu names the presets in their order and numbers each by its place.
    func testTheMenuNumbersEachPresetByItsPlace() {
        let menu = InstrumentPresets.menu(SynthKernel.factoryPresets)
        XCTAssertEqual(menu.map(\.name), SynthKernel.factoryPresets.map(\.name))
        XCTAssertEqual(menu.map(\.number), Array(SynthKernel.factoryPresets.indices))
        XCTAssertTrue(InstrumentPresets.menu(DrumKernel.factoryPresets).isEmpty)
    }

    /// A number in the list is its factory preset; a user preset's (negative) and one past the
    /// list are none, so a session from a build with more presets changes nothing.
    func testOnlyANumberInTheListIsAFactoryPreset() {
        let presets = SynthKernel.factoryPresets
        XCTAssertEqual(InstrumentPresets.factory(1, in: presets), presets[1])
        XCTAssertNil(InstrumentPresets.factory(-1, in: presets))
        XCTAssertNil(InstrumentPresets.factory(presets.count, in: presets))
        XCTAssertNil(InstrumentPresets.factory(0, in: []))
    }

    /// Choosing a preset reaches the kernel through the tree, and the tree reads it back.
    func testChoosingAPresetSetsTheKernelThroughTheTree() throws {
        let kernel = SynthKernel(sampleRate: 48_000, maximumFrames: 256)
        let parameters = tree(over: kernel)
        for preset in SynthKernel.factoryPresets.reversed() {
            InstrumentPresets.apply(preset, to: parameters)
            for (address, value) in preset.values.enumerated() {
                XCTAssertEqual(kernel.parameter(address), value, "\(preset.name) address \(address)")
                let node = try XCTUnwrap(parameters.parameter(withAddress: AUParameterAddress(address)))
                XCTAssertEqual(node.value, value, "\(preset.name) address \(address)")
            }
        }
    }
}
