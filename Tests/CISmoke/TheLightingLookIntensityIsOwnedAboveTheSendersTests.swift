// TheLightingLookIntensityIsOwnedAboveTheSendersTests.swift
// Echoel — P2 lighting ownership seam (founder decision 2026-09-22, "Lighting Creative State").
//
// ⭐ WHY THIS FILE EXISTS. Until this slice lighting had exactly TWO stored values, and both
// belonged to the operator: `grandMaster` (the desk's first fader) and `blackout` (the safety
// cut). Everything else was recomputed per tick from a bio or musical frame — a pure
// projection with nothing a composition could own. `LightingStore.lookIntensity` is the third
// thing: the CREATIVE level of the look Echoelmusic generates, above every operator and safety
// stage. The founder's decision names the order, and this guard is that order written down
// where a compiler can check it:
//
//     generated target → × lookIntensity → grandMaster → blackout → FlashGuard → wire
//
// ⚠️ THE FIVE WAYS THIS SLICE COULD GO WRONG, one claim each, because none of them announces
// itself in a diff:
//   1. the default stops being the identity — every existing rig quietly changes brightness
//      on upgrade (claims 1–2);
//   2. the creative stage lands AFTER the master or after blackout — bio/automation would then
//      be able to scale a value the operator already reduced, or survive a blackout
//      (claims 5–7);
//   3. the sender caches the SCALED target in `lastTarget` — the hold arm re-enters that line
//      every tick on a stale source, so the look would multiply in again on each pass and fade
//      a live rig to nothing (claim 9). This one is silent, gradual and only happens on stage;
//   4. a creative move with a stale source never reaches the wire, because the send guard only
//      watches the OPERATOR anchors (claim 10);
//   5. the store learns about packets, and the "protocol-independent owner" claim quietly
//      becomes false (claim 11).
//
// ⚠️ IT FORBIDS NO FUTURE WORK (#364). Nothing here says the store may not gain a second
// creative value, a descriptor, a route or a door — those are the next slices. What it pins is
// the ORDER, the identity default, and the two-writer rule. Claim 12 is the one deliberate
// "not yet", and it is scoped to THIS file only, so registering the parameter later touches
// the guard that is about it rather than this one.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — every assertion transcribed in Python
// and driven against BOTH trees. On the parent (`178d999c9`) `LightingStore` does not exist,
// so claims 1–8 do not compile there and claims 9–12 find no creative stage: that is ONE
// finding (#486), the seam was missing. Claims 1–8 are END-TO-END BEHAVIOUR (§1) — the store
// and its kernels are `public`, so the bundle really constructs, sets and evaluates them.
// Claims 9–12 are SOURCE-TEXT SCANS, because the senders' tick is `private` and lives behind
// `#if canImport(Network)`, which this bundle cannot enter on every platform.
//
// ⚠️ DEVICE PROBE, OPEN AND NAMED: that a rig looks unchanged at 1.0 is an eye question on real
// fixtures, not a test. [NEEDS-FOUNDER-VERIFY] Art-Net or sACN rig connected, run a take before
// and after this build with the look at its default — the picture must be indistinguishable.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheLightingLookIntensityIsOwnedAboveTheSendersTests: XCTestCase {

    private static let artNet = "Sources/Echoelmusic/Sync/ArtNetSender.swift"
    private static let sacn = "Sources/Echoelmusic/Sync/SACNSender.swift"
    private static let store = "Sources/Echoelmusic/Core/LightingStore.swift"
    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"

    /// A spread of generated targets including both ends and the bio mapping's own floor
    /// (`0.3 + 0.7·coherence`, so 0.3 at coherence 0 and 1.0 at coherence 1).
    private static let generated: [Float] = [0, 0.001, 0.3, 0.5, 0.65, 0.999, 1]

    // MARK: - Claims 1–2 — the default is the identity

    /// END-TO-END. A fresh store is at the identity, and the identity is 1.
    func testAFreshStoreIsAtTheIdentity() {
        XCTAssertEqual(LightingStore().lookIntensity, 1,
                       "a new `LightingStore` no longer starts at the identity. The founder's "
                       + "decision is explicit that 1.0 preserves current output behaviour; a "
                       + "different default changes the look of every existing rig on upgrade, "
                       + "with nothing on screen to explain it.")
        XCTAssertEqual(LightingStore.defaultLookIntensity, 1,
                       "`defaultLookIntensity` is no longer 1. It is the single name three "
                       + "places share — the property, the NaN fallback, and the future "
                       + "descriptor default (#416).")
    }

    /// END-TO-END — THE load-bearing claim of this slice: at the default, the creative stage
    /// is arithmetically invisible. If this fails, the build changed the picture.
    func testAtTheDefaultTheCreativeStageIsTheIdentity() {
        for g in Self.generated {
            XCTAssertEqual(
                LightingStore.creativeTarget(g, lookIntensity: LightingStore.defaultLookIntensity),
                g, accuracy: 1e-7,
                "`creativeTarget(\(g), lookIntensity: 1)` no longer returns \(g). The whole "
                + "safety of this slice rests on the creative stage being an exact no-op at its "
                + "default — that is what lets it be inserted into a shipping light chain "
                + "without a device session first.")
        }
    }

    // MARK: - Claims 3–4 — the value is sanitised by its OWNER

    /// END-TO-END. Out-of-range input clamps on the way IN, not somewhere downstream.
    /// This matters beyond tidiness: when this becomes `lighting.look.intensity`,
    /// `ParameterApplyRouter.applyReal` bypasses the descriptor's range clamp, so the owner is
    /// the only place the range can be enforced — and the value reaches a physical fixture.
    func testTheOwnerClampsWhatItIsGiven() {
        let s = LightingStore()
        s.setLookIntensity(5)
        XCTAssertEqual(s.lookIntensity, 1, "an over-range write was not clamped to 1.")
        s.setLookIntensity(-2)
        XCTAssertEqual(s.lookIntensity, 0, "an under-range write was not clamped to 0.")
        s.setLookIntensity(0.4)
        XCTAssertEqual(s.lookIntensity, 0.4, accuracy: 1e-7,
                       "an in-range write was altered — the clamp is doing more than clamping.")
    }

    /// END-TO-END. A non-finite creative level falls back to the IDENTITY, not to 0 — a
    /// deliberate reversal of `FloatingPointClamp.clamped(to:)`, which maps NaN to the lower
    /// bound. A bio value must fail quiet; a creative multiplier with no valid instruction must
    /// leave the generated look alone rather than black out a rig mid-show on one bad frame.
    /// A non-finite GENERATED value still fails to 0 — that one IS bio-derived.
    func testANonFiniteCreativeLevelFallsBackToTheIdentity() {
        let s = LightingStore()
        s.setLookIntensity(0.25)
        s.setLookIntensity(.nan)
        XCTAssertEqual(s.lookIntensity, 1,
                       "a NaN write did not fall back to the identity. Failing DARK here means "
                       + "one bad frame blacks out a live rig; failing to the identity means it "
                       + "keeps showing the generated look, which is the honest reading of "
                       + "\"no creative instruction\".")
        XCTAssertEqual(LightingStore.creativeTarget(0.6, lookIntensity: .infinity), 0.6,
                       accuracy: 1e-7, "an infinite creative level did not fall back to the identity.")
        XCTAssertEqual(LightingStore.creativeTarget(.nan, lookIntensity: 1), 0,
                       "a NaN GENERATED target no longer fails to 0. That value comes from the "
                       + "bio/music mapping and must fail quiet, the opposite direction from the "
                       + "creative level above.")
    }

    // MARK: - Claims 5–7 — the ORDER, which is the founder's decision itself

    /// END-TO-END. The creative stage can only ATTENUATE. This is not a style limit: a stage
    /// that can never raise luminance cannot raise the luminance velocity `FlashGuard` bounds
    /// downstream, so the flash guarantee survives the insertion without being re-derived.
    func testTheCreativeStageCanOnlyAttenuate() {
        for g in Self.generated {
            for look in [Float](stride(from: 0, through: 1, by: 0.125)) {
                let out = LightingStore.creativeTarget(g, lookIntensity: look)
                XCTAssertLessThanOrEqual(
                    out, g + 1e-7,
                    "`creativeTarget(\(g), lookIntensity: \(look))` = \(out) EXCEEDS the "
                    + "generated target. A creative stage that can brighten would put a new, "
                    + "unbounded luminance step in front of FlashGuard.")
                XCTAssertGreaterThanOrEqual(out, 0, "the creative stage produced a negative level.")
            }
        }
    }

    /// END-TO-END. The operator's Grand Master applies to the CREATIVE result, and a reduced
    /// master can never be undone by the creative level. This is the professional rule the
    /// founder's decision states: bio and automation target the creative parameter, never the
    /// operator master.
    func testTheOperatorMasterStillBoundsTheCreativeResult() {
        let generated: Float = 1
        let master: Float = 0.25
        for look in [Float](stride(from: 0, through: 1, by: 0.25)) {
            let creative = LightingStore.creativeTarget(generated, lookIntensity: look)
            let out = ArtNetSender.masteredDimmer(creative, grandMaster: master, blackout: false)
            XCTAssertLessThanOrEqual(
                out, master + 1e-7,
                "with the Grand Master at \(master), a creative level of \(look) produced "
                + "\(out). No creative value may raise output above a master the operator has "
                + "pulled down — that inverts the control hierarchy of every lighting rig.")
        }
    }

    /// END-TO-END. Blackout wins over BOTH. It already short-circuited the master; it must
    /// short-circuit the creative stage too, and it does so because the creative stage sits
    /// upstream of the master rather than beside it.
    func testBlackoutOutranksBothTheCreativeLevelAndTheMaster() {
        for look in [Float](stride(from: 0, through: 1, by: 0.25)) {
            let creative = LightingStore.creativeTarget(1, lookIntensity: look)
            XCTAssertEqual(
                ArtNetSender.masteredDimmer(creative, grandMaster: 1, blackout: true), 0,
                "blackout no longer forces 0 at creative level \(look). Blackout is the "
                + "absolute show/safety control and must win against every value above it.")
            XCTAssertEqual(
                FlashGuard.slewedDimmer(from: 0.9, to: creative, blackout: true, maxDelta: 0.08), 0,
                "the downstream FlashGuard blackout short-circuit no longer holds — the second, "
                + "independent cut that makes blackout survive a reordering upstream.")
        }
    }

    /// END-TO-END — COUNTERWEIGHT. The existing bio mapping is untouched: the dimmer is still
    /// `0.3 + 0.7·coherence`, and the creative stage did not fold itself into it.
    func testTheGeneratedBioMappingIsUnchanged() {
        XCTAssertEqual(ArtNetSender.dimmerUnit(for: Self.frame(coherence: 0)), 0.3, accuracy: 1e-6,
                       "the generated dimmer floor moved. The creative level is a SEPARATE "
                       + "value; it must not have been folded into the mapping.")
        XCTAssertEqual(ArtNetSender.dimmerUnit(for: Self.frame(coherence: 1)), 1.0, accuracy: 1e-6,
                       "the generated dimmer ceiling moved.")
    }

    // MARK: - Claims 9–10 — the two silent sender failures

    /// SOURCE-TEXT SCAN. Both senders apply the creative stage BEFORE the master, and cache the
    /// GENERATED target — never the scaled one. The cache is the subtle half: the hold arm
    /// re-enters that line every tick on a stale source, so a scaled cache would multiply the
    /// look in again on each pass and fade a lit rig to nothing over seconds.
    func testBothSendersApplyTheCreativeStageBeforeTheMasterAndCacheTheGeneratedTarget() throws {
        for path in [Self.artNet, Self.sacn] {
            let src = SourceText.codeOnly(try text(path))
            guard let creative = src.range(of: "LightingStore.creativeTarget(") else {
                return XCTFail("\(path) never applies `LightingStore.creativeTarget` — the "
                               + "creative stage is missing from this adapter, so the two light "
                               + "outputs would disagree about the composition's own level.")
            }
            guard let master = src.range(of: "masteredDimmer(creative") else {
                return XCTFail("\(path) does not hand the CREATIVE result to `masteredDimmer`. "
                               + "Either the stage is bypassed, or it was placed after the "
                               + "operator master — which would let a creative value scale a "
                               + "level the operator already reduced.")
            }
            XCTAssertTrue(creative.lowerBound < master.lowerBound,
                          "\(path) applies the creative stage AFTER the master. The founder's "
                          + "order is creative → master → blackout → FlashGuard → wire.")
            XCTAssertTrue(src.contains("lastTarget = target") || src.contains("lastTarget = dimmer"),
                          "\(path) no longer caches the GENERATED target. If `lastTarget` holds "
                          + "the creative result instead, the hold arm re-scales it on every "
                          + "tick and a lit rig fades to nothing on a stale source — silently, "
                          + "gradually, and only on stage.")
            XCTAssertFalse(src.contains("lastTarget = creative"),
                           "\(path) caches the CREATIVE target. That is the compounding defect "
                           + "described above, written out explicitly.")
        }
    }

    /// SOURCE-TEXT SCAN. A creative move reaches the wire even when the source is stale. The
    /// send guard already watched the two OPERATOR anchors for exactly this reason; the
    /// creative level needs its own, or moving it would appear to do nothing until the next
    /// bio frame — on a held rig, possibly never.
    func testACreativeMoveIsNotBlockedByAStaleSource() throws {
        for path in [Self.artNet, Self.sacn] {
            let src = SourceText.codeOnly(try text(path))
            XCTAssertTrue(src.contains("lookMoved"),
                          "\(path)'s send guard has no creative anchor. `masterMoved` covers "
                          + "`grandMaster` and `blackout`; nothing covers the creative level.")
            XCTAssertTrue(src.contains("|| lookMoved"),
                          "\(path) computes a creative anchor but does not OR it into the send "
                          + "guard — the #164/#227 lying control, in the send decision.")
            // ⚠️ RE-ANCHORED BY #1445, which MOVED this assignment on purpose (§4: a commit
            // that relocates a surface moves its guards in the same commit). The old needle
            // was `lastSentLookIntensity = look` in the tick — exactly the line that made a
            // no-connection tick consume the creative move. The INVARIANT is unchanged and is
            // now two halves: the attempt must CARRY the level, and the commit must record it.
            XCTAssertTrue(src.contains("lookIntensity: look,"),
                          "\(path)'s send attempt no longer carries the creative level, so "
                          + "nothing can record what was sent and `lookMoved` stays true "
                          + "forever — the sender would stream on every tick.")
            XCTAssertTrue(src.contains("lastSentLookIntensity = attempt.lookIntensity"),
                          "\(path) never records the creative level it sent. If this moved "
                          + "again, keep a needle on the COMMIT, not on the tick: committing "
                          + "in the tick is the #1445 defect.")
        }
    }

    // MARK: - Claims 11–12 — the boundary this slice must not cross

    /// SOURCE-TEXT SCAN. The owner is protocol-independent: it knows nothing about Art-Net,
    /// sACN, DMX or the network. The moment it does, "Echoelmusic owns creative lighting intent
    /// and the protocols are adapters" stops being true, and the next adapter inherits a
    /// dependency on the previous one.
    func testTheOwnerKnowsNothingAboutAnyProtocol() throws {
        let src = SourceText.codeOnly(try text(Self.store))
        for forbidden in ["import Network", "NWConnection", "ArtNet", "SACN", "e131", "artDMX",
                         "universe", "DMXResolution"] {
            XCTAssertFalse(
                src.contains(forbidden),
                "`LightingStore` now references `\(forbidden)`. It must stay a "
                + "protocol-independent owner that both adapters READ — Art-Net and sACN are "
                + "adapters, and fixture personalities, patch, cues, HTP/LTP and RDM belong to "
                + "the desk, not here.")
        }
        XCTAssertTrue(src.contains("import Foundation"),
                      "ANCHOR MISSING: `LightingStore` no longer imports Foundation (#454).")
    }

    /// SOURCE-TEXT SCAN — the deliberate NOT-YET. This slice is ownership only: no descriptor,
    /// no registry, no modulation destination, no persistence, no UI.
    /// ⚠️ Scoped to THIS FILE on purpose (#364). Registering `lighting.look.intensity` is the
    /// next approved step; when it happens it adds a descriptor ELSEWHERE and retires this
    /// assertion here, rather than going red across the repo.
    func testTheOwnerIsNotYetAParameterOrPersisted() throws {
        let src = SourceText.codeOnly(try text(Self.store))
        for premature in ["ParameterDescriptor", "EchoelParameterRegistry", "ModDestinationKey",
                          "UserDefaults", "Codable"] {
            XCTAssertFalse(
                src.contains(premature),
                "`LightingStore` references `\(premature)`. This slice is the ownership seam "
                + "ONLY — the founder's sequence is seam first, then an independent review, "
                + "then P2 Proof #1. If that step has now been taken, move this assertion into "
                + "the guard that covers the registration instead of deleting it.")
        }
        let app = SourceText.codeOnly(try text(Self.app))
        XCTAssertTrue(app.contains("artNet.attachLighting(lighting)")
                      && app.contains("sacn.attachLighting(lighting)"),
                      "ANCHOR MISSING: the app no longer attaches the one store to BOTH light "
                      + "adapters. One creative value, two adapters — that IS the seam (#454).")
        XCTAssertFalse(app.contains(".environment(lighting)"),
                       "the store is injected into the SwiftUI environment. Nothing renders it "
                       + "yet, and an `.environment` line with no reader is a door to a surface "
                       + "that does not exist. It joins the environment with its first view.")
    }

    /// A measured camera frame at one coherence — the only channel the generated dimmer
    /// reads (`0.3 + 0.7·coherence`). The other channels are held constant so a change in
    /// this helper cannot move the claim above for an unrelated reason.
    private static func frame(coherence: Float) -> BioSampleFrame {
        BioSampleFrame(timestamp: 0, heartRateBPM: 60, hrvNormalized: 0.4,
                       breathRate: 12, breathPhase: 0.25,
                       coherence: coherence, motionEnergy: 0, source: .cameraPPG)
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
