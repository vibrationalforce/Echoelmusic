// AFailedExportEndsInsteadOfHangingTests.swift
// Echoel — GMMW SH-5b, found while SH-5 gave the writer its diag-log ladder. `SingleExport
// .renderWithGain` pulls the take through `requestMediaDataWhenReady` and waited on ONE way out:
// the reader running dry. Three others existed and none resumed the continuation correctly:
// · `writer.startWriting()` was not checked — a writer that cannot start is `.failed`, and
//   `startSession` on it raises;
// · a reader that FAILS mid-file also hands back nil, so a truncated file was reported done;
// · a writer that fails (or refuses an `append`) leaves `isReadyForMoreMediaData` false, the block
//   is never called again, and the export sat at `.rendering` for good — the hang.
// The finish also resumed without asking the writer how it went.
//
// ⭐ THE REVIEW OF b22b17d FOUND THE HANG ONLY HALF CLOSED, and this file did not see it. The check
// for a failed writer ran only inside a call of the pull block, at the end of its loop — but the
// export is offline, the writer encodes between calls, and a writer that fails THEN never reports
// ready again, so the block that would have checked is never called. Now a timer on the same serial
// queue asks while the export waits (claim 5). The review also found: the exactly-once property
// rested on `return`s no claim pinned (a mutant dropping one stayed green and would resume twice);
// the finish called `markAsFinished` without asking whether the writer was still writing; and
// `cancelWriting` does nothing on a writer that already failed, so a partial file stayed in
// Exports — it is now removed in one `catch` (claim 6).
//
// WHAT IT PINS (Tests/CISmoke/CLAUDE.md §1) — all SOURCE-TEXT SCANS: `renderWithGain` is a
// private `async` method that needs a real asset and a real writer, which no bundle drives. Each
// way out is read in its own brace-matched block (#408):
// 1. The start is checked before the session opens.
// 2. A failed reader, a refused append and a failed writer each set `ended`, stop the other side
//    and resume by THROWING; the reader's failure is told apart from its end before the finish,
//    and so is a writer that stopped writing. Every exit inside the loop ends in `return`, and
//    the check after the loop asks `ended` first — the exactly-once property, not only the exits.
// 3. The finish asks the writer's status before it resumes, and a writer that did not complete
//    throws.
// 4. A late call is a no-op (`guard !counters.ended`), the continuation is a THROWING one, and
//    there are exactly seven resume sites — an eighth way out needs its own branch here (#364:
//    the number may move, with that branch).
// 5. A writer that fails while no pull is running still ends the export: a timer on the pull's
//    own serial queue, armed before the first pull, cancelled on every way out of the method,
//    whose handler asks `ended` first.
// 6. A failed export leaves no partial file: one `catch` around the wait removes the output and
//    rethrows.
// DEVICE PROBE, open: that a full disk or a file pulled away mid-export now shows the error on the
// export sheet instead of a spinner.
//
// HONEST GRADING (§3), first version (claims 1–4). The file named nothing new — it compiled on its
// parent (`b2f4f6e`). There,
// all four claims are red, each by ANCHOR ABSENCE (the thrown `RenderExitAnchorMissing`) — and here
// the anchor IS the missing check: no `guard writer.startWriting()` (claim 1), no `ended` in the nil
// branch (claim 2), no status read in the finish (claim 3), no late-call guard (claim 4). Four
// absences, three defects (the hang, the truncated file reported done, the unchecked start) plus
// the continuation that could not carry a failure. Transcribed in Python against both trees;
// MUTANTS, each red for its named reason: the start check removed → 1; `ended` dropped from the
// append branch → 2; the reader's status read after the finish → 2; the finish resuming
// unconditionally → 3 (and the count, 4); a sixth `continuation.resume(` → 4.
// SECOND VERSION (review fix), against its parent `1d72892`: claim 2 is red there by ANCHOR ABSENCE
// (the post-loop check does not ask `ended`, and there is no writer check before the finish);
// claim 4 is a REGRESSION by its count (five, not seven); claims 5 and 6 are red by ANCHOR ABSENCE
// — no timer, no `catch` — one finding each, the hang and the partial file. Claims 1 and 3 are
// COUNTERWEIGHTS, green on both. MUTANTS, each red for its named reason: the `return` after the
// refused append's resume dropped → 2; the post-loop check without `!counters.ended` → 2; the timer
// on a second queue → 5; the timer armed after the pull starts → 5; the handler without the `ended`
// read → 5; the `defer` cancel removed → 5; the removal dropped from the `catch` → 6.

import Foundation
import XCTest

private struct RenderExitAnchorMissing: Error, CustomStringConvertible {
    let reason: String
    var description: String { reason }
}

final class AFailedExportEndsInsteadOfHangingTests: XCTestCase {

    private static let writer = "Sources/Echoelmusic/Audio/SingleExport.swift"

    // MARK: 1 — the start is checked before the session

