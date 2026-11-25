import XCTest
@testable import EchoelCore

final class TempoHintTests: XCTestCase {
    func testABareNumberInTheNameIsItsTempo() {
        XCTAssertEqual(TempoHint.bpm(inName: "jungle 132 1"), 132)
        XCTAssertEqual(TempoHint.bpm(inName: "Amen_Break_136"), 136)
        XCTAssertEqual(TempoHint.bpm(inName: "pad 87.5"), 87.5)
    }

    func testANumberMarkedBPMWinsOverOtherNumbers() {
        XCTAssertEqual(TempoHint.bpm(inName: "break 2 174bpm"), 174)
        XCTAssertEqual(TempoHint.bpm(inName: "loop_90_BPM_take 120"), 90)
        XCTAssertEqual(TempoHint.bpm(inName: "BPM 240 drill"), 240)
    }

    func testANameWithoutAClearTempoStatesNone() {
        XCTAssertNil(TempoHint.bpm(inName: "kick"))
        XCTAssertNil(TempoHint.bpm(inName: "808 bass"))
        XCTAssertNil(TempoHint.bpm(inName: "take 2024"))
        XCTAssertNil(TempoHint.bpm(inName: "v120 mix"), "a number glued to a letter is not a tempo")
        XCTAssertNil(TempoHint.bpm(inName: "loop 100 120"), "two bare tempos are ambiguous")
    }

    func testTheNameDecidesTheOctaveOfWhatWasHeard() {
        XCTAssertEqual(TempoHint.resolve(name: "dnb 174", heard: 87), 174)
        XCTAssertEqual(TempoHint.resolve(name: "jungle 132", heard: 131.2), 132)
        XCTAssertEqual(TempoHint.resolve(name: "slow 70", heard: 140), 70)
    }

    func testWhatWasHeardWinsOverANameThatDisagrees() {
        XCTAssertEqual(TempoHint.resolve(name: "loop 100", heard: 128), 128)
    }

    func testTheNameAloneServesWhenNothingWasHeard() {
        XCTAssertEqual(TempoHint.resolve(name: "jungle 132", heard: nil), 132)
        XCTAssertNil(TempoHint.resolve(name: "kick", heard: nil))
        XCTAssertEqual(TempoHint.resolve(name: "kick", heard: 120), 120)
        XCTAssertEqual(TempoHint.resolve(name: "jungle 132", heard: .nan), 132)
    }
}
