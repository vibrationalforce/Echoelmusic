// TheCanvasPartEdgeMovesOnTheGridTests.swift
// Echoel — One World T1 (founder 2026-10-15: "Midi trim fehlt").
//
// WHAT THIS GUARDS. Before T1 a MIDI part could only be trimmed by the part bar's two buttons —
// one grid step INWARD, never longer — and only the audio editor moved an edge by hand. Now the
// arrange canvas gives the selected MIDI or audio part two edge handles
// (`Studio/ArrangePartEdgeHandles.swift`), and they ask the audio editor's own rule
// (`PartTrim.edgeEdit`, #416) through one canvas front end (`ArrangeCanvas.edgeEdit`).
//
// 1. END-TO-END — the canvas front end on an 8-bar song drawn 320 pt wide (40 pt a bar, exact in
//    binary): a MIDI part's end moves out over silence and in again, its start moves in and back
//    to its content's start but never before it, a covered end is refused, an audio part's end stops at
//    its file and refuses when the file's length is unknown, a video part gets no edit, and
//    degenerate input makes none.
// 2. END-TO-END — the grid: a MIDI START moves by whole bars at any zoom (the roll plays notes on
//    the song's bar lines), every other edge on `PartTrim.snapUnit` at the canvas zoom.
// 3. END-TO-END — the handles' touch areas: centred on a wide part's edges, OUTSIDE a narrow part
//    so its body stays free for the move, never past the nearest neighbouring part or the lane's
//    end (a side without half a target of room has none), never overlapping. The room comes from
//    the same lane's nearest parts (review of T1: a 44-pt handle hid a one-bar neighbour).
// 4. SOURCE-TEXT SCAN — the leaf writes once, on release, through the two store calls; the slide
//    touches no store; one `@GestureState`; hold first; the tempo is read cold; preview and
//    release ask the one question; nothing reads the song position. The canvas only MOUNTS it,
//    gated on an arrangeable track and a part kind with an edge bound, and still writes no edge.
//
// ⚠️ HONEST GRADING (#433). Claims 1–3 drive `ArrangeCanvas.edgeEdit`, `edgeUnit`, `edgeBound`,
// `edgeX`, `ArrangePartEdges.frames` and `.room`, all new in this commit, so the FILE does not compile
// against the parent and no assertion has a verdict there (one absence, #486): every claim is
// FORWARD. Expectations were derived from the rules as written (#442), by hand in this header's
// arithmetic: ppb = 320 × ticksPerBeat / (8 bars) = 10 pt a beat, so 40 pt is one bar. Claim 4 is
// a SOURCE-TEXT SCAN through `SourceText.codeOnly`; the leaf's header names `trimRegionStart`,
// `resizeRegion` and `@GestureState` in prose, so the stripper is load-bearing for those counts.
// What the handles FEEL like — whether the hold beats the canvas scroll, whether 44 pt is enough
// at a part's first bar — is a DEVICE PROBE and open (NEEDS-FOUNDER-VERIFY in the leaf's header).
//
// `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheCanvasPartEdgeMovesOnTheGridTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let lane = UUID()
    private static let width: CGFloat = 320
    private static let song = 8 * TimelineTime.ticksPerBar

    private func edit(_ edge: AudioPartEditor.Edge, _ points: CGFloat, _ part: TimelineRegion, clip: Clip?,
                      in document: TimelineDocument? = nil) -> AudioPartEditor.EdgeEdit? {
        ArrangeCanvas.edgeEdit(edge, dragPoints: points, laneWidth: Self.width, songTicks: Self.song,
                               region: part, in: document ?? TimelineDocument(lanes: [], regions: [part]),
                               clip: clip, mediaBPM: 120)
    }

    // MARK: 1 — the canvas moves an edge where the rules let it

    func testAMidiPartsEdgesMoveOnTheCanvas() throws {
        let bar = Self.bar
        let midi = Clip(name: "T1 notes", kind: .midi)
        let part = TimelineRegion(laneID: Self.lane, clipID: midi.id, startTick: 2 * bar, lengthTicks: 2 * bar)
        XCTAssertEqual(edit(.end, 40, part, clip: midi), .end(lengthTicks: 3 * bar), "the end moves out one bar")
        XCTAssertEqual(edit(.end, -40, part, clip: midi), .end(lengthTicks: bar), "and in one bar")
        XCTAssertEqual(edit(.start, 40, part, clip: midi), .start(tick: 3 * bar), "the start moves in one bar")
        XCTAssertNil(edit(.start, -40, part, clip: midi), "but not before the part's content starts")
        // A front-trimmed part can get its first bar back, and no more.
        let trimmed = try XCTUnwrap(part.trimmedStart(toTick: 3 * bar, bpm: 120))
        XCTAssertEqual(edit(.start, -40, trimmed, clip: midi), .start(tick: 2 * bar), "the hidden bar comes back")
        XCTAssertEqual(edit(.start, -80, trimmed, clip: midi), .start(tick: 2 * bar), "held at the content's start")
        // An end that would take a bar from a part still playing there is refused.
        let earlier = TimelineRegion(laneID: Self.lane, clipID: UUID(), startTick: 0, lengthTicks: 6 * bar)
        XCTAssertNil(edit(.end, 40, part, clip: midi, in: TimelineDocument(lanes: [], regions: [earlier, part])))
        // No slide, no scale, no part: no edit.
        XCTAssertNil(edit(.end, 0, part, clip: midi))
        XCTAssertNil(edit(.end, .nan, part, clip: midi))
        XCTAssertNil(ArrangeCanvas.edgeEdit(.end, dragPoints: 40, laneWidth: 0, songTicks: Self.song, region: part,
                                            in: TimelineDocument(lanes: [], regions: [part]), clip: midi, mediaBPM: 120))
        XCTAssertNil(ArrangeCanvas.edgeEdit(.end, dragPoints: 40, laneWidth: Self.width, songTicks: 0, region: part,
                                            in: TimelineDocument(lanes: [], regions: [part]), clip: midi, mediaBPM: 120))
        XCTAssertNil(edit(.end, 40, part, clip: midi, in: TimelineDocument(lanes: [], regions: [])),
                     "a part that is not in the song moves nothing")
    }

    func testAnAudioPartsEndStopsAtItsFileAndAVideoPartHasNoEdges() {
        let bar = Self.bar
        // One bar at 120 BPM is 2 s; the part starts at the file's first second.
        let fourSeconds = Clip(name: "T1 wave", kind: .audio, mediaRef: "t1.wav", nativeDurationSeconds: 4)
        let part = TimelineRegion(laneID: Self.lane, clipID: fourSeconds.id, startTick: 0, lengthTicks: bar)
        XCTAssertEqual(edit(.end, 40, part, clip: fourSeconds), .end(lengthTicks: 2 * bar), "to the file's end")
        XCTAssertEqual(edit(.end, 120, part, clip: fourSeconds), .end(lengthTicks: 2 * bar), "and never past it")
        let threeSeconds = Clip(name: "T1 short", kind: .audio, mediaRef: "t1.wav", nativeDurationSeconds: 3)
        XCTAssertNil(edit(.end, 40, part, clip: threeSeconds), "a bar more would play past the file")
        let unmeasured = Clip(name: "T1 old", kind: .audio, mediaRef: "t1.wav")
        XCTAssertNil(edit(.end, 40, part, clip: unmeasured), "a file of unknown length is not lengthened here")
        XCTAssertEqual(ArrangeCanvas.edgeBound(for: unmeasured), .media(seconds: 0))
        let video = Clip(name: "T1 film", kind: .video, mediaRef: "t1.mov")
        XCTAssertNil(ArrangeCanvas.edgeBound(for: video), "a video part does not play from the arrangement yet")
        XCTAssertNil(edit(.end, 40, part, clip: video))
        XCTAssertNil(ArrangeCanvas.edgeBound(for: nil), "a part whose clip is gone gets no handles")
        XCTAssertEqual(ArrangeCanvas.edgeBound(for: Clip(name: "T1", kind: .midi)), .unbounded)
    }

    // MARK: 2 — the grid

    func testAMidiStartMovesByBarsAndEverythingElseFollowsTheZoom() {
        let bar = Self.bar
        let midi = Clip(name: "T1", kind: .midi)
        let audio = Clip(name: "T1", kind: .audio, mediaRef: "t1.wav", nativeDurationSeconds: 60)
        // Two bars over 400 pt: 200 pt a bar, more than four targets — the beat grid.
        let zoomed: (CGFloat, Int) = (400, 2 * bar)
        let beatGrid = PartTrim.snapUnit(zoom: ArrangeCanvas.snapZoom(laneWidth: zoomed.0, songTicks: zoomed.1))
        XCTAssertEqual(beatGrid, TimelineTime.ticksPerBeat, "premise: this zoom snaps to beats")
        XCTAssertEqual(ArrangeCanvas.edgeUnit(.start, clip: midi, laneWidth: zoomed.0, songTicks: zoomed.1), bar,
                       "a MIDI start moves by whole bars — its notes sit on the song's bar lines")
        XCTAssertEqual(ArrangeCanvas.edgeUnit(.end, clip: midi, laneWidth: zoomed.0, songTicks: zoomed.1), beatGrid)
        XCTAssertEqual(ArrangeCanvas.edgeUnit(.start, clip: audio, laneWidth: zoomed.0, songTicks: zoomed.1), beatGrid)
        // A slide of less than half a bar on a MIDI start is no move.
        let part = TimelineRegion(laneID: Self.lane, clipID: midi.id, startTick: 2 * bar, lengthTicks: 2 * bar)
        XCTAssertNil(edit(.start, 16, part, clip: midi), "1.6 beats rounds back to the part's own bar")
        // The preview line sits where the edit leaves the edge, held on the lane.
        XCTAssertEqual(ArrangeCanvas.edgeX(.end(lengthTicks: 3 * bar), region: part, laneWidth: Self.width,
                                           songTicks: Self.song), 200)
        XCTAssertEqual(ArrangeCanvas.edgeX(.start(tick: 3 * bar), region: part, laneWidth: Self.width,
                                           songTicks: Self.song), 120)
        XCTAssertEqual(ArrangeCanvas.edgeX(.end(lengthTicks: 20 * bar), region: part, laneWidth: Self.width,
                                           songTicks: Self.song), Self.width, "a line past the song stays on the lane")
        XCTAssertNil(ArrangeCanvas.edgeX(.start(tick: 0), region: part, laneWidth: Self.width, songTicks: 0))
    }

    // MARK: 3 — the touch areas

    func testTheHandlesLeaveThePartsBodyAndItsNeighboursFree() throws {
        typealias Pair = (start: ClosedRange<Double>?, end: ClosedRange<Double>?)
        func frames(_ start: Double, _ end: Double, _ left: Double = 0, _ right: Double = 320) throws -> Pair {
            try XCTUnwrap(ArrangePartEdges.frames(startX: start, endX: end, leftLimit: left, rightLimit: right))
        }
        func check(_ pair: Pair, _ start: ClosedRange<Double>?, _ end: ClosedRange<Double>?, _ why: String) {
            XCTAssertEqual(pair.start, start, why)
            XCTAssertEqual(pair.end, end, why)
        }
        check(try frames(40, 160), 18...62, 138...182, "centred on a wide part's edges")
        check(try frames(100, 140), 56...100, 140...184, "outside a narrow part, so its body stays free")
        check(try frames(10, 40), nil, 40...84, "10 pt to the lane's start is less than half a target: no start handle")
        check(try frames(300, 320), 256...300, nil, "and no end handle at the lane's end")
        check(try frames(100, 140, 70, 175), 70...100, 140...175, "a neighbour 30 pt away caps the handle at its edge")
        check(try frames(40, 160, 30, 165), 30...62, 138...165, "a wide part's handle stops at its neighbours too")
        XCTAssertNil(ArrangePartEdges.frames(startX: 100, endX: 140, leftLimit: 100, rightLimit: 140),
                     "touching neighbours on both sides: no handle covers either of them")
        for (start, end, left, right) in [(40.0, 160.0, 0.0, 320.0), (100, 140, 0, 320), (100, 140, 70, 175),
                                          (40, 160, 30, 165), (0, 320, 0, 320), (160, 160, 0, 320)] {
            let pair = try frames(start, end, left, right)
            let both = [pair.start, pair.end].compactMap { $0 }
            for range in both {
                let width = range.upperBound - range.lowerBound
                XCTAssertGreaterThanOrEqual(width, AudioPartEditor.handleHitPoints / 2, "at least half a target")
                XCTAssertLessThanOrEqual(width, AudioPartEditor.handleHitPoints)
                XCTAssertGreaterThanOrEqual(range.lowerBound, left, "never over the left neighbour")
                XCTAssertLessThanOrEqual(range.upperBound, right, "never over the right neighbour")
            }
            if let s = pair.start, let e = pair.end {
                XCTAssertLessThanOrEqual(s.upperBound, e.lowerBound, "the two handles never overlap")
            }
            if end - start < 2 * AudioPartEditor.handleHitPoints {
                for range in both {
                    XCTAssertFalse(range.lowerBound < end && range.upperBound > start,
                                   "a narrow part's body is never under a handle")
                }
            }
        }
        XCTAssertNil(ArrangePartEdges.frames(startX: 20, endX: 10, leftLimit: 0, rightLimit: 320))
        XCTAssertNil(ArrangePartEdges.frames(startX: .nan, endX: 10, leftLimit: 0, rightLimit: 320))
        XCTAssertNil(ArrangePartEdges.frames(startX: 10, endX: 20, leftLimit: 15, rightLimit: 320), "a limit inside the part")
    }

    func testTheRoomIsBoundedByTheNearestPartsOnTheSameLane() {
        let other = UUID()
        let part = TimelineRegion(laneID: Self.lane, clipID: UUID(), startTick: 4 * Self.bar, lengthTicks: Self.bar)
        let before = TimelineRegion(laneID: Self.lane, clipID: UUID(), startTick: Self.bar, lengthTicks: Self.bar)
        let nearer = TimelineRegion(laneID: Self.lane, clipID: UUID(), startTick: 2 * Self.bar, lengthTicks: Self.bar)
        let after = TimelineRegion(laneID: Self.lane, clipID: UUID(), startTick: 6 * Self.bar, lengthTicks: Self.bar)
        let elsewhere = TimelineRegion(laneID: other, clipID: UUID(), startTick: 5 * Self.bar, lengthTicks: Self.bar)
        let doc = TimelineDocument(lanes: [], regions: [before, part, nearer, after, elsewhere])
        let room = ArrangePartEdges.room(for: part, in: doc)
        XCTAssertEqual(room.left, 3 * Self.bar, "the nearest end before it")
        XCTAssertEqual(room.right, 6 * Self.bar, "the nearest start after it — a part on another lane does not count")
        let alone = ArrangePartEdges.room(for: part, in: TimelineDocument(lanes: [], regions: [part]))
        XCTAssertEqual(alone.left, 0)
        XCTAssertNil(alone.right, "nothing after it: the song's end")
    }

    // MARK: 4 — SOURCE: one write per gesture, from a leaf the canvas only mounts

    func testTheLeafWritesOnceOnReleaseAndTheCanvasOnlyMountsIt() throws {
        let leaf = try source(Self.leafPath)
        XCTAssertEqual(Self.occurrences(of: "trimRegionStart(", in: leaf), 1, "one start writer")
        XCTAssertEqual(Self.occurrences(of: "resizeRegion(", in: leaf), 1, "one end writer")
        XCTAssertEqual(Self.occurrences(of: "@GestureState", in: leaf), 1, "the slide is the leaf's one finger-rate state")
        XCTAssertEqual(Self.occurrences(of: "DragGesture(", in: leaf), 1)
        guard let ended = Self.bracedBody(after: ".onEnded {", in: leaf),
              let moving = Self.bracedBody(after: ".updating($drag) {", in: leaf),
              let ask = Self.bracedBody(after: "bpm: Double) -> AudioPartEditor.EdgeEdit? {", in: leaf) else {
            return XCTFail("ANCHOR MISSING: the leaf's `.onEnded`, `.updating` or its one question (#408)")
        }
        XCTAssertTrue(ended.contains("timeline.trimRegionStart(id: region.id, toTick: tick, bpm: bpm)"))
        XCTAssertTrue(ended.contains("timeline.resizeRegion(id: region.id, lengthTicks: lengthTicks)"))
        XCTAssertFalse(moving.contains("timeline"), "the slide touches the store while the finger moves")
        XCTAssertTrue(ask.contains("ArrangeCanvas.edgeEdit("), "the one question is the canvas front end")
        XCTAssertEqual(Self.occurrences(of: "ArrangeCanvas.edgeEdit(", in: leaf), 1, "asked in one place")
        XCTAssertTrue(ended.contains("edit(edge, points: Double(slide.translation.width), bpm: bpm)"))
        XCTAssertTrue(leaf.contains("let landing = edit(drag.edge, points: drag.points, bpm: bpm)"))
        guard let hold = leaf.range(of: "LongPressGesture(minimumDuration: 0.3)"),
              let then = leaf.range(of: ".sequenced(before: DragGesture(minimumDistance: 0))") else {
            return XCTFail("the handles no longer hold first, so a swipe on the canvas would not scroll the song")
        }
        XCTAssertLessThan(hold.lowerBound, then.lowerBound)
        XCTAssertTrue(leaf.contains("private var mediaBPM: Double? {"), "the tempo is computed at each read")
        XCTAssertTrue(leaf.contains("PartSplit.mediaBPM(for: region, clip: clip, projectBPM: player.preflightTempo)"))
        for hot in ["currentTick", "TimelineView(", "Timer", "UserDefaults", "@AppStorage"] {
            XCTAssertFalse(leaf.contains(hot), "the leaf reads `\(hot)` — a finger-rate leaf must not observe the song")
        }
        // The canvas mounts the leaf and writes no edge itself.
        let canvas = try source(Self.canvasPath)
        for write in ["trimRegionStart(", "resizeRegion("] {
            XCTAssertFalse(canvas.contains(write), "the canvas writes `\(write)` — the leaf owns the edge write")
        }
        guard let mount = canvas.range(of: "ArrangePartEdgeHandles(region: pair.0, document: document, clip: pair.1,") else {
            return XCTFail("ANCHOR MISSING: the canvas no longer mounts the edge handles")
        }
        let from = canvas.index(mount.lowerBound, offsetBy: -220, limitedBy: canvas.startIndex) ?? canvas.startIndex
        let gate = String(canvas[from..<mount.lowerBound])
        XCTAssertTrue(gate.contains("arrangeable"), "the handles appear only on a MIDI or audio track")
        XCTAssertTrue(gate.contains("ArrangeCanvas.edgeBound(for: pair.1) != nil"), "and only for a part kind with an edge bound")
        XCTAssertTrue(canvas.contains("let arrangeable = TrackParts.arrangeable(row.id, in: document)"))
    }

    // MARK: - Helpers

    private static let leafPath = "Sources/Echoelmusic/Studio/ArrangePartEdgeHandles.swift"
    private static let canvasPath = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"

    static func bracedBody(after head: String, in code: String) -> String? {
        guard let start = code.range(of: head), head.hasSuffix("{") else { return nil }
        var depth = 0
        var i = code.index(before: start.upperBound)
        while i < code.endIndex {
            if code[i] == "{" {
                depth += 1
            } else if code[i] == "}" {
                depth -= 1
                if depth == 0 { return String(code[start.upperBound..<i]) }
            }
            i = code.index(after: i)
        }
        return nil
    }

    static func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func source(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { break }
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("source tree not present under \(dir.path)")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}
