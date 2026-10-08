// TheMainThreadIsWatchedTests.swift
// Echoel — GMMW SH-9. A frozen menu (10.76.48) and an iOS watchdog kill (0x8badf00d, a SIGKILL
// the crash handler never sees) both ended the diag log in silence, because nothing on the main
// thread can write while the main thread is what hangs. `MainThreadWatchdog` stands outside it: a
// utility-queue timer pings the main queue every 250 ms and writes a `main:` line when a ping
// stays unanswered for a second — while the stall lasts — then at 2, 4, 8 … s, once when it ends,
// and one summary line per 30 s. The meaning lives in a pure value type,
// `MainThreadLatencyLedger`, so the claims below drive it on a clock they own.
//
// WHAT IT PINS (Tests/CISmoke/CLAUDE.md §1) — claims 1–6 are END-TO-END on the ledger (internal,
// Foundation-only, reached through `@testable`); claims 7–8 are SOURCE-TEXT SCANS (the timer, the
// main-queue hop and the lifecycle wiring cannot run in a bundle without waiting on real time);
// claim 9 is END-TO-END on `EchoelCrashLog`'s two log readers. DEVICE PROBE, open: that a real
// stall shows up in an exported `echoel_diag.log`, and that a watchdog kill ends the log in a
// `main: still stalled` line.
// 1. A main thread that answers writes nothing but the summary, and pings at most every tick.
// 2. A stall is written WHILE it lasts (1 s, then 2, 4, 8 s) and once when it ends; no second
//    ping is handed to a main queue that has not answered the first.
// 3. A late tick does not repeat rungs it skipped; a stall no tick saw still writes one line and
//    still counts.
// 4. An answer to a ping the ledger is not waiting on (one sent before a pause), and a
//    non-finite time, change nothing.
// 5. The summary counts a stall that is still going on, and starts a fresh window.
// 6. Durations read as whole milliseconds below a second and tenths above it.
// 7. The owner is not `@MainActor`, holds nothing observable, and every closure it hands to
//    Dispatch is spelled `@Sendable` (the build-2613 trap); the timer runs on a utility queue.
// 8. The app starts it once, after `startup 4/4`; pauses it in the `.background` branch, after
//    the launch confirm; resumes it in the `.active` branch; nothing else calls it.
// 9. No line it can write reads as a crash marker or as a scene transition to the next launch.
//
// HONEST GRADING (§3). The file names a new type — it does not compile on its parent
// (`ff2064b`), so every claim is FORWARD: no assertion here has a verdict there, and the source
// scans of claims 7–8 are red there by ANCHOR ABSENCE (no watchdog file, no call in the app).
// Transcribed in Python against the worktree: the ledger is re-implemented line for line and
// driven through claims 1–6 and 9; the scans of 7–8 run over the same `codeOnly` text. MUTANTS,
// each red for its named reason: a stall line on every tick instead of doubling → 2; a ping sent
// while one is outstanding → 2; skipped rungs repeated → 3; the unseen-stall line dropped → 3; the
// id check dropped → 4; the summary without the ongoing wait → 5; `seconds < 1` in place of the
// rounded milliseconds → 6; `@MainActor` on the class → 7; one `.async {` without `@Sendable`
// → 7; the pause outside the `.background` branch → 8; a second `start()` → 8; "CRASH" in a line
// → 9; "scene: " in a line → 9.

import Foundation
import XCTest
@testable import Echoelmusic

private struct WatchAnchorMissing: Error, CustomStringConvertible {
    let reason: String
    var description: String { reason }
}

final class TheMainThreadIsWatchedTests: XCTestCase {

    private typealias Ledger = MainThreadLatencyLedger
    private static let watchdog = "Sources/Echoelmusic/Core/MainThreadWatchdog.swift"
    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"

    /// Tick `k` of a ledger started at 0 runs at `k × pingSeconds` (exact in binary).
    private func tickTime(_ k: Int) -> Double { Double(k) * Ledger.pingSeconds }

    // MARK: 1 — a main thread that answers

