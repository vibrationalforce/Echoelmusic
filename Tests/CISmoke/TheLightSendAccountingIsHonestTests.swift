//
//  TheLightSendAccountingIsHonestTests.swift
//  Echoelmusic — CISmoke (blocking bundle)
//
//  #1445 — "sent" must mean a packet the network stack ACCEPTED, never a packet this app
//  merely computed. Found by independent review of the lighting ownership seam (2026-09-22):
//  both light senders advanced their delivery anchors in the tick, BEFORE `send`, whose first
//  statement is `guard let conn = connection else { return }`. With no socket a tick therefore
//  CONSUMED `lookMoved`, `masterMoved`, the source-freshness compare and the keep-alive clock
//  for a packet that never existed — pull the cable, move the look or hit Blackout, plug back
//  in, and nothing was re-sent.
//
//  ⚠️ WHAT EACH CLAIM IS (§1):
//   · Claims 1, 2, 3, 5, 6, 7, 8, 9 and 10 are END-TO-END BEHAVIOUR. They construct the
//     shipping senders (no socket is needed: `connection` stays nil until `start`) and drive
//     `applySendOutcome` — the SAME method the production completion calls. There is no
//     test-only branch and no injected transport: the seam is the outcome, not the socket.
//   · Claims 4, 11, 12 and 13 are SOURCE-TEXT SCANS. Structure, not behaviour: that the
//     anchors have exactly one writer and that it is not the tick is what makes the
//     no-connection case impossible rather than merely untested.
//   · DEVICE PROBE, OPEN AND NAMED: [NEEDS-FOUNDER-VERIFY] with a real Art-Net or sACN rig,
//     disconnect the network, move the look / master / blackout, reconnect — the pending state
//     must be RETRIED, not silently consumed. No test in this bundle can see a cable.
//
//  ⚠️ THE CONTRACT UNDER TEST IS LOCAL ACCEPTANCE, NOT DELIVERY. UDP gives no receiver
//  acknowledgement at any layer this app can see. Nothing here proves a fixture lit up.
//
//  §0 GRADING (transcribed in Python against both trees, no Swift toolchain in a web session):
//    · The nine behavioural claims name `LightSendAttempt` / `LightSendAccounting` /
//      `applySendOutcome`, none of which exists on the parent — the file does not COMPILE
//      there, so NO assertion has a verdict on that tree. That is ONE absence (#486), not nine
//      findings, and it is stated rather than booked as nine regressions (#433).
//    · The four SOURCE-TEXT claims are pure text and WERE driven against both trees:
//      PARENT 16 red · WORKTREE 0 red, over both sender files.
//      ⚠️ AND THE SHAPE OF THOSE 16 IS THE PART WORTH READING. Fourteen are the
//      `= attempt.` / shared-rule / `sendGeneration` needles — real regressions, red on the
//      parent for exactly the reason their messages give. TWO are not: `lastSentBlackout`
//      counted TWO writers on the parent because its declaration inferred its type, so the
//      text `lastSentBlackout =` appeared in the declaration as well. That is an artefact of
//      this commit typing the declaration, not evidence of the defect, and it is written down
//      rather than counted as a win (#433, the flattering direction).
//      ⚠️ THE ONE-WRITER COUNT ALONE PROVES NOTHING, and this is why claim 4 has two needles:
//      on the parent every anchor also had exactly ONE writer — the tick. The count says
//      "one place"; only `= attempt.` says "the RIGHT place".
//
//  ⛔ WHAT THIS FILE DELIBERATELY DOES NOT DO (#364): it does not forbid a future transport
//  abstraction, a `lastError` on sACN, or a different keep-alive rule. It pins one invariant —
//  a packet that was never locally accepted may not advance delivery state.
//

import Foundation
import XCTest
@testable import Echoelmusic

#if canImport(Network)

@MainActor
final class TheLightSendAccountingIsHonestTests: XCTestCase {

    private static let artNet = "Sources/Echoelmusic/Sync/ArtNetSender.swift"
    private static let sacn = "Sources/Echoelmusic/Sync/SACNSender.swift"

