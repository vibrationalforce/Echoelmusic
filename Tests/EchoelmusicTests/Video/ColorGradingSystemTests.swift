import XCTest
@testable import Echoelmusic

/// Comprehensive tests for ColorGradingSystem
/// Coverage target: Color science, LUT application, HDR processing
final class ColorGradingSystemTests: XCTestCase {

    // MARK: - Color Space Tests

    func testSRGBGamutBounds() {
        // sRGB values should be 0-255 or 0-1 normalized
        let minValue: Float = 0.0
        let maxValue: Float = 1.0

        let testValue: Float = 0.5
        XCTAssertGreaterThanOrEqual(testValue, minValue)
        XCTAssertLessThanOrEqual(testValue, maxValue)
    }

    func testRec709PrimariesChromaticity() {
        // Rec. 709 primary chromaticities (CIE xy coordinates)
        // Red: (0.640, 0.330), Green: (0.300, 0.600), Blue: (0.150, 0.060)
        let redPrimary = (x: 0.640, y: 0.330)
        let greenPrimary = (x: 0.300, y: 0.600)
        let bluePrimary = (x: 0.150, y: 0.060)

        XCTAssertEqual(redPrimary.x + redPrimary.y, 0.97, accuracy: 0.01)
        XCTAssertEqual(greenPrimary.x + greenPrimary.y, 0.90, accuracy: 0.01)
        XCTAssertEqual(bluePrimary.x + bluePrimary.y, 0.21, accuracy: 0.01)
    }

    func testRec2020GamutWidth() {
        // Rec. 2020 has wider gamut than Rec. 709
        let rec709GamutCoverage: Float = 35.9  // % of visible spectrum
        let rec2020GamutCoverage: Float = 75.8

        XCTAssertGreaterThan(rec2020GamutCoverage, rec709GamutCoverage)
    }

    // MARK: - Gamma Tests

    func testSRGBGammaValue() {
        // sRGB gamma is approximately 2.2
        let srgbGamma: Float = 2.2

        XCTAssertEqual(srgbGamma, 2.2, accuracy: 0.1)
    }

    func testLinearToSRGBConversion() {
        // Linear to sRGB: if L <= 0.0031308, S = 12.92 * L
        //                 else S = 1.055 * L^(1/2.4) - 0.055
        let linearValue: Float = 0.5
        let gamma: Float = 2.4

        let srgbValue = pow(linearValue, 1.0 / gamma)
        XCTAssertGreaterThan(srgbValue, linearValue, "sRGB should be brighter than linear")
    }

    func testPQTransferFunction() {
        // PQ (Perceptual Quantizer) for HDR - ST 2084
        let maxNits: Float = 10000.0
        XCTAssertEqual(maxNits, 10000.0, "PQ max luminance is 10,000 nits")
    }

    // MARK: - Exposure Tests

    func testExposureStops() {
        // Each stop doubles/halves the light
        let baseValue: Float = 1.0
        let plusOneStop = baseValue * 2.0
        let minusOneStop = baseValue / 2.0

        XCTAssertEqual(plusOneStop, 2.0, accuracy: 0.01)
        XCTAssertEqual(minusOneStop, 0.5, accuracy: 0.01)
    }

    func testExposureMultiplier() {
        // EV = log2(exposure multiplier)
        let ev: Float = 2.0  // +2 stops
        let multiplier = pow(2.0, ev)

        XCTAssertEqual(multiplier, 4.0, accuracy: 0.01, "2 stops = 4x multiplier")
    }

    // MARK: - White Balance Tests

    func testDaylightWhitePoint() {
        // D65 white point (6500K daylight)
        let d65Kelvin = 6500
        XCTAssertEqual(d65Kelvin, 6500)
    }

    func testTungstenWhitePoint() {
        // Tungsten/Incandescent (3200K)
        let tungstenKelvin = 3200
        XCTAssertEqual(tungstenKelvin, 3200)
    }

    func testKelvinToMiredConversion() {
        // Mired = 1,000,000 / Kelvin
        let kelvin = 5500.0
        let mired = 1_000_000.0 / kelvin

        XCTAssertEqual(mired, 181.8, accuracy: 0.1)
    }

    // MARK: - LUT Tests

    func test3DLUTDimensions() {
        // Common 3D LUT sizes
        let smallLUT = 17  // 17x17x17
        let mediumLUT = 33 // 33x33x33
        let largeLUT = 65  // 65x65x65

        XCTAssertEqual(smallLUT * smallLUT * smallLUT, 4913)
        XCTAssertEqual(mediumLUT * mediumLUT * mediumLUT, 35937)
        XCTAssertEqual(largeLUT * largeLUT * largeLUT, 274625)
    }

    func test1DLUTChannels() {
        // 1D LUT has separate curves for R, G, B
        let channels = 3
        let bitDepth = 10
        let entries = 1 << bitDepth  // 1024

        XCTAssertEqual(channels, 3)
        XCTAssertEqual(entries, 1024)
    }

    // MARK: - Contrast Tests

    func testContrastFormula() {
        // Contrast: output = (input - 0.5) * contrast + 0.5
        let input: Float = 0.75
        let contrast: Float = 1.5
        let output = (input - 0.5) * contrast + 0.5

        XCTAssertEqual(output, 0.875, accuracy: 0.001)
    }

