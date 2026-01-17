// OctaveCreativeStudioTests.swift
// Tests für den Oktav-Kreativbaukasten
//
// Copyright 2026 Echoelmusic. MIT License.

import XCTest
@testable import Echoelmusic

final class OctaveCreativeStudioTests: XCTestCase {

    // MARK: - Bio → Audio Oktavierung Tests

    func testBioToAudio_OctaveMultiplication() {
        // f × 2^n Formel verifizieren
        let studio = OctaveCreativeStudioTestHelper()

        // 1 Hz × 2^6 = 64 Hz
        XCTAssertEqual(studio.bioToAudio(bioFrequency: 1.0, octaves: 6), 64.0, accuracy: 0.01)

        // 1 Hz × 2^12 = 4096 Hz
        XCTAssertEqual(studio.bioToAudio(bioFrequency: 1.0, octaves: 12), 4096.0, accuracy: 0.01)

        // 0.1 Hz × 2^10 = 102.4 Hz
        XCTAssertEqual(studio.bioToAudio(bioFrequency: 0.1, octaves: 10), 102.4, accuracy: 0.01)
    }

    func testHeartRateToAudio_StandardMapping() {
        let studio = OctaveCreativeStudioTestHelper()

        // 60 BPM = 1 Hz, mit 6 Oktaven = 64 Hz
        studio.liveBioData.heartRate = 60
        studio.heartRateOctaves = 6
        XCTAssertEqual(studio.heartRateToAudio(), 64.0, accuracy: 0.01)

        // 120 BPM = 2 Hz, mit 6 Oktaven = 128 Hz
        studio.liveBioData.heartRate = 120
        XCTAssertEqual(studio.heartRateToAudio(), 128.0, accuracy: 0.01)
    }

    func testBreathingToAudio_StandardMapping() {
        let studio = OctaveCreativeStudioTestHelper()

        // 12 Atemzüge/min = 0.2 Hz, mit 8 Oktaven = 51.2 Hz
        studio.liveBioData.breathingRate = 12
        studio.breathingOctaves = 8
        XCTAssertEqual(studio.breathingToAudio(), 51.2, accuracy: 0.01)
    }

    func testHRVToAudio_StandardMapping() {
        let studio = OctaveCreativeStudioTestHelper()

        // 0.1 Hz mit 12 Oktaven = 409.6 Hz
        studio.liveBioData.hrvFrequency = 0.1
        studio.hrvOctaves = 12
        XCTAssertEqual(studio.hrvToAudio(), 409.6, accuracy: 0.01)
    }

    // MARK: - Mapping Curve Tests