    /// The five delivery anchors, by the name each sender gives them. Both senders use the
    /// same spelling on purpose — the LAW is shared even though the state is not (#416).
    private static let deliveryAnchors = [
        "lastFrameTimestamp",
        "lastSentGrandMaster",
        "lastSentBlackout",
        "lastSentLookIntensity",
        "lastSentTimestamp"
    ]

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func attempt(_ generation: UInt64,
                         frame: TimeInterval = 100,
                         master: Float = 0.5,
                         blackout: Bool = false,
                         look: Float = 0.25,
                         sentAt: TimeInterval = 5_000) -> LightSendAttempt {
        LightSendAttempt(generation: generation, frameTimestamp: frame, grandMaster: master,
                         blackout: blackout, lookIntensity: look, sentAt: sentAt)
    }

    // MARK: - Claim 1 — the rule itself

    /// END-TO-END. The shared decision function, driven directly. Two independent refusals:
    /// a local failure, and a stale generation.
    func testTheRuleRefusesAFailureAndAStaleGeneration() {
        XCTAssertTrue(LightSendAccounting.commits(attempt(1), over: 0, failed: false),
                      "A newer attempt that the stack accepted cannot commit. Nothing would "
                      + "ever leave the dedup anchors, so every tick would resend forever.")
        XCTAssertFalse(LightSendAccounting.commits(attempt(1), over: 0, failed: true),
                       "A FAILED send commits its anchors. That is the #1445 defect in its "
                       + "purest form: the next tick is told a retry is unnecessary for a "
                       + "packet the stack refused.")
        XCTAssertFalse(LightSendAccounting.commits(attempt(1), over: 2, failed: false),
                       "A LATE completion of an older packet commits over a newer one. "
                       + "Delivery state would roll backward and re-open a resend of state "
                       + "that is already out.")
        XCTAssertFalse(LightSendAccounting.commits(attempt(2), over: 2, failed: false),
                       "A duplicate completion of the SAME attempt commits twice. `>` and not "
                       + "`>=` is deliberate: a second commit would re-stamp `sentAt` and push "
                       + "the keep-alive deadline out on no new packet.")
    }

    // MARK: - Claim 2 — a local failure commits nothing (requirement B, E)

    /// END-TO-END, both senders. A refused send must leave every delivery anchor where it was,
    /// so the next tick still computes `masterMoved` / `lookMoved` / a fresh source.
    func testAFailedSendCommitsNothingOnEitherSender() {
        let art = ArtNetSender()
        let beforeArt = (art.lastFrameTimestamp, art.lastSentGrandMaster,
                         art.lastSentBlackout, art.lastSentLookIntensity, art.lastSentTimestamp)
        art.applySendOutcome(attempt(1, master: 0.1, blackout: true, look: 0.9), failed: true)
        XCTAssertEqual(art.lastFrameTimestamp, beforeArt.0,
                       "Art-Net advanced the source anchor on a FAILED send. The next tick "
                       + "would see the same frame as already sent and skip the retry.")
        XCTAssertEqual(art.lastSentGrandMaster, beforeArt.1,
                       "Art-Net committed a Grand-Master move that never left the device. "
                       + "`masterMoved` falls false and the desk keeps the old level (#1445).")
        XCTAssertEqual(art.lastSentBlackout, beforeArt.2,
                       "Art-Net committed a BLACKOUT that never left the device. This is the "
                       + "safety control: it must stay retryable until a packet is accepted.")
        XCTAssertEqual(art.lastSentLookIntensity, beforeArt.3,
                       "Art-Net committed a creative look that never left the device.")
        XCTAssertEqual(art.lastSentTimestamp, beforeArt.4,
                       "Art-Net stamped the keep-alive clock for a failed send, so the node "
                       + "waits a full keep-alive period before anything is re-sent.")
        XCTAssertEqual(art.committedGeneration, 0,
                       "Art-Net advanced its committed generation on a failure, which would "
                       + "make the RETRY look stale to the rule and refuse it too.")

        let sacn = SACNSender()
        sacn.applySendOutcome(attempt(1, master: 0.1, blackout: true, look: 0.9), failed: true)
        XCTAssertEqual(sacn.lastSentBlackout, false, "sACN committed a blackout that never left (#1445)")
        XCTAssertEqual(sacn.lastSentLookIntensity, LightingStore.defaultLookIntensity,
                       "sACN committed a creative look that never left (#1445)")
        XCTAssertEqual(sacn.lastSentTimestamp, 0, "sACN stamped keep-alive for a failed send (#1445)")
        XCTAssertEqual(sacn.committedGeneration, 0, "sACN advanced its generation on a failure (#1445)")
    }

