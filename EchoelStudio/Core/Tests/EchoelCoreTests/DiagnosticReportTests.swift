import XCTest
@testable import EchoelCore

/// The report the app makes from its own diagnostic log: what it reads, what it finds, in which
/// order, and what it shows. Every log here is text in the log's own shape.
final class DiagnosticReportTests: XCTestCase {
    private let launch = "2026-11-27T10:26:00.000Z  app: launch v11.0.0 (10088), times in UTC"

    private func log(_ latest: [String], before: [String]? = nil) -> String {
        var text = ""
        if let before { text += DiagnosticLog.runBeforeHeader + "\n" + before.map { $0 + "\n" }.joined() }
        return text + DiagnosticLog.latestRunHeader + "\n" + latest.map { $0 + "\n" }.joined()
    }

    private func load(_ time: String, peak: Double, over75: Int = 0, over100: Int = 0, gaps: Int = 0) -> String {
        "2026-11-27T\(time).000Z  engine: render load callbacks=940 peak=\(peak) over50=0 over75=\(over75) over100=\(over100) gaps=\(gaps) silent=0"
    }

    func testAnEmptyLogSaysSoAndNothingElse() {
        let report = DiagnosticReport(log: "")
        XCTAssertEqual(report.findings.count, 1)
        XCTAssertEqual(report.findings.first?.weight, .note)
        XCTAssertEqual(report.findings.first?.title, "The log holds no lines yet.")
        XCTAssertEqual(report.latest.lines, 0)
        XCTAssertNil(report.before, "a file without the second run's header has one run")
        XCTAssertTrue(report.markdown.hasPrefix("# Echoelmusic report\n"))
    }

    func testEachRunGivesItsVersionBuildAndLength() {
        let report = DiagnosticReport(log: log(
            [launch, "2026-11-27T10:34:00.000Z  app: background"],
            before: ["2026-11-26T18:00:00.000Z  app: launch v11.0.0 (10087), times in UTC",
                     "2026-11-26T18:30:00.000Z  app: background"]))
        XCTAssertEqual(report.latest.version, "11.0.0")
        XCTAssertEqual(report.latest.build, "10088")
        XCTAssertEqual(report.latest.minutes, 8)
        XCTAssertEqual(report.latest.lines, 2)
        XCTAssertEqual(report.before?.build, "10087")
        XCTAssertEqual(report.before?.minutes, 30)
        XCTAssertEqual(report.lines.filter { $0.run == .before }.count, 2)
        XCTAssertEqual(report.overview, [
            "Latest run: version 11.0.0 (10088), 2026-11-27 10:26 to 10:34 UTC, 8 min, 2 lines.",
            "Run before: version 11.0.0 (10087), 2026-11-26 18:00 to 18:30 UTC, 30 min, 2 lines.",
        ])
    }

    func testALineIsTakenApartIntoEventReasonAndFields() throws {
        let held = try XCTUnwrap(DiagnosticReport.parse(
            "2026-11-27T10:27:00.000Z  tempo: flow holds (the tempo leaves this device and body sharing is off)", run: .latest))
        XCTAssertEqual(held.event, "tempo: flow holds")
        XCTAssertEqual(held.reason, "the tempo leaves this device and body sharing is off")
        XCTAssertTrue(held.fields.isEmpty)

        let window = try XCTUnwrap(DiagnosticReport.parse(load("10:27:10", peak: 0.612), run: .latest))
        XCTAssertEqual(window.event, "engine: render load")
        XCTAssertNil(window.reason)
        XCTAssertEqual(window.fields.count, 7)
        XCTAssertEqual(window.number("peak"), 0.612)

        let failed = try XCTUnwrap(DiagnosticReport.parse(
            "2026-11-27T10:27:20.000Z  engine: configure failed error=NSOSStatusErrorDomain code=-50", run: .before))
        XCTAssertEqual(failed.event, "engine: configure failed")
        XCTAssertEqual(failed.fields["error"], "NSOSStatusErrorDomain")
        XCTAssertEqual(failed.number("code"), -50)
        XCTAssertNil(failed.number("error"), "a word is no number")
        XCTAssertEqual(failed.run, .before)
    }

