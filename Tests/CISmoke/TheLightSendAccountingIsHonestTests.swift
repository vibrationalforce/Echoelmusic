//
//  TheLightSendAccountingIsHonestTests.swift
//  Echoelmusic — CISmoke (blocking bundle)
//
//  #1445/#1446 — a light packet that was never locally processed may not advance ANY of
//  this sender's state: not the dedup anchors that decide whether to retry, and not the
//  slew anchors that decide how far the next packet's value may move.
//
//  ⛔ THE TWO DEFECTS, IN ORDER, because the second one hid behind the first.
//  #1445: both senders wrote their `lastSent…` anchors in the tick, before `send` had even
//  looked for a socket, so a no-connection tick consumed `lookMoved`, `masterMoved`, the
//  freshness compare and the keep-alive clock. Pull the cable, hit Blackout, plug back in —
//  nothing was re-sent, because from the sender's point of view it already had been.
//  #1446: the FADE was still computed-relative. `lastDimmer = limited` and the in-place
//  `lastColour` advanced every tick whether or not anything reached the stack, so an outage
//  finished the ramp INSIDE the app. Dark → command full → outage for a second → reconnect,
//  and the first packet a receiver saw carried the END of the ramp: a 0→1 step in one DMX
//  frame, out of the slew-limiter written to make exactly that impossible. Nothing bounded
//  outstanding sends, and a replaced connection kept committing into the new one's books.
//
//  ⚠️ WHAT EACH CLAIM CAN AND CANNOT PROVE (§1). Claims 1–10 are END-TO-END BEHAVIOUR on
//  `LightSendPump` + `FlashGuard` — shipped, public, Foundation-only value types, driven
//  through the real sequence tick → submit → delayed completion → more ticks → completion →
//  next submission. They prove the STATE MACHINE. They cannot prove that `sendIfFresh` uses
//  it, because that method is private on a class no test bundle can tick without a socket
//  and a bus; claims 11–15 are SOURCE-TEXT SCANS pinning the four expressions that connect
//  the two. Claim 16 drives both senders' real `applySendOutcome`. No claim here is a DEVICE
//  PROBE: whether a fixture ramps is owed at a rig and is recorded as owed.
//
//  ⚠️ AND NOTHING HERE PROVES REMOTE DELIVERY, in any claim. `.contentProcessed` reports
//  that the connection finished processing the content, or the error that stopped it. On UDP
//  nothing above this layer can know more.
//

