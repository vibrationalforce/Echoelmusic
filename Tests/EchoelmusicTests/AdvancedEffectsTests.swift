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
#endif
