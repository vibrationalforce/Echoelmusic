// TheTrackPartsAreArrangedThroughTheStoreTests.swift
// Echoel — WA4.3: arrange the selected track's parts — move, copy, remove, undo.
//
// WHAT THIS PINS. `Studio/TrackPartsView.swift` gives `TimelineStore.moveRegion`,
// `duplicateRegion`, `removeRegion`, `undo` and `redo` their first production caller. The
// store's arrangement API and its region-only undo history stood caller-less since the arrange
// surface was cut (#121). The risks in dooring it: a second edit path beside the store (a part
// edit that skips the undo snapshot), a move that trims a neighbour (a second overlap rule),
// and an Undo that promises to revert a mixer change it cannot touch.
//
// 1. END-TO-END (pure): a track's parts in song order (start, then placement — the order
//    `activeRegion` breaks ties in); which tracks are arrangeable; where a one-bar move lands
//    (never below the song's top); how a part is named.
// 2. END-TO-END over a REAL `TimelineStore`: each action is one undo step — move, then undo
//    and redo; copy lands right after the part; remove, then undo brings it back. Assertions
//    are on the fixture's OWN lane and part ids, never on absolute counts: `TimelineStore()`
//    loads whatever an earlier run persisted (`TheWorkstationImportsAudioTests` claim 19).
// 3. COUNTERWEIGHTS (#343): the undo history is still region-only (so the "never mixer
//    changes" hint stays true) and each store edit still snapshots before it mutates.
// 4. SOURCE: the view writes through `TrackParts` → the store API and nothing else, and the
//    inspector is its one door.
//
// Grading (§0, no Swift toolchain in a web session): claims 1–2 were transcribed into Python
// over a model of `TrackParts` and the store's snapshot/undo/redo; claims 3–4 were driven
// against this tree. On the parent `TrackParts` does not exist, so the bundle does not build
// there — ONE absence, not N findings (#486). Claim 3 is COUNTERWEIGHTS (green on both).
// NOT covered: whether the rows render, read well, or that a moved part is HEARD in its new
// bar while the song plays — a device probe, owned by the marker below.
// NEEDS-FOUNDER-VERIFY: Workstation → tap a track → Parts: Later, Earlier, Copy, Remove, then
// Undo and Redo, once stopped and once while the song plays.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheTrackPartsAreArrangedThroughTheStoreTests: XCTestCase {

    private static let partsPath = "Sources/Echoelmusic/Studio/TrackPartsView.swift"
    private static let inspectorPath = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"
    private static let storePath = "Sources/Echoelmusic/Core/TimelineStore.swift"
    private static let sourcesRoot = "Sources/Echoelmusic"
    private static let bar = TimelineTime.ticksPerBar

    // MARK: 1 — the pure half

    func testThePartsAreInSongOrder() {
        let lane = TimelineLane(name: "Keys", kind: .midi)
        let other = TimelineLane(name: "Loop", kind: .audio)
        let clip = UUID()
        let late = TimelineRegion(laneID: lane.id, clipID: clip, startTick: 4 * Self.bar, lengthTicks: Self.bar)
        let early = TimelineRegion(laneID: lane.id, clipID: clip, startTick: 0, lengthTicks: Self.bar)
        let tieA = TimelineRegion(laneID: lane.id, clipID: clip, startTick: 2 * Self.bar, lengthTicks: Self.bar)
        let tieB = TimelineRegion(laneID: lane.id, clipID: clip, startTick: 2 * Self.bar, lengthTicks: Self.bar)
        let elsewhere = TimelineRegion(laneID: other.id, clipID: clip, startTick: 0, lengthTicks: Self.bar)
        let doc = TimelineDocument(lanes: [lane, other], regions: [late, tieA, early, elsewhere, tieB])
        XCTAssertEqual(TrackParts.parts(onLane: lane.id, in: doc).map(\.id),
                       [early.id, tieA.id, tieB.id, late.id],
                       "start order, and a tie keeps placement order — the order activeRegion uses")
    }

    func testOnlyMidiAndAudioTracksAreArrangeable() {
        let bio = TimelineLane(name: "Body", kind: .midi, isBio: true)
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let loop = TimelineLane(name: "Loop", kind: .audio)
        let look = TimelineLane(name: "Look", kind: .visual)
        let doc = TimelineDocument(lanes: [bio, keys, loop, look], regions: [])
        XCTAssertFalse(TrackParts.arrangeable(bio.id, in: doc))
        XCTAssertTrue(TrackParts.arrangeable(keys.id, in: doc))
        XCTAssertTrue(TrackParts.arrangeable(loop.id, in: doc))
        XCTAssertFalse(TrackParts.arrangeable(look.id, in: doc))
        XCTAssertFalse(TrackParts.arrangeable(UUID(), in: doc))
    }

    func testAOneBarMoveNeverLeavesTheSong() {
        func part(at tick: Int) -> TrackParts.Part {
            TrackParts.Part(id: UUID(), startTick: tick, lengthTicks: Self.bar)
        }
        XCTAssertNil(TrackParts.earlierStart(part(at: 0)), "a part at the top has no earlier")
        XCTAssertEqual(TrackParts.earlierStart(part(at: TimelineTime.ticksPerBeat * 2)), 0,
                       "an off-bar part steps back to the top, never below it")
        XCTAssertEqual(TrackParts.earlierStart(part(at: 2 * Self.bar)), Self.bar)
        XCTAssertEqual(TrackParts.laterStart(part(at: 2 * Self.bar)), 3 * Self.bar)
        XCTAssertEqual(TrackParts.stepTicks, TimelineTime.ticksPerBar)
    }

    func testAPartIsNamedByItsBarAndLength() {
        XCTAssertEqual(TrackParts.title(TrackParts.Part(id: UUID(), startTick: 4 * Self.bar,
                                                        lengthTicks: 4 * Self.bar)),
                       "Bar 5 · 4 bars")
        XCTAssertEqual(TrackParts.lengthText(Self.bar), "1 bar")
        XCTAssertEqual(TrackParts.lengthText(TimelineTime.ticksPerBeat), "1 beat")
        XCTAssertEqual(TrackParts.lengthText(2 * TimelineTime.ticksPerBeat), "2 beats")
        XCTAssertEqual(TrackParts.lengthText(600), "0.31 bars")
    }

    // MARK: 2 — each action is one undo step, over the real store

    func testEveryPartActionIsOneUndoStep() throws {
        let timeline = TimelineStore()
        let laneName = "WA4.3 guard \(UUID().uuidString.prefix(8))"
        timeline.addLane(kind: .audio, name: laneName)
        let lane = try XCTUnwrap(timeline.document.lanes.last(where: { $0.name == laneName }))
        let region = TimelineRegion(laneID: lane.id, clipID: UUID(),
                                    startTick: Self.bar, lengthTicks: 2 * Self.bar)
        timeline.addRegion(region)
        defer {
            for part in TrackParts.parts(onLane: lane.id, in: timeline.document) {
                timeline.removeRegion(id: part.id)
            }
            timeline.removeLaneIfEmpty(id: lane.id)
        }
        func starts() -> [Int] { TrackParts.parts(onLane: lane.id, in: timeline.document).map(\.startTick) }
        let part = try XCTUnwrap(TrackParts.parts(onLane: lane.id, in: timeline.document).first)
        XCTAssertEqual(part.id, region.id)

        // Move earlier, undo, redo.
        let earlier = try XCTUnwrap(TrackParts.earlierStart(part))
        TrackParts.move(part, toStartTick: earlier, timeline: timeline)
        XCTAssertEqual(starts(), [0])
        XCTAssertTrue(timeline.canUndo)
        timeline.undo()
        XCTAssertEqual(starts(), [Self.bar], "undo puts the part back where it was")
        XCTAssertTrue(timeline.canRedo)
        timeline.redo()
        XCTAssertEqual(starts(), [0], "redo moves it again")

        // Copy lands right after the part, on the same lane.
        let moved = try XCTUnwrap(TrackParts.parts(onLane: lane.id, in: timeline.document).first)
        TrackParts.duplicate(moved, timeline: timeline)
        XCTAssertEqual(starts(), [0, 2 * Self.bar])

        // Remove the copy; undo brings it back.
        let copy = try XCTUnwrap(TrackParts.parts(onLane: lane.id, in: timeline.document).last)
        TrackParts.remove(copy, timeline: timeline)
        XCTAssertEqual(starts(), [0])
        timeline.undo()
        XCTAssertEqual(starts(), [0, 2 * Self.bar], "undo restores a removed part")
    }

    // MARK: 3 — counterweights: what the Undo hint promises

    func testTheUndoHistoryIsStillRegionOnly() throws {
        let store = try source(Self.storePath)
        XCTAssertTrue(store.contains("private var undoStack: [[TimelineRegion]]"),
                      """
                      The undo history is no longer region-only. The parts view promises Undo \
                      never reverts a mixer change; if the history now holds whole documents, \
                      that hint is false — change it in `Studio/TrackPartsView.swift` in the \
                      same commit.
                      """)
        for method in ["public func moveRegion(id: UUID, toStartTick tick: Int, bpm:",
                       "public func duplicateRegion(id: UUID)",
                       "public func removeRegion(id: UUID)"] {
            guard let head = store.range(of: method),
                  let snapshot = store.range(of: "snapshotForUndo()", range: head.upperBound..<store.endIndex),
                  let persist = store.range(of: "persist()", range: head.upperBound..<store.endIndex) else {
                XCTFail("ANCHOR MISSING: \(method) (#454)")
                continue
            }
            XCTAssertLessThan(snapshot.lowerBound, persist.lowerBound,
                              "\(method) must snapshot before it saves — one action, one undo step")
        }
    }

    // MARK: 4 — source: the writes and the one door

    func testThePartsViewWritesOnlyThroughTheStore() throws {
        let code = try source(Self.partsPath)
        for call in ["timeline.moveRegion(id: part.id, toStartTick: tick)",
                     "timeline.duplicateRegion(id: part.id)",
                     "timeline.removeRegion(id: part.id)",
                     "timeline.undo()", "timeline.redo()"] {
            XCTAssertEqual(code.components(separatedBy: call).count - 1, 1, "`\(call)` exactly once")
        }
        for banned in ["UserDefaults", "@AppStorage", "JSONEncoder", "TimelineStore(",
                       "TimelineRegion(", "TimelineDocument(", "resolveOverlaps", "bpm:",
                       "Slider(", "Stepper(", "currentTick", "player."] {
            XCTAssertFalse(code.contains(banned), """
                TrackPartsView contains `\(banned)`. It arranges through the store's API only: \
                no persistence of its own, no overlap trimming (activeRegion decides at play \
                time), no playhead read.
                """)
        }
        let inspector = try source(Self.inspectorPath)
        XCTAssertEqual(inspector.components(separatedBy: "TrackPartsView(laneID: laneID)").count - 1, 1)
        let doors = try filesMatching { code, _ in code.contains("TrackPartsView(") }
        XCTAssertEqual(doors, [Self.inspectorPath], "the parts view has one door: the inspector")
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
