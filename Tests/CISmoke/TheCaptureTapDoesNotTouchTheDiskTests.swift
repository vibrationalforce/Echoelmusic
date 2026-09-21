// TheCaptureTapDoesNotTouchTheDiskTests.swift
// Echoel — #1413. The always-on capture tap fills the ring and NOTHING else.
//
// WHAT WAS THERE. `RetroCapture.install(on:)` installed an `AVAudioNodeTapBlock` that, while a
// take was armed, called `try file.write(from: buffer)` and on failure formatted
// `error.localizedDescription` — a synchronous filesystem write plus a bundle lookup, inside the
// tap callback, on a live and reachable path (the WAV button in `FloatingVisualWindow`).
//
// ⚠️ THE CLAIM THIS GUARD DOES **NOT** MAKE, and getting it right matters more than the fix.
// Apple does NOT document `AVAudioNodeTapBlock` as a hard realtime callback and does NOT forbid
// `AVAudioFile.write(from:)` inside it; the documentation says only that the block may be called
// on a thread other than the one that installed it. So this was never a proven API-contract
// violation, and an earlier draft of the audit that called it "a real audio-thread violation"
// over-stated it. What it WAS: a potentially blocking operation on a deadline-sensitive capture
// path — one stalled volume, one iCloud eviction, one full disk turns a single buffer's write
// into an underrun, and Apple's own DTS guidance for this block is to copy the samples out and
// dispatch the work elsewhere. The repair is right; the reason is Echoel's own pro-audio bar,
// not a rule somebody else wrote.
//
// ⭐ THE LESSON WORTH KEEPING: a fix does not need the strongest available justification, it
// needs the TRUE one. A finding sold as "Apple forbids this" dies the moment someone reads the
// documentation and finds it does not — and it takes the correct repair down with it.
//
// Grading (§0, no Swift toolchain in a web session): every claim below is a text assertion over
// the two source files and was transcribed into Python and driven against BOTH trees — RED on
// `ecf72a8f2` (claims 1, 3, 4, 5 fail; claim 2 already green, it is the counterweight), GREEN on
// this tree. NOT compile-verified: a transcription does not run Swift's type checker.

import XCTest

final class TheCaptureTapDoesNotTouchTheDiskTests: XCTestCase {

    private static let capturePath = "Sources/Echoelmusic/Audio/RetroCapture.swift"
    private static let windowPath  = "Sources/Echoelmusic/Studio/FloatingVisualWindow.swift"

