import XCTest
@testable import Echoelmusic

/// Unit Tests for PresetSystem
/// Tests preset creation, persistence, import/export, and search functionality
@MainActor
final class PresetSystemTests: XCTestCase {

    var presetSystem: PresetSystem!

    override func setUp() async throws {
        presetSystem = PresetSystem.shared
        // Clear user presets for clean testing
        presetSystem.clearUserPresets()
    }

    override func tearDown() async throws {
        // Cleanup
        presetSystem.clearUserPresets()
    }

    // MARK: - Preset Creation Tests

    func testCreatePreset() throws {
        let parameters: [String: PresetSystem.ParameterValue] = [
            "volume": .float(0.8),
            "pan": .float(0.0),
            "enabled": .bool(true),
            "name": .string("Test")
        ]

        let preset = PresetSystem.Preset(
            name: "Test Preset",
            category: .effects,
            toolType: .process,
            parameters: parameters
        )

        XCTAssertEqual(preset.name, "Test Preset")
        XCTAssertEqual(preset.category, .effects)
        XCTAssertEqual(preset.toolType, .process)
        XCTAssertEqual(preset.parameters.count, 4)
    }

    func testSaveUserPreset() throws {
        let parameters: [String: PresetSystem.ParameterValue] = [
            "volume": .float(0.75),
            "reverb": .float(0.3)
        ]

        let preset = PresetSystem.Preset(
            name: "My Preset",
            category: .mixing,
            toolType: .process,
            parameters: parameters,
            isUserPreset: true
        )

        presetSystem.savePreset(preset)

        // Verify saved
        let userPresets = presetSystem.getUserPresets()
        XCTAssertTrue(userPresets.contains { $0.name == "My Preset" }, "Preset should be saved")
    }

    func testDeleteUserPreset() throws {
        // First save a preset
        let preset = PresetSystem.Preset(
            name: "To Delete",
            category: .synthesis,
            toolType: .synthesis,
            parameters: ["test": .float(1.0)],
            isUserPreset: true
        )

        presetSystem.savePreset(preset)

        // Get the ID
        guard let savedPreset = presetSystem.getUserPresets().first(where: { $0.name == "To Delete" }) else {
            XCTFail("Preset should exist")
            return
        }

        // Delete it
        presetSystem.deletePreset(id: savedPreset.id)

        // Verify deleted
        let remaining = presetSystem.getUserPresets().filter { $0.name == "To Delete" }
        XCTAssertTrue(remaining.isEmpty, "Preset should be deleted")
    }

    func testUpdatePreset() throws {
        // Save initial preset
        var preset = PresetSystem.Preset(
            name: "Initial",
            category: .effects,
            toolType: .process,
            parameters: ["volume": .float(0.5)],
            isUserPreset: true
        )

        presetSystem.savePreset(preset)

        // Update it
        preset.name = "Updated"
        preset.parameters["volume"] = .float(0.9)

        presetSystem.savePreset(preset)

        // Verify update
        guard let updated = presetSystem.getPreset(id: preset.id) else {
            XCTFail("Updated preset should exist")
            return
        }

        XCTAssertEqual(updated.name, "Updated")
        if case let .float(volume) = updated.parameters["volume"] {
            XCTAssertEqual(volume, 0.9, accuracy: 0.001)
        } else {
            XCTFail("Volume parameter should be float")
        }
    }

    // MARK: - Factory Presets Tests

    func testFactoryPresetsExist() throws {
        let factoryPresets = presetSystem.getFactoryPresets()

        XCTAssertFalse(factoryPresets.isEmpty, "Factory presets should exist")
        XCTAssertGreaterThanOrEqual(factoryPresets.count, 5, "Should have at least 5 factory presets")
    }

    func testFactoryPresetsAreReadOnly() throws {
        guard let factoryPreset = presetSystem.getFactoryPresets().first else {
            XCTFail("Should have factory presets")
            return
        }

        XCTAssertFalse(factoryPreset.isUserPreset, "Factory presets should not be user presets")
    }

    func testFactoryPresetCategories() throws {
        let factoryPresets = presetSystem.getFactoryPresets()

        // Check that we have presets in multiple categories
        let categories = Set(factoryPresets.map { $0.category })
        XCTAssertGreaterThan(categories.count, 1, "Should have presets in multiple categories")
    }

    // MARK: - Search and Filter Tests

