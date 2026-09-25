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
// 4. SOURCE: the bar writes only through the store; its body reads neither the tempo, the clip
//    grid nor the position; the Workstation is its one door.
//
// Grading (§0, no Swift toolchain in a web session): claims 1–3 HAND-TRACED against the types as
// written (`TempoMatch.stretchRate`, `StretchPlan.resolve`, `TimelineRegion.split`,
// `AudioRegionPlayback.filePositionSeconds`); claim 4 driven in Python against this tree. On the
// parent (c5c938ccd) `PartSplit` does not exist, so the bundle does not build there — ONE
// absence (#486); every claim is a FORWARD guard. NOT covered: that the cut is inaudible on a
// device (codec priming, the pre-rendered Beats buffer) — a device probe.
// NEEDS-FOUNDER-VERIFY: import a loop, turn Warp on at a song tempo different from the file's,
// select the part on the canvas, Split — play across the cut: no jump, no repeat.

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
