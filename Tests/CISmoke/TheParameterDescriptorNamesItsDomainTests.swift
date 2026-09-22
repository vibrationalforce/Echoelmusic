// TheParameterDescriptorNamesItsDomainTests.swift
// Echoel — P2, descriptor contract. `ParameterDescriptor` can now SAY which creative
// medium a parameter belongs to, instead of leaving it to be inferred from a String.
//
// ⭐ WHY THIS FILE EXISTS. P2 (the cross-domain control graph) has to answer "may this
// control source own this parameter?", and the answer depends on the parameter's DOMAIN.
// Before this slice the only available answer was a prefix test on `keyPath` — a parameter
// would count as lighting because its string happens to start "light.". That is a naming
// convention doing a type's job: it cannot be checked, it cannot be exhaustively switched
// over, and the day someone names an audio parameter `ddsp.light.attack` it silently lies.
// `ParameterDomain` is the typed statement. NOTHING reads it yet — that is the point of a
// contract slice: the field lands first, its readers land later, and every claim below
// exists to prove that landing it changed no behaviour.
//
// ⚠️ THE HAZARD IS THAT THIS SLICE IS INVISIBLE IF IT GOES WRONG. A defaulted field added
// to a `Codable` struct compiles everywhere, routes everywhere and looks correct in every
// diff — while three specific things quietly break:
//   · a per-track CLONE loses the domain (the clone builds, routes, and only LIES about its
//     medium) — claim 11;
//   · a persisted payload from an older build stops decoding, because Swift's SYNTHESIZED
//     `init(from:)` does NOT fall back to a stored property's default — it throws
//     `keyNotFound` — claim 10;
//   · the blast radius leaks: `ModRoute` / `AutomationLane` start carrying a domain, which
//     would make this a persistence change rather than an identity change — claim 9.
// None of those announce themselves. Every other claim here is a COUNTERWEIGHT (#343):
// it pins that something did NOT move.
//
// ⚠️ IT FORBIDS NO DOMAIN (#364). Claim 1 asserts that `DDSPParameterCatalog` — the audio
// catalog — is audio-only. It deliberately does NOT assert that the REGISTRY is audio-only:
// registering the first `.lighting` descriptor is the NEXT P2 slice, and a guard that went
// red on correct work would be exactly the failure #364 names. Claims 2 and 8 are written
// as "these are still present" rather than "there are exactly N", for the same reason.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — every assertion transcribed in
// Python and driven against BOTH trees. On the parent (`830e26cf5`) four claims go red —
// 1, 1b, 10 and 11 — and they are ONE FINDING, not four (#486): `ParameterDomain` does not
// exist there, so a descriptor cannot state its medium, the decoder has nothing to tolerate
// and the clone has nothing to copy. The other eight are COUNTERWEIGHTS (#343) and are green
// on BOTH trees — they ARE the measurement that this slice moved nothing.
// ⚠️ The transcription itself was wrong twice before it was right, both times on claim 5,
// and both times it announced itself by going red on BOTH trees — which is the tell, since
// this slice never touched `PolySynthVoice`. A red on the parent only is a finding; a red on
// both is the grader. Recorded because a §0 grader is graded by nothing.
// Claims 1–6 and 10–11 are END-TO-END BEHAVIOUR (§1): every type named is `public`, so the
// bundle really constructs, registers, routes, encodes and decodes. Claims 7–9 are
// SOURCE-TEXT SCANS, because the tempo registration lives inside an app-startup closure this
// bundle cannot run, and "absent from a file" is a text question by nature.
//
// ⚠️ NO DEVICE PROBE IS OPEN and none is owed: nothing here reaches audio, UI or the wire.
// A field that no consumer reads cannot change what the founder hears.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheParameterDescriptorNamesItsDomainTests: XCTestCase {

    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let matrix = "Sources/Echoelmusic/Core/ModulationMatrix.swift"
    private static let automationLane = "Sources/Echoelmusic/Sequencer/AutomationLane.swift"

    /// The fifteen keyPaths the DDSP catalog has described since the EchoelAI N2 cycle.
    /// They are the PERSISTED identity of an automation target and of a modulation route,
    /// so a rename here silently orphans a user's saved curve.
    private static let knownDDSPKeyPaths = [
        "ddsp.osc.frequency", "ddsp.osc.harmonicity", "ddsp.osc.brightness",
        "ddsp.osc.noiseLevel", "ddsp.amp.level",
        "ddsp.env.attack", "ddsp.env.decay", "ddsp.env.sustain", "ddsp.env.release",
        "ddsp.filter.cutoff", "ddsp.fx.reverbMix", "ddsp.fx.reverbDecay",
        "ddsp.mod.vibratoRate", "ddsp.mod.vibratoDepth", "ddsp.warmth.drive"
    ]

    // MARK: - Claim 1 — the catalog states its domain, and states it honestly

    /// END-TO-END. Every descriptor in the audio catalog is `.audio`. Scoped to the
    /// CATALOG on purpose — see the #364 note in the header.
    func testEveryDDSPDescriptorIsAudioDomain() {
        XCTAssertFalse(DDSPParameterCatalog.descriptors.isEmpty,
                       "`DDSPParameterCatalog.descriptors` is empty — claim 1 would then be "
                       + "vacuously true. An empty list is a finding, never a pass (#454).")
        for d in DDSPParameterCatalog.descriptors {
            XCTAssertEqual(
                d.domain, .audio,
                "`\(d.keyPath)` is in the DDSP catalog — the synth engine's own parameters — "
                + "but reports domain `\(d.domain.rawValue)`. Either the descriptor is "
                + "mis-declared, or a non-audio parameter was filed in the audio catalog. "
                + "A non-audio parameter belongs in its own catalog with its own domain; it "
                + "does not belong here with the wrong one.")
        }
    }

    /// COUNTERWEIGHT. The vocabulary is real and closed: four cases, round-trippable as the
    /// raw strings a future payload would carry.
    func testTheDomainVocabularyIsTheFourMeasuredMedia() {
        XCTAssertEqual(Set(ParameterDomain.allCases.map(\.rawValue)),
                       ["audio", "visual", "lighting", "spatial"],
                       "`ParameterDomain`'s case set changed. Adding a case is additive and "
                       + "fine — update this set in the same commit and say which egress stage "
                       + "the new medium has. REMOVING or RENAMING one is not: the raw value is "
                       + "what a persisted descriptor would carry, so a rename is a migration.")
        XCTAssertEqual(ParameterDomain(rawValue: "audio"), .audio,
                       "`ParameterDomain.audio`'s raw value is no longer \"audio\" — the "
                       + "default every existing descriptor decodes to would change meaning.")
    }

    // MARK: - Claim 2 — the persisted identity did not move

    /// END-TO-END. Every keyPath a saved automation curve or modulation route may name is
    /// still described, byte-for-byte. Membership, not a count (#818/#364) — the catalog may
    /// grow.
    func testTheDDSPKeyPathsAreUnchanged() {
        let present = Set(DDSPParameterCatalog.descriptors.map(\.keyPath))
        for kp in Self.knownDDSPKeyPaths {
            XCTAssertTrue(
                present.contains(kp),
                "`\(kp)` is no longer described by `DDSPParameterCatalog`. That string is the "
                + "PERSISTED identity of an automation target and of a modulation route "
                + "(`ModRoute` stores its destination as a plain String). Dropping or renaming "
                + "it orphans every saved curve that names it. The domain slice must not have "
                + "touched a keyPath.")
        }
    }

    // MARK: - Claims 3 & 4 — lookup and ordering are what they were

    /// END-TO-END. Lookup is by keyPath and returns the same descriptor the catalog holds.
    func testRegistryLookupIsUnchanged() {
        let registry = EchoelParameterRegistry()
        registry.register(DDSPParameterCatalog.descriptors)
        for d in DDSPParameterCatalog.descriptors {
            let found = registry.descriptor(for: d.keyPath)
            XCTAssertEqual(found, d,
                           "`descriptor(for: \"\(d.keyPath)\")` no longer returns the registered "
                           + "descriptor. Lookup is the one thing `ParameterApplyRouter` needs "
                           + "before it can denormalize; a miss there makes `applyNormalized` "
                           + "return nil and the control moves nothing.")
        }
        XCTAssertNil(registry.descriptor(for: "ddsp.osc.frequency.NOPE"),
                     "an unknown keyPath now resolves. Lookup must stay exact-match — a fuzzy "
                     + "hit would apply one parameter's value to another's range.")
    }

    /// END-TO-END. `all()` preserves insertion order, and re-registering REPLACES in place
    /// rather than appending. Order is what a picker renders.
    func testRegistryOrderingIsUnchanged() {
        let registry = EchoelParameterRegistry()
        registry.register(DDSPParameterCatalog.descriptors)
        XCTAssertEqual(registry.all().map(\.keyPath),
                       DDSPParameterCatalog.descriptors.map(\.keyPath),
                       "`all()` no longer returns catalog order. Any target picker built on it "
                       + "reorders itself, and a user's muscle memory with it.")
        registry.register(DDSPParameterCatalog.descriptors)
        XCTAssertEqual(registry.all().map(\.keyPath),
                       DDSPParameterCatalog.descriptors.map(\.keyPath),
                       "re-registering the same catalog changed `all()`. `register` must REPLACE "
                       + "by keyPath keeping position — its own doc says so, and a duplicate "
                       + "would render the same parameter twice in a ForEach keyed by the key.")
    }

    // MARK: - Claim 5 — the automatable set is still registry ∩ bound setter

    /// END-TO-END. Binds the eleven automatable bases to inert setters and checks that
    /// `automatableDescriptors()` returns exactly those, in REGISTRY order — the Placebo law.
    /// (Inert setters, not a real voice: this bundle never starts audio.)
    ///
    /// ⚠️ SINCE P2 PROOF #1.1 THE SET IS registry ∩ bound ∩ `automationEligible`, and this
    /// claim is unchanged BECAUSE the eligible set is derived from `PolySynthVoice
    /// .automatableBases` — the same list this fixture binds. That agreement is the point: the
    /// repair made a previously implicit rule explicit without moving which parameters it
    /// names. If this ever goes red, the eligible set and the bind list have parted company.
    func testAutomatableDescriptorsCountAndOrderAreUnchanged() {
        let registry = EchoelParameterRegistry()
        registry.register(DDSPParameterCatalog.descriptors)
        let router = ParameterApplyRouter(registry: registry)
        XCTAssertTrue(router.automatableDescriptors().isEmpty,
                      "`automatableDescriptors()` is non-empty with NOTHING bound. It must be "
                      + "registry ∩ bound setter; a descriptor offered without a setter is a "
                      + "control that lies (#164/#227).")
        for base in PolySynthVoice.automatableBases { router.bind(base) { _ in } }
        let automatable = Set(PolySynthVoice.automatableBases)
        let expected = DDSPParameterCatalog.descriptors
            .map(\.keyPath)
            .filter { automatable.contains($0) }
        XCTAssertEqual(router.automatableDescriptors().map(\.keyPath), expected,
                       "`automatableDescriptors()` no longer returns the bound subset in "
                       + "registry order. `EchoelmusicApp` registers one modulation destination "
                       + "per element of this list, so a change here silently changes which "
                       + "destinations exist and in what order the matrix offers them.")
        XCTAssertEqual(expected.count, PolySynthVoice.automatableBases.count,
                       "a base in `PolySynthVoice.automatableBases` is not described by "
                       + "`DDSPParameterCatalog`, so it binds a setter and still cannot be "
                       + "denormalized — `applyNormalized` returns nil for it.")
    }

    // MARK: - Claim 6 — apply semantics are what they were

    /// END-TO-END. 0 → min, 1 → max, out-of-range clamps, unknown key is a nil no-op, and
    /// `applyReal` still bypasses the descriptor range entirely.
    func testParameterApplyRouterBehaviourIsUnchanged() {
        let registry = EchoelParameterRegistry()
        registry.register(DDSPParameterCatalog.descriptors)
        let router = ParameterApplyRouter(registry: registry)
        var seen: [Float] = []
        router.bind("ddsp.filter.cutoff") { seen.append($0) }

        XCTAssertEqual(router.applyNormalized("ddsp.filter.cutoff", 0), 20,
                       "normalized 0 no longer maps to the descriptor minimum.")
        XCTAssertEqual(router.applyNormalized("ddsp.filter.cutoff", 1), 18_000,
                       "normalized 1 no longer maps to the descriptor maximum.")
        XCTAssertEqual(router.applyNormalized("ddsp.filter.cutoff", -5), 20,
                       "an out-of-range normalized value no longer clamps. The clamp is the "
                       + "safety rail that keeps a planner or a route inside the range.")
        XCTAssertEqual(router.applyNormalized("ddsp.filter.cutoff", 9), 18_000,
                       "an out-of-range normalized value no longer clamps at the top.")
        XCTAssertNil(router.applyNormalized("no.such.parameter", 0.5),
                     "an unbound keyPath no longer returns nil. A silent no-op is the designed "
                     + "behaviour for a persisted route naming a key this build does not have.")
        XCTAssertEqual(seen.count, 4,
                       "the setter fired a different number of times than the four in-range "
                       + "applies above — the unknown key must NOT reach any setter.")

        XCTAssertTrue(router.applyReal("ddsp.filter.cutoff", 99_999),
                      "`applyReal` no longer reports success for a bound key.")
        XCTAssertEqual(seen.last, 99_999,
                       "`applyReal` no longer bypasses the descriptor range. That bypass is "
                       + "deliberate — it is the path a UI field with its own clamp takes — and "
                       + "changing it here would change what a typed value does.")
    }

    // MARK: - Claim 7 — the tempo's bespoke route is untouched

    /// SOURCE-TEXT SCAN. The tempo destination keeps the BPM-lock veto, the octave fold and
    /// the glide (T1/T2). A domain field must not have tempted anyone into folding the tempo
    /// into the generic path.
    func testTheTempoSpecialRouteIsUnchanged() throws {
        let src = SourceText.codeOnly(try text(Self.app))
        for needle in ["modulationEngine.register(ModDestinationKey.tempo)",
                       "studio.lockBPM",
                       "StudioCalculator.seedTempo",
                       "source: .modulationRoute"] {
            XCTAssertTrue(
                src.contains(needle),
                "`\(needle)` is gone from `EchoelmusicApp`'s tempo registration. That handler "
                + "is T1/T2 in CLAUDE.md: the user's BPM lock wins globally, the target is "
                + "octave-folded so a normalized signal cannot demand an absurd tempo, and the "
                + "clock GLIDES rather than snapping. A generic `applyNormalized` in its place "
                + "would delete all three.")
        }
    }

    // MARK: - Claim 8 — no modulation destination changed

    /// END-TO-END. `ModDestinationKey.all` is still the tempo plus the automatable bases —
    /// a projection, not a copy. A destination key is persisted inside `ModRoute`.
    func testNoModDestinationKeyChanged() {
        XCTAssertEqual(ModDestinationKey.all.count,
                       1 + PolySynthVoice.automatableBases.count,
                       "`ModDestinationKey.all` is no longer the tempo plus "
                       + "`PolySynthVoice.automatableBases`. It must stay a PROJECTION of that "
                       + "list (#1391/#416); a hand-written copy drifts, and each key is the "
                       + "persisted destination string of a saved route.")
        XCTAssertEqual(ModDestinationKey.tempo, "seq.tempo",
                       "the tempo destination's persisted string changed. Every route a user "
                       + "saved onto the tempo names the old one and would apply nothing.")
        for base in PolySynthVoice.automatableBases {
            XCTAssertTrue(ModDestinationKey.all.contains(base),
                          "`\(base)` has a live setter but is no longer offered as a modulation "
                          + "destination — the half-join #1391 removed.")
        }
    }

    // MARK: - Claim 9 — the blast radius did not leak into persistence

    /// SOURCE-TEXT SCAN. Neither the modulation matrix nor the automation lane mentions
    /// `ParameterDomain`. This slice adds a field to a parameter's IDENTITY; the moment a
    /// route or a lane carries it, it becomes a persistence change and needs a migration.
    func testTheDomainDidNotReachRouteOrLanePersistence() throws {
        for path in [Self.matrix, Self.automationLane] {
            let src = SourceText.codeOnly(try text(path))
            XCTAssertFalse(
                src.contains("ParameterDomain"),
                "`\(path)` now references `ParameterDomain`. `ModRoute` and `AutomationLane` are "
                + "PERSISTED; storing a domain in either turns a parameter-identity change into "
                + "a document-format change, and an older build would then decode a payload it "
                + "does not understand. The domain belongs to the DESCRIPTOR — the in-memory "
                + "description of a parameter — not to a saved route or curve. If a route "
                + "genuinely needs the domain, it should LOOK IT UP from the registry by "
                + "keyPath, never copy it into its own storage.")
        }
    }

    // MARK: - Claim 10 — backward decode, the invisible break

    /// END-TO-END. A payload written before this field existed must still decode, and must
    /// land on `.audio`. Swift's SYNTHESIZED `init(from:)` would throw `keyNotFound` here —
    /// the stored property's default is NOT a decode fallback. That is why the decoder is
    /// hand-written, and this is the claim that proves it.
    func testADescriptorWithoutADomainStillDecodesAsAudio() throws {
        let legacy = """
        {"keyPath":"ddsp.filter.cutoff","displayName":"Filter cutoff",\
        "min":20,"max":18000,"defaultValue":220,"unit":"Hz"}
        """
        let decoded = try JSONDecoder().decode(ParameterDescriptor.self,
                                               from: Data(legacy.utf8))
        XCTAssertEqual(decoded.domain, .audio,
                       "a descriptor payload written before `domain` existed no longer decodes "
                       + "to `.audio`.")
        XCTAssertEqual(decoded.keyPath, "ddsp.filter.cutoff")
        XCTAssertEqual(decoded.max, 18_000)

        let unknown = """
        {"keyPath":"x.y","displayName":"X","min":0,"max":1,"defaultValue":0,\
        "unit":"","domain":"olfactory"}
        """
        let tolerant = try JSONDecoder().decode(ParameterDescriptor.self,
                                                from: Data(unknown.utf8))
        XCTAssertEqual(tolerant.domain, .audio,
                       "a domain string this build does not know now THROWS instead of falling "
                       + "back to `.audio`. A newer build's payload must not make an older one "
                       + "fail to open a document — that is the `decodeIfPresent ?? default` "
                       + "discipline `Sync/LightFixtureGroup` already follows.")

        let round = ParameterDescriptor(keyPath: "light.dimmer", displayName: "Dimmer",
                                        min: 0, max: 1, defaultValue: 0, domain: .lighting)
        let back = try JSONDecoder().decode(ParameterDescriptor.self,
                                            from: JSONEncoder().encode(round))
        XCTAssertEqual(back, round,
                       "a non-audio descriptor no longer survives a round-trip. `encode(to:)` "
                       + "must still write `domain` — if it stops, every descriptor reads back "
                       + "as `.audio` and the field is decorative.")
    }

    // MARK: - Claim 11 — the per-track clone inherits the domain

    /// END-TO-END. `PerTrackParameterKeyPath.descriptors(for:laneLabel:from:)` rebuilds a
    /// descriptor field by field, so a field it forgets silently reverts to the init default.
    func testThePerTrackCloneInheritsTheDomain() {
        let lane = UUID()
        let source = ParameterDescriptor(keyPath: "light.dimmer", displayName: "Dimmer",
                                         min: 0, max: 1, defaultValue: 0, domain: .lighting)
        let clones = PerTrackParameterKeyPath.descriptors(for: lane, laneLabel: "Rig",
                                                          from: [source])
        XCTAssertEqual(clones.count, 1)
        XCTAssertEqual(
            clones.first?.domain, .lighting,
            "the per-track clone dropped the domain and fell back to `.audio`. That function "
            + "rebuilds the descriptor field by field, so a forgotten field does not fail to "
            + "compile — it silently produces a descriptor that LIES about its medium while "
            + "still building and still routing. Pass `domain: d.domain` explicitly.")
        XCTAssertEqual(
            clones.first?.automationEligible, source.automationEligible,
            "the per-track clone dropped `automationEligible`. It defaults to FALSE, so a "
            + "forgotten field here silently REVOKES automation from a per-track lane rather "
            + "than mislabelling it — no compile error, no red test at the call site.")
        XCTAssertEqual(clones.first?.modulationEligible, source.modulationEligible,
                       "the per-track clone dropped `modulationEligible` (see above).")
        let eligible = ParameterDescriptor(keyPath: "ddsp.env.attack", displayName: "A",
                                           min: 0, max: 1, defaultValue: 0,
                                           automationEligible: true, modulationEligible: true)
        let eligibleClone = PerTrackParameterKeyPath.descriptors(for: lane, laneLabel: "T",
                                                                 from: [eligible]).first
        XCTAssertEqual(eligibleClone?.automationEligible, true,
                       "an ELIGIBLE source cloned to an ineligible per-track descriptor. The "
                       + "two assertions above would be green on a clone that hard-codes false, "
                       + "because the lighting source they use is denied anyway (#367).")
        XCTAssertEqual(eligibleClone?.modulationEligible, true,
                       "an ELIGIBLE source lost `modulationEligible` in the clone.")
        XCTAssertEqual(clones.first?.max, source.max,
                       "the clone no longer inherits the range — it is the SAME engine "
                       + "parameter, only addressed per track.")
        XCTAssertEqual(PerTrackParameterKeyPath.parse(clones.first?.keyPath ?? "")?.base,
                       "light.dimmer",
                       "the clone's keyPath no longer parses back to the base keyPath.")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
