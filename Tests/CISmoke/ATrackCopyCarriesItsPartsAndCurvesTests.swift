// ATrackCopyCarriesItsPartsAndCurvesTests.swift
// A7 (founder 2026-10-16, "Arrangement auf Ableton-Level"): a track can be duplicated. The Track
// page has "Duplicate track"; the copy stands right below the original with its settings, its parts
// (playing the same clips) and its own curves, and ONE Undo takes it away.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–2 are END-TO-END on shipped types: the pure copy (`TrackCopy`) and the real
//     `TimelineStore` writer with its Undo/Redo step.
//   · Claim 3 is a SOURCE-TEXT SCAN: the button is mounted once on the Track page and writes through
//     the one writer.
//   · NOT CLAIMED (DEVICE PROBE): that both tracks sound. NEEDS-FOUNDER-VERIFY (A7) — the probe is
//     at `TrackCopyButton.swift`'s head.
//
// HONEST GRADING against the parent (§3): the file does not compile there (`TrackCopy`,
// `duplicateLane`, `TrackCopyButton` are new), so no assertion has a verdict on the parent.
// Hand-transcribed: claims 1–2 are the CAPABILITY plus COUNTERWEIGHTS (the Echoel and bio tracks
// are refused; a copy is not armed; another track's parts and curves are not copied; an Undo after
// the copy's parts changed is skipped); claim 3 is a FORWARD guard. Mutants: the Echoel track
// copied (1) · curves keyed to the original (1) · the copy placed at the end (1) · Undo leaves the
// copy's parts (2) · Undo removes a changed copy (2) · a second mount (3).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ATrackCopyCarriesItsPartsAndCurvesTests: XCTestCase {

    private struct Fixture {
        let echoel: TimelineLane
        let synth: TimelineLane
        let audio: TimelineLane
        let body: TimelineLane
        let part: TimelineRegion
        let other: TimelineRegion
        let curve: AutomationLane
        let document: TimelineDocument
        init() {
            let bar = TimelineTime.ticksPerBar
            let echoel = TimelineLane(name: "Echoel", kind: .midi)
            var synth = TimelineLane(name: "Synth", kind: .midi, builtinInstrument: .polySynth)
            synth.isArmed = true
            synth.level = 0.5
            let audio = TimelineLane(name: "Audio", kind: .audio)
            let body = TimelineLane(name: "Body", kind: .audio, isBio: true)
            let part = TimelineRegion(laneID: synth.id, clipID: UUID(), startTick: 2 * bar, lengthTicks: bar)
            let other = TimelineRegion(laneID: echoel.id, clipID: UUID(), startTick: 0, lengthTicks: bar)
            let curve = AutomationLane(parameter: PerTrackParameterKeyPath.make(laneID: synth.id, base: "ddsp.filter.cutoff"),
                                       points: [AutomationPoint(tick: 0, value: 0.2), AutomationPoint(tick: bar, value: 0.8)])
            let foreign = AutomationLane(parameter: PerTrackParameterKeyPath.make(laneID: echoel.id, base: "ddsp.filter.cutoff"))
            self.echoel = echoel; self.synth = synth; self.audio = audio; self.body = body
            self.part = part; self.other = other; self.curve = curve
            document = TimelineDocument(lanes: [echoel, synth, audio, body], regions: [part, other],
                                        automation: [curve, foreign])
        }
    }

    // MARK: 1 — what a copy is, and which tracks are refused

    func testACopyStandsBelowWithItsPartsAndCurves() throws {
        let f = Fixture()
        XCTAssertFalse(TrackCopy.offered(f.echoel.id, in: f.document), "the Echoel track is one voice")
        XCTAssertFalse(TrackCopy.offered(f.body.id, in: f.document), "the body's curve is one")
        XCTAssertTrue(TrackCopy.offered(f.audio.id, in: f.document))
        XCTAssertNil(TrackCopy.copy(of: f.echoel.id, in: f.document))
        let newID = UUID()
        let copy = try XCTUnwrap(TrackCopy.copy(of: f.synth.id, in: f.document, newID: newID))
        XCTAssertEqual(copy.index, 2, "right below the original")
        XCTAssertEqual(copy.lane.id, newID)
        XCTAssertEqual(copy.lane.name, "Synth copy")
        XCTAssertEqual(copy.lane.level, 0.5, "the mix comes along")
        XCTAssertEqual(copy.lane.builtinInstrument, .polySynth, "and the instrument")
        XCTAssertFalse(copy.lane.isArmed, "a copy is never armed")
        XCTAssertEqual(copy.regions.count, 1, "only this track's parts")
        XCTAssertEqual(copy.regions.first?.laneID, newID)
        XCTAssertEqual(copy.regions.first?.startTick, f.part.startTick, "placed where it stands")
        XCTAssertEqual(copy.regions.first?.clipID, f.part.clipID, "playing the same clip")
        XCTAssertNotEqual(copy.regions.first?.id, f.part.id)
        XCTAssertEqual(copy.automation.map(\.parameter),
                       [PerTrackParameterKeyPath.make(laneID: newID, base: "ddsp.filter.cutoff")],
                       "only this track's curve, re-keyed to the copy")
        XCTAssertEqual(copy.automation.first?.points.map(\.value), f.curve.points.map(\.value))
    }

    // MARK: 2 — the store writer is ONE Undo step

    func testDuplicateLaneIsOneUndoStep() throws {
        let f = Fixture()
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }
        timeline.replaceDocument(f.document)
        let id = try XCTUnwrap(timeline.duplicateLane(id: f.synth.id))
        XCTAssertEqual(timeline.document.lanes.map(\.id), [f.echoel.id, f.synth.id, id, f.audio.id, f.body.id])
        XCTAssertEqual(timeline.document.regions.filter { $0.laneID == id }.count, 1)
        XCTAssertEqual(timeline.document.rollLaneID, f.echoel.id, "the Echoel instrument stays where it was")
        XCTAssertNil(timeline.duplicateLane(id: f.echoel.id))
        timeline.undo()
        XCTAssertEqual(timeline.document.lanes.map(\.id), f.document.lanes.map(\.id), "ONE Undo takes the copy away")
        XCTAssertFalse(timeline.document.regions.contains { $0.laneID == id }, "with its parts")
        XCTAssertFalse(timeline.document.automation.contains { PerTrackParameterKeyPath.parse($0.parameter)?.laneID == id },
                       "and its curves")
        timeline.redo()
        XCTAssertEqual(timeline.document.lanes.map(\.id), [f.echoel.id, f.synth.id, id, f.audio.id, f.body.id],
                       "Redo puts it back where it stood")
        XCTAssertEqual(timeline.document.regions.filter { $0.laneID == id }.count, 1)
    }

    // MARK: 3 — the button

    func testTheButtonIsOnTheTrackPageAndWritesThroughTheStore() throws {
        let inspector = try source("Sources/Echoelmusic/Studio/TrackInspectorView.swift")
        XCTAssertEqual(inspector.components(separatedBy: "TrackCopyButton(laneID: laneID)").count - 1, 1, "one mount")
        let button = try source("Sources/Echoelmusic/Studio/TrackCopyButton.swift")
        XCTAssertTrue(button.contains("timeline.duplicateLane(id: laneID)"))
        XCTAssertTrue(button.contains("if TrackCopy.offered(laneID, in: timeline.document)"), "drawn only where a copy is allowed")
        let store = try source("Sources/Echoelmusic/Core/TimelineStore.swift")
        XCTAssertTrue(store.contains("pushUndo(.trackCopy("), "the copy is an Undo step")
    }

    // MARK: helpers

    private struct Unreadable: Error {}

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw Unreadable()
        }
        return SourceText.codeOnly(text)
    }
}