    func testLinesInAnotherShapeAreLeftOut() {
        let report = DiagnosticReport(log: log([
            launch,
            "hello",
            "2026-11-27  engine: start",
            "2026-13-27T10:00:00.000Z  engine: start",
            "2026-11-27T10:28:00.000Z  ",
            "2026-11-27T10:28:01.000Z  engine: start",
        ]))
        XCTAssertEqual(report.lines.map(\.event), ["app: launch", "engine: start"])
    }

    func testAMissedDeadlineIsAProblemWithTheWindowsAndThePeak() throws {
        let report = DiagnosticReport(log: log([
            launch,
            load("10:26:10", peak: 0.4),
            load("10:26:20", peak: 1.12, over75: 6, over100: 2),
            load("10:26:30", peak: 0.9, over75: 3, over100: 1),
        ]))
        let finding = try XCTUnwrap(report.findings.first)
        XCTAssertEqual(finding.weight, .problem)
        XCTAssertEqual(finding.title,
                       "The audio missed its deadline 3 times in 2 of 3 ten-second windows; the highest load was 112 %.")
        XCTAssertEqual(finding.count, 2)
        XCTAssertEqual(finding.evidence.count, 2)
        XCTAssertEqual(report.latest.missedTime, 3)
        XCTAssertEqual(report.latest.audioWindows, 3)
        XCTAssertEqual(report.latest.highestLoad, 1.12)
        XCTAssertFalse(report.findings.contains { $0.title.hasPrefix("The audio came close") },
                       "a miss says more than coming close")
    }

    func testALoadNearTheLimitIsOnlyANotice() {
        let report = DiagnosticReport(log: log([launch, load("10:26:10", peak: 0.8, over75: 4)]))
        XCTAssertEqual(report.findings.map(\.weight), [.notice])
        XCTAssertEqual(report.findings.first?.title, "The audio came close to its time limit: the highest load was 80 %.")
    }

    func testASampleTimeJumpIsAProblemOfItsOwn() {
        let report = DiagnosticReport(log: log([launch, load("10:26:10", peak: 0.3, gaps: 1)]))
        XCTAssertEqual(report.findings.map(\.title), ["The audio's sample time jumped once: a gap or a repeat."])
        XCTAssertEqual(report.latest.sampleJumps, 1)
    }

    func testACrashComesFirstAndSaysWhichRunHeldIt() throws {
        let report = DiagnosticReport(log: log(
            [launch, load("10:26:10", peak: 1.2, over100: 1)],
            before: ["2026-11-26T18:00:00.000Z  metrickit: crash signal=11 exceptionType=1 exceptionCode=0"]))
        let first = try XCTUnwrap(report.findings.first)
        XCTAssertEqual(first.weight, .failure)
        XCTAssertEqual(first.run, .before)
        XCTAssertEqual(first.title, "The app ended with a crash.")
        XCTAssertEqual(report.findings.dropFirst().first?.weight, .problem)
    }

    func testFindingsGoFromTheGravestAndTheLatestRunFirst() {
        let report = DiagnosticReport(log: log(
            [launch,
             "2026-11-27T10:27:00.000Z  engine: interruption began",
             "2026-11-27T10:28:00.000Z  memory: warning released=2 loaded=5"],
            before: ["2026-11-26T18:00:00.000Z  engine: render stalled, rebuilding",
                     "2026-11-26T18:01:00.000Z  memory: warning released=1 loaded=3"]))
        XCTAssertEqual(report.findings.map(\.weight), [.problem, .notice, .notice, .note])
        XCTAssertEqual(report.findings.map(\.run), [.before, .latest, .before, .latest])
    }

    func testEvidenceQuotesTheLastLinesAndCountsThemAll() throws {
        let warnings = (1...5).map { "2026-11-27T10:3\($0):00.000Z  memory: warning released=\($0) loaded=9" }
        let report = DiagnosticReport(log: log([launch] + warnings))
        let finding = try XCTUnwrap(report.findings.first)
        XCTAssertEqual(finding.title, "The device ran low on memory 5 times.")
        XCTAssertEqual(finding.count, 5)
        XCTAssertEqual(finding.evidence, Array(warnings.suffix(DiagnosticReport.evidenceLimit)))
    }

