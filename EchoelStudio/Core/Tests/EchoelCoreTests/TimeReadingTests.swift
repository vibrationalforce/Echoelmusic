import XCTest
@testable import EchoelCore

/// A time or a slow rate reads as a note value at the song's tempo by default, or in seconds,
/// milliseconds or hertz on choice, and never hides a digit: where the field shows a note value,
/// the exact time stands beside it.
final class TimeReadingTests: XCTestCase {
    private let marks = NumberMarks.point

    func testANoteValueLeadsByDefaultWithTheExactTimeBesideIt() throws {
        XCTAssertEqual(TimeReading.standard, .noteValue)
        // 375 ms at 120 BPM is a dotted eighth, exactly.
        let delay = try XCTUnwrap(ParameterText.rhythm(0.375, unit: .seconds, bpm: 120, reading: .noteValue, marks: marks))
        XCTAssertEqual(delay.main, "1/8 dotted")
        XCTAssertEqual(delay.others.first, "375 ms", "the exact time beside the note")
        XCTAssertEqual(delay.others.count, 2, "and the rate")
        XCTAssertTrue(delay.others[1].hasSuffix("Hz"))
        // A rate: 2 Hz at 120 BPM lasts a quarter note.
        let lfo = try XCTUnwrap(ParameterText.rhythm(2, unit: .hertz, bpm: 120, reading: .noteValue, marks: marks))
        XCTAssertEqual(lfo.main, "1/4")
        XCTAssertEqual(lfo.others.first, "2 Hz", "a rate's own unit first")
        XCTAssertEqual(lfo.others.last, "500 ms")
    }

    func testATimeNearANoteSaysSoAndATimeOnNoneShowsItsUnit() throws {
        // 377 ms at 120 BPM is within one percent of the dotted eighth (375 ms), not on it; 380 ms
        // is 1.3 % away and near none.
        let near = try XCTUnwrap(ParameterText.rhythm(0.377, unit: .seconds, bpm: 120, reading: .noteValue, marks: marks))
        XCTAssertEqual(near.main, "≈ 1/8 dotted")
        XCTAssertEqual(near.others.first, "377 ms")
        XCTAssertEqual(ParameterText.rhythm(0.38, unit: .seconds, bpm: 120, reading: .noteValue, marks: marks)?.main, "380 ms")
        // An attack of 3 ms lies on no note value: it reads in milliseconds, with no note to pretend.
        let attack = try XCTUnwrap(ParameterText.rhythm(0.003, unit: .seconds, bpm: 120, reading: .noteValue, marks: marks))
        XCTAssertEqual(attack.main, "3 ms")
        XCTAssertFalse(attack.others.contains { $0.contains("/") })
    }

    func testEachChosenUnitLeadsAndTheNoteValueMovesBeside() throws {
        let seconds = try XCTUnwrap(ParameterText.rhythm(0.375, unit: .seconds, bpm: 120, reading: .seconds, marks: marks))
        XCTAssertEqual(seconds.main, "0.375 s")
        XCTAssertEqual(seconds.others.last, "1/8 dotted")
        let milliseconds = try XCTUnwrap(ParameterText.rhythm(2, unit: .hertz, bpm: 120, reading: .milliseconds, marks: marks))
        XCTAssertEqual(milliseconds.main, "500 ms")
        XCTAssertEqual(milliseconds.others, ["2 Hz", "1/4"])
        let hertz = try XCTUnwrap(ParameterText.rhythm(0.5, unit: .seconds, bpm: 120, reading: .hertz, marks: marks))
        XCTAssertEqual(hertz.main, "2 Hz")
        XCTAssertEqual(hertz.others, ["500 ms", "1/4"])
        // A third of a second: every digit, the repeating one marked, never rounded.
        let third = try XCTUnwrap(ParameterText.rhythm(3, unit: .hertz, bpm: 120, reading: .milliseconds, marks: marks))
        XCTAssertEqual(third.mainFull, "333.3\(ExactText.repeatMark) ms", "the repeating digit carries its bar")
    }

