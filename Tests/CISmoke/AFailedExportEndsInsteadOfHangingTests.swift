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
// WHAT IT PINS (Tests/CISmoke/CLAUDE.md §1) — all SOURCE-TEXT SCANS: `renderWithGain` is a
// private `async` method that needs a real asset and a real writer, which no bundle drives. Each
// way out is read in its own brace-matched block (#408):
// 1. The start is checked before the session opens.
// 2. A failed reader, a refused append and a failed writer each set `ended`, stop the other side
//    and resume by THROWING; the reader's failure is told apart from its end before the finish.
// 3. The finish asks the writer's status before it resumes, and a writer that did not complete
//    throws.
// 4. A late call is a no-op (`guard !counters.ended`), the continuation is a THROWING one, and
//    there are exactly five resume sites — a sixth way out needs its own branch here (#364: the
//    number may move, with that branch).
// DEVICE PROBE, open: that a full disk or a file pulled away mid-export now shows the error on the
// export sheet instead of a spinner.
//
// HONEST GRADING (§3). The file names nothing new — it compiles on its parent (`b2f4f6e`). There,
// all four claims are red, each by ANCHOR ABSENCE (the thrown `RenderExitAnchorMissing`) — and here
// the anchor IS the missing check: no `guard writer.startWriting()` (claim 1), no `ended` in the nil
// branch (claim 2), no status read in the finish (claim 3), no late-call guard (claim 4). Four
// absences, three defects (the hang, the truncated file reported done, the unchecked start) plus
// the continuation that could not carry a failure. Transcribed in Python against both trees;
// MUTANTS, each red for its named reason: the start check removed → 1; `ended` dropped from the
// append branch → 2; the reader's status read after the finish → 2; the finish resuming
// unconditionally → 3 (and the count, 4); a sixth `continuation.resume(` → 4.

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

        let failedWriter = try block(after: "if writerRef.status == .failed {", in: render)
        for step in ["counters.ended = true", "readerRef.cancelReading()", "continuation.resume(throwing:"] {
            XCTAssertTrue(failedWriter.contains(step), "a writer that failed between buffers: `\(step)`")
        }
        let loop = try anchor("while writerInputRef.isReadyForMoreMediaData", in: render)
        let afterLoop = try anchor("if writerRef.status == .failed {", in: render)
        XCTAssertLessThan(loop.lowerBound, afterLoop.lowerBound, "the writer's status is read when the loop stops")
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
        XCTAssertEqual(occurrences(of: "continuation.resume(", in: render), 5, """
            five resume sites: a failed read, a finish that completed, a finish that did not, a \
            refused append, a writer that failed between buffers. If you add a way out, give it \
            `ended` and a branch in claim 2, then move this number.
            """)
    }

    // MARK: - Helpers

    private func renderBody() throws -> String {
        try block(after: "private func renderWithGain(", in: try source(Self.writer))
    }

    private func anchor(_ needle: String, in text: String) throws -> Range<String.Index> {
        guard let hit = text.range(of: needle) else {
            throw RenderExitAnchorMissing(reason: "`\(needle)` is not in the scanned block — re-anchor (#454)")
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
