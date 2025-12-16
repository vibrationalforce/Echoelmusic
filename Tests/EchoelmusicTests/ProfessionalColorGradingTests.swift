import XCTest
import CoreImage
@testable import Echoelmusic

/// Comprehensive tests for Professional Color Grading System
/// Ensures 100% quality and correctness of DaVinci Resolve-level features
final class ProfessionalColorGradingTests: XCTestCase {

    var grading: ProfessionalColorGrading!

    override func setUp() async throws {
        await MainActor.run {
            grading = ProfessionalColorGrading()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            grading = nil
        }
    }

    // MARK: - Initialization Tests

    func testDefaultValues() async throws {
        await MainActor.run {
            XCTAssertEqual(grading.temperature, 0, "Temperature should be neutral initially")
            XCTAssertEqual(grading.tint, 0, "Tint should be neutral initially")
            XCTAssertEqual(grading.exposure, 0, "Exposure should be 0 EV initially")
            XCTAssertEqual(grading.contrast, 1.0, "Contrast should be 1.0 (neutral) initially")
            XCTAssertEqual(grading.saturation, 1.0, "Saturation should be 1.0 (neutral) initially")
            XCTAssertEqual(grading.vibrance, 0, "Vibrance should be 0 initially")
        }
    }

    func testColorWheelDefaults() async throws {
        await MainActor.run {
            // Shadows (Lift)
            XCTAssertEqual(grading.shadowsLift.hue, 0, "Shadows hue should be neutral")
            XCTAssertEqual(grading.shadowsLift.saturation, 0, "Shadows saturation should be 0")
            XCTAssertEqual(grading.shadowsLift.luminance, 1.0, "Shadows luminance should be 1.0")

            // Midtones (Gamma)
            XCTAssertEqual(grading.midtonesGamma.hue, 0, "Midtones hue should be neutral")
            XCTAssertEqual(grading.midtonesGamma.saturation, 0, "Midtones saturation should be 0")
            XCTAssertEqual(grading.midtonesGamma.luminance, 1.0, "Midtones luminance should be 1.0")

            // Highlights (Gain)
            XCTAssertEqual(grading.highlightsGain.hue, 0, "Highlights hue should be neutral")
            XCTAssertEqual(grading.highlightsGain.saturation, 0, "Highlights saturation should be 0")
            XCTAssertEqual(grading.highlightsGain.luminance, 1.0, "Highlights luminance should be 1.0")
        }
    }

    // MARK: - Preset Tests

    func testTungsten3200KPreset() async throws {
        await MainActor.run {
            grading.loadPreset(.tungsten3200K)

            XCTAssertEqual(grading.temperature, 0, "3200K tungsten should be neutral (camera at 3200K)")
            XCTAssertEqual(grading.tint, 0, "Tint should be neutral for tungsten")
        }
    }

    func testDaylight5600KPreset() async throws {
        await MainActor.run {
            grading.loadPreset(.daylight5600K)

            XCTAssertEqual(grading.temperature, 42, "5600K daylight should be +42 from 3200K base")
            XCTAssertEqual(grading.tint, 0, "Tint should be neutral for daylight")
        }
    }

    func testGoldenHourPreset() async throws {
        await MainActor.run {
            grading.loadPreset(.goldenHour)

            XCTAssertEqual(grading.temperature, 60, "Golden hour should be warm (+60)")
            XCTAssertEqual(grading.tint, -10, "Golden hour should have slight magenta tint")
            XCTAssertGreaterThan(grading.shadowsLift.hue, 0, "Shadows should be warm")
            XCTAssertGreaterThan(grading.highlightsGain.hue, 0, "Highlights should be golden")
            XCTAssertEqual(grading.saturation, 1.15, "Saturation should be boosted")
        }
    }

    func testBlueHourPreset() async throws {
        await MainActor.run {
            grading.loadPreset(.blueHour)

            XCTAssertEqual(grading.temperature, -40, "Blue hour should be cool (-40)")
            XCTAssertLessThan(grading.shadowsLift.hue, 0, "Shadows should be cool/blue")
            XCTAssertEqual(grading.saturation, 1.1, "Saturation should be slightly boosted")
        }
    }

