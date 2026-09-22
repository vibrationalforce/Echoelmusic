//
//  TheLightTransportRecoversFromAStallTests.swift
//  Echoelmusic — CISmoke (blocking bundle)
//
//  #1447 — the two things #1446 BOUNDED but did not FINISH. Both are about the moment the
//  network stops behaving, which is the only moment any of this accounting exists for.
//
//  ⛔ (a) STOP WAS AN sACN SENTENCE SPOKEN FOR BOTH PROTOCOLS. `LightSendPump.retire()` reset
//  the OUTPUT anchors on every stop, and for sACN that is right: `stop()` there sends three
//  Stream_Terminated packets (E1.31 §6.7.1.2), so the receiver has been told this SOURCE
//  SESSION ended. Art-Net has no terminate opcode at all. Stopping means a node simply stops
//  hearing us, and it holds its last DMX values until its own timeout — so after an Art-Net
//  stop the fixture is still sitting at the level we last got out. Restarting from "nothing"
//  put a one-frame 0→1 step on the wire: exactly the jump #1446 was written to forbid,
//  arriving through the front door of an ordinary stop/start.
//
//  ⛔ (b) THE ONE IN-FLIGHT SLOT HAD NO DEADLINE. #1446 wrote the residual down instead of
//  hiding it: if a completion never arrives — a connection parked with no route — the slot
//  stays occupied, and with it go blackout, grand master, the look and the keep-alive. A
//  wedged light output with no way back except an operator edit. The bound stays ONE; what
//  #1447 adds is a bounded TRANSPORT RECOVERY past `LightSendPump.stallDeadlineSeconds`.
//
//  ⚠️ WHAT EACH CLAIM CAN AND CANNOT PROVE (§1). Claims 1–6 and 10 are END-TO-END BEHAVIOUR
//  on shipped Foundation-only value types (`LightSendPump`, `FlashGuard`, `LightingStore`)
//  and, in claim 10, on the two real sender classes. Claims 7–9 are SOURCE-TEXT SCANS, which
//  is the only way to pin `sendIfFresh` and `stop()` — private members of `@MainActor`
//  classes no test bundle can tick without a socket and a bus.
//
//  ⚠️ NOTHING HERE IS A DEVICE PROBE, and nothing here claims REMOTE DELIVERY. The stall
//  deadline bounds how long THIS APP waits on its own `NWConnection` completion. It is not a
//  remote-delivery deadline, not a fixture-response deadline and not a NIC-transmission
//  deadline; UDP offers no such number at any layer this app can see. Whether a real fixture
//  ramps after a real outage is owed at a rig and is recorded as owed.
//

