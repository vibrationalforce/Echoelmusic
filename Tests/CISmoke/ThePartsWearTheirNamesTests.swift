// ThePartsWearTheirNamesTests.swift
// Echoel — every part on the arrange canvas wears its clip's name, top-left, without hiding its
// notes or taking the block's touches (Workstation redesign A1b, founder 2026-10-01).
//
// WHY: both mockups the founder pointed at („Das angehängte Bild gefällt mir auch") label every
// part — "Intro", "Verse", "Drop" — so a song reads as named sections. The canvas drew only a
// coloured bar with a note sketch; the clip's name existed (`Clip.name`, written by the composer
// and by the user) and was shown nowhere on the timeline.
//
// THE THREE CLAIMS:
// 1. One pure rule names a part: its clip's name, trimmed; empty for a missing or blank clip.
// 2. The canvas reads the clip grid ONCE per lane and hands each block its own name; the block
//    draws it as a one-line tag over the body and under the selection ring, takes no touches,
//    hides it from VoiceOver as text and speaks it as the block's VALUE (the label keeps its one
//    rule), and the note sketch moves below the tag so the dashes never run through the letters.
// 3. Counterweights: the label is untouched, the tag sits on the 11-pt floor.
//
// GRADING (§0, no Swift toolchain in a web session): claim 1 is a RUNTIME claim on a function
// this commit creates — it cannot compile on the parent, so it has no verdict there (one absence,
// #486); re-derived by hand: "  Verse  " → "Verse", "   " → "", nil → "". Claim 2 is a SOURCE scan:
// transcribed against the work tree (green) and the parent (red — no `partName`, no `nameTag`).
// Claim 3: the two label assertions are counterweights (green on both); the 11-pt font needle is
// new with the tag, so it is red on the parent by absence — part of the same one absence (#486). What the tag LOOKS like on a phone (legible on every
// track hue, truncation on a one-bar part) is a DEVICE PROBE and open.

import XCTest
@testable import Echoelmusic

final class ThePartsWearTheirNamesTests: XCTestCase {

    private static let canvas = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"

    // MARK: 1 — one rule names a part

    func testOneRuleNamesAPart() {
        XCTAssertEqual(ArrangeCanvas.partName(Clip(name: "  Verse  ")), "Verse",
                       "the tag shows the clip's name as written, trimmed")
        XCTAssertEqual(ArrangeCanvas.partName(Clip(name: "   ")), "",
                       "a blank name draws no tag rather than an empty pill")
        XCTAssertEqual(ArrangeCanvas.partName(nil), "",
                       "a part whose clip is gone draws no tag")
    }

    // MARK: 2 — the canvas draws it where it reads and where it cannot get in the way

    func testTheBlockDrawsItsNameAboveItsNotes() throws {
        let file = SourceText.codeOnly(try text(Self.canvas))
        guard let lane = file.range(of: "private func laneRow(_ row: WorkstationSummary.LaneRow, selected: UUID?) -> some View {"),
              let laneEnd = file.range(of: "private func drop(", range: lane.upperBound..<file.endIndex),
              let block = file.range(of: "struct ArrangePartBlock: View {") else {
            return XCTFail("ANCHOR MISSING: `laneRow`, `drop` or `ArrangePartBlock` (#454)")
        }
        let laneBody = String(file[lane.upperBound..<laneEnd.lowerBound])
        XCTAssertTrue(laneBody.contains("let names = clips.mapValues { ArrangeCanvas.partName($0.1) }"),
                      "the names come from the same one read of the clip grid as the sketches")
        XCTAssertTrue(laneBody.contains("name: names[block.id] ?? \"\","), "each block gets its own name")

        let blockBody = String(file[block.upperBound...])
        XCTAssertTrue(blockBody.contains("let name: String"))
        guard let sketch = blockBody.range(of: ".overlay { noteSketch }"),
              let tag = blockBody.range(of: ".overlay(alignment: .topLeading) { nameTag }"),
              let ring = blockBody.range(of: ".overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)") else {
            return XCTFail("ANCHOR MISSING: the three overlays of `ArrangePartBlock` (#454)")
        }
        XCTAssertLessThan(sketch.lowerBound, tag.lowerBound, "the name sits over the notes")
        XCTAssertLessThan(tag.lowerBound, ring.lowerBound, "and under the selection ring, which stays the loudest edge")

        guard let tagDecl = blockBody.range(of: "@ViewBuilder private var nameTag: some View {"),
              let tagEnd = blockBody.range(of: "private var noteSketch: some View {", range: tagDecl.upperBound..<blockBody.endIndex) else {
            return XCTFail("ANCHOR MISSING: `nameTag` before `noteSketch` (#454)")
        }
        let tagBody = String(blockBody[tagDecl.upperBound..<tagEnd.lowerBound])
        for needle in ["if !name.isEmpty {", "Text(name)", ".lineLimit(1)", ".clipped()",
                       ".allowsHitTesting(false)", ".accessibilityHidden(true)"] {
            XCTAssertTrue(tagBody.contains(needle), "`nameTag` lost `\(needle)`")
        }
        XCTAssertTrue(blockBody.contains(".accessibilityValue(name)"),
                      "VoiceOver hears the name as the block's value, not as a second element")
        XCTAssertTrue(blockBody.contains(".padding(.top, name.isEmpty ? 0 : Self.nameRoom)"),
                      "the note sketch steps below the tag, so the dashes never cross the letters")
    }

    // MARK: 3 — counterweights

    func testTheLabelAndTheFloorAreUntouched() throws {
        let file = SourceText.codeOnly(try text(Self.canvas))
        XCTAssertTrue(file.contains(".accessibilityLabel(label)"), "the block's label keeps its one rule")
        XCTAssertTrue(file.contains("label: spokenName + String(localized: \", part at \") + SessionGrid.label(forTick: start),"),
                      "the spoken track-and-position label is unchanged")
        XCTAssertTrue(file.contains(".font(EchoelTheme.font(11, .medium))"), "the tag sits on the 11-pt floor")
    }

    private func text(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
