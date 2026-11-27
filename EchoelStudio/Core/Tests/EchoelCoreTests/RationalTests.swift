import Foundation
import XCTest
@testable import EchoelCore

final class RationalTests: XCTestCase {
    func testARatioIsKeptInLowestTermsWithAPositiveDenominator() {
        let ratio = Rational(numerator: 6, denominator: -4)
        XCTAssertEqual(ratio?.numerator, -3)
        XCTAssertEqual(ratio?.denominator, 2)
        XCTAssertEqual(Rational(numerator: 0, denominator: 7), .zero)
        XCTAssertNil(Rational(numerator: 1, denominator: 0), "no ratio has a zero denominator")
        XCTAssertNil(Rational(numerator: .min, denominator: 1))
    }

    func testADecimalIsReadExactly() {
        XCTAssertEqual(Rational(decimal: "132.1"), Rational(numerator: 1321, denominator: 10))
        XCTAssertEqual(Rational(decimal: "-0.25"), Rational(numerator: -1, denominator: 4))
        XCTAssertEqual(Rational(decimal: "1e-05"), Rational(numerator: 1, denominator: 100_000))
        XCTAssertEqual(Rational(decimal: "4.4E+4"), 44_000)
        XCTAssertEqual(Rational(decimal: "120"), 120)
        XCTAssertEqual(Rational(decimal: ".5"), Rational(numerator: 1, denominator: 2))
        for nonsense in ["", ".", "1.2.3", "abc", "1,5", "--1", "1e", "١٢"] {
            XCTAssertNil(Rational(decimal: nonsense), nonsense)
        }
        XCTAssertNil(Rational(decimal: "99999999999999999999"), "more digits than Int64 holds")
    }

    func testADoubleIsTheDecimalItPrints() {
        XCTAssertEqual(Rational(roundTripping: 0.1), Rational(numerator: 1, denominator: 10),
                       "the typed decimal, not the binary fraction nearest to it")
        XCTAssertEqual(Rational(roundTripping: 132.1), Rational(numerator: 1321, denominator: 10))
        XCTAssertEqual(Rational(roundTripping: 44_100), 44_100)
        XCTAssertEqual(Rational(roundTripping: 1e16), 10_000_000_000_000_000)
        XCTAssertEqual(Rational(roundTripping: -0.0), .zero)
        XCTAssertNil(Rational(roundTripping: .nan))
        XCTAssertNil(Rational(roundTripping: .infinity))
        XCTAssertNil(Rational(roundTripping: 1e300))
    }

    func testAStoredDoubleReadsAsTheRatioItStandsFor() {
        XCTAssertEqual(Rational(stored: 1.0 / 6), Rational.constant(1, 6), "166,6̅ ms, not 166,66666666666666 ms")
        XCTAssertEqual(Rational(stored: 60.0 / 132 * 4), Rational.constant(20, 11))
        XCTAssertEqual(Rational(stored: 0.3751), Rational.constant(3_751, 10_000))
        XCTAssertEqual(Rational(stored: 0.1), Rational.constant(1, 10))
        XCTAssertEqual(Rational(stored: -0.25), Rational.constant(-1, 4))
        XCTAssertEqual(Rational(stored: 30_000.0 / 1_001), Rational.constant(30_000, 1_001))
        XCTAssertEqual(Rational(stored: 0), .zero)
        XCTAssertEqual(Rational(stored: Double.pi), Rational(decimal: "3.141592653589793"),
                       "no small ratio holds pi, so it reads as the decimal it prints")
        XCTAssertNil(Rational(stored: .nan))
    }

    func testALargeValueIsNeverReadAsAFractionItDoesNotHold() {
        XCTAssertEqual(Rational(stored: 8_000.123456789), Rational(decimal: "8000.123456789"),
                       "a random cutoff reads as the decimal it prints, not as a 7-digit fraction")
        XCTAssertEqual(Rational(stored: 1_600.0 / 823), Rational.constant(1_600, 823), "a bar at 123,45 BPM")
        XCTAssertEqual(Rational(stored: 70_560_000.0 / 883), Rational.constant(70_560_000, 883), "its samples")
        XCTAssertEqual(Rational(stored: 40_000.0 / 303), Rational.constant(40_000, 303))
    }

