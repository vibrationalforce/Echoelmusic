// OnlyAnEmptyTrackCanBeRemovedTests.swift
// Echoel — WA4.4: remove a track from the Workstation's inspector.
//
// WHAT THIS PINS. `TimelineStore.removeLaneIfEmpty` had NO production caller: a track, once
// added ("Add Audio Track", #F1), could never be taken away again. The inspector now offers
// "Remove track" through `TrackMix.removeTrack`. The risks: removing a track with parts (a lane
// removal is not undoable, a part removal is), removing the Echoel track (the instrument would
// silently move to the next MIDI track, with its level), removing a bio curve, and asking the
// user to empty a track that has no part editor.
//
// 1. END-TO-END (pure) over `TimelineDocument`: `TrackMix.removal` answers `.allowed` for an
//    empty, non-Echoel, non-bio track only; it names the reason otherwise, and a track whose
//    parts this build cannot edit gets its own answer rather than an impossible instruction.
// 2. END-TO-END over a REAL `TimelineStore`: an empty track goes; a track with a part stays
//    until the part is removed; an Undo after the track is gone does not resurrect its part as
//    an invisible orphan (the store's `restoreRegions` drops it). Assertions are on the
//    fixture's OWN lane ids — `TimelineStore()` loads whatever an earlier run persisted.
// 3. SOURCE: the inspector is the one production caller of `removeLaneIfEmpty`, through
//    `TrackMix.removeTrack`, which re-checks the rule before writing; the button is disabled
//    whenever the rule says no.
//
// Grading (§0, no Swift toolchain in a web session): claims 1–2 were transcribed into Python
// over a model of `TrackMix.removal`, `rollLaneID` and the store's undo/restore; claim 3 was
// driven against this tree. On the parent (764e1f8e7) `TrackMix.removal` does not exist, so the
// bundle does not build there — ONE absence, not N findings (#486). The orphan claim in 2 is a
// COUNTERWEIGHT (the store behaviour predates this slice).
// NOT covered: that the row renders and reads well — a device probe, owned by the marker below.
// NEEDS-FOUNDER-VERIFY: Workstation → Add Audio Track → tap it → Remove track; then a track
// with a part: the button is disabled and says why.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class OnlyAnEmptyTrackCanBeRemovedTests: XCTestCase {

    private static let inspectorPath = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"
    private static let storePath = "Sources/Echoelmusic/Core/TimelineStore.swift"
    private static let sourcesRoot = "Sources/Echoelmusic"
    private static let bar = TimelineTime.ticksPerBar

    // One fixture VALUE per lane — never a factory (#1419).
    private static let bioLane = TimelineLane(name: "Body", kind: .midi, isBio: true)
    private static let keysLane = TimelineLane(name: "Keys", kind: .midi)
    private static let extraLane = TimelineLane(name: "Extra", kind: .midi)
    private static let loopLane = TimelineLane(name: "Loop", kind: .audio)
    private static let lookLane = TimelineLane(name: "Look", kind: .visual)

    // MARK: 1 — the rule

    func testOnlyAnEmptyOrdinaryTrackIsRemovable() {
        let clip = UUID()
        let loopA = TimelineRegion(laneID: Self.loopLane.id, clipID: clip,
                                   startTick: 0, lengthTicks: Self.bar)
        let loopB = TimelineRegion(laneID: Self.loopLane.id, clipID: clip,
                                   startTick: Self.bar, lengthTicks: Self.bar)
        let look = TimelineRegion(laneID: Self.lookLane.id, clipID: clip,
                                  startTick: 0, lengthTicks: Self.bar)
        let lanes = [Self.bioLane, Self.keysLane, Self.extraLane, Self.loopLane, Self.lookLane]
        let full = TimelineDocument(lanes: lanes, regions: [loopA, loopB, look])
        let empty = TimelineDocument(lanes: lanes, regions: [])

        XCTAssertEqual(full.rollLaneID, Self.keysLane.id, "fixture premise: Keys is the Echoel track")
        XCTAssertEqual(TrackMix.removal(of: Self.bioLane.id, in: full), .bio)
        XCTAssertEqual(TrackMix.removal(of: Self.keysLane.id, in: empty), .echoelTrack,
                       "the Echoel track stays even when empty — removing it moves the instrument")
        XCTAssertEqual(TrackMix.removal(of: Self.extraLane.id, in: full), .allowed)
        XCTAssertEqual(TrackMix.removal(of: Self.loopLane.id, in: full), .hasParts(2))
        XCTAssertEqual(TrackMix.removal(of: Self.loopLane.id, in: empty), .allowed)
        XCTAssertEqual(TrackMix.removal(of: Self.lookLane.id, in: full), .uneditableParts(1),
                       "no part editor for a visual lane — never ask the user to empty it")
        XCTAssertEqual(TrackMix.removal(of: Self.lookLane.id, in: empty), .allowed)
        XCTAssertNil(TrackMix.removal(of: UUID(), in: full))
    }

    func testEveryAnswerSaysWhy() {
        let answers: [TrackMix.Removal] = [.allowed, .hasParts(1), .hasParts(3),
                                           .uneditableParts(2), .echoelTrack, .bio]
        for answer in answers {
            XCTAssertFalse(TrackMix.removalNote(answer).isEmpty, "\(answer) has no note")
        }
        XCTAssertEqual(TrackMix.removalNote(.hasParts(1)), "Remove its part first to remove this track.")
        XCTAssertEqual(TrackMix.removalNote(.hasParts(3)), "Remove its 3 parts first to remove this track.")
        XCTAssertTrue(TrackMix.removalNote(.allowed).contains("Undo cannot bring the track"),
                      "a lane removal is outside the region-only undo history — the note must say so")
    }

    // MARK: 2 — the real store

    func testAnEmptyTrackGoesAndATrackWithAPartStays() throws {
        let timeline = TimelineStore()
        let name = "WA4.4 guard \(UUID().uuidString.prefix(8))"
        timeline.addLane(kind: .audio, name: name)
        let lane = try XCTUnwrap(timeline.document.lanes.last(where: { $0.name == name }))
        let region = TimelineRegion(laneID: lane.id, clipID: UUID(),
                                    startTick: 0, lengthTicks: Self.bar)
        timeline.addRegion(region)
        defer {
            timeline.removeRegion(id: region.id)
            timeline.removeLaneIfEmpty(id: lane.id)
        }
        func exists() -> Bool { timeline.document.lanes.contains { $0.id == lane.id } }

        XCTAssertEqual(TrackMix.removal(of: lane.id, in: timeline.document), .hasParts(1))
        TrackMix.removeTrack(laneID: lane.id, timeline: timeline)
        XCTAssertTrue(exists(), "a track with a part is never removed")

        timeline.removeRegion(id: region.id)
        XCTAssertEqual(TrackMix.removal(of: lane.id, in: timeline.document), .allowed)
        TrackMix.removeTrack(laneID: lane.id, timeline: timeline)
        XCTAssertFalse(exists(), "an empty track is removed")

        // Undo reverts the part removal, but the lane is gone: the part must not come back as
        // an orphan nobody can see or remove.
        timeline.undo()
        XCTAssertFalse(timeline.document.regions.contains { $0.id == region.id })
        XCTAssertFalse(exists(), "undo never restores a lane — the history is region-only")
    }

    // MARK: 3 — source: one caller, re-checked, disabled when refused

    func testTheInspectorIsTheOneRemoverAndReChecksTheRule() throws {
        let inspector = try source(Self.inspectorPath)
        XCTAssertEqual(inspector.components(separatedBy: "TrackMix.removeTrack(laneID: laneID, timeline: timeline)").count - 1, 1)
        XCTAssertEqual(inspector.components(separatedBy: "timeline.removeLaneIfEmpty(id: laneID)").count - 1, 1)
        guard let head = inspector.range(of: "static func removeTrack(laneID: UUID, timeline: TimelineStore)"),
              let check = inspector.range(of: "removal(of: laneID, in: timeline.document) == .allowed",
                                          range: head.upperBound..<inspector.endIndex),
              let write = inspector.range(of: "timeline.removeLaneIfEmpty(id: laneID)",
                                          range: head.upperBound..<inspector.endIndex) else {
            XCTFail("ANCHOR MISSING: TrackMix.removeTrack moved (#454)")
            return
        }
        XCTAssertLessThan(check.lowerBound, write.lowerBound,
                          "removeTrack must re-check the rule before it writes")
        XCTAssertTrue(inspector.contains(".disabled(!allowed)"),
                      "a refused removal must be a disabled button, not a silent no-op")

        let callers = try filesMatching { code, path in
            path != Self.storePath && code.contains("removeLaneIfEmpty(")
        }
        XCTAssertEqual(callers, [Self.inspectorPath],
                       "the inspector is the one production caller of removeLaneIfEmpty")
        let store = try source(Self.storePath)
        XCTAssertTrue(store.contains("guard document.regions(in: id).isEmpty else { return }"),
                      "the store's own refusal of a lane with parts is the last line of defence")
    }

    // MARK: Source helpers

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        return dir
    }

    private func source(_ relativePath: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    private func filesMatching(_ matches: (String, String) -> Bool) throws -> [String] {
        let root = repoRoot().appendingPathComponent(Self.sourcesRoot)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("cannot enumerate \(Self.sourcesRoot) — a scan that saw nothing is not a pass")
            return []
        }
        var hits: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            let path = Self.sourcesRoot + "/" + relative
            let url = root.appendingPathComponent(relative)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if matches(SourceText.codeOnly(text), path) { hits.append(path) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        return hits.sorted()
    }
}