    // MARK: - Claim 3 — a successful send commits (requirement C, F)

    /// END-TO-END, both senders. The other direction: an accepted packet must commit, or the
    /// senders would stream on every tick forever and the guard would be a lie in the safe
    /// direction (#367's mirror case).
    func testAnAcceptedSendCommitsEveryAnchorOnEitherSender() {
        let art = ArtNetSender()
        art.applySendOutcome(attempt(1, frame: 42, master: 0.25, blackout: true,
                                     look: 0.75, sentAt: 9_000), failed: false)
        XCTAssertEqual(art.lastFrameTimestamp, 42, "Art-Net did not commit the source anchor (#1445)")
        XCTAssertEqual(art.lastSentGrandMaster, 0.25, "Art-Net did not commit the master anchor (#1445)")
        XCTAssertTrue(art.lastSentBlackout, "Art-Net did not commit the blackout anchor (#1445)")
        XCTAssertEqual(art.lastSentLookIntensity, 0.75, "Art-Net did not commit the creative anchor (#1445)")
        XCTAssertEqual(art.lastSentTimestamp, 9_000,
                       "Art-Net did not stamp the keep-alive anchor from the ATTEMPT's own "
                       + "handover time. Reading a fresh clock in the completion would push "
                       + "the deadline out by the completion latency, which has nothing to do "
                       + "with the receiver's timeout.")
        XCTAssertEqual(art.committedGeneration, 1, "Art-Net did not record the committed generation (#1445)")

        let sacn = SACNSender()
        sacn.applySendOutcome(attempt(1, frame: 42, master: 0.25, blackout: true,
                                      look: 0.75, sentAt: 9_000), failed: false)
        XCTAssertEqual(sacn.lastFrameTimestamp, 42, "sACN did not commit the source anchor (#1445)")
        XCTAssertEqual(sacn.lastSentLookIntensity, 0.75, "sACN did not commit the creative anchor (#1445)")
        XCTAssertEqual(sacn.lastSentTimestamp, 9_000, "sACN did not stamp the keep-alive anchor (#1445)")
        XCTAssertEqual(sacn.committedGeneration, 1, "sACN did not record the committed generation (#1445)")
    }

    // MARK: - Claim 4 — the anchors have exactly ONE writer, and it is not the tick

    /// SOURCE-TEXT SCAN, and the structural half of requirement A: with no connection `send`
    /// returns before `conn.send`, so the ONLY way an anchor can advance is the completion.
    /// That holds only while `applySendOutcome` is the sole writer.
    func testEachDeliveryAnchorIsWrittenOnlyByTheCommit() throws {
        for path in [Self.artNet, Self.sacn] {
            let src = SourceText.codeOnly(try text(path))
            for anchor in Self.deliveryAnchors {
                let assignments = src.components(separatedBy: "\(anchor) = ").count - 1
                XCTAssertEqual(assignments, 1, """
                    \(path) assigns `\(anchor)` \(assignments) time(s). Exactly ONE is \
                    allowed and it must be the line in `applySendOutcome`. A second writer \
                    is how #1445 happened: the tick advanced the anchor before `send`, whose \
                    first statement is `guard let conn = connection else { return }`, so a \
                    no-connection tick consumed the reason to retry.
                    """)
                XCTAssertTrue(src.contains("\(anchor) = attempt."),
                              "\(path) writes `\(anchor)` from something other than the "
                              + "attempt. The committed value must be the one that was "
                              + "actually handed to the stack, not whatever the property "
                              + "holds when the completion happens to run.")
            }
            XCTAssertTrue(src.contains("guard LightSendAccounting.commits(attempt"),
                          "\(path)'s commit no longer consults the shared rule, so the "
                          + "stale-generation and failure refusals are gone or duplicated "
                          + "(#416: one definition per decision).")
        }
    }

