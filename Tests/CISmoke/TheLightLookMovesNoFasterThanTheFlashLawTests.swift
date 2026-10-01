// TheLightLookMovesNoFasterThanTheFlashLawTests.swift
// Echoel — Workstation redesign C3a (scratchpads/PLAN_WORKSTATION_REDESIGN_2026-10-01.md): the
// SAFETY half of an automatable light look, landed before anything may write the look.
//
// ⭐ WHAT IS BEING PROVED. `LightingStore.lookIntensity` (P2 Proof #1) is the creative level of the
// light look, `lighting.look.intensity` on the canonical parameter path, and both eligibilities
// are still denied. C3 wants a person to draw it as a curve on the timeline. A curve steps the
// store once per transport step (a sixteenth), and the only rate limit between the store and a
// fixture was `FlashGuard.slewedDimmer` at ~2.4 per second — loose enough that a curve
// alternating 0 and 1 on successive sixteenths swings a rig by ~0.3 four times a second at
// 120 BPM (claim 4 shows it on the PARENT arithmetic). So the senders now SLEW the look per tick
// from the look their network last ACCEPTED, at `LightingStore.maxLookChangePerSecond`
// (0.10 × 3 = 0.30/s), and with nothing accepted yet the look lands with the dimmer's own
// no-history edge. This file proves, on the real public types, that after this slice:
//   · the look can only DIM — the output never exceeds the generated target (claim 3);
//   · with the generated target HELD, no curve moves the output by 0.10 inside one 3 Hz
//     half-cycle (claim 3) — the LOOK is not a flash source at any curve rate;
//   · a slow curve still dims the rig all the way — the slew is not a placebo (claim 5);
//   · an outage freezes the look's ramp like the dimmer's (#1446) (claim 6);
//   · a rig that connects into a dark curve starts dark, not bright-then-fading (claim 7);
//   · both senders take this path, with this anchor, and no raw read survives (claim 8).
//
// ⚠️ WHAT IT DOES NOT PROVE: anything about the OUTPUT while the generated target moves. When
// music sounds that target is `0.3 + 0.7·masterLevel` (`MusicMediaMap.dimmerUnit(forMusic:)`),
// an unsmoothed velocity sum that can step per sequencer tick; that path is bounded by the
// dimmer slew alone and is a separate, open finding — not covered, not claimed here.
//
// ⚠️ IT FORBIDS NO FUTURE WORK (#364). It does not pin the rate to 0.30 — only that it is
// positive and at most one threshold per flash cycle, so a slower, gentler light is a designer's
// edit. It says nothing about eligibility, the editor, persistence or modulation: C3b flips
// `automationEligible` together with its door and edits `TheLightingLookIsACanonicalParameterTests`,
// not this file.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — every assertion was transcribed into
// Python and driven against BOTH trees. On the parent `dc1652988` neither
// `LightingStore.slewedLookIntensity` nor `maxLookChangePerSecond` exists, so this file does not
// compile there: NO assertion has a verdict on that tree (#486, #488). By transcription:
// claims 1, 2, 3, 5, 6 and 7 are FORWARD (they drive symbols this commit creates); claim 4 is a
// COUNTERWEIGHT whose arithmetic uses only parent symbols and would hold there — it is what makes
// claim 3 mean something; claim 8 is the one REGRESSION-shaped scan — on the parent both senders
// read the store raw, which is ONE finding at two sites (#486). Claims 1–7 are END-TO-END
// BEHAVIOUR on public types (`LightingStore`, `LightSendPump`, `ArtNetSender.masteredDimmer`,
// `FlashGuard`); claim 7's no-history rule is the helper's model of the sender, and claim 8 pins
// that the senders spell the same anchor. Claim 8 is a SOURCE-TEXT SCAN because the senders'
// tick is `private` and behind `#if canImport(Network)`. STRIPPER (#453): PROPHYLAKTISCH — every
// needle of claim 8 occurs only in code on both trees, 0 of 14 needle counts flip between raw
// and `SourceText.codeOnly` text.
//
// ⚠️ DEVICE PROBE. [NEEDS-FOUNDER-VERIFY] Art-Net- oder sACN-Rig verbunden, eine Aufnahme wie
// gewohnt spielen: das Licht muss genau so aussehen wie vor diesem Build — nichts schreibt die
// Look-Intensität, der neue Schritt läuft von 1 nach 1. Ein Abblenden über eine Kurve gibt es erst
// mit C3b und wird dort geprüft.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheLightLookMovesNoFasterThanTheFlashLawTests: XCTestCase {

    private static let artNet = "Sources/Echoelmusic/Sync/ArtNetSender.swift"
    private static let sacn = "Sources/Echoelmusic/Sync/SACNSender.swift"

    /// The flash threshold as the output's type.
    private static let threshold = Float(FlashGuard.luminanceDeltaThreshold)

    /// Spans of whole sender ticks that fit STRICTLY inside one half-cycle at the flash ceiling
    /// (1/6 s): 5 at 33 ms. Derived, so a faster loop or a different ceiling moves it with them.
    private static var halfCycleSpan: Int {
        Int(((1 / (2 * FlashGuard.maxFlashHz)) / FlashGuard.senderTickSeconds).rounded(.up)) - 1
    }

    /// One look step at the senders' nominal tick.
    private static var tickStep: Float {
        Float(FlashGuard.maxDelta(perSecond: LightingStore.maxLookChangePerSecond,
                                  dt: FlashGuard.senderTickSeconds))
    }

    // MARK: - 1. The ceiling is the flash law (BEHAVIOUR, FORWARD)

    func testTheLookCeilingIsTheFlashLaw() {
        let rate = LightingStore.maxLookChangePerSecond
        XCTAssertGreaterThan(rate, 0,
                             "ANCHOR MISSING: the look may not move at all — every claim below would "
                             + "be green for a frozen look, and a curve would be a placebo (#454).")
        XCTAssertLessThanOrEqual(
            rate, FlashGuard.luminanceDeltaThreshold * FlashGuard.maxFlashHz + 1e-12,
            "the look may move \(rate) per second — faster than one flash threshold per cycle at "
            + "\(FlashGuard.maxFlashHz) Hz. Slower is a design choice; faster spends the margin "
            + "that keeps a curve from being a flash source.")

        let dt = FlashGuard.senderTickSeconds
        let one = LightingStore.slewedLookIntensity(from: 1, toward: 0, dt: dt)
        XCTAssertEqual(Double(1 - one), rate * dt, accuracy: 1e-5,
                       "one sender tick did not move the look by exactly rate × dt.")

        XCTAssertGreaterThan(Self.halfCycleSpan, 0,
                             "ANCHOR MISSING: no whole tick fits in a half-cycle, so the loop below "
                             + "proves nothing (#367).")
        var look: Float = 1
        for _ in 0..<Self.halfCycleSpan {
            look = LightingStore.slewedLookIntensity(from: look, toward: 0, dt: dt)
        }
        XCTAssertLessThan(1 - look, Self.threshold,
                          "inside one half-cycle at the flash ceiling the look moved \(1 - look) — "
                          + "at or past the flash threshold.")
    }

    // MARK: - 2. Exact at the identity, sanitised at both ends (BEHAVIOUR, FORWARD)

    func testTheSlewIsExactAtTheIdentityAndSanitisesBothEnds() {
        let rate = LightingStore.maxLookChangePerSecond
        for dt: Double in [FlashGuard.senderTickSeconds, 0, -1, .nan, .infinity, 3600] {
            XCTAssertEqual(LightingStore.slewedLookIntensity(from: 1, toward: 1, dt: dt), 1,
                           "the identity does not survive a tick EXACTLY at dt \(dt). Nothing writes "
                           + "the look in this build; anything but an exact 1 changes every packet.")
        }
        let stalled = LightingStore.slewedLookIntensity(from: 1, toward: 0, dt: 3600)
        XCTAssertEqual(Double(1 - stalled), FlashGuard.maxDelta(perSecond: rate, dt: 3600),
                       accuracy: 1e-6,
                       "a long stall is not bounded by FlashGuard.maxDelta's 1 s cap — one late tick "
                       + "would be one flash edge.")
        let nanDt = LightingStore.slewedLookIntensity(from: 1, toward: 0, dt: .nan)
        XCTAssertTrue(nanDt.isFinite, "a NaN dt produced a non-finite look.")
        XCTAssertEqual(Double(1 - nanDt), FlashGuard.maxDelta(perSecond: rate, dt: .nan),
                       accuracy: 1e-6, "a NaN dt does not take FlashGuard.maxDelta's fallback.")
        XCTAssertGreaterThan(LightingStore.slewedLookIntensity(from: 0.5, toward: .nan,
                                                              dt: FlashGuard.senderTickSeconds), 0.5,
                             "a NaN target did not move toward the identity — the owner's policy "
                             + "(`sanitizedLookIntensity`) is that no instruction means no dimming.")
        XCTAssertEqual(LightingStore.slewedLookIntensity(from: nil, toward: 0.25,
                                                         dt: FlashGuard.senderTickSeconds),
                       0.25, accuracy: 1e-6,
                       "no history did not land on the goal — the dimmer snaps on no history, and "
                       + "a look that ramps instead would flare a dark piece bright on connect.")
        XCTAssertEqual(LightingStore.slewedLookIntensity(from: Float.nan, toward: 0.25,
                                                         dt: FlashGuard.senderTickSeconds),
                       0.25, accuracy: 1e-6, "a NaN current is not read as no history.")
        for target: Float in [-5, 7, .infinity, -.infinity] {
            let v = LightingStore.slewedLookIntensity(from: 0.5, toward: target,
                                                      dt: FlashGuard.senderTickSeconds)
            XCTAssertTrue(v >= 0 && v <= 1, "target \(target) slewed to \(v), outside 0…1.")
        }
    }

    // MARK: - 3. No curve makes the LOOK a flash source, and it only dims (BEHAVIOUR, FORWARD)

    /// END-TO-END through the shipped tick arithmetic and a real `LightSendPump`, with the
    /// GENERATED target held (see the header for what that excludes): a square on sixteenths at
    /// 120 and 160 BPM, a square on every tick, and a 0.2 s square — at three generated levels,
    /// including the bio floor 0.3.
    func testNoCurveSwingsTheRigFasterThanTheFlashLaw() {
        let curves: [(String, (Double) -> Float)] = [
            ("sixteenths at 120 BPM", Self.alternating(every: 60.0 / 120 / 4)),
            ("sixteenths at 160 BPM", Self.alternating(every: 60.0 / 160 / 4)),
            ("every sender tick", Self.alternating(every: FlashGuard.senderTickSeconds)),
            ("0.2 s square", Self.alternating(every: 0.2)),
        ]
        var lookEverMoved = false
        for (name, curve) in curves {
            for generated: Float in [1, 0.5, 0.3] {
                let run = drive(curve: curve, seconds: 4, generated: generated, slewLook: true)
                XCTAssertFalse(run.dimmer.isEmpty, "ANCHOR MISSING: the drive produced no ticks (#367).")
                let swing = Self.largestSwing(in: run.dimmer, withinTicks: Self.halfCycleSpan)
                XCTAssertLessThan(
                    swing, Self.threshold,
                    "\(name), generated \(generated): the output moved \(swing) inside one 3 Hz "
                    + "half-cycle. A curve on the light look is a flash source again.")
                for (i, d) in run.dimmer.enumerated() {
                    XCTAssertLessThanOrEqual(d, generated + 1e-6,
                                             "\(name): tick \(i) sent \(d) above the generated "
                                             + "\(generated). The look may only DIM.")
                }
                for l in run.look { XCTAssertTrue(l >= 0 && l <= 1, "\(name): look \(l) left 0…1.") }
                if run.look.contains(where: { $0 > 0 && $0 < 1 }) { lookEverMoved = true }
            }
        }
        XCTAssertTrue(lookEverMoved,
                      "ANCHOR MISSING: no curve ever left the look between its ends, so the swing "
                      + "bound above is green for a frozen or snapping chain, not a slewed one (#367).")
    }

    // MARK: - 4. COUNTERWEIGHT — the same curve on the parent arithmetic DOES flash

    /// The look read RAW, exactly as both senders did before this slice. If this goes green-to-red
    /// (the swing falls under the threshold), claim 3 no longer proves anything: the scenario has
    /// stopped being adversarial — re-derive the curve, do not delete the claim.
    func testWithoutTheSlewTheSameCurveFlashes() {
        let run = drive(curve: Self.alternating(every: 60.0 / 120 / 4), seconds: 4,
                        generated: 1, slewLook: false)
        let swing = Self.largestSwing(in: run.dimmer, withinTicks: Self.halfCycleSpan)
        XCTAssertGreaterThanOrEqual(
            swing, Self.threshold,
            "the RAW look on a 120 BPM sixteenth square moved the output only \(swing) inside a "
            + "half-cycle. Either FlashGuard's dimmer slew tightened (then this slice's premise "
            + "changed — say so at `LightingStore`) or the scenario is no longer adversarial.")
    }

    // MARK: - 5. A slow curve still dims all the way (BEHAVIOUR, FORWARD)

    func testASlowCurveStillDimsTheRigAllTheWay() {
        // 1 → 0 over four seconds (0.25/s, under the ceiling), then held at 0.
        let ramp: (Double) -> Float = { t in Float(Swift.max(0, 1 - t / 4)) }
        let run = drive(curve: ramp, seconds: 5, generated: 1, slewLook: true)
        XCTAssertEqual(run.look.last ?? 1, 0, accuracy: 1e-6,
                       "a curve that ends at 0 left the look at \(run.look.last ?? 1). The slew must "
                       + "delay a curve, never refuse it — otherwise C3b ships a placebo.")
        XCTAssertEqual(run.dimmer.last ?? 1, 0, accuracy: 1e-6,
                       "the dimmer did not follow the look down to 0.")
    }

    // MARK: - 6. An outage freezes the look's ramp (BEHAVIOUR, FORWARD — the #1446 discipline)

    func testAFailedSendCannotAdvanceTheLook() {
        var pump = LightSendPump()
        pump.openEpoch()
        // Seed ONE accepted packet: the senders only slew from a pump that has history.
        let seed = pump.submit(frameTimestamp: 0, grandMaster: 1, blackout: false,
                               lookIntensity: 1, sentAt: 0, dimmer: 1, colour: [0, 0, 0])
        pump.complete(seed, failed: false)
        XCTAssertEqual(pump.acceptedDimmer, 1,
                       "ANCHOR MISSING: the seed packet did not commit, so the outage below would "
                       + "start from no history and prove nothing about the ramp (#367).")
        let dt = FlashGuard.senderTickSeconds
        let step = Self.tickStep
        for i in 1...20 {
            let look = LightingStore.slewedLookIntensity(from: pump.acceptedLookIntensity,
                                                         toward: 0, dt: dt)
            XCTAssertGreaterThanOrEqual(look, 1 - step - 1e-6,
                                        "attempt \(i) carried look \(look) while the network had "
                                        + "accepted only 1 — the ramp ran ahead of the wire.")
            let a = pump.submit(frameTimestamp: TimeInterval(i), grandMaster: 1, blackout: false,
                                lookIntensity: look, sentAt: TimeInterval(i), dimmer: look,
                                colour: [0, 0, 0])
            pump.complete(a, failed: true)
            XCTAssertEqual(pump.acceptedLookIntensity, 1,
                           "a FAILED send advanced the accepted look (#1446).")
        }
        for expected in [1 - step, 1 - 2 * step] {
            let look = LightingStore.slewedLookIntensity(from: pump.acceptedLookIntensity,
                                                         toward: 0, dt: dt)
            let a = pump.submit(frameTimestamp: 100, grandMaster: 1, blackout: false,
                                lookIntensity: look, sentAt: 100, dimmer: look, colour: [0, 0, 0])
            pump.complete(a, failed: false)
            XCTAssertEqual(pump.acceptedLookIntensity, expected, accuracy: 1e-6,
                           "after recovery the look did not continue one step at a time from what "
                           + "the network had accepted.")
        }
    }

    // MARK: - 7. A rig that connects into a dark curve starts dark (BEHAVIOUR, FORWARD)

    func testARigThatConnectsIntoADarkCurveStartsDark() {
        let dark = drive(curve: { _ in 0 }, seconds: 0.2, generated: 1, slewLook: true)
        guard let firstLook = dark.look.first, let firstDimmer = dark.dimmer.first else {
            return XCTFail("ANCHOR MISSING: the drive produced no ticks (#367).")
        }
        XCTAssertEqual(firstLook, 0,
                       "with nothing accepted yet the look ramped from 1 instead of landing on the "
                       + "curve — a piece that opens dark would flare bright on connect and fade.")
        XCTAssertEqual(firstDimmer, 0, "the first packet into a dark curve was not dark.")
        // COUNTERWEIGHT: once a packet is accepted the ramp applies again — a jump back to 1 is
        // slewed, so the no-history landing is a single edge, not a way around the slew.
        let jump = drive(curve: { t in t < 0.05 ? 0 : 1 }, seconds: 0.3, generated: 1, slewLook: true)
        for (i, l) in jump.look.enumerated() {
            XCTAssertLessThanOrEqual(l, Float(i) * Self.tickStep + 1e-6,
                                     "tick \(i): after history existed the look jumped to \(l) "
                                     + "instead of ramping.")
        }
        XCTAssertGreaterThan(jump.look.last ?? 0, 0,
                             "ANCHOR MISSING: the look never rose, so the ramp bound above is "
                             + "green for a frozen chain (#367).")
    }

    // MARK: - 8. Both senders take the slew, from this anchor, and no raw read survives (SCAN)

    func testBothSendersSlewTheLookFromTheAcceptedAnchor() throws {
        let anchor = "pump.acceptedDimmer < 0 ? nil : pump.acceptedLookIntensity"
        let slew = "LightingStore.slewedLookIntensity(from: lookAnchor,"
        for path in [Self.artNet, Self.sacn] {
            let code = SourceText.codeOnly(try text(path))
            XCTAssertEqual(Self.count(anchor, in: code), 1,
                           "\(path) does not anchor the look on the ACCEPTED look (nil while nothing "
                           + "is accepted). Slewing from a computed value lets an outage finish the "
                           + "ramp the network never took (#1446); ramping without history flares "
                           + "a dark piece bright on connect.")
            XCTAssertEqual(Self.count(slew, in: code), 1,
                           "\(path) does not slew the look exactly once from that anchor. Reading "
                           + "the store raw lets a curve step a fixture faster than the flash law.")
            XCTAssertEqual(Self.count("dt: FlashGuard.senderTickSeconds)", in: code), 1,
                           "\(path) slews the look at some interval other than the one its loop "
                           + "runs at (#372) — the step and the tick would drift apart.")
            XCTAssertEqual(Self.count("lighting?.lookIntensity", in: code), 1,
                           "\(path) reads the store more than once (or not at all). The one read "
                           + "belongs inside the slew; a second is a raw path around it.")
            XCTAssertFalse(code.contains("sanitizedLookIntensity(lighting"),
                           "\(path) reads the store RAW again — the parent's form.")
            guard let a = code.range(of: anchor),
                  let s = code.range(of: slew),
                  let c = code.range(of: "LightingStore.creativeTarget(") else {
                XCTFail("ANCHOR MISSING: \(path) has no anchor, slew or creative stage to order (#454).")
                continue
            }
            XCTAssertTrue(a.lowerBound < s.lowerBound && s.lowerBound < c.lowerBound,
                          "\(path) does not run anchor → slew → creative stage in that order.")
            XCTAssertTrue(code.contains("lookIntensity: look)"),
                          "ANCHOR MISSING: \(path)'s creative stage no longer consumes `look` (#454).")
        }
    }

    // MARK: - Helpers

    private struct Run {
        var dimmer: [Float] = []
        var look: [Float] = []
    }

    /// One sender tick after another, exactly the arithmetic both senders run after their send
    /// guard (anchor → look slew → creative → master → FlashGuard dimmer slew → submit), with every
    /// send succeeding and the generated target HELD. `slewLook: false` is the PARENT arithmetic —
    /// the store read raw. The store is written directly, once per tick, as any writer would;
    /// where the write comes from does not matter, because the slew sits at the reader.
    private func drive(curve: (Double) -> Float, seconds: Double, generated: Float,
                       slewLook: Bool) -> Run {
        let store = LightingStore()
        var pump = LightSendPump()
        pump.openEpoch()
        let dt = FlashGuard.senderTickSeconds
        let ticks = Int((seconds / dt).rounded(.up))
        var run = Run()
        for i in 0..<ticks {
            let now = Double(i) * dt
            store.setLookIntensity(curve(now))
            let lookAnchor: Float? = pump.acceptedDimmer < 0 ? nil : pump.acceptedLookIntensity
            let look = slewLook
                ? LightingStore.slewedLookIntensity(from: lookAnchor,
                                                    toward: store.lookIntensity, dt: dt)
                : LightingStore.sanitizedLookIntensity(store.lookIntensity)
            let creative = LightingStore.creativeTarget(generated, lookIntensity: look)
            let mastered = ArtNetSender.masteredDimmer(creative, grandMaster: 1, blackout: false)
            let limited = FlashGuard.slewedDimmer(from: pump.acceptedDimmer, to: mastered,
                                                  blackout: false,
                                                  maxDelta: FlashGuard.senderTickDelta)
            let attempt = pump.submit(frameTimestamp: now, grandMaster: 1, blackout: false,
                                      lookIntensity: look, sentAt: now, dimmer: limited,
                                      colour: [0, 0, 0])
            pump.complete(attempt, failed: false)
            run.dimmer.append(limited)
            run.look.append(look)
        }
        return run
    }

    /// A square curve: 0 for one period, 1 for the next.
    private static func alternating(every period: Double) -> (Double) -> Float {
        { t in Int((t / period).rounded(.down)) % 2 == 0 ? 0 : 1 }
    }

    /// The largest change between any two ticks at most `span` apart — no dark-state filter, so
    /// the bound is STRONGER than WCAG's (a bright-only swing counts here too).
    private static func largestSwing(in series: [Float], withinTicks span: Int) -> Float {
        var worst: Float = 0
        for i in series.indices {
            var k = 1
            while k <= span, i + k < series.count {
                worst = Swift.max(worst, abs(series[i + k] - series[i]))
                k += 1
            }
        }
        return worst
    }

    private static func count(_ needle: String, in hay: String) -> Int {
        hay.components(separatedBy: needle).count - 1
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
