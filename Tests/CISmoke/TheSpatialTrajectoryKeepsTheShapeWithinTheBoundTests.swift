//
//  TheSpatialTrajectoryKeepsTheShapeWithinTheBoundTests.swift
//  Spatial S-A2. ADR-007 §2 (accepted 2026-10-04): every object of an immersive master carries
//  WHERE it was over the piece, recorded at 20 Hz on the SAMPLE clock and thinned before export
//  by time-faithful Ramer–Douglas–Peucker — ≤ 1° azimuth, ≤ 1° elevation, ≤ 0.01 distance, plus
//  a maximum block length. This guard is the record's executable half: `SpatialTrajectory` must
//  keep every recorded sample inside those bounds with fewer points, and write the same bytes
//  for the same path, so the export folder (S-A4) and the BW64 writer (S-A5) read ONE answer.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–8) — `SpatialTrajectory`, `SpatialTrajectoryRecording`,
//    `SpatialPosition` and `SpatialScene` are shipped, Foundation-only values; nothing is mocked.
//    Every bound is measured with the type's OWN reader, `position(atSampleTime:)` — the reading
//    a writer will use — never with a second interpolation written here (#416).
//  · SOURCE-TEXT SCAN (claim 9) — the file reads no clock and draws no random number, and time
//    is an integer sample index.
//  · NOT PINNED, and said so: that anything RECORDS a trajectory in the app. Nothing does yet —
//    S-A3 will. Built: yes · wired: no · device: no · studio: no.
//
//  ⚠️ WHAT MUST NOT BE READ INTO THIS (#364): it forbids no other bound. Tighter or looser
//  bounds, another control rate or a different block length are NEW decisions — update ADR-007
//  and this guard in the same commit; the messages say so.
//
//  GRADING (#433/#464): the file does NOT compile on the parent tree — `SpatialTrajectory` and
//  `SpatialTrajectoryRecording` are created by this commit — so no assertion has a verdict there
//  (ONE absence, #486). Every claim was transcribed in Python against the new file, including
//  Float32 arithmetic for the bound in claim 4 and the exact CSV bytes of claim 8; claim 6 was
//  also driven against the FIRST draft, which returned early for two points and so never cut a
//  hold — red there, green here.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSpatialTrajectoryKeepsTheShapeWithinTheBoundTests: XCTestCase {

    private static let trajectoryFile = "Sources/Echoelmusic/Core/SpatialTrajectory.swift"
    private static let rate = 48_000
    private static let tick: Int64 = 2_400          // 48 kHz / 20 Hz

    private func at(_ azimuth: Float, _ elevation: Float, _ distance: Float) -> SpatialPosition {
        SpatialPosition(azimuth: azimuth, elevation: elevation, distance: distance)
    }

    /// Largest component error, in the bound's own unit, between every point of `reference` and
    /// what `thinned` reads at the same time.
    private func worstError(_ reference: [SpatialTrajectory.Point],
                            _ thinned: SpatialTrajectory) -> (azimuth: Float, elevation: Float, distance: Float) {
        var worst: (azimuth: Float, elevation: Float, distance: Float) = (0, 0, 0)
        for point in reference {
            guard let read = thinned.position(atSampleTime: point.sampleTime) else {
                return (.infinity, .infinity, .infinity)
            }
            let azimuth = abs(SpatialTrajectory.wrapDegrees(point.position.azimuth - read.azimuth))
            worst.azimuth = Swift.max(worst.azimuth, azimuth)
            worst.elevation = Swift.max(worst.elevation, abs(point.position.elevation - read.elevation))
            worst.distance = Swift.max(worst.distance, abs(point.position.distance - read.distance))
        }
        return worst
    }

    // MARK: 1 — a trajectory is a function of time: one place per instant, never backwards

    func testATrajectoryIsAFunctionOfTime() {
        var path = SpatialTrajectory(objectID: "a", sampleRate: Self.rate)
        XCTAssertNil(path.position(atSampleTime: 0), "an empty trajectory has no position")
        let negative = path.append(sampleTime: -1, position: .front)
        let first = path.append(sampleTime: 0, position: .front)
        let sameInstant = path.append(sampleTime: 0, position: at(30, 0, 1))
        let later = path.append(sampleTime: 4_800, position: at(30, 0, 1))
        let backwards = path.append(sampleTime: 2_400, position: at(60, 0, 1))
        XCTAssertFalse(negative, "a negative time is refused")
        XCTAssertTrue(first)
        XCTAssertFalse(sameInstant, "one place per instant")
        XCTAssertTrue(later)
        XCTAssertFalse(backwards, "time never runs back")
        XCTAssertEqual(path.points.map(\.sampleTime), [0, 4_800])

        XCTAssertEqual(SpatialTrajectory(objectID: "b", sampleRate: 0).sampleRate,
                       ImmersiveMasterPlan.sampleRate, "a trajectory without a clock takes the master's")
        XCTAssertEqual(SpatialTrajectory.controlInterval(sampleRate: 48_000), Self.tick,
                       "20 Hz at 48 kHz is one recording every 2400 samples (ADR-007 §2)")
        XCTAssertEqual(SpatialTrajectory.controlInterval(sampleRate: 10), 1, "never below one sample")
    }

    // MARK: 2 — a hold costs two points however long, and the compression is exact

    func testAHoldCostsTwoPointsAndLosesNothing() {
        var path = SpatialTrajectory(objectID: "a", sampleRate: Self.rate)
        let start = at(-20, 5, 0.8)
        let held = at(45, 10, 0.5)
        var recorded: [SpatialTrajectory.Point] = []
        let script = [start] + Array(repeating: held, count: 200) + [at(90, 0, 0.3)]
        for (index, position) in script.enumerated() {
            let time = Int64(index) * Self.tick
            path.append(sampleTime: time, position: position)
            recorded.append(.init(sampleTime: time, position: position))
        }
        XCTAssertEqual(path.points.count, 4, """
            A hold is its first and its latest sample: start, hold-begin, hold-end, move = 4 points \
            for 202 recordings.
            """)
        XCTAssertEqual(path.points[1].sampleTime, 1 * Self.tick, "the hold's FIRST sample survives")
        XCTAssertEqual(path.points[2].sampleTime, 200 * Self.tick, "the hold's LATEST sample survives")
        for point in recorded {
            XCTAssertEqual(path.position(atSampleTime: point.sampleTime), point.position, """
                The hold compression must be exact: linear interpolation of the kept points \
                reproduces every recorded sample bit for bit (t = \(point.sampleTime)).
                """)
        }
    }

    // MARK: 3 — a straight line at constant speed thins to its two ends

    func testAStraightLineThinsToItsEnds() {
        var path = SpatialTrajectory(objectID: "a", sampleRate: Self.rate)
        for index in 0...100 {
            let step = Float(index)
            path.append(sampleTime: Int64(index) * Self.tick,
                        position: at(-60 + 1.2 * step, -10 + 0.2 * step, 0.2 + 0.006 * step))
        }
        let thinned = path.thinned(maxBlockSamples: 0)
        XCTAssertEqual(thinned.points.count, 2, "constant motion is exactly its two ends")
        XCTAssertEqual(thinned.points.first, path.points.first)
        XCTAssertEqual(thinned.points.last, path.points.last)
    }

    // MARK: 4 — the bound holds at EVERY recorded sample, with far fewer points

    func testTheBoundHoldsAtEverySample() {
        var path = SpatialTrajectory(objectID: "a", sampleRate: Self.rate)
        for index in 0..<600 {
            let step = Float(index)
            path.append(sampleTime: Int64(index) * Self.tick,
                        position: at(50 * sinf(step * 0.05),
                                     20 * cosf(step * 0.031),
                                     0.5 + 0.3 * sinf(step * 0.02)))
        }
        let thinned = path.thinned(maxBlockSamples: 0)
        let worst = worstError(path.points, thinned)
        XCTAssertLessThan(thinned.points.count, path.points.count / 4, """
            Thinning must actually thin: a smooth 30-second path at 20 Hz needs far fewer points \
            than it was recorded with (got \(thinned.points.count) of \(path.points.count)).
            """)
        XCTAssertLessThanOrEqual(worst.azimuth, SpatialTrajectory.maxAngleErrorDegrees + 1e-3,
                                 "azimuth error above the ADR-007 bound of 1°")
        XCTAssertLessThanOrEqual(worst.elevation, SpatialTrajectory.maxAngleErrorDegrees + 1e-3,
                                 "elevation error above the ADR-007 bound of 1°")
        XCTAssertLessThanOrEqual(worst.distance, SpatialTrajectory.maxDistanceError + 1e-5,
                                 "distance error above the ADR-007 bound of 0.01")
        XCTAssertEqual(SpatialTrajectory.maxAngleErrorDegrees, 1, "ADR-007 §2: ≤ 1° per angle")
        XCTAssertEqual(SpatialTrajectory.maxDistanceError, 0.01, "ADR-007 §2: ≤ 0.01 distance")
    }

    // MARK: 5 — azimuth takes the shorter arc: 170° → −170° passes behind, not through the front

    func testAzimuthTakesTheShortArc() throws {
        var path = SpatialTrajectory(objectID: "a", sampleRate: Self.rate)
        path.append(sampleTime: 0, position: at(170, 0, 1))
        path.append(sampleTime: 100, position: at(-170, 0, 1))
        let quarter = try XCTUnwrap(path.position(atSampleTime: 25)).azimuth
        let middle = try XCTUnwrap(path.position(atSampleTime: 50)).azimuth
        let threeQuarters = try XCTUnwrap(path.position(atSampleTime: 75)).azimuth
        XCTAssertEqual(quarter, 175, accuracy: 1e-3)
        XCTAssertEqual(abs(middle), 180, accuracy: 1e-3, "half way is BEHIND the listener, not in front")
        XCTAssertEqual(threeQuarters, -175, accuracy: 1e-3)
    }

    // MARK: 6 — no block is longer than the limit, and the cut changes nothing — a hold included

    func testNoBlockIsLongerThanTheLimit() {
        var path = SpatialTrajectory(objectID: "a", sampleRate: Self.rate)
        for index in 0..<100 {                      // a hold of ~5 s: two points
            path.append(sampleTime: Int64(index) * Self.tick, position: at(30, 0, 0.7))
        }
        let holdOnly = path
        // Then a slow CURVED sweep. On a straight line a cut at a RECORDED point would not drift
        // either, and the drift check below could never fail for its named reason (driven in
        // Python: this sweep gives 1.5e-5° here and 0.98° for a recorded-point cut).
        for index in 100..<300 {
            let step = Float(index - 100)
            path.append(sampleTime: Int64(index) * Self.tick,
                        position: at(30 - 40 * sinf(step * 0.01), 0, 0.7))
        }
        let limit: Int64 = 48_000                   // one second at 48 kHz
        let uncut = path.thinned(maxBlockSamples: 0)
        for (trajectory, label) in [(path, "hold + sweep"), (holdOnly, "hold only")] {
            let cut = trajectory.thinned(maxBlockSamples: limit)
            let gaps = zip(cut.points, cut.points.dropFirst()).map { $1.sampleTime - $0.sampleTime }
            XCTAssertTrue(gaps.allSatisfy { $0 > 0 && $0 <= limit }, """
                \(label): a block spans more than the limit (gaps \(gaps)). A hold is two points \
                however long it lasts and still owes the cut.
                """)
            XCTAssertEqual(cut.points.first?.sampleTime, trajectory.points.first?.sampleTime)
            XCTAssertEqual(cut.points.last?.sampleTime, trajectory.points.last?.sampleTime)
        }
        XCTAssertTrue(holdOnly.thinned(maxBlockSamples: limit).points.allSatisfy { $0.position == at(30, 0, 0.7) },
                      "a point cut into a hold sits exactly at the held place")
        let cut = path.thinned(maxBlockSamples: limit)
        // Read the uncut line at EVERY recorded time — not only at its own kept points, which the
        // cut path contains unchanged and so could never show a drift.
        let uncutReading = path.points.compactMap { point in
            uncut.position(atSampleTime: point.sampleTime).map {
                SpatialTrajectory.Point(sampleTime: point.sampleTime, position: $0)
            }
        }
        XCTAssertEqual(uncutReading.count, path.points.count)
        let drift = worstError(uncutReading, cut)
        XCTAssertLessThanOrEqual(Swift.max(drift.azimuth, drift.elevation), 1e-3, """
            The cuts lie ON the thinned line, so they must not move it — a cut at a RECORDED point \
            would, and could double the error of points already judged.
            """)
        XCTAssertLessThanOrEqual(drift.distance, 1e-5)
    }

    // MARK: 7 — a recording keeps one trajectory per scene object, by id

    func testARecordingKeysEveryObjectByItsID() {
        var recording = SpatialTrajectoryRecording(sampleRate: Self.rate)
        recording.sample(SpatialScene(objects: [SpatialObject(id: "b", position: at(10, 0, 1)),
                                                SpatialObject(id: "a", position: at(-10, 0, 1))]),
                         atSampleTime: 0)
        recording.sample(SpatialScene(objects: [SpatialObject(id: "a", position: at(-20, 0, 1)),
                                                SpatialObject(id: "b", position: at(10, 0, 1)),
                                                SpatialObject(id: "c", position: at(0, 30, 0.5))]),
                         atSampleTime: Self.tick)
        recording.sample(SpatialScene(objects: [SpatialObject(id: "a", position: at(-30, 0, 1))]),
                         atSampleTime: 2 * Self.tick)

        XCTAssertEqual(recording.objectIDs, ["a", "b", "c"], "ids in a stable, sorted order")
        XCTAssertEqual(recording.trajectory(objectID: "a")?.points.count, 3)
        XCTAssertEqual(recording.trajectory(objectID: "b")?.points.map(\.sampleTime), [0, Self.tick], """
            An object that leaves keeps the points it had: a stem does not vanish because its lane \
            was deleted after the take.
            """)
        XCTAssertEqual(recording.trajectory(objectID: "c")?.points.first?.sampleTime, Self.tick,
                       "an object that joins mid-take starts where it joined, not at zero")
        XCTAssertTrue(recording.trajectories.values.allSatisfy { $0.sampleRate == Self.rate })
    }

    // MARK: 8 — the writers give the same bytes for the same path

    func testTheWritersAreByteStable() throws {
        var path = SpatialTrajectory(objectID: "track-1", sampleRate: Self.rate)
        path.append(sampleTime: 0, position: at(0, 0, 1))
        path.append(sampleTime: 24_000, position: at(90, 10, 0.5))
        path.append(sampleTime: 72_000, position: at(-45.5, -5.25, 0.25))

        XCTAssertEqual(path.csv(), """
            sample_time,seconds,azimuth,elevation,distance
            0,0.000000000,0.0000,0.0000,1.0000
            24000,0.500000000,90.0000,10.0000,0.5000
            72000,1.500000000,-45.5000,-5.2500,0.2500

            """, "the CSV layout is the S-A4 export format: integer samples, nine-digit seconds")
        XCTAssertEqual(SpatialTrajectory.seconds(1, rate: 3), "0.333333333",
                       "seconds come from integer arithmetic, truncated at nine digits")
        XCTAssertEqual(SpatialTrajectory.seconds(48_001, rate: 48_000), "1.000020833")

        let first = try path.json()
        XCTAssertEqual(first, try path.json(), "the same path encodes to the same bytes")
        XCTAssertEqual(try JSONDecoder().decode(SpatialTrajectory.self, from: first), path,
                       "the JSON reads back to the same trajectory")
    }

    // MARK: 9 — no clock, no dice, and time is an integer

    func testTheTrajectoryReadsNoClockAndNoDice() throws {
        let code = SourceText.codeOnly(try text(Self.trajectoryFile))
        for needle in ["Date()", "Date.now", "UUID()", ".random", "CFAbsoluteTimeGetCurrent",
                       "ProcessInfo", "TimeInterval"] {
            XCTAssertFalse(code.contains(needle), """
                \(Self.trajectoryFile) contains `\(needle)` in code. A trajectory is stamped on \
                the SAMPLE clock (ADR-008 §6): a wall clock or a dice makes two exports of the same \
                take differ.
                """)
        }
        XCTAssertTrue(code.contains("public let sampleTime: Int64"), """
            Time is an integer sample index. A Double of seconds decides the writer's precision \
            here, silently, and its rounding breaks block contiguity (ADR-007 K5).
            """)
        let imports = code.split(separator: "\n").filter { $0.hasPrefix("import ") }
        XCTAssertEqual(imports, ["import Foundation"], "the trajectory is Foundation-only")
    }

    private func text(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        let file = url.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("\(relative) not on disk — this run has no source tree")
        }
        return try String(contentsOf: file, encoding: .utf8)
    }
}