    // MARK: - Claim 5 — a late completion must not roll delivery state backward (requirement D)

    /// END-TO-END. Attempt A, then newer attempt B; B completes first, A completes late.
    /// UDP sends can complete out of order and the tick is 33 ms, so two may be in flight.
    ///
    /// ⚠️ WRITTEN OUT TWICE ON PURPOSE. A shared wrapper over "either sender" would be a
    /// transport abstraction in the one place this slice promised not to build one, and a
    /// heterogeneous closure array is exactly the shape that produces slow-type-check
    /// warnings here (#933d). Two plain blocks cost lines and nothing else.
    func testALateArtNetCompletionDoesNotRollDeliveryStateBackward() {
        let s = ArtNetSender()
        s.applySendOutcome(attempt(2, frame: 20, master: 0.9, look: 0.9, sentAt: 2_000), failed: false)
        s.applySendOutcome(attempt(1, frame: 10, master: 0.1, look: 0.1, sentAt: 1_000), failed: false)
        XCTAssertEqual(s.lastFrameTimestamp, 20, """
            Art-Net: a late completion of an older packet overwrote the newer source anchor. \
            The sender would then believe frame 10 is the newest thing it sent and resend \
            state that is already out.
            """)
        XCTAssertEqual(s.lastSentGrandMaster, 0.9, "Art-Net: a late completion rolled the master back (#1445)")
        XCTAssertEqual(s.lastSentLookIntensity, 0.9, "Art-Net: a late completion rolled the look back (#1445)")
        XCTAssertEqual(s.lastSentTimestamp, 2_000,
                       "Art-Net: a late completion rolled the keep-alive clock BACKWARD, which "
                       + "would fire a keep-alive that is not due.")
        XCTAssertEqual(s.committedGeneration, 2, "Art-Net: committed generation rolled backward (#1445)")
    }

    /// END-TO-END. The identical script on the other transport — the accounting law is shared
    /// even where the protocols are not.
    func testALateSACNCompletionDoesNotRollDeliveryStateBackward() {
        let s = SACNSender()
        s.applySendOutcome(attempt(2, frame: 20, master: 0.9, look: 0.9, sentAt: 2_000), failed: false)
        s.applySendOutcome(attempt(1, frame: 10, master: 0.1, look: 0.1, sentAt: 1_000), failed: false)
        XCTAssertEqual(s.lastFrameTimestamp, 20, "sACN: a late completion rolled the source anchor back (#1445)")
        XCTAssertEqual(s.lastSentGrandMaster, 0.9, "sACN: a late completion rolled the master back (#1445)")
        XCTAssertEqual(s.lastSentLookIntensity, 0.9, "sACN: a late completion rolled the look back (#1445)")
        XCTAssertEqual(s.lastSentTimestamp, 2_000, "sACN: a late completion rolled the keep-alive clock back (#1445)")
        XCTAssertEqual(s.committedGeneration, 2, "sACN: committed generation rolled backward (#1445)")
    }

    // MARK: - Claim 6 — an older FAILURE cannot un-commit a newer success

    /// END-TO-END. The mirror of claim 5, and the one a naive "commit on completion" rewrite
    /// gets wrong: a failure must refuse to commit, never actively clear what is committed.
    func testAnOlderFailureDoesNotDisturbANewerSuccess() {
        let art = ArtNetSender()
        art.applySendOutcome(attempt(2, frame: 20, look: 0.9, sentAt: 2_000), failed: false)
        art.applySendOutcome(attempt(1, frame: 10, look: 0.1, sentAt: 1_000), failed: true)
        XCTAssertEqual(art.lastFrameTimestamp, 20,
                       "An older FAILED completion disturbed a newer committed anchor. A "
                       + "failure is a refusal to commit, never a rollback.")
        XCTAssertEqual(art.lastSentLookIntensity, 0.9, "an older failure cleared a newer creative anchor (#1445)")
        XCTAssertEqual(art.committedGeneration, 2, "an older failure rolled the generation back (#1445)")
    }

