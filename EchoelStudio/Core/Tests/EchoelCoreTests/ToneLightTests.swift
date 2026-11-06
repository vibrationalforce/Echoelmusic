import EchoelCore
import XCTest

/// A tone's light by octave transposition: the one colour rule every surface shares.
final class ToneLightTests: XCTestCase {
    private func distance(_ a: ToneLight.RGB, _ b: ToneLight.RGB) -> Double {
        Swift.max(Swift.abs(a.red - b.red), Swift.max(Swift.abs(a.green - b.green), Swift.abs(a.blue - b.blue)))
    }

    func testAnOctaveIsTheSameColour() {
        let a4 = ToneLight.colour(forToneHz: 440), a5 = ToneLight.colour(forToneHz: 880)
        let a2 = ToneLight.colour(forToneHz: 110)
        XCTAssertEqual(distance(a4, a5), 0, accuracy: 1e-9, "A4 and A5 are one light")
        XCTAssertEqual(distance(a4, a2), 0, accuracy: 1e-9, "and A2 too")
    }

    func testASemitoneMovesTheColour() {
        let a = ToneLight.colour(forToneHz: 440)
        let aSharp = ToneLight.colour(forToneHz: 440 * Foundation.pow(2, 1.0 / 12))
        XCTAssertGreaterThan(distance(a, aSharp), 0.05, "the next pitch class is another colour")
        let twelve = (0..<12).map { (step: Int) -> ToneLight.RGB in
            ToneLight.colour(forToneHz: 261.63 * Foundation.pow(2, Double(step) / 12))
        }
        for index in 0..<12 {
            XCTAssertGreaterThan(distance(twelve[index], twelve[(index + 1) % 12]), 0.01, "step \(index)")
        }
    }

    func testA440IsTakenUpFortyOctavesToOrangeRedLight() throws {
        XCTAssertEqual(ToneLight.octaves(forToneHz: 440), 40)
        let light = try XCTUnwrap(ToneLight.lightHertz(forToneHz: 440))
        XCTAssertEqual(light / 1e12, 483.8, accuracy: 0.1, "440 Hz × 2⁴⁰ ≈ 484 THz")
        XCTAssertTrue((400e12...790e12).contains(light), "inside the visible band")
        let nanometres = try XCTUnwrap(ToneLight.wavelength(forToneHz: 440))
        XCTAssertEqual(nanometres, 619.7, accuracy: 0.1, "c / 484 THz ≈ 620 nm")
        XCTAssertEqual(ToneLight.wavelength(forToneHz: 880) ?? 0, nanometres, accuracy: 1e-6, "one octave higher, one octave fewer")
        XCTAssertEqual(ToneLight.octaves(forToneHz: 880), 39)
    }

    func testEveryToneLandsInTheLightOctave() throws {
        for step in 0..<240 {
            let hertz = 20 * Foundation.pow(2, Double(step) / 24)
            let nanometres = try XCTUnwrap(ToneLight.wavelength(forToneHz: hertz))
            XCTAssertGreaterThanOrEqual(nanometres, 389.9, "\(hertz) Hz")
            XCTAssertLessThanOrEqual(nanometres, 780.0 + 1e-6, "\(hertz) Hz")
        }
    }

    func testTheCircleIsContinuousAcrossThePurpleSeamAndNeverBlack() {
        var previous: ToneLight.RGB?
        for step in 0...4_000 {
            let hertz = 261.63 * Foundation.pow(2, Double(step) / 4_000)
            let colour = ToneLight.colour(forToneHz: hertz)
            XCTAssertGreaterThan(colour.peak, 0.5, "no pitch is dark: \(hertz) Hz")
            if let previous {
                XCTAssertLessThan(distance(previous, colour), 0.02, "no jump at \(hertz) Hz")
            }
            previous = colour
        }
    }

    func testTheSeamMeetsTheSpectrumAtBothEdges() {
        let red = ToneLight.spectrum(nanometres: ToneLight.redEdgeNanometres)
        let violet = ToneLight.spectrum(nanometres: ToneLight.violetEdgeNanometres)
        // The tones whose light is exactly the edge wavelengths.
        let atRed = ToneLight.speedOfLightNanometresPerSecond / ToneLight.redEdgeNanometres / Foundation.pow(2, 40)
        let atViolet = ToneLight.speedOfLightNanometresPerSecond / ToneLight.violetEdgeNanometres / Foundation.pow(2, 41)
        XCTAssertEqual(distance(ToneLight.colour(forToneHz: atRed), red), 0, accuracy: 1e-6)
        XCTAssertEqual(distance(ToneLight.colour(forToneHz: atViolet), violet), 0, accuracy: 1e-6)
    }

    func testAnInvalidToneIsNeutral() {
        for bad in [Double.nan, 0, -440, .infinity, -.infinity] {
            XCTAssertEqual(ToneLight.colour(forToneHz: bad), ToneLight.neutral, "\(bad)")
            XCTAssertNil(ToneLight.octaves(forToneHz: bad))
            XCTAssertNil(ToneLight.wavelength(forToneHz: bad))
        }
        XCTAssertGreaterThan(ToneLight.neutral.peak, 0, "neutral is a grey, not black")
        XCTAssertEqual(ToneLight.neutral.red, ToneLight.neutral.green)
        XCTAssertEqual(ToneLight.neutral.green, ToneLight.neutral.blue)
    }

    /// The shader is compiled from text at runtime: its numbers are tokens written from these
    /// constants. Read each token back as a number and compare it with the constant, at the
    /// precision the GPU keeps (float).
    func testTheShaderTokensCarryTheSwiftConstants() throws {
        XCTAssertEqual(try XCTUnwrap(Double(ToneLight.speedOfLightLiteral)), ToneLight.speedOfLightNanometresPerSecond)
        XCTAssertEqual(try XCTUnwrap(Double(ToneLight.anchorLiteral)), ToneLight.anchorNanometres)
        XCTAssertEqual(try XCTUnwrap(Double(ToneLight.redEdgeNanometresLiteral)), ToneLight.redEdgeNanometres)
        XCTAssertEqual(try XCTUnwrap(Double(ToneLight.violetEdgeNanometresLiteral)), ToneLight.violetEdgeNanometres)
        XCTAssertEqual(Float(try XCTUnwrap(Double(ToneLight.redEdgeLiteral))), Float(ToneLight.redEdge))
        XCTAssertEqual(Float(try XCTUnwrap(Double(ToneLight.violetEdgeLiteral))), Float(ToneLight.violetEdge))
        XCTAssertEqual(ToneLight.redEdge, Foundation.log2(780.0 / 640.0), accuracy: 1e-15)
        XCTAssertEqual(ToneLight.violetEdge, Foundation.log2(780.0 / 420.0), accuracy: 1e-15)
    }

    func testAColourHoldsItsChannelsToUnit() {
        XCTAssertEqual(ToneLight.RGB(red: 2, green: -1, blue: .nan), ToneLight.RGB(red: 1, green: 0, blue: 0))
        XCTAssertEqual(ToneLight.RGB(grey: 0.5).scaled(by: 0.5), ToneLight.RGB(grey: 0.25))
        XCTAssertEqual(ToneLight.RGB(grey: 0.5).scaled(by: .nan), ToneLight.RGB(grey: 0))
    }
}