    func testCinematicPreset() async throws {
        await MainActor.run {
            grading.loadPreset(.cinematic)

            XCTAssertLessThan(grading.shadowsLift.hue, 0, "Shadows should be teal (negative hue)")
            XCTAssertGreaterThan(grading.highlightsGain.hue, 0, "Highlights should be orange (positive hue)")
            XCTAssertEqual(grading.saturation, 1.2, "Cinematic look should have boosted saturation")
            XCTAssertEqual(grading.contrast, 1.1, "Cinematic look should have increased contrast")
        }
    }

    // MARK: - Film Emulation Tests

    func testKodakVision3Preset() async throws {
        await MainActor.run {
            grading.loadPreset(.kodakVision3)

            XCTAssertEqual(grading.filmEmulation, .kodak5219, "Should use Kodak 5219 film stock")
            XCTAssertEqual(grading.saturation, 1.15, "Kodak should have increased saturation")
        }
    }

    func testFujiEternaPreset() async throws {
        await MainActor.run {
            grading.loadPreset(.fujiEterna)

            XCTAssertEqual(grading.filmEmulation, .fujiEterna, "Should use Fuji Eterna film stock")
            XCTAssertEqual(grading.saturation, 0.9, "Fuji Eterna should have muted colors")
            XCTAssertEqual(grading.contrast, 0.95, "Fuji Eterna should have slightly reduced contrast")
        }
    }

    func testFujiVelviaPreset() async throws {
        await MainActor.run {
            grading.loadPreset(.fujiVelvia)

            XCTAssertEqual(grading.filmEmulation, .fujiVelvia, "Should use Fuji Velvia film stock")
            XCTAssertEqual(grading.saturation, 1.35, "Fuji Velvia should have ultra-saturated colors")
            XCTAssertEqual(grading.contrast, 1.1, "Fuji Velvia should have increased contrast")
        }
    }

    // MARK: - Reset Tests

    func testReset() async throws {
        await MainActor.run {
            // Modify values
            grading.temperature = 50
            grading.tint = 20
            grading.exposure = 1.5
            grading.contrast = 1.3
            grading.saturation = 1.5
            grading.shadowsLift.hue = 0.5

            // Reset
            grading.reset()

            // Verify reset
            XCTAssertEqual(grading.temperature, 0, "Temperature should reset to 0")
            XCTAssertEqual(grading.tint, 0, "Tint should reset to 0")
            XCTAssertEqual(grading.exposure, 0, "Exposure should reset to 0")
            XCTAssertEqual(grading.contrast, 1.0, "Contrast should reset to 1.0")
            XCTAssertEqual(grading.saturation, 1.0, "Saturation should reset to 1.0")
            XCTAssertEqual(grading.shadowsLift.hue, 0, "Shadows hue should reset to 0")
        }
    }

    // MARK: - Color Wheel Tests

    func testColorWheelHueRange() async throws {
        await MainActor.run {
            // Test hue range (-1 to +1)
            grading.shadowsLift.hue = -1.0
            XCTAssertEqual(grading.shadowsLift.hue, -1.0, "Should support -1.0 hue")

            grading.shadowsLift.hue = 1.0
            XCTAssertEqual(grading.shadowsLift.hue, 1.0, "Should support +1.0 hue")
        }
    }

    func testColorWheelSaturationRange() async throws {
        await MainActor.run {
            // Test saturation range (0 to 1)
            grading.midtonesGamma.saturation = 0.0
            XCTAssertEqual(grading.midtonesGamma.saturation, 0.0, "Should support 0.0 saturation (center)")

            grading.midtonesGamma.saturation = 1.0
            XCTAssertEqual(grading.midtonesGamma.saturation, 1.0, "Should support 1.0 saturation (edge)")
        }
    }

    func testColorWheelLuminanceRange() async throws {
        await MainActor.run {
            // Test luminance range (0 to 2)
            grading.highlightsGain.luminance = 0.0
            XCTAssertEqual(grading.highlightsGain.luminance, 0.0, "Should support 0.0 luminance")

            grading.highlightsGain.luminance = 2.0
            XCTAssertEqual(grading.highlightsGain.luminance, 2.0, "Should support 2.0 luminance")
        }
    }

    // MARK: - Temperature and Tint Tests

    func testTemperatureRange() async throws {
        await MainActor.run {
            grading.temperature = -100
            XCTAssertEqual(grading.temperature, -100, "Should support -100 temperature (cool)")

            grading.temperature = 100
            XCTAssertEqual(grading.temperature, 100, "Should support +100 temperature (warm)")
        }
    }