    func testAnAnsweringMainThreadWritesOnlyTheSummary() {
        var ledger = Ledger(startedAt: 0)
        var lines: [String] = []
        var pings = 0
        for k in 1...120 {
            let (ping, written) = ledger.tick(at: tickTime(k))
            lines += written
            if let id = ping {
                pings += 1
                lines += ledger.answer(id, at: tickTime(k) + 0.005)
            }
        }
        XCTAssertEqual(pings, 120, "one ping per tick while every ping is answered")
        XCTAssertEqual(lines, ["main: 30 s — answered 119, worst 5 ms, stalls 0"], """
            A main thread that answers within milliseconds writes ONE summary line per 30 s and \
            nothing else — the 30 s tick writes it before it sends its own ping.
            """)
    }

    // MARK: 2 — a stall, while it lasts and when it ends

    func testAStallIsWrittenWhileItLastsAndOnceWhenItEnds() {
        var ledger = Ledger(startedAt: 0)
        guard let first = ledger.tick(at: tickTime(1)).ping else {
            return XCTFail("the first tick sends a ping")
        }
        var lines: [String] = []
        for k in 2...37 {                                   // 0.5 s … 9.25 s, no answer
            let (ping, written) = ledger.tick(at: tickTime(k))
            XCTAssertNil(ping, "a main queue that has not answered is never handed a second ping")
            lines += written
        }
        lines += ledger.answer(first, at: 9.55)
        XCTAssertEqual(lines, [
            "main: stalled — no answer for 1.0 s",
            "main: still stalled — no answer for 2.0 s",
            "main: still stalled — no answer for 4.0 s",
            "main: still stalled — no answer for 8.0 s",
            "main: recovered — answered after 9.3 s",
        ], "the stall speaks while it lasts, doubling, and once when it ends")
        XCTAssertNotNil(ledger.tick(at: 9.75).ping, "after the answer the next tick pings again")
    }

    // MARK: 3 — a late tick, and a stall no tick saw

    func testALateTickSkipsRungsAndAnUnseenStallStillCounts() {
        var late = Ledger(startedAt: 0)
        _ = late.tick(at: 0.25)
        XCTAssertEqual(late.tick(at: 5.25).lines, ["main: stalled — no answer for 5.0 s"])
        XCTAssertEqual(late.tick(at: 7.25).lines, [], "the 2 s and 4 s rungs already passed — not repeated")
        XCTAssertEqual(late.tick(at: 8.25).lines, ["main: still stalled — no answer for 8.0 s"])

        var unseen = Ledger(startedAt: 0)
        guard let id = unseen.tick(at: 0.25).ping else { return XCTFail("the first tick sends a ping") }
        XCTAssertEqual(unseen.answer(id, at: 1.75),
                       ["main: recovered — answered after 1.5 s (not seen while it lasted)"], """
            A stall that ended before any tick saw it (the utility queue starved too) still writes \
            ONE line — otherwise the stall count would miss exactly the worst kind.
            """)
        XCTAssertEqual(unseen.tick(at: 30).lines, ["main: 30 s — answered 1, worst 1.5 s, stalls 1"])
    }

    // MARK: 4 — answers the ledger is not waiting on

    func testAStaleAnswerOrABrokenClockChangesNothing() {
        var ledger = Ledger(startedAt: 0)
        guard let id = ledger.tick(at: 0.25).ping else { return XCTFail("the first tick sends a ping") }
        let before = ledger
        XCTAssertEqual(ledger.answer(id + 1, at: 0.3), [], "an answer to another ping writes nothing")
        XCTAssertEqual(ledger.answer(id, at: .nan), [], "a non-finite answer time writes nothing")
        let broken = ledger.tick(at: .infinity)
        XCTAssertNil(broken.ping)
        XCTAssertEqual(broken.lines, [])
        XCTAssertEqual(ledger, before, "none of the three changed the ledger")
        XCTAssertEqual(ledger.answer(id, at: 0.3), [], "the real answer still lands, quietly")
    }

    // MARK: 5 — the summary sees a stall that is still going on