#if canImport(Network)
import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheLightSendAccountingIsHonestTests: XCTestCase {

    private static let artNet = "Sources/Echoelmusic/Sync/ArtNetSender.swift"
    private static let sacn = "Sources/Echoelmusic/Sync/SACNSender.swift"
    private static let pumpFile = "Sources/Echoelmusic/Sync/LightSendAccounting.swift"

    /// DELIVERY/DEDUP anchors — what the next tick compares against. Exactly ONE writer each,
    /// the line in `LightSendPump.complete`.
    private static let deliveryAnchors = [
        "acceptedFrameTimestamp",
        "acceptedGrandMaster",
        "acceptedBlackout",
        "acceptedLookIntensity",
        "acceptedSentAt"
    ]

    /// OUTPUT anchors — what the slew step is measured from. TWO writers each, and the second
    /// one is not a leak: `retire()` drops them on stop, because after Stream_Terminated (or an
    /// Art-Net node's timeout) nothing on the far side is holding a level to ramp from.
    private static let outputAnchors = ["acceptedDimmer", "acceptedColour"]

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func text(_ path: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(path), encoding: .utf8)
    }

    // MARK: - The shipped tick, driven against a real pump

    /// ONE tick of exactly the arithmetic `sendIfFresh` runs after its send guard: slew the
    /// dimmer from the ACCEPTED anchor, slew a COPY of the accepted colour, submit. Returns
    /// nil when the pump is busy — which is the whole bound, expressed the way the senders
    /// express it (`guard !pump.isBusy else { return }`, pinned by claim 12).
    @discardableResult
    private func tick(_ pump: inout LightSendPump,
                      target: Float,
                      colourTarget: [Float] = [0, 0, 0],
                      blackout: Bool = false,
                      frame: TimeInterval = 0,
                      master: Float = 1,
                      look: Float = LightingStore.defaultLookIntensity,
                      now: TimeInterval = 0) -> LightSendAttempt? {
        guard !pump.isBusy else { return nil }
        let creative = LightingStore.creativeTarget(target, lookIntensity: look)
        let mastered = ArtNetSender.masteredDimmer(creative, grandMaster: master, blackout: blackout)
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
        return pump.submit(frameTimestamp: frame, grandMaster: master, blackout: blackout,
                           lookIntensity: look, sentAt: now, dimmer: limited, colour: colour)
    }

    // MARK: - Claim 1 — the rule itself

    /// END-TO-END BEHAVIOUR on the shipped pure rule. Three independent refusals plus the
    /// `>` versus `>=` case, which is the one a reader is most likely to "simplify".
    func testAFailureAStaleEpochAndAStaleGenerationAllRefuse() {
        let a = LightSendAttempt(epoch: 3, generation: 5, frameTimestamp: 1, grandMaster: 1,
                                 blackout: false, lookIntensity: 1, sentAt: 10,
                                 dimmer: 0.5, colour: [0, 0, 0])
        XCTAssertTrue(LightSendAccounting.commits(a, over: 4, epoch: 3, failed: false),
                      "a newer attempt on the current epoch with no error must commit")
        XCTAssertFalse(LightSendAccounting.commits(a, over: 4, epoch: 3, failed: true),
                       "a completion that reported an error committed anyway (#1445)")
        XCTAssertFalse(LightSendAccounting.commits(a, over: 4, epoch: 4, failed: false),
                       "a completion from a REPLACED connection committed into the current "
                       + "one. That is how a late success on an old endpoint tells the new "
                       + "endpoint its state is already out (#1446).")
        XCTAssertFalse(LightSendAccounting.commits(a, over: 9, epoch: 3, failed: false),
                       "a late completion of an older packet rolled state backward (#1445)")
        XCTAssertFalse(LightSendAccounting.commits(a, over: 5, epoch: 3, failed: false),
                       "the comparison is `>=` again — a DUPLICATE completion of the same "
                       + "attempt can then re-stamp the keep-alive clock on no new packet.")
    }

    // MARK: - Claim 2 — case A, the in-flight bound

    /// END-TO-END BEHAVIOUR. Thirty ticks arrive while one completion is outstanding. The
    /// bound is structural — one optional slot — so the proof is that thirty ticks produce
    /// exactly ONE attempt and burn exactly ONE generation.
    func testManyTicksDuringOneDelayedCompletionProduceOneSend() {
        var pump = LightSendPump()
        pump.openEpoch()
        guard let first = tick(&pump, target: 1) else {
            return XCTFail("the first tick produced no attempt")
        }
        var extra = 0
        for i in 0..<30 {
            if tick(&pump, target: 1, frame: TimeInterval(i + 1)) != nil { extra += 1 }
        }
        XCTAssertEqual(extra, 0, """
        \(extra) further ordinary data sends were submitted while one was still outstanding. \
        MAX_IN_FLIGHT is 1 and it is the only thing bounding this sender's outstanding work \
        by code rather than by how fast the network happens to be (#1446).
        """)
        XCTAssertTrue(pump.isBusy, "the slot freed itself without a completion")
        XCTAssertEqual(pump.generation, first.generation,
                       "a blocked tick burned a generation. A tick that cannot send must "
                       + "build nothing at all — no packet, no generation, no sequence.")
        pump.complete(first, failed: false)
        XCTAssertFalse(pump.isBusy, "the completion did not free the one in-flight slot")
        XCTAssertNotNil(tick(&pump, target: 1, frame: 99),
                        "the sender stayed blocked after its completion arrived")
    }

    // MARK: - Claim 3 — case B, coalescing

    /// END-TO-END BEHAVIOUR. Control state moves several times while a send is pending. The
    /// contract is LATEST-STATE COALESCING, not one datagram per control event: the
    /// intermediate values are intentionally never put on the wire, and the next packet
    /// carries the newest of them.
    func testTheNextPacketCarriesTheLatestDesiredStateNotEveryIntermediate() {
        var pump = LightSendPump()
        pump.openEpoch()
        guard let pending = tick(&pump, target: 0.5, master: 1, look: 1) else {
            return XCTFail("no first attempt")
        }
        // Three creative/operator moves arrive while `pending` is outstanding.
        for (m, l) in [(Float(0.9), Float(0.9)), (0.8, 0.8), (0.7, 0.7)] {
            XCTAssertNil(tick(&pump, target: 0.5, master: m, look: l),
                         "a control event enqueued its own datagram — the sender is "
                         + "event-driven again and the bound is not a bound (#1446)")
        }
        pump.complete(pending, failed: false)
        guard let next = tick(&pump, target: 0.5, master: 0.7, look: 0.7) else {
            return XCTFail("nothing was sent after the pending completion resolved")
        }
        XCTAssertEqual(next.grandMaster, 0.7, "the next packet carried a stale master")
        XCTAssertEqual(next.lookIntensity, 0.7, "the next packet carried a stale creative level")
        XCTAssertEqual(pump.generation, 2, """
        \(pump.generation) generations were burned for one pending send plus one catch-up. \
        The intermediate control states must be coalesced, never queued.
        """)
    }

    // MARK: - Claim 4 — case C, the failed dimmer ramp (the core safety proof)

    /// END-TO-END BEHAVIOUR, and the reason #1446 exists. The accepted output is dark, the
    /// desired output is full, and the network refuses for long enough that the OLD
    /// implementation would have reached 1.0 internally. Every candidate must still be one
    /// slew step above the last ACCEPTED value — and after recovery the ramp continues from
    /// there rather than from wherever the app had walked to.
    func testAnOutageCannotFinishAFadeTheNetworkNeverTook() {
        var pump = LightSendPump()
        pump.openEpoch()
        // Seed an ACCEPTED dark state, the way a real session reaches one.
        guard let dark = tick(&pump, target: 0, now: 100) else { return XCTFail("no seed") }
        pump.complete(dark, failed: false)
        XCTAssertEqual(pump.acceptedDimmer, 0, "the seed did not establish an accepted dark state")

        // 30 ticks, every one failing. 30 × 0.08 is far past full scale.
        for i in 0..<30 {
            guard let a = tick(&pump, target: 1, frame: TimeInterval(i + 1)) else {
                return XCTFail("tick \(i) produced no attempt although nothing was outstanding")
            }
            XCTAssertLessThanOrEqual(Double(a.dimmer - 0), FlashGuard.senderTickDelta + 1e-6, """
            attempt \(i) carried \(a.dimmer) while the last dimmer the network ACCEPTED was 0. \
            A slew-limiter measured from a value nobody received is not a slew-limiter: this \
            is the 0→1 jump in one DMX frame that #1446 exists to make impossible.
            """)
            pump.complete(a, failed: true)
            XCTAssertEqual(pump.acceptedDimmer, 0,
                           "a FAILED send advanced the accepted output anchor (#1446)")
        }
        // Recovery: the ramp continues from the accepted anchor, one step at a time.
        var accepted: [Float] = []
        for _ in 0..<3 {
            guard let a = tick(&pump, target: 1) else { return XCTFail("no attempt after recovery") }
            pump.complete(a, failed: false)
            accepted.append(pump.acceptedDimmer)
        }
        XCTAssertEqual(accepted.count, 3)
        XCTAssertEqual(Double(accepted[0]), FlashGuard.senderTickDelta, accuracy: 1e-6,
                       "the first accepted packet after recovery did not start at one step")
        XCTAssertGreaterThan(accepted[1], accepted[0], "the ramp did not continue after recovery")
        XCTAssertGreaterThan(accepted[2], accepted[1], "the ramp did not continue after recovery")
    }

    // MARK: - Claim 5 — case D, the failed colour ramp

    /// END-TO-END BEHAVIOUR. The same law on the colour channels, which carry the same
    /// luminance risk at a high dimmer (the Law 6 gap `applySlewedColour` was written for).
    func testAnOutageCannotWalkTheHueToItsDestination() {
        var pump = LightSendPump()
        pump.openEpoch()
        guard let seed = tick(&pump, target: 1, colourTarget: [0, 0, 0]) else {
            return XCTFail("no seed")
        }
        pump.complete(seed, failed: false)
        let accepted0 = pump.acceptedColour
        XCTAssertEqual(accepted0.count, 3, "the seed did not establish an accepted colour")

        for i in 0..<30 {
            guard let a = tick(&pump, target: 1, colourTarget: [1, 1, 1],
                               frame: TimeInterval(i + 1)) else {
                return XCTFail("tick \(i) produced no attempt")
            }
            for c in 0..<3 {
                XCTAssertLessThanOrEqual(Double(a.colour[c] - accepted0[c]),
                                         FlashGuard.senderTickDelta + 1e-6, """
                colour channel \(c) reached \(a.colour[c]) while the last value the network \
                ACCEPTED was \(accepted0[c]). The in-place `lastColour` walked the hue to its \
                destination during an outage; the candidate must be a COPY that dies with the \
                packet (#1446).
                """)
            }
            pump.complete(a, failed: true)
            XCTAssertEqual(pump.acceptedColour, accepted0,
                           "a FAILED send advanced the accepted colour anchor (#1446)")
        }
    }

    // MARK: - Claim 6 — case E, blackout under an in-flight send

    /// END-TO-END BEHAVIOUR. Blackout is a safety/operator state, not a creative value: it
    /// may be DELAYED by the one outstanding send, never LOST. It reaches the wire on the
    /// first eligible tick after that completion, and it cuts to 0 rather than ramping down.
    func testBlackoutIsDelayedByAnInFlightSendButNeverLost() {
        var pump = LightSendPump()
        pump.openEpoch()
        guard let lit = tick(&pump, target: 1) else { return XCTFail("no lit attempt") }
        pump.complete(lit, failed: false)
        guard let pending = tick(&pump, target: 1, frame: 1) else { return XCTFail("no pending") }
        // The operator hits Blackout while `pending` is outstanding.
        XCTAssertNil(tick(&pump, target: 1, blackout: true, frame: 1),
                     "blackout jumped the bound and made a second send outstanding. The bound "
                     + "would then not be a bound, and a backlog delivers STALE pre-blackout "
                     + "packets first on recovery (#1446).")
        XCTAssertFalse(pump.acceptedBlackout, "a blackout committed without any packet")
        pump.complete(pending, failed: false)
        guard let cut = tick(&pump, target: 1, blackout: true, frame: 1) else {
            return XCTFail("BLACKOUT WAS LOST: nothing was submitted after the slot freed")
        }
        XCTAssertTrue(cut.blackout, "the first packet after the slot freed was not the blackout")
        XCTAssertEqual(cut.dimmer, 0, accuracy: 1e-6,
                       "blackout ramped down instead of cutting. An intentional cut to dark is "
                       + "not a flash; only the RETURN to light is slew-limited.")
    }

    // MARK: - Claim 7 — case F, blackout release

    /// END-TO-END BEHAVIOUR. The return to light rides the limiter, measured from the
    /// accepted dark state — the half of the blackout contract that is a flash risk.
    func testReleasingBlackoutRampsFromTheAcceptedDarkState() {
        var pump = LightSendPump()
        pump.openEpoch()
        guard let cut = tick(&pump, target: 1, blackout: true) else { return XCTFail("no cut") }
        pump.complete(cut, failed: false)
        XCTAssertEqual(pump.acceptedDimmer, 0, accuracy: 1e-6, "the cut did not accept a dark state")
        guard let release = tick(&pump, target: 1, blackout: false, frame: 1) else {
            return XCTFail("nothing was sent when blackout was released")
        }
        XCTAssertLessThanOrEqual(Double(release.dimmer), FlashGuard.senderTickDelta + 1e-6, """
        releasing blackout jumped to \(release.dimmer) in one packet. The whole reason a cut \
        to dark is allowed to be instant is that the way back is not.
        """)
    }

    // MARK: - Claim 8 — case G, the connection epoch

    /// END-TO-END BEHAVIOUR. An attempt is outstanding on the old endpoint when the operator
    /// corrects the host. Its late SUCCESS must not commit, and the new endpoint must be
    /// eligible at once rather than after the keep-alive.
    func testALateSuccessOnAReplacedConnectionCannotCommit() {
        var pump = LightSendPump()
        pump.openEpoch()
        guard let old = tick(&pump, target: 1, frame: 7, master: 0.3, look: 0.3, now: 500) else {
            return XCTFail("no attempt on the old endpoint")
        }
        pump.openEpoch()                      // operator changes host/port/universe
        XCTAssertFalse(pump.isBusy, "the new connection inherited the old one's in-flight slot")
        pump.complete(old, failed: false)     // the old socket's completion lands late
        XCTAssertEqual(pump.acceptedFrameTimestamp, -1, """
        a completion from the REPLACED connection committed into the current one. The next \
        tick then believes the new endpoint already has this state and sends it nothing \
        until the keep-alive (#1446).
        """)
        XCTAssertEqual(pump.acceptedGrandMaster, 1, "the old endpoint committed a master anchor")
        XCTAssertEqual(pump.acceptedSentAt, 0, "the old endpoint stamped the keep-alive clock")
        XCTAssertTrue(pump.needsResend, "a new connection is not armed to resend the current state")
        guard let fresh = tick(&pump, target: 1, frame: 7, master: 0.3, look: 0.3, now: 501) else {
            return XCTFail("the new connection submitted nothing")
        }
        XCTAssertEqual(fresh.epoch, pump.epoch, "the new attempt carries the wrong epoch")
        pump.complete(fresh, failed: false)
        XCTAssertFalse(pump.needsResend, "the resend arming survived its own commit")
        XCTAssertEqual(pump.acceptedFrameTimestamp, 7, "the new endpoint's packet did not commit")
    }

    // MARK: - Claim 9 — case H, stop then restart

    /// END-TO-END BEHAVIOUR. ⛔ THE PREVIOUS VERSION OF THIS CLAIM WAS BEHAVIOURALLY WRONG and
    /// the reviewer was right to call it: it stopped a FRESH sender and then invented a
    /// generation-1 completion, which had never been submitted and was therefore not "old" in
    /// any sense the code could tell. The genuine shape is below — submit a real pre-stop
    /// attempt, leave it outstanding, stop, restart, and prove THAT attempt is retired while
    /// the restarted session is eligible immediately.
    func testARestartRetiresTheOutstandingAttemptAndEmitsAtOnce() {
        var pump = LightSendPump()
        pump.openEpoch()
        // A genuinely PRE-STOP, genuinely COMMITTED state — without this the keep-alive check
        // below would be vacuously false and the claim would prove nothing.
        guard let committed = tick(&pump, target: 0.4, frame: 11, master: 0.6, look: 0.6,
                                   now: 1_000) else { return XCTFail("no pre-stop attempt") }
        pump.complete(committed, failed: false)
        XCTAssertEqual(pump.acceptedSentAt, 1_000, "the pre-stop state never committed")
        // ...and a second attempt that is still OUTSTANDING when the sender stops.
        guard let outstanding = tick(&pump, target: 0.4, frame: 12, master: 0.6, look: 0.6,
                                     now: 1_000.05) else { return XCTFail("no outstanding attempt") }
        XCTAssertTrue(pump.isBusy, "the pre-stop attempt is not outstanding — the case is vacuous")

        pump.retire()                             // stop(): goodbye, cancel, epoch closed
        XCTAssertFalse(pump.isBusy, "stop left the in-flight slot occupied")
        XCTAssertEqual(pump.acceptedDimmer, -1,
                       "stop kept an output anchor. After Stream_Terminated nothing on the far "
                       + "side is holding a level to ramp from.")
        pump.openEpoch()                          // start() -> connect()
        pump.complete(outstanding, failed: false) // the old socket's completion lands late
        XCTAssertEqual(pump.acceptedFrameTimestamp, 11, """
        a completion from the STOPPED session committed into the restarted one. The anchor \
        must still read 11 — the last state that genuinely committed before the stop — not 12.
        """)
        XCTAssertEqual(pump.acceptedSentAt, 1_000,
                       "the stopped session's completion re-stamped the keep-alive clock")

        // Nothing has changed and the keep-alive is nowhere near due: the restart must still
        // emit. This is the defect where a quick stop/start went silent for 0.8 s after telling
        // an sACN receiver, in so many words, that the stream had ended.
        XCTAssertTrue(pump.needsResend, "a restart is not armed to emit the current state")
        XCTAssertFalse(pump.keepAliveDue(now: 1_000.1, after: SACNSender.keepAliveSeconds), """
        the case is vacuous — the keep-alive would have fired anyway, so a silent restart \
        would not have been observable here.
        """)
        guard let afterRestart = tick(&pump, target: 0.4, frame: 11, master: 0.6, look: 0.6,
                                      now: 1_000.1) else {
            return XCTFail("THE RESTART WAS SILENT: nothing submitted although the state stands")
        }
        pump.complete(afterRestart, failed: false)
        XCTAssertEqual(pump.acceptedSentAt, 1_000.1, "the restart's own packet did not commit")
    }

    // MARK: - Claim 10 — the healthy-network counterweight

    /// END-TO-END BEHAVIOUR, and a COUNTERWEIGHT (#343): on a network that completes each send
    /// before the next tick — which is every local UDP send at 33 ms — the accepted-anchor
    /// model must produce the SAME fade as the old compute-anchor model, value for value.
    /// A safety repair that changed the shipped look would be a regression wearing a fix.
    func testAHealthyNetworkFadesExactlyAsBefore() {
        // Seed dark, then ramp to full — the shape every blackout release and every fade-up
        // takes. A schedule that starts AT the target would compare two flat lines.
        let targets: [Float] = [0] + Array(repeating: 1, count: 20)
        var pump = LightSendPump()
        pump.openEpoch()
        var new: [Float] = []
        for (i, t) in targets.enumerated() {
            guard let a = tick(&pump, target: t, frame: TimeInterval(i)) else {
                return XCTFail("a healthy tick produced nothing at step \(i)")
            }
            pump.complete(a, failed: false)     // immediate completion, as on a LAN
            new.append(a.dimmer)
        }
        // The retired model: chain the limiter through its own previous OUTPUT.
        var previous: Float = -1
        var old: [Float] = []
        for t in targets {
            previous = FlashGuard.slewedDimmer(from: previous, to: t, blackout: false,
                                               maxDelta: FlashGuard.senderTickDelta)
            old.append(previous)
        }
        XCTAssertEqual(new, old, """
        the accepted-anchor fade differs from the shipped compute-anchor fade on a healthy \
        network. The repair is supposed to be invisible when every completion lands in time.
        """)
        // #367 — prove the comparison is not two flat lines agreeing with each other.
        XCTAssertEqual(Double(new[1]), FlashGuard.senderTickDelta, accuracy: 1e-6,
                       "the series does not ramp, so the equality above proves nothing")
        XCTAssertGreaterThan(new[10], new[1], "the series does not ramp")
        XCTAssertEqual(LightingStore.creativeTarget(0.37, lookIntensity:
                                                    LightingStore.defaultLookIntensity), 0.37,
                       "the default creative level stopped being the identity")
    }

    // MARK: - Claim 11 — the senders slew from the ACCEPTED anchor

    /// SOURCE-TEXT SCAN. This is the line that ties claims 4 and 5 to the shipping code.
    func testBothSendersSlewFromWhatTheNetworkAccepted() throws {
        for path in [Self.artNet, Self.sacn] {
            let src = SourceText.codeOnly(try text(path))
            XCTAssertTrue(src.contains("FlashGuard.slewedDimmer(from: pump.acceptedDimmer"), """
            \(path) no longer measures its slew step from the last ACCEPTED dimmer. If it \
            measures from a value it merely computed, an outage finishes the fade inside the \
            app and the first packet after recovery carries the end of the ramp (#1446).
            """)
            XCTAssertTrue(src.contains("var colour = pump.acceptedColour"), """
            \(path) no longer copies the accepted colour before slewing it. \
            `applySlewedColour` updates its `last` IN PLACE, so handing it the stored anchor \
            walks the hue to its destination during an outage (#1446).
            """)
            for dead in ["private var lastDimmer", "private var lastColour"] {
                XCTAssertFalse(src.contains(dead), """
                \(path) re-declared `\(dead)`. There is ONE output anchor per safety quantity \
                and it means ACCEPTED; a second one that means COMPUTED is the defect, and a \
                variable that means both is worse (#1446 §8).
                """)
            }
        }
    }

    // MARK: - Claim 12 — the bound, the abandon and the epoch are wired

    /// SOURCE-TEXT SCAN. Four expressions, each of which the behaviour above depends on.
    func testBothSendersWireTheBoundTheAbandonAndTheEpoch() throws {
        for path in [Self.artNet, Self.sacn] {
            let src = SourceText.codeOnly(try text(path))
            XCTAssertTrue(src.contains("guard !pump.isBusy else { return }"), """
            \(path) submits without checking the one in-flight slot. Outstanding sends are \
            then bounded by nothing in this repository (#1446).
            """)
            XCTAssertTrue(src.contains("if !send(packet, attempt: attempt) { pump.abandon(attempt) }"), """
            \(path) does not free the in-flight slot when there is no socket. The bound would \
            latch shut the first time the cable is out and the sender would never send again.
            """)
            XCTAssertTrue(src.contains("pump.openEpoch()"), """
            \(path) does not open a new delivery epoch when it connects. A completion from the \
            replaced connection can then commit, and the new one waits for the keep-alive.
            """)
            XCTAssertTrue(src.contains("pump.retire()"), """
            \(path) does not retire its epoch on stop. A completion in flight when the socket \
            died would commit into whatever session comes next.
            """)
            XCTAssertTrue(src.contains("pump.complete(attempt, failed: failed)"), """
            \(path) no longer routes its send outcome through the shared rule. Two light \
            outputs with two readings of "sent" is the thing this type exists to prevent.
            """)
        }
    }

    // MARK: - Claim 13 — one writer per accepted anchor

    /// SOURCE-TEXT SCAN. Every anchor is written in exactly ONE place, and that place is
    /// `LightSendPump.complete` — reached only through `LightSendAccounting.commits`.
    func testEachAcceptedAnchorHasExactlyOneWriter() throws {
        let pumpSrc = SourceText.codeOnly(try text(Self.pumpFile))
        for anchor in Self.deliveryAnchors {
            let writes = pumpSrc.components(separatedBy: "\(anchor) = ").count - 1
            XCTAssertEqual(writes, 1, """
            `\(anchor)` has \(writes) assignments in \(Self.pumpFile); exactly one is allowed \
            and it must be the line in `complete`. A second writer is a second definition of \
            "sent" (#416), and the first round of this defect was written exactly that way.
            """)
        }
        for anchor in Self.outputAnchors {
            let writes = pumpSrc.components(separatedBy: "\(anchor) = ").count - 1
            XCTAssertEqual(writes, 2, """
            `\(anchor)` has \(writes) assignments in \(Self.pumpFile); exactly two are allowed \
            — the commit in `complete` and the reset in `retire`. A third is a compute-side \
            writer, which is #1446 written again.
            """)
        }
        XCTAssertTrue(pumpSrc.contains("guard LightSendAccounting.commits(attempt"), """
        `LightSendPump.complete` no longer gates on the shared rule. Everything above this \
        line assumes an outcome cannot commit without passing it.
        """)
        for path in [Self.artNet, Self.sacn] {
            let src = SourceText.codeOnly(try text(path))
            for anchor in Self.deliveryAnchors + Self.outputAnchors {
                XCTAssertFalse(src.contains("\(anchor) = "), """
                \(path) assigns `\(anchor)` itself. The anchors belong to the pump; a sender \
                that writes one has re-opened the tick-side commit (#1445).
                """)
            }
        }
    }

    // MARK: - Claim 14 — nothing accumulates

    /// SOURCE-TEXT SCAN, COUNTERWEIGHT (#343). The bound is worth nothing if a queue grows
    /// beside it. No collection of attempts, anywhere.
    func testNoPendingSendCollectionExistsAnywhere() throws {
        for path in [Self.artNet, Self.sacn, Self.pumpFile] {
            let src = SourceText.codeOnly(try text(path))
            for shape in ["[LightSendAttempt]", "Array<LightSendAttempt>"] {
                XCTAssertFalse(src.contains(shape), """
                \(path) declares \(shape). One optional slot is the bound; a collection is a \
                queue, and a queue delivers STALE pre-blackout packets first on recovery.
                """)
            }
        }
    }

    // MARK: - Claim 15 — the wire sequence is not the accounting

    /// SOURCE-TEXT SCAN. Three counters, three questions: the protocol `sequence` orders
    /// packets for a RECEIVER, `generation` orders completions for US, `epoch` names a
    /// connection lifetime. Mixing any two makes a wire value look like proof of delivery.
    func testTheWireSequenceIsNeitherGenerationNorEpoch() throws {
        for path in [Self.artNet, Self.sacn] {
            let src = SourceText.codeOnly(try text(path))
            XCTAssertTrue(src.contains("private var sequence: UInt8"),
                          "\(path) lost its own protocol sequence counter")
            XCTAssertFalse(src.contains("sequence: sequence, generation"),
                           "\(path) passes the wire sequence into the accounting (#1446 §9)")
            XCTAssertFalse(src.contains("generation: sequence"),
                           "\(path) uses the wire sequence AS the generation. A receiver-facing "
                           + "ordering hint would then decide what this app believes it sent.")
            XCTAssertFalse(src.contains("epoch: sequence"),
                           "\(path) uses the wire sequence as the connection epoch")
        }
        // The pump cannot even see a wire value: it takes no sequence anywhere.
        let pump = SourceText.codeOnly(try text(Self.pumpFile))
        XCTAssertFalse(pump.contains("sequence"), """
        `LightSendAccounting.swift` mentions a wire sequence in code. It must stay ignorant of \
        the protocols: Art-Net wraps 1...255 with 0 disabled, E1.31 wraps 0...255, and their \
        receivers do different things with a gap. One type that knew both would be the \
        transport framework this slice refuses to build.
        """)
    }

    // MARK: - Claim 16 — both senders answer identically

    /// END-TO-END BEHAVIOUR on the two shipped classes. The same script through each real
    /// `applySendOutcome`: same refusals, same commits, same observable keep-alive clock.
    func testTheTwoLightOutputsAnswerTheSameScript() {
        let art = ArtNetSender()
        let sacn = SACNSender()
        func attempt(_ epoch: UInt64, _ generation: UInt64, frame: TimeInterval,
                     at: TimeInterval) -> LightSendAttempt {
            LightSendAttempt(epoch: epoch, generation: generation, frameTimestamp: frame,
                             grandMaster: 0.5, blackout: false, lookIntensity: 0.6,
                             sentAt: at, dimmer: 0.25, colour: [0.1, 0.2, 0.3])
        }
        let e = art.pump.epoch
        XCTAssertEqual(e, sacn.pump.epoch, "the two senders start on different epochs")
        let script: [(LightSendAttempt, Bool)] = [
            (attempt(e, 1, frame: 1, at: 1_000), false),   // commits
            (attempt(e, 3, frame: 3, at: 3_000), false),   // commits
            (attempt(e, 2, frame: 2, at: 2_000), false),   // stale generation, refused
            (attempt(e, 4, frame: 4, at: 4_000), true),    // failed, refused
            (attempt(e &+ 9, 5, frame: 5, at: 5_000), false)  // stale epoch, refused
        ]
        for (a, failed) in script {
            art.applySendOutcome(a, failed: failed)
            sacn.applySendOutcome(a, failed: failed)
        }
        XCTAssertEqual(art.pump.acceptedFrameTimestamp, sacn.pump.acceptedFrameTimestamp,
                       "the two light outputs disagree about what was sent (#416)")
        XCTAssertEqual(art.lastSentTimestamp, sacn.lastSentTimestamp,
                       "the two keep-alive clocks diverged")
        XCTAssertEqual(art.pump.acceptedFrameTimestamp, 3, """
        the script ends committed at generation 3: 1 and 3 commit, 2 is stale, 4 failed and 5 \
        belongs to a connection that no longer exists.
        """)
        XCTAssertEqual(art.lastSentTimestamp, 3_000,
                       "the observable keep-alive mirror does not follow the accepted anchor")
        XCTAssertEqual(art.pump.committedGeneration, 3, "Art-Net committed a refused attempt")
        XCTAssertEqual(sacn.pump.committedGeneration, 3, "sACN committed a refused attempt")
    }
}
#endif