#if canImport(Network)
import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheLightTransportRecoversFromAStallTests: XCTestCase {

    private static let artNet = "Sources/Echoelmusic/Sync/ArtNetSender.swift"
    private static let sacn = "Sources/Echoelmusic/Sync/SACNSender.swift"
    private static let pumpFile = "Sources/Echoelmusic/Sync/LightSendAccounting.swift"

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func text(_ path: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(path), encoding: .utf8)
    }

    /// ONE tick of exactly the arithmetic both senders run after their send guard: slew the
    /// dimmer from the ACCEPTED anchor, slew a COPY of the accepted colour, submit. Returns
    /// nil while the pump is busy — the bound, expressed the way the senders express it.
    @discardableResult
    private func tick(_ pump: inout LightSendPump,
                      target: Float,
                      colourTarget: [Float] = [0, 0, 0],
                      blackout: Bool = false,
                      frame: TimeInterval = 0,
                      now: TimeInterval = 0) -> LightSendAttempt? {
        guard !pump.isBusy else { return nil }
        let look = LightingStore.defaultLookIntensity
        let creative = LightingStore.creativeTarget(target, lookIntensity: look)
        let mastered = ArtNetSender.masteredDimmer(creative, grandMaster: 1, blackout: blackout)
        let limited = FlashGuard.slewedDimmer(from: pump.acceptedDimmer, to: mastered,
                                              blackout: blackout,
                                              maxDelta: FlashGuard.senderTickDelta)
        var colour = pump.acceptedColour
        if colour.count != 3 { colour = [-1, -1, -1] }
        for c in 0..<3 {
            colour[c] = FlashGuard.slewedDimmer(from: colour[c], to: colourTarget[c],
                                                blackout: false,
                                                maxDelta: FlashGuard.senderTickDelta)
        }
        return pump.submit(frameTimestamp: frame, grandMaster: 1, blackout: blackout,
                           lookIntensity: look, sentAt: now, dimmer: limited, colour: colour)
    }

    /// Bring a pump to a committed output state of `dimmer` / `colour`, on an open epoch.
    private func seated(dimmer: Float, colour: [Float]) -> LightSendPump {
        var pump = LightSendPump()
        pump.openEpoch()
        guard let first = tick(&pump, target: dimmer, colourTarget: colour, frame: 1, now: 100) else {
            XCTFail("the seating tick submitted nothing")
            return pump
        }
        pump.complete(first, failed: false)
        // The first packet on a virgin anchor SNAPS (anchor -1 = no history), which is what
        // makes this a clean seat rather than a partial ramp.
        XCTAssertEqual(pump.acceptedDimmer, dimmer, accuracy: 1e-6, "the seat did not take")
        XCTAssertEqual(pump.acceptedColour, colour, "the colour seat did not take")
        return pump
    }

    // MARK: - Claim 1 — BLOCKER A: an Art-Net stop/restart ramps, it does not jump

    /// END-TO-END BEHAVIOUR, and the required case: accepted output 0.20 / a nontrivial
    /// colour, stop, restart, desired 1.0 / a distant colour. The first post-restart candidate
    /// must be bounded by `FlashGuard.senderTickDelta` from 0.20 and from each old component.
    func testAnArtNetRestartRampsFromTheLevelTheNodeIsStillHolding() {
        let colourA: [Float] = [0.90, 0.10, 0.40]
        var pump = seated(dimmer: 0.20, colour: colourA)

        pump.retire()      // ArtNetSender.stop() — TRANSPORT retirement, and nothing else
        XCTAssertFalse(pump.isBusy, "the stop left the one in-flight slot occupied")
        XCTAssertEqual(pump.acceptedDimmer, 0.20, accuracy: 1e-6, """
        an Art-Net stop dropped the accepted dimmer. Art-Net has NO terminate opcode: the node \
        is still holding 0.20 until its own timeout, so this is the only value the next packet \
        may be measured from (#1447(a)).
        """)
        XCTAssertEqual(pump.acceptedColour, colourA, "an Art-Net stop dropped the accepted colour")

        pump.openEpoch()   // start() -> connect()
        let colourB: [Float] = [0.05, 0.95, 0.05]
        guard let first = tick(&pump, target: 1.0, colourTarget: colourB, frame: 2, now: 200) else {
            return XCTFail("THE RESTART WAS SILENT: nothing submitted although the state stands")
        }

        let step = Float(FlashGuard.senderTickDelta)
        XCTAssertLessThanOrEqual(abs(first.dimmer - 0.20), step + 1e-6, """
        the first post-restart Art-Net packet moved \(abs(first.dimmer - 0.20)) from the level \
        the node is holding; the bound is \(step). THIS IS THE #1446 JUMP, re-entered through \
        an ordinary stop/start.
        """)
        XCTAssertNotEqual(first.dimmer, 1.0, "the first post-restart packet jumped straight to target")
        XCTAssertGreaterThan(first.dimmer, 0.20, "the ramp did not move at all — the case is vacuous")
        for c in 0..<3 {
            XCTAssertLessThanOrEqual(abs(first.colour[c] - colourA[c]), step + 1e-6, """
            post-restart colour component \(c) moved \(abs(first.colour[c] - colourA[c])) from \
            \(colourA[c]); the bound is \(step). A fast hue swing at high dimmer strobes even \
            when the dimmer itself is limited.
            """)
        }
        XCTAssertNotEqual(first.colour, colourB, "the colour jumped straight to its destination")
    }

    // MARK: - Claim 2 — the sACN policy is DIFFERENT, on purpose, and it is source-session

    /// END-TO-END BEHAVIOUR. sACN announced the end of the source session, so its next session
    /// legitimately starts from nothing. ⛔ The claim stays narrow: Stream_Terminated expresses
    /// SOURCE TERMINATION. It does not prove a fixture went dark, released physically, or that
    /// the three packets arrived at all — it is UDP, and the receiver's own merge/hold
    /// configuration decides what happens next. What is asserted is only what WE stop claiming.
    func testAnSACNRestartIsANewSourceSessionAndStartsCold() {
        var pump = seated(dimmer: 0.20, colour: [0.90, 0.10, 0.40])

        pump.retire()                  // SACNSender.stop(), first half — the same transport law
        pump.forgetAcceptedOutput()    // ...and the second half, which ONLY sACN is entitled to
        XCTAssertEqual(pump.acceptedDimmer, -1, "the source session ended and an anchor survived")
        XCTAssertTrue(pump.acceptedColour.isEmpty, "the source session ended and a colour survived")

        pump.openEpoch()
        guard let first = tick(&pump, target: 1.0, colourTarget: [0.05, 0.95, 0.05],
                               frame: 2, now: 200) else {
            return XCTFail("the restarted sACN session submitted nothing")
        }
        XCTAssertEqual(first.dimmer, 1.0, accuracy: 1e-6, """
        a new sACN source session must SNAP to its first value — a cold start has no level to \
        ramp from, and pretending it has one is a different lie from the Art-Net one.
        """)
    }

    // MARK: - Claim 3 — BLOCKER B: below the deadline nothing changes

    /// END-TO-END BEHAVIOUR. A never-completing attempt keeps exactly ONE outstanding send,
    /// however many ticks and control moves land on top of it.
    func testBelowTheDeadlineAStalledSendStillBoundsEverythingToOne() {
        var pump = seated(dimmer: 0.20, colour: [0.2, 0.2, 0.2])
        guard let stuck = tick(&pump, target: 0.30, frame: 2, now: 1_000) else {
            return XCTFail("nothing submitted")
        }
        XCTAssertTrue(pump.isBusy, "the case is vacuous — nothing is outstanding")
        let generationAtStall = pump.generation

        // 20 ticks, a blackout among them, all inside the deadline.
        var submitted = 0
        for i in 1...20 {
            let now = 1_000 + Double(i) * FlashGuard.senderTickSeconds
            XCTAssertFalse(pump.stalled(now: now, after: LightSendPump.stallDeadlineSeconds),
                           "the deadline fired early, at \(now - 1_000) s")
            if tick(&pump, target: 1.0, blackout: i > 10, frame: TimeInterval(2 + i), now: now) != nil {
                submitted += 1
            }
        }
        XCTAssertEqual(submitted, 0, "a second ordinary packet was built while one was outstanding")
        XCTAssertEqual(pump.generation, generationAtStall, "a generation was burned on a tick that built nothing")
        XCTAssertEqual(pump.inFlight ?? 0, stuck.generation, "the slot changed hands without a completion")
        XCTAssertEqual(pump.acceptedDimmer, 0.20, accuracy: 1e-6, "an uncompleted send moved the output anchor")
    }

    // MARK: - Claim 4 — crossing the deadline frees the slot and lets blackout out

    /// END-TO-END BEHAVIOUR, and the heart of blocker B. Past the deadline the epoch is
    /// declared stale; the recovery (`reconnectIfActive()` → `connect()` → `openEpoch()`) frees
    /// the slot, arms the resend and KEEPS the output anchors. The abandoned attempt's late
    /// completion commits nothing, and the first eligible packet carries the blackout.
    func testPastTheDeadlineTheEpochIsRetiredAndBlackoutGetsOut() {
        var pump = seated(dimmer: 0.60, colour: [0.3, 0.4, 0.5])
        guard let stuck = tick(&pump, target: 0.70, frame: 2, now: 1_000) else {
            return XCTFail("nothing submitted")
        }
        let epochAtStall = pump.epoch

        let deadline = 1_000 + LightSendPump.stallDeadlineSeconds
        XCTAssertFalse(pump.stalled(now: deadline - 0.001, after: LightSendPump.stallDeadlineSeconds),
                       "the deadline fired one millisecond early")
        // ⚠️ ASKED ONE TICK PAST THE DEADLINE, NOT EXACTLY ON IT, and the reason is arithmetic
        // rather than slack: `(1_000 + 0.8) - 1_000` is 0.799999999999954 in `Double`, so an
        // assertion exactly on the boundary would test the rounding of a thousand-second offset
        // instead of the policy. The senders only ask on tick boundaries anyway, so "stale by
        // the first tick after the deadline" is the real-world claim — and the line above still
        // proves it does not fire early.
        let firstTickPast = deadline + FlashGuard.senderTickSeconds
        XCTAssertTrue(pump.stalled(now: firstTickPast, after: LightSendPump.stallDeadlineSeconds), """
        the slot is still not declared stale a full \(LightSendPump.stallDeadlineSeconds) s after \
        submission. That is the wedged output #1447(b) exists to end.
        """)

        pump.openEpoch()   // what reconnectIfActive() -> connect() does
        XCTAssertFalse(pump.isBusy, "the recovery did not free the one in-flight slot")
        XCTAssertGreaterThan(pump.epoch, epochAtStall, "the recovery did not open a new epoch")
        XCTAssertTrue(pump.needsResend, "the recovery did not arm the current state for resend")
        XCTAssertEqual(pump.acceptedDimmer, 0.60, accuracy: 1e-6, """
        the stall recovery dropped the OUTPUT anchor. A recovery is a transport event: nothing \
        about it tells us the fixture stopped holding 0.60, and starting the next ramp from \
        nothing is the #1446 jump again.
        """)
        XCTAssertFalse(pump.stalled(now: firstTickPast + 10, after: LightSendPump.stallDeadlineSeconds),
                       "one stalled epoch armed a SECOND recovery — this is the reconnect storm")

        // The blackout that could not get out during the stall is the first thing that does.
        guard let recovery = tick(&pump, target: 1.0, blackout: true, frame: 9,
                                  now: firstTickPast) else {
            return XCTFail("the recovered epoch submitted nothing — blackout is still trapped")
        }
        XCTAssertEqual(recovery.dimmer, 0, "the first packet after recovery is not the blackout cut")
        XCTAssertTrue(recovery.blackout, "the recovered packet does not carry the blackout state")
        XCTAssertEqual(pump.inFlight ?? 0, recovery.generation, "the new epoch is not bounded to one send")
        XCTAssertGreaterThan(recovery.generation, stuck.generation, "generations went backwards")
        XCTAssertEqual(recovery.epoch, pump.epoch, "the recovered packet was stamped with the dead epoch")

        // ...and the abandoned attempt finally lands. It must change nothing.
        pump.complete(stuck, failed: false)
        XCTAssertEqual(pump.acceptedDimmer, 0.60, accuracy: 1e-6,
                       "a completion from the abandoned epoch committed its output")
        XCTAssertEqual(pump.acceptedFrameTimestamp, 1, "a completion from the abandoned epoch committed its frame")
        XCTAssertEqual(pump.inFlight ?? 0, recovery.generation, """
        the abandoned attempt's late completion freed the CURRENT epoch's slot. An old socket \
        must not be able to hand the live one a free pass.
        """)
        pump.complete(recovery, failed: false)
        XCTAssertEqual(pump.acceptedDimmer, 0, "the blackout packet never committed")
        XCTAssertTrue(pump.acceptedBlackout, "the blackout never reached the delivery anchors")
    }

    // MARK: - Claim 5 — blackout release still slews, after a recovery like anywhere else

    /// END-TO-END BEHAVIOUR, COUNTERWEIGHT (#343). Nothing about a stall recovery may turn the
    /// return to light into a jump: the release rides the same limiter from the accepted 0.
    func testBlackoutReleaseAfterARecoveryStillRamps() {
        var pump = seated(dimmer: 0.60, colour: [0.3, 0.4, 0.5])
        guard let cut = tick(&pump, target: 1.0, blackout: true, frame: 2, now: 1_000) else {
            return XCTFail("no blackout packet")
        }
        pump.complete(cut, failed: false)
        XCTAssertEqual(pump.acceptedDimmer, 0, "the blackout cut did not commit")
        pump.openEpoch()   // a recovery, or a reconnect — same transition
        guard let release = tick(&pump, target: 1.0, blackout: false, frame: 3, now: 1_001) else {
            return XCTFail("the release submitted nothing")
        }
        XCTAssertEqual(Double(release.dimmer), FlashGuard.senderTickDelta, accuracy: 1e-6, """
        releasing blackout jumped to \(release.dimmer) instead of stepping \
        \(FlashGuard.senderTickDelta) from the accepted dark state.
        """)
    }

    // MARK: - Claim 6 — the deadline is derived, not invented

    /// END-TO-END BEHAVIOUR on constants. The stall deadline is the senders' keep-alive budget
    /// (#416, one decision seen from both sides), comfortably above the send loop and strictly
    /// below both receivers' own patience so a replaced epoch can re-send before the far side
    /// declares the source lost.
    func testTheStallDeadlineIsTheKeepAliveBudget() {
        XCTAssertEqual(LightSendPump.stallDeadlineSeconds, SACNSender.keepAliveSeconds, """
        the stall deadline drifted away from the keep-alive budget. They are one decision: the \
        longest the wire may be quiet, and the longest one attempt may keep it quiet (#416).
        """)
        XCTAssertEqual(SACNSender.keepAliveSeconds, ArtNetSender.keepAliveSeconds,
                       "the two light outputs no longer share the keep-alive budget")
        XCTAssertGreaterThan(LightSendPump.stallDeadlineSeconds, FlashGuard.senderTickSeconds * 10, """
        the deadline is within ten send ticks. Local processing of a ~530-byte datagram on a \
        ready connection is sub-millisecond, so a deadline this tight would fire on healthy \
        traffic and reconnect a working socket.
        """)
        // E1.31 §6.7.1 declares a source lost after 2.5 s; an Art-Net node holds ~4 s. The
        // recovery has to happen INSIDE the tighter of the two to be worth anything.
        XCTAssertLessThan(LightSendPump.stallDeadlineSeconds, 2.5, """
        the deadline is at or past E1.31's 2.5 s source-lost timeout: the receiver would give \
        up on us before the recovery could re-send anything.
        """)
    }

    // MARK: - Claim 7 — the recovery is wired into both ticks, before the bound

    /// SOURCE-TEXT SCAN. The check must sit BEFORE `guard !pump.isBusy`, because it is the
    /// only thing that can free a slot no completion will free.
    func testBothSendersCheckForAStallBeforeTheBound() throws {
        for path in [Self.artNet, Self.sacn] {
            let src = SourceText.codeOnly(try text(path))
            XCTAssertTrue(src.contains("pump.stalled(now: CFAbsoluteTimeGetCurrent()"), """
            \(path) never asks whether its one in-flight slot has stalled. Without it a \
            completion that never arrives wedges the output forever (#1447(b)).
            """)
            XCTAssertTrue(src.contains("after: LightSendPump.stallDeadlineSeconds"), """
            \(path) uses a deadline other than the shared one. A second number here is a \
            second policy (#416).
            """)
            XCTAssertTrue(src.contains("reconnectIfActive()"), """
            \(path) does not recover through the ONE connection-replacement path. A private \
            second reconnect is a second definition of "replace the socket".
            """)
            guard let stallAt = src.range(of: "pump.stalled(now:"),
                  let boundAt = src.range(of: "guard !pump.isBusy") else {
                return XCTFail("\(path): the stall check or the in-flight bound is gone")
            }
            XCTAssertLessThan(stallAt.lowerBound, boundAt.lowerBound, """
            \(path) checks for a stall AFTER `guard !pump.isBusy`, so the guard returns first \
            and the recovery can never run. That is the wedge with a comment on it.
            """)
        }
    }

    // MARK: - Claim 8 — the two stop policies differ, and only in the documented direction

    /// SOURCE-TEXT SCAN. sACN forgets its accepted output because it said goodbye; Art-Net
    /// does not, because it cannot say anything.
    func testOnlyTheProtocolThatSaysGoodbyeForgetsItsOutput() throws {
        let art = SourceText.codeOnly(try text(Self.artNet))
        let sac = SourceText.codeOnly(try text(Self.sacn))
        XCTAssertTrue(art.contains("pump.retire()"), "ArtNetSender.stop() no longer retires the transport")
        XCTAssertFalse(art.contains("forgetAcceptedOutput"), """
        ArtNetSender forgets its accepted output. Art-Net has no terminate opcode — the node \
        keeps holding the last level, and the next session must ramp from it (#1447(a)).
        """)
        XCTAssertTrue(sac.contains("pump.retire()"), "SACNSender.stop() no longer retires the transport")
        XCTAssertTrue(sac.contains("pump.forgetAcceptedOutput()"), """
        SACNSender no longer forgets its accepted output although `sayGoodbye()` still \
        announces the end of the source session. The two must move together.
        """)
        XCTAssertTrue(sac.contains("sayGoodbye()"), """
        the Stream_Terminated burst is gone, which removes the ONLY justification for the \
        line above it.
        """)
        // #486 — the absence above is ONE finding; it is not repeated per call site.
    }

    // MARK: - Claim 9 — the separation is real in the pump, and nothing accumulated

    /// SOURCE-TEXT SCAN. `retire()` is transport-only; the output reset lives in its own
    /// method; and the recovery introduced no queue.
    func testTheTransportRetirementTouchesNoOutputAnchor() throws {
        let src = SourceText.codeOnly(try text(Self.pumpFile))
        guard let start = src.range(of: "public mutating func retire() {"),
              let end = src.range(of: "\n    }", range: start.upperBound..<src.endIndex) else {
            return XCTFail("`LightSendPump.retire()` is gone or was reshaped beyond this anchor")
        }
        let body = String(src[start.upperBound..<end.lowerBound])
        for anchor in ["acceptedDimmer", "acceptedColour"] {
            XCTAssertFalse(body.contains(anchor), """
            `retire()` still writes `\(anchor)`. Transport retirement does not decide what a \
            receiver is holding — that sentence belongs to `forgetAcceptedOutput()`, and only \
            an adapter whose protocol announced the end of its source session may speak it.
            """)
        }
        XCTAssertTrue(src.contains("public mutating func forgetAcceptedOutput()"),
                      "the output-anchor reset has no home of its own")
        XCTAssertTrue(src.contains("inFlightSince = sentAt"),
                      "nothing records WHEN the in-flight attempt took the slot, so it cannot stall")
        XCTAssertEqual(src.components(separatedBy: "inFlightSince = ").count - 1, 1,
                       "`inFlightSince` has a second writer; it is meaningful only as `submit` set it")
        for needle in ["[LightSendAttempt]", "Array<LightSendAttempt>", "pending"] {
            XCTAssertFalse(src.contains(needle), """
            \(Self.pumpFile) grew a `\(needle)`. The recovery must not have become a queue — \
            a backlog delivers STALE pre-blackout packets first, which is worse than waiting.
            """)
        }
    }

    // MARK: - Claim 10 — both real senders, same law

    /// END-TO-END BEHAVIOUR on the two shipped classes, through the real `applySendOutcome`.
    /// A completion from a retired epoch is refused identically by both.
    func testBothRealSendersRefuseTheAbandonedEpoch() {
        let art = ArtNetSender()
        let sacn = SACNSender()
        let stale = LightSendAttempt(epoch: art.pump.epoch &+ 7, generation: 1, frameTimestamp: 5,
                                     grandMaster: 1, blackout: false,
                                     lookIntensity: LightingStore.defaultLookIntensity,
                                     sentAt: 5_000, dimmer: 1, colour: [1, 1, 1])
        art.applySendOutcome(stale, failed: false)
        sacn.applySendOutcome(stale, failed: false)
        XCTAssertEqual(art.pump.acceptedDimmer, -1, "Art-Net committed an abandoned epoch's output")
        XCTAssertEqual(sacn.pump.acceptedDimmer, -1, "sACN committed an abandoned epoch's output")
        XCTAssertEqual(art.lastSentTimestamp, 0, "Art-Net re-stamped its keep-alive from a dead epoch")
        XCTAssertEqual(sacn.lastSentTimestamp, 0, "sACN re-stamped its keep-alive from a dead epoch")
        XCTAssertFalse(art.pump.stalled(now: 9_999, after: LightSendPump.stallDeadlineSeconds), """
        a sender with an EMPTY slot reports a stall. `stalled` must be false whenever \
        `inFlight` is nil, or every idle tick would reconnect.
        """)
        XCTAssertFalse(sacn.pump.stalled(now: 9_999, after: LightSendPump.stallDeadlineSeconds),
                       "an idle sACN sender reports a stall")
    }
}
#endif
