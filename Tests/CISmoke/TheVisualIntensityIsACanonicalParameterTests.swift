// TheVisualIntensityIsACanonicalParameterTests.swift
// Echoel — Workstation redesign C1 (scratchpads/PLAN_WORKSTATION_REDESIGN_2026-10-01.md): the
// first VISUAL parameter through the canonical parameter path.
//
// ⭐ WHAT IS BEING PROVED. P2 Proof #1 sent one LIGHTING parameter down
//     EchoelParameterRegistry → ParameterDescriptor → ParameterApplyRouter → owner
// and this file sends the first VISUAL one down the same path, plus the step lighting did not
// need: the owner is READ by a 60 fps Metal draw loop, so the value must reach
// `MetalBioView.draw(in:)` without SwiftUI, `@AppStorage` or `@Observable`, and must reach the
// picture SLEWED, because a curve that steps the brightness of the whole screen is a flash.
//
// ⚠️ THE WAYS THIS COULD GO WRONG, one claim family each:
//   1. registered but not bound, or bound but not READ — the placebo (claims 1–4, 9);
//   2. the parameter writes the `visual.intensity` setting (claims 10, 11);
//   3. the value lands in an observable or persisted store (claim 10);
//   4. it acquires a control source by accident — eligibility denied on the descriptor and
//      asked for at dispatch, the P2 Proof #1.1 law (claims 5, 6);
//   5. the FACTOR steps faster than the flash law allows, or a NaN reaches a uniform (7, 8).
//      ⚠️ Claim 7 pins the factor's bound (≤ 0.05 per 3 Hz half-cycle). The bound on the PICTURE
//      also needs the renderer's τ 0.4 intensity easing downstream (the gain stages can multiply
//      the factor ~2.8×) — that argument is prose in `VisualCreativeState`'s header plus the
//      device probe below, not an assertion here, because pinning the easing's tau would forbid
//      a designer's change (#364).
//
// ⚠️ IT FORBIDS NO FUTURE WORK (#364). C2 makes the parameter automatable together with its
// editor: one word at the descriptor plus claims 5/6, whose messages name the repair. A faster
// slew is a device decision and edits claim 7 together with `VisualCreativeState`'s header.
//
// ⚠️ HONEST GRADING (§0/§3). On the parent `aea9096f6` neither `VisualCreativeState` nor
// `VisualParameterCatalog` exists, so this file does not compile there: NO claim has a verdict
// on that tree, and none is booked as a regression (#486, #488). Every claim is FORWARD except
// the counterweights, which hold on both trees and are marked where they stand (claim 6's
// eligible audio lane, claim 9's autoTerm factor and touch read, claim 11's user field key).
// ANCHOR MISSING (#454) marks the claims that would otherwise pass vacuously. Claims 1–8 are
// END-TO-END BEHAVIOUR on the real public types; 9–12 are SOURCE-TEXT SCANS over
// `SourceText.codeOnly`, because who reads this in the draw loop and who writes it are facts no
// test process can observe. STRIPPER (#453), derived from the patch text, no tree run:
// TRAGEND for claim 9's file-wide `VisualCreativeState.shared` count (the `creativeIntensity`
// property doc names it: raw 2, stripped 1); PROPHYLAKTISCH for every other needle (0 flips).
// [TRANSCRIPTION OWED by the implementing session, §0.]
//
// ⚠️ DEVICE PROBE. [NEEDS-FOUNDER-VERIFY] Visual-Fenster öffnen und die Felder Intensität,
// Bewegung und Farbton wie gewohnt benutzen: das Bild muss sich genau so verhalten wie vor C1 —
// der neue Faktor steht auf 1 und hat keinen Schreiber. Ein Abblenden über eine Kurve gibt es
// erst mit C2 und wird dort geprüft.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheVisualIntensityIsACanonicalParameterTests: XCTestCase {

    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let registry = "Sources/Echoelmusic/Core/EchoelParameterRegistry.swift"
    private static let router = "Sources/Echoelmusic/Core/ParameterApplyRouter.swift"
    private static let store = "Sources/Echoelmusic/Core/VisualCreativeState.swift"
    private static let renderer = "Sources/Echoelmusic/Views/MetalBioView.swift"
    private static let catalog = "Sources/Echoelmusic/Resources/Localizable.xcstrings"

    /// Written out ONCE, not read through the catalog constant: a scan that asks the code what
    /// it is looking for cannot notice a rename.
    private static let key = "visual.creative.intensity"

    // MARK: - 1. Exactly one visual descriptor, and it is this key (BEHAVIOUR, FORWARD)

    func testTheRegistryCarriesExactlyOneVisualParameter() {
        let registry = EchoelParameterRegistry()
        registry.register(DDSPParameterCatalog.descriptors)
        registry.register(LightingParameterCatalog.descriptors)
        registry.register(VisualParameterCatalog.descriptors)
        let visual = registry.all().filter { $0.domain == .visual }
        XCTAssertEqual(visual.count, 1,
                       "the registry carries \(visual.count) visual descriptors, not 1. C1 is ONE "
                       + "parameter; motion, hue, detail and blend each need their own flash "
                       + "analysis first. A deliberate second one edits this count.")
        XCTAssertEqual(visual.first?.keyPath, Self.key, "the one visual descriptor is not `\(Self.key)`.")
        XCTAssertEqual(registry.all().count,
                       DDSPParameterCatalog.descriptors.count
                       + LightingParameterCatalog.descriptors.count + 1,
                       "registering the visual catalog changed the size of another inventory.")
        XCTAssertEqual(VisualParameterCatalog.creativeIntensity, Self.key,
                       "the catalog constant no longer spells `\(Self.key)`.")
    }

    // MARK: - 2. The descriptor's range is the owner's range (BEHAVIOUR, FORWARD)

    func testTheDescriptorRangeIsTheOwnersRange() throws {
        let d = try XCTUnwrap(VisualParameterCatalog.descriptors.first { $0.keyPath == Self.key },
                              "ANCHOR MISSING: `VisualParameterCatalog` has no `\(Self.key)` (#454).")
        XCTAssertEqual(d.domain, .visual, "the creative visual level is not `.visual`.")
        XCTAssertEqual(d.min, 0, accuracy: 1e-6, "the level is a 0…1 multiplier.")
        XCTAssertEqual(d.max, 1, accuracy: 1e-6, "the level is a 0…1 multiplier — it attenuates only.")
        XCTAssertEqual(d.defaultValue, VisualCreativeState.defaultIntensity, accuracy: 1e-6,
                       "the descriptor default and the owner's identity are two values (#416).")
        XCTAssertEqual(d.defaultValue, 1, accuracy: 1e-6,
                       "the identity is 1: at the default the picture must be exactly the user's.")
        XCTAssertEqual(d.unit, "", "a dimensionless 0…1 value reads as a raw decimal, so no unit.")
        XCTAssertNil(d.valueLabels, "a continuous level is a number field, never a Picker.")
    }

    // MARK: - 3. A dispatch reaches the owner; an unbound registration moves nothing (BEHAVIOUR)

    func testANormalizedDispatchReachesTheOwner() {
        let state = VisualCreativeState()
        let router = Self.wiredRouter(for: state)
        _ = router.applyNormalized(Self.key, 0.25)
        XCTAssertEqual(state.intensity, 0.25, accuracy: 1e-6,
                       "a registered, bound dispatch did not reach `VisualCreativeState`.")

        let registry = EchoelParameterRegistry()
        registry.register(VisualParameterCatalog.descriptors)
        let unbound = ParameterApplyRouter(registry: registry)
        let untouched = VisualCreativeState()
        _ = unbound.applyNormalized(Self.key, 0)
        XCTAssertEqual(untouched.intensity, VisualCreativeState.defaultIntensity, accuracy: 1e-6,
                       "an UNBOUND registration moved an owner — the router holds a second home.")
    }

    // MARK: - 4. The owner clamps what `applyReal` does not (BEHAVIOUR, FORWARD)

    func testTheOwnerClampsWhatTheRouterDoesNot() {
        let state = VisualCreativeState()
        let router = Self.wiredRouter(for: state)
        _ = router.applyReal(Self.key, -2)
        XCTAssertEqual(state.intensity, 0, accuracy: 1e-6, "below-range real value was not clamped to 0.")
        _ = router.applyReal(Self.key, 3)
        XCTAssertEqual(state.intensity, 1, accuracy: 1e-6,
                       "above-range real value was not clamped to 1 — the level would AMPLIFY.")
        state.setIntensity(.nan)
        XCTAssertEqual(state.intensity, VisualCreativeState.defaultIntensity, accuracy: 1e-6,
                       "NaN did not map to the identity; it would reach a Metal uniform.")
        state.setIntensity(.infinity)
        XCTAssertEqual(state.intensity, VisualCreativeState.defaultIntensity, accuracy: 1e-6,
                       "infinity did not map to the identity.")
    }

    // MARK: - 5. Denied both ways, even when bound EARLY (BEHAVIOUR, FORWARD)

    func testNothingMayAutomateOrModulateItYet() {
        let registry = EchoelParameterRegistry()
        let router = ParameterApplyRouter(registry: registry)
        let state = VisualCreativeState()
        registry.register(VisualParameterCatalog.descriptors)
        router.bind(VisualParameterCatalog.creativeIntensity) { [weak state] in state?.setIntensity($0) }
        registry.register(DDSPParameterCatalog.descriptors)
        for base in PolySynthVoice.automatableBases { router.bind(base) { _ in } }

        XCTAssertTrue(router.isBound(Self.key),
                      "ANCHOR MISSING: the key is not bound, so the exclusions below are vacuous (#367).")
        XCTAssertFalse(router.isAutomationEligible(Self.key),
                       "the visual level is automation eligible. C2 flips this WITH its editor — "
                       + "edit this message then, do not delete the assertion.")
        XCTAssertFalse(router.isModulationEligible(Self.key), "the visual level is modulation eligible.")
        XCTAssertFalse(router.automatableDescriptors().map(\.keyPath).contains(Self.key),
                       "binding early put the visual level into the automatable set.")
        XCTAssertFalse(router.modulatableDescriptors().map(\.keyPath).contains(Self.key),
                       "binding early put the visual level into the modulatable set.")
        XCTAssertFalse(ModDestinationKey.all.contains(Self.key),
                       "`\(Self.key)` is a modulation destination; making it body-modulatable is a "
                       + "later, deliberate slice.")
    }

    // MARK: - 6. A lane naming the key cannot move the owner (BEHAVIOUR; counterweight in 6b)

    func testAnAutomationLaneCannotMoveTheVisualOwner() {
        let state = VisualCreativeState()
        let router = Self.wiredRouter(for: state)
        let player = AutomationPlayer()
        player.wire(router: router)
        player.enabled = true
        player.addPoint(parameter: Self.key, beat: 0, value: 0)
        player.addPoint(parameter: Self.key, beat: 1, value: 0)
        for step in 0..<16 { player.applyStep(step) }
        XCTAssertEqual(state.intensity, VisualCreativeState.defaultIntensity, accuracy: 1e-6,
                       "an automation lane drawn at 0 moved the visual owner to \(state.intensity). "
                       + "Automation is not authorised in C1; `applyAutomation` must ask the descriptor.")
        XCTAssertFalse(player.lanes.filter { $0.parameter == Self.key }.isEmpty,
                       "ANCHOR MISSING: the lane was never created, so the assertion above proves "
                       + "nothing (#367).")
    }

    /// COUNTERWEIGHT (holds on both trees): the same player still moves an eligible parameter.
    func testAnAutomationLaneStillMovesAnEligibleAudioParameter() {
        let registry = EchoelParameterRegistry()
        registry.register(DDSPParameterCatalog.descriptors)
        let router = ParameterApplyRouter(registry: registry)
        let base = "ddsp.env.attack"
        var seen: [Float] = []
        router.bind(base) { seen.append($0) }
        let player = AutomationPlayer()
        player.wire(router: router)
        player.enabled = true
        player.addPoint(parameter: base, beat: 0, value: 1)
        player.addPoint(parameter: base, beat: 1, value: 1)
        for step in 0..<16 { player.applyStep(step) }
        XCTAssertFalse(seen.isEmpty,
                       "an eligible audio parameter received nothing — the exclusion above would be "
                       + "green on a player that dispatches nothing at all (#367).")
    }

    // MARK: - 7. The slew is the flash law (BEHAVIOUR, FORWARD)

    func testTheSlewIsTheFlashLaw() {
        let rate = VisualCreativeState.maxIntensityChangePerSecond
        XCTAssertEqual(rate, FlashGuard.luminanceDeltaThreshold * FlashGuard.maxFlashHz, accuracy: 1e-12,
                       "the slew ceiling is no longer derived from the flash law.")
        let frame = 1.0 / 60
        let one = VisualCreativeState.slewedIntensity(from: 1, toward: 0, dt: frame)
        XCTAssertEqual(Double(1 - one), rate * frame, accuracy: 1e-5,
                       "one 60 fps frame did not move by exactly rate × dt.")

        var v: Float = 1
        let halfCycleFrames = Int((60 / (2 * FlashGuard.maxFlashHz)).rounded())   // 10
        for _ in 0..<halfCycleFrames { v = VisualCreativeState.slewedIntensity(from: v, toward: 0, dt: frame) }
        XCTAssertLessThan(Double(1 - v), FlashGuard.luminanceDeltaThreshold,
                          "inside one half-cycle at maxFlashHz the level moved \(1 - v) — at or past "
                          + "the flash threshold. A full-screen step is a flash.")

        let stalled = VisualCreativeState.slewedIntensity(from: 1, toward: 0, dt: 3600)
        XCTAssertEqual(Double(1 - stalled), FlashGuard.maxDelta(perSecond: rate, dt: 3600), accuracy: 1e-6,
                       "a long stall is not bounded by FlashGuard.maxDelta's 1 s cap.")
        let nanDt = VisualCreativeState.slewedIntensity(from: 1, toward: 0, dt: .nan)
        XCTAssertTrue(nanDt.isFinite, "a NaN dt produced a non-finite level.")
        XCTAssertEqual(Double(1 - nanDt), FlashGuard.maxDelta(perSecond: rate, dt: .nan), accuracy: 1e-6,
                       "a NaN dt does not take FlashGuard.maxDelta's fallback.")
        XCTAssertEqual(VisualCreativeState.slewedIntensity(from: 1, toward: 1, dt: frame), 1,
                       "the identity does not survive a frame EXACTLY — the #1244 skip would break.")
        let nanTarget = VisualCreativeState.slewedIntensity(from: 0.5, toward: .nan, dt: frame)
        XCTAssertGreaterThan(nanTarget, 0.5, "a NaN target did not move toward the identity.")
        XCTAssertEqual(VisualCreativeState.slewedIntensity(from: .nan, toward: 0.25, dt: frame), 0.25,
                       accuracy: 1e-6, "a NaN current did not land on the goal.")
    }

    // MARK: - 8. Attenuate only (BEHAVIOUR, FORWARD)

    func testTheLevelOnlyAttenuates() {
        for x: Float in [-1e9, -1, 0, 0.5, 1, 1.0001, 7, 1e9, .nan, .infinity, -.infinity] {
            let s = VisualCreativeState.sanitizedIntensity(x)
            XCTAssertTrue(s >= 0 && s <= 1, "sanitized \(x) to \(s), outside 0…1.")
        }
    }

    // MARK: - 9. The draw loop reads it once per frame (SOURCE SCAN; counterweights marked)

    func testTheRendererReadsItOncePerFrame() throws {
        let code = SourceText.codeOnly(try text(Self.renderer))
        let body = try Self.body(after: "func draw(in view: MTKView) {", in: code)
        XCTAssertEqual(Self.count("VisualCreativeState.shared.intensity", in: body), 1,
                       "`draw(in:)` does not read the creative level exactly once per frame.")
        XCTAssertEqual(Self.count("VisualCreativeState.slewedIntensity(", in: body), 1,
                       "`draw(in:)` does not slew the creative level — a curve could step the picture.")
        XCTAssertTrue(body.contains("intensity: lookIntensity * creativeIntensity * (1 + 0.45 * liveE + 0.30 * musicLevel)"),
                      "the intensity uniform no longer multiplies by `creativeIntensity` — registered "
                      + "and bound but unread is the placebo.")
        XCTAssertEqual(Self.count("VisualCreativeState.shared", in: code), 1,
                       "the renderer reads `VisualCreativeState.shared` outside the one per-frame read.")
        // COUNTERWEIGHTS (both trees): the neighbours this slice must not have displaced.
        XCTAssertTrue(body.contains("* (1 + 0.5 * autoTerm)"), "ANCHOR MISSING: the autoTerm factor is gone (#454).")
        XCTAssertTrue(body.contains("TouchVisualEnergy.shared.value(now: nowGov)"),
                      "ANCHOR MISSING: the touch read the creative read sits beside is gone (#454).")
    }

    // MARK: - 10. Outside SwiftUI, one writer, two readers (SOURCE SCAN, FORWARD)

    func testTheStateLivesOutsideSwiftUIAndHasOneWriter() throws {
        let store = SourceText.codeOnly(try text(Self.store))
        for banned in ["@Observable", "@AppStorage", "UserDefaults", "import SwiftUI", "import Observation"] {
            XCTAssertFalse(store.contains(banned),
                           "`VisualCreativeState` uses `\(banned)`: a transport-rate value would reach "
                           + "SwiftUI bodies or survive a relaunch.")
        }
        var users = Set<String>()
        var setters = 0
        for url in try Self.swiftFilesUnderSources() {
            let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
            if code.contains("VisualCreativeState.shared") {
                users.insert(url.path.components(separatedBy: "Sources/Echoelmusic/").last ?? url.path)
            }
            setters += Self.count(".setIntensity(", in: code)
        }
        XCTAssertEqual(users, ["EchoelmusicApp.swift", "Views/MetalBioView.swift"],
                       "`VisualCreativeState.shared` is used in \(users.sorted()). The router binding "
                       + "and the draw loop are the only two; a third is a second writer or a hot read.")
        XCTAssertEqual(setters, 1,
                       "`.setIntensity(` occurs \(setters) times in Sources code; the router binding is "
                       + "the one writer.")
    }

    // MARK: - 11. One home for the key, and it is not the user's field (SOURCE SCAN; counterweight)

    func testTheKeyHasOneHomeAndIsNotTheUsersField() throws {
        var hits = 0
        for url in try Self.swiftFilesUnderSources() {
            hits += Self.count("\"\(Self.key)\"", in: SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8)))
        }
        XCTAssertEqual(hits, 1, "the literal `\(Self.key)` occurs \(hits) times in Sources code, not 1.")
        // COUNTERWEIGHT (both trees): the user's field keeps its own key.
        XCTAssertEqual(StudioDefaultKeys.visualIntensity.key, "visual.intensity",
                       "ANCHOR MISSING: the user's intensity field changed key (#454).")
        XCTAssertNotEqual(StudioDefaultKeys.visualIntensity.key, Self.key,
                          "the parameter and the user's field share a key — two writers of one number.")
    }

    // MARK: - 12. Router and registry own nothing visual; the name speaks German (SCAN, FORWARD)

    func testTheRouterAndRegistryOwnNothingVisual() throws {
        XCTAssertFalse(SourceText.codeOnly(try text(Self.router)).contains("VisualCreativeState"),
                       "the router names `VisualCreativeState` — it must stay medium-agnostic.")
        let registry = SourceText.codeOnly(try text(Self.registry))
        XCTAssertTrue(registry.contains("defaultValue: VisualCreativeState.defaultIntensity"),
                      "the descriptor default is no longer read from the owner (#416).")
        XCTAssertFalse(registry.contains("setIntensity"), "the registry writes the visual level.")

        let data = try Data(contentsOf: Self.repoRoot().appendingPathComponent(Self.catalog))
        let strings = (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["strings"] as? [String: Any]
        let de = (((strings?["Visual intensity"] as? [String: Any])?["localizations"] as? [String: Any])?["de"]
                  as? [String: Any])?["stringUnit"] as? [String: Any]
        XCTAssertEqual(de?["state"] as? String, "translated",
                       "\"Visual intensity\" has no translated German unit; E4-105 draws descriptor "
                       + "names through the catalog, so it would revert to English mid-screen.")
    }

    // MARK: - Helpers

    /// A walk that cannot run is a red, never a skip (#454): a skipped scan reads as a pass.
    private struct AnchorMissing: Error { let what: String }

    private static func wiredRouter(for state: VisualCreativeState) -> ParameterApplyRouter {
        let registry = EchoelParameterRegistry()
        registry.register(VisualParameterCatalog.descriptors)
        let router = ParameterApplyRouter(registry: registry)
        router.bind(VisualParameterCatalog.creativeIntensity) { [weak state] value in
            state?.setIntensity(value)
        }
        return router
    }

    /// Brace-matched body (codeOnly keeps line count; a fixed window is unsound, #408).
    private static func body(after anchor: String, in code: String) throws -> String {
        let start = try XCTUnwrap(code.range(of: anchor), "ANCHOR MISSING: `\(anchor)` (#454).")
        let chars = Array(code[code.index(before: start.upperBound)...])
        var depth = 0
        for i in chars.indices {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { return String(chars[0...i]) } }
        }
        XCTFail("`\(anchor)` has an unbalanced body in the stripped text — re-anchor.")
        return ""
    }

    private static func count(_ needle: String, in hay: String) -> Int {
        hay.components(separatedBy: needle).count - 1
    }

    private static func swiftFilesUnderSources() throws -> [URL] {
        let dir = repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard FileManager.default.fileExists(atPath: dir.path),
              let walk = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else {
            throw AnchorMissing(what: "could not enumerate Sources/Echoelmusic (#454)")
        }
        let files = walk.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThan(files.count, 250, "the walk read too few files to be a measurement.")
        return files
    }

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func text(_ relativePath: String) throws -> String {
        try String(contentsOf: Self.repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }
}
