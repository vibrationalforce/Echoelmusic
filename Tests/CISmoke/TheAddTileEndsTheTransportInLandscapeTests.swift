// TheAddTileEndsTheTransportInLandscapeTests.swift
// Echoel — DAW shell S8b (founder 2026-10-02, the approved shell, "abtsturzsicher … übersichtlich").
//
// WHY: a phone on its side has about 390 pt of height. Above the plate stood the control bar,
// then the arrangement's own pinned row holding ONE tile ("Add", ~56 pt), and under it the pinned
// transport bar. In landscape that row was a whole row of height for one tile, while the transport
// row had width to spare. S8b moves the tile to the END of the transport row in landscape; in
// portrait nothing changes.
//
// THE THREE CLAIMS:
// 1. END-TO-END (pure, `ArrangeAddPlacement.of`): the tile stands somewhere exactly when the
//    Arrange plate shows a song with a track; then in the toolbar in portrait and at the end of
//    the transport bar in landscape — never both, never neither. Driven over every plate, both
//    track states and both size classes.
// 2. SOURCE: each placement is asked at ONE gate — `if addPlacement == .toolbar {` in `pieceTabs`,
//    `if addPlacement == .transportBar {` in `transportRow` — and the second gate stands inside the
//    row's `controls { … }` group AFTER Play, Click and Record (they keep their lead and their
//    width) and before the meter. The note line follows the tile in landscape too.
// 3. COUNTERWEIGHTS: `addPlacement` asks the one decision with the empty plate's predicate and
//    the same size class the A9 columns and the S8a rail read; it reads nothing hot (it is
//    evaluated in `body` and in the pinned bar, ancestors of the plate's pickers); the decision
//    is declared once and asked once.
//
// KIND (per this directory's §1): claim 1 is END-TO-END on a shipped, pure, nonisolated function;
// claims 2–3 are SOURCE-TEXT scans — `WorkstationView` is a SwiftUI struct no bundle renders. They
// prove where the tile is mounted, never that it fits beside a playing meter on glass.
//
// HONEST GRADING (§3), parent = the tree before S8b: this file names `ArrangeAddPlacement`, which
// this commit creates, so it DOES NOT COMPILE there and no assertion has a verdict. Transcribed in
// Python against both trees instead: claim 1 is FORWARD (drives the new symbol); claims 2 and 3
// are red on the parent by ONE ABSENCE (`addPlacement`), reported once (#486); their hot-read and
// once-declared needles are COUNTERWEIGHTS. Stripper `SourceText.codeOnly`: PROPHYLACTIC (measured:
// every count reads the same raw and stripped on this tree, 1 each) — kept because the view's
// comments name `addPlacement` and `ArrangeAddPlacement` in prose.
//
// DEVICE PROBE, open (NEEDS-FOUNDER-VERIFY): an iPhone in landscape on Arrange with a track —
// no row between the control bar and the arrangement; "Add" at the end of Play · Click · Record;
// while playing the meter still fits (the position readout yields first); Import Audio from that
// tile → its note line appears under the transport row, with an ×. Rotate back to portrait — the
// tile is above the arrangement again, the note with it.

import XCTest
@testable import Echoelmusic

final class TheAddTileEndsTheTransportInLandscapeTests: XCTestCase {

    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"

    // MARK: 1 — END-TO-END: one placement, exactly when the arrangement has a track

    func testTheTileStandsInOnePlaceExactlyWhenTheArrangementHasATrack() {
        for plate in PieceView.allCases {
            for hasTrack in [false, true] {
                for compactHeight in [false, true] {
                    let placement = ArrangeAddPlacement.of(plate: plate, hasTrack: hasTrack,
                                                           compactHeight: compactHeight)
                    let shown = plate == .arrange && hasTrack
                    XCTAssertEqual(placement != nil, shown, """
                        plate \(plate.rawValue), hasTrack \(hasTrack), compact \(compactHeight): the \
                        tile must stand exactly on the Arrange plate of a song with a track — the \
                        empty plate shows the five doors itself, and the other plates add nothing
                        """)
                    guard shown else { continue }
                    XCTAssertEqual(placement, compactHeight ? .transportBar : .toolbar, """
                        in \(compactHeight ? "landscape" : "portrait") the tile belongs \
                        \(compactHeight ? "at the end of the transport bar" : "in the toolbar above the plate")
                        """)
                }
            }
        }
    }

    // MARK: 2 — one gate per placement; the landscape tile ends the row

