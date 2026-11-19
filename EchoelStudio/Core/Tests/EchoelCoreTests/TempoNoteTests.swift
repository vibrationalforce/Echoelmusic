import Foundation
import XCTest
@testable import EchoelCore

final class TempoNoteTests: XCTestCase {
    func testADelayTimeIsNamedByItsNoteValue() {
        XCTAssertEqual(TempoNote.division(forSeconds: 0.375, bpm: 120)?.name, "1/8 dotted")
        XCTAssertEqual(TempoNote.division(forSeconds: 0.5, bpm: 120)?.name, "1/4")
        XCTAssertEqual(TempoNote.division(forSeconds: 0.25 * 2 / 3, bpm: 120)?.name, "1/8 triplet")
        XCTAssertNil(TempoNote.division(forSeconds: 0.4, bpm: 120), "400 ms at 120 is no note value")
    }

    func testARateIsNamedByTheNoteOneCycleLasts() {
        XCTAssertEqual(TempoNote.division(forHertz: 4, bpm: 120)?.name, "1/8")
        XCTAssertEqual(TempoNote.division(forHertz: 2, bpm: 120)?.name, "1/4")
        XCTAssertEqual(TempoNote.division(forHertz: 0.5, bpm: 120)?.name, "1/1")
    }

    func testWithinOnePercentOnly() {
        XCTAssertEqual(TempoNote.division(forSeconds: 0.5 * 1.009, bpm: 120)?.name, "1/4")
        XCTAssertNil(TempoNote.division(forSeconds: 0.5 * 1.02, bpm: 120))
    }

    func testNothingIsNamedWithoutATempoOrAValue() {
        XCTAssertNil(TempoNote.division(forSeconds: 0.5, bpm: 0))
        XCTAssertNil(TempoNote.division(forSeconds: .nan, bpm: 120))
        XCTAssertNil(TempoNote.division(forHertz: 0, bpm: 120))
        XCTAssertEqual(TempoNote.seconds(of: TempoNote.divisions[0], bpm: 120), 2, "a whole note at 120 is two seconds")
        XCTAssertEqual(TempoNote.seconds(of: TempoNote.divisions[0], bpm: .infinity), 0)
    }
}
