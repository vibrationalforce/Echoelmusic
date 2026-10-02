// ThePieceHasOneTabRowTests.swift
// Echoel — the Piece stage carries ONE tab row, and the two domains the removed row offered keep
// their doors without a twin on the piece (slice B, founder order 2026-10-01: „Vermeide das es
// mehrfache Wege zu einem Bereich gibt und das es so unübersichtlich ist. Viele Bereiche sind zu
// groß und füllen den Bildschirm aus. Vermeide slop.").
//
// ⭐ THIS FILE WAS `TheDomainTabsOpenOnlyWhatExistsTests` and is RENAMED because its subject is gone
// and its old name would now be a false sentence (#374). C5 (same day, FOUNDER_INBOX H5) built a
// second top row above `pieceTabs`: Music · Visual · Light. Measured against the one-door order,
// none of its three cells was a unique door:
// · Music  — a marker for "where you are", which the seam („Piece", selected) and the Arrange tab
//            (selected) already say. A third "you are here" is the slop the order names.
// · Light  — posted `"routing"`, the SAME post the header light monitor (`EchoelLuxMonitorMini`)
//            sends, and that monitor sits in `WorkspaceView.topBar`, on screen on BOTH stages. Two
//            buttons on one screen, one destination.
// · Visual — posted `"field"` and turned the stage: a second door to the Field panel, which the
//            Instrument's Field chip already opens (one seam tap away). The
//            picture itself stays on the Piece stage as the floating card (header visual tile).
// Removing the row gives its 44 pt (`.frame(minHeight: 44)`, no vertical padding) back to the
// arrangement on every phone. Folding Visual and Light into `pieceTabs` was considered and
// REJECTED: it would put a stage-jumping tile back into the row slice B just made act-in-place,
// and Light would still be the header monitor's twin.
//
// THE THREE CLAIMS, and where each old claim went:
// 1. ONE top row: `WorkstationView.body` has exactly one `.safeAreaInset(edge: .top`, and it is
//    `pieceTabs`; no `domainTabs` and no "Music" marker survive in its code; it still does not
//    door `ImmersiveStageView` (ship gate 4). — OLD claim 1 (two insets in order) INVERTED to one;
//    old claim 4's ImmersiveStageView ban KEPT, widened from the row to the file. Old claim 1's
//    hot-read ban and old claim 4's Space/Stream/XR word ban are NOT dropped: they MOVED to
//    `ThePieceHasTabsTests` claim 3, over `pieceTabs`, the one top row left (the level-key needles
//    excepted — that row reads the level, cold, for its Mix and Export gates).
// 2. Routing has ONE chrome-door poster: exactly one file in `Sources/` posts `"routing"` —
//    `HeaderMonitors`, from `EchoelLuxMonitorMini` — and `WorkspaceView`'s head mounts that tile;
//    the receiver still refuses while a medium-detent sheet is up, and the destination is real
//    (the routing slot builds `PatchbayView`, whose `content` mounts `lichtSection`). ⚠️ ONE POSTER
//    IS NOT ONE DOOR: the bio panel's „Open Routing" and the master panel's „Routing" set the same
//    slot directly on the Instrument stage. What slice B removed is the second door ON THE PIECE
//    STAGE, where the header tile is the only one. — OLD claim 3's routing half and destination
//    needles MOVED here unchanged; the poster count is NEW.
// 3. The Field panel keeps its Instrument doors and gains no piece twin: nothing posts `"field"`,
//    the receiver has no `case "field":`
//    (#290/#492 — a case without a poster is a hook nobody pulls), and the Field plate keeps its
//    one door: the Field chip, in the strip at Producer and up (`chips(for:)`), and `.field` still
//    builds `visualPanel`. ⚠️ Slice A (same day) deleted the Instrument's area row, which was the
//    Field plate's door at EVERY level; below Producer the plate now has no door. That is the
//    user's chosen level thinning the strip ("absence chosen is a setting", `visibleChips`), and
//    raising the level brings the chip back — recorded in `docs/dev/FOUNDER_INBOX.md`, not
//    decided here. — OLD claim 2's two area-row counterweights are RE-ANCHORED on the chip (the
//    area row no longer exists); old claim 3's `visualPanel` needle MOVED here; old claim 3's
//    "the field arm turns the stage" INVERTED to the case's absence.
//
// GRADING (§0/§3 — no Swift toolchain in a web session; transcribed in Python against the parent
// tree and the slice-B tree): all claims are SOURCE-TEXT scans. Parent tree: claim 1's inset count
// and its two absence needles are REGRESSIONS, red there for their named reason (the C5 row is
// mounted); claim 2's poster count is a REGRESSION, red there for its named reason (two posters:
// `HeaderMonitors` and `WorkstationView`); claim 3's two absence needles are REGRESSIONS, red there
// (one poster, one case); every remaining needle is a COUNTERWEIGHT, green on both. Slice-B tree:
// all green. Nothing here is a forward guard over a new type.
// DEVICE PROBE, open: on a 375×667 phone the arrangement gains one row of height; the header light
// tile opens Routing from the piece; „Instrument" → the Field chip reaches the Field panel; with FX open at
// medium detent a light-tile tap does nothing and nothing freezes — readings, not scans.

