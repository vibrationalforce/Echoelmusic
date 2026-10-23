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
                       "== this run ==\n2026-10-23T01:15:00.250Z  app: launch v11.0.0 (10023)\n",
                       "the folder is made, and the first line names the build")
    }

    func testAVersionThatIsNotDigitsAndDotsIsAQuestionMark() throws {
        let diagnostics = log(at: try folder().appendingPathComponent("a.log"))
        diagnostics.begin(version: "11.0 My Song", build: "")
        let text = diagnostics.text()
        XCTAssertTrue(text.contains("app: launch v? (?)"), text)
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
        let previous = try XCTUnwrap(text.range(of: DiagnosticLog.previousRunHeader + "\n"))
        let this = try XCTUnwrap(text.range(of: DiagnosticLog.thisRunHeader + "\n"))
        XCTAssertLessThan(previous.lowerBound, this.lowerBound)
        XCTAssertTrue(text[previous.upperBound..<this.lowerBound].contains("app: launch v11.0.0 (2)"))
        XCTAssertTrue(text[previous.upperBound..<this.lowerBound].contains("run two"))
        XCTAssertTrue(text[this.upperBound...].contains("run three"))
        XCTAssertEqual(text.components(separatedBy: DiagnosticLog.thisRunHeader).count, 2, "one header for this run")
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
        XCTAssertTrue(text.hasSuffix(DiagnosticLog.fullLine + "\n"))
        XCTAssertEqual(text.components(separatedBy: DiagnosticLog.fullLine).count, 2, "said once")
        // Two full runs stay bounded too.
        let next = log(at: url, capacity: capacity)
        next.begin(version: "11.0.0", build: "2")
        for _ in 0..<100 { next.note("route: change", [("reason", 2)]) }
        XCTAssertLessThanOrEqual(next.text().utf8.count, 2 * capacity + DiagnosticLog.previousRunHeader.utf8.count + 1)
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
        XCTAssertEqual(line, "record: writing failed error=\(error._domain) code=\(error._code)")
        XCTAssertTrue(line.contains("NamedError"), line)
        XCTAssertFalse(diagnostics.text().contains("Secret"), "a description can carry a name")
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
        XCTAssertTrue(diagnostics.text().hasPrefix(DiagnosticLog.thisRunHeader + "\n"))
        XCTAssertFalse(diagnostics.text().contains("someone"))
    }

    func testTheTimeIsUTCToTheMillisecond() {
        XCTAssertEqual(DiagnosticLog.timestamp(Self.moment), "2026-10-23T01:15:00.250Z")
        XCTAssertEqual(DiagnosticLog.timestamp(Date(timeIntervalSince1970: 951_782_400)), "2000-02-29T00:00:00.000Z")
        XCTAssertEqual(DiagnosticLog.timestamp(Date(timeIntervalSince1970: -1.5)), "1969-12-31T23:59:58.500Z")
        XCTAssertEqual(DiagnosticLog.timestamp(Date(timeIntervalSince1970: 0)), "1970-01-01T00:00:00.000Z")
    }
}
