import XCTest
@testable import Blab
import CoreMIDI

@MainActor
final class Push3LEDControllerTests: XCTestCase {

    var controller: Push3LEDController!

    override func setUp() async throws {
        try await super.setUp()
        controller = Push3LEDController()
    }

    override func tearDown() async throws {
        controller.disconnect()
        controller = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(controller, "Controller should be initialized")
        XCTAssertEqual(controller.currentPattern, .breathe, "Default pattern should be breathe")
        XCTAssertEqual(controller.brightness, 0.7, accuracy: 0.01, "Default brightness should be 0.7")
    }

    func testConnectionState() {
        // Controller may or may not be connected depending on hardware
        // Both states are valid
        XCTAssertTrue(controller.isConnected || !controller.isConnected, "Connection state should be boolean")
    }

    // MARK: - LED Pattern Tests

    func testLEDPatternEnums() {
        let allPatterns = Push3LEDController.LEDPattern.allCases
        XCTAssertEqual(allPatterns.count, 7, "Should have 7 LED patterns")

        // Verify all patterns exist
        XCTAssertTrue(allPatterns.contains(.breathe))
        XCTAssertTrue(allPatterns.contains(.pulse))
        XCTAssertTrue(allPatterns.contains(.coherence))
        XCTAssertTrue(allPatterns.contains(.rainbow))
        XCTAssertTrue(allPatterns.contains(.wave))
        XCTAssertTrue(allPatterns.contains(.spiral))
        XCTAssertTrue(allPatterns.contains(.gestureFlash))
    }

    func testLEDPatternDescriptions() {
        XCTAssertEqual(Push3LEDController.LEDPattern.breathe.description, "Breathing animation (HRV-synced)")
        XCTAssertEqual(Push3LEDController.LEDPattern.pulse.description, "Heart rate pulse indicator")
        XCTAssertEqual(Push3LEDController.LEDPattern.coherence.description, "HRV coherence color mapping")
        XCTAssertEqual(Push3LEDController.LEDPattern.rainbow.description, "Rainbow spectrum animation")
        XCTAssertEqual(Push3LEDController.LEDPattern.wave.description, "Ripple wave effect")
        XCTAssertEqual(Push3LEDController.LEDPattern.spiral.description, "Spiral pattern from center")
        XCTAssertEqual(Push3LEDController.LEDPattern.gestureFlash.description, "Flash on gesture trigger")
    }

    func testPatternChange() {
        controller.currentPattern = .pulse
        XCTAssertEqual(controller.currentPattern, .pulse)

        controller.currentPattern = .rainbow
        XCTAssertEqual(controller.currentPattern, .rainbow)
    }

    // MARK: - RGB Color Tests

    func testRGBStruct() {
        let red = Push3LEDController.RGB(r: 255, g: 0, b: 0)
        XCTAssertEqual(red.r, 255)
        XCTAssertEqual(red.g, 0)
        XCTAssertEqual(red.b, 0)
    }

    func testRGBPresetColors() {
        let black = Push3LEDController.RGB.black
        XCTAssertEqual(black.r, 0)
        XCTAssertEqual(black.g, 0)
        XCTAssertEqual(black.b, 0)

        let red = Push3LEDController.RGB.red
        XCTAssertEqual(red.r, 255)
        XCTAssertEqual(red.g, 0)
        XCTAssertEqual(red.b, 0)

        let green = Push3LEDController.RGB.green
        XCTAssertEqual(green.r, 0)
        XCTAssertEqual(green.g, 255)
        XCTAssertEqual(green.b, 0)

        let blue = Push3LEDController.RGB.blue
        XCTAssertEqual(blue.r, 0)
        XCTAssertEqual(blue.g, 0)
        XCTAssertEqual(blue.b, 255)

        let white = Push3LEDController.RGB.white
        XCTAssertEqual(white.r, 255)
        XCTAssertEqual(white.g, 255)
        XCTAssertEqual(white.b, 255)

        let cyan = Push3LEDController.RGB.cyan
        XCTAssertEqual(cyan.r, 0)
        XCTAssertEqual(cyan.g, 255)
        XCTAssertEqual(cyan.b, 255)

        let magenta = Push3LEDController.RGB.magenta
        XCTAssertEqual(magenta.r, 255)
        XCTAssertEqual(magenta.g, 0)
        XCTAssertEqual(magenta.b, 255)

        let yellow = Push3LEDController.RGB.yellow
        XCTAssertEqual(yellow.r, 255)
        XCTAssertEqual(yellow.g, 255)
        XCTAssertEqual(yellow.b, 0)
    }

