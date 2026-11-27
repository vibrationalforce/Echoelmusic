import Foundation
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
        XCTAssertEqual(first.title, "iOS reported that the app ended with a crash.")
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

    func testACrashIsUsuallyHandedOverInTheRunAfterIt() throws {
        let report = DiagnosticReport(log: log([launch, "2026-11-27T10:26:02.000Z  metrickit: crash signal=6 exceptionType=10 exceptionCode=0"]))
        let crash = try XCTUnwrap(report.findings.first)
        XCTAssertEqual(crash.weight, .failure)
        XCTAssertEqual(crash.run, .latest)
        XCTAssertTrue(crash.suggestion.contains("The last lines of the run before show what the app was doing."), crash.suggestion)
    }

    func testAnAudioWishIOSKeptIsANoteAndASetupThatFailedIsAProblem() {
        let report = DiagnosticReport(log: log([
            launch,
            "2026-11-27T10:26:01.000Z  session: preferred rate refused error=NSOSStatusErrorDomain code=-50",
            "2026-11-27T10:26:02.000Z  engine: configure failed error=NSOSStatusErrorDomain code=561017449",
        ]))
        XCTAssertEqual(report.findings.map(\.weight), [.problem, .note])
        XCTAssertEqual(report.findings.map(\.title),
                       ["The audio could not be set up.", "iOS kept its own sample rate or buffer size."])
    }

    func testAMemoryWarningSaysWhatWasReleasedOnlyWhenSomethingWas() {
        let none = DiagnosticReport(log: log([launch, "2026-11-27T10:26:01.000Z  memory: warning released=0 loaded=4"]))
        XCTAssertEqual(none.findings.first?.suggestion, "Close other apps if it repeats.")
        let some = DiagnosticReport(log: log([launch, "2026-11-27T10:26:01.000Z  memory: warning released=3 loaded=4"]))
        XCTAssertEqual(some.findings.first?.suggestion,
                       "The app released 3 samples that were not playing. Close other apps if it repeats.")
    }

    func testAStreamWithoutTheSongsSoundAndAFieldLayerThatFailedAreProblems() {
        let report = DiagnosticReport(log: log([
            launch,
            "2026-11-27T10:26:01.000Z  graph: stream tap refused the format",
            "2026-11-27T10:26:02.000Z  field layer: pipeline failed error=MTLLibraryErrorDomain code=3",
        ]))
        XCTAssertEqual(report.findings.map(\.weight), [.problem, .problem])
        XCTAssertEqual(report.findings.map(\.title),
                       ["A live stream could not take the song's sound format.", "The Field layer for video could not be built."])
    }

    func testALogSavedWithWindowsLineEndsIsReadToo() {
        let report = DiagnosticReport(log: log([launch, "2026-11-27T10:27:00.000Z  memory: warning released=1 loaded=2"])
            .replacingOccurrences(of: "\n", with: "\r\n"))
        XCTAssertEqual(report.lines.map(\.event), ["app: launch", "memory: warning"])
        XCTAssertEqual(report.latest.build, "10088")
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
        XCTAssertTrue(report.markdown.contains(DiagnosticReport.nothingFound))
        XCTAssertEqual(DiagnosticReport.nothingFound, "None of the report's rules found a fault in the log.",
                       "it speaks for the rules, not for the app")
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

    // MARK: - Body sources (BR-8)

    /// A strap as `HeartRateStrap` runs one, for `seconds` after it was turned on: a packet carrying
    /// `value` at each second in `packets` into its `BodyChannel`, a tick each second, and whether the
    /// channel holds a value into its `BodySourceLog`, whose lines go into a real log. The reading
    /// itself stays in the channel. Returns the log's text.
    private func strapRun(packets: [ClosedRange<Int>], value: Double, seconds: Int) throws -> String {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("body-report-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let diagnostics = DiagnosticLog(url: folder.appendingPathComponent("a.log"),
                                        clock: { Date(timeIntervalSince1970: 1_795_775_160) })
        diagnostics.begin(version: "11.0.0", build: "10089")
        var channel = BodyChannel(maximumAgeMilliseconds: 3_000)
        var lifecycle = BodySourceLog(.strap)
        if let line = lifecycle.start(at: 0) { diagnostics.note(line) }
        _ = try channel.step(.start(.ble, .granted), at: 0)
        for second in 0...seconds {
            let now = Int64(second) * 1_000
            if packets.contains(where: { $0.contains(second) }) {
                _ = try channel.step(.sample(.init(source: .ble, epoch: channel.epoch, sequence: Int64(second),
                                                   capturedMilliseconds: now, value: value, quality: 1)), at: now)
            }
            _ = try channel.step(.tick, at: now)
            if let line = lifecycle.measures(channel.value != nil, at: now) { diagnostics.note(line) }
        }
        if let line = lifecycle.stop(at: Int64(seconds) * 1_000) { diagnostics.note(line) }
        return diagnostics.text()
    }

    func testDropsAreReportedWithoutValues() throws {
        // 0.734519 of the travel is 157.52304 bpm: neither may appear anywhere in the report.
        let text = try strapRun(packets: [0...100, 121...200], value: 0.734519, seconds: 260)
        let report = DiagnosticReport(log: text)
        let drop = try XCTUnwrap(report.findings.first)
        XCTAssertEqual(report.findings.count, 1, "\(report.findings)")
        XCTAssertEqual(drop.weight, .notice)
        XCTAssertEqual(drop.run, .latest)
        XCTAssertEqual(drop.title,
                       "The heart rate strap stopped measuring 2 times; the longest gap was 17 s, and after the last it was not measured again.")
        XCTAssertEqual(drop.count, 2)
        XCTAssertEqual(drop.evidence, report.lines.filter { $0.event == "body: strap lost" }.map(\.text))
        XCTAssertEqual(drop.evidence.map { DiagnosticReport.parse($0, run: .latest)?.number("measured_s") }, [104, 83],
                       "each loss says how long the strap had measured: the last packet ages out after three seconds")

        let body = report.lines.filter { $0.event.hasPrefix("body: ") }
        XCTAssertEqual(body.map(\.event), ["body: strap started", "body: strap lost", "body: strap regained",
                                           "body: strap lost", "body: strap stopped"])
        for line in body {
            XCTAssertTrue(Set(line.fields.keys).isSubset(of: ["measured_s", "absent_s"]), "durations only: \(line.text)")
        }
        let shown = report.markdown
        for reading in ["0.734519", "0.7345", "157.523", "157.52"] {
            XCTAssertFalse(shown.contains(reading), "a reading reached the report: \(reading)")
        }
    }

    func testAPauseByIOSOrAVideoTakeIsNoDrop() throws {
        let paused = [
            "2026-11-27T10:27:00.000Z  body: camera started",
            "2026-11-27T10:27:40.000Z  body: camera lost (paused by iOS) measured_s=40",
            "2026-11-27T10:27:52.000Z  body: camera regained absent_s=12",
            "2026-11-27T10:28:22.000Z  body: camera lost (a video take holds the camera) measured_s=30",
            "2026-11-27T10:29:57.500Z  body: camera regained absent_s=95.5",
        ]
        XCTAssertTrue(DiagnosticReport(log: log([launch] + paused)).findings.isEmpty,
                      "iOS and a take give the camera back by themselves: nothing to try")

        let report = DiagnosticReport(log: log([launch] + paused + [
            "2026-11-27T10:30:30.000Z  body: camera lost (no reading) measured_s=32.5",
            "2026-11-27T10:30:36.125Z  body: camera regained absent_s=6.125",
            "2026-11-27T10:31:00.000Z  body: camera lost (no reading) measured_s=23.875",
            "2026-11-27T10:31:12.500Z  body: camera regained absent_s=12.5",
            "2026-11-27T10:32:00.000Z  body: camera stopped measured_s=47.5",
        ]))
        let drop = try XCTUnwrap(report.findings.first)
        XCTAssertEqual(report.findings.count, 1)
        XCTAssertEqual(drop.title, "The camera pulse stopped measuring 2 times; the longest gap was 12.5 s.",
                       "the gaps are those of its own losses, quoted as the log wrote them")
        XCTAssertEqual(drop.count, 2)
        XCTAssertTrue(drop.evidence.allSatisfy { $0.contains("(no reading)") }, "\(drop.evidence)")
    }

    func testEachBodySourceSaysWhatToTry() {
        let report = DiagnosticReport(log: log([
            launch,
            "2026-11-27T10:27:00.000Z  body: strap lost (disconnected) measured_s=60",
            "2026-11-27T10:27:09.000Z  body: strap regained absent_s=9",
            "2026-11-27T10:28:00.000Z  body: camera lost (failed) measured_s=31.5",
            "2026-11-27T10:29:00.000Z  body: apple health lost (no reading) measured_s=120",
            "2026-11-27T10:30:00.000Z  body: phone motion lost (no reading) measured_s=4.25",
        ]))
        XCTAssertEqual(report.findings.map(\.weight), [.notice, .notice, .notice, .notice])
        XCTAssertEqual(report.findings.map(\.title), [
            "The heart rate strap stopped measuring once, for 9 s.",
            "The camera pulse stopped measuring once and was not measured again.",
            "The Apple Health pulse stopped measuring once and was not measured again.",
            "Phone Motion stopped measuring once and was not measured again.",
        ])
        let tries = report.findings.map(\.suggestion)
        XCTAssertEqual(tries.count, 4)
        guard tries.count == 4 else { return }
        XCTAssertTrue(tries[0].contains("battery") && tries[0].contains("skin"), tries[0])
        XCTAssertTrue(tries[0].contains("No strap found") && tries[0].contains("Off and then Heart Rate Strap"),
                      "the app searches once after a lost link; the way back is the musician's: \(tries[0])")
        XCTAssertTrue(tries[1].contains("fingertip") && tries[1].contains("flash") && tries[1].contains("off and on again"), tries[1])
        XCTAssertTrue(tries[1].contains("lamp"), "a bright lamp reads too, as the camera's cue says: \(tries[1])")
        XCTAssertTrue(tries[0].contains("Off stops Phone Motion too") && tries[1].contains("Off stops Phone Motion too"),
                      "advice that goes through Off says what else Off stops")
        XCTAssertTrue(tries[2].contains("Watch") && tries[2].contains("synced"), tries[2])
        XCTAssertTrue(tries[3].contains("next sample"), tries[3])
        XCTAssertEqual(Set(tries).count, 4, "each source its own")
    }

    func testABodyLineEditedInTheFileCannotStopTheReport() throws {
        let report = DiagnosticReport(log: log([
            launch,
            "2026-11-27T10:27:00.000Z  body: strap regained absent_s=5",
            "2026-11-27T10:27:10.000Z  body: strap lost",
            "2026-11-27T10:27:20.000Z  body: strap regained absent_s=nan",
            "2026-11-27T10:27:30.000Z  body: strap lost (no reading) measured_s=-1e300",
            "2026-11-27T10:27:40.000Z  body: strap regained absent_s=1e300",
            "2026-11-27T10:27:50.000Z  body: strap lost (something new) measured_s=2",
            "2026-11-27T10:28:00.000Z  body: strap regained absent_s=-4",
        ]))
        let drop = try XCTUnwrap(report.findings.first)
        XCTAssertEqual(drop.count, 3, "a regain without a loss before it is no loss, and a reason not known is still one")
        XCTAssertEqual(drop.title, "The heart rate strap stopped measuring 3 times; the longest gap was 1e300 s.")
    }

    func testAStartAStopOrAPauseEndsALossThatWasNotMeasuredAgain() {
        // An order the app does not write (an edited file): a regain after a stop and a start, or after
        // a pause, belongs to no loss before them.
        let report = DiagnosticReport(log: log([
            launch,
            "2026-11-27T10:27:00.000Z  body: strap lost (no reading) measured_s=60",
            "2026-11-27T10:27:30.000Z  body: strap stopped measured_s=0",
            "2026-11-27T10:28:00.000Z  body: strap started",
            "2026-11-27T10:28:05.000Z  body: strap regained absent_s=65",
            "2026-11-27T10:29:00.000Z  body: camera lost (no reading) measured_s=40",
            "2026-11-27T10:29:10.000Z  body: camera lost (paused by iOS) measured_s=0",
            "2026-11-27T10:29:22.000Z  body: camera regained absent_s=22",
        ]))
        XCTAssertEqual(report.findings.map(\.title), [
            "The heart rate strap stopped measuring once and was not measured again.",
            "The camera pulse stopped measuring once and was not measured again.",
        ])
    }

    func testALossWhileTheAppWasInTheBackgroundIsCountedApart() throws {
        let report = DiagnosticReport(log: log([
            launch,
            "2026-11-27T10:27:00.000Z  body: strap started",
            "2026-11-27T10:30:00.000Z  app: inactive",
            "2026-11-27T10:30:00.250Z  app: background",
            "2026-11-27T10:30:10.000Z  app: inactive",
            "2026-11-27T10:30:10.125Z  app: active",
            "2026-11-27T10:30:10.500Z  body: strap lost (no reading) measured_s=190.5",
            "2026-11-27T10:30:11.750Z  body: strap regained absent_s=1.25",
            "2026-11-27T10:40:00.000Z  body: strap lost (disconnected) measured_s=588.25",
            "2026-11-27T10:40:09.000Z  body: strap regained absent_s=9",
        ]))
        let drop = try XCTUnwrap(report.findings.first)
        XCTAssertEqual(report.findings.count, 1, "\(report.findings)")
        XCTAssertEqual(drop.weight, .notice, "one of the losses came with the app on the screen")
        XCTAssertEqual(drop.title,
                       "The heart rate strap stopped measuring 2 times, one of them while the app was in the background; the longest gap was 9 s.",
                       "the loss found just after the app came back belongs to the time away")
        XCTAssertEqual(drop.count, 2)
        XCTAssertEqual(drop.evidence.count, 2)
        XCTAssertTrue(drop.suggestion.hasPrefix("Check the strap's battery"), drop.suggestion)
        XCTAssertTrue(drop.suggestion.hasSuffix("keep it on the screen while a body source should move the song."), drop.suggestion)
    }

    func testLossesThatAllCameWhileAwayAreANoteWithoutTheSourcesAdvice() throws {
        let awayAndBack = DiagnosticReport(log: log([
            launch,
            "2026-11-27T10:27:00.000Z  body: strap started",
            "2026-11-27T10:30:00.250Z  app: background",
            "2026-11-27T10:30:04.000Z  body: strap lost (no reading) measured_s=184",
            "2026-11-27T10:30:20.000Z  app: active",
            "2026-11-27T10:30:21.000Z  body: strap regained absent_s=17",
            "2026-11-27T10:45:00.000Z  app: background",
            "2026-11-27T10:45:30.000Z  app: active",
            "2026-11-27T10:45:30.400Z  body: strap lost (no reading) measured_s=909.4",
            "2026-11-27T10:45:31.400Z  body: strap regained absent_s=1",
        ]))
        let finding = try XCTUnwrap(awayAndBack.findings.first)
        XCTAssertEqual(awayAndBack.findings.count, 1)
        XCTAssertEqual(finding.weight, .note, "leaving the screen and coming back explains them")
        XCTAssertEqual(finding.title,
                       "The heart rate strap stopped measuring 2 times, each while the app was in the background; the longest gap was 17 s.")
        XCTAssertFalse(finding.suggestion.contains("battery"), "nothing about the strap to fix: \(finding.suggestion)")
        XCTAssertTrue(finding.suggestion.contains("on the screen"), finding.suggestion)
        XCTAssertTrue(awayAndBack.markdown.contains(DiagnosticReport.nothingFound), "time away alone is no fault")

        let endedAway = DiagnosticReport(log: log([
            launch,
            "2026-11-27T10:50:00.000Z  body: phone motion started",
            "2026-11-27T10:55:00.000Z  app: background",
            "2026-11-27T10:55:00.600Z  body: phone motion lost (no reading) measured_s=300.6",
        ]))
        let unfinished = try XCTUnwrap(endedAway.findings.first)
        XCTAssertEqual(unfinished.weight, .notice, "it was not measured again, so the source's own advice stays")
        XCTAssertEqual(unfinished.title,
                       "Phone Motion stopped measuring once, while the app was in the background, and was not measured again.")
        XCTAssertTrue(unfinished.suggestion.contains("next sample") && unfinished.suggestion.contains("on the screen"),
                      unfinished.suggestion)
    }

    func testTheTimeAwayEndsFiveSecondsAfterTheAppIsBack() throws {
        let report = DiagnosticReport(log: log([
            launch,
            "2026-11-27T10:27:00.000Z  body: phone motion started",
            "2026-11-27T10:28:00.000Z  app: inactive",
            "2026-11-27T10:28:02.000Z  app: active",
            "2026-11-27T10:28:03.000Z  body: phone motion lost (no reading) measured_s=63",
            "2026-11-27T10:28:10.000Z  body: phone motion regained absent_s=7",
            "2026-11-27T10:30:00.000Z  app: background",
            "2026-11-27T10:30:30.000Z  app: active",
            "2026-11-27T10:30:34.900Z  body: phone motion lost (no reading) measured_s=144.9",
            "2026-11-27T10:30:40.000Z  body: phone motion regained absent_s=5.1",
            "2026-11-27T10:32:00.000Z  app: background",
            "2026-11-27T10:32:30.000Z  app: active",
            "2026-11-27T10:32:35.100Z  body: phone motion lost (no reading) measured_s=115.1",
            "2026-11-27T10:32:44.000Z  body: phone motion regained absent_s=8.9",
        ]))
        let drop = try XCTUnwrap(report.findings.first)
        XCTAssertEqual(drop.title,
                       "Phone Motion stopped measuring 3 times, one of them while the app was in the background; the longest gap was 8.9 s.",
                       "Control Centre alone is no time away; 4.9 s after coming back still is, 5.1 s is not")
        XCTAssertEqual(drop.weight, .notice)
    }
}
