// TheCrashLogNamesTheQueueTests.swift
// Echoel — the lesson of the 2613/2618 triage (2026-10-08), written into the crash handler.
//
// WHAT WAS WRONG. `EchoelCrashLog`'s signal handler wrote the crashing thread's pthread name
// after the `CRASH SIG…` marker, and its doc said "libdispatch names its worker threads after
// the queue label". It does not. A dispatch worker carries no pthread name, so BOTH device
// logs of the SIGTRAP in `dispatch_assert_queue` (a MainActor-isolation check trapping on a
// worker) wrote no `crash thread/queue:` line at all — and the one datum that would have named
// the trapping closure's home, the QUEUE, cost a 23-agent, 2.3-hour triage to recover
// (`RetroCapture.writeQueue`, `com.echoelmusic.retrocapture.disk`).
//
// THE REPAIR. One more line in the handler: `crash queue: <label>`, read with
// `__dispatch_queue_get_label(nil)` — the Swift spelling of
// `dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL)`, a thread-local read that returns
// the current queue's own label pointer (the empty string off any queue). No allocation, no
// lock, written through the same raw `write(2)` as everything else in the handler, BEFORE the
// backtrace so a fault inside `backtrace_symbols_fd` cannot lose it.
//
// THE RULE THIS FILE PINS. The fatal-signal handler (the `signal(sig) { received in … }`
// closure in `installHandlers`) writes the current queue's label, from a pre-encoded prefix,
// and stays allocation-free by text: no `String(`, no interpolation, no `Array(`, no
// `.append(`, no logger, no `Task`, no `DispatchQueue` inside the handler span. The pthread
// name line stays — it is the right line for the main thread and for named threads.
//
// LIMITS (Tests/CISmoke/CLAUDE.md §1). SOURCE-TEXT SCAN of one file, comment-stripped. It
// proves the handler CALLS the label read and WRITES it, never that the label is non-empty on
// the device (that is the device's to show — the ask at the end of this header), and never that
// `__dispatch_queue_get_label` is async-signal-safe — it is a TSD read in every libdispatch
// source published, and the handler already calls `backtrace_symbols_fd`, which is not on the
// POSIX list either. The handler span is cut between `signal(sig) { received in` and
// `signal(received, SIG_DFL)`; a handler restructured around those anchors fails LOUDLY
// (ANCHOR MISSING), not green. The allocation needles are a text list, not a type check: a
// new allocating call spelled differently is not seen.
//
// HONEST GRADING (§3). Transcribed in Python against the parent `39dc05e` and the worktree,
// with `SourceText.codeOnly` ported line for line:
//   · claim 1 — FORWARD: red on the parent by ANCHOR ABSENCE (no `__dispatch_queue_get_label`
//     anywhere in the file); green after.
//   · claim 2 — FORWARD: red on the parent by ANCHOR ABSENCE (no `crash queue: ` prefix, no
//     `echoelQueuePrefix` write); green after.
//   · claim 3 — COUNTERWEIGHT, green on both: the handler span is allocation-free by text on
//     the parent too — the queue line did not introduce an allocation, and the needles do fire
//     on a fixture that puts `String(cString:)` in a handler (#367).
//   · claim 4 — FORWARD for its order half (red on the parent: nothing to order), COUNTERWEIGHT
//     for its pthread half (green on both: the name line is still written).
//   · claim 5 — FORWARD: red on the parent by ANCHOR ABSENCE (the triage skill named neither
//     line); green after.
// Stripper measured: raw vs stripped verdicts identical on both trees for every claim (0 flips).
// It is load-bearing nonetheless: the handler's own comment spells `__dispatch_queue_get_label(nil)`
// verbatim, so without the stripper claim 1 would stay green after the CALL was removed and the
// comment kept.
// NEEDS-FOUNDER-VERIFY: Beim nächsten Absturz, der auf einer Hintergrund-Warteschlange passiert,
// steht in Save/Export → Diagnostics unter der `CRASH SIG…`-Zeile eine Zeile `crash queue: …` mit
// einem `com.echoelmusic.…`-Namen — nur das Gerät zeigt, dass der Lese-Aufruf dort einen Namen
// liefert; dieser Wächter zeigt nur, dass er gemacht wird.

import Foundation
import XCTest

final class TheCrashLogNamesTheQueueTests: XCTestCase {

    private static let crashLog = "Sources/Echoelmusic/Core/EchoelCrashLog.swift"
    private static let triageSkill = ".claude/skills/device-log-triage/SKILL.md"

    private static let handlerOpen = "signal(sig) { received in"
    private static let handlerClose = "signal(received, SIG_DFL)"
    private static let labelRead = "__dispatch_queue_get_label(nil)"
    private static let prefixDecl = "Array(\"crash queue: \".utf8)"
    private static let prefixWrite = "echoelQueuePrefix.withUnsafeBufferPointer"
    private static let backtraceCall = "backtrace(&echoelBacktraceBuffer"
    private static let threadName = "pthread_getname_np(pthread_self(), echoelThreadNameBuf"

