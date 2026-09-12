// TheWholeEgressSurfaceIsClinicalFreeTests.swift
// Echoel — #1293. #1292 gave `BioEgressPolicy` a vocabulary for WHICH values may leave
// (.derived / .clinical / .raw) and applied it at exactly ONE of the six places a bio
// frame becomes bytes: `OSCSender.send(frame:)`. This file measures the other five and
// pins what it found.
//
// THE CENSUS (2026-09-12, read at each mapping rather than assumed):
//   · ADM-OSC   `admMessages(for:object:)` — breathPhase→/azim · hrvNormalized→/elev ·
//               coherence→/dist · motion→/gain (never, #215).  All derived.
//   · Art-Net   `dmxChannels(for:)` — heartRateBPM · coherence · hrvNormalized ·
//               breathPhase, four channels.  All derived.
//   · sACN      shares that exact function (`SACNSender.swift:231` calls
//               `ArtNetSender.dmxChannels(for:resolution:)`) — measured, not inferred from
//               the neighbouring comment (#867: a register line claimed over a NEIGHBOUR
//               measures the neighbour).
//   · Multipeer `ColabPayload.egressible(from:)` → `BioPeek(bpm, coherence,
//               hrvNormalized, breathRate, synthetic)`.  All derived.
//   · Mod tap   `ModulationEngine` → `/echoelmusic/mod/*`, already-applied values.
//
// So the surface is ALREADY clinical-free everywhere except the OSC batch, which #1292
// gated. NOTHING PROVED IT, and nothing would catch the regression — and the regression
// is the plausible next edit, not a hypothetical: a fifth DMX channel carrying "HRV
// detail in ms" is exactly what a lighting-desk request sounds like.
//
// KIND (§1): END-TO-END BEHAVIOUR for claims 1–7 — every mapping here is a pure static
// function over Foundation-only value types, driven directly with two frames that differ
// ONLY in the three clinical fields. Claim 8 is a SOURCE-TEXT SCAN (the shared mapping).
// No DEVICE PROBE is claimed; what a renderer or a desk SEES is still unverified.
//
// ⚠️ CLAIM 5 IS THE ONE THAT MAKES 1–4 MEAN ANYTHING (#367, the mirror case). "Output does
// not change when the clinical fields change" is ALSO true of a sender that ignores the
// frame entirely, or that has been accidentally disconnected. Claim 5 drives the same four
// mappings with a changed DERIVED field and requires the output to MOVE. Without it this
// file would stay green through exactly the breakage it exists to notice.
//
// ⚠️ HONEST GRADING (§3) — TRANSCRIBED (§0) against the parent (`14a4f1e`) and this tree,
// every claim driven. Claims 1–8 are all COUNTERWEIGHTS: green on BOTH trees, because this
// slice adds no production code. That is the point and it is declared rather than dressed
// up — booking a counterweight as a regression is the flattering direction §3 names. The
// file's value is entirely forward: it fails the day a clinical field is wired into a
// light, an object position or a peer row. Mutation-driven, six mutations, all red.
// Stripper: PROPHYLAKTISCH — MEASURED, not asserted. Claim 8 is the only scan and holds
// two assertions; in `SACNSender.swift` the positive needle occurs once, in code, and the
// three clinical field names occur nowhere at all, comment or code. So `codeOnly` flips
// 0 of 2 verdicts today. It stays because the day someone writes "we could send
// `hrvRMSSDms` here" in a comment is the day the negative half would go red for a reason
// that is not a defect.
//
// ⚠️ TWO COMPILE FACTS, both measured while writing this rather than assumed — either one
// would have been a `TEST BUILD FAILED`, which `Xcode Compile Check` cannot see (§5).
//   · `#if canImport(Network)`: `ArtNetSender`, `ADMOSCSender` and `OSCSender` all live
//     inside that guard, so this file must too. `ColabPayload` and `BioEgressPolicy` do not,
//     but a file is one compilation unit.
//   · `@MainActor` on the class: `ArtNetSender` is a `@MainActor` class and `dmxChannels`
//     carries no `nonisolated`, so it is main-actor isolated. (`admMessages`, `bioMessages`
//     and `egressible` are all nonisolated — `ADMOSCAbsenceTests` says so in as many words
//     and needs no annotation. Art-Net is the odd one out, and a `@MainActor` test may call
//     nonisolated code freely, so one annotation covers all four.)
//
// ⚠️ AND THE NEIGHBOUR CLAIM THAT STOOD HERE WAS WRONG (#867 — a line claimed over a
// NEIGHBOUR measures the neighbour). It said `TheBreathRateAndItsWaveformAreTwoGatesTests`
// drives `ArtNetSender.dmxChannels` unguarded; that file only NAMES it, in a comment.
// Measured: before this file, NO guard in the blocking bundle drove that function at all.
// Its only driver is `Tests/EchoelmusicTests/ArtNetSenderTests.swift` — the bundle **no gate
// compiles** (#208). So the bio→DMX mapping had no blocking coverage of any kind, which is
// a stronger reason for this file than the one I first wrote down.

