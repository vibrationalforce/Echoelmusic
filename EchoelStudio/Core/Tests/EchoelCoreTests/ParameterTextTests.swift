import Foundation
import XCTest
@testable import EchoelCore

final class ParameterTextTests: XCTestCase {
    private let bar = ExactText.repeatMark

    func testAValueReadsExactlyInTheUnitThatReadsBest() {
        XCTAssertEqual(ParameterText.value(0.375, unit: .seconds, marks: .comma)?.compact, "375 ms")
        XCTAssertEqual(ParameterText.value(1.0 / 6, unit: .seconds, marks: .comma)?.full, "166,6\(bar) ms",
                       "a sixth of a second reads as the ratio it is")
        XCTAssertEqual(ParameterText.value(2.5, unit: .seconds, marks: .comma)?.full, "2,5 s")
        XCTAssertEqual(ParameterText.value(2_500, unit: .hertz, marks: .comma)?.full, "2,5 kHz")
        XCTAssertEqual(ParameterText.value(0.25, unit: .hertz, marks: .point)?.full, "0.25 Hz")
        XCTAssertEqual(ParameterText.value(-6, unit: .decibel, marks: .comma)?.full, "\u{2212}6 dB")
        XCTAssertEqual(ParameterText.value(132.5, unit: .bpm, marks: .comma)?.full, "132,5 BPM")
        XCTAssertNil(ParameterText.value(0.5, unit: .pan, marks: .comma))
        XCTAssertNil(ParameterText.value(2, unit: .choice, marks: .comma))
        XCTAssertNil(ParameterText.value(.nan, unit: .seconds, marks: .comma))
    }

    func testATimeAlsoReadsAsARateAndANoteValue() throws {
        let delay = ParameterText.companions(0.375, unit: .seconds, bpm: 120, marks: .comma)
        XCTAssertEqual(delay.other?.full, "2,6\(bar) Hz")
        XCTAssertEqual(delay.note?.name, "1/8 dotted")
        XCTAssertEqual(delay.note?.isExact, true)
        let triplet = ParameterText.companions(1.0 / 6, unit: .seconds, bpm: 120, marks: .comma)
        XCTAssertEqual(triplet.note?.name, "1/8 triplet", "a sixth of a second is an eighth triplet at 120, exactly")
        let near = ParameterText.companions(0.3334, unit: .seconds, bpm: 120, marks: .comma)
        XCTAssertEqual(near.note?.name, "≈ 1/4 triplet", "333,4 ms is near a quarter triplet, not on it")
        XCTAssertEqual(near.note?.isExact, false)
        XCTAssertNil(ParameterText.companions(0.4, unit: .seconds, bpm: 120, marks: .comma).note,
                     "400 ms at 120 is no note value")
    }

    func testASlowRateAlsoReadsAsATimeAndANoteValue() {
        let rate = ParameterText.companions(4, unit: .hertz, bpm: 120, marks: .comma)
        XCTAssertEqual(rate.other?.full, "250 ms")
        XCTAssertEqual(rate.note?.name, "1/8")
        let cutoff = ParameterText.companions(440, unit: .hertz, bpm: 120, marks: .comma)
        XCTAssertNil(cutoff.other, "a frequency above 40 Hz is a pitch, not a rhythm")
        XCTAssertNil(cutoff.note)
        XCTAssertNil(ParameterText.companions(0, unit: .seconds, bpm: 120, marks: .comma).other)
    }

    func testAMovedControlWritesOnTheGridItsFieldShows() {
        let time = ParameterDescriptor(address: .tempo, title: "Time", unit: .seconds, range: 0.001...4,
                                       defaultValue: 0.25, taper: .exponential)
        for step in 1..<200 {
            let value = time.movedValue(forNormalized: Double(step) / 200)
            let text = ParameterText.value(value, unit: .seconds, marks: .point)
            XCTAssertEqual(text?.text.isShortened, false, "every moved value shows whole: \(value)")
            let digits = text.map { $0.text.full.filter(\.isNumber).drop { $0 == "0" } } ?? ""
            XCTAssertLessThanOrEqual(digits.count, 4, "four significant digits: \(value)")
        }
        XCTAssertEqual(time.movedValue(forNormalized: 0), 0.001, "the ends stay exact")
        XCTAssertEqual(time.movedValue(forNormalized: 1), 4)
        let level = ParameterDescriptor(address: .masterVolume, title: "Volume", unit: .decibel, range: -60...6,
                                        defaultValue: 0, taper: .linear)
        XCTAssertEqual(level.movedValue(forNormalized: 0.5), -27, "a tenth of a decibel")
        XCTAssertEqual(level.movedValue(forNormalized: 0.123), -51.9, accuracy: 1e-12)
        let mix = ParameterDescriptor(address: .masterPan, title: "Mix", unit: .amount, range: 0...1,
                                      defaultValue: 0.5, taper: .linear)
        XCTAssertEqual(mix.movedValue(forNormalized: 0.12345), 0.12)
        XCTAssertEqual(mix.movedValue(forNormalized: .nan), 0, "a position that is not a number reads as 0")
    }

    func testSignificantDigits() {
        XCTAssertEqual(ParameterDescriptor.significant(0.0123456, digits: 4), 0.01235)
        XCTAssertEqual(ParameterDescriptor.significant(12_345, digits: 4), 12_350)
        XCTAssertEqual(ParameterDescriptor.significant(-0.37512, digits: 4), -0.3751)
        XCTAssertEqual(ParameterDescriptor.significant(0, digits: 4), 0)
    }
}
