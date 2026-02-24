// HomeKitBioLightingTests.swift
// Tests for HomeKitBioLighting — Bio-Reactive Smart Lighting

import XCTest
@testable import Echoelmusic

final class HomeKitBioLightingTests: XCTestCase {

    // MARK: - Init

    func testDefaultInit() {
        let controller = HomeKitBioLighting()
        XCTAssertFalse(controller.isEnabled)
        XCTAssertFalse(controller.isConnected)
        XCTAssertTrue(controller.zones.isEmpty)
    }

    // MARK: - Bio-to-Light Mapping

    func testHighCoherenceWarmColor() {
        let controller = HomeKitBioLighting()
        controller.updateBio(coherence: 0.9, hrv: 0.7)
        let state = controller.computeLightState()

        // High coherence → warm hue (near 0.08)
        XCTAssertLessThan(state.hue, 0.3, "High coherence should produce warm hue")
    }

    func testLowCoherenceCoolColor() {
        let controller = HomeKitBioLighting()
        controller.updateBio(coherence: 0.1, hrv: 0.3)
        let state = controller.computeLightState()

        // Low coherence → cool hue (near 0.6)
        XCTAssertGreaterThan(state.hue, 0.3, "Low coherence should produce cool hue")
    }

    func testBrightnessWithinBounds() {
        let controller = HomeKitBioLighting()

        for coherence in stride(from: Float(0), through: 1.0, by: 0.2) {
            for breath in stride(from: Float(0), through: 1.0, by: 0.2) {
                controller.updateBio(coherence: coherence, breathPhase: breath, breathDepth: 1.0)
                let state = controller.computeLightState()
                XCTAssertGreaterThanOrEqual(state.brightness, controller.mapping.minBrightness - 0.01)
                XCTAssertLessThanOrEqual(state.brightness, controller.mapping.maxBrightness + 0.01)
            }
        }
    }

    func testHueWithinRange() {
        let controller = HomeKitBioLighting()

        for c in stride(from: Float(0), through: 1.0, by: 0.1) {
            controller.updateBio(coherence: c)
            let state = controller.computeLightState()
            XCTAssertGreaterThanOrEqual(state.hue, 0)
            XCTAssertLessThanOrEqual(state.hue, 1.0)
            XCTAssertGreaterThanOrEqual(state.saturation, 0)
            XCTAssertLessThanOrEqual(state.saturation, 1.0)
        }
    }

    // MARK: - RGB Conversion

    func testRGBConversion() {
        var state = BioLightState()
        state.hue = 0
        state.saturation = 1.0
        state.brightness = 1.0
        let rgb = state.rgb
        // Red
        XCTAssertEqual(rgb.r, 1.0, accuracy: 0.01)
        XCTAssertEqual(rgb.g, 0.0, accuracy: 0.01)
        XCTAssertEqual(rgb.b, 0.0, accuracy: 0.01)
    }

    func testRGBDesaturated() {
        var state = BioLightState()
        state.hue = 0.5
        state.saturation = 0.0
        state.brightness = 0.8
        let rgb = state.rgb
        // Grayscale
        XCTAssertEqual(rgb.r, rgb.g, accuracy: 0.01)
        XCTAssertEqual(rgb.g, rgb.b, accuracy: 0.01)
    }

    // MARK: - Zone Management

    func testAddRemoveZone() {
        let controller = HomeKitBioLighting()
        let zone = LightZone(name: "Test Zone")
        controller.addZone(zone)
        XCTAssertEqual(controller.zones.count, 1)
        controller.removeZone(id: zone.id)
        XCTAssertEqual(controller.zones.count, 0)
    }

    // MARK: - Presets

    func testRelaxationPreset() {
        let controller = HomeKitBioLighting()
        controller.applyPreset(.relaxation)
        XCTAssertEqual(controller.mapping.coherenceToWarmth, 0.9, accuracy: 0.01)
        XCTAssertLessThanOrEqual(controller.mapping.maxBrightness, 0.6)
    }

    func testFocusPreset() {
        let controller = HomeKitBioLighting()
        controller.applyPreset(.focus)
        XCTAssertGreaterThanOrEqual(controller.mapping.minBrightness, 0.5)
    }

    func testPerformancePreset() {
        let controller = HomeKitBioLighting()
        controller.applyPreset(.performance)
        XCTAssertGreaterThan(controller.mapping.audioToHue, 0)
    }

    func testSleepPreset() {
        let controller = HomeKitBioLighting()
        controller.applyPreset(.sleep)
        XCTAssertLessThanOrEqual(controller.mapping.maxBrightness, 0.15)
    }

    // MARK: - Audio Reactive

    func testAudioReactiveHueShift() {
        let controller = HomeKitBioLighting()
        controller.mapping.audioToHue = 0.8
        controller.updateBio(coherence: 0.5)

        controller.updateAudio(spectralCentroid: 0.1)
        let stateLow = controller.computeLightState()

        controller.updateAudio(spectralCentroid: 0.9)
        let stateHigh = controller.computeLightState()

        // Different spectral centroids should shift hue
        XCTAssertNotEqual(stateLow.hue, stateHigh.hue, accuracy: 0.001)
    }

    // MARK: - Color Temperature

    func testColorTemperatureRange() {
        let controller = HomeKitBioLighting()

        controller.updateBio(coherence: 0.0)
        let coolState = controller.computeLightState()

        controller.updateBio(coherence: 1.0)
        let warmState = controller.computeLightState()

        XCTAssertGreaterThan(coolState.colorTemperature, warmState.colorTemperature,
                             "Low coherence → higher color temp (cooler)")
    }
}