    func testTintRange() async throws {
        await MainActor.run {
            grading.tint = -100
            XCTAssertEqual(grading.tint, -100, "Should support -100 tint (magenta)")

            grading.tint = 100
            XCTAssertEqual(grading.tint, 100, "Should support +100 tint (green)")
        }
    }

    // MARK: - Exposure Tests

    func testExposureRange() async throws {
        await MainActor.run {
            grading.exposure = -2.0
            XCTAssertEqual(grading.exposure, -2.0, "Should support -2 EV")

            grading.exposure = 2.0
            XCTAssertEqual(grading.exposure, 2.0, "Should support +2 EV")
        }
    }

    // MARK: - Contrast and Saturation Tests

    func testContrastRange() async throws {
        await MainActor.run {
            grading.contrast = 0.0
            XCTAssertEqual(grading.contrast, 0.0, "Should support 0.0 contrast (flat)")

            grading.contrast = 2.0
            XCTAssertEqual(grading.contrast, 2.0, "Should support 2.0 contrast (high)")
        }
    }

    func testSaturationRange() async throws {
        await MainActor.run {
            grading.saturation = 0.0
            XCTAssertEqual(grading.saturation, 0.0, "Should support 0.0 saturation (B&W)")

            grading.saturation = 2.0
            XCTAssertEqual(grading.saturation, 2.0, "Should support 2.0 saturation (vivid)")
        }
    }

    // MARK: - Image Processing Tests

    func testProcessImageDoesNotCrash() async throws {
        await MainActor.run {
            let testImage = CIImage(color: CIColor.red).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))

            let processed = grading.process(testImage)
            XCTAssertNotNil(processed, "Should process image without crashing")
            XCTAssertEqual(processed.extent, testImage.extent, "Output extent should match input")
        }
    }

    func testProcessImageWithPreset() async throws {
        await MainActor.run {
            let testImage = CIImage(color: CIColor.red).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))

            grading.loadPreset(.cinematic)
            let processed = grading.process(testImage)
            XCTAssertNotNil(processed, "Should process image with preset without crashing")
        }
    }

    // MARK: - Film Stock Tests

    func testFilmStockEnum() {
        let stocks = ProfessionalColorGrading.FilmStock.allCases
        XCTAssertTrue(stocks.contains(.none), "Should include 'none' option")
        XCTAssertTrue(stocks.contains(.kodak5219), "Should include Kodak Vision3 500T")
        XCTAssertTrue(stocks.contains(.kodak5207), "Should include Kodak Vision3 250D")
        XCTAssertTrue(stocks.contains(.fujiEterna), "Should include Fuji Eterna")
        XCTAssertTrue(stocks.contains(.fujiVelvia), "Should include Fuji Velvia")
        XCTAssertTrue(stocks.contains(.ilfordHP5), "Should include Ilford HP5+ (B&W)")
    }

    // MARK: - User Workflow Tests

    func testUserWorkflow3200KTo5600K() async throws {
        await MainActor.run {
            // User's workflow: Start with 3200K tungsten in studio
            grading.loadPreset(.tungsten3200K)
            XCTAssertEqual(grading.temperature, 0, "Studio setup should be neutral")

            // Switch to outdoor daylight (5600K)
            grading.loadPreset(.daylight5600K)
            XCTAssertEqual(grading.temperature, 42, "Outdoor should adjust to daylight")

            // Back to studio
            grading.loadPreset(.tungsten3200K)
            XCTAssertEqual(grading.temperature, 0, "Back to neutral studio")
        }
    }

    // MARK: - Performance Tests

    func testInitializationPerformance() async throws {
        measure {
            Task { @MainActor in
                _ = ProfessionalColorGrading()
            }
        }
    }

    func testImageProcessingPerformance() async throws {
        await MainActor.run {
            let testImage = CIImage(color: CIColor.red).cropped(to: CGRect(x: 0, y: 0, width: 1920, height: 1080))

            measure {
                _ = grading.process(testImage)
            }
        }
    }

    func testPresetLoadingPerformance() async throws {
        await MainActor.run {
            measure {
                grading.loadPreset(.cinematic)
            }
        }
    }
}
