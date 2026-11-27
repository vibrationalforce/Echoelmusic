import Foundation
import XCTest
@testable import EchoelCore

final class ExactTextTests: XCTestCase {
    private let bar = ExactText.repeatMark

    func testARepeatingGroupCarriesABarAndNothingIsRounded() {
        let triplet = ExactText(Rational.constant(8, 15), marks: .comma)
        XCTAssertEqual(triplet.full, "0,53\(bar)")
        XCTAssertEqual(triplet.compact, triplet.full, "short enough to show whole")
        XCTAssertFalse(triplet.isShortened)
        XCTAssertEqual(ExactText(Rational.constant(20, 11), marks: .point).full, "1.8\(bar)1\(bar)")
        XCTAssertEqual(ExactText(Rational.constant(8, 5), marks: .comma).full, "1,6")
        XCTAssertEqual(ExactText(70_560, marks: .comma).full, "70560", "no thousands mark, as on every screen")
    }

    func testACompactValueSaysItLeftDigitsOut() {
        let tempo = ExactText(Rational.constant(40_000, 303), marks: .comma)
        XCTAssertEqual(tempo.full, "132,0\(bar)1\(bar)3\(bar)2\(bar)")
        XCTAssertEqual(tempo.compact, "132,013…", "six significant digits, then the mark")
        XCTAssertTrue(tempo.isShortened)
        let samples = ExactText(Rational.constant(882_000, 11), marks: .comma)
        XCTAssertEqual(samples.full, "80181,8\(bar)1\(bar)")
        XCTAssertEqual(samples.compact, "80181,8…", "the whole part is never cut")
        let small = ExactText(Rational.constant(1, 48), marks: .comma, compactDigits: 3)
        XCTAssertEqual(small.full, "0,02083\(bar)")
        XCTAssertEqual(small.compact, "0,0208…", "zeros right after the point do not count as digits")
    }

    func testVoiceOverHearsWhichDigitsRepeat() {
        XCTAssertEqual(ExactText(Rational.constant(8, 15), marks: .point).spoken, "0.53, the last digit repeating")
        XCTAssertEqual(ExactText(Rational.constant(20, 11), marks: .point).spoken, "1.81, the last 2 digits repeating")
        XCTAssertEqual(ExactText(Rational.constant(-1, 4), marks: .point).spoken, "minus 0.25")
        XCTAssertEqual(ExactText(Rational.constant(-1, 4), marks: .point).full, "\u{2212}0.25")
    }

    func testAValueWhoseDigitsGoOnEndsInTheMark() {
        let pitch = ExactText(approximately: 261.6255653005986, marks: .point)
        XCTAssertEqual(pitch.full, "261.6255653005986…", "every digit the Double holds, then the mark")
        XCTAssertEqual(pitch.compact, "261.625…")
        XCTAssertTrue(pitch.spoken.hasSuffix(", continuing"))
        XCTAssertEqual(ExactText(approximately: .nan, marks: .point).full, "–")
    }

    func testAStoredValueTooLongForARatioReadsAsTheDigitsItPrints() {
        let attack = ExactText(printed: 0.0012345678901234567, marks: .point)
        XCTAssertEqual(attack.full, "0.0012345678901234567")
        XCTAssertEqual(attack.compact, "0.00123456…")
        XCTAssertEqual(ExactText(printed: 1e16, marks: .point).full, "10000000000000000")
        XCTAssertEqual(ExactText(printed: -2.5e-7, marks: .comma).full, "\u{2212}0,00000025")
        XCTAssertEqual(ExactText(printed: .infinity, marks: .point).full, "–")
    }

    func testARepeatingGroupLongerThanTheLimitCarriesItsFraction() {
        let bar = ExactText(Rational.constant(1_600, 823), marks: .comma)
        XCTAssertTrue(bar.full.hasSuffix("… = 1600/823"), bar.full)
        XCTAssertEqual(bar.compact, "1,94410…")
        XCTAssertEqual(bar.spoken, "exactly 1600 over 823")
    }

    func testTimesAndRatesTakeTheUnitThatReadsBest() {
        let triplet = ExactUnits.time(Rational.constant(8, 15), marks: .comma)
        XCTAssertEqual(triplet.text.full, "533,3\(bar)")
        XCTAssertEqual(triplet.unit, "ms")
        let bar = ExactUnits.time(Rational.constant(8, 5), marks: .comma)
        XCTAssertEqual(bar.text.full, "1,6")
        XCTAssertEqual(bar.unit, "s")
        let rate = ExactUnits.rate(Rational.constant(15, 8), marks: .comma)
        XCTAssertEqual(rate.text.full, "1,875")
        XCTAssertEqual(rate.unit, "Hz")
        let cutoff = ExactUnits.rate(2_500, marks: .comma)
        XCTAssertEqual(cutoff.text.full, "2,5")
        XCTAssertEqual(cutoff.unit, "kHz")
    }

    func testTheMarksFollowTheRegion() {
        XCTAssertEqual(NumberMarks(locale: Locale(identifier: "de_DE")).decimal, ",")
        XCTAssertEqual(NumberMarks(locale: Locale(identifier: "en_US")).decimal, ".")
    }
}
