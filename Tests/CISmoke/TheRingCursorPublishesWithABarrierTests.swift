// TheRingCursorPublishesWithABarrierTests.swift
// Echoel — #1429. Blocking bundle. SOURCE-TEXT SCAN (`Tests/CISmoke/CLAUDE.md` §1): it proves
// the barriers are WRITTEN and on the correct side. No test in any language can prove a memory
// ordering holds at runtime; what a guard can do is stop the pair being dropped or inverted.
//
// ⭐ WHY THIS FILE EXISTS. #1413 moved disk I/O out of the capture tap — the right move — and
// left a producer/consumer pair with no ordering at all: the tap fills `ring` then stores
// `ringWriteFrame`; the drain and three main-actor readers load `ringWriteFrame` then read
// `ring`. arm64 is not total-store-ordered, so the cursor may become visible BEFORE the slots
// it covers, and a consumer reads a slot never filled. That is a click in a recording, not a
// crash — the class of defect that gets blamed on hardware for months.
//
// ⛔ AND THE REASON IT SAT OPEN WAS A RETRACTION THAT OVER-STATED ITS OWN SCOPE. #1413b
// correctly named the gap, then said closing it "needs `Synchronization.Atomic` … a slice of
// its own, because a concurrency primitive introduced without a compiler is a guess" — because
// it read #1237 as this repo having decided AGAINST fences. #1237 removed the fences from
// `SPSCQueue`'s METRICS counters and KEPT them on the publish path, where they still are. The
// mechanism was in the tree the whole time, on the same platform, already on an audio thread.
// **A retraction that describes a decision more broadly than it was made costs the next session
// the cheap fix** — which is why claim 5 pins the spine this file's reasoning leans on.
//
// ⚠️ WHAT THIS SLICE DOES NOT CLAIM. `writeFailure`, `droppedFrames` and `isActive` remain plain
// cells. Their second writers are temporally exclusive by construction (`startRecording` writes
// them before `isActive` goes true; `stopRecording` clears it, cancels the timer, then takes
// `writeQueue.sync`, a real happens-before edge), with ONE read left outside that edge — the
// `writeFailure` lift immediately before the `sync`, which can be a tick stale and is re-read
// after it. A late latch, never a wrong file. That is argued at the declaration, not here.
//
// ⚠️ HONEST GRADING. No local Swift toolchain (§0). **Seven assertions across six claims**,
// each transcribed in Python against today's tree and each needle re-derived by `grep` first,
// comment-stripped. Claims 1–4 are REGRESSION CATCHES: before this commit claim 1 had nothing
// to find, claim 3 found a raw store, and claim 4 found eight raw reads. Claims 5–6 are
// COUNTERWEIGHTS (#343) and are green by construction — booking them as catches would be the
// flattering direction (#433/#464). What they buy is the day someone strips the spine's
// barriers, or "tidies" the producer's own self-read into the accessor and puts a fence in the
// hottest loop in the app for nothing.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheRingCursorPublishesWithABarrierTests: XCTestCase {

    private static let captureFile = "Sources/Echoelmusic/Audio/RetroCapture.swift"
    private static let spineFile = "Sources/Echoelmusic/Core/SPSCQueue.swift"

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func code(_ relative: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relative)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read — a missing anchor is a "
                    + "finding, not a pass (#454).")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    // MARK: - claim 1 — both halves exist, and each carries a barrier

    func testTheRingCursorDeclaresBothHalvesWithABarrier() throws {
        let src = try code(Self.captureFile)
        guard !src.isEmpty else { return }

        XCTAssertTrue(src.contains("enum RetroRingCursor"), """
            `RetroRingCursor` is gone from \(Self.captureFile).

            It is the ONE definition of the capture ring's release/acquire pair (#416). If the
            pair moved, re-anchor this file in the SAME commit; if it was deleted, the tap is
            back to publishing a cursor with no ordering and #1429 has been undone.
            """)
        for half in ["static func publish(", "static func load("] {
            XCTAssertTrue(src.contains(half), """
                `RetroRingCursor` no longer declares `\(half)`. Both halves are required: a
                release without a matching acquire is not a protocol, it is half a protocol that
                reads as done.
                """)
        }
    }

    // MARK: - claim 2 — the barrier is on the CORRECT SIDE of the access

    func testTheBarrierSitsOnTheCorrectSideOfEachAccess() throws {
        let src = try code(Self.captureFile)
        guard !src.isEmpty else { return }

        // publish: fence, THEN store. load: read, THEN fence.
        XCTAssertTrue(src.contains("OSMemoryBarrier()\n        cursor.pointee = frame"), """
            `RetroRingCursor.publish` no longer fences BEFORE storing the cursor.

            This is the assertion that matters most in this file. A barrier on the wrong side of
            the store is WORSE than no barrier, because the call is present and the next reader
            will take the ordering as handled. Release means: every ring write above becomes
            visible before the cursor that advertises it.
            """)
        XCTAssertTrue(src.contains("let frame = cursor.pointee\n        OSMemoryBarrier()"), """
            `RetroRingCursor.load` no longer fences AFTER reading the cursor.

            Acquire means: no slot load below may be satisfied ahead of this cursor load. Same
            hazard from the consumer's side — see `SPSCQueue.dequeue`, which states it for the
            same reason and for pointer payloads where it is a use-after-free rather than a click.
            """)
    }

    // MARK: - claim 3 — the tap publishes through the pair, never by a raw store

    func testTheTapPublishesThroughThePair() throws {
        let src = try code(Self.captureFile)
        guard !src.isEmpty else { return }

        XCTAssertTrue(src.contains("RetroRingCursor.publish(writePtr,"), """
            The capture tap no longer publishes through `RetroRingCursor.publish`.

            The tap is the one producer and captures no `self` by design; the accessor is a
            static on a top-level non-isolated enum precisely so the closure can call it. A raw
            store here is the #1413 state: "PUBLISH LAST" as an aspiration with nothing
            enforcing it.
            """)
        XCTAssertFalse(src.contains("writePtr.pointee ="), """
            A raw STORE to `writePtr.pointee` is back in \(Self.captureFile).

            Publishing the cursor without the release barrier is exactly the defect #1429
            closed. Route it through `RetroRingCursor.publish`.
            """)
    }

    // MARK: - claim 4 — every cross-thread read goes through the pair

    func testEveryCursorReadGoesThroughThePair() throws {
        let src = try code(Self.captureFile)
        guard !src.isEmpty else { return }

        XCTAssertFalse(src.contains("ringWriteFrame.pointee"), """
            A raw read of `ringWriteFrame.pointee` is back in \(Self.captureFile).

            Eight sites load this cursor and then read `ring`. A barrier written out at each is
            one refactor away from being dropped at one of them, and the loss is SILENT — no
            crash, no test, just an occasional wrong sample. Read it only through
            `RetroRingCursor.load`.
            """)
    }

    // MARK: - claim 5 — COUNTERWEIGHT: the spine this file's reasoning cites still fences

    func testTheSpineStillCarriesTheBarriersThisFileCites() throws {
        let spine = try code(Self.spineFile)
        guard !spine.isEmpty else { return }

        let fences = spine.components(separatedBy: "OSMemoryBarrier()").count - 1
        XCTAssertGreaterThanOrEqual(fences, 4, """
            `SPSCQueue` now carries \(fences) `OSMemoryBarrier()` calls.

            This is NOT a rule against changing the spine (#364). It is the counterweight to the
            argument #1429 rests on: "the mechanism is already in the tree, on this platform, on
            an audio-thread path, and needs no new dependency". If the spine moved to a different
            primitive — `Synchronization.Atomic`, say — then `RetroCapture` should follow it
            rather than keep a second mechanism, and the doc comment at `RetroRingCursor` that
            cites this file has to be re-read in the SAME commit.
            """)
    }

    // MARK: - claim 6 — COUNTERWEIGHT: the producer's own self-read stays raw

    func testTheProducerSelfReadIsNotRoutedThroughTheAccessor() throws {
        let src = try code(Self.captureFile)
        guard !src.isEmpty else { return }

        XCTAssertTrue(src.contains("var frame      = Int(writePtr.pointee)"), """
            The tap's read of its OWN cursor was changed.

            This one is raw ON PURPOSE and the distinction is the whole reason claim 4 is scoped
            to `ringWriteFrame` and not to every pointer in the file. Inside the tap, `writePtr`
            is the producer reading back its own last publish — same thread, no cross-thread
            edge to establish. Routing it through `RetroRingCursor.load` would put a fence in the
            hottest loop in the app to order a value against itself, and would imply a second
            consumer that does not exist. A "consistency" pass is exactly how that would happen.
            """)
    }
}