    func testAWriterThatCannotStartIsRefusedBeforeTheSession() throws {
        let render = try renderBody()
        let start = try anchor("guard writer.startWriting() else {", in: render)
        let session = try anchor("writer.startSession(", in: render)
        XCTAssertLessThan(start.lowerBound, session.lowerBound, """
            the start must be checked BEFORE the session opens — `startSession` on a writer that \
            failed to start raises
            """)
        let refusal = try block(after: "guard writer.startWriting() else {", in: render)
        XCTAssertTrue(refusal.contains("reader.cancelReading()"), "a refused start lets go of the reader")
        XCTAssertTrue(refusal.contains("throw "), "a refused start throws — the caller writes `export FAILED`")
        XCTAssertEqual(occurrences(of: "writer.startWriting()", in: render), 1,
                       "no bare `writer.startWriting()` whose answer is dropped")
    }

    // MARK: 2 — a failed reader or writer ends the export with an error

    func testAFailedReaderOrWriterEndsTheExportWithAnError() throws {
        let render = try renderBody()

        let dry = try block(after: "guard let sampleBuffer = readerOutputRef.copyNextSampleBuffer() else {", in: render)
        let ended = try anchor("counters.ended = true", in: dry)
        let status = try anchor("readerRef.status != .failed", in: dry)
        let finish = try anchor("writerInputRef.markAsFinished()", in: dry)
        XCTAssertLessThan(ended.lowerBound, status.lowerBound, "the nil branch marks the loop ended first")
        XCTAssertLessThan(status.lowerBound, finish.lowerBound, """
            a nil buffer is also how a FAILED reader answers — its status is read BEFORE the file is \
            finished, or a truncated file is reported done
            """)
        let failedRead = try block(after: "guard readerRef.status != .failed else {", in: dry)
        XCTAssertTrue(failedRead.contains("writerRef.cancelWriting()"), "a failed read deletes the partial file")
        XCTAssertTrue(failedRead.contains("continuation.resume(throwing:"), "a failed read ends the export with an error")

        let refused = try block(after: "guard writerInputRef.append(sampleBuffer) else {", in: render)
        for step in ["counters.ended = true", "readerRef.cancelReading()", "writerRef.cancelWriting()",
                     "continuation.resume(throwing:"] {
            XCTAssertTrue(refused.contains(step), "a refused append: `\(step)` — without it the block is never called again")
        }

        let notWriting = try block(after: "guard writerRef.status == .writing else {", in: dry)
        let writerAsked = try anchor("writerRef.status == .writing", in: dry)
        XCTAssertLessThan(status.lowerBound, writerAsked.lowerBound, "the reader is asked first, then the writer")
        XCTAssertLessThan(writerAsked.lowerBound, finish.lowerBound, """
            a writer that stopped writing is not finished — `markAsFinished` and `finishWriting` \
            belong to a writer that is still writing
            """)
        XCTAssertTrue(notWriting.contains("continuation.resume(throwing:"), "a writer that stopped writing ends the export with an error")

        let failedWriter = try block(after: "if !counters.ended, writerRef.status == .failed {", in: render)
        for step in ["counters.ended = true", "readerRef.cancelReading()", "continuation.resume(throwing:"] {
            XCTAssertTrue(failedWriter.contains(step), "a writer that failed between buffers: `\(step)`")
        }
        let loop = try anchor("while writerInputRef.isReadyForMoreMediaData", in: render)
        let afterLoop = try anchor("if !counters.ended, writerRef.status == .failed {", in: render)
        XCTAssertLessThan(loop.lowerBound, afterLoop.lowerBound, "the writer's status is read when the loop stops")

        // Exactly once is the `return`s, not only the exits: without one, the loop goes on and the
        // check after it can resume a second time — a trap (review of b22b17d, a driven mutant).
        for (exit, body) in [("a failed read", failedRead), ("a writer that stopped writing", notWriting),
                             ("a refused append", refused)] {
            XCTAssertTrue(body.filter { !$0.isWhitespace }.hasSuffix("return}"), """
                \(exit) does not end in `return` — the loop would run on after the continuation \
                resumed, and the check after the loop could resume it again
                """)
        }
    }

    // MARK: 3 — the finish asks how it went

    func testTheFinishAsksTheWriterHowItWent() throws {
        let completion = try block(after: "writerRef.finishWriting {", in: try renderBody())
        let asked = try anchor("writerRef.status == .completed", in: completion)
        let done = try anchor("continuation.resume()", in: completion)
        XCTAssertLessThan(asked.lowerBound, done.lowerBound, "the writer's status is read before the export is called done")
        XCTAssertTrue(completion.contains("continuation.resume(throwing:"), "a writer that did not complete throws")
    }

    // MARK: 4 — every way out resumes once

