// TheMemoryVerdictComesFromTheSystemTests.swift
// Echoel — #1201. Blocking bundle.
//
// ⭐ WHY THIS EXISTS. `MemoryPressureHandler` polled every five seconds and computed
//
//     used  = ProcessInfo.processInfo.physicalMemory − os_proc_available_memory()
//     ratio = used / physicalMemory
//
// Those two quantities describe DIFFERENT THINGS. `physicalMemory` is the system's RAM;
// `os_proc_available_memory()` is THIS PROCESS's remaining headroom before jetsam. Their
// difference names nothing — on an 8 GB phone with ~2 GB of headroom it reads as 6 GB "used"
// by an app using a few hundred MB. 6/8 = 0.75 is above the 0.70 warning threshold, so
// `currentLevel` went to `.warning` within five seconds of EVERY launch on EVERY device and
// the log gained "Handling Warning pressure".
//
// That is the log a founder pastes when reporting high memory use: an instrument that
// manufactures the very finding it is consulted about. It arrived while investigating a live
// founder report of exactly that ("Es scheint zwischendurch zu viel Arbeitsspeicher zu
// verbrauchen", 2026-09-09), which is the only reason anyone looked.
//
// THE REPAIR IS A DELETION, NOT A REDESIGN. iOS's own `DispatchSourceMemoryPressure` was
// already wired and is the authority; `handlePressure` was already its handler. The poll now
// publishes only the headroom figure it can honestly read.
//
// ⚠️ WHAT THIS FILE IS (§1): a SOURCE-TEXT SCAN. It proves the arithmetic is gone and the
// system signal is still wired. It runs no app and allocates no memory — whether the device
// actually behaves is Instruments, and stays open.
//
// GRADING, transcribed in Python and driven against `git show HEAD:<path>` and the worktree:
//  · claim 1 — REGRESSION. The parent's `updateMemoryStats` derived a level from the mixed
//    ratio.
//  · claim 2 — REGRESSION, and a SECOND finding rather than a second witness (#486). On the
//    parent there was exactly ONE writer of `currentLevel` and it sat in the POLL, so the
//    first assertion passed and the second one (the writer must be in `handlePressure`) is
//    what goes red. ⛔ The first draft of this note said the parent's failure was ZERO writers.
//    Measured, that is wrong — zero is what MY EDIT would have produced had this claim not
//    been written: removing the ratio removed the assignment, and `currentLevel` would have
//    been pinned at `.normal` for the life of the process, a silently dead readout in place of
//    a lying one. Caught by writing the claim, not by making the edit. The distinction is
//    exactly the kind this bundle exists to keep straight.
//  · claim 4 — REGRESSION, not a counterweight: the "NOT this app's memory footprint" label at
//    `usedMemoryBytes` is new in #1201; the parent published the number with no warning at all.
//  · claim 3 — the only COUNTERWEIGHT here, green on both trees and deliberately (#343). It is
//    the premise the deletion rests on: the system signal must still be wired, because after
//    #1201 it is the ONLY source of a pressure verdict.

import XCTest

final class TheMemoryVerdictComesFromTheSystemTests: XCTestCase {

    private static let owner = "Sources/Echoelmusic/Core/MemoryPressureHandler.swift"

    // MARK: - 1. the poll derives no verdict

    func testThePollDoesNotDeriveAPressureLevel() throws {
        let poll = try memberBody("private func updateMemoryStats()").joined(separator: "\n")
        for forbidden in ["thresholds.", "usageRatio", "currentLevel"] {
            XCTAssertFalse(poll.contains(forbidden), """
                `updateMemoryStats` mentions `\(forbidden)` again. This poll cannot compute a \
                pressure ratio: `physicalMemory` is system RAM and `os_proc_available_memory()` \
                is this process's headroom, so no quotient of them means anything. The last \
                version of this arithmetic put `currentLevel` at `.warning` five seconds into \
                every launch on a healthy device.

                This does NOT forbid a real measurement (#364). If a future slice measures the \
                actual process footprint, it may decide again — and the prose in this file's \
                header and at `usedMemoryBytes` must move with it.
                """)
        }
    }

    // MARK: - 2. the published level still has exactly one writer

    func testThePublishedLevelHasExactlyOneWriter() throws {
        let code = try source()
        let writers = code.components(separatedBy: "currentLevel = ").count - 1
        XCTAssertEqual(writers, 1, """
            `currentLevel` has \(writers) writer(s); it must have exactly one.

            ZERO is the trap this claim was written for: removing the poll's ratio removed the \
            only assignment, which would have pinned the published level at `.normal` for the \
            life of the process — a readout that is silently dead rather than loudly wrong, \
            and not an improvement. TWO means a second path is deciding pressure on its own \
            terms again.

            The one writer is `handlePressure(level:)`, and every path into it is a real \
            signal: `DispatchSourceMemoryPressure`, the UIKit memory warning, or an explicit \
            `releaseMemory(level:)`.
            """)
        let handler = try memberBody("private func handlePressure(level: MemoryPressureLevel)")
        XCTAssertTrue(handler.contains(where: { $0.contains("currentLevel = level") }), """
            the one writer of `currentLevel` is no longer inside `handlePressure(level:)`. \
            That is the only function every real pressure signal passes through; anywhere else \
            and some signals stop being published.
            """)
    }

    // MARK: - 3. counterweight — the system signal is still wired

    func testTheSystemPressureSourceIsStillWired() throws {
        let code = try source()
        for needle in ["DispatchSource.makeMemoryPressureSource", "memorySource?.resume()",
                       "didReceiveMemoryWarningNotification"] {
            XCTAssertTrue(code.contains(needle), """
                `\(needle)` is gone. Since #1201 the system's own signal is the ONLY source of \
                a pressure verdict — the five-second poll no longer produces one. Removing \
                this leaves the app with no memory-pressure handling at all, and nothing else \
                would say so.
                """)
        }
    }

    // MARK: - 4. counterweight — the surviving subtraction is labelled

    func testTheMisleadingByteCountIsStillLabelled() throws {
        let code = try source()
        XCTAssertTrue(code.contains("NOT this app's memory footprint"), """
            `usedMemoryBytes` lost the warning at its declaration. The property still holds \
            `physicalMemory − os_proc_available_memory()`, which names nothing; it is kept only \
            because it is public API. Without the label the next reader adopts the number, \
            which is how #1201 happened in the first place.
            """)
    }

    // MARK: - source access

    private struct Anchor: Error { let reason: String }

    private func source() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let path = root.appendingPathComponent(Self.owner)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("\(Self.owner) not reachable — source tree not co-located.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    /// Lines of a member, by BRACE-matched indentation rather than a line count (#408): this
    /// file carries 20-line comment blocks inside its members, so any window is unsound.
    private func memberBody(_ prefix: String) throws -> [String] {
        let lines = try source().split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        guard let start = lines.firstIndex(where: { $0.contains(prefix) }) else {
            throw Anchor(reason: """
                `\(prefix)` is gone from \(Self.owner). If it was renamed, move this guard with \
                it — do not let the scan skip (#454).
                """)
        }
        let indent = lines[start].prefix { $0 == " " }.count
        let close = lines[(start + 1)...].firstIndex {
            $0.trimmingCharacters(in: .whitespaces) == "}"
                && $0.prefix { c in c == " " }.count == indent
        } ?? lines.endIndex
        return Array(lines[start..<close])
    }
}
