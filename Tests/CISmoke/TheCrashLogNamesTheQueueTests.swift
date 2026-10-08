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
// SH-3 (GMMW, 2026-10-08) — claim 6: a stack overflow on the main thread could not write its marker
// (the handler ran on the overflowed stack and faulted again — build 2037's black screen left no
// `CRASH` line). `begin()` now arms an alternate signal stack BEFORE `installHandlers()`, SIGSEGV
// and SIGBUS (only those) are flagged `SA_ONSTACK` on the action `signal` installed, and every
// `echoel…` global the handler and its marker helper read is warmed above the first install — the
// set is DERIVED from the handler's text, so a new unwarmed global goes red. Graded against the
// parent `01e65a6` in Python (`SourceText.codeOnly` ported): REGRESSION, red there at its FIRST
// anchor — no arming call — and the method returns there. Its other halves, driven past that
// return, are red on the parent too: no `SA_ONSTACK`, and none of the twelve globals warmed (one
// absence of a warming block, #486). Mutants red: arming after the install; the flag on
// every fatal signal; a thirteenth global read in the handler and not warmed; the name buffer's
// warm line removed. NOT covered: that the kernel accepts the stack (the `crash net:` line says it
// on the device) and that an overflow on a NON-main thread is logged (it is not: the stack is
// per thread).
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

    /// 6 — SH-3: an overflowed main thread can still write its marker. The alternate stack is
    /// armed BEFORE the handlers; exactly SIGSEGV and SIGBUS run on it, flagged after `signal`
    /// installed them; and every global the handler reads is warmed above the first install.
    func testAStackOverflowCanStillWriteItsMarker() throws {
        let code = try read(Self.crashLog)
        guard let arm = code.range(of: "installAlternateSignalStack()"),
              let install = code.range(of: "installHandlers()") else {
            return XCTFail("ANCHOR MISSING: `installAlternateSignalStack()` or `installHandlers()` (#454)")
        }
        XCTAssertLessThan(arm.lowerBound, install.lowerBound, """
            `begin()` must arm the alternate signal stack before it installs the handlers — an \
            overflow on the main thread has no stack left to run a handler on (build 2037).
            """)
        let armBody = try body(of: "private static func installAlternateSignalStack() -> Bool", in: code)
        XCTAssertTrue(armBody.contains("sigaltstack(&stack, nil)") && armBody.contains("echoelAltStack"),
                      "the arming function no longer hands `echoelAltStack` to `sigaltstack`")
        XCTAssertEqual(code.components(separatedBy: "SA_ONSTACK").count - 1, 1,
                       "one place flags a signal for the alternate stack")
        let loop = try body(of: "for sig in [SIGSEGV, SIGBUS] {", in: code)
        XCTAssertTrue(loop.contains("action.sa_flags |= SA_ONSTACK"), """
            the alternate stack is for SIGSEGV and SIGBUS only — an overflow arrives as one of them, \
            and SIGTRAP keeps its own stack so its backtrace still walks the trapping frames.
            """)
        guard let handlerEnd = code.range(of: Self.handlerClose),
              let flag = code.range(of: "action.sa_flags |= SA_ONSTACK") else {
            return XCTFail("ANCHOR MISSING: the handler's end or the SA_ONSTACK flag (#454)")
        }
        XCTAssertLessThan(handlerEnd.lowerBound, flag.lowerBound,
                          "the flag is added to the action `signal` installed, so it must come after the install")

        // Every global the handler (and the marker helper it calls) reads, derived from the text —
        // a NEW global added to the handler without being warmed goes red here.
        let span = try handlerSpan(in: code)
        let helper = try body(of: "private func echoelCrashMarker(for sig: Int32) -> [UInt8]", in: code)
        let globals = Self.handlerGlobals(in: String(span) + "\n" + helper)
        XCTAssertGreaterThanOrEqual(globals.count, 10, "the scan found the handler's globals (#367): \(globals)")
        let installs = try body(of: "private static func installHandlers()", in: code)
        guard let firstInstall = installs.range(of: Self.handlerOpen) else {
            return XCTFail("ANCHOR MISSING: the handler is no longer installed inside `installHandlers` (#454)")
        }
        let warming = installs[..<firstInstall.lowerBound]
        for name in globals.sorted() {
            XCTAssertTrue(warming.contains(name), """
                `\(name)` is read inside the signal handler but not warmed above the first install. A \
                Swift global is lazy; its first read runs `swift_once` and may allocate — inside a \
                handler that is the lock and the malloc a crash may already hold.
                """)
        }
        XCTAssertTrue(warming.contains("warmedHandlerBytes = warmed"), "the warmed reads are stored, so they are kept")
    }

    /// The `echoel…` globals a span of code names, once each.
    private static func handlerGlobals(in text: String) -> Set<String> {
        guard let pattern = try? NSRegularExpression(pattern: "echoel[A-Z][A-Za-z]*") else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var names = Set<String>()
        for match in pattern.matches(in: text, range: range) {
            if let found = Range(match.range, in: text) { names.insert(String(text[found])) }
        }
        return names
    }

    /// The text between the braces that open after `head`, brace-matched (#408/#454).
    private func body(of head: String, in text: String) throws -> String {
        guard let start = text.range(of: head),
              let open = text[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: `\(head)` (#454)")
            throw AnchorMissing(name: head)
        }
        var depth = 1
        var index = text.index(after: open)
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[text.index(after: open)..<index]) }
            default: break
            }
            index = text.index(after: index)
        }
        XCTFail("UNBALANCED: `\(head)` never closes (#454)")
        throw AnchorMissing(name: head)
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
