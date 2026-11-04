import Foundation
import XCTest
@testable import EchoelDSP

final class TemperamentTests: XCTestCase {
    func testTheStandardIsTwelveEqualStepsAtA440() {
        XCTAssertEqual(Temperament.standard.frequency(of: 69), 440, accuracy: 1e-3)
        XCTAssertEqual(Temperament.standard.frequency(of: 60), 261.6256, accuracy: 1e-3)
        XCTAssertEqual(Temperament.standard.frequency(of: 81), 880, accuracy: 1e-2)
    }

    func testDamageIsSanitizedAndTheUnusedLanesStayZero() {
        var lanes = SIMD16<Float>(repeating: 5)
        lanes[0] = .nan
        lanes[1] = .infinity
        lanes[2] = -5_000
        let temperament = Temperament(cents: lanes)
        XCTAssertEqual(temperament.cents[0], 0)
        XCTAssertEqual(temperament.cents[1], 0)
        XCTAssertEqual(temperament.cents[2], -Temperament.limit)
        XCTAssertEqual(temperament.cents[3], 5)
        for lane in 12..<16 { XCTAssertEqual(temperament.cents[lane], 0) }
        XCTAssertTrue(temperament.frequency(of: 0).isFinite)
        XCTAssertTrue(temperament.frequency(of: 127).isFinite)
    }

    func testANegativePitchFindsItsClass() {
        var lanes = SIMD16<Float>.zero
        lanes[11] = 30
        XCTAssertEqual(Temperament(cents: lanes).cents(of: -1), 30)
    }
}
