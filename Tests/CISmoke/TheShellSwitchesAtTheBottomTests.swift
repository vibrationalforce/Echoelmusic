// TheShellSwitchesAtTheBottomTests.swift
// Echoel — the DAW shell's bottom switcher: Arrange · Mixer · Instrument · Browse · Piece, five
// words in one row at the bottom of the screen (DAW shell S2, founder 2026-10-02, inbox E18
// „Ja, so bauen", E19 „Nur im Detail").
//
// WHY: until S2 the workspace had THREE kinds of door to its areas — the „Piece | Instrument"
// seam above the stage, the Arrange/Mix/Export tiles of the piece's tab row, and the media
// library behind its own toggle. The founder's ask was one professional, legible environment
// („DAW look mit allen Features", „Vermeide, dass es unübersichtlich ist"), and every DAW names
// its views in one fixed place. The switcher is that place: every area has ONE door, and every
// entry is visible at every skill level — levels only hide detail fields (E19).
//
// The switcher stores nothing of its own. The two truths it projects were already persisted
// apart: the STAGE (`StudioStage`, piece | instrument — the instrument is hidden, never
// unmounted) and, new in S2, the piece's PLATE (`PieceView`). `ShellTab` is the pure projection
// of that pair, so no third key can disagree with them.
//
// THE THREE CLAIMS:
// 1. END-TO-END: the five entries in their order with their words; each entry maps to the
//    stage and plate it shows, and `ShellTab.current(stage:piece:)` returns it from that pair
//    (the round trip a relaunch performs); the Instrument entry carries no plate and wins on the
//    instrument stage whatever plate is stored; the plate key is "studio.pieceView", default
//    Arrange, so a fresh install still opens on the arrangement.
// 2. SOURCE: one spelling and one writer. The literal lives only in `StudioDefaultKeys`; the key
//    is referenced by exactly two files — the switcher (writes on a tap) and the Workstation
//    (reads); the switcher assigns its plate exactly twice (declaration + the one `select`) and
//    nothing binds either `@AppStorage` with `$`, which would be a writer the count cannot see.
//    Because the switcher is the ONE writer, "New piece" cannot move the plate — so the compose
//    guide draws on every plate while the piece has no part (review of 82b7a6a5a, MED).
// 3. SOURCE: the switcher is chrome, not a modal host and not a level gate — no presentation
//    modifier in `StageShell` (black-screen law), no `SkillLevel`, the chrome's Dynamic Type cap,
//    a solid surface with a 1-px border, no blur or material (Uncodixfy).
// 4. SOURCE (DAW shell S8a): on a phone held sideways the switcher is a RAIL on the leading edge.
//    `railMode` is the compact vertical size class (the Workstation's side-by-side test); the body
//    keeps ONE shape — `ShellLayout(rail:)` around the stage and then the switcher, no branch above
//    the stage — and the layout puts the switcher at the bottom in portrait and at the leading
//    origin in landscape, the stage beside it at full height. The rail's border is a 1-px column on
//    its trailing side, its surface runs under the LEADING safe area, its buttons keep the tap height.
//
// GRADING (§0/§3, no Swift toolchain in a web session — claims 2–3 transcribed in Python against
// both trees): against the parent (7537dcb02) `PieceView`, `ShellTab` and
// `StudioDefaultKeys.pieceView` are not declared, so this file does NOT COMPILE there — no
// assertion has a verdict on the parent; hand-transcribed, claims 2–3 are red there by ONE
// absence each (`shellSwitcher`, `"studio.pieceView"`; #486). The counterweights — `StageShell`
// still free of presentation modifiers, `StudioDefaultKeys.stage.key` still the stage's one
// spelling — are green on both. Claim 1 is a FORWARD guard on types this commit creates.
// DEVICE PROBE, open: the five words fit one row at 375 pt and at the cap, the active entry reads
// as active without colour, a tap on Instrument keeps the music playing — readings, not scans.
// S8a GRADING: claim 4 is a SOURCE-TEXT scan, transcribed against both trees: on the parent
// (6ba502435) eight of its nine assertions are red, and they are ONE finding — the rail does not
// exist there (#486); the tap-height assertion and all of claim 3 are counterweights, green on both.
// S8a REVIEW REPAIR: the fill assertion is a REGRESSION on 1fd73147f (the rail's surface stopped
// under its last entry) and green after; the two placements are now read per branch, so swapping
// the branch bodies is red (driven as a mutant: both go red, the other eight stay green).
// DEVICE PROBE, open: rotate a phone — the five entries stand in a column left of the stage, the
// column's surface and border run to the bottom, all entries are reachable (an SE at the rail's
// xxxLarge cap is the tight case), and the floating card stays clear of them.

