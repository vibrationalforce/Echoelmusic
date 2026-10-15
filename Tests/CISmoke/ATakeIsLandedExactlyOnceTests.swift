// ATakeIsLandedExactlyOnceTests.swift
// Echoel — One World C1/M1, the counter-check of 2026-10-15 (ChatGPT/Astra on `e81f3820c`, B1–B4).
// A camera take's result is decided and handed over in ONE step, to exactly ONE Stop; a Stop that
// came before the camera confirmed is remembered; a take is kept in the library before any lane is
// checked; both lenses land at one position in one step.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR (`VideoTakeLedger`, a pure value): the B1 interleaving cannot happen —
//      a waiting Stop receives the files with the last file's answer, in the same call; a take
//      that finished before any Stop keeps its result until one claims it.
//   2. END-TO-END BEHAVIOUR: two Stops for one take — the first receives the files, the second
//      `.handedOver`; exactly one landing.
//   3. END-TO-END BEHAVIOUR: identity — a late answer of an earlier take is ignored by the next, a
//      new take is refused while the last one's result is unclaimed, each lens keeps its name.
//   4. END-TO-END BEHAVIOUR (B4): a Stop before the outputs confirmed sets `stopRequested`, and the
//      take's completion clears it.
//   5. END-TO-END BEHAVIOUR (B2): the take sentence never calls a take kept when its move failed.
//   6. SOURCE-TEXT SCAN (B2 + B3): `performTake` moves every file BEFORE it checks a lane, and
//      between the read of the shared start and the writes there is no `await`; the camera's
//      delegate stops an output that starts after a Stop.
//
// ⚠️ HONEST GRADING (#433). `VideoTakeLedger`, `VideoImport.TakeLanding`, `takeNote` and
// `performTake` are created by this commit, so the file does not compile against the parent and no
// assertion has a verdict there (one absence, #486): claims 1–5 are FORWARD and END-TO-END; claim
// 6 is FORWARD and a scan. The B1 interleaving itself was red on the parent by reading
// (`VideoTakeCamera.swift:310–343` at `e81f3820c`: `pendingRear/Front` cleared and the lock
// released before `settle`) — that is what claim 1 now pins as a value, not as text.
//
// ⚠️ THE LIMIT. No camera runs here. Whether AVFoundation calls `didStartRecording` before or after
// a fast Stop, and whether both files really finish, are DEVICE PROBES (NEEDS-FOUNDER-VERIFY:
// Record Video, Rear + Front, tap Record and Stop at once — one take lands, or the card says why).

import Foundation
import XCTest
@testable import Echoelmusic

final class ATakeIsLandedExactlyOnceTests: XCTestCase {

    private let rearA = URL(fileURLWithPath: "/tmp/echoel-take-A.mov")
    private let frontA = URL(fileURLWithPath: "/tmp/echoel-take-A-front.mov")
    private let rearB = URL(fileURLWithPath: "/tmp/echoel-take-B.mov")

    // MARK: 1 — one step decides and hands over

    func testAWaitingStopReceivesTheFilesWithTheLastAnswer() {
        var ledger = VideoTakeLedger()
        XCTAssertTrue(ledger.begin(rear: rearA, front: frontA))
        XCTAssertEqual(ledger.requestStop(), .wait(ticket: 1))
        let first = ledger.fileFinished(rearA, written: true)
        XCTAssertTrue(first.owned)
        XCTAssertTrue(first.deliveries.isEmpty, "one lens still owes its file — nobody is answered yet")
        XCTAssertTrue(ledger.takeInFlight)
        let last = ledger.fileFinished(frontA, written: true)
        XCTAssertEqual(last.deliveries.map(\.ticket), [1])
        XCTAssertEqual(last.deliveries.first?.outcome, .taken(.init(rear: rearA, front: frontA)),
                       "the take completes AND reaches its waiter in the same call — no gap for a failure (B1)")
        XCTAssertNil(ledger.unclaimed, "a delivered result is not kept a second time")
        XCTAssertEqual(ledger.requestStop(), .answer(.nothingRecorded), "after delivery there is no take to stop")
    }

    func testATakeThatEndedOnItsOwnWaitsForItsStop() {
        var ledger = VideoTakeLedger()
        XCTAssertTrue(ledger.begin(rear: rearA, front: nil))
        XCTAssertTrue(ledger.fileFinished(rearA, written: true).deliveries.isEmpty)
        XCTAssertEqual(ledger.unclaimed, .taken(.init(rear: rearA, front: nil)),
                       "an interruption's result is kept, not lost")
        XCTAssertEqual(ledger.requestStop(), .answer(.taken(.init(rear: rearA, front: nil))))
        XCTAssertNil(ledger.unclaimed)
    }

    // MARK: 2 — exactly one receiver

    func testASecondStopForOneTakeLandsNothing() {
        var ledger = VideoTakeLedger()
        XCTAssertTrue(ledger.begin(rear: rearA, front: nil))
        XCTAssertEqual(ledger.requestStop(), .wait(ticket: 1))
        XCTAssertEqual(ledger.requestStop(), .wait(ticket: 2), "a second Stop waits too — it is never failed early")
        let done = ledger.fileFinished(rearA, written: true)
        XCTAssertEqual(done.deliveries.map(\.ticket), [1, 2])
        XCTAssertEqual(done.deliveries.map(\.outcome), [.taken(.init(rear: rearA, front: nil)), .handedOver],
                       "the first Stop receives the files, every other one `.handedOver` — one landing")
    }

