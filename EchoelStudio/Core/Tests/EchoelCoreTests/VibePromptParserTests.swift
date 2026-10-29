import XCTest
@testable import EchoelCore

/// The parser is local, keyword-based and deterministic (wave W11.1b). Unknown words are
/// ignored, missing fields fall back to the genre's house values, no genre at all returns `nil`.
final class VibePromptParserTests: XCTestCase {

    func testAFullPromptMapsEachField() {
        let p = VibePromptParser.parse("fast dark trap, 140 bpm, Cm")
        XCTAssertNotNil(p)
        XCTAssertEqual(p?.genre, .hipHop)
        XCTAssertEqual(p?.targetBPM, 140)
        XCTAssertEqual(p?.targetKeyRoot, 0)
        XCTAssertEqual(p?.targetScale, .minor)
        XCTAssertLessThan(p?.brightness ?? 1, 0.3)
    }

    func testMissingFieldsFallBackToGenreHouseValues() {
        let p = VibePromptParser.parse("chill")
        XCTAssertNotNil(p)
        XCTAssertEqual(p?.genre, .chill)
        XCTAssertEqual(p?.targetBPM, 72)
        XCTAssertEqual(p?.targetScale, .minorPentatonic)
    }

    func testPromptWithoutGenreReturnsNil() {
        XCTAssertNil(VibePromptParser.parse("fast dark 140 bpm"))
    }

    func testEnergyAndDensityKeywordsAreRecognised() {
        let p = VibePromptParser.parse("minimal mellow score")
        XCTAssertEqual(p?.genre, .score)
        XCTAssertLessThan(p?.density ?? 1, 0.3)
        XCTAssertLessThan(p?.energy ?? 1, 0.4)
    }

    func testSameInputProducesSameOutput() {
        let a = VibePromptParser.parse("uplifting house 128 bpm")
        let b = VibePromptParser.parse("uplifting house 128 bpm")
        XCTAssertEqual(a, b)
    }

    func testCaseAndPunctuationAreIgnored() {
        let a = VibePromptParser.parse("TECHNO, 128 BPM!")
        let b = VibePromptParser.parse("techno 128 bpm")
        XCTAssertEqual(a?.genre, b?.genre)
        XCTAssertEqual(a?.targetBPM, b?.targetBPM)
    }

    func testPitchClassAcceptsSharpAndFlat() {
        XCTAssertEqual(VibePromptParser.pitchClass(from: "c#"), 1)
        XCTAssertEqual(VibePromptParser.pitchClass(from: "db"), 1)
        XCTAssertEqual(VibePromptParser.pitchClass(from: "f"), 5)
        XCTAssertEqual(VibePromptParser.pitchClass(from: "x"), nil)
    }
}