import XCTest
@testable import Echoelmusic

final class TheShellSwitchesAtTheBottomTests: XCTestCase {

    private static let shell = "Sources/Echoelmusic/Studio/StageShell.swift"

    // MARK: 1 — five entries, each a projection of the two persisted keys

    func testTheSwitcherProjectsTheStageAndThePlate() {
        XCTAssertEqual(ShellTab.allCases, [.arrange, .mixer, .instrument, .browse, .project], """
            The switcher's order is the DAW reading order the founder approved (E18): Arrange · \
            Mixer · Instrument · Browse · Piece (H18 renamed "Project", 2026-10-07). A reorder moves a word under every thumb that \
            learned it — decide it, then change this line.
            """)
        XCTAssertEqual(ShellTab.allCases.map(\.label), ["Arrange", "Mixer", "Instrument", "Browse", "Piece"],
                       "the switcher's words — the guide's first card and the hints name them (#351)")
        XCTAssertEqual(PieceView.allCases, [.arrange, .mixer, .browse, .project],
                       "the piece's four plates; a fifth is a new area and needs its switcher entry in the same commit")

        for tab in ShellTab.allCases {
            if let plate = tab.pieceView {
                XCTAssertEqual(tab.stage, .piece, "`\(tab)` shows a plate of the piece, so it turns the Piece stage")
                XCTAssertEqual(ShellTab.current(stage: .piece, piece: plate), tab, """
                    `\(tab)` writes stage .piece + plate .\(plate) and does not read back as itself \
                    — after a relaunch the switcher would light a different entry than the screen shows.
                    """)
            } else {
                XCTAssertEqual(tab, .instrument, "only the Instrument entry carries no plate")
                XCTAssertEqual(tab.stage, .instrument)
            }
        }
        for plate in PieceView.allCases {
            XCTAssertEqual(ShellTab.current(stage: .instrument, piece: plate), .instrument, """
                On the instrument stage the stored plate .\(plate) must not light a piece entry — \
                the plate is remembered for the way back, it is not on screen.
                """)
        }
        XCTAssertEqual(Set(ShellTab.allCases.compactMap(\.pieceView)), Set(PieceView.allCases),
                       "every plate has exactly one switcher entry — a plate without one is a room without a door")

        XCTAssertEqual(StudioDefaultKeys.pieceView.key, "studio.pieceView",
                       "the persisted key — renaming it forgets every player's last plate")
        XCTAssertEqual(StudioDefaultKeys.pieceView.value, .arrange,
                       "a fresh install opens on the arrangement (TheAppOpensOnThePieceTests' promise, one level down)")
        XCTAssertEqual(PieceView(rawValue: "mixer"), .mixer, "raw values are persisted — rename a label, never a case")
    }

    // MARK: 2 — one spelling, two hands, one writer