    func testTheSummaryCountsAnOngoingStallAndStartsAFreshWindow() {
        var ledger = Ledger(startedAt: 0)
        _ = ledger.tick(at: 0.25)
        var lines: [String] = []
        for k in 2...120 { lines += ledger.tick(at: tickTime(k)).lines }
        guard let summary = lines.last else { return XCTFail("the 30 s tick writes a line") }
        XCTAssertTrue(summary.hasPrefix("main: 30 s — answered 0, worst 29."), "got `\(summary)`")
        XCTAssertTrue(summary.hasSuffix(" s, stalls 1"), "the stall that is still going on counts — got `\(summary)`")
        var next: [String] = []
        for k in 121...240 { next += ledger.tick(at: tickTime(k)).lines }
        XCTAssertTrue(next.contains { $0.hasPrefix("main: 30 s — answered 0, worst 59.") && $0.hasSuffix("stalls 0") },
                      "a fresh window: the same stall is not counted twice, but its wait is still the worst — got \(next)")
    }

    // MARK: 6 — durations

    func testDurationsReadAsMillisecondsThenTenths() {
        XCTAssertEqual(Ledger.duration(0.0042), "4 ms")
        XCTAssertEqual(Ledger.duration(0.9994), "999 ms")
        XCTAssertEqual(Ledger.duration(0.9996), "1.0 s", "a value that rounds to 1000 ms reads as a second")
        XCTAssertEqual(Ledger.duration(2.34), "2.3 s")
        XCTAssertEqual(Ledger.duration(-1), "0 ms")
        XCTAssertEqual(Ledger.duration(.nan), "?")
    }

    // MARK: 7 — the owner's isolation

    func testTheWatchIsNotOnTheMainActorAndEveryHandlerIsSendable() throws {
        let code = try source(Self.watchdog)
        for forbidden in ["@MainActor", "@Observable", "ObservableObject", "import SwiftUI", "import Observation"] {
            XCTAssertFalse(code.contains(forbidden), """
                `\(forbidden)` in the watchdog. It must stand OUTSIDE the main thread and publish \
                nothing to SwiftUI — a watch on the main actor stalls with what it watches, and an \
                observable one becomes a hot read itself.
                """)
        }
        XCTAssertTrue(code.contains("final class MainThreadWatchdog: @unchecked Sendable {"))
        XCTAssertTrue(code.contains("DispatchQueue(label: \"com.echoelmusic.main-watchdog\", qos: .utility)"),
                      "the timer runs on its own utility queue")
        XCTAssertTrue(code.contains("DispatchSource.makeTimerSource(queue: queue)"))
        let asyncs = occurrences(of: ".async {", in: code)
        XCTAssertGreaterThanOrEqual(asyncs, 5, "precondition: start, pause, resume, the ping and its hop back were read")
        XCTAssertEqual(occurrences(of: ".async { @Sendable in", in: code), asyncs,
                       "every closure handed to `async` is spelled `@Sendable` (build 2613)")
        XCTAssertEqual(occurrences(of: "setEventHandler {", in: code), 1)
        XCTAssertEqual(occurrences(of: "setEventHandler { @Sendable", in: code), 1,
                       "the timer's handler is spelled `@Sendable`")
        XCTAssertTrue(code.contains("DispatchQueue.main.async { @Sendable in"), "the ping is one block on the main queue")
    }

    // MARK: 8 — the lifecycle