    private func source(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        let url = dir.appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath). A guard that cannot find its "
                    + "subject is not a pass — re-anchor it rather than letting it stay green "
                    + "(#454).")
            return ""
        }
        return text
    }

    /// The closure body passed to `installTap`, comments stripped.
    ///
    /// ⚠️ Bounded on the CLOSURE, not on the function: `install(on:)` legitimately logs and
    /// legitimately reads `captureSampleRate` around the tap, and a whole-function scan would
    /// forbid both. The block runs from the `installTap(` call to the first line that closes it
    /// at the call's own indentation.
    private func tapBody(_ text: String) throws -> String {
        let lines = text.components(separatedBy: "\n")
        guard let open = lines.firstIndex(where: { $0.contains("node.installTap(onBus: 0") }) else {
            XCTFail("ANCHOR MISSING: no `node.installTap(onBus: 0` in \(Self.capturePath). The "
                    + "tap install moved or was renamed — re-anchor this walk (#454).")
            return ""
        }
        guard let close = lines[(open + 1)...].firstIndex(where: { $0 == "        }" }) else {
            XCTFail("ANCHOR MISSING: the tap closure in \(Self.capturePath) never closes at its "
                    + "own indentation. Re-anchor rather than scanning the whole file (#454).")
            return ""
        }
        return lines[open...close]
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    // 1 — THE RULE. Nothing that can block, allocate a description or reach the filesystem.
    func testTheTapBodyTouchesNoFileAndFormatsNoString() throws {
        let body = try tapBody(try source(Self.capturePath))
        XCTAssertFalse(body.isEmpty, "empty tap body — the anchor above already failed")

        // Each needle is a DIFFERENT way the old body reached off the deadline path, so they
        // are reported together as ONE finding rather than five (#486).
        let banned = ["file.write", "AVAudioFile", "localizedDescription",
                      "log.log", "activeFile", "writeFailure", "catch"]
        let hits = banned.filter { body.contains($0) }
        XCTAssertTrue(hits.isEmpty, """
            The capture tap block in \(Self.capturePath) contains \(hits.joined(separator: ", ")).
            The tap fills the ring and nothing else (#1413). Disk writes, error formatting and
            logging belong on `writeQueue`, which follows the ring's cursor — see `drainToDisk`.
            This is not an Apple rule (Apple neither documents this block as a hard realtime
            callback nor forbids file I/O in it); it is Echoel's own bar: a potentially blocking
            call on a deadline-sensitive capture path is an avoidable underrun risk.
            """)
    }

    // 2 — COUNTERWEIGHT, and it is the one claim that was ALREADY GREEN before the fix. Claim 1
    // passes trivially if the tap stops doing anything at all, so pin what it must STILL do.
    func testTheTapStillFillsTheRing() throws {
        let body = try tapBody(try source(Self.capturePath))
        for needle in ["ringPtr[slot]", "writePtr.pointee = Int64(frame)"] {
            XCTAssertTrue(body.contains(needle), """
                The capture tap no longer contains `\(needle)`. Claim 1 of this file forbids the
                tap from reaching disk; it must not be satisfiable by emptying the tap. The ring
                fill IS the tap's job — and the cursor publish must stay LAST, after the loop, or
                the writer can read frames that were never filled.
                """)
        }
    }

    // 3 — the work moved somewhere real, off the main actor and onto one serial consumer.
    func testTheDiskWriterRunsOnItsOwnSerialQueue() throws {
        let text = try source(Self.capturePath)
        for needle in ["DispatchQueue(label: \"com.echoelmusic.retrocapture.disk\"",
                       "nonisolated private func drainToDisk()",
                       "DispatchSource.makeTimerSource(queue: writeQueue)"] {
            XCTAssertTrue(text.contains(needle), """
                \(Self.capturePath) no longer carries `\(needle)`. The tap's write did not simply
                disappear — it moved to a single serial consumer that follows the ring cursor.
                If the writer is being replaced, replace this needle in the same commit; if it was
                folded back into the tap, claim 1 is the one to read.
                """)
        }
        // The queue must NOT be the main actor: a 200 ms file write on main is a UI hitch, and
        // the whole point was to stop putting a blocking call on a path that has a deadline.
        XCTAssertFalse(text.contains("@MainActor private func drainToDisk"), """
            `drainToDisk` is main-actor isolated. It writes to disk on a timer while a take runs;
            on the main actor that trades an audio deadline for a render deadline.
            """)
    }

    // 4 — THE NEW FAILURE MODE HAS A COUNTER AND A SCREEN. A cursor that follows the ring can
    // fall behind; the old tap-side write could not. A recorder that silently loses audio is the
    // lying-control class this file already refuses for `writeFailed` (#164/#227).
    func testTheOverrunIsCountedAndShown() throws {
        let capture = try source(Self.capturePath)
        for needle in ["droppedFrames.pointee &+= Int64(", "private(set) var droppedSeconds"] {
            XCTAssertTrue(capture.contains(needle), """
                \(Self.capturePath) no longer carries `\(needle)`. The drain can fall more than
                the ring behind, and then the tap has already overwritten frames the file was
                owed. That gap must be counted and lifted onto an observable, or the REC pill
                keeps counting over a hole.
                """)
        }
        let window = try source(Self.windowPath)
        XCTAssertTrue(window.contains("retroCapture.droppedSeconds"), """
            \(Self.windowPath) does not read `droppedSeconds`. Counting a dropout without
            showing it is the same defect as not counting it: the performer finds out when the
            file is opened afterwards, which is exactly what `writeFailed` exists to prevent.
            """)
    }

    // 5 — and VoiceOver says the same thing the label shows. #1378's lesson, one surface over:
    // two homes for one fact, only one kept current.
    func testTheSpokenValueNamesTheGap() throws {
        let window = try source(Self.windowPath)
        XCTAssertTrue(window.contains("static func wavAccessibilityValue("), """
            `wavAccessibilityValue` is gone from \(Self.windowPath). It exists as a pure static
            so the three states (silent, failed, gap) can be checked without building a view —
            an inline ternary in `.accessibilityValue` grew a third state once and dropped it.
            """)
        XCTAssertTrue(window.contains("seconds lost"), """
            The spoken value no longer names the dropout. A gap that is visible in the bar and
            silent to VoiceOver is an accessibility claim that is less truthful than the visible
            copy — the rule is that it must be at least as truthful.
            """)
    }
}
