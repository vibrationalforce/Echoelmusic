import AudioToolbox
import EchoelCore
import EchoelKernels
import XCTest
@testable import EchoelHost

/// A host's preset menu for the synth plugin, and what choosing an entry does.
final class InstrumentPresetsTests: XCTestCase {
    /// The plugin's tree over a synth kernel, wired as the plugin's unit wires it.
    private func tree(over kernel: SynthKernel) -> AUParameterTree {
        let tree = InstrumentParameterTree.make(for: SynthKernel.self)
        tree.implementorValueObserver = { parameter, value in kernel.setParameter(Int(parameter.address), value) }
        tree.implementorValueProvider = { parameter in kernel.parameter(Int(parameter.address)) }
        return tree
    }

    /// The menu names the presets in their order and numbers each by its place.
    func testTheMenuNumbersEachPresetByItsPlace() {
        let menu = InstrumentPresets.menu(SynthKernel.factoryPresets)
        XCTAssertEqual(menu.map(\.name), SynthKernel.factoryPresets.map(\.name))
        XCTAssertEqual(menu.map(\.number), Array(SynthKernel.factoryPresets.indices))
        XCTAssertEqual(InstrumentPresets.menu(DrumKernel.factoryPresets).map(\.name), DrumKernel.factoryPresets.map(\.name))
        XCTAssertEqual(InstrumentPresets.menu(SamplerKernel.factoryPresets).map(\.name), SamplerKernel.factoryPresets.map(\.name))
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

    /// A sampler shape sets the envelope and leaves the root key the musician tuned to the sample.
    func testASamplerShapeLeavesTheRootKey() throws {
        let kernel = SamplerKernel(sampleRate: 48_000, maximumFrames: 256)
        let parameters = InstrumentParameterTree.make(for: SamplerKernel.self)
        parameters.implementorValueObserver = { parameter, value in kernel.setParameter(Int(parameter.address), value) }
        parameters.implementorValueProvider = { parameter in kernel.parameter(Int(parameter.address)) }
        let rows = InstrumentDevice.sampler.parameters
        let root = try XCTUnwrap(rows.firstIndex { $0.key == SynthParameter.samplerRoot.key })
        let rootNode = try XCTUnwrap(parameters.parameter(withAddress: AUParameterAddress(root)))
        rootNode.value = 57
        let swell = try XCTUnwrap(SamplerKernel.factoryPresets.first { $0.name == "Swell" })
        InstrumentPresets.apply(swell, to: parameters)
        XCTAssertEqual(kernel.parameter(root), 57, "the root key stays the sample's")
        for (address, value) in swell.values.enumerated() where address != root {
            XCTAssertEqual(kernel.parameter(address), value, "Swell address \(address)")
        }
    }

    private struct Unreadable: Error {}

    private func menuItem(_ number: Int, _ name: String) -> AUAudioUnitPreset {
        let item = AUAudioUnitPreset()
        item.number = number
        item.name = name
        return item
    }

    /// A user preset (negative number) is the unit's saved state, read back; the factory list is
    /// not consulted. One that cannot be read is not chosen.
    func testAUserPresetRestoresItsSavedStateAndAnUnreadableOneIsNotChosen() {
        let kernel = SynthKernel(sampleRate: 48_000, maximumFrames: 256)
        let parameters = tree(over: kernel)
        var restored: [Int] = []
        let mine = menuItem(-3, "Mine")
        let chosen = InstrumentPresets.choose(mine, from: SynthKernel.factoryPresets, tree: parameters) { item in
            restored.append(item.number)
        }
        XCTAssertTrue(chosen)
        XCTAssertEqual(restored, [-3])
        let unreadable = InstrumentPresets.choose(mine, from: SynthKernel.factoryPresets, tree: parameters) { _ in
            throw Unreadable()
        }
        XCTAssertFalse(unreadable)
    }

    /// A factory preset is set through the tree without touching the user branch; a number past
    /// the list leaves every value where it was.
    func testAFactoryPresetIsSetAndANumberPastTheListChangesNothing() throws {
        let kernel = SynthKernel(sampleRate: 48_000, maximumFrames: 256)
        let parameters = tree(over: kernel)
        let presets = SynthKernel.factoryPresets
        let pluck = try XCTUnwrap(presets.firstIndex { $0.name == "Pluck" })
        var restored = 0
        let chosen = InstrumentPresets.choose(menuItem(pluck, "Pluck"), from: presets, tree: parameters) { _ in
            restored += 1
        }
        XCTAssertTrue(chosen)
        XCTAssertEqual(restored, 0)
        for (address, value) in presets[pluck].values.enumerated() {
            XCTAssertEqual(kernel.parameter(address), value, "address \(address)")
        }
        let later = InstrumentPresets.choose(menuItem(presets.count, "Later"), from: presets, tree: parameters) { _ in
            restored += 1
        }
        XCTAssertFalse(later)
        XCTAssertEqual(restored, 0)
        for (address, value) in presets[pluck].values.enumerated() {
            XCTAssertEqual(kernel.parameter(address), value, "still Pluck, address \(address)")
        }
    }
}
