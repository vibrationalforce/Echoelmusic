// TheTrackHeadSitsOnTheCanvasTests.swift
// Echoel — the arrange canvas's name gutter IS the head of every track it draws: a tap selects
// the track and opens its header under the canvas, and the card list below keeps a card only for
// the open track and for tracks the canvas cannot draw (Workstation redesign A5, founder
// 2026-10-01).
//
// WHY: both mockups the founder pointed at („Das angehängte Bild gefällt mir auch") put each
// track's head at the left of its own lane — one row per track, name and lane side by side. The
// plate drew every track TWICE: once as a canvas row, once more as a card in a list underneath,
// so a five-track song read as ten rows and the head sat a screen away from the lane it names.
// On a phone two 44 pt Mute/Solo switches do not fit a 96 pt gutter beside a name, so the gutter
// SELECTS and the one Mute/Solo stays in the open track's header — still exactly one control
// each, now one tap away from the lane.
//
// THE THREE CLAIMS:
// 1. One pure rule decides which tracks keep a card: the open one, and every track the canvas
//    does not draw (a bio curve, a track without parts) — so every track has exactly one head
//    (RUNTIME, on `ArrangeCanvas.listsCard`, driven through `ArrangeCanvas.rows`).
// 2. The gutter is a selection target: it calls `selection.toggleTrack` for the tap AND for
//    VoiceOver, says selected as a trait and as a ring (never colour alone), is one accessible
//    element instead of a hidden one, and the canvas row is 44 pt tall. The list asks the rule,
//    and an audio track's pitch and part-tempo rows live under its OPEN head.
// 3. Counterweights: the gutter mutes and solos nothing (no `Button(`, no `TrackMix.flip`), the
//    flips stay exactly once each in the Workstation, and the open track still mounts its
//    inspector and arm toggle.
//
// GRADING (§0/§3, no Swift toolchain in a web session — transcribed in Python against both
// trees): claim 1 is a FORWARD guard on a function this commit creates — it cannot compile on
// the parent, so no assertion in this file has a verdict there; re-derived by hand on the
// fixture: nothing open → bio lane yes, keys no, empty lane yes; keys open → keys yes. Claims 2–3
// are SOURCE scans: work tree green; on the parent claim 2 is red by ABSENCE (`listsCard`, the
// tap, the ring) — one absence (#486) — except `rowHeight: CGFloat = 44`, a REGRESSION guard red
// there for its named reason (40); claim 3 is COUNTERWEIGHTS, green on both. DEVICE PROBE, open:
// the gutter is found as the place to open a track, the ring reads on every hue, and the open
// header under the canvas is understood as belonging to the ringed row.

import XCTest
@testable import Echoelmusic

final class TheTrackHeadSitsOnTheCanvasTests: XCTestCase {

    private static let canvas = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let bar = TimelineTime.ticksPerBar

    // One fixture VALUE per lane — never a factory (#1419).
    private static let keysLane = TimelineLane(name: "Keys", kind: .midi)
    private static let bioLane = TimelineLane(name: "Body", kind: .midi, isBio: true)
    private static let emptyLane = TimelineLane(name: "Loop", kind: .audio)

    // MARK: 1 — one rule: every track has exactly one head

    func testEveryTrackHasExactlyOneHead() {
        let clip = UUID()
        let doc = TimelineDocument(
            lanes: [Self.bioLane, Self.keysLane, Self.emptyLane],
            regions: [TimelineRegion(laneID: Self.bioLane.id, clipID: clip, startTick: 0, lengthTicks: Self.bar),
                      TimelineRegion(laneID: Self.keysLane.id, clipID: clip, startTick: 0, lengthTicks: Self.bar)])
        let rows = ArrangeCanvas.rows(WorkstationSummary(document: doc))
        XCTAssertEqual(rows.map(\.id), [Self.keysLane.id], "the fixture's canvas draws Keys only")

        XCTAssertFalse(ArrangeCanvas.listsCard(Self.keysLane.id, open: nil, canvasRows: rows),
                       "a drawn, closed track's head is its canvas gutter — no second card")
        XCTAssertTrue(ArrangeCanvas.listsCard(Self.bioLane.id, open: nil, canvasRows: rows),
                      "a bio curve is not drawn on the canvas — it keeps its card")
        XCTAssertTrue(ArrangeCanvas.listsCard(Self.emptyLane.id, open: nil, canvasRows: rows),
                      "a track with no parts is not drawn — it keeps its card, or it has no head at all")
        XCTAssertTrue(ArrangeCanvas.listsCard(Self.keysLane.id, open: Self.keysLane.id, canvasRows: rows),
                      "the OPEN track's card is its header, with the one Mute and Solo")
        XCTAssertTrue(ArrangeCanvas.listsCard(Self.keysLane.id, open: nil, canvasRows: []),
                      "with no canvas at all, every track keeps its card")
    }