    func testSearchPresetsByName() throws {
        // Save some test presets
        let preset1 = PresetSystem.Preset(name: "Warm Pad", category: .synthesis, toolType: .synthesis, parameters: [:], isUserPreset: true)
        let preset2 = PresetSystem.Preset(name: "Cold Strings", category: .synthesis, toolType: .synthesis, parameters: [:], isUserPreset: true)
        let preset3 = PresetSystem.Preset(name: "Warm Bass", category: .synthesis, toolType: .synthesis, parameters: [:], isUserPreset: true)

        presetSystem.savePreset(preset1)
        presetSystem.savePreset(preset2)
        presetSystem.savePreset(preset3)

        // Search for "Warm"
        let results = presetSystem.searchPresets(query: "Warm")

        XCTAssertEqual(results.count, 2, "Should find 2 presets with 'Warm'")
        XCTAssertTrue(results.allSatisfy { $0.name.contains("Warm") }, "All results should contain 'Warm'")
    }

    func testSearchPresetsCaseInsensitive() throws {
        let preset = PresetSystem.Preset(name: "UPPERCASE TEST", category: .effects, toolType: .process, parameters: [:], isUserPreset: true)
        presetSystem.savePreset(preset)

        let results = presetSystem.searchPresets(query: "uppercase")

        XCTAssertEqual(results.count, 1, "Search should be case-insensitive")
    }

    func testFilterPresetsByCategory() throws {
        // Save presets in different categories
        let synthPreset = PresetSystem.Preset(name: "Synth Test", category: .synthesis, toolType: .synthesis, parameters: [:], isUserPreset: true)
        let effectPreset = PresetSystem.Preset(name: "Effect Test", category: .effects, toolType: .process, parameters: [:], isUserPreset: true)
        let mixingPreset = PresetSystem.Preset(name: "Mix Test", category: .mixing, toolType: .process, parameters: [:], isUserPreset: true)

        presetSystem.savePreset(synthPreset)
        presetSystem.savePreset(effectPreset)
        presetSystem.savePreset(mixingPreset)

        // Filter by category
        let synthPresets = presetSystem.getPresets(forCategory: .synthesis)
        let userSynthPresets = synthPresets.filter { $0.isUserPreset && $0.name.contains("Test") }

        XCTAssertEqual(userSynthPresets.count, 1, "Should find 1 user synthesis preset")
        XCTAssertEqual(userSynthPresets.first?.name, "Synth Test")
    }

    func testFilterPresetsByToolType() throws {
        let synthPreset = PresetSystem.Preset(name: "Synth Tool", category: .synthesis, toolType: .synthesis, parameters: [:], isUserPreset: true)
        let processPreset = PresetSystem.Preset(name: "Process Tool", category: .effects, toolType: .process, parameters: [:], isUserPreset: true)

        presetSystem.savePreset(synthPreset)
        presetSystem.savePreset(processPreset)

        let synthTools = presetSystem.getPresets(forToolType: .synthesis)
        let userSynthTools = synthTools.filter { $0.isUserPreset && $0.name.contains("Tool") }

        XCTAssertEqual(userSynthTools.count, 1)
        XCTAssertEqual(userSynthTools.first?.name, "Synth Tool")
    }

    // MARK: - JSON Export/Import Tests

    func testExportPresetToJSON() throws {
        let preset = PresetSystem.Preset(
            name: "Export Test",
            category: .mastering,
            toolType: .process,
            parameters: [
                "limiterCeiling": .float(-0.3),
                "lufs": .float(-14.0),
                "stereoWidth": .float(1.0),
                "enabled": .bool(true),
                "format": .string("wav")
            ],
            isUserPreset: true
        )

        let jsonData = try presetSystem.exportPresetToJSON(preset)

        XCTAssertFalse(jsonData.isEmpty, "JSON data should not be empty")

        // Verify it's valid JSON
        let json = try JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(json)
    }

    func testImportPresetFromJSON() throws {
        // Create a preset and export it
        let original = PresetSystem.Preset(
            name: "Import Test",
            category: .effects,
            toolType: .process,
            parameters: [
                "delay": .float(250.0),
                "feedback": .float(0.4),
                "mix": .float(0.3)
            ],
            isUserPreset: true
        )

        let jsonData = try presetSystem.exportPresetToJSON(original)

        // Import it back
        let imported = try presetSystem.importPresetFromJSON(jsonData)

        XCTAssertEqual(imported.name, original.name)
        XCTAssertEqual(imported.category, original.category)
        XCTAssertEqual(imported.parameters.count, original.parameters.count)

        // Check parameter values
        if case let .float(delay) = imported.parameters["delay"] {
            XCTAssertEqual(delay, 250.0, accuracy: 0.001)
        } else {
            XCTFail("Delay parameter should be float")
        }
    }

