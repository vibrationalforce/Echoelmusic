import Foundation
import XCTest
@testable import EchoelCore

/// The local log the musician exports: what a line holds, what a run keeps, where it stops.
final class DiagnosticLogTests: XCTestCase {
    private static let moment = Date(timeIntervalSince1970: 1_792_718_100.25)

    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("diag-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func log(at url: URL, capacity: Int = 256 * 1024) -> DiagnosticLog {
        DiagnosticLog(url: url, capacity: capacity, clock: { DiagnosticLogTests.moment })
    }

    func testARunStartsWithItsVersionAndBuild() throws {
        let url = try folder().appendingPathComponent("Diagnostics/Echoel diagnostics.log")
        let diagnostics = log(at: url)
        diagnostics.begin(version: "11.0.0", build: "10023")
        XCTAssertEqual(diagnostics.text(),
                       "== latest run ==\n2026-10-23T01:15:00.250Z  app: launch v11.0.0 (10023), times in UTC\n",
                       "the folder is made, and the first line names the build")
    }

    func testAVersionThatIsNotDigitsAndDotsIsAQuestionMark() throws {
        let diagnostics = log(at: try folder().appendingPathComponent("a.log"))
        diagnostics.begin(version: "11.0 My Song", build: "")
        let text = diagnostics.text()
        XCTAssertTrue(text.contains("app: launch v? (?), times in UTC"), text)
        XCTAssertFalse(text.contains("Song"))
    }

    func testANoteIsInTheFileBeforeItReturns() throws {
        let url = try folder().appendingPathComponent("a.log")
        let diagnostics = log(at: url)
        diagnostics.begin(version: "11.0.0", build: "1")
        let attach = diagnostics.note("graph: attach source node", [("Hz", 48_000), ("ch", 2)])
        XCTAssertEqual(attach, "graph: attach source node Hz=48000 ch=2")
        XCTAssertEqual(diagnostics.note("engine: rebuilding", because: "interruption ended"),
                       "engine: rebuilding (interruption ended)")
        XCTAssertEqual(diagnostics.note("engine: trying again", [("s", 0.25), ("odd", .nan)]),
                       "engine: trying again s=0.25 odd=nan")
        // Read past the log, as the next launch would after a crash: nothing waits in a buffer.
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
        XCTAssertEqual(Array(lines.suffix(3)), [
            "2026-10-23T01:15:00.250Z  graph: attach source node Hz=48000 ch=2",
            "2026-10-23T01:15:00.250Z  engine: rebuilding (interruption ended)",
            "2026-10-23T01:15:00.250Z  engine: trying again s=0.25 odd=nan",
        ])
    }

    func testANewRunKeepsTheLastRunAndDropsTheOneBefore() throws {
        let url = try folder().appendingPathComponent("a.log")
        let first = log(at: url)
        first.begin(version: "11.0.0", build: "1")
        first.note("run one")
        // A run that ended without closing anything, as a crash ends it.
        let second = log(at: url)
        second.begin(version: "11.0.0", build: "2")
        second.note("run two")
        let third = log(at: url)
        third.begin(version: "11.0.0", build: "3")
        third.note("run three")
        let text = third.text()
        XCTAssertFalse(text.contains("run one"), "two runs back is gone")
        let previous = try XCTUnwrap(text.range(of: DiagnosticLog.runBeforeHeader + "\n"))
        let this = try XCTUnwrap(text.range(of: DiagnosticLog.latestRunHeader + "\n"))
        XCTAssertLessThan(previous.lowerBound, this.lowerBound)
        XCTAssertTrue(text[previous.upperBound..<this.lowerBound].contains("app: launch v11.0.0 (2)"))
        XCTAssertTrue(text[previous.upperBound..<this.lowerBound].contains("run two"))
        XCTAssertTrue(text[this.upperBound...].contains("run three"))
        XCTAssertEqual(text.components(separatedBy: DiagnosticLog.latestRunHeader).count, 2, "one header for the latest run")
    }

