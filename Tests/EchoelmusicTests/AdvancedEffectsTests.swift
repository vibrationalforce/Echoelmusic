#if canImport(AVFoundation)
// AdvancedEffectsTests.swift
// Echoelmusic — Phase 3 Test Coverage: Advanced DSP Effects
//
// Tests for AnalogConsole (ClassicAnalogEmulations),
// and SynthesisEngineType / SynthesisCategory.

import XCTest
@testable import Echoelmusic

// MARK: - AnalogConsole Tests

final class AnalogConsoleTests: XCTestCase {

    func testInit() {
        let console = AnalogConsole()
        XCTAssertEqual(console.character, 50.0)
        XCTAssertEqual(console.output, 50.0)
        XCTAssertEqual(console.mix, 100.0)
        XCTAssertFalse(console.bypassed)
    }

    func testAllHardwareStyles() {
        let styles = AnalogConsole.HardwareStyle.allCases
        XCTAssertEqual(styles.count, 8)
        XCTAssertTrue(styles.contains(.ssl))
        XCTAssertTrue(styles.contains(.api))
        XCTAssertTrue(styles.contains(.neve))
        XCTAssertTrue(styles.contains(.pultec))
        XCTAssertTrue(styles.contains(.fairchild))
        XCTAssertTrue(styles.contains(.la2a))
        XCTAssertTrue(styles.contains(.urei1176))
        XCTAssertTrue(styles.contains(.manley))
    }

    func testHardwareStyleProperties() {
        for style in AnalogConsole.HardwareStyle.allCases {
            XCTAssertFalse(style.fullName.isEmpty, "\(style) missing fullName")
            XCTAssertFalse(style.color.isEmpty, "\(style) missing color")
            // category is a Category enum, not String — just verify it's accessible
            _ = style.category
        }
    }

    func testProcessAllStyles() {
        let console = AnalogConsole()
        let input: [Float] = Array(repeating: 0.5, count: 256)

        for style in AnalogConsole.HardwareStyle.allCases {
            console.currentStyle = style
            let output = console.process(input)
            XCTAssertEqual(output.count, input.count, "\(style) changed output count")
            for sample in output {
                XCTAssertFalse(sample.isNaN, "NaN in \(style)")
                XCTAssertFalse(sample.isInfinite, "Inf in \(style)")
            }
        }
    }

    func testBypass() {
        let console = AnalogConsole()
        console.bypassed = true
        let input: [Float] = [0.1, 0.2, 0.3]
        let output = console.process(input)
        XCTAssertEqual(output, input)
    }

    func testGainReduction() {
        let console = AnalogConsole()
        console.currentStyle = .ssl
        console.character = 80.0
        let input: [Float] = Array(repeating: 0.9, count: 256)
        _ = console.process(input)
        let gr = console.getGainReduction()
        XCTAssertGreaterThanOrEqual(gr, 0)
    }

    func testStyleSwitching() {
        let console = AnalogConsole()
        console.currentStyle = .neve
        XCTAssertEqual(console.currentStyle, .neve)
        console.currentStyle = .ssl
        XCTAssertEqual(console.currentStyle, .ssl)
    }
}

// MARK: - SynthesisEngineType Tests

final class SynthesisEngineTypeTests: XCTestCase {

    func testAllCases() {
        let cases = SynthesisEngineType.allCases
        XCTAssertGreaterThan(cases.count, 15)
        XCTAssertTrue(cases.contains(.subtractive))
        XCTAssertTrue(cases.contains(.fm))
        XCTAssertTrue(cases.contains(.wavetable))
        XCTAssertTrue(cases.contains(.additive))
        XCTAssertTrue(cases.contains(.granular))
        XCTAssertTrue(cases.contains(.spectral))
        XCTAssertTrue(cases.contains(.physicalModeling))
        XCTAssertTrue(cases.contains(.sampler))
        XCTAssertTrue(cases.contains(.ddsp))
        XCTAssertTrue(cases.contains(.cellularAutomata))
        XCTAssertTrue(cases.contains(.modalBank))
        XCTAssertTrue(cases.contains(.bioReactive))
    }

    func testDisplayNames() {
        for type in SynthesisEngineType.allCases {
            XCTAssertFalse(type.displayName.isEmpty, "\(type) missing displayName")
        }
    }

    func testDescriptions() {
        for type in SynthesisEngineType.allCases {
            XCTAssertFalse(type.description.isEmpty, "\(type) missing description")
        }
    }

    func testCategories() {
        for type in SynthesisEngineType.allCases {
            let category = type.category
            XCTAssertNotNil(category)
        }
    }

    func testCodable() throws {
        let original = SynthesisEngineType.ddsp
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SynthesisEngineType.self, from: encoded)
        XCTAssertEqual(original, decoded)
    }

    func testSupportsRealTimeModulation() {
        // Bio-reactive and DDSP should support real-time modulation
        XCTAssertTrue(SynthesisEngineType.bioReactive.supportsRealTimeModulation)
        XCTAssertTrue(SynthesisEngineType.ddsp.supportsRealTimeModulation)
    }
}

// MARK: - SynthesisCategory Tests

final class SynthesisCategoryTests: XCTestCase {

    func testAllCases() {
        let cases = SynthesisCategory.allCases
        XCTAssertGreaterThan(cases.count, 5)
    }

    func testEnginesMapping() {
        for category in SynthesisCategory.allCases {
            let engines = category.engines
            // Each category should have at least one engine
            XCTAssertGreaterThan(engines.count, 0, "\(category) has no engines")
            // All engines should map back to this category
            for engine in engines {
                XCTAssertEqual(engine.category, category,
                               "\(engine) mapped to \(engine.category) but should be \(category)")
            }
        }
    }
}
#endif