import XCTest

final class ThePieceHasOneTabRowTests: XCTestCase {

    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let workspace = "Sources/Echoelmusic/Studio/WorkspaceView.swift"
    private static let monitors = "Sources/Echoelmusic/Studio/HeaderMonitors.swift"
    private static let patchbay = "Sources/Echoelmusic/Studio/PatchbayView.swift"
    private static let sourcesRoot = "Sources/Echoelmusic"
    private static let post = "NotificationCenter.default.post(name: .echoelChromeDoor, object: "

    // MARK: 1 — one tab row on the piece

    func testThePieceStagePinsExactlyOneTabRow() throws {
        let code = SourceText.codeOnly(try text(Self.workstation))
        let body = try member("var body: some View {", in: code)
        XCTAssertEqual(body.components(separatedBy: ".safeAreaInset(edge: .top").count - 1, 1, """
            `WorkstationView.body` pins more than one row above the arrangement. Slice B removed \
            the C5 domain row: every top row costs the plate its height on a 375×667 phone, and \
            that row held no door the screen did not already carry.
            """)
        XCTAssertTrue(body.contains(".safeAreaInset(edge: .top, spacing: 0) { pieceTabs }"),
                      "ANCHOR: the one top row is `pieceTabs` — if it moved, re-anchor (#454)")
        for gone in ["domainTabs", "Text(\"Music\")"] {
            XCTAssertFalse(code.contains(gone), """
                `\(gone)` is back in WorkstationView. The domain row's Music marker said "you are \
                here" a third time (seam + Arrange already do), and its Light and Visual cells were \
                twins of the header light tile and the Instrument's Field chip.
                """)
        }
        XCTAssertFalse(code.contains("ImmersiveStageView"),
                       "the spatial stage stays doorless (ship gate 4) — the piece must not open it")
    }

    // MARK: 2 — Routing: the header light tile is its one poster, and it still lands

    func testRoutingHasOneChromeDoorPosterTheHeaderLightTile() throws {
        let posters = try chromeDoorPosters(of: "routing")
        XCTAssertEqual(posters, ["Studio/HeaderMonitors.swift"], """
            `"routing"` is posted from \(posters). The header light tile is Routing's ONE \
            chrome-door poster and its only door on the Piece stage — it sits in the head on both \
            stages, so a second poster is the twin slice B removed (founder 2026-10-01, one door \
            per area). The Instrument stage's two Routing buttons set the slot directly.
            """)
        let monitors = SourceText.codeOnly(try text(Self.monitors))
        let tile = try member("struct EchoelLuxMonitorMini: View {", in: monitors)
        XCTAssertTrue(tile.contains(Self.post + "\"routing\")"),
                      "the light tile itself posts the door — not some other view in `HeaderMonitors`")
        let workspace = SourceText.codeOnly(try text(Self.workspace))
        XCTAssertTrue(workspace.contains("EchoelLuxMonitorMini()"),
                      "the head mounts the light tile — a door in a file nobody renders is no door (#227)")

        let studio = SourceText.codeOnly(try text(Self.studio))
        guard let routing = receiverArm("routing", in: studio) else {
            return XCTFail("the receiver has no `case \"routing\":` — the light tile would be a button that does nothing")
        }
        XCTAssertTrue(routing.contains("showRouting = true"), "`routing` raises the EXISTING routing slot")
        for refusal in ["!showAllFX", "!showLiveColabo"] {
            XCTAssertTrue(routing.contains(refusal), """
                `routing` raises its sheet without `\(refusal)`. The light tile is on screen while a \
                medium-detent sheet can still be up; driving a second modal true is the invisible \
                tap-blocking layer (the two-modals hang).
                """)
        }
        XCTAssertTrue(studio.contains(".sheet(isPresented: $showRouting) { AnyView(PatchbayView("),
                      "the routing slot still builds `PatchbayView` — the light tile's destination")
        let patchbay = SourceText.codeOnly(try text(Self.patchbay))
        XCTAssertTrue(patchbay.contains("private var lichtSection: some View {"),
                      "Routing still holds the light card")
        let content = try member("private var content: some View {", in: patchbay)
        XCTAssertTrue(content.contains("lichtSection"),
                      "and Routing's content still mounts it — a declared card nobody shows is not the light destination")
    }