    func testARunStopsAtItsCapacityWithOneLastLine() throws {
        let url = try folder().appendingPathComponent("a.log")
        let capacity = 1024
        let diagnostics = log(at: url, capacity: capacity)
        diagnostics.begin(version: "11.0.0", build: "1")
        for _ in 0..<100 {
            XCTAssertEqual(diagnostics.note("route: change", [("reason", 2)]), "route: change reason=2",
                           "the line still reaches os_log")
        }
        let text = diagnostics.text()
        XCTAssertLessThanOrEqual(text.utf8.count, capacity)
        XCTAssertTrue(text.hasSuffix("2026-10-23T01:15:00.250Z  " + DiagnosticLog.fullLine + "\n"), "with its time")
        XCTAssertEqual(text.components(separatedBy: DiagnosticLog.fullLine).count, 2, "said once")
        // Two full runs stay bounded too.
        let next = log(at: url, capacity: capacity)
        next.begin(version: "11.0.0", build: "2")
        for _ in 0..<100 { next.note("route: change", [("reason", 2)]) }
        XCTAssertLessThanOrEqual(next.text().utf8.count, 2 * capacity + DiagnosticLog.runBeforeHeader.utf8.count + 1)
    }

    private enum NamedError: Error, LocalizedError {
        case gone(String)
        case unreadable(String)
        var errorDescription: String? {
            switch self {
            case .gone(let name), .unreadable(let name): return "The song \(name) could not be read."
            }
        }
    }

    func testAnErrorIsWrittenByDomainAndCodeNeverByItsDescription() throws {
        let diagnostics = log(at: try folder().appendingPathComponent("a.log"))
        diagnostics.begin(version: "11.0.0", build: "1")
        let error = NamedError.unreadable("My Secret Song")
        let line = diagnostics.note("record: writing failed", error: error)
        XCTAssertEqual(line, "record: writing failed error=\(DiagnosticLog.domain(error._domain)) code=\(error._code)")
        XCTAssertTrue(line.contains("NamedError"), line)
        XCTAssertFalse(diagnostics.text().contains("Secret"), "a description can carry a name")
    }

    /// A crash or a lost battery can cut the last line inside a character; the run before it is
    /// still what the next file carries (review 008, round 1).
    func testABrokenByteDoesNotCostTheRunBefore() throws {
        let url = try folder().appendingPathComponent("a.log")
        var bytes = Data((DiagnosticLog.latestRunHeader + "\n2026-10-23T01:14:59.000Z  engine: start\n"
            + "2026-10-23T01:15:00.000Z  graph: connect source ").utf8)
        bytes.append(contentsOf: [0xE2, 0x86])   // the first two bytes of "→", the third never came
        try bytes.write(to: url)
        let diagnostics = log(at: url)
        diagnostics.begin(version: "11.0.0", build: "2")
        let text = diagnostics.text()
        let before = try XCTUnwrap(text.range(of: DiagnosticLog.runBeforeHeader + "\n"))
        let latest = try XCTUnwrap(text.range(of: DiagnosticLog.latestRunHeader + "\n"))
        XCTAssertTrue(text[before.upperBound..<latest.lowerBound].contains("engine: start"), text)
        XCTAssertTrue(text[before.upperBound..<latest.lowerBound].contains("graph: connect source"), "the cut line keeps what it has")
    }

    /// Only lines in the log's own shape move on: a line someone added to the file in Files does
    /// not reach the next file the musician shares.
    func testOnlyTheLogsOwnLinesAreCarriedOver() throws {
        let url = try folder().appendingPathComponent("a.log")
        try Data((DiagnosticLog.latestRunHeader + "\n2026-10-23T01:14:59.000Z  engine: start\n"
            + "My Secret Song\n2026-10-23T01:15:00.000Z  engine: stop for configure input=0\n").utf8).write(to: url)
        let diagnostics = log(at: url)
        diagnostics.begin(version: "11.0.0", build: "2")
        let text = diagnostics.text()
        XCTAssertFalse(text.contains("Secret"))
        XCTAssertTrue(text.contains("2026-10-23T01:14:59.000Z  engine: start\n2026-10-23T01:15:00.000Z  engine: stop"), text)
    }

