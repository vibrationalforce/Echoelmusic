// TheLightingLookIsACanonicalParameterTests.swift
// Echoel — P2 Proof #1 (founder sequence 2026-09-22: ownership seam → review → this).
//
// ⭐ WHAT IS BEING PROVED, and it is exactly one thing. `EchoelParameterRegistry` has
// described engine parameters since the EchoelAI N2 cycle, and every descriptor in it has
// been `.audio` — one medium, one inventory, so "the canonical parameter path" was a claim
// about a path that had only ever carried one kind of traffic. This slice sends ONE non-audio
// creative parameter down the same path, end to end:
//
//     EchoelParameterRegistry → ParameterDescriptor → ParameterApplyRouter
//                             → LightingStore.setLookIntensity
//
// No second registry, no lighting-specific descriptor type, no parallel key namespace. If the
// path is genuinely canonical, a second medium costs a catalog entry and a binding — and that
// is the proposition this file measures.
//
// ⚠️ THE FIVE WAYS THIS COULD GO WRONG, one claim family each, because none shows up in a diff:
//   1. the descriptor is REGISTERED but nothing is BOUND — the placebo the router's own header
//      forbids: a queryable parameter that moves nothing (claims 1–4);
//   2. the registry or the router starts OWNING the value — a second home for lighting state,
//      and then two writers race for what a rig shows (claims 5, 9);
//   3. the clamp is repeated at the binding — `applyReal` BYPASSES the descriptor range on
//      purpose, so a second clamp would look like safety while the two spellings drift
//      (claims 6–7);
//   4. the parameter silently acquires a modulation destination. The app loop directly above
//      the binding turns EVERY router-bound keyPath into one; binding after it is the whole
//      reason this parameter is not modulatable, and that ORDER is invisible to review
//      (claim 10);
//   5. per-track cloning namespaces it into `track.<uuid>.lighting.look.intensity`, which
//      would address a lighting rig per audio lane — a category error (claim 11).
//
// ⚠️ IT FORBIDS NO FUTURE WORK (#364). Nothing here says the look may never be modulated,
// automated, persisted or given a door. Those are later, DELIBERATE steps, and each one has a
// named repair in the message of the claim it reds: move the binding above the loop, register
// the destination explicitly, add the persistence with its migration. What this file pins is
// that none of them happens BY ACCIDENT, and that the value has exactly one writer today.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — every assertion was transcribed into
// Python and driven against BOTH trees. On the parent (`cc0c71ed3`) `LightingParameterCatalog`
// does not exist, so this file does not compile there at all: NO assertion has a verdict on the
// parent, and that is stated rather than booked as twelve regressions (#486, #488). Claims 1–8
// and 11 are END-TO-END BEHAVIOUR (§1) — the registry, the router and the store are `public`
// value/control-plane types the bundle really constructs and drives. Claims 5b, 7b, 9, 10 and
// 11b are SOURCE-TEXT SCANS, because a wiring ORDER inside `EchoelmusicApp.body` and the
// absence of a second writer are not observable from a test process.
//
// ⚠️ DEVICE PROBE, OPEN AND NAMED: that the look reads as one continuous creative level on a
// real rig — and that the default still looks identical to the pre-parameter build — is an eye
// question. [NEEDS-FOUNDER-VERIFY] Art-Net or sACN rig connected, drive the parameter from 1.0
// down to 0 and back; the picture must dim smoothly and return unchanged.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheLightingLookIsACanonicalParameterTests: XCTestCase {

    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let registry = "Sources/Echoelmusic/Core/EchoelParameterRegistry.swift"
    private static let router = "Sources/Echoelmusic/Core/ParameterApplyRouter.swift"

    /// The literal, written out ONCE here rather than read through the catalog constant: a
    /// source scan that asks the code what it is looking for cannot notice a rename, and a
    /// rename is one of the things these scans exist to notice.
    private static let key = "lighting.look.intensity"

    // MARK: - 1. The registry really carries it, and carries exactly one of it

    /// END-TO-END BEHAVIOUR. Registration is what makes the parameter QUERYABLE — the half a
    /// planner, a picker or a tool surface sees. One lighting descriptor, and it is this key.
    func testTheRegistryCarriesExactlyOneLightingParameter() {
        let registry = EchoelParameterRegistry()
        registry.register(DDSPParameterCatalog.descriptors)
        registry.register(LightingParameterCatalog.descriptors)

        let lighting = registry.all().filter { $0.domain == .lighting }
        XCTAssertEqual(
            lighting.count, 1,
            "the registry carries \(lighting.count) lighting descriptors, not 1. P2 Proof #1 is "
            + "ONE canonical cross-domain parameter. A second lighting parameter is a later, "
            + "deliberate slice — and `grandMaster` and `blackout` may never be among them: "
            + "one is the operator's control over finished output, the other a safety cut.")
        XCTAssertEqual(lighting.first?.keyPath, Self.key,
                       "the one lighting descriptor is not `\(Self.key)`.")
        XCTAssertEqual(LightingParameterCatalog.descriptors.count, 1,
                       "`LightingParameterCatalog` no longer holds exactly one descriptor.")

        // COUNTERWEIGHT (#343): the audio inventory it joined is untouched, and the new entry
        // did not REPLACE anything — `register` replaces by keyPath, so a key collision would
        // shrink the registry silently.
        XCTAssertEqual(registry.all().count,
                       DDSPParameterCatalog.descriptors.count + 1,
                       "registering the lighting catalog changed the registry size by something "
                       + "other than +1 — a keyPath collided with an existing descriptor.")
        XCTAssertTrue(registry.all().contains { $0.domain == .audio },
                      "ANCHOR MISSING: the audio inventory is gone from the registry (#454).")
    }

    // MARK: - 2. The descriptor describes the owner's own range, not a second opinion

    /// END-TO-END BEHAVIOUR. The descriptor is metadata ABOUT `LightingStore`, so its default
    /// is READ from the owner (#416) — three places (stored property, NaN fallback, this
    /// default) must agree, and only one of them may hold the literal.
    func testTheDescriptorDescribesTheOwnersOwnRange() throws {
        let registry = EchoelParameterRegistry()
        registry.register(LightingParameterCatalog.descriptors)
        let d = try XCTUnwrap(registry.descriptor(for: Self.key),
                              "no descriptor is registered for `\(Self.key)`.")

        XCTAssertEqual(d.domain, .lighting,
                       "the lighting parameter's domain is `\(d.domain)`. A keyPath beginning "
                       + "\"lighting.\" is a naming convention; `domain` is the typed statement.")
        XCTAssertEqual(d.min, 0, accuracy: 1e-6, "the creative look level is a 0…1 multiplier.")
        XCTAssertEqual(d.max, 1, accuracy: 1e-6, "the creative look level is a 0…1 multiplier.")
        XCTAssertEqual(
            d.defaultValue, LightingStore.defaultLookIntensity, accuracy: 1e-6,
            "the descriptor default has drifted from the owner's. It must be READ from "
            + "`LightingStore.defaultLookIntensity`, never written again — the stored property, "
            + "the non-finite fallback and this default are one decision in three places.")
        XCTAssertEqual(d.defaultValue, 1, accuracy: 1e-6,
                       "the identity is no longer 1.0, so every existing rig changes brightness "
                       + "on upgrade. That is a founder decision, not a parameter edit.")
        XCTAssertTrue(d.unit.isEmpty,
                      "the look level carries a unit. It is dimensionless and reads as a raw "
                      + "decimal (\"0.50\", never \"50 %\") — the Uncodixfy parameter-row law.")
        XCTAssertNil(d.valueLabels,
                     "the look level carries value labels. Labels make a parameter a stepped "
                     + "choice — a Picker; this is a continuous level and stays a number field.")
        XCTAssertFalse(d.displayName.isEmpty, "the descriptor has no display name.")
    }

    // MARK: - 3. A normalized apply reaches the REAL owner

    /// END-TO-END BEHAVIOUR — the claim the whole slice is about. Registry + router + store,
    /// wired exactly as `EchoelmusicApp` wires them, and the value lands on the owner.
    func testANormalizedApplyReachesTheRealOwner() {
        let store = LightingStore()
        let router = Self.wiredRouter(for: store)

        for normalized in [Float(0), 0.5, 1] {
            let applied = router.applyNormalized(Self.key, normalized)
            XCTAssertEqual(
                applied ?? -1, normalized, accuracy: 1e-6,
                "applying \(normalized) returned \(String(describing: applied)). The 0…1 "
                + "descriptor range maps normalized to real one-to-one, so the router must "
                + "return the same number it wrote.")
            XCTAssertEqual(
                store.lookIntensity, normalized, accuracy: 1e-6,
                "applying \(normalized) left the OWNER at \(store.lookIntensity). The router "
                + "must write through `LightingStore.setLookIntensity` — a descriptor that is "
                + "registered but bound to nothing is the placebo `ParameterApplyRouter`'s own "
                + "header forbids.")
        }
    }

    /// END-TO-END BEHAVIOUR — the binding is what separates "described" from "real", so the
    /// registry-only half is pinned as the no-op it must be.
    func testAnUnboundRegistrationMovesNothing() {
        let store = LightingStore()
        let registry = EchoelParameterRegistry()
        registry.register(LightingParameterCatalog.descriptors)
        let router = ParameterApplyRouter(registry: registry)   // deliberately NOT bound

        XCTAssertNil(router.applyNormalized(Self.key, 0),
                     "an unbound keyPath applied something. Unbound must be a safe no-op.")
        XCTAssertEqual(store.lookIntensity, LightingStore.defaultLookIntensity, accuracy: 1e-6,
                       "the owner moved although nothing was bound to it — something else in "
                       + "this build can write `lookIntensity`.")
        XCTAssertFalse(router.isBound(Self.key),
                       "ANCHOR MISSING: an unbound router reports the key as bound (#454).")
    }

    // MARK: - 4. The OWNER holds the clamp, because `applyReal` bypasses the descriptor's

    /// END-TO-END BEHAVIOUR. `applyReal` dispatches without consulting the descriptor range —
    /// that is documented and deliberate — so for a value that reaches a physical fixture the
    /// range has to be enforced by the owner or not at all.
    func testTheOwnerClampsWhatTheDescriptorRangeCannot() {
        let store = LightingStore()
        let router = Self.wiredRouter(for: store)

        XCTAssertTrue(router.applyReal(Self.key, -2),
                      "no setter took the real value — the binding is gone.")
        XCTAssertEqual(store.lookIntensity, 0, accuracy: 1e-6,
                       "a real value below the range left the owner at \(store.lookIntensity). "
                       + "`applyReal` bypasses the descriptor clamp on purpose; the clamp lives "
                       + "in `LightingStore.sanitizedLookIntensity` and nowhere else.")

        XCTAssertTrue(router.applyReal(Self.key, 3), "no setter took the real value.")
        XCTAssertEqual(store.lookIntensity, 1, accuracy: 1e-6,
                       "a real value above the range left the owner at \(store.lookIntensity).")
    }

    /// END-TO-END BEHAVIOUR. Non-finite follows the OWNER's policy, which is deliberately NOT
    /// the repo's usual `clamped(to:)` direction: a creative multiplier with no valid
    /// instruction leaves the generated look alone (identity 1), because failing to the lower
    /// bound would black out a rig mid-show on one bad frame.
    func testANonFiniteRealValueFollowsTheOwnersPolicy() {
        let store = LightingStore()
        let router = Self.wiredRouter(for: store)

        for bad in [Float.nan, Float.infinity, -Float.infinity] {
            router.applyReal(Self.key, 0.25)
            XCTAssertEqual(store.lookIntensity, 0.25, accuracy: 1e-6,
                           "ANCHOR MISSING: the owner did not take 0.25 (#454).")
            router.applyReal(Self.key, bad)
            XCTAssertEqual(
                store.lookIntensity, LightingStore.defaultLookIntensity, accuracy: 1e-6,
                "a non-finite value left the owner at \(store.lookIntensity). It must fall back "
                + "to the IDENTITY, not to 0 — `FloatingPointClamp.clamped(to:)`'s NaN→lower-"
                + "bound direction is right for a bio value that must fail quiet and wrong for a "
                + "creative multiplier, which must fail INVISIBLE.")
        }
    }

    // MARK: - 5. The registry and the router do not own lighting state

    /// SOURCE-TEXT SCAN. The catalog READS the owner's default; that is the whole permitted
    /// direction of dependency. Neither file may hold lighting state or a second writer.
    func testTheParameterInfrastructureDoesNotOwnTheValue() throws {
        let registryCode = SourceText.codeOnly(try text(Self.registry))
        XCTAssertFalse(registryCode.contains("var lookIntensity"),
                       "`EchoelParameterRegistry.swift` now declares lighting STATE. The "
                       + "registry describes parameters; `LightingStore` owns the value.")
        XCTAssertFalse(registryCode.contains("setLookIntensity"),
                       "the catalog now WRITES the look. It may only read the owner's default.")
        XCTAssertTrue(registryCode.contains("LightingStore.defaultLookIntensity"),
                      "ANCHOR MISSING: the descriptor default is no longer read from the owner "
                      + "(#454) — check it has not been re-written as a literal (#416).")

        let routerCode = SourceText.codeOnly(try text(Self.router))
        XCTAssertFalse(routerCode.contains("Lighting"),
                       "`ParameterApplyRouter` now names a lighting type. It is the generic "
                       + "dispatcher; a domain-specific branch in it is the beginning of a "
                       + "per-medium router, and then the canonical path stops being one path.")
    }

    // MARK: - 6. The default is the identity for the creative stage

    /// END-TO-END BEHAVIOUR. The descriptor default and the creative stage are two halves of
    /// the same promise: a build that registers this parameter but never moves it must look
    /// exactly like the build before it.
    func testTheDescriptorDefaultIsTheIdentityForTheCreativeStage() throws {
        let registry = EchoelParameterRegistry()
        registry.register(LightingParameterCatalog.descriptors)
        let d = try XCTUnwrap(registry.descriptor(for: Self.key))

        for generated in [Float(0), 0.05, 0.3, 0.5, 0.77, 1] {
            XCTAssertEqual(
                LightingStore.creativeTarget(generated, lookIntensity: d.defaultValue),
                generated, accuracy: 1e-6,
                "at the descriptor default the creative stage changed \(generated). The default "
                + "MUST be behaviourally neutral — otherwise this slice silently re-lights every "
                + "existing show.")
        }
    }

    // MARK: - 7. Exactly one thing in this build can mutate the look

    /// SOURCE-TEXT SCAN. `lookIntensity` is `private(set)`, so the only writer is
    /// `setLookIntensity` — and this pins that exactly one production call site exists.
    func testExactlyOneProductionPathMutatesTheLook() throws {
        let calls = try Self.occurrencesAcrossSources(".setLookIntensity(")
        XCTAssertEqual(
            calls, 1,
            "\(calls) production call sites write the creative look, not 1. Two writers race "
            + "last-writer-wins for what a rig shows, and the loser is invisible. If a second "
            + "surface needs to move it, it routes through the SAME parameter, not a second "
            + "call — that is what the canonical path is for.")

        let bindBlock = try Self.bindClosure(
            in: SourceText.codeOnly(try text(Self.app)))
        XCTAssertTrue(bindBlock.contains("setLookIntensity("),
                      "the router binding no longer delegates to the owner's API.")
        for forbidden in ["artNet", "sacn", "grandMaster", "blackout", "FlashGuard"] {
            XCTAssertFalse(
                bindBlock.contains(forbidden),
                "the router binding now touches `\(forbidden)`. A parameter may move the "
                + "CREATIVE level only: the senders READ the store, the master is the live "
                + "operator's, and blackout is a safety cut no parameter may reach.")
        }
        for clampish in ["min(", "max(", "clamped(", "isFinite"] {
            XCTAssertFalse(
                bindBlock.contains(clampish),
                "the router binding repeats the range policy (`\(clampish)`). The owner clamps; "
                + "a second spelling of one decision drifts (#416) and looks like safety while "
                + "it does so.")
        }
    }

    // MARK: - 8. Nothing persists, modulates or automates this key

    /// END-TO-END BEHAVIOUR + SOURCE-TEXT SCAN — the absence set the slice promised. Each half
    /// names its own repair, so a deliberate later step edits this message instead of deleting
    /// the claim (#364).
    func testNothingYetModulatesOrPersistsThisKey() throws {
        XCTAssertFalse(
            ModDestinationKey.all.contains(Self.key),
            "`\(Self.key)` is now a modulation destination. P2 Proof #1 is descriptor + "
            + "registration + binding + owner mutation, and explicitly NOT modulation. Making "
            + "the look body-modulatable is a later, deliberate slice — when it happens, say so "
            + "here rather than deleting the assertion.")

        let codeHits = try Self.occurrencesAcrossSources("\"\(Self.key)\"")
        XCTAssertEqual(
            codeHits, 1,
            "the literal `\(Self.key)` occurs \(codeHits) times in `Sources/` CODE, not 1. It "
            + "has one home — `LightingParameterCatalog.lookIntensity` — and every other site "
            + "reads that constant, so a rename cannot leave a descriptor registered under a "
            + "name nothing is bound to. (Comments naming it are stripped and do not count.)")
    }

    // MARK: - 9. The wiring ORDER that keeps the parameter out of the modulation engine

    /// SOURCE-TEXT SCAN, and the one claim in this file that guards a fact invisible to review.
    /// The app loop turns every ROUTER-BOUND keyPath into a `ModulationEngine` destination, and
    /// it reads a snapshot — so binding lighting AFTER the loop is the entire reason claim 8's
    /// first half holds. Moving one line up would grant a modulation destination nobody asked
    /// for, and no test of the loop or of the binding alone would notice.
    func testTheLightingBindingComesAfterTheModulationRegistrationLoop() throws {
        let code = SourceText.codeOnly(try text(Self.app))
        let loop = "for descriptor in parameterRouter.automatableDescriptors()"
        let bind = "parameterRouter.bind(LightingParameterCatalog.lookIntensity)"

        let loopRange = try XCTUnwrap(
            code.range(of: loop),
            "ANCHOR MISSING: `\(loop)` is gone from the app. If the modulation registration "
            + "moved or was rewritten, re-anchor this claim in the same commit (§4) — do not "
            + "let it pass by finding nothing.")
        let bindRange = try XCTUnwrap(
            code.range(of: bind),
            "ANCHOR MISSING: the lighting parameter is no longer bound in `EchoelmusicApp`.")

        XCTAssertTrue(
            loopRange.lowerBound < bindRange.lowerBound,
            "the lighting binding now runs BEFORE the modulation registration loop, so the loop "
            + "sweeps it up and `\(Self.key)` becomes a modulation destination as a side effect. "
            + "If that is intended, register the destination EXPLICITLY and say so — a "
            + "capability nobody asked for should not arrive by line order.")
        XCTAssertEqual(try Self.occurrencesAcrossSources(bind), 1,
                       "the lighting parameter is bound more than once.")
    }

    // MARK: - 10. It is not a per-track parameter, and nothing clones it into one

    /// END-TO-END BEHAVIOUR + SOURCE-TEXT SCAN. `PerTrackParameterKeyPath.descriptors(for:…)`
    /// would clone a supplied descriptor array into `track.<uuid>.<base>` keys. A per-lane
    /// lighting look is a category error — a rig is not owned by an audio lane — and the clone
    /// is safe today for a measurable reason: it takes an explicit `base:` array and has NO
    /// production caller, so it cannot sweep the registry.
    func testTheLookIsNotClonedPerTrack() throws {
        XCTAssertFalse(PerTrackParameterKeyPath.isPerTrack(Self.key),
                       "`\(Self.key)` parses as a per-track keyPath.")
        XCTAssertTrue(PerTrackParameterKeyPath.isPerTrack(
            PerTrackParameterKeyPath.make(laneID: UUID(), base: "ddsp.filter.cutoff")),
                      "ANCHOR MISSING: `isPerTrack` no longer recognises its own form (#454).")

        let callers = try Self.occurrencesAcrossSources("PerTrackParameterKeyPath.descriptors(")
        XCTAssertEqual(
            callers, 0,
            "`PerTrackParameterKeyPath.descriptors(` now has \(callers) production call site(s). "
            + "Read what it is handed: if it is swept over the whole registry it will clone the "
            + "lighting descriptor into `track.<uuid>.\(Self.key)`, addressing a light rig per "
            + "audio lane. Pass an explicitly AUDIO base list, or filter by `domain`.")
    }

    // MARK: - Helpers

    /// The app's wiring, reproduced exactly: one registry, one router, one store, one binding.
    private static func wiredRouter(for store: LightingStore) -> ParameterApplyRouter {
        let registry = EchoelParameterRegistry()
        registry.register(LightingParameterCatalog.descriptors)
        let router = ParameterApplyRouter(registry: registry)
        router.bind(LightingParameterCatalog.lookIntensity) { [weak store] value in
            store?.setLookIntensity(value)
        }
        return router
    }

    /// The body of the lighting `bind` closure, by BRACE MATCHING rather than a line window:
    /// this repo writes 30–40-line comment blocks and `SourceText.codeOnly` preserves line
    /// count, so any fixed window is unsound by construction (#408).
    private static func bindClosure(in code: String) throws -> String {
        let anchor = "parameterRouter.bind(LightingParameterCatalog.lookIntensity)"
        let start = try XCTUnwrap(code.range(of: anchor),
                                  "ANCHOR MISSING: the lighting binding is gone (#454).")
        let chars = Array(code[start.upperBound...])
        guard let open = chars.firstIndex(of: "{") else {
            throw XCTSkip("the lighting binding has no closure body to read")
        }
        var depth = 0
        for i in open..<chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" {
                depth -= 1
                if depth == 0 { return String(chars[open...i]) }
            }
        }
        throw XCTSkip("the lighting binding's closure is unbalanced in the stripped text")
    }

    /// Occurrences of a literal in the CODE of every Swift file under `Sources/` (comments
    /// stripped, string literals kept).
    private static func occurrencesAcrossSources(_ needle: String) throws -> Int {
        var total = 0
        for url in try swiftFilesUnderSources() {
            let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
            total += code.components(separatedBy: needle).count - 1
        }
        return total
    }

    private static func swiftFilesUnderSources() throws -> [URL] {
        let dir = repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard let walk = FileManager.default.enumerator(at: dir,
                                                        includingPropertiesForKeys: nil) else {
            throw XCTSkip("could not enumerate Sources/Echoelmusic")
        }
        return walk.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func text(_ relativePath: String) throws -> String {
        try String(contentsOf: Self.repoRoot().appendingPathComponent(relativePath),
                   encoding: .utf8)
    }
}
