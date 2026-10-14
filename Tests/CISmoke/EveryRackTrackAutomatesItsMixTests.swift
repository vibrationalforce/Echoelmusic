//
//  EveryRackTrackAutomatesItsMixTests.swift
//  Production level A1c (founder 2026-10-13: „… automation etc …"). The Automation page existed only
//  on a POLY rack track and listed only synth parameters. Every rack track now offers its own
//  Volume, and Pan where its voice honours pan; a poly track keeps its synth parameters after them.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–3) — `SongAutomationEdit` and `TrackMix` are shipped and pure.
//    Claim 1: a poly track offers Volume, Pan, then the synth projection; a Sampler track Volume
//    alone (`TrackMix.controls` says it has no pan — the one truth, #416), and no synth parameter.
//    Claim 2, COUNTERWEIGHTS: the Echoel track and a rack with no room offer nothing and draw no
//    row (the Echoel level shapes new notes only — no live fader yet); an audio track (A1d)
//    offers exactly Volume and Pan. Claim 3: the
//    Volume curve's readout names the track and the parameter, and the two mix descriptors are
//    NOT in the parameter catalog, so the router can never apply them a second time.
//  · DEVICE PROBE, OPEN — the A1 ask at `TimelineDocument.automatedGain`.
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there —
//  `parameters(on:)`, `mixVolume` and `mixPan` are created by this commit — so no assertion has a
//  verdict on the parent (ONE absence, #486). All claims are forward guards transcribed by reading
//  `parameters(on:)`, `TrackMix.role/controls` and `statusScale`.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class EveryRackTrackAutomatesItsMixTests: XCTestCase {

    private static let echoel = TimelineLane(name: "Echoel", kind: .midi)
    private static let keys = TimelineLane(name: "Keys", kind: .midi)
    private static let hits = TimelineLane(name: "Hits", kind: .midi, builtinInstrument: .sampler)
    private static let tape = TimelineLane(name: "Tape", kind: .audio)
    private static var document: TimelineDocument {
        TimelineDocument(lanes: [echoel, keys, hits, tape], regions: [])
    }

    // MARK: 1 — what each rack track offers

    func testEachRackTrackOffersItsOwnMix() {
        let doc = Self.document
        let poly = SongAutomationEdit.parameters(on: Self.keys.id, in: doc, voiceCapacity: 4).map(\.keyPath)
        XCTAssertEqual(Array(poly.prefix(2)), [TimelineDocument.mixGainBase, TimelineDocument.mixPanBase])
        XCTAssertEqual(Array(poly.dropFirst(2)), SongAutomationEdit.offered.map(\.keyPath),
                       "a poly track keeps the synth projection after its mix")

        XCTAssertEqual(TrackMix.role(of: Self.hits.id, in: doc, voiceCapacity: 4), .laneSynth(.sampler),
                       "premise: the Sampler track plays on the rack")
        let sampler = SongAutomationEdit.parameters(on: Self.hits.id, in: doc, voiceCapacity: 4).map(\.keyPath)
        let controls = TrackMix.controls(of: Self.hits.id, in: doc, voiceCapacity: 4)
        XCTAssertEqual(sampler.contains(TimelineDocument.mixPanBase), controls?.pan ?? true,
                       "Pan is offered exactly where the mixer offers pan")
        XCTAssertTrue(sampler.contains(TimelineDocument.mixGainBase))
        XCTAssertFalse(sampler.contains(SongAutomationEdit.defaultBase), "no synth parameter on a Sampler")
        XCTAssertTrue(SongAutomationEdit.sounds(on: Self.hits.id, in: doc, voiceCapacity: 4))
    }

    // MARK: 2 — counterweights

    func testTracksWhoseMixDoesNotFollowACurveOfferNothing() {
        let doc = Self.document
        XCTAssertTrue(SongAutomationEdit.parameters(on: Self.echoel.id, in: doc, voiceCapacity: 4).isEmpty,
                      "the Echoel track's level shapes new notes only — a curve there would mislead")
        XCTAssertFalse(SongAutomationEdit.sounds(on: Self.echoel.id, in: doc, voiceCapacity: 4))
        // A1d: an audio track's mix follows its curve, so it offers Volume and Pan — nothing else.
        XCTAssertEqual(SongAutomationEdit.parameters(on: Self.tape.id, in: doc, voiceCapacity: 4).map(\.keyPath),
                       [TimelineDocument.mixGainBase, TimelineDocument.mixPanBase])
        XCTAssertTrue(SongAutomationEdit.parameters(on: Self.keys.id, in: doc, voiceCapacity: 0).isEmpty,
                      "no rack, no voice to follow the curve")
    }

    // MARK: 3 — the readout names it, and the router never sees it

    func testTheReadoutNamesTheVolumeAndTheRouterCannotApplyIt() throws {
        let doc = Self.document
        let key = SongAutomationEdit.key(for: Self.keys.id, base: TimelineDocument.mixGainBase)
        let scale = try XCTUnwrap(SongAutomationEdit.statusScale(key, in: doc, voiceCapacity: 4))
        XCTAssertTrue(scale.displayName.hasPrefix("Keys · "), scale.displayName)
        for d in [SongAutomationEdit.mixVolume, SongAutomationEdit.mixPan] {
            XCTAssertFalse(DDSPParameterCatalog.descriptors.contains { $0.keyPath == d.keyPath },
                           "\(d.keyPath) in the catalog would let AutomationPlayer apply it a second time")
        }
        XCTAssertEqual(SongAutomationEdit.realValue(0.5, of: SongAutomationEdit.mixPan), 0, accuracy: 1e-6,
                       "the stored middle reads as centre, the value playback uses")
    }
}
