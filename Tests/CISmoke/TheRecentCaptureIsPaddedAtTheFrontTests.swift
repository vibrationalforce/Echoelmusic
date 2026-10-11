// TheRecentCaptureIsPaddedAtTheFrontTests.swift
// Echoel — GMMW GA-3 step 0 (2026-10-11). Blocking bundle. Claims 1–4 are SOURCE-TEXT SCANS
// (`Tests/CISmoke/CLAUDE.md` §1): they prove where the window starts and in which ORDER the
// boundary skip and the ring index sit, never that a capture ran. Claim 5 is END-TO-END on the
// public, pure `StudioCalculator.loopTrimWindow`. A real "Keep last" on a device is a DEVICE
// PROBE and stays open (G9 in `docs/dev/FOUNDER_INBOX.md`).
//
// ⭐ WHY THIS FILE EXISTS. `RetroCapture.captureRecent(seconds:)` wrote its file from
// `startFrame = max(0, endFrame - frames)`. On the ring's FIRST lap — the first `seconds` after
// the capture object was created — `endFrame < frames`, so the window started at frame 0: the
// audio came FIRST and the never-written ring slots LAST. Its live consumer,
// `LoopExporter.exportRecentLoop`, cuts the loop from the END of that file
// (`loopTrimWindow`: start = fileDuration − ago − loopSeconds). So "Keep last" pressed in that
// first stretch exported silence or the wrong bars, reported as success. The file's own
// comments already promised the opposite ("front-padded with the ring's zeros").
// The window now ends at the cursor (`startFrame = endFrame - frames`, negative on the first
// lap); every index below `boundary` — and so every negative one — becomes an explicit zero
// BEFORE the `% ringCapacity` read. `snapshotPreRoll` had the same line and the same promise
// ("zero-padded at the front"); it has no production caller, so it carries no user-visible
// defect, but one rule for one ring is #416, and its length and fresh-silence contracts
// (`APreRollNeverCrossesARateSwitchTests` claim 3) are untouched by the change.
//
// ⚠️ WHAT IT DOES NOT SAY (#364). It does not forbid a different spelling of an end-anchored
// window — a rewrite that keeps the file padded at the front only has to re-anchor claims 1
// and 3 in the same commit, and their messages say what they protect. It does not touch
// `preRollWindow`, which TRUNCATES on purpose for the take that continues live.
//
// ⚠️ HONEST GRADING (§3). No local Swift toolchain (§0). Five claims, twelve assertions.
// Transcribed into Python and driven against the parent tree and this tree:
// · REGRESSIONS (red on the parent for their named reason): claim 1's two start-line
//   assertions and claim 3's two — 4.
// · COUNTERWEIGHTS (green on both, #343): claim 2's order and explicit-zero assertions (2),
//   claim 3's order assertion (1), claim 4's three premises that keep a negative index away
//   from `%`, and claim 5's two on the consumer's behaviour — 8.
// · No FORWARD guard: the slice creates no symbol.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheRecentCaptureIsPaddedAtTheFrontTests: XCTestCase {

    private static let captureFile = "Sources/Echoelmusic/Audio/RetroCapture.swift"

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    /// Comment-stripped: the source quotes the old `max(0, …)` line inside the ⛔ block that
    /// explains its removal. A raw scan would read that argument as the code (#453).
    private func code() throws -> String {
        SourceText.codeOnly(try String(
            contentsOf: try repoRoot().appendingPathComponent(Self.captureFile), encoding: .utf8))
    }

    /// The text from `from` up to (not including) `to`. Fails, never returns "", when an anchor
    /// is missing — an empty slice would make every absence assertion a vacuous green (#926).
    private func body(_ code: String, from: String, to: String,
                      file: StaticString = #filePath, line: UInt = #line) -> String? {
        guard let start = code.range(of: from),
              let end = code.range(of: to, range: start.upperBound..<code.endIndex) else {
            XCTFail("could not bracket `\(from)` … `\(to)` in \(Self.captureFile); the claim "
                    + "measures nothing until it is re-anchored", file: file, line: line)
            return nil
        }
        return String(code[start.lowerBound..<end.lowerBound])
    }

    // MARK: - Claim 1 — the file a "Keep last" reads ENDS at the cursor

    func testTheRecentCaptureEndsAtTheCursor() throws {
        let code = try self.code()
        guard let capture = body(code, from: "func captureRecent(seconds: Double) -> URL? {",
                                 to: "private func makeRecordingURL() throws -> URL") else { return }
        XCTAssertEqual(capture.components(separatedBy: "let startFrame = endFrame - frames").count - 1, 1, """
            `captureRecent` no longer starts its window at `endFrame - frames`. The consumer \
            (`LoopExporter.exportRecentLoop`) cuts the loop from the END of the file, so the \
            file must END at the cursor — on the ring's first lap too, where the start is \
            negative and is padded with zeros at the FRONT.
            """)
        XCTAssertFalse(capture.contains("max(0, endFrame - frames)"), """
            `captureRecent` clamps its start to 0 again. On the first lap that puts the audio \
            at the front and the never-written slots at the end, and "Keep last" exports \
            silence or the wrong bars while reporting success (GA-3 step 0).
            """)
    }

    // MARK: - Claim 2 — a negative index is skipped BEFORE it can reach `%`

    func testANegativeIndexIsZeroedBeforeTheRingIsRead() throws {
        let code = try self.code()
        guard let capture = body(code, from: "func captureRecent(seconds: Double) -> URL? {",
                                 to: "private func makeRecordingURL() throws -> URL") else { return }
        guard let skip = capture.range(of: "guard startFrame + written + f >= boundary else {"),
              let read = capture.range(of: "% ringCapacity) * 2") else {
            return XCTFail("""
                `captureRecent` lost its boundary skip or its ring read. With a negative start \
                the skip is what turns every index below 0 into an explicit zero; without it \
                `%` on a negative operand reads the wrong slot.
                """)
        }
        XCTAssertLessThan(skip.lowerBound, read.lowerBound, """
            The ring read sits BEFORE the boundary skip in `captureRecent`. On the first lap \
            the start is negative, and only the skip keeps that index away from `%`.
            """)
        XCTAssertTrue(capture.contains("ch0[f] = 0; ch1[f] = 0"), """
            The skipped frames are no longer written as explicit zeros. `AVAudioPCMBuffer` \
            does not promise a cleared buffer, so the front padding would be whatever was in \
            that allocation (#630b).
            """)
    }

    // MARK: - Claim 3 — the snapshot reads the same ring by the same rule

    func testTheSnapshotEndsAtTheCursorToo() throws {
        let code = try self.code()
        guard let snapshot = body(code, from: "func snapshotPreRoll(seconds: Int = 30) -> [Float] {",
                                  to: "func captureRecent(seconds: Double) -> URL? {") else { return }
        XCTAssertEqual(snapshot.components(separatedBy: "let startFrame = endFrame - frames").count - 1, 1, """
            `snapshotPreRoll` no longer ends its window at the cursor. Its contract says \
            "zero-padded at the front"; one ring read by two rules is #416.
            """)
        XCTAssertFalse(snapshot.contains("max(0, endFrame - frames)"), """
            `snapshotPreRoll` clamps its start to 0 again, which puts the padding at the END \
            on the ring's first lap — the opposite of its own contract.
            """)
        guard let skip = snapshot.range(of: "guard startFrame + f >= boundary else { continue }"),
              let read = snapshot.range(of: "% ringCapacity) * 2") else {
            return XCTFail("`snapshotPreRoll` lost its boundary skip or its ring read")
        }
        XCTAssertLessThan(skip.lowerBound, read.lowerBound, """
            The snapshot reads the ring BEFORE its boundary skip; a negative index would reach `%`.
            """)
    }

    // MARK: - Claim 4 — the boundary can never be negative (the premise of claims 2 and 3)

    /// The skip turns a negative index into a zero only because `boundary` is ≥ 0. It is the
    /// write cursor at the last rate switch, and the cursor starts at 0 and only advances.
    func testTheBoundaryIsNeverNegative() throws {
        let code = try self.code()
        XCTAssertTrue(code.contains("private var rateBoundaryFrame: Int64 = 0"), """
            `rateBoundaryFrame` no longer starts at 0. A negative boundary would let a negative \
            index past the skip and into `%` — the front padding of claims 2 and 3 rests on it.
            """)
        XCTAssertTrue(code.contains("ringWriteFrame.initialize(to: 0)"), """
            The ring cursor no longer starts at 0, so the boundary it feeds may not either.
            """)
        let writers = code.components(separatedBy: "rateBoundaryFrame = ").count - 1
        let cursorWriters = code.components(
            separatedBy: "rateBoundaryFrame = RetroRingCursor.load(ringWriteFrame)").count - 1
        XCTAssertEqual(writers, cursorWriters, """
            Something other than the ring cursor now writes `rateBoundaryFrame`. Only the \
            cursor is known to be ≥ 0; read the new writer before trusting the skip.
            """)
    }

    // MARK: - Claim 5 — END-TO-END: the consumer cuts from the END (why the padding is in front)

    func testTheLoopIsCutFromTheEndOfTheCapture() throws {
        // A 30 s capture whose last 10 s hold audio — the first-lap file after the fix.
        // A 4-bar loop at 120 BPM is 8 s; the last downbeat was 1 s ago.
        let window = try XCTUnwrap(StudioCalculator.loopTrimWindow(
            fileDuration: 30, loopSeconds: 8, secondsSinceBarStart: 1))
        XCTAssertEqual(window.start, 21, accuracy: 1e-9, """
            `loopTrimWindow` no longer anchors at the END of the capture. Claims 1–3 pad the \
            file at the front precisely because the cut is taken from the end.
            """)
        XCTAssertGreaterThanOrEqual(window.start, 20, """
            The cut starts before the audio in a front-padded first-lap file, so it would take \
            silence — the defect this file exists to keep out.
            """)
    }
}