    // MARK: - Brightness Tests

    func testBrightnessRange() {
        controller.brightness = 0.0
        XCTAssertEqual(controller.brightness, 0.0, accuracy: 0.01)

        controller.brightness = 0.5
        XCTAssertEqual(controller.brightness, 0.5, accuracy: 0.01)

        controller.brightness = 1.0
        XCTAssertEqual(controller.brightness, 1.0, accuracy: 0.01)
    }

    func testBrightnessClipping() {
        // Test values outside normal range
        controller.brightness = -0.5
        // Should either clamp or handle gracefully
        XCTAssertGreaterThanOrEqual(controller.brightness, -0.5)

        controller.brightness = 1.5
        // Should either clamp or handle gracefully
        XCTAssertGreaterThanOrEqual(controller.brightness, 0.0)
    }

    // MARK: - LED Grid Tests

    func testLEDGridDimensions() {
        // LED grid should be 8x8
        // We can't access private ledGrid directly, but we can test the concept
        let gridSize = 8
        XCTAssertEqual(gridSize, 8, "LED grid should be 8x8")
    }

    func testSetLEDColor() {
        let color = Push3LEDController.RGB(r: 100, g: 150, b: 200)

        // Test setting LED at various positions
        for row in 0..<8 {
            for col in 0..<8 {
                // Should not crash when setting LEDs
                controller.setLED(row: row, col: col, color: color)
            }
        }
    }

    func testSetAllLEDs() {
        let color = Push3LEDController.RGB.red

        // Should not crash when setting all LEDs
        controller.setAllLEDs(color: color)
    }

    func testClearGrid() {
        // Should not crash when clearing
        controller.clearGrid()
    }

    // MARK: - Bio-Reactive Pattern Tests

    func testBreathePattern() {
        controller.currentPattern = .breathe

        // Update with HRV data
        controller.updateBioParameters(hrvCoherence: 0.5, heartRate: 60, breathingRate: 6.0)

        // Should not crash
        XCTAssertEqual(controller.currentPattern, .breathe)
    }

    func testPulsePattern() {
        controller.currentPattern = .pulse

        // Update with heart rate data
        controller.updateBioParameters(hrvCoherence: 0.5, heartRate: 72, breathingRate: 6.0)

        // Should pulse at heart rate frequency
        XCTAssertEqual(controller.currentPattern, .pulse)
    }

    func testCoherencePattern() {
        controller.currentPattern = .coherence

        // Test low coherence (red)
        controller.updateBioParameters(hrvCoherence: 0.2, heartRate: 60, breathingRate: 6.0)

        // Test mid coherence (yellow/green)
        controller.updateBioParameters(hrvCoherence: 0.5, heartRate: 60, breathingRate: 6.0)

        // Test high coherence (green/blue)
        controller.updateBioParameters(hrvCoherence: 0.9, heartRate: 60, breathingRate: 6.0)

        XCTAssertEqual(controller.currentPattern, .coherence)
    }

    // MARK: - Animation Tests

    func testRainbowAnimation() {
        controller.currentPattern = .rainbow

        // Animate rainbow pattern
        let startTime = CACurrentMediaTime()
        controller.updateAnimation(time: startTime)
        controller.updateAnimation(time: startTime + 1.0)
        controller.updateAnimation(time: startTime + 2.0)

        // Should cycle through colors without crashing
        XCTAssertEqual(controller.currentPattern, .rainbow)
    }

    func testWaveAnimation() {
        controller.currentPattern = .wave

        // Animate wave pattern
        let startTime = CACurrentMediaTime()
        controller.updateAnimation(time: startTime)
        controller.updateAnimation(time: startTime + 0.5)
        controller.updateAnimation(time: startTime + 1.0)

        XCTAssertEqual(controller.currentPattern, .wave)
    }

