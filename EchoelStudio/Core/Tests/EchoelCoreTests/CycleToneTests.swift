import Foundation
import XCTest
@testable import EchoelCore

/// A natural cycle heard as a tone: one over its period, doubled by whole octaves into octave 3;
/// its tempo is that tone seven octaves lower; its concert pitch puts it exactly on its key.
final class CycleToneTests: XCTestCase {
    private func tone(_ id: String) throws -> CycleTone {
        let cycle = try XCTUnwrap(CycleLibrary.all.first { $0.id == id }, id)
        return try XCTUnwrap(cycle.tone, id)
    }

    func testTheEarthsYearSoundsAt136HzPlaysAt63BPMAndSitsOnCSharpAtA432() throws {
        let year = try tone("earth.year")
        XCTAssertEqual(year.hertz, 136.10, accuracy: 0.005)
        XCTAssertEqual(year.tempo, 63.80, accuracy: 0.005)
        XCTAssertEqual(year.concertPitch, 432.10, accuracy: 0.005)
        XCTAssertEqual(NoteEditing.name(of: year.pitch), "C♯3")
        XCTAssertEqual(year.octaves, 32, "the year's frequency doubled 32 times")
    }

    func testTheLibrarysTonesAreThePublishedOctaveTones() throws {
        // Values as published in Hans Cousto's tuning tables, rounded to 0.01 Hz.
        let published: [(String, Double)] = [
            ("earth.day", 194.18), ("earth.siderealDay", 194.71), ("moon.synodicMonth", 210.42),
            ("moon.siderealMonth", 227.43), ("moon.saros", 241.56), ("moon.metonicCycle", 229.22),
            ("mercury.orbit", 141.27), ("venus.orbit", 221.23), ("mars.orbit", 144.72),
            ("jupiter.orbit", 183.58), ("saturn.orbit", 147.85), ("uranus.orbit", 207.36),
            ("neptune.orbit", 211.44), ("pluto.orbit", 140.64), ("ceres.orbit", 236.47),
            ("eris.orbit", 249.28), ("sedna.orbit", 193.40), ("io.orbit", 219.52),
            ("titan.orbit", 194.85), ("charon.orbit", 243.22),
        ]
        for (id, hertz) in published {
            XCTAssertEqual(try tone(id).hertz, hertz, accuracy: 0.006, id)
        }
    }

    func testEveryToneLiesInOctaveThreeAndGivesAConcertPitchTheSongAccepts() {
        XCTAssertGreaterThan(CycleLibrary.all.count, 60)
        for cycle in CycleLibrary.all {
            guard let tone = cycle.tone else { return XCTFail("\(cycle.id) has no tone") }
            XCTAssertGreaterThanOrEqual(tone.hertz, CycleTone.lowestHertz, cycle.id)
            XCTAssertLessThan(tone.hertz, CycleTone.highestHertz, cycle.id)
            XCTAssertTrue((48...59).contains(tone.pitch), "\(cycle.id): its key is in octave 3")
            XCTAssertLessThanOrEqual(abs(tone.centsFromKey), 50 + 1e-9, cycle.id)
            XCTAssertTrue(MusicalContext.concertPitchRange.contains(tone.concertPitch), cycle.id)
            XCTAssertEqual(tone.tempo, tone.hertz * 60 / 128, accuracy: 1e-9, "\(cycle.id): seven octaves lower")
        }
    }

    func testAnOctaveOfThePeriodIsTheSameTone() throws {
        let day = try XCTUnwrap(CycleTone(periodSeconds: 86_400))
        let half = try XCTUnwrap(CycleTone(periodSeconds: 43_200))
        let double = try XCTUnwrap(CycleTone(periodSeconds: 172_800))
        XCTAssertEqual(half.hertz, day.hertz, accuracy: 1e-9)
        XCTAssertEqual(double.hertz, day.hertz, accuracy: 1e-9)
        XCTAssertEqual(half.octaves, day.octaves - 1)
        XCTAssertEqual(double.octaves, day.octaves + 1)
        XCTAssertEqual(day.cycleHertz, 1.0 / 86_400, accuracy: 1e-15)
    }

    func testACycleFasterThanTheWindowIsHalvedIntoIt() throws {
        let fast = try XCTUnwrap(CycleTone(periodSeconds: 1.0 / 1_000), "1 kHz")
        XCTAssertEqual(fast.hertz, 250, accuracy: 1e-9)
        XCTAssertEqual(fast.octaves, -2)
    }

    func testAPeriodThatIsNotATimeHasNoTone() {
        XCTAssertNil(CycleTone(periodSeconds: 0))
        XCTAssertNil(CycleTone(periodSeconds: -86_400))
        XCTAssertNil(CycleTone(periodSeconds: .nan))
        XCTAssertNil(CycleTone(periodSeconds: .infinity))
        XCTAssertNil(CycleTone(periodSeconds: .greatestFiniteMagnitude), "too slow to double into hearing")
        XCTAssertNil(CycleTone(periodSeconds: .leastNonzeroMagnitude), "too fast to halve into hearing")
    }

    func testEveryCycleHasOneIdAndNamesItsSource() {
        let ids = CycleLibrary.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "ids are unique")
        for cycle in CycleLibrary.all {
            XCTAssertFalse(cycle.body.isEmpty, cycle.id)
            XCTAssertFalse(cycle.cycle.isEmpty, cycle.id)
            XCTAssertFalse(cycle.source.isEmpty, cycle.id)
            XCTAssertTrue(cycle.periodDays.isFinite && cycle.periodDays > 0, cycle.id)
        }
        for group in NaturalCycle.Group.allCases {
            XCTAssertFalse(CycleLibrary.all.filter { $0.group == group }.isEmpty, "\(group) has cycles")
        }
    }
}