    func testASafeStartSaysHowOftenTheLaunchDidNotFinish() {
        let report = DiagnosticReport(log: log([launch, "2026-11-27T10:26:01.000Z  launch: safe start deaths=3"]))
        XCTAssertEqual(report.findings.map(\.weight), [.problem])
        XCTAssertEqual(report.findings.first?.title, "The app did not finish starting 3 times in a row, so it started safely.")
    }

    func testTheFieldLoweringItsDetailIsANoticeWithTheSlowestSecond() {
        let report = DiagnosticReport(log: log([
            launch,
            "2026-11-27T10:27:00.000Z  field: detail level=1 fps=41",
            "2026-11-27T10:28:00.000Z  field: detail level=2 fps=60",
        ]))
        XCTAssertEqual(report.findings.map(\.title),
                       ["The Field lowered its picture detail once; the slowest second showed 41 frames."])
    }

    func testAQuietLogSaysNothingPointsToAFault() {
        let report = DiagnosticReport(log: log([launch, "2026-11-27T10:26:05.000Z  app: active", load("10:26:10", peak: 0.3)]))
        XCTAssertTrue(report.findings.isEmpty)
        XCTAssertTrue(report.markdown.contains("Nothing in the log points to a fault."))
    }

    func testANumberEditedInTheFileCannotStopTheReport() {
        let report = DiagnosticReport(log: log([
            launch,
            "2026-11-27T10:26:10.000Z  engine: render load callbacks=1 peak=1e300 over100=1e300 gaps=nan",
            "2026-11-27T10:26:20.000Z  launch: safe start deaths=-1e300",
        ]))
        XCTAssertEqual(report.latest.missedTime, 1_000_000_000, "held within a billion")
        XCTAssertEqual(report.latest.sampleJumps, 0, "no number counts as none")
        XCTAssertTrue(report.markdown.contains("## Numbers"))
    }

    func testTheMarkdownCarriesTheFindingsTheNumbersAndTheLog() {
        let late = load("10:26:20", peak: 1.05, over100: 1)
        let text = log([launch, late, "2026-11-27T10:34:00.000Z  app: background"])
        let markdown = DiagnosticReport(log: text).markdown
        XCTAssertTrue(markdown.contains("Latest run: version 11.0.0 (10088), 2026-11-27 10:26 to 10:34 UTC, 8 min, 3 lines."), markdown)
        XCTAssertTrue(markdown.contains("1. **Problem** · latest run · The audio missed its deadline once in 1 of 1 ten-second windows"), markdown)
        XCTAssertTrue(markdown.contains("   \(late)\n"), "the evidence quotes the line as written")
        XCTAssertTrue(markdown.contains("| Version | 11.0.0 (10088) | – |"), markdown)
        XCTAssertTrue(markdown.contains("| Highest load | 105 % | – |"), markdown)
        XCTAssertTrue(markdown.hasSuffix("## The log\n\n```\n" + text + "```\n"), "the whole log is the material")
    }

    func testTimesCountSecondsSince1970InUTC() {
        XCTAssertEqual(DiagnosticReport.seconds(of: "1970-01-01T00:00:00.000Z"), 0)
        XCTAssertEqual(DiagnosticReport.seconds(of: "1969-12-31T23:59:59.000Z"), -1)
        XCTAssertEqual(DiagnosticReport.seconds(of: "2000-02-29T12:00:00.000Z"), 951_825_600)
        XCTAssertEqual(DiagnosticReport.seconds(of: "2026-11-27T10:26:00.250Z"), 1_795_775_160.25)
        XCTAssertNil(DiagnosticReport.seconds(of: "2026-11-27T10:26:00Z"))
        XCTAssertNil(DiagnosticReport.seconds(of: "2026-11-27T25:00:00.000Z"))
    }
}
