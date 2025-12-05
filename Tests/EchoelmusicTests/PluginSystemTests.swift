import XCTest
import AVFoundation
@testable import Echoelmusic

/// Tests for the Plugin System (AU/VST3/AUv3)
final class PluginSystemTests: XCTestCase {

    var pluginHost: AUv3PluginHost!

    override func setUp() async throws {
        pluginHost = AUv3PluginHost.shared
    }

    // MARK: - Plugin Description Tests

    func testPluginDescriptionCreation() {
        let description = PluginDescription(
            identifier: "test.plugin.1",
            name: "Test Plugin",
            manufacturer: "Test Manufacturer",
            version: "1.0.0",
            type: .effect,
            format: .audioUnit,
            category: .dynamics,
            inputChannels: 2,
            outputChannels: 2
        )

        XCTAssertEqual(description.identifier, "test.plugin.1")
        XCTAssertEqual(description.name, "Test Plugin")
        XCTAssertEqual(description.type, .effect)
        XCTAssertEqual(description.format, .audioUnit)
    }

    func testPluginTypes() {
        let types: [PluginType] = [.effect, .instrument, .generator, .analyzer]

        for type in types {
            XCTAssertNotNil(type.rawValue)
        }
    }

    func testPluginFormats() {
        let formats: [PluginFormat] = [.audioUnit, .auv3, .vst3]

        for format in formats {
            XCTAssertNotNil(format.rawValue)
        }
    }

    func testPluginCategories() {
        let allCategories = PluginCategory.allCases
        XCTAssertGreaterThan(allCategories.count, 5)
        XCTAssertTrue(allCategories.contains(.equalizer))
        XCTAssertTrue(allCategories.contains(.dynamics))
        XCTAssertTrue(allCategories.contains(.reverb))
    }

    // MARK: - Plugin Browser Tests

    func testPluginFiltering() {
        let plugins = [
            PluginDescription(
                identifier: "1",
                name: "Test EQ",
                manufacturer: "Test",
                version: "1.0",
                type: .effect,
                format: .audioUnit,
                category: .equalizer,
                inputChannels: 2,
                outputChannels: 2
            ),
            PluginDescription(
                identifier: "2",
                name: "Test Synth",
                manufacturer: "Test",
                version: "1.0",
                type: .instrument,
                format: .vst3,
                category: .synthesizer,
                inputChannels: 0,
                outputChannels: 2
            )
        ]

        // Filter by type
        let effects = PluginBrowser.filter(plugins: plugins, type: .effect)
        XCTAssertEqual(effects.count, 1)
        XCTAssertEqual(effects.first?.name, "Test EQ")

        // Filter by format
        let vst3s = PluginBrowser.filter(plugins: plugins, format: .vst3)
        XCTAssertEqual(vst3s.count, 1)
        XCTAssertEqual(vst3s.first?.name, "Test Synth")

        // Filter by category
        let eqs = PluginBrowser.filter(plugins: plugins, category: .equalizer)
        XCTAssertEqual(eqs.count, 1)

        // Filter by search
        let synths = PluginBrowser.filter(plugins: plugins, search: "synth")
        XCTAssertEqual(synths.count, 1)
    }

    func testPluginGrouping() {
        let plugins = [
            PluginDescription(
                identifier: "1",
                name: "Plugin A",
                manufacturer: "Company A",
                version: "1.0",
                type: .effect,
                format: .audioUnit,
                category: .dynamics,
                inputChannels: 2,
                outputChannels: 2
            ),
            PluginDescription(
                identifier: "2",
                name: "Plugin B",
                manufacturer: "Company A",
                version: "1.0",
                type: .effect,
                format: .audioUnit,
                category: .reverb,
                inputChannels: 2,
                outputChannels: 2
            ),
            PluginDescription(
                identifier: "3",
                name: "Plugin C",
                manufacturer: "Company B",
                version: "1.0",
                type: .effect,
                format: .audioUnit,
                category: .dynamics,
                inputChannels: 2,
                outputChannels: 2
            )
        ]

        // Group by manufacturer
        let byManufacturer = PluginBrowser.groupByManufacturer(plugins)
        XCTAssertEqual(byManufacturer.count, 2)
        XCTAssertEqual(byManufacturer["Company A"]?.count, 2)
        XCTAssertEqual(byManufacturer["Company B"]?.count, 1)

        // Group by category
        let byCategory = PluginBrowser.groupByCategory(plugins)
        XCTAssertEqual(byCategory[.dynamics]?.count, 2)
        XCTAssertEqual(byCategory[.reverb]?.count, 1)
    }