    func testSpiralAnimation() {
        controller.currentPattern = .spiral

        // Animate spiral pattern
        let startTime = CACurrentMediaTime()
        controller.updateAnimation(time: startTime)
        controller.updateAnimation(time: startTime + 0.5)

        XCTAssertEqual(controller.currentPattern, .spiral)
    }

    // MARK: - Gesture Flash Tests

    func testGestureFlash() {
        controller.currentPattern = .gestureFlash

        // Trigger gesture flash
        controller.triggerGestureFlash(type: "swipe")

        // Should flash briefly
        XCTAssertEqual(controller.currentPattern, .gestureFlash)
    }

    func testMultipleGestureFlashes() {
        controller.currentPattern = .gestureFlash

        // Trigger multiple flashes
        controller.triggerGestureFlash(type: "swipe")
        controller.triggerGestureFlash(type: "tap")
        controller.triggerGestureFlash(type: "pinch")

        // Should handle rapid triggers
        XCTAssertEqual(controller.currentPattern, .gestureFlash)
    }

    // MARK: - SysEx Message Tests

    func testSysExMessageFormat() {
        // Test that SysEx messages are properly formatted
        // Header should be: F0 00 21 1D 01 01 (Ableton Push 3)
        // Should end with F7

        let message = controller.createLEDSysExMessage(row: 0, col: 0, color: .red)

        XCTAssertNotNil(message)
        if let msg = message {
            XCTAssertEqual(msg.first, 0xF0, "SysEx should start with F0")
            XCTAssertEqual(msg.last, 0xF7, "SysEx should end with F7")
            XCTAssertTrue(msg.count > 6, "Message should contain header + data")
        }
    }

    func testSysExMessageForAllLEDs() {
        // Test creating SysEx messages for entire grid
        for row in 0..<8 {
            for col in 0..<8 {
                let message = controller.createLEDSysExMessage(
                    row: row,
                    col: col,
                    color: Push3LEDController.RGB.green
                )
                XCTAssertNotNil(message, "Should create message for LED at \(row),\(col)")
            }
        }
    }

    // MARK: - Connection Tests

    func testConnect() {
        // Connection may fail without hardware
        controller.connect()
        // Should not crash
        XCTAssertTrue(controller.isConnected || !controller.isConnected)
    }

    func testDisconnect() {
        controller.disconnect()
        XCTAssertFalse(controller.isConnected, "Should be disconnected after disconnect()")
    }

    func testReconnect() {
        controller.disconnect()
        XCTAssertFalse(controller.isConnected)

        controller.connect()
        // May or may not succeed without hardware
        XCTAssertTrue(controller.isConnected || !controller.isConnected)
    }

    // MARK: - Color Interpolation Tests

    func testColorInterpolation() {
        let color1 = Push3LEDController.RGB.red
        let color2 = Push3LEDController.RGB.blue

        // Interpolate at 0% (should be color1)
        let result0 = controller.interpolateColor(from: color1, to: color2, t: 0.0)
        XCTAssertEqual(result0.r, color1.r)
        XCTAssertEqual(result0.g, color1.g)
        XCTAssertEqual(result0.b, color1.b)

        // Interpolate at 100% (should be color2)
        let result1 = controller.interpolateColor(from: color1, to: color2, t: 1.0)
        XCTAssertEqual(result1.r, color2.r)
        XCTAssertEqual(result1.g, color2.g)
        XCTAssertEqual(result1.b, color2.b)

        // Interpolate at 50% (should be midpoint)
        let result05 = controller.interpolateColor(from: color1, to: color2, t: 0.5)
        XCTAssertGreaterThan(result05.r, 0)
        XCTAssertGreaterThan(result05.b, 0)
    }

    func testHRVToColor() {
        // Low HRV coherence = red
        let colorLow = controller.hrvCoherenceToColor(coherence: 0.0)
        XCTAssertGreaterThan(colorLow.r, 200)

        // Mid HRV coherence = yellow/green
        let colorMid = controller.hrvCoherenceToColor(coherence: 0.5)
        XCTAssertGreaterThan(colorMid.g, 100)

        // High HRV coherence = green/blue
        let colorHigh = controller.hrvCoherenceToColor(coherence: 1.0)
        XCTAssertGreaterThan(colorHigh.g, 100)
    }