    func testEveryWayOutResumesTheContinuationOnce() throws {
        let render = try renderBody()
        let pull = try block(after: "requestMediaDataWhenReady(", in: render)
        let lateCall = try anchor("guard !counters.ended else { return }", in: pull)
        let lead = pull[pull.startIndex..<lateCall.lowerBound].filter { !$0.isWhitespace }
        XCTAssertEqual(lead, "{@Sendablein", """
            the pull block must OPEN with the late-call guard — AVFoundation may call it again after \
            a way out, and a second resume is a trap
            """)
        XCTAssertTrue(render.contains("withCheckedThrowingContinuation"), "the continuation can carry a failure")
        XCTAssertFalse(render.contains("withCheckedContinuation {"), "no non-throwing continuation is left")
        XCTAssertEqual(occurrences(of: "continuation.resume(", in: render), 7, """
            seven resume sites: a failed read, a writer that stopped writing before the finish, a \
            finish that completed, a finish that did not, a refused append, a writer that failed \
            between buffers, and the timer that finds a writer failed while no pull runs. If you \
            add a way out, give it `ended` and a branch in claim 2 or 5, then move this number.
            """)
    }

    // MARK: 5 — a writer that fails between pulls still ends the export

    func testAWriterThatFailsBetweenPullsStillEndsTheExport() throws {
        let render = try renderBody()
        let queue = try anchor("let exportQueue = DispatchQueue(label: \"com.echoelmusic.export\")", in: render)
        let timer = try anchor("DispatchSource.makeTimerSource(queue: exportQueue)", in: render)
        let cancel = try anchor("defer { watchdog.cancel() }", in: render)
        let wait = try anchor("withCheckedThrowingContinuation", in: render)
        let armed = try anchor("watchdog.resume()", in: render)
        let pull = try anchor("requestMediaDataWhenReady(on: exportQueue)", in: render)
        XCTAssertLessThan(queue.lowerBound, timer.lowerBound, "premise: the queue is made before the timer")
        XCTAssertEqual(occurrences(of: "DispatchQueue(label:", in: render), 1, """
            the timer and the pull run on ONE serial queue — `ended` is unsynchronised and safe \
            only because a single queue touches it
            """)
        XCTAssertLessThan(cancel.lowerBound, wait.lowerBound, "the timer is cancelled on every way out of the method")
        XCTAssertLessThan(armed.lowerBound, pull.lowerBound, """
            the timer is armed before the first pull — a writer can fail before the block is ever \
            called
            """)
        let handler = try block(after: "watchdog.setEventHandler {", in: render)
        let asked = try anchor("guard !counters.ended, writerRef.status == .failed else { return }", in: handler)
        XCTAssertEqual(handler[handler.startIndex..<asked.lowerBound].filter { !$0.isWhitespace }, "{@Sendablein", """
            the timer's handler must OPEN by asking `ended` — it fires twice a second for the whole \
            export, also after every other way out
            """)
        for step in ["counters.ended = true", "readerRef.cancelReading()", "continuation.resume(throwing:"] {
            XCTAssertTrue(handler.contains(step), "a writer the timer finds failed: `\(step)`")
        }
    }

    // MARK: 6 — a failed export leaves no partial file

    func testAFailedExportLeavesNoPartialFile() throws {
        let render = try renderBody()
        let wait = try anchor("withCheckedThrowingContinuation", in: render)
        let caught = try anchor("catch {", in: render)
        XCTAssertLessThan(wait.lowerBound, caught.lowerBound, "the `catch` is the one around the wait")
        let cleanup = try block(after: "catch {", in: render)
        let removal = try anchor("try? FileManager.default.removeItem(at: outputURL)", in: cleanup)
        let rethrow = try anchor("throw error", in: cleanup)
        XCTAssertLessThan(removal.lowerBound, rethrow.lowerBound, """
            a failed export removes its output before it reports the failure — `cancelWriting` \
            does nothing on a writer that already failed, so nothing else would
            """)
        XCTAssertEqual(occurrences(of: "catch {", in: render), 1, "one place for every exit's cleanup")
    }

    // MARK: - Helpers

    private func renderBody() throws -> String {
        try block(after: "private func renderWithGain(", in: try source(Self.writer))
    }

    private func anchor(_ needle: String, in text: String) throws -> Range<String.Index> {
        guard let hit = text.range(of: needle) else {
            throw RenderExitAnchorMissing(reason: """
                `\(needle)` is not in the scanned block. Here the anchor is usually the CHECK itself: \
                restore it — or re-anchor if it only moved (#454)
                """)
        }
        return hit
    }

    /// The brace-matched block that opens at the first `{` at or after `key` (#408).
    private func block(after key: String, in text: String) throws -> String {
        let start = try anchor(key, in: text)
        var depth = 0
        var body = ""
        for ch in text[start.lowerBound...] {
            if ch == "{" { depth += 1 }
            if depth > 0 { body.append(ch) }
            if ch == "}" {
                depth -= 1
                if depth == 0 { break }
            }
        }
        return body
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw RenderExitAnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor (#454)")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}