    // MARK: 3 — identity

    func testAnEarlierTakeNeverReachesTheNextOne() {
        var ledger = VideoTakeLedger()
        XCTAssertTrue(ledger.begin(rear: rearA, front: nil))
        XCTAssertFalse(ledger.begin(rear: rearB, front: nil), "no new take while the last one finalises")
        _ = ledger.fileFinished(rearA, written: true)
        XCTAssertFalse(ledger.begin(rear: rearB, front: nil),
                       "no new take while the last one's result is unclaimed — it would be overwritten")
        XCTAssertEqual(ledger.requestStop(), .answer(.taken(.init(rear: rearA, front: nil))))
        XCTAssertTrue(ledger.begin(rear: rearB, front: nil))
        let late = ledger.fileFinished(rearA, written: true)
        XCTAssertFalse(late.owned, "a late answer for take A is not take B's")
        XCTAssertTrue(late.deliveries.isEmpty)
        XCTAssertEqual(ledger.pendingRear, rearB)
    }

    func testEachLensKeepsItsName() {
        var ledger = VideoTakeLedger()
        XCTAssertTrue(ledger.begin(rear: rearA, front: frontA))
        _ = ledger.requestStop()
        _ = ledger.fileFinished(frontA, written: true)
        let done = ledger.fileFinished(rearA, written: false)
        XCTAssertEqual(done.deliveries.first?.outcome, .taken(.init(rear: nil, front: frontA)),
                       "a failed rear lens never relabels the front file as the rear one")

        var empty = VideoTakeLedger()
        XCTAssertTrue(empty.begin(rear: rearA, front: frontA))
        _ = empty.requestStop()
        _ = empty.fileFinished(rearA, written: false)
        XCTAssertEqual(empty.fileFinished(frontA, written: false).deliveries.first?.outcome, .nothingRecorded,
                       "two failed lenses are ONE answer: nothing recorded")
    }

    // MARK: 4 — a Stop before the camera confirmed (B4)

    func testAStopBeforeTheStartIsRemembered() {
        var ledger = VideoTakeLedger()
        XCTAssertTrue(ledger.begin(rear: rearA, front: nil))
        XCTAssertFalse(ledger.stopRequested)
        _ = ledger.requestStop()
        XCTAssertTrue(ledger.stopRequested, "an output that starts after this Stop is stopped at once")
        _ = ledger.fileFinished(rearA, written: true)
        XCTAssertFalse(ledger.stopRequested, "the finished take leaves no stop behind for the next one")
        var fresh = VideoTakeLedger()
        XCTAssertEqual(fresh.requestStop(), .answer(.nothingRecorded), "no take, nothing to wait for")
    }

    // MARK: 5 — the take sentence (B2)

    func testTheTakeSentenceNeverCallsAFailedMoveKept() {
        let failedMove = VideoImport.TakeLanding(rear: .failure(.copyFailed), front: nil)
        let note = VideoImport.takeNote(failedMove) { _ in "Video" }
        XCTAssertFalse(note.contains("kept"), "a take whose move failed is not in the library — never call it kept")
        let refused = VideoImport.TakeLanding(rear: .failure(.noPictureLane), front: nil)
        XCTAssertTrue(VideoImport.takeNote(refused) { _ in "Video" }.hasSuffix("The take is kept on this phone."),
                      "a refused take was moved into the library first, so it IS kept")
    }

    // MARK: 6 — keep first, land in one step

    func testTheTakeIsKeptFirstAndLandsInOneStep() throws {
        let importer = try code("Sources/Echoelmusic/Sequencer/VideoImport.swift")
        let take = try XCTUnwrap(slice(importer, from: "public static func performTake(", to: "private static func keepTake("),
                                 "ANCHOR: `performTake` is gone (#454)")
        let keep = try XCTUnwrap(take.range(of: "let rearKept = rear.map(keepTake)"))
        let laneCheck = try XCTUnwrap(take.range(of: "videoLaneIDs.contains"))
        XCTAssertLessThan(keep.lowerBound, laneCheck.lowerBound,
                          "every file is kept in the library BEFORE any lane is checked (B2)")
        let oneStep = try XCTUnwrap(slice(take, from: "let frontSeconds = await measuredSeconds(of: frontKept)",
                                          to: "return TakeLanding("))
        XCTAssertFalse(oneStep.dropFirst("let frontSeconds = await".count).contains("await"),
                       "no suspension between reading the shared start and writing both parts (B3)")
        XCTAssertTrue(take.contains("deleteManagedCopy: { _ in })"), "a take is never deleted")

        let camera = try code("Sources/Echoelmusic/Video/VideoTakeCamera.swift")
        let started = try XCTUnwrap(slice(camera, from: "didStartRecordingTo fileURL: URL,", to: "didFinishRecordingTo"),
                                    "ANCHOR: the start confirmation is gone (#454)")
        XCTAssertTrue(started.contains("if stopWasRequested() { output.stopRecording() }"),
                      "an output that starts after a Stop is stopped at once (B4)")
        XCTAssertFalse(camera.contains("settle("), "no second, unlocked hand-over path beside the ledger (B1)")
    }

    // MARK: helpers

    private func slice(_ text: String, from: String, to: String) -> String? {
        guard let start = text.range(of: from),
              let end = text.range(of: to, range: start.upperBound..<text.endIndex) else { return nil }
        return String(text[start.lowerBound..<end.lowerBound])
    }

    private func code(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { break }
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("source tree not present at \(url.path)")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}