#if canImport(Network)
import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheWholeEgressSurfaceIsClinicalFreeTests: XCTestCase {

    /// A frame with every derived channel measured and the clinical triplet at zero.
    private func base(_ source: BioSource = .cameraPPG) -> BioSampleFrame {
        BioSampleFrame(timestamp: 1000, heartRateBPM: 64, hrvNormalized: 0.45,
                       breathRate: 12, breathPhase: 0.3, coherence: 0.62,
                       motionEnergy: 0, source: source)
    }

    /// The SAME frame with the three clinical statistics loaded. Nothing else differs.
    private func clinicalLoaded(_ source: BioSource = .cameraPPG) -> BioSampleFrame {
        BioSampleFrame(timestamp: 1000, heartRateBPM: 64, hrvNormalized: 0.45,
                       breathRate: 12, breathPhase: 0.3, coherence: 0.62,
                       motionEnergy: 0, source: source,
                       hrvRMSSDms: 137, hrvSDNNms: 204, hrvPNN50: 0.91)
    }

    /// The same frame with one DERIVED channel moved — the control for claim 5.
    private func derivedMoved(_ source: BioSource = .cameraPPG) -> BioSampleFrame {
        BioSampleFrame(timestamp: 1000, heartRateBPM: 64, hrvNormalized: 0.45,
                       breathRate: 12, breathPhase: 0.3, coherence: 0.11,
                       motionEnergy: 0, source: source)
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    // MARK: - 1–4  no clinical value reaches any of the four mappings

    /// Claim 1 — Art-Net, both DMX resolutions. sACN rides this same function (claim 8).
    func testTheLightChannelsIgnoreTheClinicalTriplet() {
        XCTAssertEqual(ArtNetSender.dmxChannels(for: base()),
                       ArtNetSender.dmxChannels(for: clinicalLoaded()), """
            A DMX channel moved when only rMSSD/SDNN/pNN50 changed, so a millisecond HRV \
            statistic now drives a light. The four channels are heart rate, coherence, \
            normalized HRV and breath phase — all derived, all bounded. If a desk really \
            needs clinical detail, it goes behind the same opt-in the OSC wire uses \
            (`StudioDefaultKeys.oscClinicalDetail`), never onto the default output.
            """)
        XCTAssertEqual(ArtNetSender.dmxChannels16(for: base()),
                       ArtNetSender.dmxChannels16(for: clinicalLoaded()),
                       "the 16-bit path took a clinical value the 8-bit path refuses (#1293)")
    }

    /// Claim 2 — ADM-OSC object positions.
    func testTheObjectPositionIgnoresTheClinicalTriplet() {
        let a = ADMOSCSender.admMessages(for: base(), object: 1)
        let b = ADMOSCSender.admMessages(for: clinicalLoaded(), object: 1)
        XCTAssertEqual(a.map(\.0), b.map(\.0), "the address set changed on a clinical-only edit")
        XCTAssertEqual(a.map(\.1), b.map(\.1), """
            An ADM object coordinate moved when only the clinical triplet changed. \
            `/azim` is breath phase, `/elev` normalized HRV, `/dist` coherence — all \
            derived. A position derived from a millisecond statistic is still that \
            statistic, one transform away (#1293).
            """)
    }

    /// Claim 3 — the Multipeer peer row. This is the surface that reaches ANOTHER PERSON'S
    /// phone rather than the performer's own rig, so it is the one where a leak is least
    /// recoverable: the holder of the receiving device never agreed to anything.
    func testThePeerRowIgnoresTheClinicalTriplet() throws {
        let a = try XCTUnwrap(ColabPayload.egressible(from: base()))
        let b = try XCTUnwrap(ColabPayload.egressible(from: clinicalLoaded()))
        XCTAssertEqual(a, b, """
            `BioPeek` changed on a clinical-only edit, so a millisecond HRV statistic now \
            travels to someone else's phone. `BioPeek` carries bpm, coherence, normalized \
            HRV, breath rate and the synthetic flag — adding a field here is a different \
            decision from adding one to the OSC wire, and needs its own founder ask (#1293).
            """)
    }

    /// Claim 4 — the policy itself still refuses the three by name, whatever the callers do.
    func testThePolicyStillNamesTheThreeAsClinical() {
        for a in ["/echoelmusic/bio/heart/rmssd",
                  "/echoelmusic/bio/heart/sdnn",
                  "/echoelmusic/bio/heart/pnn50"] {
            XCTAssertEqual(BioEgressPolicy.fieldClass(ofOSCAddress: a), .clinical,
                           "`\(a)` stopped being clinical — #1292's split is the premise of this file")
        }
    }

    // MARK: - 5  THE CONTROL — without this, 1–4 are vacuous

    /// Claim 5 — the same four mappings MUST move when a DERIVED channel moves. A sender
    /// that ignores the frame, or one accidentally disconnected, would satisfy claims 1–4
    /// perfectly; this is what tells "correctly indifferent" from "not listening" (#367).
    func testTheSameMappingsDoMoveOnADerivedChange() throws {
        XCTAssertNotEqual(ArtNetSender.dmxChannels(for: base()),
                          ArtNetSender.dmxChannels(for: derivedMoved()), """
            Art-Net's channels did NOT move when coherence changed 0.62 → 0.11. Claims 1–4 \
            then prove nothing: an output that never moves is trivially indifferent to the \
            clinical fields. Check the mapping is still wired before trusting this file.
            """)
        XCTAssertNotEqual(ArtNetSender.dmxChannels16(for: base()),
                          ArtNetSender.dmxChannels16(for: derivedMoved()),
                          "the 16-bit path stopped responding to coherence (#1293 control)")
        let admA = ADMOSCSender.admMessages(for: base(), object: 1).map(\.1)
        let admB = ADMOSCSender.admMessages(for: derivedMoved(), object: 1).map(\.1)
        XCTAssertNotEqual(admA, admB, "ADM `/dist` stopped following coherence (#1293 control)")
        let peekA = try XCTUnwrap(ColabPayload.egressible(from: base()))
        let peekB = try XCTUnwrap(ColabPayload.egressible(from: derivedMoved()))
        XCTAssertNotEqual(peekA, peekB, "`BioPeek` stopped carrying coherence (#1293 control)")
    }

    // MARK: - 6–7  counterweights: the source gate, and the one surface that MAY carry them

    /// Claim 6 — 5.1.3 is untouched by all of this: a Health-sourced frame still reaches
    /// no peer at all. The field question never gets asked, because the source answer is no.
    func testTheSourceGateStillRefusesHealthKitEverywhere() {
        XCTAssertNil(ColabPayload.egressible(from: base(.healthKit)),
                     "a HealthKit-sourced frame reached a peer row — 5.1.3 (#186)")
        for s in [BioSource.healthKit, .watch, .oura] {
            XCTAssertFalse(BioEgressPolicy.allowsEgress(s), "\(s) is Health-store data")
        }
        for s in [BioSource.ble, .cameraPPG, .faceCam, .fallback] {
            XCTAssertTrue(BioEgressPolicy.allowsEgress(s), "\(s) is Echoel's own measurement")
        }
    }

    /// Claim 7 — the taxonomy did not make everything blind. The OSC batch is the ONE
    /// surface that may carry the three, and with the opt-in on it still does. A file that
    /// only asserted absence would stay green on a build where the opt-in stopped working.
    func testTheOptInSurfaceStillCarriesThemWhenAsked() {
        let emitted = Set(OSCSender.bioMessages(for: clinicalLoaded()).map(\.address))
        for a in ["/echoelmusic/bio/heart/rmssd",
                  "/echoelmusic/bio/heart/sdnn",
                  "/echoelmusic/bio/heart/pnn50"] {
            XCTAssertTrue(emitted.contains(a), "`\(a)` left the message list entirely (#1292)")
            XCTAssertTrue(BioEgressPolicy.allowsEgress(address: a, source: .cameraPPG,
                                                       clinicalDetailEnabled: true), """
                `\(a)` can no longer be switched ON. The opt-in is the reason #1292 was a \
                switch and not a deletion — TouchDesigner/Max analysis is a real use.
                """)
        }
    }

    // MARK: - 8  the shared mapping, measured rather than inherited from a comment

    /// Claim 8 — sACN does not own a second bio→DMX mapping; it calls Art-Net's. That is
    /// what lets claim 1 cover both senders. If sACN ever forks its own, claim 1 silently
    /// stops covering it — so the sharing is pinned rather than assumed.
    func testSACNSharesTheArtNetMapping() throws {
        let sacn = SourceText.codeOnly(try text("Sources/Echoelmusic/Sync/SACNSender.swift"))
        XCTAssertTrue(sacn.contains("ArtNetSender.dmxChannels(for: frame, resolution: resolution)"), """
            sACN no longer calls Art-Net's bio→DMX mapping. Claim 1 drives that one function \
            and therefore covered BOTH light senders; with a fork it covers only Art-Net, and \
            sACN needs its own clinical-free claim in this file (#1293).
            """)
        XCTAssertFalse(sacn.contains("hrvRMSSDms") || sacn.contains("hrvSDNNms")
                       || sacn.contains("hrvPNN50"),
                       "sACN reads a clinical field directly, bypassing the shared mapping (#1293)")
    }
}
#endif