    // MARK: - Plugin Parameter Tests

    func testPluginParameterCreation() {
        let param = PluginParameter(
            identifier: "freq",
            name: "Frequency",
            value: 1000,
            minValue: 20,
            maxValue: 20000,
            defaultValue: 1000,
            unit: "Hz"
        )

        XCTAssertEqual(param.name, "Frequency")
        XCTAssertEqual(param.value, 1000)
        XCTAssertEqual(param.minValue, 20)
        XCTAssertEqual(param.maxValue, 20000)
        XCTAssertEqual(param.unit, "Hz")
    }

    // MARK: - Plugin Preset Tests

    func testPresetEncoding() throws {
        let preset = PluginPreset(
            name: "Test Preset",
            pluginId: "test.plugin.1",
            parameters: [("freq", 1000), ("gain", 0.5)]
        )

        let encoded = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(PluginPreset.self, from: encoded)

        XCTAssertEqual(decoded.name, "Test Preset")
        XCTAssertEqual(decoded.pluginId, "test.plugin.1")
        XCTAssertEqual(decoded.parameters.count, 2)
    }

    // MARK: - Plugin Chain Tests

    func testPluginChainCreation() {
        let chain = PluginChain()
        XCTAssertTrue(chain.plugins.isEmpty)
    }

    func testPluginChainOrdering() async throws {
        let chain = PluginChain()

        // Note: Can't actually load plugins without AU components
        // This tests the chain structure
        chain.plugins = ["plugin1", "plugin2", "plugin3"]

        XCTAssertEqual(chain.plugins.count, 3)
        XCTAssertEqual(chain.plugins[0], "plugin1")
        XCTAssertEqual(chain.plugins[2], "plugin3")

        // Test move
        chain.move(from: 0, to: 2)
        XCTAssertEqual(chain.plugins[0], "plugin2")
    }

    // MARK: - Error Tests

    func testPluginErrors() {
        let errors: [PluginError] = [
            .pluginNotFound,
            .invalidIdentifier,
            .instantiationFailed,
            .pluginNotLoaded,
            .formatNotSupported,
            .platformNotSupported,
            .bufferCreationFailed,
            .renderFailed(0),
            .presetNotFound
        ]

        for error in errors {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Performance Tests

    func testPluginFilteringPerformance() {
        // Create many mock plugins
        var plugins: [PluginDescription] = []
        for i in 0..<1000 {
            plugins.append(PluginDescription(
                identifier: "plugin.\(i)",
                name: "Plugin \(i)",
                manufacturer: "Manufacturer \(i % 10)",
                version: "1.0",
                type: [.effect, .instrument, .generator, .analyzer][i % 4],
                format: [.audioUnit, .vst3, .auv3][i % 3],
                category: PluginCategory.allCases[i % PluginCategory.allCases.count],
                inputChannels: 2,
                outputChannels: 2
            ))
        }

        let options = XCTMeasureOptions()
        options.iterationCount = 100

        measure(options: options) {
            _ = PluginBrowser.filter(
                plugins: plugins,
                type: .effect,
                format: .audioUnit,
                category: .dynamics,
                search: "plugin"
            )
        }
    }
}

// MARK: - Mock Plugin Host Tests

final class MockPluginHostTests: XCTestCase {

    func testPluginScanningFlow() async throws {
        // This would test the scanning flow on platforms with AU support
        let host = AUv3PluginHost.shared

        // Start scan
        await host.scanPlugins()

        // Verify scan completed (may or may not find plugins depending on platform)
        XCTAssertFalse(host.isScanning)
    }
}