    func testEachPlacementIsMountedOnceAndTheLandscapeTileEndsTheRow() throws {
        let code = SourceText.codeOnly(try text(Self.workstation))
        XCTAssertEqual(code.components(separatedBy: "if addPlacement == .toolbar {").count - 1, 1,
                       "the toolbar placement is asked at exactly one gate")
        XCTAssertEqual(code.components(separatedBy: "if addPlacement == .transportBar {").count - 1, 1,
                       "the transport placement is asked at exactly one gate")

        let tabs = try member("private var pieceTabs: some View {", in: code)
        XCTAssertTrue(tabs.contains("if addPlacement == .toolbar {"),
                      "the toolbar row stands only where the toolbar placement is")

        let row = try member("private var transportRow: some View {", in: code)
        let group = try member("controls {", in: row)
        guard let record = group.range(of: "RecordTakeButton(playing: playing, startable: startable,"),
              let gate = group.range(of: "if addPlacement == .transportBar {", range: record.upperBound..<group.endIndex),
              let meter = group.range(of: "if playing {", range: gate.upperBound..<group.endIndex) else {
            return XCTFail("""
                The landscape Add gate is not inside the transport row's `controls { … }` group \
                after Record and before the meter. Before Record it would take width from Play, \
                Click and Record; outside the group it would be a second row — the height S8b \
                gives back.
                """)
        }
        let lead = group[group.startIndex..<gate.lowerBound]
        XCTAssertEqual(lead.filter { $0 == "{" }.count - lead.filter { $0 == "}" }.count, 0,
                       "the gate is a direct child of the row, not nested in another branch")
        let mount = String(group[gate.upperBound..<meter.lowerBound].filter { !$0.isWhitespace })
        XCTAssertEqual(mount, "addMenu}", """
            the landscape gate mounts the ONE Add menu and nothing else — the same tile, the same \
            five actions, not a second menu
            """)
        guard let noteGate = row.range(of: "if addPlacement == .transportBar, let note = importNote {"),
              let noteLine = row.range(of: "pinnedNoteLine(note)", range: noteGate.upperBound..<row.endIndex) else {
            return XCTFail("in landscape the Add menu's outcome is not said under the transport row (S8b)")
        }
        XCTAssertTrue(row[noteGate.upperBound..<noteLine.lowerBound].allSatisfy(\.isWhitespace))
        XCTAssertFalse(group.contains("pinnedNoteLine("),
                       "the note is under the row, never a member of it — it would widen the row instead")
    }

    // MARK: 3 — counterweights: one decision, the shared size class, nothing hot

    func testThePlacementAsksOneColdDecision() throws {
        let code = SourceText.codeOnly(try text(Self.workstation))
        let placement = try member("private var addPlacement: ArrangeAddPlacement? {", in: code)
        XCTAssertTrue(placement.contains("let hasTrack = !WorkstationSummary(document: timeline.document).isEmpty"),
                      "the empty plate's predicate, negated (#416)")
        XCTAssertTrue(placement.contains("ArrangeAddPlacement.of(plate: pieceView, hasTrack: hasTrack,"),
                      "the plate and that predicate go to the one decision")
        XCTAssertTrue(placement.contains("compactHeight: verticalSizeClass == .compact"),
                      "landscape is the size class the A9 columns and the S8a rail read — one meaning of 'landscape'")
        for hot in ["player.", "transport.", "metronome.", "cameraRPPG", "bus.", "currentTick", "masterLevel"] {
            XCTAssertFalse(placement.contains(hot), """
                `addPlacement` reads `\(hot)`. It is evaluated in the pinned toolbar and the pinned \
                transport bar, ancestors of every picker on the plate — a hot read here is the \
                10.76.41/50 freeze.
                """)
        }
        let sources = try sourcesCode()
        XCTAssertEqual(sources.components(separatedBy: "enum ArrangeAddPlacement").count - 1, 1,
                       "the placement is decided by ONE type")
        XCTAssertEqual(sources.components(separatedBy: "ArrangeAddPlacement.of(").count - 1, 1,
                       "and asked at ONE place — both mounts read that one answer")
    }

    // MARK: helpers

    /// The brace-matched body after `anchor` (#408); string-literal aware.
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            XCTFail("ANCHOR MISSING: `\(anchor)` (#454)")
            return ""
        }
        var depth = 1
        var index = start.upperBound
        var inString = false
        while index < code.endIndex {
            let ch = code[index]
            if inString, ch == "\\" {
                index = code.index(after: index)
                if index < code.endIndex { index = code.index(after: index) }
                continue
            }
            if ch == "\"" { inString.toggle() }
            if !inString {
                if ch == "{" { depth += 1 }
                if ch == "}" {
                    depth -= 1
                    if depth == 0 { return String(code[start.upperBound..<index]) }
                }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: `\(anchor)` never closes (#454)")
        return ""
    }

    private func root() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func text(_ relativePath: String) throws -> String {
        try String(contentsOf: root().appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// Every Swift file under `Sources/`, comment-stripped and joined.
    private func sourcesCode() throws -> String {
        let base = root().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else {
            XCTFail("ANCHOR MISSING: `Sources/` is not readable (#454)")
            return ""
        }
        var joined = ""
        for case let url as URL in walker where url.pathExtension == "swift" {
            joined += SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8)) + "\n"
        }
        XCTAssertFalse(joined.isEmpty, "the walk found no Swift source — a scan over nothing is not a pass")
        return joined
    }
}
