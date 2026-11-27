import Foundation
import XCTest
@testable import EchoelCore

/// A body source's life in the diagnostics log: which changes become lines, what each line says, and
/// that it says it in fixed words and durations only.
final class BodySourceLogTests: XCTestCase {
    private func diagnostics() throws -> DiagnosticLog {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("body-log-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let log = DiagnosticLog(url: folder.appendingPathComponent("a.log"),
                                clock: { Date(timeIntervalSince1970: 1_795_775_160) })
        log.begin(version: "11.0.0", build: "10089")
        return log
    }

    func testALossSaysHowLongTheSourceMeasuredAndARegainHowLongItWasAbsent() {
        var strap = BodySourceLog(.strap)
        XCTAssertEqual(strap.start(at: 1_000), BodySourceLog.Line(source: .strap, kind: .started))
        XCTAssertNil(strap.measures(true, at: 5_000), "the first measurement is no line: the loss after it says how long")
        XCTAssertEqual(strap.measures(false, at: 305_400)?.kind, .lost(.noReading, measuredSeconds: 300.4))
        XCTAssertEqual(strap.measures(true, at: 313_900)?.kind, .regained(absentSeconds: 8.5))
        XCTAssertEqual(strap.stop(at: 400_000)?.kind, .stopped(measuredSeconds: 86.1))
        XCTAssertFalse(strap.isOn)
    }

    func testOnlyAChangeBetweenMeasuringAndNotIsALine() {
        var camera = BodySourceLog(.camera)
        _ = camera.start(at: 0)
        XCTAssertNil(camera.measures(false, at: 100), "not measuring, and still not: nothing changed")
        XCTAssertNil(camera.measures(true, at: 200))
        XCTAssertNil(camera.measures(true, at: 300), "another source of the same owner joining is no change")
        XCTAssertNotNil(camera.measures(false, at: 400))
        XCTAssertNil(camera.measures(false, at: 500), "lost once, not twice")
    }

    func testNothingIsALineWhileTheSourceIsOff() {
        var motion = BodySourceLog(.motion)
        XCTAssertNil(motion.measures(true, at: 0))
        XCTAssertNil(motion.stop(at: 10))
        XCTAssertEqual(motion.start(at: 20)?.kind, .started)
        XCTAssertNil(motion.start(at: 30), "turned on once")
        XCTAssertEqual(motion.stop(at: 40)?.kind, .stopped(measuredSeconds: 0))
        XCTAssertNil(motion.measures(false, at: 50))
        XCTAssertNil(motion.measures(true, at: 60))
    }

    func testTurningASourceOffIsNoLossAndSaysHowLongItLastMeasured() {
        var health = BodySourceLog(.health)
        _ = health.start(at: 121_000)
        XCTAssertEqual(health.stop(at: 181_000)?.kind, .stopped(measuredSeconds: 0), "on, and never measured")
        _ = health.start(at: 200_000)
        _ = health.measures(true, at: 210_000)
        XCTAssertEqual(health.stop(at: 330_000)?.kind, .stopped(measuredSeconds: 120))
        _ = health.start(at: 400_000)
        XCTAssertNil(health.measures(true, at: 410_000),
                     "a new start forgets the old one: its first measurement is no regain")
    }

    func testALossKeepsTheReasonItsOwnerGaveAndNeedsAMeasurementToLose() {
        var strap = BodySourceLog(.strap)
        _ = strap.start(at: 0)
        XCTAssertNil(strap.measures(false, at: 1_000, losing: .disconnected),
                     "a strap that drops before its first pulse lost nothing")
        _ = strap.measures(true, at: 2_000)
        XCTAssertEqual(strap.measures(false, at: 62_000, losing: .disconnected)?.kind,
                       .lost(.disconnected, measuredSeconds: 60))
        XCTAssertNil(strap.measures(false, at: 62_030),
                     "the glide that finds the value gone a moment later adds nothing")
    }

    func testAClockThatGoesBackCountsNoTimeAndNoClockStopsIt() throws {
        var camera = BodySourceLog(.camera)
        _ = camera.start(at: 50_000)
        _ = camera.measures(true, at: 50_000)
        XCTAssertEqual(camera.measures(false, at: 40_000)?.kind, .lost(.noReading, measuredSeconds: 0))
        XCTAssertEqual(camera.measures(true, at: .min)?.kind, .regained(absentSeconds: 0))
        let stopped = try XCTUnwrap(camera.stop(at: .max))
        guard case let .stopped(seconds) = stopped.kind else { return XCTFail("\(stopped)") }
        XCTAssertTrue(seconds.isFinite && seconds > 0, "\(seconds)")
    }

    func testEveryLineIsFixedWordsAndDurations() throws {
        let log = try diagnostics()
        XCTAssertEqual(log.note(BodySourceLog.Line(source: .strap, kind: .lost(.disconnected, measuredSeconds: 303.25))),
                       "body: strap lost (disconnected) measured_s=303.25")
        XCTAssertEqual(log.note(BodySourceLog.Line(source: .camera, kind: .regained(absentSeconds: 8.5))),
                       "body: camera regained absent_s=8.5")
        XCTAssertEqual(log.note(BodySourceLog.Line(source: .health, kind: .started)), "body: apple health started")
        XCTAssertEqual(log.note(BodySourceLog.Line(source: .motion, kind: .stopped(measuredSeconds: 0))),
                       "body: phone motion stopped measured_s=0")

        let kinds: [BodySourceLog.Line.Kind] = [.started, .regained(absentSeconds: 8.5), .stopped(measuredSeconds: 0)]
            + BodySourceLog.Loss.allCases.map { .lost($0, measuredSeconds: 303.25) }
        for source in BodySourceLog.Source.allCases {
            for kind in kinds { log.note(BodySourceLog.Line(source: source, kind: kind)) }
        }
        let lines = DiagnosticReport(log: log.text()).lines.filter { $0.event != "app: launch" }
        XCTAssertEqual(lines.count, 4 + BodySourceLog.Source.allCases.count * kinds.count, "every line is in the log's shape")
        let events = Set(lines.map(\.event))
        XCTAssertEqual(events.count, 4 * BodySourceLog.Source.allCases.count, "four words per source, none shared")
        XCTAssertEqual(Set(lines.compactMap(\.reason)).count, BodySourceLog.Loss.allCases.count, "a word for each reason")
        for line in lines {
            XCTAssertTrue(line.event.hasPrefix("body: "), line.text)
            XCTAssertTrue(Set(line.fields.keys).isSubset(of: ["measured_s", "absent_s"]), line.text)
            XCTAssertTrue(line.fields.keys.allSatisfy { line.number($0) != nil }, line.text)
        }
    }
}
