// TheInstrumentHasOneRowOfPlateDoorsTests.swift
// Echoel — the Instrument stage reaches its plates through ONE row: the chip strip.
//
// WHY: founder 2026-10-01, „Vermeide das es mehrfache Wege zu einem Bereich gibt und das es so
// unübersichtlich ist. Viele Bereiche sind zu groß und füllen den Bildschirm aus. Vermeide slop."
// From 2026-09-29 the Instrument carried an AREA row (Compose · Perform · Visuals · Library ·
// Settings, `StudioArea`) directly above the chip strip. Measured on 430b20307: four of its five
// buttons selected a plate that already has its own chip in the strip below (Tempo, Sound,
// Field, Save/Export), and Library raised the project sheet that the Open tile on the same
// stage raises — a second way to every place it reached, for one more 44 pt row of chrome. The
// row and its type are deleted; this file holds what the deletion must leave standing.
//
// THE FOUR CLAIMS:
// 1. The area row is gone: no `StudioArea` in the CODE of `Sources/` (comments may tell its
//    history), none of its four members, and its file is absent. A walk that reads too few files
//    is ANCHOR MISSING, never a vacuous pass.
// 2. Nothing became unreachable — every plate the area row reached still has a chip: each
//    `StudioMenu` case except `.bio` sits in `studioChips` exactly once; `chips(for:)` decides
//    every case (no `default:`), keeps Save/Export at every level (the level switch lives in
//    its `utilityRow`, so no level can hide the way back), and `.bio` keeps its pulse-pill door.
// 3. The root body keeps its child count: the strip is wrapped as `AnyView(menuBar` directly
//    after the start row (black-screen law — the deleted row sat INSIDE that AnyView for this
//    reason, and removing it must not add a sibling).
// 4. Open has ONE door: `showOpen = true` is written exactly once — the chrome door "open", which
//    the ≡ menu in `WorkspaceView.topBar` posts on both stages — and the project sheet is
//    presented from one slot. The menu entry is NEVER disabled: the sheet also holds "New piece"
//    and Import, which an empty library needs most, and the deleted Library button was their
//    only always-lit door. Without this half the deletion would shut both on a fresh install.
//    ⛔ Until DAW shell S3 (2026-10-02) this claim counted TWO writers — the Instrument's Open
//    tile (`quickDoorRow`) and the chrome door posted by the Piece stage's Open tile. S3 moved
//    both into the one menu, so the count went DOWN on purpose and every other needle got
//    STRICTER: the Piece stage may no longer post "open" at all (a second door), and the menu's
//    entry is pinned ungated.
//
// IT FORBIDS NOTHING LEGITIMATE (#364). A future main navigation is allowed; it arrives as a
// REPLACEMENT for a door that exists, and edits claims 1 and 4 in the same commit with the
// reason. It must not arrive as a second row above the first.
//
// GRADING (§0/§3 — no Swift toolchain in a web session; transcribed in Python against the
// parent 430b20307 and the slice tree): claims 1, 3 and 4 are REGRESSIONS, red on the parent for
// their named reason (`StudioArea` in code, `AnyView(VStack(spacing: 0) {` around `areaBar`, a
// third `showOpen = true` in `selectArea`, and both Open tiles gated on a non-empty library);
// claim 2 and claim 4's sheet needles are COUNTERWEIGHTS, green on both — the "nothing was
// lost" half, which must stay green across the deletion.
// S3 RE-GRADE (against f4b4f006d): claim 4's new needles are REGRESSIONS there — two writers, no
// "open" entry in the ≡ menu (one absence, reported once), and the Piece stage still posting
// "open"; the sheet needles stay COUNTERWEIGHTS. Claims 1–3 are untouched.
// DEVICE PROBE, open: the Instrument shows the start row, then the chip strip, no row between;
// Tempo, Sound, Field and Save/Export each open from their chip; Open opens the saved pieces
// from the Instrument and from the Piece stage, and on a fresh install shows "No saved pieces
// yet." with New piece and Import; Beginner sees Sound · Mood · Save/Export and
// can raise the level from Save/Export.

import XCTest

