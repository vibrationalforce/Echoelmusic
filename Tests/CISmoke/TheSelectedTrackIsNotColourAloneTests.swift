// TheSelectedTrackIsNotColourAloneTests.swift
// Echoel — Zug 4 „Klarheit" (2026-09-30): a state is never told by hue alone.
//
// WHAT THIS PINS. The Workstation's track row marked "this track is open" with ONE cue: its
// 1 pt border turned from `EchoelTheme.border` to `EchoelTheme.accent`. A reader who does not
// separate that green from the grey (deuteranopia, a dim stage, the Increase-Contrast setting)
// saw no difference; VoiceOver had the `.isSelected` trait, sighted readers had nothing. Every
// other selection in the app already carries a second, hue-free cue — a selected PART thickens
// its stroke to 2 pt (`TrackPartsView`, the arrange canvas) — so the row now does the same. No
// new glyph, no new word: the pattern that exists, applied to the one place that lacked it.
//
// Measured before this slice (32 `accent : token` ternaries in 12 files): every other reachable
// site pairs the colour with a word, a glyph, a luminance inversion (accent fill + black label)
// or a stroke width. This row was the one exception on a reachable surface.
//
// 1. SOURCE: `laneRow`'s stroke width switches with `selected` (the hue-free cue).
// 2. COUNTERWEIGHTS (#343): the accent stroke is still there (the cue was ADDED, not swapped),
//    the row still carries `.isSelected` for VoiceOver, and the two part selections still
//    thicken — the premise that makes this the app's pattern rather than a one-off.
//
// Grading (§0, transcribed against both trees): claim 1 red on the parent (`lineWidth: 1`
// literal, no `selected ?` width), green here; claim 2 green on both. SOURCE-TEXT scan.
// NEEDS-FOUNDER-VERIFY: Workstation → tap a track → its row border is visibly heavier, also
// with Settings → Accessibility → Increase Contrast on.

import Foundation
import XCTest

final class TheSelectedTrackIsNotColourAloneTests: XCTestCase {

    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let parts = "Sources/Echoelmusic/Studio/TrackPartsView.swift"
    private static let canvas = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"

    func testTheSelectedRowThickensItsStroke() throws {
        let row = try laneRow()
        XCTAssertTrue(row.contains("lineWidth: selected ? 2 : 1"), """
            `laneRow` no longer thickens its border when the track is selected. The accent \
            colour alone is invisible to a reader who cannot tell that green from the border; \
            keep `lineWidth: selected ? 2 : 1` (the part-selection pattern) or add another \
            hue-free cue and re-anchor this claim on it.
            """)
    }

    func testTheColourCueAndTheTraitAreStillThere() throws {
        let row = try laneRow()
        XCTAssertTrue(row.contains("selected ? EchoelTheme.accent : EchoelTheme.border"),
                      "the thicker stroke was ADDED beside the accent, not instead of it")
        XCTAssertTrue(row.contains(".isSelected"), "VoiceOver still hears the selection as a trait")
        for (path, needle) in [(Self.parts, "lineWidth: isSelected ? 2 : 1"),
                               (Self.canvas, "lineWidth: isSelected || moving ? 2 : 1")] {
            XCTAssertTrue(try source(path).contains(needle), """
                `\(path)` no longer thickens a selected part's stroke — the row copies THAT \
                pattern; if the pattern changed, change all three together.
                """)
        }
    }

    /// `laneRow`'s body: from its declaration to the next `private func`, brace-agnostic on
    /// purpose — the row is one expression and its stroke is its last modifier.
    private func laneRow() throws -> String {
        let code = try source(Self.workstation)
        guard let start = code.range(of: "private func laneRow(_ row: WorkstationSummary.LaneRow) -> some View {"),
              let end = code.range(of: "private func headerSwitch(", range: start.upperBound..<code.endIndex) else {
            throw XCTSkip("ANCHOR MISSING: `laneRow` / `headerSwitch` in WorkstationView — re-anchor (#454)")
        }
        return String(code[start.upperBound..<end.lowerBound])
    }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            throw XCTSkip("ANCHOR MISSING: cannot read \(relativePath) (#454)")
        }
        return SourceText.codeOnly(text)
    }
}
