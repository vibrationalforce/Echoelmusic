// LEDControlTests.swift
// Echoelmusic - LED Control Test Suite
// Wise Mode Implementation

import XCTest
@testable import Echoelmusic

final class LEDControlTests: XCTestCase {

    // MARK: - Properties

    var ledService: LEDControlService!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        ledService = LEDControlService()
    }

    override func tearDown() {
        ledService = nil
        super.tearDown()
    }

    // MARK: - Connection Tests

    func testInitiallyDisconnected() {
        XCTAssertFalse(ledService.isConnected)
    }

    func testConnect() async throws {
        try await ledService.connect()
        XCTAssertTrue(ledService.isConnected)
    }

    func testDisconnect() async throws {
        try await ledService.connect()
        ledService.disconnect()
        XCTAssertFalse(ledService.isConnected)
    }

    // MARK: - Color Validation Tests

    func testDMXValueValidation() {
        // UInt8 is already 0-255, so all values are valid
        XCTAssertEqual(InputValidator.validateDMX(0), 0)
        XCTAssertEqual(InputValidator.validateDMX(127), 127)
        XCTAssertEqual(InputValidator.validateDMX(255), 255)
    }

    func testRGBColorCreation() {
        let color = RGBColor(r: 255, g: 128, b: 64)
        XCTAssertEqual(color.r, 255)
        XCTAssertEqual(color.g, 128)
        XCTAssertEqual(color.b, 64)
    }

    func testRGBColorPresets() {
        XCTAssertEqual(RGBColor.black, RGBColor(r: 0, g: 0, b: 0))
        XCTAssertEqual(RGBColor.white, RGBColor(r: 255, g: 255, b: 255))
        XCTAssertEqual(RGBColor.red, RGBColor(r: 255, g: 0, b: 0))
        XCTAssertEqual(RGBColor.green, RGBColor(r: 0, g: 255, b: 0))
        XCTAssertEqual(RGBColor.blue, RGBColor(r: 0, g: 0, b: 255))
    }

    // MARK: - LED Pattern Tests

    func testAllLEDPatterns() {
        for pattern in LEDPattern.allCases {
            ledService.setPattern(pattern)
            // Pattern should be accepted without error
        }
    }

    func testLEDPatternCount() {
        XCTAssertEqual(LEDPattern.allCases.count, 7, "Should have 7 LED patterns")
    }

    // MARK: - Color Setting Tests

    func testSetColor() {
        ledService.setColor(r: 255, g: 128, b: 64)
        // Color should be set without error
    }

    func testSetColorBoundary() {
        // Test minimum values
        ledService.setColor(r: 0, g: 0, b: 0)

        // Test maximum values
        ledService.setColor(r: 255, g: 255, b: 255)

        // Test mixed values
        ledService.setColor(r: 0, g: 128, b: 255)
    }

    // MARK: - Color Conversion Tests

    func testRGBToFloat() {
        let color = RGBColor(r: 255, g: 128, b: 0)

        let rFloat = Float(color.r) / 255.0
        let gFloat = Float(color.g) / 255.0
        let bFloat = Float(color.b) / 255.0

        XCTAssertEqual(rFloat, 1.0, accuracy: 0.001)
        XCTAssertEqual(gFloat, 0.502, accuracy: 0.001)
        XCTAssertEqual(bFloat, 0.0, accuracy: 0.001)
    }

    func testFloatToRGB() {
        let r: Float = 0.5
        let g: Float = 0.25
        let b: Float = 1.0

        let color = RGBColor(
            r: UInt8(r * 255),
            g: UInt8(g * 255),
            b: UInt8(b * 255)
        )

        XCTAssertEqual(color.r, 127)
        XCTAssertEqual(color.g, 63)
        XCTAssertEqual(color.b, 255)
    }

    // MARK: - HSV to RGB Conversion Tests

    func testHSVToRGBRed() {
        let rgb = hsvToRGB(h: 0, s: 1.0, v: 1.0)
        XCTAssertEqual(rgb.r, 255)
        XCTAssertEqual(rgb.g, 0)
        XCTAssertEqual(rgb.b, 0)
    }

    func testHSVToRGBGreen() {
        let rgb = hsvToRGB(h: 120, s: 1.0, v: 1.0)
        XCTAssertEqual(rgb.r, 0)
        XCTAssertEqual(rgb.g, 255)
        XCTAssertEqual(rgb.b, 0)
    }

    func testHSVToRGBBlue() {
        let rgb = hsvToRGB(h: 240, s: 1.0, v: 1.0)
        XCTAssertEqual(rgb.r, 0)
        XCTAssertEqual(rgb.g, 0)
        XCTAssertEqual(rgb.b, 255)
    }

    func testHSVToRGBWhite() {
        let rgb = hsvToRGB(h: 0, s: 0, v: 1.0)
        XCTAssertEqual(rgb.r, 255)
        XCTAssertEqual(rgb.g, 255)
        XCTAssertEqual(rgb.b, 255)
    }

    func testHSVToRGBBlack() {
        let rgb = hsvToRGB(h: 0, s: 1.0, v: 0)
        XCTAssertEqual(rgb.r, 0)
        XCTAssertEqual(rgb.g, 0)
        XCTAssertEqual(rgb.b, 0)
    }

    // MARK: - Helper Functions

    /// Convert HSV to RGB
    /// - Parameters:
    ///   - h: Hue (0-360)
    ///   - s: Saturation (0-1)
    ///   - v: Value (0-1)
    private func hsvToRGB(h: Float, s: Float, v: Float) -> RGBColor {
        let c = v * s
        let x = c * (1 - abs(fmod(h / 60.0, 2) - 1))
        let m = v - c

        var r: Float = 0
        var g: Float = 0
        var b: Float = 0

        if h < 60 {
            r = c; g = x; b = 0
        } else if h < 120 {
            r = x; g = c; b = 0
        } else if h < 180 {
            r = 0; g = c; b = x
        } else if h < 240 {
            r = 0; g = x; b = c
        } else if h < 300 {
            r = x; g = 0; b = c
        } else {
            r = c; g = 0; b = x
        }

        return RGBColor(
            r: UInt8((r + m) * 255),
            g: UInt8((g + m) * 255),
            b: UInt8((b + m) * 255)
        )
    }
}

// MARK: - DMX Protocol Tests

extension LEDControlTests {

    func testDMXChannelValidation() {
        // DMX channels are 1-512
        for channel in 1...512 {
            XCTAssertTrue(isValidDMXChannel(channel))
        }

        XCTAssertFalse(isValidDMXChannel(0))
        XCTAssertFalse(isValidDMXChannel(513))
    }

    func testDMXUniverseValidation() {
        // Standard Art-Net supports universes 0-32767
        for universe in 0...32767 {
            XCTAssertTrue(isValidDMXUniverse(universe))
        }

        XCTAssertFalse(isValidDMXUniverse(-1))
        XCTAssertFalse(isValidDMXUniverse(32768))
    }

    private func isValidDMXChannel(_ channel: Int) -> Bool {
        channel >= 1 && channel <= 512
    }

    private func isValidDMXUniverse(_ universe: Int) -> Bool {
        universe >= 0 && universe <= 32767
    }
}

// MARK: - Performance Tests

extension LEDControlTests {

    func testColorConversionPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = hsvToRGB(
                    h: Float.random(in: 0...360),
                    s: Float.random(in: 0...1),
                    v: Float.random(in: 0...1)
                )
            }
        }
    }
}