    // MARK: 2 — the gutter selects; the list asks the rule

    func testTheGutterSelectsAndTheListAsksTheRule() throws {
        let canvas = SourceText.codeOnly(try text(Self.canvas))
        let gutter = try slice(canvas, from: "private func nameGutter(", to: "private func laneRow(")
        XCTAssertEqual(gutter.components(separatedBy: "selection.toggleTrack(row.id)").count - 1, 2,
                       "the tap AND the VoiceOver action select the track — one gesture, two ways in")
        XCTAssertTrue(gutter.contains(".onTapGesture { selection.toggleTrack(row.id) }"), "a tap selects")
        XCTAssertTrue(gutter.contains(".isSelected"), "selected is spoken as a trait")
        XCTAssertTrue(gutter.contains("strokeBorder(open ?"), "and drawn as a ring — never colour alone")
        XCTAssertTrue(gutter.contains(".accessibilityElement(children: .ignore)"),
                      "the head is ONE VoiceOver element")
        XCTAssertFalse(gutter.contains(".accessibilityHidden(true)"), """
            the gutter is hidden from VoiceOver again — a control nobody can reach without sight. \
            Since A5 it is the head of its track; it speaks name and state and selects.
            """)
        XCTAssertTrue(canvas.contains("private static let rowHeight: CGFloat = 44"),
                      "a tap target is 44 pt tall (A5); the gutter fills the row")

        let view = SourceText.codeOnly(try text(Self.workstation))
        XCTAssertTrue(view.contains("if ArrangeCanvas.listsCard(row.id, open: open, canvasRows: arrangeRows) { laneRow(row) }"),
                      "the card list asks the one rule, with the rows the canvas actually drew")
        guard let openBranch = view.range(of: "if open == row.id {"),
              let pitch = view.range(of: "pitchField(row)") else {
            return XCTFail("ANCHOR MISSING: the open-track branch or `pitchField(row)` (#454)")
        }
        XCTAssertLessThan(openBranch.lowerBound, pitch.lowerBound,
                          "an audio track's pitch row lives under its OPEN head — under a missing card it would dangle")
    }

    // MARK: 3 — counterweights: the gutter mutes nothing, the one Mute/Solo stays

    func testTheGutterMutesNothingAndTheOneMuteSoloStays() throws {
        let canvas = SourceText.codeOnly(try text(Self.canvas))
        let gutter = try slice(canvas, from: "private func nameGutter(", to: "private func laneRow(")
        XCTAssertFalse(gutter.contains("Button("), "the gutter selects; it is not a mute or solo button")
        XCTAssertFalse(gutter.contains("TrackMix.flip"), "nothing on the canvas mutes or solos")
        XCTAssertTrue(gutter.contains(".frame(width: Self.nameWidth, alignment: .leading)"),
                      "the gutter keeps its one fixed width (the canvas's shared scale)")

        let view = SourceText.codeOnly(try text(Self.workstation))
        XCTAssertEqual(view.components(separatedBy: "TrackMix.flipMute").count - 1, 1, "ONE Mute control")
        XCTAssertEqual(view.components(separatedBy: "TrackMix.flipSolo").count - 1, 1, "ONE Solo control")
        XCTAssertTrue(view.contains("TrackInspectorView(laneID: row.id)"), "the open track still mounts its inspector")
        XCTAssertTrue(view.contains("TrackArmToggle(laneID: row.id)"), "and its record arm")
    }

    // MARK: helpers

    /// The text from `from` (inclusive) up to `to` (exclusive); fails loudly on a missing anchor
    /// rather than returning "" — an empty slice makes every absence above vacuous (#926).
    private func slice(_ code: String, from: String, to: String) throws -> String {
        guard let start = code.range(of: from),
              let end = code.range(of: to, range: start.upperBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: `\(from)` … `\(to)` (#454)")
            return ""
        }
        return String(code[start.lowerBound..<end.lowerBound])
    }

    private func text(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