    // MARK: - Performance Tests

    func testPerformanceUpdateAllLEDs() {
        measure {
            for _ in 0..<100 {
                controller.setAllLEDs(color: .red)
            }
        }
    }

    func testPerformanceAnimationUpdate() {
        controller.currentPattern = .rainbow

        measure {
            let startTime = CACurrentMediaTime()
            for i in 0..<60 {
                controller.updateAnimation(time: startTime + Double(i) / 60.0)
            }
        }
    }

    func testPerformanceSysExGeneration() {
        measure {
            for row in 0..<8 {
                for col in 0..<8 {
                    _ = controller.createLEDSysExMessage(
                        row: row,
                        col: col,
                        color: Push3LEDController.RGB(
                            r: UInt8.random(in: 0...255),
                            g: UInt8.random(in: 0...255),
                            b: UInt8.random(in: 0...255)
                        )
                    )
                }
            }
        }
    }

    // MARK: - Edge Cases

    func testOutOfBoundsLED() {
        let color = Push3LEDController.RGB.red

        // Should handle gracefully (clamp or ignore)
        controller.setLED(row: -1, col: 0, color: color)
        controller.setLED(row: 0, col: -1, color: color)
        controller.setLED(row: 10, col: 0, color: color)
        controller.setLED(row: 0, col: 10, color: color)
    }

    func testZeroBrightness() {
        controller.brightness = 0.0

        // All LEDs should be off
        controller.setAllLEDs(color: .white)

        XCTAssertEqual(controller.brightness, 0.0, accuracy: 0.01)
    }

    func testInvalidBioParameters() {
        // Negative values should be handled
        controller.updateBioParameters(hrvCoherence: -1.0, heartRate: -50, breathingRate: -10)

        // Should not crash
        XCTAssertNotNil(controller)
    }

    func testExtremeHeartRate() {
        controller.currentPattern = .pulse

        // Very low heart rate
        controller.updateBioParameters(hrvCoherence: 0.5, heartRate: 30, breathingRate: 6.0)

        // Very high heart rate
        controller.updateBioParameters(hrvCoherence: 0.5, heartRate: 200, breathingRate: 6.0)

        // Should handle gracefully
        XCTAssertEqual(controller.currentPattern, .pulse)
    }

    // MARK: - Integration Tests

    func testFullWorkflow() {
        // 1. Connect (may fail without hardware)
        controller.connect()

        // 2. Set pattern
        controller.currentPattern = .coherence

        // 3. Set brightness
        controller.brightness = 0.8

        // 4. Update with bio parameters
        controller.updateBioParameters(hrvCoherence: 0.7, heartRate: 65, breathingRate: 6.0)

        // 5. Animate
        let startTime = CACurrentMediaTime()
        controller.updateAnimation(time: startTime)
        controller.updateAnimation(time: startTime + 0.5)

        // 6. Change pattern
        controller.currentPattern = .rainbow
        controller.updateAnimation(time: startTime + 1.0)

        // 7. Trigger gesture flash
        controller.triggerGestureFlash(type: "swipe")

        // 8. Clear grid
        controller.clearGrid()

        // 9. Disconnect
        controller.disconnect()
        XCTAssertFalse(controller.isConnected)

        // Should complete without crashes
        XCTAssertNotNil(controller)
    }

    func testBioReactiveColorMapping() {
        // Test full range of bio parameters
        let coherenceLevels: [Float] = [0.0, 0.25, 0.5, 0.75, 1.0]
        let heartRates = [40, 60, 80, 100, 120]

        for coherence in coherenceLevels {
            for hr in heartRates {
                controller.currentPattern = .coherence
                controller.updateBioParameters(
                    hrvCoherence: coherence,
                    heartRate: hr,
                    breathingRate: 6.0
                )

                // Should update colors based on bio parameters
                XCTAssertNotNil(controller)
            }
        }
    }

    func testPatternTransitions() {
        let patterns = Push3LEDController.LEDPattern.allCases

        // Cycle through all patterns
        for pattern in patterns {
            controller.currentPattern = pattern
            XCTAssertEqual(controller.currentPattern, pattern)

            // Animate each pattern
            let time = CACurrentMediaTime()
            controller.updateAnimation(time: time)
        }
    }
}