    func testThePlateKeyHasOneSpellingAndOneWriter() throws {
        let root = repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            XCTFail("could not enumerate Sources/Echoelmusic — a scan that saw nothing is not a pass"); return
        }
        var seen = 0
        var literal: [String] = []
        var hands: [String] = []
        var bindings: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            seen += 1
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let code = SourceText.codeOnly(raw)
            if code.contains("\"studio.pieceView\"") { literal.append(url.lastPathComponent) }
            if code.contains("StudioDefaultKeys.pieceView.key") { hands.append(url.lastPathComponent) }
            if code.contains("$pieceRaw") || code.contains("$pieceViewRaw") { bindings.append(url.lastPathComponent) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        XCTAssertEqual(literal, ["StudioDefaultKeys.swift"], """
            The literal "studio.pieceView" is spelled in \(literal). One definition (#416): every \
            reader and writer goes through `StudioDefaultKeys.pieceView.key`.
            """)
        XCTAssertEqual(Set(hands), ["StageShell.swift", "WorkstationView.swift"], """
            The plate key is referenced by \(hands.sorted()). Two files are the design: the \
            switcher writes it on a tap, the Workstation reads it to choose its plate. A third is \
            a second door to an area — the twin S2 removed with the Arrange/Mix tiles.
            """)
        XCTAssertEqual(bindings, [], """
            \(bindings) binds the plate key with `$` — a Picker or a Toggle on that binding is a \
            writer the assignment count below cannot see.
            """)

        let shell = SourceText.codeOnly(try source(Self.shell))
        XCTAssertEqual(count("pieceRaw = ", in: shell), 2, """
            `pieceRaw = ` occurs \(count("pieceRaw = ", in: shell)) times in the switcher; exactly \
            two — the declaration's default and the one `select(_:)`. A third is a code path \
            choosing the plate for the player.
            """)
        let select = try member("private func select(_ tab: ShellTab) {", in: shell)
        XCTAssertTrue(select.contains("if let piece = tab.pieceView { pieceRaw = piece.rawValue }"),
                      "the plate is written from the tapped entry and only when it has one — the Instrument entry keeps the plate for the way back")
        let workstation = SourceText.codeOnly(try source("Sources/Echoelmusic/Studio/WorkstationView.swift"))
        XCTAssertEqual(count("pieceViewRaw = ", in: workstation), 1,
                       "the Workstation READS the plate — its one `pieceViewRaw = ` is the declaration's default")

        // The price of ONE writer (review of 82b7a6a5a, MED): "New piece" and Open move the STAGE,
        // never the plate, so a piece begun from the Piece plate lands there. The guide — the
        // creation path — must therefore draw on every plate while the piece has no part, or that
        // landing shows neither a guide nor a creation door.
        let guide = try member("private var composeGuide: some View {", in: workstation)
        XCTAssertTrue(guide.contains("if pieceView == .arrange || !facts.hasPart {"), """
            the compose guide is gated to the Arrange plate alone again — a new piece begun from \
            Piece, Browse or Mixer then lands on a plate with no way to start it
            """)
        XCTAssertFalse(workstation.contains("pieceViewRaw = PieceView"),
                       "the fix is the guide's gate, never a second writer of the plate")
    }

    // MARK: 3 — chrome, not a modal host and not a level gate

    func testTheSwitcherIsSolidChromeAtEveryLevel() throws {
        let shell = SourceText.codeOnly(try source(Self.shell))
        for modal in [".sheet(", ".fullScreenCover(", ".alert(", ".confirmationDialog(", ".fileImporter(",
                      ".fileExporter(", ".popover("] {
            XCTAssertFalse(shell.contains(modal), """
                `StageShell` carries `\(modal)` — it is an ancestor of the studio's 11-modifier chain \
                (black-screen law 10.76.34) and of the Workstation's importer (#W1).
                """)
        }
        XCTAssertFalse(shell.contains("SkillLevel"), """
            The switcher reads the skill level. E19 („Nur im Detail"): every view is visible at \
            every level; levels hide detail fields only.
            """)

        let switcher = try member("private var shellSwitcher: some View {", in: shell)
        XCTAssertTrue(switcher.contains("ForEach(ShellTab.allCases)"),
                      "the entries are the enum's cases — a hand-written row drifts from the projection")
        XCTAssertTrue(switcher.contains(".dynamicTypeSize(...DynamicTypeSize.accessibility1)"),
                      "the chrome's Dynamic Type cap — past it five words cannot share one row")
        XCTAssertTrue(switcher.contains(".background(EchoelTheme.surface"), "a solid surface (Uncodixfy)")
        XCTAssertTrue(switcher.contains("Rectangle().fill(EchoelTheme.border).frame(height: 1)"), "a 1-px border, not a shadow")
        for banned in ["Material", ".blur(", ".shadow("] {
            XCTAssertFalse(switcher.contains(banned), "the switcher uses `\(banned)` — Uncodixfy bans glass, blur and big shadows")
        }

        let body = try member("var body: some View {", in: shell)
        guard let stack = body.range(of: "ZStack {"), let bar = body.range(of: "shellSwitcher") else {
            XCTFail("ANCHOR MISSING: the stage `ZStack {` or `shellSwitcher` in the shell's body (#454)"); return
        }
        XCTAssertLessThan(stack.lowerBound, bar.lowerBound, "the switcher follows the stage in the body — in portrait it sits at the bottom, under the thumb")
    }