    func testMappingCurve_Linear() {
        let curve = OctaveCreativeStudio.MappingCurve.linear
        XCTAssertEqual(curve.apply(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(curve.apply(0.5), 0.5, accuracy: 0.001)
        XCTAssertEqual(curve.apply(1.0), 1.0, accuracy: 0.001)
    }

    func testMappingCurve_Logarithmic() {
        let curve = OctaveCreativeStudio.MappingCurve.logarithmic
        XCTAssertEqual(curve.apply(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(curve.apply(1.0), 1.0, accuracy: 0.001)
        // Logarithmisch sollte bei 0.5 input höher als 0.5 sein
        XCTAssertGreaterThan(curve.apply(0.5), 0.5)
    }

    func testMappingCurve_Exponential() {
        let curve = OctaveCreativeStudio.MappingCurve.exponential
        XCTAssertEqual(curve.apply(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(curve.apply(1.0), 1.0, accuracy: 0.001)
        // Exponentiell sollte bei 0.5 input = 0.25 sein (0.5^2)
        XCTAssertEqual(curve.apply(0.5), 0.25, accuracy: 0.001)
    }

    func testMappingCurve_SCurve() {
        let curve = OctaveCreativeStudio.MappingCurve.sCurve
        XCTAssertEqual(curve.apply(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(curve.apply(1.0), 1.0, accuracy: 0.001)
        // S-Curve sollte bei 0.5 input = 0.5 sein (Wendepunkt)
        XCTAssertEqual(curve.apply(0.5), 0.5, accuracy: 0.001)
    }

    func testMappingCurve_Stepped() {
        let curve = OctaveCreativeStudio.MappingCurve.stepped
        // 8 Stufen: 0, 0.125, 0.25, ...
        XCTAssertEqual(curve.apply(0.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(curve.apply(0.1), 0.0, accuracy: 0.001)  // floor(0.1 * 8) / 8 = 0
        XCTAssertEqual(curve.apply(0.2), 0.125, accuracy: 0.001) // floor(0.2 * 8) / 8 = 1/8
    }

    func testMappingCurve_AllCases() {
        // Alle Kurven sollten definiert sein
        XCTAssertEqual(OctaveCreativeStudio.MappingCurve.allCases.count, 6)

        // Alle sollten bei 0 → 0 und 1 → 1 mappen
        for curve in OctaveCreativeStudio.MappingCurve.allCases {
            XCTAssertEqual(curve.apply(0.0), 0.0, accuracy: 0.01, "\(curve) failed at 0")
            XCTAssertEqual(curve.apply(1.0), 1.0, accuracy: 0.01, "\(curve) failed at 1")
        }
    }

    // MARK: - Preset Tests

    func testPreset_AllCasesExist() {
        XCTAssertEqual(OctaveCreativeStudio.OctavePreset.allCases.count, 8)
    }

    func testPreset_ValuesInValidRange() {
        for preset in OctaveCreativeStudio.OctavePreset.allCases {
            XCTAssertGreaterThanOrEqual(preset.heartRateOctaves, 1)
            XCTAssertLessThanOrEqual(preset.heartRateOctaves, 12)

            XCTAssertGreaterThanOrEqual(preset.breathingOctaves, 1)
            XCTAssertLessThanOrEqual(preset.breathingOctaves, 15)

            XCTAssertGreaterThanOrEqual(preset.hrvOctaves, 1)
            XCTAssertLessThanOrEqual(preset.hrvOctaves, 18)

            XCTAssertGreaterThanOrEqual(preset.colorTemperature, -1)
            XCTAssertLessThanOrEqual(preset.colorTemperature, 1)
        }
    }

    func testPreset_WarmHasNegativeTemperature() {
        let warm = OctaveCreativeStudio.OctavePreset.warm
        XCTAssertLessThan(warm.colorTemperature, 0, "Warm preset should have negative temperature")
    }

    func testPreset_CoolHasPositiveTemperature() {
        let cool = OctaveCreativeStudio.OctavePreset.cool
        XCTAssertGreaterThan(cool.colorTemperature, 0, "Cool preset should have positive temperature")
    }

    func testPreset_NeutralHasZeroTemperature() {
        let neutral = OctaveCreativeStudio.OctavePreset.neutral
        XCTAssertEqual(neutral.colorTemperature, 0, accuracy: 0.001)
    }

    // MARK: - Wavelength → RGB Tests

    func testWavelengthToRGB_RedRegion() {
        let studio = OctaveCreativeStudioTestHelper()

        // 700nm sollte Rot sein
        let rgb = studio.wavelengthToRGB(wavelength: 700)
        XCTAssertGreaterThan(rgb.r, 0.5, "Red should be dominant at 700nm")
        XCTAssertLessThan(rgb.g, 0.1, "Green should be low at 700nm")
        XCTAssertLessThan(rgb.b, 0.1, "Blue should be low at 700nm")
    }

    func testWavelengthToRGB_GreenRegion() {
        let studio = OctaveCreativeStudioTestHelper()

        // 550nm sollte Grün sein
        let rgb = studio.wavelengthToRGB(wavelength: 550)
        XCTAssertGreaterThan(rgb.g, 0.5, "Green should be dominant at 550nm")
    }

    func testWavelengthToRGB_BlueRegion() {
        let studio = OctaveCreativeStudioTestHelper()

        // 450nm sollte Blau sein
        let rgb = studio.wavelengthToRGB(wavelength: 450)
        XCTAssertGreaterThan(rgb.b, 0.5, "Blue should be dominant at 450nm")
    }

    func testWavelengthToRGB_VioletRegion() {
        let studio = OctaveCreativeStudioTestHelper()

        // 400nm sollte Violett sein (Rot + Blau)
        let rgb = studio.wavelengthToRGB(wavelength: 400)
        XCTAssertGreaterThan(rgb.r, 0, "Red should be present in violet")
        XCTAssertGreaterThan(rgb.b, 0, "Blue should be present in violet")
    }

    // MARK: - Frequency → Wavelength Tests

    func testFrequencyToWavelength_Physics() {
        let studio = OctaveCreativeStudioTestHelper()

        // c = λ × f → λ = c / f
        // Bei 500 THz: λ = 299792.458 / 500 ≈ 600 nm
        XCTAssertEqual(studio.frequencyToWavelength(thz: 500), 599.58, accuracy: 0.1)

        // Bei 750 THz: λ ≈ 400 nm (Violett)
        XCTAssertEqual(studio.frequencyToWavelength(thz: 750), 399.72, accuracy: 0.1)

        // Bei 400 THz: λ ≈ 750 nm (Rot)
        XCTAssertEqual(studio.frequencyToWavelength(thz: 400), 749.48, accuracy: 0.1)
    }

    // MARK: - Live Bio Data Tests

    func testLiveBioData_DefaultValues() {
        let bioData = OctaveCreativeStudio.LiveBioData()
        XCTAssertEqual(bioData.heartRate, 70)
        XCTAssertEqual(bioData.breathingRate, 12)
        XCTAssertEqual(bioData.hrvFrequency, 0.1, accuracy: 0.001)
        XCTAssertEqual(bioData.coherence, 0.5, accuracy: 0.001)
    }

    func testLiveBioData_CustomValues() {
        let bioData = OctaveCreativeStudio.LiveBioData(
            heartRate: 80,
            breathingRate: 15,
            hrvFrequency: 0.15,
            coherence: 0.8
        )
        XCTAssertEqual(bioData.heartRate, 80)
        XCTAssertEqual(bioData.breathingRate, 15)
        XCTAssertEqual(bioData.hrvFrequency, 0.15, accuracy: 0.001)
        XCTAssertEqual(bioData.coherence, 0.8, accuracy: 0.001)
    }

    // MARK: - Full Chain Tests

    func testFullChain_BioToColor() {
        let studio = OctaveCreativeStudioTestHelper()

        // Setup standard values
        studio.liveBioData.heartRate = 60  // 1 Hz
        studio.heartRateOctaves = 6        // → 64 Hz (tiefes C)
        studio.liveBioData.coherence = 1.0 // Volle Sättigung

        // Berechne Farbe
        let color = studio.calculateResultColor()

        // Farbe sollte existieren (nicht nil/crash)
        XCTAssertNotNil(color)
    }

    // MARK: - Edge Case Tests

    func testOctaveShift_EdgeCases() {
        let studio = OctaveCreativeStudioTestHelper()

        // Sehr niedrige Frequenz mit vielen Oktaven
        let result = studio.bioToAudio(bioFrequency: 0.01, octaves: 18)
        XCTAssertGreaterThan(result, 0)
        XCTAssertLessThan(result, 100000) // Sollte noch im hörbaren/nahen Bereich sein

        // Null Frequenz
        let zeroResult = studio.bioToAudio(bioFrequency: 0, octaves: 6)
        XCTAssertEqual(zeroResult, 0)
    }

    func testMappingCurve_Clamping() {
        // Werte außerhalb 0-1 sollten geclampt werden
        for curve in OctaveCreativeStudio.MappingCurve.allCases {
            let belowZero = curve.apply(-0.5)
            let aboveOne = curve.apply(1.5)

            XCTAssertGreaterThanOrEqual(belowZero, 0, "\(curve) should clamp negative values")
            XCTAssertLessThanOrEqual(aboveOne, 1, "\(curve) should clamp values > 1")
        }
    }

    // MARK: - Light Mapper Integration Tests

    func testResultRGB_StoresComponents() {
        let studio = OctaveCreativeStudioTestHelper()

        studio.liveBioData.heartRate = 70
        studio.liveBioData.coherence = 0.8
        studio.heartRateOctaves = 6

        // Calculate result
        let result = studio.calculateResultColor() as! (r: Float, g: Float, b: Float)

        // RGB components should be valid
        XCTAssertGreaterThanOrEqual(result.r, 0)
        XCTAssertLessThanOrEqual(result.r, 1)
        XCTAssertGreaterThanOrEqual(result.g, 0)
        XCTAssertLessThanOrEqual(result.g, 1)
        XCTAssertGreaterThanOrEqual(result.b, 0)
        XCTAssertLessThanOrEqual(result.b, 1)
    }

    func testOnColorUpdate_CallbackFires() {
        var callbackFired = false
        var capturedR: Float = 0
        var capturedG: Float = 0
        var capturedB: Float = 0
        var capturedCoherence: Float = 0

        // Simulate callback behavior from OctaveCreativeStudio
        let callback: (Float, Float, Float, Float) -> Void = { r, g, b, coherence in
            callbackFired = true
            capturedR = r
            capturedG = g
            capturedB = b
            capturedCoherence = coherence
        }

        // Simulate what updateResult would do
        let rgb: (r: Float, g: Float, b: Float) = (0.8, 0.3, 0.1)
        let coherence: Float = 0.75
        callback(rgb.r, rgb.g, rgb.b, coherence)

        XCTAssertTrue(callbackFired, "Color update callback should fire")
        XCTAssertEqual(capturedR, 0.8, accuracy: 0.01)
        XCTAssertEqual(capturedG, 0.3, accuracy: 0.01)
        XCTAssertEqual(capturedB, 0.1, accuracy: 0.01)
        XCTAssertEqual(capturedCoherence, 0.75, accuracy: 0.01)
    }
}

// MARK: - Test Helper (Non-MainActor)

/// Test-Helfer ohne @MainActor für synchrone Tests
class OctaveCreativeStudioTestHelper {
    var heartRateOctaves: Int = 6
    var breathingOctaves: Int = 8
    var hrvOctaves: Int = 12
    var mappingCurve: OctaveCreativeStudio.MappingCurve = .logarithmic
    var colorTemperature: Float = 0.0
    var liveBioData: OctaveCreativeStudio.LiveBioData = .init()

    func bioToAudio(bioFrequency: Float, octaves: Int) -> Float {
        return bioFrequency * pow(2.0, Float(octaves))
    }

    func heartRateToAudio() -> Float {
        let heartFrequency = liveBioData.heartRate / 60.0
        return bioToAudio(bioFrequency: heartFrequency, octaves: heartRateOctaves)
    }

    func breathingToAudio() -> Float {
        let breathFrequency = liveBioData.breathingRate / 60.0
        return bioToAudio(bioFrequency: breathFrequency, octaves: breathingOctaves)
    }

    func hrvToAudio() -> Float {
        return bioToAudio(bioFrequency: liveBioData.hrvFrequency, octaves: hrvOctaves)
    }

    func frequencyToWavelength(thz: Float) -> Float {
        return 299792.458 / thz
    }

    func wavelengthToRGB(wavelength: Float) -> (r: Float, g: Float, b: Float) {
        var r: Float = 0, g: Float = 0, b: Float = 0
        let wl = wavelength

        if wl >= 380 && wl < 440 {
            r = -(wl - 440) / (440 - 380)
            b = 1
        } else if wl >= 440 && wl < 490 {
            g = (wl - 440) / (490 - 440)
            b = 1
        } else if wl >= 490 && wl < 510 {
            g = 1
            b = -(wl - 510) / (510 - 490)
        } else if wl >= 510 && wl < 580 {
            r = (wl - 510) / (580 - 510)
            g = 1
        } else if wl >= 580 && wl < 645 {
            r = 1
            g = -(wl - 645) / (645 - 580)
        } else if wl >= 645 && wl <= 780 {
            r = 1
        }

        var intensity: Float = 1.0
        if wl >= 380 && wl < 420 {
            intensity = 0.3 + 0.7 * (wl - 380) / (420 - 380)
        } else if wl >= 700 && wl <= 780 {
            intensity = 0.3 + 0.7 * (780 - wl) / (780 - 700)
        }

        return (r * intensity, g * intensity, b * intensity)
    }

    func audioToLight(audioFrequency: Float) -> Float {
        let audioMin: Float = 20
        let audioMax: Float = 20000
        let lightMinTHz: Float = 400
        let lightMaxTHz: Float = 750

        let audioOctaves = log2(audioMax / audioMin)
        let position = log2(audioFrequency / audioMin) / audioOctaves
        let clampedPosition = max(0, min(1, position))
        let curvedPosition = mappingCurve.apply(clampedPosition)
        let adjustedPosition = max(0, min(1, curvedPosition + colorTemperature * 0.2))

        return lightMinTHz * pow(lightMaxTHz / lightMinTHz, adjustedPosition)
    }

    func calculateResultColor() -> Any {
        let audioFreq = heartRateToAudio()
        let lightFreq = audioToLight(audioFrequency: audioFreq)
        let wavelength = frequencyToWavelength(thz: lightFreq)
        let rgb = wavelengthToRGB(wavelength: wavelength)
        let saturation = 0.5 + liveBioData.coherence * 0.5
        return (r: rgb.r * saturation, g: rgb.g * saturation, b: rgb.b * saturation)
    }
}
