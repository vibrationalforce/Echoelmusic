import EchoelCore
import XCTest
@testable import EchoelKernels

/// What a host's preset menu offers for each instrument plugin: the app's presets, by address.
final class FactoryPresetTests: XCTestCase {
    /// The synth plugin lists the app's presets under their names, in the app's order — the
    /// number a host stores for a preset is its place.
    func testTheSynthOffersTheAppsPresetsInTheirOrder() {
        XCTAssertEqual(SynthKernel.factoryPresets.map(\.name), InstrumentPreset.all.map(\.name))
        XCTAssertFalse(SynthKernel.factoryPresets.isEmpty)
    }

    /// Every key a preset names is one of the plugin's addresses, every preset has a value for
    /// every address, and each value is one the parameter takes (a whole step for a choice).
    func testEveryPresetKeyIsAnAddressAndEveryValueIsInRange() {
        let rows = InstrumentDevice.synth.parameters
        let keys = rows.map(\.key.rawValue)
        for (preset, offered) in zip(InstrumentPreset.all, SynthKernel.factoryPresets) {
            XCTAssertEqual(offered.values.count, SynthKernel.parameters.count, preset.name)
            for (key, value) in preset.values {
                guard let address = keys.firstIndex(of: key) else {
                    XCTFail("\(preset.name): \(key) is no address of the plugin")
                    continue
                }
                XCTAssertEqual(offered.values[address], Float(value), "\(preset.name) \(key)")
            }
            for (address, row) in rows.enumerated() {
                let value = Double(offered.values[address])
                XCTAssertTrue(value.isFinite && row.range.contains(value), "\(preset.name) \(row.key.rawValue)")
                if row.taper == .stepped {
                    XCTAssertEqual(value, value.rounded(), "\(preset.name) \(row.key.rawValue) is a whole step")
                }
            }
        }
    }

    /// A row the preset does not name plays what the same preset plays in a song: loading it in
    /// the app replaces every synth value, so the row is at its song default there too.
    func testARowThePresetDoesNotNameIsAtItsSongDefault() throws {
        let rows = InstrumentDevice.synth.parameters
        let initial = try XCTUnwrap(SynthKernel.factoryPresets.first)
        XCTAssertEqual(initial.name, InstrumentPreset.initial.name)
        XCTAssertEqual(initial.values, rows.map { Float($0.songDefault) })
        let pluck = try XCTUnwrap(SynthKernel.factoryPresets.first { $0.name == "Pluck" })
        let engine = try XCTUnwrap(rows.firstIndex { $0.key == SynthParameter.engine.key })
        XCTAssertEqual(pluck.values[engine], Float(SynthParameter.engine.songDefault), "Pluck names no engine")
    }

    /// A kernel given a preset's values plays them as they are: none is clamped on the way.
    func testAKernelGivenAPresetHoldsEveryValue() {
        for preset in SynthKernel.factoryPresets {
            let kernel = SynthKernel(sampleRate: 48_000, maximumFrames: 256)
            for (address, value) in preset.values.enumerated() { kernel.setParameter(address, value) }
            for (address, value) in preset.values.enumerated() {
                XCTAssertEqual(kernel.parameter(address), value, "\(preset.name) address \(address)")
            }
        }
    }

    /// The drums and the sampler have no presets in the app, so a host lists none for them.
    func testTheDrumsAndTheSamplerOfferNone() {
        XCTAssertTrue(DrumKernel.factoryPresets.isEmpty)
        XCTAssertTrue(SamplerKernel.factoryPresets.isEmpty)
        XCTAssertTrue(InstrumentKernelPreset.factory(for: .drums).isEmpty)
        XCTAssertTrue(InstrumentKernelPreset.factory(for: .sampler).isEmpty)
    }
}
