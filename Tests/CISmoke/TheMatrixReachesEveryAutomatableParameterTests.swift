// TheMatrixReachesEveryAutomatableParameterTests.swift
// Echoel — #1391. The body may now move every parameter a control source is allowed to own,
// not just the tempo.
//
// ⭐ WHY THIS FILE EXISTS. `EchoelParameterRegistry` has described fifteen DDSP parameters
// since the EchoelAI N2 cycle, and `ParameterApplyRouter` has dispatched eleven of them to
// live setters since the automation cycle. `ModDestinationKey.all` — the ONE list the
// modulation matrix offers — read `[tempo]`. The intersection of "what the body can reach"
// and "what the engine can move" was a single element, while the product line says the body
// plays the instrument. Nothing was broken; the two halves had simply never been joined.
//
// THE JOIN IS A PROJECTION, NOT A SECOND LIST (#416). `all` is now
// `[tempo] + PolySynthVoice.automatableBases`, and the REGISTRATIONS in `EchoelmusicApp` are
// derived at runtime from `ParameterApplyRouter.modulatableDescriptors()` — registry ∩ bound
// setter ∩ `modulationEligible` since P2 Proof #1.1. So the offered set cannot drift from the
// movable set by editing one of them, and a parameter made merely DISPATCHABLE does not join
// the matrix as a side effect of being bound.
//
// ⚠️ THE HAZARD THIS GUARD EXISTS FOR IS CLAIM 4, AND IT IS NOT OBVIOUS FROM THE DIFF. The
// tempo keeps a BESPOKE handler: it refuses to move while the BPM lock is on, octave-folds its
// target and GLIDES (T1/T2 in CLAUDE.md, source `.modulationRoute`). The new loop calls
// `modulationEngine.register(_:)`, whose own doc says "re-registering a key REPLACES it". So
// the day someone adds a tempo-shaped key to `automatableBases`, the loop silently overwrites
// the lock/fold/glide handler with a raw `applyNormalized` — a tempo invariant deleted by an
// edit in a different file that mentions neither the tempo nor the lock.
//
// ⚠️ IT FORBIDS NO DESTINATION (#364). Every claim here is a RELATIONSHIP — the offered set
// equals the movable set, each offered key can be denormalized, the tempo keeps its own
// handler — so the list may grow or shrink freely and these stay true. What goes red is a
// half-join: a key offered that nothing moves, or a key moved that nothing offers.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — every assertion transcribed in Python
// and driven against BOTH trees. On the parent (`07adb94`) the reds are claims 1, 5 and 6, and
// they are THREE findings (#486): the join did not exist (claim 1, one assertion per base),
// nothing registered the synth keys (claim 5, two assertions — the loop is absent, so "after the
// bind" is vacuous), and the card still counted one destination (claim 6). Claims 2, 3 and 4 are
// COUNTERWEIGHTS (#343), green on both trees. Claims 1–3 are END-TO-END — `ModDestinationKey`
// and `PolySynthVoice.automatableBases` are `public`/`nonisolated`, so the bundle really calls
// them; claims 4–6 are SOURCE-TEXT scans, because the wiring they check lives inside a SwiftUI
// `body` this bundle cannot evaluate.
//
// ⚠️ DEVICE PROBE, OPEN. Whether a route onto "Warmth drive" is AUDIBLE is an ear question and
// stays with the founder — the `NEEDS-FOUNDER-VERIFY` note at `modulationSection` carries it.
// Nothing here plays anything.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheMatrixReachesEveryAutomatableParameterTests: XCTestCase {

    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let patchbay = "Sources/Echoelmusic/Studio/PatchbayView.swift"

    /// Claim 1 — the join itself: every parameter a control source may own is offered to the
    /// body. This is the finding, stated as the relationship rather than as a count (#818).
    func testEveryAutomatableParameterIsAModulationDestination() {
        let offered = Set(ModDestinationKey.all)
        XCTAssertFalse(PolySynthVoice.automatableBases.isEmpty,
                       "`automatableBases` is empty — claim 1 would then be vacuously true. "
                       + "An empty list is a finding, never a pass (#454).")
        for base in PolySynthVoice.automatableBases {
            XCTAssertTrue(
                offered.contains(base),
                "`\(base)` has a live setter (it is in `PolySynthVoice.automatableBases`, so "
                + "`bindAutomatable` binds it and a drawn automation lane moves it) but the "
                + "modulation matrix does not offer it. The body can then reach a parameter the "
                + "pencil can — that asymmetry is what #1391 removed. `ModDestinationKey.all` "
                + "must stay a projection of that list, not a copy of it.")
        }
    }

    /// Claim 2 — COUNTERWEIGHT: the tempo did not fall out of the list while the synth keys
    /// were added. It is the destination every other guard, the card's copy and the founder's
    /// verify note name.
    func testTheTempoIsStillOffered() {
        XCTAssertTrue(ModDestinationKey.all.contains(ModDestinationKey.tempo),
                      "the tempo left `ModDestinationKey.all` — it is the one destination with "
                      + "a bespoke handler and the one the verify note probes.")
        XCTAssertEqual(ModDestinationKey.all.count, Set(ModDestinationKey.all).count,
                       "`ModDestinationKey.all` contains a DUPLICATE. The Add-route menu is a "
                       + "`ForEach(..., id: \\.self)`, so a repeated key renders twice and "
                       + "SwiftUI's identity is ambiguous between the two rows.")
    }

    /// Claim 3 — the PLACEBO law, inherited rather than re-stated: a key the matrix offers must
    /// be denormalizable, or `applyNormalized` returns nil and the route moves nothing. The
    /// tempo is exempt — its handler takes the raw 0…1 and does its own mapping.
    func testEveryOfferedSynthKeyCanBeDenormalized() {
        let described = Set(DDSPParameterCatalog.descriptors.map(\.keyPath))
        for key in ModDestinationKey.all where key != ModDestinationKey.tempo {
            XCTAssertTrue(
                described.contains(key),
                "the matrix offers `\(key)`, but `DDSPParameterCatalog` describes no such "
                + "parameter. `ParameterApplyRouter.applyNormalized` needs the descriptor to "
                + "turn the engine's 0…1 into a real value; without one it returns nil and the "
                + "row is a control that lies. Add the descriptor in the same commit as the key.")
        }
    }

    /// Claim 4 — THE HAZARD (see the header). The tempo's bespoke registration survives, and no
    /// tempo-shaped key hides in the list the loop re-registers from.
    func testTheTempoKeepsItsOwnHandler() throws {
        let src = SourceText.codeOnly(try text(Self.app))
        XCTAssertTrue(
            src.contains("modulationEngine.register(ModDestinationKey.tempo)"),
            "the tempo's own registration is gone from `EchoelmusicApp`. It carries the BPM-lock "
            + "guard, the octave fold and the glide (T1/T2); a generic `applyNormalized` "
            + "registration in its place would let a body route SNAP a locked clock.")
        XCTAssertFalse(
            PolySynthVoice.automatableBases.contains(ModDestinationKey.tempo),
            "`\(ModDestinationKey.tempo)` is in `automatableBases`, so the registration loop "
            + "re-registers it — and `ModulationEngine.register` REPLACES. The bespoke tempo "
            + "handler above would be overwritten by a raw denormalize, deleting the BPM lock "
            + "from the modulation path. If the tempo really should be router-driven, move the "
            + "lock/fold/glide INTO its setter first, then retire this assertion.")
    }

    /// Claim 5 — ORDER, and it fails silently. The registration loop reads a SNAPSHOT of the
    /// router, so a loop that runs BEFORE `bindAutomatable` iterates an empty sequence: zero
    /// registrations, zero errors, a full picker and not one working row.
    ///
    /// ⚠️ THIS IS THE ORDER THAT IS STILL LOAD-BEARING, AND IT IS THE OPPOSITE OF THE ONE
    /// P2 PROOF #1.1 RETIRED. That slice removed order as a way to WITHHOLD a capability
    /// (lighting was kept out of modulation by being bound after the loop — now it is kept out
    /// by saying so on its descriptor). It did not, and could not, remove order as a
    /// precondition for GRANTING one: a filter over an empty set is empty whatever it filters
    /// on. Bind first, then register — that has always been the requirement and still is.
    func testTheRegistrationLoopRunsAfterTheSettersAreBound() throws {
        let src = SourceText.codeOnly(try text(Self.app))
        guard let bind = src.range(of: "polyVoice.bindAutomatable(into: parameterRouter)") else {
            return XCTFail("ANCHOR MISSING: `bindAutomatable` is not called in `EchoelmusicApp` — "
                           + "nothing binds the synth setters, so every synth row in the matrix "
                           + "is dead (#454: a missing anchor is a finding, not a pass).")
        }
        guard let loop = src.range(of: "parameterRouter.modulatableDescriptors()") else {
            return XCTFail("`EchoelmusicApp` never reads `modulatableDescriptors()` — the synth "
                           + "keys are OFFERED by `ModDestinationKey.all` and REGISTERED by "
                           + "nothing, so every one of them is a row that moves no audio. "
                           + "(P2 Proof #1.1 renamed this read from `automatableDescriptors()`; "
                           + "if it moved again, re-anchor here in the same commit, §4.)")
        }
        XCTAssertTrue(bind.lowerBound < loop.lowerBound,
                      "the registration loop reads `modulatableDescriptors()` BEFORE "
                      + "`bindAutomatable` has bound the setters. That set is registry ∩ bound "
                      + "setter ∩ eligible, so it is empty there — the loop registers nothing "
                      + "and says so in no log. Move the loop below the bind.")
    }

    /// Claim 6 — COUNTERWEIGHT: the card's first-run copy moved with the list (#456). Nothing in
    /// production constructs a `ModRoute`, so the empty state IS what a player reads.
    func testTheEmptyStateNoLongerOffersASingleDestination() throws {
        let src = SourceText.codeOnly(try text(Self.patchbay))
        XCTAssertTrue(src.contains("No routes yet."),
                      "ANCHOR MISSING: the empty state is gone (#454).")
        XCTAssertFalse(
            src.contains("This build offers one: the tempo."),
            "the Body → parameter card still tells a first-run player that this build offers ONE "
            + "destination. Since #1391 it offers the tempo plus every automatable sound "
            + "parameter. Reword freely — what this assertion forbids is the old sentence "
            + "outliving the list it counted.")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
