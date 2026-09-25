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
//   4. the parameter silently acquires a control source. BINDING used to be enough: the
//      router offered every bound keyPath to automation, and the app loop swept that same set
//      into the modulation matrix — so "the look is not modulatable" was carried by the ORDER
//      OF TWO STATEMENTS in `EchoelmusicApp`. P2 Proof #1.1 replaced that with eligibility
//      STATED on the descriptor and ASKED FOR at dispatch (claims 9–15);
//   5. per-track cloning namespaces it into `track.<uuid>.lighting.look.intensity`, which
//      would address a lighting rig per audio lane — a category error (claims 16–17).
//
// ⚠️ IT FORBIDS NO FUTURE WORK (#364). Nothing here says the look may never be modulated,
// automated, persisted or given a door. Those are later, DELIBERATE steps, and each one has a
// named repair in the message of the claim it reds: move the binding above the loop, register
// the destination explicitly, add the persistence with its migration. What this file pins is
// that none of them happens BY ACCIDENT, and that the value has exactly one writer today.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — every assertion was transcribed into
// Python and driven against BOTH trees. Against `cc0c71ed3` (before P2 Proof #1)
// `LightingParameterCatalog` does not exist, so this file does not compile there at all: NO
// assertion has a verdict on that tree, and that is stated rather than booked as sixteen
// regressions (#486, #488). Against `b38332a75` (before P2 Proof #1.1) it does compile, and
// the transcription put NINE claims red there — the ones this repair creates. Most claims are
// END-TO-END BEHAVIOUR (§1): the registry, the router, the player and the store are `public`
// value/control-plane types the bundle really constructs and drives, and that is the whole
// point of replacing a line-order scan with a behavioural one. The SOURCE-TEXT SCANS are the
// ones asking about a second writer, a persistence root and a call-site count — facts no test
// process can observe.
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

    // MARK: - 9. ELIGIBILITY, not line order — the P2 Proof #1.1 repair

    /// END-TO-END BEHAVIOUR, and it REPLACES a source-order scan that this file used to carry.
    ///
    /// ⛔ WHAT THAT SCAN PINNED, AND WHY IT HAD TO GO. It asserted that the lighting binding
    /// appears AFTER the app's modulation-registration loop, because the loop swept up every
    /// router-bound keyPath and read a snapshot. The assertion was true and the protection was
    /// real — and it institutionalised the defect: the policy "the look is not modulatable"
    /// was carried by the ORDER OF TWO STATEMENTS. A guard that pins line order teaches the
    /// next session that line order is the mechanism, and it goes green on a tree where the
    /// mechanism has quietly become something else. Codex named it, and the repair is that
    /// eligibility is now stated on the descriptor and asked for at dispatch.
    ///
    /// ⭐ SO THIS CLAIM PROVES THE ORDER NO LONGER MATTERS, by binding lighting FIRST — the
    /// arrangement the old guard forbade — and showing the answer is unchanged.
    func testEligibilityGovernsRegardlessOfBindingOrder() {
        let store = LightingStore()
        let registry = EchoelParameterRegistry()
        let router = ParameterApplyRouter(registry: registry)

        // Deliberately the "wrong" order: lighting bound BEFORE the audio catalog is even
        // registered, and long before anything reads the modulatable set.
        registry.register(LightingParameterCatalog.descriptors)
        router.bind(LightingParameterCatalog.lookIntensity) { [weak store] in
            store?.setLookIntensity($0)
        }
        registry.register(DDSPParameterCatalog.descriptors)
        for base in PolySynthVoice.automatableBases { router.bind(base) { _ in } }

        XCTAssertFalse(
            router.modulatableDescriptors().map(\.keyPath).contains(Self.key),
            "binding the lighting parameter EARLY put it into the modulatable set. Eligibility "
            + "must be a property of the descriptor, not of when the bind happened — that was "
            + "the whole defect this slice repairs.")
        XCTAssertFalse(
            router.automatableDescriptors().map(\.keyPath).contains(Self.key),
            "binding the lighting parameter EARLY put it into the automatable set.")
        XCTAssertEqual(
            router.modulatableDescriptors().map(\.keyPath),
            PolySynthVoice.automatableBases.filter { base in
                DDSPParameterCatalog.descriptors.contains { $0.keyPath == base }
            },
            "the modulatable set is no longer exactly the eligible AUDIO parameters, in "
            + "registry order. ⚠️ This is a COUNTERWEIGHT (#343): if it goes red together with "
            + "the two assertions above, the filter is broken in general; if it goes red ALONE, "
            + "the audio inventory changed and this expectation follows it.")
        XCTAssertTrue(router.isBound(Self.key),
                      "ANCHOR MISSING: the lighting key is not bound in this fixture, so the "
                      + "two exclusions above would be green for the wrong reason (#367).")
    }

    /// END-TO-END BEHAVIOUR — the three concepts, told apart on one router.
    func testRegisteredAndBoundDoNotImplyEligible() {
        let store = LightingStore()
        let router = Self.wiredRouter(for: store)

        XCTAssertNotNil(router.applyNormalized(Self.key, 0.25),
                        "REGISTERED + BOUND must still dispatch: the canonical path is what "
                        + "this parameter exists to prove, and eligibility must not break it.")
        XCTAssertEqual(store.lookIntensity, 0.25, accuracy: 1e-6,
                       "the direct apply no longer reaches the owner.")
        XCTAssertFalse(router.isAutomationEligible(Self.key),
                       "the look is automation eligible. It is not — and a lane must not be "
                       + "able to own a light rig's creative level in this slice.")
        XCTAssertFalse(router.isModulationEligible(Self.key),
                       "the look is modulation eligible. It is not.")
    }

    /// END-TO-END BEHAVIOUR — an `AutomationLane` naming this key cannot move the owner.
    /// The lane is CONSTRUCTED, not rejected: the schema is untouched and a persisted project
    /// carrying such a lane still decodes. Only the runtime authorisation is gone.
    func testAnAutomationLaneCannotMoveTheLightingOwner() {
        let store = LightingStore()
        let router = Self.wiredRouter(for: store)
        let player = AutomationPlayer()
        player.wire(router: router)
        player.enabled = true

        player.addPoint(parameter: Self.key, beat: 0, value: 0)
        player.addPoint(parameter: Self.key, beat: 1, value: 0)
        for step in 0..<16 { player.applyStep(step) }

        XCTAssertEqual(
            store.lookIntensity, LightingStore.defaultLookIntensity, accuracy: 1e-6,
            "an automation lane on `\(Self.key)` moved the owner to \(store.lookIntensity). "
            + "The lane drew a value of 0, so a dispatch would be unmistakable. Automation is "
            + "not authorised for this parameter; `AutomationPlayer` must go through "
            + "`applyAutomation`, which asks the descriptor.")
        XCTAssertFalse(
            player.lanes.filter { $0.parameter == Self.key }.isEmpty,
            "ANCHOR MISSING: the lane was never created, so the assertion above proves nothing "
            + "(#367). The schema must still ACCEPT this parameter — refusing to store it would "
            + "be a persistence change, which this slice does not make.")
    }

    /// END-TO-END BEHAVIOUR — the counterweight that keeps claim 9 honest: the SAME player,
    /// the SAME router, an ELIGIBLE audio parameter, and the value does arrive.
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

        XCTAssertFalse(
            seen.isEmpty,
            "an eligible, bound audio parameter received NOTHING from an automation lane. "
            + "Without this, the lighting exclusion above would be green on a build where "
            + "automation dispatches nothing at all — the #367 mirror case.")
    }

    /// END-TO-END BEHAVIOUR — eligibility does not replace a bound owner. A descriptor may say
    /// yes and still move nothing, because nothing is listening.
    func testAnEligibleButUnboundDescriptorStillExecutesNothing() {
        let registry = EchoelParameterRegistry()
        registry.register(DDSPParameterCatalog.descriptors)
        let router = ParameterApplyRouter(registry: registry)   // NOTHING bound
        let base = "ddsp.env.attack"

        XCTAssertTrue(router.isAutomationEligible(base),
                      "ANCHOR MISSING: `\(base)` is no longer automation eligible, so this "
                      + "claim has no eligible-but-unbound subject left (#454).")
        XCTAssertNil(router.applyAutomation(base, 0.5),
                     "an ELIGIBLE but UNBOUND parameter applied something. Capability is "
                     + "permission, never a setter — both conditions are required.")
        XCTAssertTrue(router.automatableDescriptors().isEmpty,
                      "the automatable set offers an unbound parameter. The Placebo law still "
                      + "applies on top of eligibility.")
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

    // MARK: - 11. A per-track ADDRESS cannot launder an eligibility answer

    /// END-TO-END BEHAVIOUR, and it pins the mechanism the previous claim's neighbour relies
    /// on without ever naming it.
    ///
    /// ⭐ WHY THIS IS A CLAIM OF ITS OWN. `ParameterApplyRouter` answers eligibility through
    /// `PerTrackParameterKeyPath.parse` — a `track.<uuid>.<base>` key is answered by its BASE
    /// descriptor. That is deliberate and it is load-bearing in the direction that matters:
    /// `PerTrackParameterKeyPath.descriptors(` has ZERO production call sites (claim 10), so a
    /// per-track key reaching the router today resolves against NOTHING unless the base is
    /// consulted. Resolve by the raw key instead and every per-track lane silently becomes
    /// ineligible — and in the other direction, a future clone that hard-codes `true` could
    /// not grant what its base denies.
    ///
    /// ⚠️ BOTH HALVES ARE REQUIRED (#367). The denial half alone is green on a router that
    /// resolves nothing at all, because "no descriptor" also answers `false`.
    func testAPerTrackAddressResolvesThroughItsBaseDescriptor() {
        let registry = EchoelParameterRegistry()
        registry.register(DDSPParameterCatalog.descriptors)
        registry.register(LightingParameterCatalog.descriptors)
        let router = ParameterApplyRouter(registry: registry)
        let lane = UUID()

        let eligibleBase = PolySynthVoice.automatableBases.first ?? "ddsp.env.attack"
        let perTrackAudio = PerTrackParameterKeyPath.make(laneID: lane, base: eligibleBase)
        XCTAssertTrue(
            router.isAutomationEligible(perTrackAudio),
            "`\(perTrackAudio)` is not automation eligible, although its base `\(eligibleBase)` "
            + "is. No clone of it is registered — nothing registers per-track descriptors in "
            + "production — so the only way to answer is through the BASE. A router that looks "
            + "the raw key up instead answers `false` for every per-track lane in the app, "
            + "silently, with no compile error and no lane that refuses out loud.")

        let perTrackLook = PerTrackParameterKeyPath.make(laneID: lane, base: Self.key)
        XCTAssertFalse(
            router.isAutomationEligible(perTrackLook),
            "`\(Self.key)` is denied automation, but addressing it PER TRACK grants it. A "
            + "key namespace is not a capability decision — whatever answers for the base must "
            + "answer for every address of it, or the denial is one string away from useless.")
        XCTAssertFalse(
            router.isModulationEligible(perTrackLook),
            "the same, for modulation: a per-track address must not grant what the base denies.")
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
        guard FileManager.default.fileExists(atPath: dir.path), let walk = FileManager.default.enumerator(at: dir,
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