    func testArithmeticIsExactOrNothing() {
        let third = Rational.constant(1, 3)
        let sixth = Rational.constant(1, 6)
        XCTAssertEqual(third.adding(sixth), Rational.constant(1, 2))
        XCTAssertEqual(third.subtracting(sixth), sixth)
        XCTAssertEqual(third.multiplied(by: 3), .one)
        XCTAssertEqual(third.divided(by: sixth), 2)
        XCTAssertNil(third.divided(by: .zero), "no division by zero")
        XCTAssertNil(Rational.zero.reciprocal)
        let large = Rational(integerLiteral: Int64.max)
        XCTAssertNil(large.multiplied(by: 2), "an overflow is nil, never a wrong value")
        XCTAssertNil(large.adding(large))
        XCTAssertEqual(large.multiplied(by: Rational.constant(1, 2))?.denominator, 2,
                       "cross-reducing keeps large values in range")
    }

    func testOrderIsExactEvenForLargeRatios() {
        XCTAssertLessThan(Rational.constant(1, 3), Rational.constant(1, 2))
        XCTAssertLessThan(Rational.constant(-1, 2), Rational.constant(1, 3))
        let larger = Rational.constant(Int64.max - 1, Int64.max)
        let smaller = Rational.constant(Int64.max - 2, Int64.max - 1)
        XCTAssertLessThan(smaller, larger, "both cross products overflow Int64; they are compared at 128 bits")
        XCTAssertFalse(larger < smaller)
        XCTAssertLessThan(larger, .one)
    }

    func testLongDivisionFindsTheRepeatingGroup() {
        let triplet = Rational.constant(8, 15).decimalDigits()
        XCTAssertEqual([triplet.whole, triplet.fixed, triplet.repeating], ["0", "5", "3"])
        let bar = Rational.constant(20, 11).decimalDigits()
        XCTAssertEqual([bar.whole, bar.fixed, bar.repeating], ["1", "", "81"])
        let tempo = Rational.constant(40_000, 303).decimalDigits()
        XCTAssertEqual([tempo.whole, tempo.fixed, tempo.repeating], ["132", "", "0132"])
        let seventh = Rational.constant(1, 7).decimalDigits()
        XCTAssertEqual([seventh.whole, seventh.fixed, seventh.repeating], ["0", "", "142857"])
        let sixtyFourthTriplet = Rational.constant(1, 48).decimalDigits()
        XCTAssertEqual([sixtyFourthTriplet.fixed, sixtyFourthTriplet.repeating], ["0208", "3"])
        let ends = Rational.constant(8, 5).decimalDigits()
        XCTAssertEqual([ends.whole, ends.fixed, ends.repeating], ["1", "6", ""])
        XCTAssertTrue(ends.isComplete)
        XCTAssertEqual(Rational.constant(-1, 4).decimalDigits().repeating, "")
        XCTAssertTrue(Rational.constant(-1, 4).decimalDigits().isNegative)
    }

    func testAGroupLongerThanTheLimitIsMarkedIncomplete() {
        let digits = Rational.constant(1, 97).decimalDigits(limit: 10)
        XCTAssertFalse(digits.isComplete)
        XCTAssertEqual(digits.fixed, "0103092783")
        XCTAssertEqual(digits.repeating, "")
        let whole = Rational.constant(1, 97).decimalDigits()
        XCTAssertFalse(whole.isComplete, "1/97 repeats after 96 digits, past the default limit of 64")
        XCTAssertTrue(Rational.constant(1, 97).decimalDigits(limit: 96).isComplete)
        XCTAssertEqual(Rational.constant(1, 97).decimalDigits(limit: 96).repeating.count, 96)
    }

    /// Input no caller sends today must still refuse instead of trapping: an exponent beyond any
    /// finite number's, and the largest denominator bound there is.
    func testAbsurdInputIsRefusedAndNeverTraps() {
        XCTAssertNil(Rational(decimal: "1e-9223372036854775808"))
        XCTAssertNil(Rational(decimal: "1e9223372036854775807"))
        XCTAssertNil(Rational(decimal: "1e401"))
        XCTAssertEqual(Rational(stored: 0, maxDenominator: .max), Rational(numerator: 0, denominator: 1))
        XCTAssertEqual(Rational(stored: 0.5, maxDenominator: .max), Rational(numerator: 1, denominator: 2))
    }
}