    /// Text that allocates or takes a lock — none of it belongs in a signal handler.
    private static let allocationNeedles = [
        "String(", "\"\\(", "Array(", ".append(", "print(", "os_log(", "log.log(",
        "breadcrumb(", "Task {", "Task.detached", "DispatchQueue", "NSLock", "malloc(",
    ]

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    private func root() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }

    private func read(_ relativePath: String, stripped: Bool = true) throws -> String {
        guard let text = try? String(contentsOf: root().appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return stripped ? SourceText.codeOnly(text) : text
    }

    /// The fatal-signal handler's body, cut between its two anchors. Loud when either is gone.
    private func handlerSpan(in code: String) throws -> Substring {
        guard let open = code.range(of: Self.handlerOpen) else {
            XCTFail("ANCHOR MISSING: `\(Self.handlerOpen)` is gone from EchoelCrashLog (#454)")
            throw AnchorMissing(name: Self.handlerOpen)
        }
        guard let close = code.range(of: Self.handlerClose, range: open.upperBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: `\(Self.handlerClose)` no longer follows the handler's opening (#454)")
            throw AnchorMissing(name: Self.handlerClose)
        }
        return code[open.upperBound..<close.lowerBound]
    }

    private func allocationHits(in span: Substring) -> [String] {
        Self.allocationNeedles.filter { span.contains($0) }
    }

    // MARK: claims

    /// 1 — the handler reads the current queue's label.
    func testTheHandlerReadsTheCurrentQueueLabel() throws {
        let span = try handlerSpan(in: try read(Self.crashLog))
        XCTAssertTrue(span.contains(Self.labelRead), """
            the fatal-signal handler no longer calls `\(Self.labelRead)`. Without it a trap on a \
            libdispatch worker writes NO line naming where it died — the pthread name is empty \
            there (builds 2613/2618), and the queue is the datum that names the trapping closure.
            """)
    }

    /// 2 — the label is written from a pre-encoded prefix through the raw fd, like every other line.
    func testTheLabelIsWrittenFromAPreEncodedPrefix() throws {
        let code = try read(Self.crashLog)
        XCTAssertTrue(code.contains(Self.prefixDecl), """
            the pre-encoded `crash queue: ` prefix is gone. The handler must not build a String — \
            encode the prefix once at load, like `echoelThreadPrefix`.
            """)
        let span = try handlerSpan(in: code)
        XCTAssertTrue(span.contains(Self.prefixWrite), """
            the handler no longer writes `echoelQueuePrefix` — the label would arrive without its \
            prefix, or not at all.
            """)
    }

    /// 3 — the handler span stays allocation-free by text, and the needles can fire (#367).
    func testTheHandlerStaysAllocationFreeByText() throws {
        let span = try handlerSpan(in: try read(Self.crashLog))
        XCTAssertEqual(allocationHits(in: span), [], """
            the fatal-signal handler now contains text that allocates or locks: \
            \(allocationHits(in: span)). malloc may be held by the crashing thread; the handler \
            writes pre-encoded bytes only. Use a fixed buffer or a pre-encoded array.
            """)

        let fixture = """
            signal(sig) { received in
                let name = String(cString: __dispatch_queue_get_label(nil))
                signal(received, SIG_DFL)
            }
            """
        XCTAssertEqual(allocationHits(in: try handlerSpan(in: fixture)), ["String("],
                       "the needles must catch a `String(cString:)` in a handler (#367)")
    }

    /// 4 — the queue line comes BEFORE the backtrace, and the pthread name line still exists.
    func testTheQueueLineComesBeforeTheBacktraceAndTheThreadNameStays() throws {
        let span = try handlerSpan(in: try read(Self.crashLog))
        XCTAssertTrue(span.contains(Self.threadName), """
            the pthread-name line is gone. It is the right line for the main thread and for named \
            threads; the queue line is in ADDITION, not instead.
            """)
        guard let label = span.range(of: Self.labelRead),
              let backtrace = span.range(of: Self.backtraceCall) else {
            return XCTFail("ANCHOR MISSING: label read or backtrace call not in the handler span (#454)")
        }
        XCTAssertLessThan(label.lowerBound, backtrace.lowerBound, """
            the queue label is written AFTER the backtrace. `backtrace_symbols_fd` is the riskiest \
            call in the handler; a fault inside it must not lose the one line that names the queue.
            """)
    }

    /// 5 — the triage skill tells the next reader what the two lines mean.
    func testTheTriageSkillNamesBothLines() throws {
        let skill = try read(Self.triageSkill, stripped: false)
        XCTAssertTrue(skill.contains("`crash queue:`"), """
            `\(Self.triageSkill)` no longer names the `crash queue:` line — the next session reading a \
            worker-thread trap would not know the queue is in the log.
            """)
        XCTAssertTrue(skill.contains("`crash thread/queue:`"),
                      "the skill no longer names the pthread line beside the queue line")
    }
}
