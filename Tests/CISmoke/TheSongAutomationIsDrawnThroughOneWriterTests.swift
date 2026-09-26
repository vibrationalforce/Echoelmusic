// TheSongAutomationIsDrawnThroughOneWriterTests.swift
// Echoel — Phase 3 / Automation editing, slice A1. The song's automation layer
// (`TimelineDocument.automation`) was persisted and played every transport step, and nothing
// could draw into it: the row that did went with #473, and the store's per-point mutators
// outlived it with no caller and no Undo. `SongAutomationEditor` draws ONE parameter
// (Brightness) on the selected poly rack track through ONE writer with ONE undo step.
//
// WHAT IT PINS.
// 1. END-TO-END BEHAVIOUR (a real `TimelineStore`): `setSongAutomation` writes the lanes and
//    records exactly one `.automation` undo step; Undo and Redo restore it; an unchanged list
//    writes nothing and records nothing; undoing an automation step leaves the parts alone.
// 2. END-TO-END BEHAVIOUR (`SongAutomationEdit`, pure): a tap adds a snapped point or picks
//    the one under the finger; a hold-and-slide moves a point by the finger's travel from its
//    OWN position, snapped to the sixteenth; add / move / revalue / remove give the whole new
//    lane list; a redraw on a held sixteenth changes its value instead of stacking a point.
// 3. END-TO-END BEHAVIOUR (the premise that makes the row honest): the row is offered on a
//    poly rack track and NOT on the Echoel track — and the key it writes resolves to a rack
//    slot through `PerTrackAutomationResolver` on the first and to nothing on the second.
// 4. END-TO-END BEHAVIOUR + SOURCE-TEXT SCAN: an automation-only edit takes the player's short
//    path (`differsOnlyInAutomation`), checked before the chase flushes a single voice.
// 6. END-TO-END BEHAVIOUR (review repair): a hold that travels less than the shared tap slop
//    moves nothing; a move onto an occupied sixteenth replaces, never stacks; Remove drops only
//    the emptied lane; removing a track takes its curves with it, and an Undo step that would
//    only touch that track's lane is skipped, never a no-op that reads as available.
// 5. SOURCE-TEXT SCAN: the editor writes only through the one writer and never the older
//    per-point mutators (they record no Undo); the only finger-rate state is `@GestureState`;
//    the editor reads no clock; the Workstation mounts it once.
//
// HONEST GRADING (§3), against the parent tree (the S2 doc commit): the file does NOT compile
// there — `setSongAutomation`, `SongAutomationEdit` and `differsOnlyInAutomation` are new —
// so no assertion has a verdict on the parent; every claim is a FORWARD guard (one absence,
// #486). Counterweights (#343): claim 1's parts survive an automation Undo; claim 3's Echoel
// track gets NO row and its key resolves to nothing; claim 4's structural edit is NOT short.
// Graded by Python transcription of the scan anchors against the worktree; the behavioural
// claims by hand-tracing the pure cores they call.
// REVIEW REPAIR (against 6bcbc731f, where the file DOES compile): claim 6's slop, replace,
// single-lane remove and removed-track assertions are REGRESSIONS there — each is red for its
// named reason (a 3.6-pt travel moved the point; a move stacked two points; Remove pruned the
// bystander; the removed track's lane stayed). The new `doc.automation` pin in claim 4 is
// green on both trees (a pin on a line A1 already wrote).
//
// NOT HERE — DEVICE PROBE, open.
// NEEDS-FOUNDER-VERIFY: Workstation → a second MIDI track (poly) → select it → "Automation" →
// tap three points, hold one and slide it → Play: the track's brightness follows the curve;
// Undo takes the last point edit back; the Echoel track shows no Automation switch.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheSongAutomationIsDrawnThroughOneWriterTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let editorPath = "Sources/Echoelmusic/Studio/SongAutomationEditor.swift"
    private static let playerPath = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"
    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"

    /// Echoel (the roll lane, first non-bio MIDI lane) + a poly rack track + an audio track.
    private static func song() -> (TimelineDocument, echoel: UUID, keys: UUID, audio: UUID) {
        let echoel = TimelineLane(name: "MIDI 1", kind: .midi)
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let audio = TimelineLane(name: "Audio 1", kind: .audio)
        return (TimelineDocument(lanes: [echoel, keys, audio], regions: []),
                echoel.id, keys.id, audio.id)
    }

    // MARK: 1 — the one writer, on a real store

    func testTheWriterRecordsOneUndoStepAndLeavesThePartsAlone() throws {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }

        let (doc, _, keys, _) = Self.song()
        timeline.replaceDocument(doc)
        XCTAssertFalse(timeline.canUndo, "a replaced song starts with no history")
        let key = SongAutomationEdit.key(for: keys)

        let one = SongAutomationEdit.adding(tick: Self.bar, value: 0.25, key: key,
                                            to: [], songTicks: 4 * Self.bar)
        XCTAssertTrue(timeline.setSongAutomation(one))
        XCTAssertEqual(timeline.document.automation, one)
        XCTAssertTrue(timeline.canUndo)

        XCTAssertTrue(timeline.setSongAutomation(one), "an unchanged list is accepted")
        timeline.undo()
        XCTAssertEqual(timeline.document.automation, [], "ONE step: an unchanged write recorded none")
        XCTAssertFalse(timeline.canUndo)
        timeline.redo()
        XCTAssertEqual(timeline.document.automation, one)

        // Counterweight: a parts edit, then an automation edit — Undo takes back only the latter.
        let region = TimelineRegion(laneID: keys, clipID: UUID(), startTick: 0, lengthTicks: Self.bar)
        timeline.addRegion(region)
        let regions = timeline.document.regions
        let two = SongAutomationEdit.adding(tick: 2 * Self.bar, value: 0.75, key: key,
                                            to: one, songTicks: 4 * Self.bar)
        timeline.setSongAutomation(two)
        timeline.undo()
        XCTAssertEqual(timeline.document.automation, one, "the automation step is undone")
        XCTAssertEqual(timeline.document.regions, regions, "and the parts are untouched by it")
    }

    // MARK: 2 — the gestures, pure

    func testATapAddsASnappedPointOrPicksTheOneUnderTheFinger() throws {
        let song = 4 * Self.bar
        // 400 pt wide → 0.052 pt per tick; x = 101 lands a hair past bar 2's start.
        guard case .add(let tick, let value)? = SongAutomationEdit.resolveTap(
            x: 101, y: 25, width: 400, height: 100, points: [], songTicks: song) else {
            return XCTFail("a tap on an empty row adds")
        }
        XCTAssertEqual(tick % TimelineTime.ticksPerTransportStep, 0, "snapped to the sixteenth")
        XCTAssertEqual(tick, Self.bar, "the sixteenth nearest the finger")
        XCTAssertEqual(value, 0.75, accuracy: 1e-9, "top is high")

        let key = SongAutomationEdit.key(for: UUID())
        let lanes = SongAutomationEdit.adding(tick: tick, value: value, key: key, to: [],
                                              songTicks: song)
        let points = SongAutomationEdit.points(key, in: lanes, songTicks: song)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(SongAutomationEdit.resolveTap(x: 104, y: 27, width: 400, height: 100,
                                                     points: points, songTicks: song),
                       SongAutomationEdit.Tap.pick(points[0].id), "a tap on a point picks it")

        let redrawn = SongAutomationEdit.adding(tick: tick, value: 0.1, key: key, to: lanes,
                                                songTicks: song)
        XCTAssertEqual(SongAutomationEdit.points(key, in: redrawn, songTicks: song).map(\.value), [0.1],
                       "a redraw on a held sixteenth sets its value — no stacked point")
        XCTAssertNil(SongAutomationEdit.resolveTap(x: 10, y: 10, width: 0, height: 100,
                                                   points: [], songTicks: song))
    }

    func testASlideMovesThePointFromItsOwnPosition() throws {
        let song = 4 * Self.bar
        let key = SongAutomationEdit.key(for: UUID())
        let lanes = SongAutomationEdit.adding(tick: Self.bar, value: 0.5, key: key, to: [],
                                              songTicks: song)
        let point = try XCTUnwrap(SongAutomationEdit.points(key, in: lanes, songTicks: song).first)
        // The point sits at x = 100, y = 50. Grab it 10 pt off-centre and slide one bar right,
        // a quarter of the height up: it lands on bar 3 at 0.75 — the grab offset is not a jump.
        let move = try XCTUnwrap(SongAutomationEdit.resolveMove(
            startX: 110, startY: 50, dx: 100, dy: -25, width: 400, height: 100,
            points: [point], songTicks: song))
        XCTAssertEqual(move, SongAutomationEdit.Move(id: point.id, tick: 2 * Self.bar, value: 0.75))
        XCTAssertNil(SongAutomationEdit.resolveMove(startX: 110, startY: 50, dx: 3, dy: 2,
                                                    width: 400, height: 100, points: [point],
                                                    songTicks: song),
                     "a trembling hold (under the tap slop) moves nothing and writes no Undo step")
        XCTAssertNil(SongAutomationEdit.resolveMove(startX: 300, startY: 90, dx: 20, dy: 0,
                                                    width: 400, height: 100, points: [point],
                                                    songTicks: song),
                     "a slide that starts off every point moves nothing")

        let moved = SongAutomationEdit.moving(move, in: lanes, songTicks: song)
        XCTAssertEqual(SongAutomationEdit.points(key, in: moved, songTicks: song).map(\.tick), [2 * Self.bar])
        let revalued = SongAutomationEdit.revaluing(point.id, to: 0.2, in: moved)
        XCTAssertEqual(SongAutomationEdit.points(key, in: revalued, songTicks: song).map(\.value), [0.2])
        XCTAssertEqual(SongAutomationEdit.removing(point.id, from: revalued), [],
                       "removing the last point drops the lane — no ghost lanes in the song")
    }

    // MARK: 3 — offered only where the curve sounds

    func testTheRowIsOfferedWhereTheKeyReachesAVoice() throws {
        let descriptor = try XCTUnwrap(SongAutomationEdit.descriptor,
                                       "the one parameter must be offered for automation")
        XCTAssertTrue(PolySynthVoice.automatableBases.contains(SongAutomationEdit.base))
        XCTAssertEqual(descriptor.keyPath, SongAutomationEdit.base)

        let (doc, echoel, keys, audio) = Self.song()
        XCTAssertTrue(SongAutomationEdit.sounds(on: keys, in: doc, voiceCapacity: 4))
        XCTAssertFalse(SongAutomationEdit.sounds(on: echoel, in: doc, voiceCapacity: 4),
                       "the Echoel track gets no row — which voice it means is a founder call")
        XCTAssertFalse(SongAutomationEdit.sounds(on: audio, in: doc, voiceCapacity: 4))
        XCTAssertFalse(SongAutomationEdit.sounds(on: keys, in: doc, voiceCapacity: 0),
                       "a track without a rack voice would draw silence")

        // The premise, end to end: the key reaches a rack slot on the offered track and nothing
        // on the Echoel track. (The resolver also finds a slot for a non-poly rack lane; there
        // the POLY gate above is what keeps the row away — a slot is not a sounding brightness.)
        func resolves(_ lane: UUID) -> Bool {
            PerTrackAutomationResolver.resolve(
                keyPath: SongAutomationEdit.key(for: lane), normalized: 0.5, document: doc,
                rollLane: doc.rollLaneID, capacity: 4,
                descriptor: { base in DDSPParameterCatalog.descriptors.first { $0.keyPath == base } }) != nil
        }
        XCTAssertTrue(resolves(keys))
        XCTAssertFalse(resolves(echoel))
    }

    // MARK: 4 — the player's short path

    func testAnAutomationOnlyEditIsNotARelocation() throws {
        let (doc, _, keys, _) = Self.song()
        var drawn = doc
        drawn.automation = SongAutomationEdit.adding(tick: 0, value: 0.5,
                                                     key: SongAutomationEdit.key(for: keys),
                                                     to: [], songTicks: 4 * Self.bar)
        XCTAssertTrue(TimelineRegionPlayer.differsOnlyInAutomation(doc, drawn))
        XCTAssertFalse(TimelineRegionPlayer.differsOnlyInAutomation(doc, doc), "no change is not a change")
        var moved = drawn
        moved.regions = [TimelineRegion(laneID: keys, clipID: UUID(), startTick: 0, lengthTicks: Self.bar)]
        XCTAssertFalse(TimelineRegionPlayer.differsOnlyInAutomation(doc, moved),
                       "a structural edit still takes the chase")

        let player = try source(Self.playerPath)
        let refresh = try body(of: "private func refreshStructure()", in: player)
        guard let short = refresh.range(of: "if Self.differsOnlyInAutomation(doc, fresh) {"),
              let flush = refresh.range(of: "flushPumps()") else {
            return XCTFail("ANCHOR MISSING: refreshStructure's short path (#454)")
        }
        XCTAssertLessThan(short.lowerBound, flush.lowerBound, "decided before a voice is flushed")
        let path = try body(of: "if Self.differsOnlyInAutomation(doc, fresh)", in: refresh)
        XCTAssertTrue(path.contains("pianoRoll?.setTimelineAutomation(fresh.automation)"))
        XCTAssertTrue(path.contains("doc.automation = fresh.automation"),
                      "the player's snapshot takes the lanes, or every step re-sends them")
        XCTAssertTrue(path.contains("return"))
    }

    // MARK: 6 — review repair

    func testAMoveReplacesAndARemoveTouchesOnlyItsLane() throws {
        let song = 4 * Self.bar
        let key = SongAutomationEdit.key(for: UUID())
        var lanes = SongAutomationEdit.adding(tick: Self.bar, value: 0.2, key: key, to: [],
                                              songTicks: song)
        lanes = SongAutomationEdit.adding(tick: 2 * Self.bar, value: 0.8, key: key, to: lanes,
                                          songTicks: song)
        let first = try XCTUnwrap(SongAutomationEdit.points(key, in: lanes, songTicks: song).first)
        let moved = SongAutomationEdit.moving(
            SongAutomationEdit.Move(id: first.id, tick: 2 * Self.bar, value: 0.4),
            in: lanes, songTicks: song)
        let after = SongAutomationEdit.points(key, in: moved, songTicks: song)
        XCTAssertEqual(after.map(\.id), [first.id], "one point per sixteenth — the mover wins")
        XCTAssertEqual(after.map(\.value), [0.4])

        let bystander = AutomationLane(parameter: "mix.level")   // empty, not this row's
        let removed = SongAutomationEdit.removing(first.id, from: moved + [bystander])
        XCTAssertEqual(removed, [bystander], "only the emptied lane goes; another empty lane stays")
    }

    func testARemovedTrackTakesItsCurvesAndUndoSkipsThem() throws {
        let timeline = TimelineStore()
        let original = timeline.document
        defer { timeline.replaceDocument(original) }

        let (doc, _, keys, _) = Self.song()
        timeline.replaceDocument(doc)
        let song = 4 * Self.bar
        let global = SongAutomationEdit.adding(tick: 0, value: 0.5, key: SongAutomationEdit.base,
                                               to: [], songTicks: song)
        timeline.setSongAutomation(global)
        timeline.setSongAutomation(SongAutomationEdit.adding(
            tick: Self.bar, value: 0.9, key: SongAutomationEdit.key(for: keys), to: global,
            songTicks: song))
        XCTAssertEqual(timeline.document.automation.count, 2)

        timeline.removeLaneIfEmpty(id: keys)
        XCTAssertFalse(timeline.document.lanes.contains { $0.id == keys }, "premise: the track went")
        XCTAssertEqual(timeline.document.automation, global,
                       "its curve went with it; the song-wide lane stays")

        // The newest step would only bring back the removed track's lane — skipped; the one
        // before it (the global lane's first point) is what Undo takes back.
        timeline.undo()
        XCTAssertEqual(timeline.document.automation, [], "Undo did something visible")
        XCTAssertFalse(timeline.canUndo)
    }

    // MARK: 5 — one writer, gesture-local preview, no clock

    func testTheEditorWritesOnlyThroughTheOneWriter() throws {
        let editor = try source(Self.editorPath)
        XCTAssertEqual(editor.components(separatedBy: "timeline.setSongAutomation(").count - 1, 4,
                       "add, move, value and remove — each one commit")
        for mutator in ["addAutomationPoint(", "moveAutomationPoint(", "removeAutomationPoint(",
                        "setAutomationValue(", "setAutomationCurve(", "setAutomationCurvature(",
                        "clearAutomation("] {
            XCTAssertFalse(editor.contains(mutator), "`\(mutator)` writes no Undo step")
        }
        XCTAssertTrue(editor.contains("@GestureState private var live: SongAutomationEdit.Move? = nil"))
        XCTAssertEqual(editor.components(separatedBy: "@State private var draft").count - 1, 1,
                       "the value field drafts locally and writes once")
        for clock in ["currentTick", "isPlaying", "masterLevel", "latestBio"] {
            XCTAssertFalse(editor.contains(clock), "the editor reads no clock or live signal (`\(clock)`)")
        }
        let workstation = try source(Self.workstationPath)
        XCTAssertEqual(workstation.components(
            separatedBy: "SongAutomationEditor(songTicks: ArrangementStrip.songTicks(summary))").count - 1, 1)
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    /// The brace-matched body after the first occurrence of `anchor` (#408).
    private func body(of anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code[start.upperBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: \(anchor) (#454)")
            throw AnchorMissing(name: anchor)
        }
        var depth = 0
        var index = open
        while index < code.endIndex {
            switch code[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(code[code.index(after: open)..<index]) }
            default: break
            }
            index = code.index(after: index)
        }
        XCTFail("ANCHOR MISSING: unbalanced body after \(anchor) (#454)")
        throw AnchorMissing(name: anchor)
    }

    private func source(_ relativePath: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    private func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url
            }
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}