final class TheInstrumentHasOneRowOfPlateDoorsTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let workspace = "Sources/Echoelmusic/Studio/WorkspaceView.swift"
    private static let areaFile = "Sources/Echoelmusic/Studio/StudioArea.swift"

    /// Fewest Swift files the `Sources/` walk must read for claim 1 to mean anything.
    private static let walkFloor = 250

    // MARK: 1 — the area row and its type are gone

    func testTheAreaRowIsGone() throws {
        let root = repoRoot()
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(Self.areaFile).path), """
            `StudioArea.swift` is back. The area row was a second door to plates the chip strip \
            already opens (founder 2026-10-01: one way to each place). A new main navigation \
            REPLACES a door; it is not a second row above the strip.
            """)

        let sources = root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            return XCTFail("ANCHOR MISSING: cannot walk `Sources/` (#454)")
        }
        var scanned = 0
        var offenders: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }
            scanned += 1
            let code = SourceText.codeOnly(raw)
            for token in ["StudioArea", "areaBar", "areaHome(", "selectArea(", "areaButton("] where code.contains(token) {
                offenders.append("\(url.lastPathComponent): `\(token)`")
            }
        }
        XCTAssertGreaterThan(scanned, Self.walkFloor, """
            ANCHOR MISSING: the walk read \(scanned) Swift files under `Sources/` — too few for \
            an absence to mean anything (#454). Re-point the walk; do not lower the floor to pass.
            """)
        XCTAssertTrue(offenders.isEmpty, """
            the area row is back in code: \(offenders.joined(separator: ", ")). Every plate it \
            reached has a chip in the strip below it, and Library raised the sheet the Open tile \
            raises — two ways to one place. Comments may name it; code may not.
            """)
    }

    // MARK: 2 — counterweight: every plate the row reached still has its one chip

    func testEveryPlateButBioHasExactlyOneChip() throws {
        let code = SourceText.codeOnly(try text(Self.studio))
        guard let caseLine = code.components(separatedBy: "\n").first(where: { $0.contains("case bio, composition,") }) else {
            return XCTFail("ANCHOR MISSING: the `StudioMenu` case list `case bio, composition,` (#454)")
        }
        let cases = caseLine
            .replacingOccurrences(of: "case", with: "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        XCTAssertGreaterThanOrEqual(cases.count, 9, "ANCHOR MISSING: parsed only \(cases.count) plate cases (#454)")

        guard let stripStart = code.range(of: "private static let studioChips: [StudioMenu] ="),
              let open = code.range(of: "[", range: stripStart.upperBound..<code.endIndex),
              let close = code.range(of: "]", range: open.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: `studioChips` (#454)")
        }
        let strip = code[open.upperBound..<close.lowerBound]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for plate in cases where plate != "bio" {
            XCTAssertEqual(strip.filter { $0 == ".\(plate)" }.count, 1, """
                `.\(plate)` is not in the chip strip exactly once. With the area row gone the strip \
                is the Instrument's ONE row of plate doors; a plate without a chip is unreachable \
                (#164/#227), a plate with two is the double door this slice removed.
                """)
        }
        XCTAssertFalse(strip.contains(".bio"), "`.bio` stays off the strip — the pulse pill is its door (#290)")

        let filter = try member("private static func chips(for level: SkillLevel) -> [StudioMenu] {", in: code)
        XCTAssertFalse(filter.contains("default:"), """
            `chips(for:)` has a `default:` — a new plate would then pick a level by accident \
            instead of by decision (the compiler must ask).
            """)
        guard let always = filter.range(of: "case .sound, .mood, .export:") else {
            return XCTFail("ANCHOR MISSING: the always-shown arm `case .sound, .mood, .export:` (#454)")
        }
        XCTAssertTrue(filter[always.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("return true"), """
            Save/Export is no longer shown at every level. The level switch lives in its \
            `utilityRow`; hiding the chip at any level hides the way back up.
            """)
        guard let bio = filter.range(of: "case .bio:") else {
            return XCTFail("ANCHOR MISSING: the `.bio` arm of `chips(for:)` (#454)")
        }
        XCTAssertTrue(filter[bio.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("return false"),
                      "`.bio` is never a chip — the pulse pill is its door")

        let utility = try member("private var utilityRow: some View {", in: code)
        XCTAssertTrue(utility.contains("skillLevelRow"), """
            the Save/Export plate no longer mounts the level switch — a lower level could not be \
            undone from the one chip every level keeps
            """)
        guard let receiver = code.range(of: "publisher(for: .echoelChromeDoor)) { note in"),
              let bioArm = code.range(of: "case \"bio\":", range: receiver.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: the chrome door `case \"bio\":` (#454)")
        }
        let armTail = code[bioArm.upperBound...]
        let armEnd = armTail.range(of: "case \"")?.lowerBound ?? armTail.endIndex
        XCTAssertTrue(armTail[..<armEnd].contains("activeMenu = .bio"),
                      "the pulse pill's door still selects the Bio plate")
    }

    // MARK: 3 — the root keeps its child count

    func testTheStripIsTheRootChildAfterTheStartRow() throws {
        let code = SourceText.codeOnly(try text(Self.studio))
        XCTAssertEqual(code.components(separatedBy: "AnyView(menuBar").count - 1, 1, """
            the chip strip is not wrapped as `AnyView(menuBar` exactly once. The deleted area row \
            sat INSIDE that AnyView so the root VStack kept its child count; after the deletion \
            the strip is that child alone (black-screen law, 10.76.34).
            """)
        guard let start = code.range(of: "AnyView(startControlRow"),
              let strip = code.range(of: "AnyView(menuBar", range: start.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: `AnyView(startControlRow` followed by `AnyView(menuBar` (#454)")
        }
        XCTAssertFalse(code[start.upperBound..<strip.lowerBound].contains("AnyView("), """
            a root child sits between the start row and the strip. A row added here is a new root \
            child — the metadata-depth law forbids growing that list.
            """)
    }

    // MARK: 4 — Open has one door per stage and one sheet

    func testOpenHasOneDoorPerStage() throws {
        let code = SourceText.codeOnly(try text(Self.studio))
        XCTAssertEqual(code.components(separatedBy: "showOpen = true").count - 1, 1, """
            the project sheet is raised from a number of places other than one — the chrome door \
            "open", which the ≡ menu posts on both stages (DAW shell S3). A second writer is a \
            second door to the same sheet (the deleted Library button, the deleted Open tile).
            """)
        guard let receiver = code.range(of: "publisher(for: .echoelChromeDoor)) { note in"),
              let openArm = code.range(of: "case \"open\":", range: receiver.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: the chrome door `case \"open\":` (#454)")
        }
        let armTail = code[openArm.upperBound...]
        let armEnd = armTail.range(of: "case \"")?.lowerBound ?? armTail.endIndex
        XCTAssertTrue(armTail[..<armEnd].contains("showOpen = true"), "the chrome door \"open\" raises the sheet")
        XCTAssertEqual(code.components(separatedBy: ".sheet(isPresented: $showOpen) { AnyView(openSheet) }").count - 1, 1,
                       "the saved pieces are presented from ONE slot")
        let sheet = try member("private var openSheet: some View {", in: code)
        XCTAssertTrue(sheet.contains("newPieceRow"), "counterweight: the sheet still offers New piece — the reason Open is never shut")
        XCTAssertTrue(sheet.contains("projectImportPresented = true"), "counterweight: the sheet still offers Import")

        let workspace = SourceText.codeOnly(try text(Self.workspace))
        let bar = try member("private var topBar: some View {", in: workspace)
        let menu = try member("Menu {", in: bar)
        XCTAssertEqual(menu.components(separatedBy: "Button { Self.postDoor(\"open\") }").count - 1, 1, """
            the ≡ menu does not hold exactly one Open entry. It is the ONE door to the project \
            sheet on both stages since DAW shell S3.
            """)
        XCTAssertFalse(menu.contains(".disabled("), """
            an entry of the ≡ menu is gated. Open must never be: the sheet also holds "New piece" \
            and Import, which a fresh install needs most — and the menu is built in the ROOT body, \
            where reading the library or the composed notes is the 10.76.50 freeze.
            """)

        let workstation = SourceText.codeOnly(try text(Self.workstation))
        XCTAssertFalse(workstation.contains("object: \"open\""), """
            the Piece stage posts the door "open" again — a second Open door on that stage, next \
            to the ≡ menu that already reaches the same sheet (DAW shell S3: one door per area).
            """)
        XCTAssertFalse(workstation.contains("canOpen"), "the Piece stage's Open door is gated again (`canOpen`)")
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

    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func text(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }
}
