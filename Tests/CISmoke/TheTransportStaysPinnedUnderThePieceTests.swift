// TheTransportStaysPinnedUnderThePieceTests.swift
// Echoel — the Piece stage scrolls, its transport does not (Workstation redesign A3, founder
// 2026-10-01).
//
// WHY: both mockups the founder pointed at („Das angehängte Bild gefällt mir auch") keep Play,
// the position and the meter in one bar at the bottom of the workstation. On the Piece stage the
// transport sat in the MIDDLE of a scrolled stack — a song with a few tracks scrolled its own Play
// out of reach. A3 moves the scroll from `ArrangeStage` into `WorkstationView` so the transport
// row can be pinned beneath it with `.safeAreaInset(edge: .bottom)`: no overlay, no modal, no new
// presentation slot (the black-screen law), and the row itself is unchanged.
//
// THE THREE CLAIMS:
// 1. `WorkstationView.body` scrolls its plate and pins `transportBar` under the scroll; the bar
//    wraps `transportRow`, and the row is no longer a member of the plate's stack (one start).
// 2. `ArrangeStage` holds no scroll of its own — two nested vertical scrolls would let the outer
//    one carry the pinned bar away again.
// 3. Counterweights — the stage still mounts `PieceTuningStatus()` and `WorkstationView()`; the
//    file importer stays on the leaf (#W1); the row still holds the ONE production Play and the
//    record button; the bar is solid with a 1-px border (Uncodixfy, no blur, no shadow).
//
// GRADING (§0/§3, no Swift toolchain in a web session — transcribed in Python against both trees):
// all scans are SOURCE-TEXT. Parent tree: claim 1 is red there by ABSENCE (`transportBar` does
// not exist, no `safeAreaInset`) — one absence (#486); claim 2 is a REGRESSION guard, red there
// for its named reason (`ArrangeStage` wrapped `ScrollView {`); claim 3 is COUNTERWEIGHTS, green
// on both — except its two bar needles, which read `transportBar` and so belong to claim 1's one
// absence. Driven: work tree 14/14 green; parent 5 red = 1 regression + 1 absence. DEVICE PROBE, open: the bar stays visible while the song scrolls, does not cover
// the last row, and sits above the home indicator on a notched phone — readings, not scans.

import XCTest

final class TheTransportStaysPinnedUnderThePieceTests: XCTestCase {

    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let seam = "Sources/Echoelmusic/Studio/StageShell.swift"

    // MARK: 1 — the plate scrolls, the transport is pinned under it

    func testTheWorkstationPinsItsTransportUnderTheScroll() throws {
        let code = SourceText.codeOnly(try text(Self.workstation))
        let body = try member("var body: some View {", in: code)
        guard let scroll = body.range(of: "ScrollView {"),
              let stack = body.range(of: "VStack(alignment: .leading, spacing: 10) {"),
              let inset = body.range(of: ".safeAreaInset(edge: .bottom, spacing: 0) { transportBar }") else {
            return XCTFail("ANCHOR MISSING: the plate's `ScrollView`, its stack, or the pinned `transportBar` (#454)")
        }
        XCTAssertLessThan(scroll.lowerBound, stack.lowerBound, "the scroll wraps the plate's stack")
        XCTAssertLessThan(stack.lowerBound, inset.lowerBound, "the bar is pinned AFTER the scroll closes, not inside it")

        let plate = try member("VStack(alignment: .leading, spacing: 10) {", in: body)
        XCTAssertFalse(plate.contains("transportRow"), """
            `transportRow` is a row of the plate's stack again — it scrolls away with a long song. \
            A3 pins it under the scroll as `transportBar`; one row, one start.
            """)

        let bar = try member("private var transportBar: some View {", in: code)
        XCTAssertTrue(bar.contains("transportRow"), "the pinned bar IS the transport row, not a second one")
    }

    // MARK: 2 — the stage holds no second scroll

    func testTheArrangeStageHoldsNoScrollOfItsOwn() throws {
        let code = SourceText.codeOnly(try text(Self.seam))
        let stage = try member("struct ArrangeStage: View {", in: code)
        XCTAssertTrue(stage.contains("WorkstationView()"), "the scan reached the stage's body")
        XCTAssertFalse(stage.contains("ScrollView"), """
            `ArrangeStage` wraps a `ScrollView` again. The scroll lives inside `WorkstationView` \
            since A3; an outer one would scroll the pinned transport out of view.
            """)
    }

    // MARK: 3 — counterweights

    func testTheStageTheImporterAndTheOneStartAreIntact() throws {
        let seam = SourceText.codeOnly(try text(Self.seam))
        let stage = try member("struct ArrangeStage: View {", in: seam)
        XCTAssertTrue(stage.contains("PieceTuningStatus()"), "the tuning status still stands above the piece (2c)")

        let code = SourceText.codeOnly(try text(Self.workstation))
        let body = try member("var body: some View {", in: code)
        XCTAssertTrue(body.contains(".fileImporter(isPresented: $importPresented,"),
                      "the importer stays on the leaf (#W1), not on the stage or the root")

        let row = try member("private var transportRow: some View {", in: code)
        XCTAssertTrue(row.contains("RecordTakeButton("), "the bar still records")
        XCTAssertTrue(code.contains("player.play("), "the Workstation still holds the one production Play")

        let bar = try member("private var transportBar: some View {", in: code)
        XCTAssertTrue(bar.contains(".background(EchoelTheme.bg)"), "a solid bar — no blur, no glass")
        XCTAssertTrue(bar.contains("Rectangle().fill(EchoelTheme.border).frame(height: 1)"),
                      "a 1-px border separates it from the plate")
        XCTAssertFalse(bar.contains(".shadow("), "no shadow layer on the bar (Uncodixfy)")
    }

    // MARK: helpers

    /// The brace-matched body that follows `anchor` (#408). Literal-aware enough for these files:
    /// the scanned text is already comment-stripped by `SourceText.codeOnly`.
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
                // Skip the escaped character, so `\"` cannot end a literal early.
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

    private func text(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
