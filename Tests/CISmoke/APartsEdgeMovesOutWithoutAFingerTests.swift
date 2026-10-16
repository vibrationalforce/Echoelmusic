// APartsEdgeMovesOutWithoutAFingerTests.swift
// Ultraplan-A11 (2026-10-16): the arrange canvas's edge handles (One World T1) and the audio
// editor's are hidden from VoiceOver, and the part bar's Trim buttons only move an edge INWARD. So
// a part could be lengthened, or started earlier, only by a finger — the two headers said so as an
// open gap. The part bar's title now carries two VoiceOver actions that move an edge OUTWARD to the
// next bar line, asking the handles' own rule (`ArrangeCanvas.barLineEdit` → `PartTrim.edgeEdit`
// with `ArrangeCanvas.edgeBound`, #416).
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–3 are END-TO-END over `ArrangeCanvas.barLineEdit` (nonisolated, Foundation-only
//     values): a bar LINE, not a bar; the content's start, a neighbour, the file's end and an
//     unknown file length refuse; a video part and a missing part get nothing.
//   · Claim 4 is a SOURCE-TEXT SCAN — the bar is a `View` with private members: the two actions sit
//     on the title, the handler writes through the two store calls the handles use, and the clip
//     grid and the tempo are read in the handler, never in the rendered body.
//   · DEVICE PROBE, open: VoiceOver lists both actions on "Selected part · …", the announcement is
//     spoken, and one Undo takes the move back.
//
// HONEST GRADING against the parent (§3): the file does not COMPILE there — it names
// `ArrangeCanvas.barLineEdit`, which this commit creates — ONE absence (#486), every claim a
// FORWARD guard. Expectations derived by hand from `PartTrim.edgeEdit`'s rules (#442): unit = one
// bar, the outward end takes the first grid line after the end (`floorGrid(end) + bar`), the
// outward start the line before the start (`floorGrid(start − 1)`). Mutants and the claim each
// turns red: "one bar" instead of "the bar line" (1, the mid-bar case moves two lines' worth) · a
// bound of `.unbounded` for audio (2) · the actions on a Button that can be disabled (4) · the
// handler in the rendered body (4, and `TheSelectedPartIsCutWhereItIsHeardTests` claim's ban).

import Foundation
import XCTest
@testable import Echoelmusic

final class APartsEdgeMovesOutWithoutAFingerTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let beat = TimelineTime.ticksPerBeat
    private static let lane = UUID()

    private func step(_ edge: AudioPartEditor.Edge, _ part: TimelineRegion, clip: Clip?,
                      among others: [TimelineRegion] = []) -> AudioPartEditor.EdgeEdit? {
        ArrangeCanvas.barLineEdit(edge, region: part, in: TimelineDocument(lanes: [], regions: others + [part]),
                                  clip: clip, mediaBPM: 120)
    }

    // MARK: 1 — a MIDI part reaches the next bar line outward, never further

    func testAMidiPartsEdgesMoveOutToTheNextBarLine() throws {
        let bar = Self.bar
        let midi = Clip(name: "A11 notes", kind: .midi)
        let part = TimelineRegion(laneID: Self.lane, clipID: midi.id, startTick: 2 * bar, lengthTicks: 2 * bar)
        XCTAssertEqual(step(.end, part, clip: midi), .end(lengthTicks: 3 * bar), "the end moves out one bar line")
        XCTAssertNil(step(.start, part, clip: midi), "the start never moves before the content's start")

        // A front-trimmed part gets its hidden bar back — one bar line, not two.
        let trimmed = try XCTUnwrap(part.trimmedStart(toTick: 3 * bar + Self.beat, bpm: 120))
        XCTAssertEqual(trimmed.startTick, 3 * bar + Self.beat, "premise: the start sits a beat after a bar line")
        XCTAssertEqual(step(.start, trimmed, clip: midi), .start(tick: 3 * bar),
                       "a mid-bar start reaches the bar line it sits after, never the one before that")

        // A mid-bar end reaches the bar line after it, not a whole bar past it.
        var short = part
        short.lengthTicks = bar + Self.beat
        XCTAssertEqual(step(.end, short, clip: midi), .end(lengthTicks: 2 * bar))
    }

    // MARK: 2 — the rules refuse where the handles refuse

    func testTheMoveIsRefusedWhereTheHandlesAreRefused() {
        let bar = Self.bar
        let midi = Clip(name: "A11 notes", kind: .midi)
        let part = TimelineRegion(laneID: Self.lane, clipID: midi.id, startTick: 2 * bar, lengthTicks: 2 * bar)
        let still = TimelineRegion(laneID: Self.lane, clipID: UUID(), startTick: 0, lengthTicks: 6 * bar)
        XCTAssertNil(step(.end, part, clip: midi, among: [still]),
                     "an end that would take a bar from a part still playing there is refused")

        // An audio part ends inside its file; a file of unknown length is never extended.
        var known = Clip(name: "A11 audio", kind: .audio)
        known.nativeDurationSeconds = 8 * 2   // eight bars at 120 bpm (2 s a bar)
        let audio = TimelineRegion(laneID: Self.lane, clipID: known.id, startTick: 0, lengthTicks: 8 * bar)
        XCTAssertNil(step(.end, audio, clip: known), "the file ends where the part ends")
        var shorter = audio
        shorter.lengthTicks = 7 * bar
        XCTAssertEqual(step(.end, shorter, clip: known), .end(lengthTicks: 8 * bar), "and up to there it moves")
        let unknown = Clip(name: "A11 unknown", kind: .audio)
        XCTAssertNil(step(.end, shorter, clip: unknown), "an unknown length refuses (the canvas's own bound)")
    }

    // MARK: 3 — no bound, no part: nothing

    func testAPartWithoutAnEdgeBoundGetsNothing() {
        let bar = Self.bar
        let video = Clip(name: "A11 video", kind: .video)
        let part = TimelineRegion(laneID: Self.lane, clipID: video.id, startTick: bar, lengthTicks: bar)
        XCTAssertNil(step(.end, part, clip: video), "a picture part's edge rule is not decided")
        XCTAssertNil(step(.end, part, clip: nil), "a part whose clip is gone")
        let midi = Clip(name: "A11 notes", kind: .midi)
        let gone = TimelineRegion(laneID: Self.lane, clipID: midi.id, startTick: bar, lengthTicks: bar)
        XCTAssertNil(ArrangeCanvas.barLineEdit(.end, region: gone, in: TimelineDocument(lanes: [], regions: []),
                                               clip: midi, mediaBPM: 120), "a part not in the piece")
        XCTAssertEqual(ArrangeCanvas.edgeBound(for: midi), .unbounded, "counterweight: the canvas's MIDI bound")
    }

    // MARK: 4 — the actions sit on the title; the handler writes through the store, cold

    func testTheActionsSitOnTheTitleAndWriteThroughTheStore() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let file = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(
            "Sources/Echoelmusic/Studio/SelectedPartBar.swift"), encoding: .utf8))
        guard let title = file.range(of: "private func headingTitle(_ title: String, regionID: UUID) -> some View {"),
              let titleEnd = file.range(of: "\n    }\n", range: title.upperBound..<file.endIndex) else {
            return XCTFail("`headingTitle` moved — re-anchor")
        }
        let titleBody = String(file[title.upperBound..<titleEnd.lowerBound])
        XCTAssertTrue(titleBody.contains(".accessibilityAction(named: \"Start from the bar line before\") { moveEdgeOut(.start, regionID) }"))
        XCTAssertTrue(titleBody.contains(".accessibilityAction(named: \"Lengthen to the next bar line\") { moveEdgeOut(.end, regionID) }"))
        XCTAssertEqual(file.components(separatedBy: "headingTitle(title, regionID: regionID)").count - 1, 3,
                       "every layout the bar may pick carries the actions")

        guard let handler = file.range(of: "private func moveEdgeOut(_ edge: AudioPartEditor.Edge, _ regionID: UUID) {"),
              let handlerEnd = file.range(of: "\n    }\n", range: handler.upperBound..<file.endIndex) else {
            return XCTFail("`moveEdgeOut` moved — re-anchor")
        }
        let move = String(file[handler.upperBound..<handlerEnd.lowerBound])
        for needle in ["ArrangeCanvas.barLineEdit(edge, region: region, in: document, clip: clip,",
                       "PartSplit.mediaBPM(for: region, clip: clip, projectBPM: player.preflightTempo)",
                       "timeline.trimRegionStart(id: regionID, toTick: tick, bpm: bpm)",
                       "timeline.resizeRegion(id: regionID, lengthTicks: lengthTicks)",
                       "String(localized: \"That edge cannot move further out here.\")"] {
            XCTAssertTrue(move.contains(needle), "the edge-out handler lost `\(needle)`")
        }
        guard let body = file.range(of: "var body: some View {"),
              let trims = file.range(of: "private struct Trims {") else {
            return XCTFail("the bar's body or `Trims` moved — re-anchor")
        }
        XCTAssertLessThan(trims.lowerBound, handler.lowerBound, "the handler sits outside the rendered body")
        XCTAssertLessThan(body.lowerBound, title.lowerBound)
    }
}
