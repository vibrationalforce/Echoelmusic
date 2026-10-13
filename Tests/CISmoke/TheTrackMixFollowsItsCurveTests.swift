//
//  TheTrackMixFollowsItsCurveTests.swift
//  Production level A1a/A1b (founder 2026-10-13: „… automation etc …"). Song automation reached only
//  eleven synth parameters on a poly rack track; no track could fade or pan over time. A track's
//  volume and pan now have curves (`track.<id>.mix.gain` / `.mix.pan`), and every sounding rack slot
//  follows them once per transport step.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–3) — `TimelineDocument` and `MultiRollFanout` are shipped and
//    pure. Claim 1: the volume curve multiplies the fader (a fade, never a boost); no curve leaves
//    the fader alone; mute and foreign solo still silence; the note-on gate (`effectiveGain`) does
//    not move with the curve. Claim 2: the pan curve maps 0…1 to −1…1 and replaces the lane's pan;
//    no curve keeps the lane's pan. Claim 3: the rack's tick-aware gain and pan ask the same rule,
//    and an unknown slot is unity and centre.
//  · SOURCE-TEXT SCAN (claim 4) — `TimelineRegionPlayer` is driven by an engine-bound transport:
//    every slot gain/pan push in the player goes through `pushSlotMix` (the audition's stopped-only
//    bind is the one other site), and the step follows the curves after it sets `currentTick`.
//  · DEVICE PROBE, OPEN — that a fade sounds smooth enough at step rate: NEEDS-FOUNDER-VERIFY A1
//    at `TimelineDocument.automatedGain`. The Echoel track and audio tracks are A1c/A1d, not here.
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — `automatedGain`,
//  `automatedPan`, `mixGainBase` and the `atTick:` overloads are created by this commit — so no
//  assertion has a verdict on the parent (ONE absence, #486). Claims 1–3 are forward guards
//  transcribed by reading the three functions and `AutomationLane.value(atTick:)`; claim 4's
//  needles were grepped against the worktree. COUNTERWEIGHTS (#343): no-curve, mute, the gate.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheTrackMixFollowsItsCurveTests: XCTestCase {

    private static let playerPath = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"
    private static let bar = 16 * Note.ticksPerStep

    private static func curve(_ lane: TimelineLane, _ base: String, from a: Double, to b: Double) -> AutomationLane {
        AutomationLane(parameter: PerTrackParameterKeyPath.make(laneID: lane.id, base: base),
                       points: [AutomationPoint(tick: 0, value: a), AutomationPoint(tick: bar, value: b)])
    }

    // MARK: 1 — the volume curve is a fade over the fader

    func testTheVolumeCurveFadesTheFader() {
        let lane = TimelineLane(name: "Keys", kind: .midi, level: 0.8)
        let other = TimelineLane(name: "Pad", kind: .midi)
        var doc = TimelineDocument(lanes: [lane, other], regions: [],
                                   automation: [Self.curve(lane, TimelineDocument.mixGainBase, from: 0, to: 1)])
        XCTAssertEqual(doc.automatedGain(for: lane.id, atTick: 0), 0, accuracy: 1e-6)
        XCTAssertEqual(doc.automatedGain(for: lane.id, atTick: Self.bar / 2), 0.4, accuracy: 1e-6, "half the curve × the fader")
        XCTAssertEqual(doc.automatedGain(for: lane.id, atTick: Self.bar), 0.8, accuracy: 1e-6, "never past the fader")
        // COUNTERWEIGHTS
        XCTAssertEqual(doc.automatedGain(for: other.id, atTick: Self.bar / 2), doc.effectiveGain(for: other.id),
                       "no curve: the fader alone")
        XCTAssertEqual(doc.effectiveGain(for: lane.id), 0.8, accuracy: 1e-6,
                       "the note-on gate does not follow the curve — a fade-in from 0 still starts its notes")
        doc.lanes[0].isMuted = true
        XCTAssertEqual(doc.automatedGain(for: lane.id, atTick: Self.bar), 0, "mute still wins")
    }

    // MARK: 2 — the pan curve replaces the lane's pan

    func testThePanCurveMapsAcrossTheField() {
        let lane = TimelineLane(name: "Keys", kind: .midi, pan: 0.3)
        let plain = TimelineLane(name: "Pad", kind: .midi, pan: -0.5)
        let doc = TimelineDocument(lanes: [lane, plain], regions: [],
                                   automation: [Self.curve(lane, TimelineDocument.mixPanBase, from: 0, to: 1)])
        XCTAssertEqual(doc.automatedPan(for: lane.id, atTick: 0), -1, accuracy: 1e-6)
        XCTAssertEqual(doc.automatedPan(for: lane.id, atTick: Self.bar / 2), 0, accuracy: 1e-6)
        XCTAssertEqual(doc.automatedPan(for: lane.id, atTick: Self.bar), 1, accuracy: 1e-6)
        XCTAssertEqual(doc.automatedPan(for: plain.id, atTick: Self.bar / 2), -0.5, accuracy: 1e-6, "no curve: the lane's pan")
    }

    // MARK: 3 — the rack asks the same rule

    func testTheRackAsksTheSameRule() {
        let echoel = TimelineLane(name: "Echoel", kind: .midi)
        let keys = TimelineLane(name: "Keys", kind: .midi, level: 0.5)
        let doc = TimelineDocument(lanes: [echoel, keys], regions: [],
                                   automation: [Self.curve(keys, TimelineDocument.mixGainBase, from: 1, to: 0),
                                                Self.curve(keys, TimelineDocument.mixPanBase, from: 1, to: 1)])
        let tick = Self.bar / 4
        XCTAssertEqual(MultiRollFanout.gain(forSlot: 0, in: doc, rollLane: doc.rollLaneID, atTick: tick),
                       doc.automatedGain(for: keys.id, atTick: tick))
        XCTAssertEqual(MultiRollFanout.pan(forSlot: 0, in: doc, rollLane: doc.rollLaneID, atTick: tick), 1)
        XCTAssertEqual(MultiRollFanout.gain(forSlot: 7, in: doc, rollLane: doc.rollLaneID, atTick: tick), 1,
                       "unknown slot: unity, never silence on a mapping gap")
        XCTAssertEqual(MultiRollFanout.pan(forSlot: 7, in: doc, rollLane: doc.rollLaneID, atTick: tick), 0)
    }

    // MARK: 4 — the player follows the curves once per step

    func testThePlayerPushesEverySlotMixThroughOneHelper() throws {
        let code = SourceText.codeOnly(try source(Self.playerPath))
        XCTAssertEqual(code.components(separatedBy: "slotGainSink?(").count - 1, 2,
                       "pushSlotMix and the stopped-only audition bind — no third gain push")
        XCTAssertEqual(code.components(separatedBy: "slotPanSink?(").count - 1, 2)
        XCTAssertTrue(code.contains("MultiRollFanout.gain(forSlot: slot, in: doc, rollLane: rollLane, atTick: currentTick)"))
        XCTAssertTrue(code.contains("        currentTick = newTick\n        followMixAutomation()"),
                      "the step follows the curves right after it sets currentTick")
    }

    private func source(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        let file = url.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("\(relative) not on disk — this run has no source tree")
        }
        return try String(contentsOf: file, encoding: .utf8)
    }
}
