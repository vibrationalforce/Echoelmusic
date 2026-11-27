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

    func testAPluginPositionIsNeverSnapped() {
        let plugin = ParameterDescriptor(address: .plugin(TrackID(), PluginParameter(.instrument, address: 7)),
                                         title: "Cutoff", unit: .amount, range: 0...1, defaultValue: 0.5,
                                         taper: .linear)
        XCTAssertEqual(plugin.movedValue(forNormalized: 0.525), 0.525, "a position along the unit's own travel")
        for pick in 0..<128 {
            let position = Double(pick) / 127
            XCTAssertEqual(plugin.movedValue(forNormalized: position), position, "pick \(pick) of 128 names")
        }
    }

    func testAValueFromAnEarlierBuildReadsItsDigitsNeverADash() {
        let attack = ParameterText.value(0.0012345678901234567, unit: .seconds, marks: .point)
        XCTAssertEqual(attack?.unit, "ms")
        XCTAssertEqual(attack?.text.compact.hasPrefix("1.23456"), true)
        XCTAssertNotEqual(attack?.compact, "–")
    }

    func testVoiceOverHearsUnitsAsWords() {
        XCTAssertEqual(ParameterText.value(0.375, unit: .seconds, marks: .point)?.spoken, "375 milliseconds")
        XCTAssertEqual(ParameterText.value(2_500, unit: .hertz, marks: .point)?.spoken, "2.5 kilohertz")
        XCTAssertEqual(ParameterText.value(-6, unit: .decibel, marks: .point)?.spoken, "minus 6 decibels")
    }

    func testAFloatReadsAsTheDecimalItHolds() {
        XCTAssertEqual(FloatReading.value(Float(0.6)), 0.6, "not 0.6000000238418579")
        XCTAssertEqual(FloatReading.value(Float(-5.9999995)), -6, "one last-place step from −6 reads −6")
        XCTAssertEqual(FloatReading.value(Float(0.37509997)), 0.3751)
        XCTAssertEqual(FloatReading.value(Float(1.813)), 1.813)
        XCTAssertEqual(FloatReading.value(Float(0.123)), 0.123, "nothing farther than a few last places moves")
        XCTAssertEqual(FloatReading.value(Float(8_000)), 8_000)
        XCTAssertTrue(FloatReading.value(Float.nan).isNaN)
    }

    func testSignificantDigits() {
        XCTAssertEqual(ParameterDescriptor.significant(0.0123456, digits: 4), 0.01235)
        XCTAssertEqual(ParameterDescriptor.significant(12_345, digits: 4), 12_350)
        XCTAssertEqual(ParameterDescriptor.significant(-0.37512, digits: 4), -0.3751)
        XCTAssertEqual(ParameterDescriptor.significant(0, digits: 4), 0)
    }
}