    // MARK: - Claim 7 — a retry after a failure commits (requirement B, second half)

    /// END-TO-END. Failure leaves the anchors alone AND leaves the sender able to commit the
    /// retry — a refusal that also poisoned the generation counter would be a worse bug than
    /// the one being fixed.
    func testTheRetryAfterAFailedSendStillCommits() {
        let sacn = SACNSender()
        sacn.applySendOutcome(attempt(1, look: 0.9, sentAt: 1_000), failed: true)
        sacn.applySendOutcome(attempt(2, look: 0.9, sentAt: 1_050), failed: false)
        XCTAssertEqual(sacn.lastSentLookIntensity, 0.9,
                       "The RETRY of a failed creative move did not commit. The sender would "
                       + "stream that look on every tick for the rest of the session.")
        XCTAssertEqual(sacn.lastSentTimestamp, 1_050, "the retry did not stamp the keep-alive anchor (#1445)")
    }

    // MARK: - Claim 8 — unchanged state does not resend forever (requirement 5)

    /// END-TO-END. Once an attempt commits, a tick that computes the SAME values finds nothing
    /// moved. Proven on the anchors the tick compares, not on the tick itself.
    func testCommittedStateMatchesWhatTheNextTickWouldCompare() {
        let art = ArtNetSender()
        art.grandMaster = 0.4
        art.blackout = false
        art.applySendOutcome(attempt(1, frame: 77, master: 0.4, blackout: false,
                                     look: 0.6, sentAt: 3_000), failed: false)
        XCTAssertEqual(art.lastSentGrandMaster, art.grandMaster,
                       "After a successful send the master anchor does not equal the live "
                       + "master, so `masterMoved` stays true and the sender resends forever.")
        XCTAssertEqual(art.lastSentBlackout, art.blackout, "blackout anchor != live blackout after a commit (#1445)")
        XCTAssertEqual(art.lastFrameTimestamp, 77, "source anchor != the sent frame after a commit (#1445)")
    }

    // MARK: - Claim 9 — stop() retires outstanding generations

    /// END-TO-END. A completion still in flight when the socket dies must not commit into the
    /// next session's anchors.
    func testStopRetiresOutstandingGenerations() {
        let art = ArtNetSender()
        art.stop()
        art.applySendOutcome(attempt(1, frame: 55, sentAt: 4_000), failed: false)
        XCTAssertEqual(art.lastFrameTimestamp, -1,
                       "A completion from a stopped session committed. `stop()` must retire "
                       + "every outstanding generation, or a restart dedups against packets "
                       + "belonging to a socket that no longer exists.")
        let sacn = SACNSender()
        sacn.stop()
        sacn.applySendOutcome(attempt(1, frame: 55, sentAt: 4_000), failed: false)
        XCTAssertEqual(sacn.lastFrameTimestamp, -1, "sACN committed a completion from a stopped session (#1445)")
    }

    // MARK: - Claim 10 — the two senders answer identically

    /// END-TO-END. The invariant is shared even though the transports are not: the same
    /// outcome sequence must leave both senders in the same delivery state.
    func testBothSendersApplyTheSameLawToTheSameOutcomes() {
        let art = ArtNetSender(), sacn = SACNSender()
        let script: [(LightSendAttempt, Bool)] = [
            (attempt(1, frame: 1, master: 0.2, look: 0.2, sentAt: 100), true),
            (attempt(2, frame: 2, master: 0.4, look: 0.4, sentAt: 200), false),
            (attempt(3, frame: 3, master: 0.6, look: 0.6, sentAt: 300), true),
            (attempt(2, frame: 9, master: 0.9, look: 0.9, sentAt: 900), false)
        ]
        for (a, failed) in script {
            art.applySendOutcome(a, failed: failed)
            sacn.applySendOutcome(a, failed: failed)
        }
        XCTAssertEqual(art.lastFrameTimestamp, sacn.lastFrameTimestamp,
                       "The two light senders reached different delivery state from the same "
                       + "outcomes. The transports may differ; the accounting law may not.")
        XCTAssertEqual(art.lastSentLookIntensity, sacn.lastSentLookIntensity, "creative anchors diverged (#1445)")
        XCTAssertEqual(art.lastSentTimestamp, sacn.lastSentTimestamp, "keep-alive anchors diverged (#1445)")
        XCTAssertEqual(art.lastFrameTimestamp, 2,
                       "The script's expected end state is attempt 2 (the only accepted, "
                       + "non-stale one). If this moved, re-derive it before changing it.")
    }

