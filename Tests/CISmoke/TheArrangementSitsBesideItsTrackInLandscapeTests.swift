// TheArrangementSitsBesideItsTrackInLandscapeTests.swift
// Echoel — in landscape the Piece stage shows the arrangement and the open track's head side by
// side; in portrait it stacks them as before (Workstation redesign A9, founder 2026-10-01).
//
// WHY: the tablet mockup the founder pointed at („Das angehängte Bild gefällt mir auch") is a
// workstation in columns — tracks, arrangement, inspector in one view. On a phone turned sideways
// the plate kept its portrait stack, so the open track's header, Mute/Solo and inspector sat a
// whole screen below the lane they belong to. A9 puts them in a column beside the canvas. The
// plan's third column (the visual) needs no code: it is the floating card over the plate.
//
// THE THREE CLAIMS:
// 1. `WorkstationView` reads the vertical size class, and ONE `AnyLayout` switch — horizontal when
//    `.compact` and a canvas is drawn, vertical otherwise — holds the arrangement column FIRST and
//    the track column SECOND. A landscape column with no open track says how to fill it.
// 2. The switch keeps identity: the canvas and the inspector are each built ONCE in the file (no
//    `if landscape { … } else { … }` copy that would reset a switch on rotation); the track column
//    has a bounded width in landscape and the full width in portrait.
// 3. Counterweights — the A5 head rule, the pinned transport, the plate stack the other guards
//    anchor on, and no modal or button in the hint; the hint has its German line.
//
// GRADING (§0/§3, no Swift toolchain in a web session — transcribed in Python against both trees):
// all claims are SOURCE-TEXT scans. Parent tree: claims 1–2 are red by ABSENCE of the switch
// (`sideBySide`, `columns {`, `trackColumnHint`) — one absence (#486); claim 2's two build-once
// counts are COUNTERWEIGHTS (green on both, 1 and 1). Claim 3 is COUNTERWEIGHTS, green on both
// except three needles that belong to claim 1's absence: the plate-before-switch order, the hint
// and its catalog line. DEVICE PROBE, open: the
// two columns read well at 667–932 pt, the canvas stays legible beside a 260–360 pt column, and a
// rotation keeps Notes/Automation open — readings, not scans.

import XCTest

final class TheArrangementSitsBesideItsTrackInLandscapeTests: XCTestCase {

    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let catalog = "Sources/Echoelmusic/Resources/Localizable.xcstrings"

    // MARK: 1 — one switch, arrangement first, track column second

    func testLandscapePutsTheTrackBesideTheArrangement() throws {
        let code = SourceText.codeOnly(try text(Self.workstation))
        XCTAssertTrue(code.contains("@Environment(\\.verticalSizeClass) private var verticalSizeClass"),
                      "the plate reads the size class that is `.compact` on an iPhone in landscape")
        XCTAssertTrue(code.contains("let sideBySide = verticalSizeClass == .compact && !arrangeRows.isEmpty"),
                      "side by side only in landscape AND only with a drawn canvas to sit beside")
        XCTAssertTrue(code.contains("? AnyLayout(HStackLayout(alignment: .top, spacing: 10))"),
                      "landscape lays the columns out horizontally, tops aligned")
        XCTAssertTrue(code.contains(": AnyLayout(VStackLayout(alignment: .leading, spacing: 10))"),
                      "portrait stacks them at the plate's own spacing — unchanged from before A9")

        let body = try member("var body: some View {", in: code)
        guard let columns = body.range(of: "columns {"),
              let canvas = body.range(of: "ArrangeCanvasView("),
              let lanes = body.range(of: "ForEach(summary.lanes) { row in") else {
            return XCTFail("ANCHOR MISSING: `columns {`, the canvas or the track list in the body (#454)")
        }
        XCTAssertLessThan(columns.lowerBound, canvas.lowerBound, "the canvas sits inside the switch")
        XCTAssertLessThan(canvas.lowerBound, lanes.lowerBound,
                          "the arrangement is the FIRST column, the track heads the second")
        XCTAssertTrue(body.contains("if sideBySide && open == nil { trackColumnHint }"),
                      "an empty landscape column says how to fill it, instead of an empty box")
    }

    // MARK: 2 — identity survives a rotation; widths follow the orientation

    func testTheSwitchKeepsEveryChildsIdentity() throws {
        let code = SourceText.codeOnly(try text(Self.workstation))
        XCTAssertEqual(code.components(separatedBy: "ArrangeCanvasView(").count - 1, 1, """
            the canvas is built more than once — an `if landscape { … } else { … }` copy gives each \
            branch its own identity, so a rotation would reset Notes, Automation and the inspector. \
            One `AnyLayout` switch around one set of children is the A9 shape.
            """)
        XCTAssertEqual(code.components(separatedBy: "TrackInspectorView(laneID: row.id)").count - 1, 1,
                       "one inspector, wherever the column stands")
        XCTAssertTrue(code.contains(".frame(minWidth: sideBySide ?"),
                      "the track column has a floor in landscape so the inspector stays usable")
        XCTAssertTrue(code.contains("maxWidth: sideBySide ?"),
                      "and a ceiling in landscape so the canvas keeps the room; full width in portrait")
    }

    // MARK: 3 — counterweights: the neighbours' anchors and laws still hold

    func testTheNeighbouringLawsStillHold() throws {
        let code = SourceText.codeOnly(try text(Self.workstation))
        XCTAssertTrue(code.contains("if ArrangeCanvas.listsCard(row.id, open: open, canvasRows: arrangeRows) { laneRow(row) }"),
                      "the A5 head rule is unchanged — every track still has exactly one head")
        let body = try member("var body: some View {", in: code)
        guard let scroll = body.range(of: "ScrollView {"),
              let plate = body.range(of: "VStack(alignment: .leading, spacing: 10) {"),
              let columns = body.range(of: "columns {") else {
            return XCTFail("ANCHOR MISSING: the scroll, the plate stack or the switch (#454)")
        }
        XCTAssertLessThan(scroll.lowerBound, plate.lowerBound, "one scroll still wraps the plate")
        XCTAssertLessThan(plate.lowerBound, columns.lowerBound,
                          "the plate's own stack comes first — the anchor the A3/A6 guards read")
        XCTAssertTrue(body.contains(".safeAreaInset(edge: .bottom, spacing: 0) { transportBar }"),
                      "the transport stays pinned in both orientations")

        let hint = try member("private var trackColumnHint: some View {", in: code)
        for banned in ["Button", ".sheet(", ".fullScreenCover(", ".popover(", ".alert("] {
            XCTAssertFalse(hint.contains(banned), "the hint is a sentence, not a control or a modal: `\(banned)`")
        }
        XCTAssertTrue(hint.contains("Text(\"Tap a track name to open it here\")"), "the hint names the gesture")

        let data = Data(try text(Self.catalog).utf8)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let entry = (root?["strings"] as? [String: Any])?["Tap a track name to open it here"] as? [String: Any]
        let localizations = entry?["localizations"] as? [String: Any] ?? [:]
        let en = (localizations["en"] as? [String: Any])?["stringUnit"] as? [String: Any]
        XCTAssertEqual(en?["value"] as? String, "Tap a track name to open it here", "the hint has its English line")
        XCTAssertEqual(Set(localizations.keys), ["en"], "the app speaks one language (founder 2026-10-02) — no second unit")
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

    private func text(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
