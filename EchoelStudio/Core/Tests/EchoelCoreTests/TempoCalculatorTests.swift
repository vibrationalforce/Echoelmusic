import Foundation
import XCTest
@testable import EchoelCore

final class TempoCalculatorTests: XCTestCase {
    private func note(_ denominator: Int, _ feel: NoteValue.Feel = .straight) throws -> NoteValue {
        try XCTUnwrap(NoteValue(denominator: denominator, feel: feel))
    }

    func testABarAt150IsOnePointSixSecondsAndExactlySoManySamples() throws {
        let calculator = try XCTUnwrap(TempoCalculator(songTempo: 150, sampleRate: 44_100))
        let bar = try XCTUnwrap(calculator.barSeconds)
        XCTAssertEqual(bar, Rational.constant(8, 5))
        XCTAssertEqual(calculator.samples(ofSeconds: bar), 70_560)
    }

    func testTheDelayTableAt150IsExact() throws {
        let calculator = TempoCalculator(bpm: 150)
        XCTAssertEqual(calculator.seconds(of: try note(2)), Rational.constant(4, 5), "800 ms")
        XCTAssertEqual(calculator.seconds(of: try note(2, .dotted)), Rational.constant(6, 5), "1200 ms")
        let triplet = try XCTUnwrap(calculator.seconds(of: try note(2, .triplet)))
        XCTAssertEqual(triplet, Rational.constant(8, 15), "533,3̅ ms — the calculator showed 533")
        XCTAssertEqual(calculator.samples(ofSeconds: triplet), 23_520)
        XCTAssertEqual(TempoCalculator.hertz(ofSeconds: triplet), Rational.constant(15, 8), "1,875 Hz")
        XCTAssertEqual(calculator.seconds(of: try note(64, .dotted)), Rational.constant(3, 80), "37,5 ms — it showed 38")
        XCTAssertEqual(calculator.seconds(of: try note(64, .triplet)), Rational.constant(1, 60), "16,6̅ ms — it showed 17")
    }

    func testATempoWithDecimalsStaysExact() throws {
        let calculator = try XCTUnwrap(TempoCalculator(songTempo: 132, sampleRate: 44_100))
        let bar = try XCTUnwrap(calculator.barSeconds)
        XCTAssertEqual(bar, Rational.constant(20, 11), "1,8̅1̅ s — the calculator showed 1,818")
        XCTAssertEqual(calculator.samples(ofSeconds: bar), Rational.constant(882_000, 11), "80181,8̅1̅ — it showed 80.182")
        XCTAssertEqual(calculator.seconds(of: try note(16, .dotted)), Rational.constant(15, 88))
        let typed = try XCTUnwrap(TempoCalculator(songTempo: 132.5, sampleRate: 48_000))
        XCTAssertEqual(typed.bpm, Rational.constant(265, 2))
        XCTAssertEqual(typed.seconds(ofQuarters: 1), Rational.constant(24, 53))
    }

    func testALengthGivesItsTempo() {
        let length = Rational.constant(1_818, 1_000)
        XCTAssertEqual(TempoCalculator.bpm(quarters: 4, lasting: length), Rational.constant(40_000, 303),
                       "132,0̅1̅3̅2̅ BPM — the calculator showed 132")
        XCTAssertEqual(TempoCalculator.bpm(quarters: 4, lasting: 2), 120)
        XCTAssertNil(TempoCalculator.bpm(quarters: 4, lasting: .zero))
    }

    func testTheMeterSetsTheBar() throws {
        XCTAssertEqual(TempoCalculator(bpm: 120, beatsPerBar: 6, beatUnit: 8).barQuarters, 3)
        XCTAssertEqual(TempoCalculator(bpm: 120, beatsPerBar: 7, beatUnit: 8).barQuarters, Rational.constant(7, 2))
        XCTAssertNil(TempoCalculator(songTempo: 120, sampleRate: 44_100, beatsPerBar: 4, beatUnit: 3))
        XCTAssertNil(TempoCalculator(songTempo: 0, sampleRate: 44_100))
        XCTAssertNil(TempoCalculator(songTempo: .nan, sampleRate: 44_100))
    }

    func testVideoFramesAreExactAtTwentyNineNinetySeven() throws {
        let calculator = TempoCalculator(bpm: 150, frameRate: Rational.constant(30_000, 1_001))
        let quarter = try XCTUnwrap(calculator.seconds(ofQuarters: 1))
        XCTAssertEqual(calculator.frames(ofSeconds: quarter), Rational.constant(12_000, 1_001))
        XCTAssertEqual(TempoCalculator(bpm: 150).frames(ofSeconds: quarter), 12)
    }

    func testTheSortedListRunsLongestFirst() throws {
        let sorted = TempoCalculator(bpm: 150).sortedDelays
        XCTAssertEqual(sorted.count, 18, "1/2 to 1/64, three feels each")
        XCTAssertEqual(sorted.first?.note, try note(2, .dotted))
        XCTAssertEqual(sorted.first?.seconds, Rational.constant(6, 5))
        XCTAssertEqual(sorted.last?.note, try note(64, .triplet))
        let names = sorted.prefix(5).map { $0.note.name }
        XCTAssertEqual(names, ["1/2 dotted", "1/2", "1/4 dotted", "1/2 triplet", "1/4"])
        for (earlier, later) in zip(sorted, sorted.dropFirst()) {
            XCTAssertGreaterThan(earlier.seconds, later.seconds)
        }
    }

    func testPitchIsExactOnlyAtTheOctavesOfA() {
        XCTAssertEqual(TempoCalculator.exactHertz(ofMIDINote: 69, concertPitch: 440), 440)
        XCTAssertEqual(TempoCalculator.exactHertz(ofMIDINote: 57, concertPitch: 440), 220)
        XCTAssertEqual(TempoCalculator.exactHertz(ofMIDINote: 81, concertPitch: Rational.constant(8_811, 20)),
                       Rational.constant(8_811, 10), "440,55 Hz an octave up")
        XCTAssertNil(TempoCalculator.exactHertz(ofMIDINote: 60, concertPitch: 440), "middle C is irrational")
        XCTAssertEqual(TempoCalculator.approximateHertz(ofMIDINote: 60, concertPitch: 440), 261.6255653005986,
                       accuracy: 1e-9)
        XCTAssertEqual(TempoCalculator.wavelength(ofHertz: 343), 1, "343 Hz is one metre in air")
    }

    func testNoteValuesNameThemselvesAsTempoNoteDoes() throws {
        XCTAssertEqual(NoteValue.all.count, 21)
        XCTAssertEqual(try note(8, .dotted).quarters, Rational.constant(3, 4))
        XCTAssertEqual(try note(8, .triplet).quarters, Rational.constant(1, 3))
        XCTAssertEqual(try note(1).quarters, 4)
        XCTAssertNil(NoteValue(denominator: 3))
        let names = Set(TempoNote.divisions.map(\.name))
        XCTAssertEqual(Set(NoteValue.all.map(\.name)), names, "the two tables agree on every name")
    }
}