    // MARK: - Claim 11 — COUNTERWEIGHT: render/slew state is not delivery state

    /// SOURCE-TEXT SCAN. The tick still advances the slew anchor itself — gating the fade on an
    /// asynchronous completion would halve its rate whenever a completion lands after the next
    /// tick, a visible artefact on stage. `LightSendAttempt` carries no dimmer or colour field
    /// at all, so the conflation is impossible by the type as well as by these needles.
    func testTheSlewAnchorIsNotPartOfTheDeliveryContract() throws {
        for path in [Self.artNet, Self.sacn] {
            let src = SourceText.codeOnly(try text(path))
            XCTAssertTrue(src.contains("lastDimmer = limited"),
                          "\(path) no longer advances the slew anchor in the tick. FlashGuard's "
                          + "ramp is this app's own deterministic fade; moving it onto the "
                          + "delivery contract changes how fast the light moves.")
            XCTAssertFalse(src.contains("lastDimmer = attempt."),
                           "\(path) moved the slew anchor onto the delivery contract. That is "
                           + "the conflation #1445 exists to separate — render/slew advances "
                           + "on COMPUTE, delivery anchors on ACCEPTANCE.")
            XCTAssertFalse(src.contains("lastColour = attempt."),
                           "\(path) moved the colour slew anchor onto the delivery contract (#1445)")
        }
    }

    // MARK: - Claim 12 — the wire sequence is not a delivery proxy

    /// SOURCE-TEXT SCAN. Both protocols number packets so a receiver can reject out-of-order
    /// or duplicate data; a GAP (a packet the stack refused) is harmless, a REPEAT is not.
    /// So the sequence advances per packet CONSTRUCTED — in the tick — and never in the commit.
    func testTheWireSequenceAdvancesOnConstructionAndNotOnDelivery() throws {
        for path in [Self.artNet, Self.sacn] {
            let src = SourceText.codeOnly(try text(path))
            XCTAssertFalse(src.contains("sequence = attempt."),
                           "\(path) drives its wire sequence from the delivery contract. A "
                           + "retry would then reuse a number the receiver may treat as a "
                           + "duplicate and discard — turning the #1445 repair into a silent "
                           + "drop at the desk.")
            XCTAssertTrue(src.contains("sendGeneration &+= 1"),
                          "\(path) has no attempt generation, so nothing orders two in-flight "
                          + "completions and a late one can roll delivery state backward.")
            XCTAssertFalse(src.contains("generation: sequence"),
                           "\(path) uses the wire sequence AS the attempt generation. They are "
                           + "different facts: one is a protocol field a receiver reads, the "
                           + "other is local ordering. Conflating them makes a wire wrap "
                           + "(255→0 / 255→1) look like a stale completion.")
        }
    }

    // MARK: - Claim 13 — COUNTERWEIGHT: nothing queues pending sends

    /// SOURCE-TEXT SCAN. Each attempt carries its own bookkeeping in its completion closure,
    /// so there is no structure to grow under a stalled network. This is the bound the design
    /// requirement asked for, stated where a future edit would break it.
    func testNoPendingSendStructureIsIntroduced() throws {
        for path in [Self.artNet, Self.sacn] {
            let src = SourceText.codeOnly(try text(path))
            XCTAssertFalse(src.contains("[LightSendAttempt]"),
                           "\(path) grew a COLLECTION of pending attempts. Under a stalled "
                           + "network that is unbounded memory on the path that already has "
                           + "a hard real-time neighbour. One attempt per closure is the bound.")
        }
    }

}

#endif
