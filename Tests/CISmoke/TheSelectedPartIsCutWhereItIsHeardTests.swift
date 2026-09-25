// TheSelectedPartIsCutWhereItIsHeardTests.swift
// Echoel — WA4 critical path 5: edit the part selected on the Arrange canvas.
//
// WHAT THIS PINS. `Studio/SelectedPartBar.swift` acts on the canvas selection — earlier, later,
// split, copy, remove — through `TimelineStore`'s existing methods only. The new behaviour is
// SPLIT, and its risk is not a crash but a jump in the sound: `TimelineRegion.split(at:bpm:)`
// advances the second half's media offset by the elapsed time at the tempo it is handed, while
// the engine plays a WARPED part's media `rate×` faster or slower than song time
// (`AudioRegionPlayback.filePositionSeconds`). Handed the song tempo, a warped split restarts
// the file at the wrong place.
//
// 1. END-TO-END (pure): the cut is the song-grid bar nearest the part's middle, else the nearest
//    beat, else none — never a free tick.
// 2. END-TO-END (pure): `PartSplit.mediaBPM` is the song tempo for an unwarped part and the
//    tempo at which media elapses for a warped one; nil for a tempo no split may use.
// 3. END-TO-END over the shipped value types: a warped part split through `mediaBPM` continues
//    in the file EXACTLY where the unsplit part would be at the cut (the engine's own position
//    map) — and the same split at the song tempo does NOT, which is what makes claim 3 able to
//    fail for its named reason (#367).
// 3b. END-TO-END (pure): a cut that would change which overlapping part plays is refused —
//    the second half starts later than its original and would win `activeRegion` over a part
//    that covered it (review MEDIUM-1). Counterweights: a lone part and a cut after a nested
//    part has ended are allowed — overlap alone refuses nothing.
// 4. SOURCE: the bar writes only through the store; its body reads neither the tempo, the clip
//    grid nor the position; Split is gated on 3b; the Workstation is its one door.
// 5. END-TO-END (pure): TRIM moves an edge ONE grid step INWARD (bar, else beat, else nothing) —
//    it only takes material away, so "Trim" promises exactly what it does. 5b: a trim may change
//    nothing but the ticks the part lets go of — a start trim that would win an overlap it used
//    to lose is refused; revealing a buried part underneath is allowed (that is what a trim is).
//
// Grading (§0, no Swift toolchain in a web session): claims 1–3 HAND-TRACED against the types as
// written (`TempoMatch.stretchRate`, `StretchPlan.resolve`, `TimelineRegion.split`,
// `AudioRegionPlayback.filePositionSeconds`); claim 4 driven in Python against this tree. On the
// parent (c5c938ccd) `PartSplit` does not exist, so the bundle does not build there — ONE
// absence (#486); every claim is a FORWARD guard. NOT covered: that the cut is inaudible on a
// device (codec priming, the pre-rendered Beats buffer) — a device probe.
// NEEDS-FOUNDER-VERIFY: import a loop, turn Warp on at a song tempo different from the file's,
// select the part on the canvas, Split — play across the cut: no jump, no repeat. Then Trim start
// on the second half — the audio starts one bar later in the file, not from the file's top.
// (Claims 5/5b added with the Trim slice: on its parent `PartTrim` does not exist — ONE absence,
// FORWARD guards; driven by hand-trace against `TimelineScheduling` as written.)

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSelectedPartIsCutWhereItIsHeardTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let beat = TimelineTime.ticksPerBeat
    private static let laneID = UUID()

    // MARK: 1 — where the cut falls

    func testTheCutSnapsToTheSongGrid() {
        func part(_ start: Int, _ length: Int) -> TrackParts.Part {
            TrackParts.Part(id: UUID(), startTick: start, lengthTicks: length)
        }
        XCTAssertEqual(PartSplit.tick(for: part(0, 4 * Self.bar)), 2 * Self.bar,
                       "a four-bar part is cut on its middle bar line")
        XCTAssertEqual(PartSplit.tick(for: part(Self.bar, Self.bar)), Self.bar + 2 * Self.beat,
                       "a one-bar part has no bar line inside it — the middle beat")
        XCTAssertEqual(PartSplit.tick(for: part(0, 2 * Self.beat)), Self.beat)
        XCTAssertNil(PartSplit.tick(for: part(0, Self.beat)), "a one-beat part has no grid line inside it")
        if let cut = PartSplit.tick(for: part(Self.beat, 3 * Self.bar)) {
            XCTAssertTrue(cut > Self.beat && cut < Self.beat + 3 * Self.bar, "the cut is inside the part")
            XCTAssertEqual(cut % Self.bar, 0, "an off-grid part is still cut on the song's bar grid")
        } else {
            XCTFail("a three-bar part must be splittable")
        }
    }

    // MARK: 2 — the tempo media elapses at

    func testTheMediaTempoFollowsWarp() throws {
        let clip = Clip(name: "Loop", kind: .audio, mediaRef: "Media/Audio/loop.wav", nativeBPM: 100)
        let plain = TimelineRegion(laneID: Self.laneID, clipID: clip.id, startTick: 0,
                                   lengthTicks: 4 * Self.bar)
        var warped = plain
        warped.warpEnabled = true

        XCTAssertEqual(PartSplit.mediaBPM(for: plain, clip: clip, projectBPM: 120), 120)
        XCTAssertEqual(try XCTUnwrap(PartSplit.mediaBPM(for: warped, clip: clip, projectBPM: 120)),
                       100, accuracy: 1e-9, "a warped 100-BPM file elapses at its own tempo")
        XCTAssertEqual(PartSplit.mediaBPM(for: warped, clip: nil, projectBPM: 120), 120,
                       "an unknown clip tempo cannot warp — the song tempo")
        XCTAssertNil(PartSplit.mediaBPM(for: plain, clip: clip, projectBPM: .nan))
        XCTAssertNil(PartSplit.mediaBPM(for: plain, clip: clip, projectBPM: 0))
    }

    // MARK: 3 — the cut is seamless in the file

    func testAWarpedSplitContinuesWhereTheFileWas() throws {
        let songBPM = 120.0
        let clip = Clip(name: "Loop", kind: .audio, mediaRef: "Media/Audio/loop.wav", nativeBPM: 100)
        let region = TimelineRegion(laneID: Self.laneID, clipID: clip.id, startTick: Self.bar,
                                    lengthTicks: 4 * Self.bar, contentOffsetSeconds: 1.5,
                                    warpEnabled: true)
        let part = TrackParts.Part(id: region.id, startTick: region.startTick,
                                   lengthTicks: region.lengthTicks)
        let cut = try XCTUnwrap(PartSplit.tick(for: part))
        let rate = StretchPlan.resolve(mode: region.stretchMode, warpEnabled: true,
                                       nativeBPM: clip.nativeBPM, projectBPM: songBPM,
                                       capabilities: StretchMode.timelineCapabilities).rate
        XCTAssertNotEqual(rate, 1, "precondition: the part really is stretched")
        let heardAtCut = try XCTUnwrap(AudioRegionPlayback.filePositionSeconds(
            for: region, atTick: cut, bpm: songBPM, stretchRate: rate))

        let mediaBPM = try XCTUnwrap(PartSplit.mediaBPM(for: region, clip: clip, projectBPM: songBPM))
        let (first, second) = try XCTUnwrap(region.split(at: cut, bpm: mediaBPM))
        XCTAssertEqual(first.endTick, second.startTick)
        XCTAssertEqual(second.contentOffsetSeconds, heardAtCut, accuracy: 1e-9, """
            the second half must start in the file where the whole part was at the cut — \
            anything else is a jump or a repeat in the middle of a loop
            """)

        let (_, naive) = try XCTUnwrap(region.split(at: cut, bpm: songBPM))
        XCTAssertGreaterThan(abs(naive.contentOffsetSeconds - heardAtCut), 0.1, """
            COUNTERWEIGHT: splitting at the song tempo must be measurably wrong for a warped \
            part, or claim 3 could not fail for its reason
            """)
    }

    // MARK: 3b — a cut never changes WHO plays (review MEDIUM-1)

    func testACutThatWouldUnburyAPartIsRefused() {
        let clipID = UUID()
        let a = TimelineRegion(laneID: Self.laneID, clipID: clipID, startTick: 0,
                               lengthTicks: 4 * Self.bar)
        let b = TimelineRegion(laneID: Self.laneID, clipID: clipID, startTick: Self.bar,
                               lengthTicks: 4 * Self.bar)
        let overlapped = TimelineDocument(lanes: [], regions: [a, b])
        // Bars 2–4 belong to B (the later start). A's second half would start at bar 2 — later
        // than B — and take bars 2–4 from it.
        XCTAssertEqual(TimelineScheduling.activeRegion(in: overlapped, laneID: Self.laneID,
                                                       at: 2 * Self.bar)?.id, b.id,
                       "precondition: B is heard at the cut")
        XCTAssertFalse(PartSplit.keepsWhoPlays(regionID: a.id, atTick: 2 * Self.bar, in: overlapped),
                       "cutting A there would un-bury it over B — the cut must be refused")

        // COUNTERWEIGHTS: overlap alone refuses nothing.
        let alone = TimelineDocument(lanes: [], regions: [a])
        XCTAssertTrue(PartSplit.keepsWhoPlays(regionID: a.id, atTick: 2 * Self.bar, in: alone))
        let long = TimelineRegion(laneID: Self.laneID, clipID: clipID, startTick: 0,
                                  lengthTicks: 8 * Self.bar)
        let inner = TimelineRegion(laneID: Self.laneID, clipID: clipID, startTick: Self.bar,
                                   lengthTicks: Self.bar)
        let nested = TimelineDocument(lanes: [], regions: [long, inner])
        XCTAssertTrue(PartSplit.keepsWhoPlays(regionID: long.id, atTick: 4 * Self.bar, in: nested),
                      "a cut after the inner part has ended changes nobody's turn")
        XCTAssertFalse(PartSplit.keepsWhoPlays(regionID: UUID(), atTick: Self.bar, in: nested),
                       "an unknown part cannot be cut")
    }

    // MARK: 5 — Trim: one grid step inward, and only what the part lets go of

    func testTrimMovesOneGridStepInward() {
        func part(_ start: Int, _ length: Int) -> TrackParts.Part {
            TrackParts.Part(id: UUID(), startTick: start, lengthTicks: length)
        }
        let fourBars = part(0, 4 * Self.bar)
        XCTAssertEqual(PartTrim.startTick(for: fourBars), Self.bar, "the first bar goes")
        XCTAssertEqual(PartTrim.endTick(for: fourBars), 3 * Self.bar, "the last bar goes")
        // Off the grid: the edge snaps to the next line inside, never a free tick.
        let offGrid = part(100, 2 * Self.bar)
        XCTAssertEqual(PartTrim.startTick(for: offGrid), Self.bar)
        XCTAssertEqual(PartTrim.endTick(for: offGrid), 2 * Self.bar)
        // No bar line inside → a beat line.
        let twoBeats = part(0, 2 * Self.beat)
        XCTAssertEqual(PartTrim.startTick(for: twoBeats), Self.beat)
        XCTAssertEqual(PartTrim.endTick(for: twoBeats), Self.beat)
        // One beat or less has no grid line strictly inside: nothing to trim.
        let oneBeat = part(0, Self.beat)
        XCTAssertNil(PartTrim.startTick(for: oneBeat))
        XCTAssertNil(PartTrim.endTick(for: oneBeat))
        XCTAssertNil(PartTrim.startTick(for: part(0, 1)))
    }

    func testATrimThatWouldStealBarsIsRefused() {
        let clipID = UUID()
        // C (placed FIRST) starts at bar 1 and wins bar 1 over A (start 0). Trimming A's start to
        // bar 1 ties the starts, and the tie goes to the later placement — A — so bar 1, which A
        // still covers, would change hands. Refused.
        let c = TimelineRegion(laneID: Self.laneID, clipID: clipID, startTick: Self.bar,
                               lengthTicks: Self.bar)
        let a = TimelineRegion(laneID: Self.laneID, clipID: clipID, startTick: 0,
                               lengthTicks: 4 * Self.bar)
        let stealing = TimelineDocument(lanes: [], regions: [c, a])
        XCTAssertEqual(TimelineScheduling.activeRegion(in: stealing, laneID: Self.laneID,
                                                       at: Self.bar)?.id, c.id,
                       "precondition: C is heard at bar 1")
        let aPart = TrackParts.Part(id: a.id, startTick: a.startTick, lengthTicks: a.lengthTicks)
        XCTAssertNil(PartTrim.startTrim(aPart, in: stealing),
                     "trimming A's start would take bar 1 from C — the trim must be refused")

        // COUNTERWEIGHTS: a lone part trims both edges; revealing a buried part is what a trim IS.
        let alone = TimelineDocument(lanes: [], regions: [a])
        XCTAssertEqual(PartTrim.startTrim(aPart, in: alone), Self.bar)
        XCTAssertEqual(PartTrim.endTrim(aPart, in: alone), 3 * Self.bar)
        let under = TimelineRegion(laneID: Self.laneID, clipID: clipID, startTick: 0,
                                   lengthTicks: 4 * Self.bar)
        let over = TimelineRegion(laneID: Self.laneID, clipID: clipID, startTick: Self.bar,
                                  lengthTicks: 2 * Self.bar)
        let layered = TimelineDocument(lanes: [], regions: [under, over])
        let overPart = TrackParts.Part(id: over.id, startTick: over.startTick,
                                       lengthTicks: over.lengthTicks)
        XCTAssertEqual(PartTrim.startTrim(overPart, in: layered), 2 * Self.bar,
                       "the top part lets go of bar 1 and the part underneath is heard there — allowed")
        XCTAssertEqual(PartTrim.endTrim(overPart, in: layered), Self.bar,
                       "…and the same at its end")
        let unknown = TrackParts.Part(id: UUID(), startTick: 0, lengthTicks: 4 * Self.bar)
        XCTAssertNil(PartTrim.startTrim(unknown, in: layered), "an unknown part cannot be trimmed")
        XCTAssertNil(PartTrim.endTrim(unknown, in: layered))
    }

    // MARK: 4 — source: store-only writes, a cold body, one door

    func testTheBarWritesThroughTheStoreAndReadsColdState() throws {
        let file = try code("Sources/Echoelmusic/Studio/SelectedPartBar.swift")
        guard let bodyStart = file.range(of: "var body: some View {"),
              let splitStart = file.range(of: "private func split(_ regionID: UUID, at tick: Int) {"),
              bodyStart.upperBound < splitStart.lowerBound else {
            return XCTFail("ANCHOR MISSING: the bar's body and its Split handler (#454)")
        }
        let body = String(file[bodyStart.upperBound..<splitStart.lowerBound])
        for banned in ["preflightTempo", "clipStore", "currentTick", "player."] {
            XCTAssertFalse(body.contains(banned),
                           "the bar's body reads `\(banned)` — tempo and clip belong inside the Split handler")
        }
        for write in ["TrackParts.move(part, toStartTick:", "TrackParts.duplicate(part, timeline: timeline)",
                      "TrackParts.remove(part, timeline: timeline)"] {
            XCTAssertTrue(body.contains(write), "the bar writes through the store's API: `\(write)`")
        }
        let handler = String(file[splitStart.upperBound...])
        XCTAssertTrue(handler.contains("PartSplit.mediaBPM(for: region, clip: clipStore.clip(id: region.clipID),"),
                      "Split asks the media tempo, never hands the song tempo straight through")
        XCTAssertTrue(handler.contains("timeline.splitRegion(id: regionID, atTick: tick, bpm: bpm)"))
        XCTAssertTrue(body.contains("PartSplit.keepsWhoPlays(regionID: regionID, atTick: $0,"),
                      "Split is enabled only when the cut keeps who plays (review MEDIUM-1)")
        XCTAssertTrue(body.contains("if splittable, let cut { split(regionID, at: cut) }"),
                      "the action re-checks the same answer the button was enabled by")
        // Trim — enabled by the same answers the actions use, written through the store.
        for needle in ["let trims = Trims(start: PartTrim.startTrim(part, in: document),",
                       "endLength: PartTrim.endTrim(part, in: document))",
                       "if let tick = trims.start { trimStart(regionID, to: tick) }",
                       "timeline.resizeRegion(id: regionID, lengthTicks: length)"] {
            XCTAssertTrue(body.contains(needle), "the bar's Trim lost `\(needle)`")
        }
        XCTAssertTrue(handler.contains("timeline.trimRegionStart(id: regionID, toTick: tick, bpm: bpm)"),
                      "Trim start writes through the store's own front-trim")
        XCTAssertEqual(handler.components(separatedBy: "PartSplit.mediaBPM(for: region, clip: clipStore.clip(id: region.clipID),").count - 1, 2,
                       "Split AND Trim start ask the media tempo — the start trim moves the media offset too")

        let workstation = try code("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertEqual(workstation.components(separatedBy: "SelectedPartBar()").count - 1, 1)
    }

    // MARK: helpers

    private func code(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}
