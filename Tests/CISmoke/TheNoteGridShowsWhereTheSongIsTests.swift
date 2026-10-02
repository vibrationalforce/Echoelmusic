// TheNoteGridShowsWhereTheSongIsTests.swift
// Echoel — modes census 2026-09-26, design slice 9: the note grid shows the playhead.
//
// WHAT THIS PINS. The Arrange canvas drew where the song was; the note grid under it did not, so
// a musician editing notes while the song played had to look up to find the beat. A 1 pt line
// now crosses the open part's grid at the song's column, while the song plays inside that part.
//
// 1. END-TO-END BEHAVIOUR (`PartNotePlayhead.step`, pure): the step is measured from the part's
//    START in the note grid's own unit (`Note.ticksPerStep`), is fractional off the column grid
//    (the player itself moves a whole column per transport step — review of e091712e5, LOW-7), and is nil
//    before the part, at or after its end, and for a part with no length.
// 2. SOURCE: the position is read ONLY in `PartNotePlayheadView`'s own file, once, inside a
//    `TimelineView` that pauses while the song is stopped — the self-driving-leaf shape of
//    `ArrangePlayheadView` and `SongPositionReadout`. The line takes no touches and is hidden
//    from VoiceOver.
// 3. SOURCE: the note editor mounts it once, as an overlay ON the grid canvas (so it scrolls with
//    the columns), handing it three COLD numbers — and the editor still names no `currentTick`
//    and no `player.` (the ban `TheSelectedPartsNotesAreEditedThroughOneWriterTests` holds; this
//    file only checks the mount did not break it). The canvas draws a note at
//    `note.startStep * stepW`, the unit the playhead uses.
//
// Grading (§0, no Swift toolchain): `PartNotePlayhead` and `PartNotePlayheadView` do not exist on
// the parent (`b8e3c1e0f`), so this file does not compile there — every claim is a FORWARD guard,
// one absence (#486). Claim 1 transcribed into Python and driven over three parts × every tick in
// a window around each; claims 2-3 transcribed against this tree, with mutants (the read hoisted
// above the `TimelineView`, the pause dropped, the overlay moved outside the scroll view, a second
// mount): each red.
// NOT covered: that the line is visible over the accent-coloured notes, and that 15 Hz reads as
// smooth on glass — a device look.
// NEEDS-FOUNDER-VERIFY: Workstation → a MIDI part with notes → Notes → Play from here: a thin line
// walks across the note grid in time with the Arrange canvas's line; it is absent before the part
// starts and gone after it ends; Stop removes it; scrolling the grid moves the line with the
// columns.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheNoteGridShowsWhereTheSongIsTests: XCTestCase {

    private static let step = Note.ticksPerStep
    private static let leafPath = "Sources/Echoelmusic/Studio/PartNotePlayheadView.swift"
    private static let editorPath = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"

    // MARK: 1 — the column, pure

    func testThePlayheadStepIsMeasuredFromThePartsStart() throws {
        let parts: [(start: Int, length: Int)] = [(0, 1_920), (3_840, 960), (1_000, 7)]
        for part in parts {
            for tick in (part.start - 300)...(part.start + part.length + 300) {
                let step = PartNotePlayhead.step(atTick: tick, partStartTick: part.start,
                                                 lengthTicks: part.length)
                if tick < part.start || tick >= part.start + part.length {
                    XCTAssertNil(step, "tick \(tick) is outside the part at \(part.start)+\(part.length)")
                } else {
                    let s = try XCTUnwrap(step, "tick \(tick) is inside the part")
                    XCTAssertEqual(s * Double(Self.step) + Double(part.start), Double(tick), accuracy: 1e-9,
                                   "the step, in the grid's own unit, maps back to the song's tick")
                }
            }
        }
        XCTAssertEqual(PartNotePlayhead.step(atTick: 3_840 + 60, partStartTick: 3_840, lengthTicks: 960), 0.5,
                       "half a column in — exact for a part that starts off the column grid")
        XCTAssertNil(PartNotePlayhead.step(atTick: 0, partStartTick: 0, lengthTicks: 0), "a part with no length shows no line")
        XCTAssertNil(PartNotePlayhead.step(atTick: 0, partStartTick: 0, lengthTicks: -5))
    }

    // MARK: 2 — the leaf reads the position, and only it

    func testThePositionIsReadInsideTheSelfDrivingLeaf() throws {
        let code = try source(Self.leafPath)
        guard let leaf = code.range(of: "struct PartNotePlayheadView: View {") else {
            return XCTFail("ANCHOR MISSING: `struct PartNotePlayheadView: View {` (#454)")
        }
        let body = String(code[leaf.upperBound...])
        XCTAssertTrue(body.contains("TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !playing))"),
                      "the line redraws itself at the canvas playhead's rate and stops while the song is stopped")
        guard let clock = body.range(of: "TimelineView("),
              let read = body.range(of: "PartNotePlayhead.step(atTick: player.currentTick,") else {
            return XCTFail("the leaf no longer asks the pure rule with the player's position")
        }
        XCTAssertLessThan(clock.lowerBound, read.lowerBound,
                          "the position is read INSIDE the `TimelineView` — hoisted, it is read once and the line stands still")
        XCTAssertEqual(code.components(separatedBy: "currentTick").count - 1, 1, "ONE read of the position in this file")
        XCTAssertTrue(body.contains("if playing,"), "no line while the song is stopped")
        // Review of e091712e5, LOW-8: the two premises the pause and the geometry stand on.
        XCTAssertTrue(body.contains("let playing = player.isPlaying"),
                      "the pause and the absence follow the player — a constant would leave a line standing while stopped")
        XCTAssertTrue(body.contains(".offset(x: stepWidth * CGFloat(step))"),
                      "the line sits at `step × stepWidth` — the width the grid places its notes with")
        XCTAssertTrue(body.contains(".allowsHitTesting(false)"), "the line never takes a tap meant for the grid")
        XCTAssertTrue(body.contains(".accessibilityHidden(true)"),
                      "a moving line has nothing to say; the song-position readout speaks the place")
    }

    // MARK: 3 — the editor mounts it, cold

    func testTheEditorMountsTheLeafOnTheCanvasWithColdNumbers() throws {
        let code = try source(Self.editorPath)
        guard let scroll = code.range(of: "ScrollView(.horizontal, showsIndicators: true) {"),
              let canvas = code.range(of: "PartNoteCanvas(visible: visible, steps: steps, grid: grid, naming: naming,",
                                      range: scroll.upperBound..<code.endIndex),
              let overlay = code.range(of: ".overlay(alignment: .leading) {", range: canvas.upperBound..<code.endIndex),
              let a11y = code.range(of: ".accessibilityElement()", range: canvas.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: the grid's scroll view, its canvas, the overlay and the canvas's accessibility element (#454)")
        }
        XCTAssertLessThan(overlay.lowerBound, a11y.lowerBound,
                          "the line is an overlay ON the canvas, inside the scroll view — it moves with the columns")
        let mount = String(code[overlay.upperBound..<a11y.lowerBound])
        XCTAssertTrue(mount.contains("PartNotePlayheadView(partStartTick: region.startTick,"))
        XCTAssertTrue(mount.contains("lengthTicks: region.lengthTicks,"))
        XCTAssertTrue(mount.contains("stepWidth: stepWidth)"), "the grid's own column width — one width for notes and line (since S9b the zoomed `stepWidth`, #416)")
        XCTAssertEqual(code.components(separatedBy: "PartNotePlayheadView(").count - 1, 1, "mounted once")
        for banned in ["currentTick", "player."] {
            XCTAssertFalse(code.contains(banned), "the note editor reads `\(banned)` — the position belongs to the leaf's own file")
        }
        XCTAssertTrue(code.contains("let rect = CGRect(x: CGFloat(note.startStep) * stepW + 1,"),
                      "counterweight: the canvas places a note at `startStep × stepW` — the unit the playhead uses")
        XCTAssertTrue(code.contains("stepWidth: Double(stepWidth), rowHeight: Double(Self.rowHeight),"),
                      "counterweight: the canvas's grid is built from the same `stepWidth` the leaf is handed")
    }

    // MARK: helpers

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}