    /// A file far larger than two runs is read only at its end, and what it carries over fits one run.
    func testAnOversizedFileIsReadOnlyAtItsEnd() throws {
        let url = try folder().appendingPathComponent("a.log")
        let capacity = 1024
        var junk = String(repeating: "x", count: 40 * capacity)
        junk += "\n" + DiagnosticLog.latestRunHeader + "\n"
        // About 1,500 bytes: more than one run may carry, less than the end the log reads.
        for index in 0..<30 { junk += "2026-10-23T01:15:00.000Z  route: change reason=\(index)\n" }
        try Data(junk.utf8).write(to: url)
        let diagnostics = log(at: url, capacity: capacity)
        diagnostics.begin(version: "11.0.0", build: "2")
        let text = diagnostics.text()
        XCTAssertTrue(text.contains("route: change reason=29\n"), "the newest lines come over")
        XCTAssertFalse(text.contains("reason=0\n"), "the oldest do not fit")
        XCTAssertFalse(text.contains("reason=9\n"), "the oldest do not fit")
        XCTAssertFalse(text.contains("xxx"))
        XCTAssertLessThanOrEqual(text.utf8.count, 2 * capacity + DiagnosticLog.runBeforeHeader.utf8.count + 1)
    }

    /// An error domain is a developer's string; whatever it holds, the line stays one line.
    func testAnErrorDomainStaysOneShortLine() throws {
        let diagnostics = log(at: try folder().appendingPathComponent("a.log"))
        diagnostics.begin(version: "11.0.0", build: "1")
        let odd = NSError(domain: "bad\ndomain (with) spaces", code: 7)
        XCTAssertEqual(diagnostics.note("engine: configure failed", error: odd),
                       "engine: configure failed error=bad_domain__with__spaces code=7")
        let long = NSError(domain: String(repeating: "a", count: 100), code: 1)
        XCTAssertEqual(diagnostics.note("engine: configure failed", error: long),
                       "engine: configure failed error=\(String(repeating: "a", count: 64)) code=1")
        XCTAssertEqual(diagnostics.text().split(separator: "\n").count, 4, "header, launch and two lines")
    }

    func testALogItCannotWriteStaysSilent() throws {
        let blocker = try folder().appendingPathComponent("not a folder")
        try Data("x".utf8).write(to: blocker)
        let diagnostics = log(at: blocker.appendingPathComponent("a.log"))
        diagnostics.begin(version: "11.0.0", build: "1")
        XCTAssertEqual(diagnostics.note("engine: start"), "engine: start")
        XCTAssertEqual(diagnostics.text(), "")
    }

    func testANoteBeforeTheRunBeganIsDropped() throws {
        let url = try folder().appendingPathComponent("a.log")
        let diagnostics = log(at: url)
        diagnostics.note("engine: start")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testAFileThisLogDidNotWriteIsNotCarriedOver() throws {
        let url = try folder().appendingPathComponent("a.log")
        try Data("someone else's text\n".utf8).write(to: url)
        let diagnostics = log(at: url)
        diagnostics.begin(version: "11.0.0", build: "1")
        XCTAssertTrue(diagnostics.text().hasPrefix(DiagnosticLog.latestRunHeader + "\n"))
        XCTAssertFalse(diagnostics.text().contains("someone"))
    }

    func testTheTimeIsUTCToTheMillisecond() {
        XCTAssertEqual(DiagnosticLog.timestamp(Self.moment), "2026-10-23T01:15:00.250Z")
        XCTAssertEqual(DiagnosticLog.timestamp(Date(timeIntervalSince1970: 951_782_400)), "2000-02-29T00:00:00.000Z")
        XCTAssertEqual(DiagnosticLog.timestamp(Date(timeIntervalSince1970: -1.5)), "1969-12-31T23:59:58.500Z")
        XCTAssertEqual(DiagnosticLog.timestamp(Date(timeIntervalSince1970: 0)), "1970-01-01T00:00:00.000Z")
    }
}