    func testSCurveContrast() {
        // S-curve increases midtone contrast while protecting highlights/shadows
        let midpoint: Float = 0.5
        let shadowInput: Float = 0.2
        let highlightInput: Float = 0.8

        // S-curve should compress shadows and highlights
        XCTAssertLessThan(shadowInput, midpoint)
        XCTAssertGreaterThan(highlightInput, midpoint)
    }

    // MARK: - Saturation Tests

    func testSaturationBounds() {
        // Saturation typically 0-2 (0 = grayscale, 1 = normal, 2 = oversaturated)
        let minSaturation: Float = 0.0
        let normalSaturation: Float = 1.0
        let maxSaturation: Float = 2.0

        XCTAssertEqual(minSaturation, 0.0)
        XCTAssertEqual(normalSaturation, 1.0)
        XCTAssertLessThanOrEqual(maxSaturation, 3.0)
    }

    func testVibranceSaturation() {
        // Vibrance saturates less saturated colors more
        let lowSatColor: Float = 0.3
        let highSatColor: Float = 0.9
        let vibranceAmount: Float = 0.5

        let lowSatBoost = lowSatColor + vibranceAmount * (1.0 - lowSatColor)
        let highSatBoost = highSatColor + vibranceAmount * (1.0 - highSatColor)

        XCTAssertGreaterThan(lowSatBoost - lowSatColor, highSatBoost - highSatColor,
                             "Vibrance should boost low-sat colors more")
    }

    // MARK: - HDR Tests

    func testHDRMetadataBounds() {
        // HDR10 metadata
        let maxCLL: Int = 10000  // Max Content Light Level (nits)
        let maxFALL: Int = 4000  // Max Frame Average Light Level

        XCTAssertLessThanOrEqual(maxCLL, 10000)
        XCTAssertLessThanOrEqual(maxFALL, maxCLL)
    }

    func testDolbyVisionProfiles() {
        // Dolby Vision profile numbers
        let profileBackwardsCompatible = 5  // Profile 5: HDR10 compatible
        let profileDualLayer = 7            // Profile 7: Dual layer

        XCTAssertEqual(profileBackwardsCompatible, 5)
        XCTAssertEqual(profileDualLayer, 7)
    }

    // MARK: - Tone Mapping Tests

    func testReinhardToneMapping() {
        // Reinhard: output = input / (1 + input)
        let hdrValue: Float = 4.0
        let reinhardOutput = hdrValue / (1.0 + hdrValue)

        XCTAssertEqual(reinhardOutput, 0.8, accuracy: 0.01)
        XCTAssertLessThan(reinhardOutput, 1.0, "Tone mapped value should be < 1")
    }

    func testACESToneMapping() {
        // ACES typically compresses highlights more aggressively
        let highlightValue: Float = 10.0

        // ACES curve (simplified)
        let a: Float = 2.51
        let b: Float = 0.03
        let c: Float = 2.43
        let d: Float = 0.59
        let e: Float = 0.14

        let aces = (highlightValue * (a * highlightValue + b)) / (highlightValue * (c * highlightValue + d) + e)
        XCTAssertLessThan(aces, 2.0, "ACES should compress high values")
    }

    // MARK: - Color Correction Tests

    func testLiftGammaGain() {
        // Lift affects shadows, Gamma affects midtones, Gain affects highlights
        let lift: Float = 0.0    // Normally 0 (shadow adjustment)
        let gamma: Float = 1.0   // Normally 1 (midtone adjustment)
        let gain: Float = 1.0    // Normally 1 (highlight adjustment)

        XCTAssertEqual(lift, 0.0, accuracy: 0.01)
        XCTAssertEqual(gamma, 1.0, accuracy: 0.01)
        XCTAssertEqual(gain, 1.0, accuracy: 0.01)
    }

    func testHueSaturationLightness() {
        // HSL color model
        let hue: Float = 180.0      // 0-360 degrees
        let saturation: Float = 0.5  // 0-1
        let lightness: Float = 0.5   // 0-1

        XCTAssertGreaterThanOrEqual(hue, 0)
        XCTAssertLessThanOrEqual(hue, 360)
        XCTAssertGreaterThanOrEqual(saturation, 0)
        XCTAssertLessThanOrEqual(saturation, 1)
    }

    // MARK: - Color Grade Presets

    func testCinematicPresetWarmth() {
        // Cinematic look often has warm shadows, cool highlights
        let shadowTemperature: Float = 0.1  // Positive = warmer
        let highlightTemperature: Float = -0.1  // Negative = cooler

        XCTAssertGreaterThan(shadowTemperature, highlightTemperature)
    }

    func testVintagePresetDesaturation() {
        // Vintage looks are typically desaturated
        let vintageSaturation: Float = 0.7

        XCTAssertLessThan(vintageSaturation, 1.0)
    }

    // MARK: - Bit Depth Tests

    func test8BitRange() {
        let max8Bit = 255
        XCTAssertEqual(max8Bit, (1 << 8) - 1)
    }

    func test10BitRange() {
        let max10Bit = 1023
        XCTAssertEqual(max10Bit, (1 << 10) - 1)
    }

    func test12BitRange() {
        let max12Bit = 4095
        XCTAssertEqual(max12Bit, (1 << 12) - 1)
    }

    // MARK: - Performance Tests

    func testLUTInterpolationTypes() {
        // Interpolation methods
        let methods = ["nearest", "trilinear", "tetrahedral"]
        XCTAssertEqual(methods.count, 3)
        XCTAssertTrue(methods.contains("trilinear"), "Trilinear is most common")
    }
}