    func testImportInvalidJSON() throws {
        let invalidJSON = "{ invalid json }".data(using: .utf8)!

        XCTAssertThrowsError(try presetSystem.importPresetFromJSON(invalidJSON)) { error in
            // Should throw an error for invalid JSON
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Favorites Tests

    func testAddToFavorites() throws {
        let preset = PresetSystem.Preset(
            name: "Favorite Test",
            category: .synthesis,
            toolType: .synthesis,
            parameters: [:],
            isUserPreset: true
        )

        presetSystem.savePreset(preset)
        presetSystem.addToFavorites(preset.id)

        let favorites = presetSystem.getFavorites()
        XCTAssertTrue(favorites.contains { $0.id == preset.id }, "Preset should be in favorites")
    }

    func testRemoveFromFavorites() throws {
        let preset = PresetSystem.Preset(
            name: "Remove Favorite",
            category: .effects,
            toolType: .process,
            parameters: [:],
            isUserPreset: true
        )

        presetSystem.savePreset(preset)
        presetSystem.addToFavorites(preset.id)
        presetSystem.removeFromFavorites(preset.id)

        let favorites = presetSystem.getFavorites()
        XCTAssertFalse(favorites.contains { $0.id == preset.id }, "Preset should not be in favorites")
    }

    func testToggleFavorite() throws {
        let preset = PresetSystem.Preset(
            name: "Toggle Favorite",
            category: .mixing,
            toolType: .process,
            parameters: [:],
            isUserPreset: true
        )

        presetSystem.savePreset(preset)

        // Toggle on
        presetSystem.toggleFavorite(preset.id)
        XCTAssertTrue(presetSystem.isFavorite(preset.id), "Should be favorite after toggle")

        // Toggle off
        presetSystem.toggleFavorite(preset.id)
        XCTAssertFalse(presetSystem.isFavorite(preset.id), "Should not be favorite after second toggle")
    }

    // MARK: - Recents Tests

    func testMarkAsRecentlyUsed() throws {
        let preset = PresetSystem.Preset(
            name: "Recent Test",
            category: .synthesis,
            toolType: .synthesis,
            parameters: [:],
            isUserPreset: true
        )

        presetSystem.savePreset(preset)
        presetSystem.markAsRecentlyUsed(preset.id)

        let recents = presetSystem.getRecentPresets()
        XCTAssertTrue(recents.contains { $0.id == preset.id }, "Preset should be in recents")
    }

    func testRecentsOrderedByTime() throws {
        let preset1 = PresetSystem.Preset(name: "Recent 1", category: .effects, toolType: .process, parameters: [:], isUserPreset: true)
        let preset2 = PresetSystem.Preset(name: "Recent 2", category: .effects, toolType: .process, parameters: [:], isUserPreset: true)
        let preset3 = PresetSystem.Preset(name: "Recent 3", category: .effects, toolType: .process, parameters: [:], isUserPreset: true)

        presetSystem.savePreset(preset1)
        presetSystem.savePreset(preset2)
        presetSystem.savePreset(preset3)

        presetSystem.markAsRecentlyUsed(preset1.id)
        presetSystem.markAsRecentlyUsed(preset2.id)
        presetSystem.markAsRecentlyUsed(preset3.id)
        presetSystem.markAsRecentlyUsed(preset1.id)  // Use preset1 again

        let recents = presetSystem.getRecentPresets()
        XCTAssertEqual(recents.first?.id, preset1.id, "Most recently used should be first")
    }

    func testRecentslimit() throws {
        // Create more than the limit of recent presets
        for i in 0..<25 {
            let preset = PresetSystem.Preset(
                name: "Recent \(i)",
                category: .effects,
                toolType: .process,
                parameters: [:],
                isUserPreset: true
            )
            presetSystem.savePreset(preset)
            presetSystem.markAsRecentlyUsed(preset.id)
        }

        let recents = presetSystem.getRecentPresets()
        XCTAssertLessThanOrEqual(recents.count, 20, "Recents should be limited")
    }

    // MARK: - Tags Tests

    func testAddTagToPreset() throws {
        var preset = PresetSystem.Preset(
            name: "Tagged Preset",
            category: .synthesis,
            toolType: .synthesis,
            parameters: [:],
            isUserPreset: true
        )

        preset.tags = ["ambient", "pad", "lush"]
        presetSystem.savePreset(preset)

        guard let saved = presetSystem.getPreset(id: preset.id) else {
            XCTFail("Preset should exist")
            return
        }

        XCTAssertEqual(saved.tags.count, 3)
        XCTAssertTrue(saved.tags.contains("ambient"))
        XCTAssertTrue(saved.tags.contains("pad"))
        XCTAssertTrue(saved.tags.contains("lush"))
    }

    func testSearchByTag() throws {
        var preset1 = PresetSystem.Preset(name: "Bass 1", category: .synthesis, toolType: .synthesis, parameters: [:], isUserPreset: true)
        preset1.tags = ["bass", "deep"]

        var preset2 = PresetSystem.Preset(name: "Pad 1", category: .synthesis, toolType: .synthesis, parameters: [:], isUserPreset: true)
        preset2.tags = ["pad", "ambient"]

        var preset3 = PresetSystem.Preset(name: "Bass 2", category: .synthesis, toolType: .synthesis, parameters: [:], isUserPreset: true)
        preset3.tags = ["bass", "punchy"]

        presetSystem.savePreset(preset1)
        presetSystem.savePreset(preset2)
        presetSystem.savePreset(preset3)

        let bassPresets = presetSystem.getPresets(withTag: "bass")
        XCTAssertEqual(bassPresets.count, 2, "Should find 2 presets with 'bass' tag")
    }

    // MARK: - Parameter Value Tests

    func testParameterValueFloat() throws {
        let value = PresetSystem.ParameterValue.float(0.75)

        if case let .float(f) = value {
            XCTAssertEqual(f, 0.75, accuracy: 0.001)
        } else {
            XCTFail("Should be float")
        }
    }

    func testParameterValueInt() throws {
        let value = PresetSystem.ParameterValue.int(42)

        if case let .int(i) = value {
            XCTAssertEqual(i, 42)
        } else {
            XCTFail("Should be int")
        }
    }

    func testParameterValueBool() throws {
        let value = PresetSystem.ParameterValue.bool(true)

        if case let .bool(b) = value {
            XCTAssertTrue(b)
        } else {
            XCTFail("Should be bool")
        }
    }

    func testParameterValueString() throws {
        let value = PresetSystem.ParameterValue.string("test")

        if case let .string(s) = value {
            XCTAssertEqual(s, "test")
        } else {
            XCTFail("Should be string")
        }
    }

    func testParameterValueArray() throws {
        let value = PresetSystem.ParameterValue.array([.float(1.0), .float(2.0), .float(3.0)])

        if case let .array(arr) = value {
            XCTAssertEqual(arr.count, 3)
        } else {
            XCTFail("Should be array")
        }
    }

    // MARK: - Duplicate Tests

    func testDuplicatePreset() throws {
        let original = PresetSystem.Preset(
            name: "Original",
            category: .effects,
            toolType: .process,
            parameters: ["volume": .float(0.8)],
            isUserPreset: true
        )

        presetSystem.savePreset(original)

        let duplicate = presetSystem.duplicatePreset(original)

        XCTAssertNotEqual(duplicate.id, original.id, "Duplicate should have new ID")
        XCTAssertTrue(duplicate.name.contains("Copy"), "Duplicate name should indicate it's a copy")
        XCTAssertEqual(duplicate.parameters["volume"], original.parameters["volume"], "Parameters should match")
    }

    // MARK: - Performance Tests

    func testPresetSavePerformance() throws {
        measure {
            for i in 0..<100 {
                let preset = PresetSystem.Preset(
                    name: "Perf Test \(i)",
                    category: .effects,
                    toolType: .process,
                    parameters: ["value": .float(Float(i))],
                    isUserPreset: true
                )
                presetSystem.savePreset(preset)
            }
        }
    }

    func testPresetSearchPerformance() throws {
        // Save many presets first
        for i in 0..<100 {
            let preset = PresetSystem.Preset(
                name: "Search Test \(i)",
                category: .effects,
                toolType: .process,
                parameters: [:],
                isUserPreset: true
            )
            presetSystem.savePreset(preset)
        }

        measure {
            for _ in 0..<100 {
                _ = presetSystem.searchPresets(query: "Test")
            }
        }
    }
}

// MARK: - Persistence Tests

@MainActor
final class PresetSystemPersistenceTests: XCTestCase {

    func testPresetPersistsAcrossInstances() throws {
        // Note: This test may need adjustment based on actual persistence implementation
        let presetSystem1 = PresetSystem.shared

        let preset = PresetSystem.Preset(
            name: "Persistence Test",
            category: .synthesis,
            toolType: .synthesis,
            parameters: ["test": .float(1.0)],
            isUserPreset: true
        )

        presetSystem1.savePreset(preset)

        // In a real scenario, this would test persistence across app launches
        // For now, we just verify the preset is saved
        let found = presetSystem1.getUserPresets().contains { $0.name == "Persistence Test" }
        XCTAssertTrue(found, "Preset should persist")

        // Cleanup
        presetSystem1.clearUserPresets()
    }
}