    func testTheAppStartsItAtFourOfFourAndPausesItInTheBackground() throws {
        let app = try source(Self.app)
        XCTAssertEqual(occurrences(of: "MainThreadWatchdog.shared.start()", in: app), 1, "one start")
        XCTAssertEqual(occurrences(of: "MainThreadWatchdog.shared.pause(reason: \"background\")", in: app), 1, "one pause")
        XCTAssertEqual(occurrences(of: "MainThreadWatchdog.shared.resume()", in: app), 1, "one resume")
        XCTAssertEqual(occurrences(of: "MainThreadWatchdog.shared.", in: app), 3, "nothing else in the app calls it")

        let rung = try anchor("EchoelCrashLog.breadcrumb(\"startup 4/4: core ready — instrument live\")", in: app)
        let start = try anchor("MainThreadWatchdog.shared.start()", in: app)
        XCTAssertLessThan(rung.lowerBound, start.lowerBound, """
            The watch starts AFTER `startup 4/4`: Safe Mode and onboarding never reach that rung, and \
            a launch that is still building its graph would read as stalls.
            """)

        // The scene-phase handler, not `scenePhaseName`'s own `case .active:` near the top.
        let handler = try anchor(".onChange(of: scenePhase)", in: app)
        guard let active = app.range(of: "case .active:", range: handler.upperBound..<app.endIndex),
              let background = app.range(of: "wasBackgrounded = true", range: active.upperBound..<app.endIndex),
              let inactive = app.range(of: "case .inactive:", range: background.upperBound..<app.endIndex) else {
            throw WatchAnchorMissing(reason: "the scene-phase `.active` / `.background` / `.inactive` branches moved — re-anchor (#408)")
        }
        let activeBranch = String(app[active.upperBound..<background.lowerBound])
        let backgroundBranch = String(app[background.upperBound..<inactive.lowerBound])
        XCTAssertTrue(activeBranch.contains("MainThreadWatchdog.shared.resume()"), "the `.active` branch resumes it")
        let confirm = try anchor("confirmSteadyLaunch(trigger: \"first background\")", in: backgroundBranch)
        let pause = try anchor("MainThreadWatchdog.shared.pause(reason: \"background\")", in: backgroundBranch)
        XCTAssertLessThan(confirm.lowerBound, pause.lowerBound, "the launch confirm stays FIRST in the branch (SH-1)")

        let sources = try sourceFiles()
        XCTAssertGreaterThan(sources.count, 100, "precondition: the source tree was walked")
        for url in sources where !url.path.hasSuffix("/" + Self.app) && !url.path.hasSuffix("/" + Self.watchdog) {
            let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
            XCTAssertFalse(code.contains("MainThreadWatchdog.shared"),
                           "\(url.lastPathComponent) calls the watch — one owner, the app")
        }
    }

    // MARK: 9 — no line reads as something else

    func testNoWatchLineReadsAsACrashOrASceneTransition() throws {
        var lines: [String] = []
        var ledger = Ledger(startedAt: 0)
        let first = ledger.tick(at: 0.25).ping
        for k in 2...125 { lines += ledger.tick(at: tickTime(k)).lines }
        if let first { lines += ledger.answer(first, at: 31.4) }
        var unseen = Ledger(startedAt: 0)
        if let id = unseen.tick(at: 0.25).ping { lines += unseen.answer(id, at: 2) }
        XCTAssertGreaterThanOrEqual(lines.count, 7, "precondition: every kind of ledger line was produced")

        let code = try source(Self.watchdog)
        let literals = stringLiterals(in: code)
        XCTAssertTrue(literals.contains { $0.hasPrefix("watch on — ping ") }, "precondition: the start line was read")
        XCTAssertTrue(literals.contains { $0.hasPrefix("watch off — ") }, "precondition: the pause line was read")

        for line in lines + literals {
            XCTAssertFalse(EchoelCrashLog.looksLikeUnseenCrash(line), "`\(line)` reads as a crash to the next launch")
            XCTAssertNil(EchoelCrashLog.lastScenePhase(in: line), "`\(line)` reads as a scene transition")
        }
        for line in lines { XCTAssertTrue(line.hasPrefix(Ledger.linePrefix), "`\(line)` carries the `main: ` prefix") }
    }

    // MARK: - Helpers

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func anchor(_ needle: String, in text: String) throws -> Range<String.Index> {
        guard let hit = text.range(of: needle) else {
            throw WatchAnchorMissing(reason: "`\(needle)` is not in the scanned text — re-anchor (#454)")
        }
        return hit
    }

    /// Every single-line string literal's text, interpolations left as written.
    private func stringLiterals(in code: String) -> [String] {
        var found: [String] = []
        for line in code.split(separator: "\n") {
            var inside = false
            var current = ""
            var escaped = false
            for ch in line {
                if inside {
                    if escaped { escaped = false; current.append(ch); continue }
                    if ch == "\\" { escaped = true; current.append(ch); continue }
                    if ch == "\"" { inside = false; found.append(current); current = ""; continue }
                    current.append(ch)
                } else if ch == "\"" {
                    inside = true
                }
            }
        }
        return found
    }

    private func root() throws -> URL {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        let path = try root().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw WatchAnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor (#454)")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    private func sourceFiles() throws -> [URL] {
        let sources = try root().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            throw WatchAnchorMissing(reason: "Sources/ could not be listed")
        }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }
}