    func testAPitchAndANonNumberAreNoRhythm() {
        XCTAssertNil(ParameterText.rhythm(440, unit: .hertz, bpm: 120, reading: .noteValue, marks: marks), "440 Hz is a pitch")
        XCTAssertNotNil(ParameterText.rhythm(40, unit: .hertz, bpm: 120, reading: .noteValue, marks: marks))
        XCTAssertNil(ParameterText.rhythm(-1, unit: .seconds, bpm: 120, reading: .noteValue, marks: marks))
        XCTAssertNil(ParameterText.rhythm(.nan, unit: .seconds, bpm: 120, reading: .noteValue, marks: marks))
        XCTAssertNil(ParameterText.rhythm(0.5, unit: .decibel, bpm: 120, reading: .noteValue, marks: marks))
        // A tempo that is no number leaves the note out but still shows the time.
        let noTempo = ParameterText.rhythm(0.375, unit: .seconds, bpm: .nan, reading: .noteValue, marks: marks)
        XCTAssertEqual(noTempo?.main, "375 ms")
    }

    /// The note grid a moved rhythmic control lands on: every note value in range, each the exact
    /// time it lasts at the tempo, and the nearest by ratio.
    func testAMovedRhythmLandsOnTheNearestNoteValueInRange() throws {
        let grid = ParameterText.noteGrid(unit: .seconds, range: 0.001...2, bpm: 120)
        XCTAssertFalse(grid.isEmpty)
        XCTAssertEqual(grid.map(\.value), grid.map(\.value).sorted(), "shortest first")
        XCTAssertTrue(grid.allSatisfy { (0.001...2).contains($0.value) })
        XCTAssertTrue(grid.contains { $0.note.name == "1/8 dotted" && $0.value == 0.375 })
        XCTAssertFalse(grid.contains { $0.note.name == "1/1" && $0.value > 2 }, "a whole note of 2 s fits, none longer")
        XCTAssertEqual(ParameterText.nearestNote(to: 0.36, unit: .seconds, range: 0.001...2, bpm: 120), 0.375)
        XCTAssertEqual(ParameterText.nearestNote(to: 0.26, unit: .seconds, range: 0.001...2, bpm: 120), 0.25)
        // A rate: 1.9 Hz at 120 BPM lands on the quarter note's 2 Hz; the grid stays under 40 Hz.
        XCTAssertEqual(ParameterText.nearestNote(to: 1.9, unit: .hertz, range: 0.05...8, bpm: 120), 2)
        let rates = ParameterText.noteGrid(unit: .hertz, range: 0.05...100, bpm: 120)
        XCTAssertTrue(rates.allSatisfy { $0.value <= ParameterText.rhythmCeiling })
        XCTAssertTrue(ParameterText.noteGrid(unit: .decibel, range: 0...1, bpm: 120).isEmpty)
        XCTAssertNil(ParameterText.nearestNote(to: 0.5, unit: .seconds, range: 10...20, bpm: 120), "no note value fits")
        // What the grid stores reads back as the note, exactly.
        for entry in grid {
            let read = ParameterText.rhythm(entry.value, unit: .seconds, bpm: 120, reading: .noteValue, marks: marks)
            XCTAssertEqual(read?.main, entry.note.name)
        }
    }

    /// Only a rate that keeps time with the song lands on note values when moved; an envelope's
    /// times stay free.
    func testOnlyARateThatKeepsTimeMovesOnNoteValues() {
        let rhythmic = SynthParameter.Name.allCases.filter { (name: SynthParameter.Name) -> Bool in
            ParameterDescriptor(address: ParameterAddress(.track(TrackID()), name.parameter.key), title: name.parameter.title,
                                unit: name.parameter.unit, range: name.parameter.range,
                                defaultValue: name.parameter.defaultValue, taper: name.parameter.taper).isRhythmic
        }
        XCTAssertEqual(rhythmic, [.textureRate])
    }
}