    // MARK: 3 — Visual: the Field panel's doors are the Instrument's, one of them at every level

    func testTheFieldPanelKeepsItsInstrumentDoors() throws {
        let posters = try chromeDoorPosters(of: "field")
        XCTAssertTrue(posters.isEmpty, """
            `"field"` is posted from \(posters). The Field panel's door is the Instrument's Field \
            chip; the piece's Visual tab was its twin and went with slice B.
            """)
        let studio = SourceText.codeOnly(try text(Self.studio))
        XCTAssertNotNil(receiverArm("sound", in: studio), """
            ANCHOR: the receiver's surviving `"sound"` case is gone — an absence scan over a \
            receiver that lost everything is the #343 trap
            """)
        XCTAssertNil(receiverArm("field", in: studio), """
            `case "field":` is back in the chrome-door receiver with no poster — a hook nobody \
            pulls reads like a live door (#290/#492). Re-add it only TOGETHER with a poster that \
            is not a twin of the Field chip.
            """)

        let chips = try member("private static func chips(for level: SkillLevel) -> [StudioMenu] {", in: studio)
        XCTAssertTrue(chips.contains("case .effects, .mix, .composition, .field:"),
                      "the Field chip is still in the strip — the Field panel's one door")
        XCTAssertTrue(chips.contains("return level.showsSongs"),
                      "the Field chip shows from Producer up — if its level gate moved, say so in FOUNDER_INBOX")
        XCTAssertTrue(studio.contains("case .field:       return AnyView(visualPanel)"),
                      "the Field plate still builds `visualPanel` — the destination is real")
    }

    // MARK: helpers

    /// The `case "<door>":` arm of the chrome-door receiver, up to the next case — nil when absent.
    private func receiverArm(_ door: String, in studio: String) -> Substring? {
        guard let start = studio.range(of: "publisher(for: .echoelChromeDoor)) { note in"),
              let end = studio.range(of: "default: break", range: start.upperBound..<studio.endIndex) else {
            XCTFail("ANCHOR MISSING: the chrome-door receiver (#454)")
            return nil
        }
        let receiver = studio[start.upperBound..<end.lowerBound]
        guard let caseStart = receiver.range(of: "case \"\(door)\":") else { return nil }
        let tail = receiver[caseStart.upperBound...]
        let next = tail.range(of: "case \"")?.lowerBound ?? tail.endIndex
        return tail[..<next]
    }

    /// Files under `Sources/Echoelmusic` whose CODE posts the chrome door with `door`, sorted.
    /// A walk that saw too few files is a finding, never a pass.
    private func chromeDoorPosters(of door: String) throws -> [String] {
        let base = repoRoot().appendingPathComponent(Self.sourcesRoot)
        guard let walker = FileManager.default.enumerator(atPath: base.path) else {
            XCTFail("cannot enumerate \(Self.sourcesRoot) — a scan that saw nothing is not a pass")
            return []
        }
        var found: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            guard let raw = try? String(contentsOf: base.appendingPathComponent(relative), encoding: .utf8)
            else { continue }
            if SourceText.codeOnly(raw).contains(Self.post + "\"\(door)\")") { found.append(relative) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        return found.sorted()
    }

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

    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func text(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }
}
