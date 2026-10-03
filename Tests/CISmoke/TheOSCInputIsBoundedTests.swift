// TheOSCInputIsBoundedTests.swift
//
// Echoel — audit 2026-10-03, slice SEC-1.
//
// THE DEFECT. `OSCReceiver` is opt-in and its allowlist is EMPTY by default — any sender on
// the network the OS delivers from. Three costs were unbounded for such a sender:
//   · UDP gives every new source address its own `NWConnection`, and `connections` only grew;
//     datagrams from many spoofed ports held state without limit.
//   · Every accepted cue wrote one `EchoelCrashLog.breadcrumb` line — a `write(2)` into the
//     exported diag file — so a console re-sending a value at 60 Hz wrote 60 lines a second and
//     buried the lifecycle ladder a crash read depends on.
//   · Every identical repeat was dispatched again on the main actor.
//
// THE REPAIR. A ceiling of `maxConnections` that drops the OLDEST (a fresh sender still gets
// through), an identical-command window that drops only repeats (a CHANGED value always
// passes, so nothing is lost), and a breadcrumb only on a change, at most once per window.
//
// ⚠️ THE LIMIT. Claim 1 is END-TO-END on the shipped constants. Claims 2–4 are SOURCE-TEXT
// SCANS: a flood test over the loopback would be the known OSC-loopback flake times a thousand
// (`testALoopbackCueReachesTheDispatch` is the one runtime proof, and it still passes — it sends
// two DIFFERENT datagrams). Behaviour under a real flood is a DEVICE PROBE, open.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheOSCInputIsBoundedTests: XCTestCase {

    private static let receiver = "Sources/Echoelmusic/Sync/OSCReceiver.swift"

    #if canImport(Network)
    /// Claim 1 — the two bounds exist and are small enough to bound something.
    func testTheBoundsAreSmall() {
        XCTAssertGreaterThan(OSCReceiver.maxConnections, 0, "a ceiling of 0 refuses every sender (SEC-1)")
        XCTAssertLessThanOrEqual(OSCReceiver.maxConnections, 64,
                                 "the connection ceiling no longer bounds anything (SEC-1)")
        XCTAssertGreaterThan(OSCReceiver.repeatWindow, 0)
        XCTAssertLessThanOrEqual(OSCReceiver.repeatWindow, 0.25,
                                 "a long repeat window delays a re-sent cue a performer can hear (SEC-1)")
    }
    #endif

    /// Claim 2 — the ceiling is enforced where a connection is ADDED, before the append, and
    /// it evicts the oldest instead of refusing the newcomer.
    func testTheConnectionListHasACeiling() throws {
        let src = SourceText.codeOnly(try text(Self.receiver))
        guard let cap = src.range(of: "if connections.count >= Self.maxConnections {"),
              let append = src.range(of: "connections.append(connection)") else {
            XCTFail("ANCHOR MISSING: the ceiling or the append moved — re-anchor (#408)")
            return
        }
        XCTAssertLessThan(cap.lowerBound, append.lowerBound,
                          "the ceiling is checked after the append — it bounds nothing (SEC-1)")
        XCTAssertTrue(src.contains("connections.removeFirst().cancel()"),
                      "the ceiling no longer evicts the oldest connection (SEC-1)")
        XCTAssertEqual(src.components(separatedBy: "connections.append(").count - 1, 1,
                       "a second append site would bypass the ceiling (SEC-1)")
    }

    /// Claim 3 — only an IDENTICAL repeat is dropped; the comparison is on the command, not on
    /// its rounded summary (two tempos 0.2 BPM apart share a summary and must both pass).
    func testOnlyIdenticalRepeatsAreDropped() throws {
        let src = SourceText.codeOnly(try text(Self.receiver))
        XCTAssertTrue(src.contains("if command == lastCommand, now - lastReceivedTimestamp < Self.repeatWindow { return }"),
                      "the repeat window no longer compares the command itself (SEC-1)")
        XCTAssertTrue(src.contains("lastCommand = nil"), "a stopped socket keeps a stale repeat filter (SEC-1)")
    }

    /// Claim 4 — the diag-log line is written only on a change, rate-limited, and it sits
    /// BEFORE the dispatch (a ladder rung stands before its call).
    func testTheBreadcrumbIsBounded() throws {
        let src = SourceText.codeOnly(try text(Self.receiver))
        guard let gate = src.range(of: "if changed, now - lastBreadcrumbAt >= Self.repeatWindow {"),
              let crumb = src.range(of: "EchoelCrashLog.breadcrumb(\"osc in: \\(summary)\")"),
              let dispatch = src.range(of: "onCommand?(command)") else {
            XCTFail("ANCHOR MISSING: the breadcrumb gate, the line or the dispatch moved (#408)")
            return
        }
        XCTAssertLessThan(gate.lowerBound, crumb.lowerBound)
        XCTAssertLessThan(crumb.lowerBound, dispatch.lowerBound,
                          "the breadcrumb sits after the dispatch — a crash inside it leaves no rung")
        XCTAssertFalse(src.contains("EchoelCrashLog.breadcrumb(\"osc in: \\(command.summary)\")"),
                       "the unbounded per-cue breadcrumb is back (SEC-1)")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