    // MARK: 4 — in landscape the switcher is a rail on the leading edge (S8a)

    func testInLandscapeTheSwitcherIsARailOnTheLeadingEdge() throws {
        let shell = SourceText.codeOnly(try source(Self.shell))
        XCTAssertTrue(shell.contains("@Environment(\\.verticalSizeClass) private var verticalSizeClass"),
                      "the rail follows the size class — an environment value that changes on rotation, never hot state")
        XCTAssertTrue(shell.contains("private var railMode: Bool { verticalSizeClass == .compact }"), """
            A compact vertical size class is a phone held sideways — the same test the Workstation's \
            side-by-side detail uses, so the shell and the plate turn together.
            """)

        let body = try member("var body: some View {", in: shell)
        XCTAssertTrue(body.hasPrefix("\n        ShellLayout(rail: railMode) {"), """
            The body is ONE shape in both orientations: `ShellLayout(rail:)` wraps the stage and the \
            switcher. A branch on the orientation above the stage would change the stage's identity \
            on rotation and unmount the always-mounted instrument (its `.onDisappear` stops the session).
            """)

        let layout = try member("private struct ShellLayout: Layout {", in: shell)
        XCTAssertTrue(layout.contains("let stage = subviews[0]") && layout.contains("let switcher = subviews[1]"),
                      "the layout reads the body's order — the stage first, the switcher second")
        // Each placement is read in ITS branch, so swapping the two branch bodies is red (review of S8a).
        let railBranch = try member("if rail {", in: layout)
        let barBranch = try member("} else {", in: layout)
        XCTAssertTrue(railBranch.contains("switcher.place(at: bounds.origin"),
                      "in landscape the rail stands at the LEADING origin — the visual card docks bottom-trailing")
        XCTAssertTrue(barBranch.contains("switcher.place(at: CGPoint(x: bounds.minX, y: bounds.maxY - height)"),
                      "in portrait the switcher stays at the bottom, under the thumb")

        let switcher = try member("private var shellSwitcher: some View {", in: shell)
        XCTAssertTrue(switcher.contains("Rectangle().fill(EchoelTheme.border).frame(width: 1)"),
                      "the rail's border is a 1-px column on its trailing side, not a shadow")
        XCTAssertTrue(switcher.contains("ignoresSafeArea(edges: rail ? .leading : .bottom)"),
                      "the rail's surface runs under the leading safe area, the bar's under the bottom one")
        guard let fill = switcher.range(of: ".frame(maxHeight: rail ? .infinity : nil, alignment: .top)"),
              let surface = switcher.range(of: ".background(EchoelTheme.surface") else {
            XCTFail("""
                ANCHOR MISSING: the rail's fill frame or its surface in `shellSwitcher` — the five \
                entries alone are ~250 pt, so without a fill the surface and the trailing border \
                stop under the last entry and the column below shows the page (review of S8a).
                """); return
        }
        XCTAssertLessThan(fill.lowerBound, surface.lowerBound,
                          "the fill comes BEFORE the surface, or the surface paints only the entries' height")
        let button = try member("private func switcherButton(_ tab: ShellTab, isActive: Bool) -> some View {", in: shell)
        XCTAssertTrue(button.contains("minHeight: EchoelTheme.controlTapHeight"),
                      "each entry keeps the 44-pt tap height in the rail too — the column must not squeeze them")
    }

    // MARK: helpers

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { break }
            dir = dir.deletingLastPathComponent()
        }
        return dir
    }

    private func source(_ path: String) throws -> String {
        let url = repoRoot().appendingPathComponent(path)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(path) could not be read — a missing anchor is a finding.")
            return ""
        }
        return text
    }

    private func count(_ needle: String, in code: String) -> Int {
        code.components(separatedBy: needle).count - 1
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
}
