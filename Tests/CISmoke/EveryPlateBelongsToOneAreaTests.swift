// EveryPlateBelongsToOneAreaTests — DMMW Phase 1 (founder 2026-09-29): the main navigation
// Compose · Perform · Visuals · Library · Settings sits one row above the chip strip
// (`StudioArea`, `EchoelStudioView.areaBar`).
//
// WHAT IS PINNED, and why each claim:
//   1. DRIVEN — the five areas, in the founder's order, with the founder's words. An area row
//      whose labels drift from the brief is unfindable by the names it was specified under.
//   2. DRIVEN — every area speaks a hint, and exactly ONE area (Library) opens a sheet instead
//      of selecting a plate. A second non-plate area would be a second modal door, which is
//      what the black-screen law forbids growing.
//   3. SCAN — `StudioMenu.area` names EVERY `StudioMenu` case exactly once. The compiler
//      already refuses a missing case (the switch is exhaustive); what it does NOT refuse is
//      a `default:` sneaking in, which would silently file a new plate under some area. So
//      the claim is: no `default`, and the case list here equals the enum's.
//   4. SCAN — each plate-selecting area's home plate belongs to that same area (otherwise the
//      area would light up something else than the chip it selected), and Library's nil
//      branch reuses the existing `showOpen` slot.
//   5. SCAN — the area row adds no presentation modifier and rides inside the SAME `AnyView`
//      as the chip strip, so the root body's child count is unchanged (black-screen law).
//
// ⚠️ WHY A SOURCE SCAN for 3–5: `StudioMenu`, `areaHome` and `areaBar` are `private` members
// of a view; `@testable import` grants `internal` only (house pattern, see
// `ChipStripScrollsToSelectionTests`).
//
// GRADING (§3). Against the PARENT tree this file does NOT COMPILE — it names `StudioArea`,
// which this same commit creates — so no assertion has a verdict there. All five claims are
// FORWARD guards; none is a regression, and none could have been red before. Transcribed in
// Python against THIS tree (no toolchain here): claims 3–5 green — the parsed case list and
// the `area` switch are the same ten plates, each named once, no `default`; all four homes
// sit in their own area; Library returns nil and sets `showOpen`; the row carries none of the
// six modal modifiers and sits inside the shared `AnyView`. Claims 1–2 are read off
// `StudioArea.swift` directly.
//
// ⛔ HONEST LIMIT: this proves the row is WRITTEN and wired. It cannot prove how it looks,
// that the five labels fit a given phone at a given text size, or that VoiceOver reads the
// hint well. NEEDS-FOUNDER-VERIFY: open the app, tap each of the five areas, confirm the
// matching chip lights up and Library opens the project list.

import Foundation
import XCTest
@testable import Echoelmusic

final class EveryPlateBelongsToOneAreaTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"

    // MARK: - 1–2. DRIVEN

    func testTheFiveAreasAreTheFoundersFive() {
        XCTAssertEqual(StudioArea.allCases.map(\.label),
                       ["Compose", "Perform", "Visuals", "Library", "Settings"], """
            The main navigation is the founder's five areas in the founder's order \
            (2026-09-29). Renaming or reordering one changes the brief, not a detail.
            """)
    }

    func testEveryAreaSpeaksAndOnlyLibraryOpensASheet() {
        for area in StudioArea.allCases {
            XCTAssertFalse(area.spokenHint.isEmpty, "\(area.label) has no spoken hint (#482)")
        }
        XCTAssertEqual(StudioArea.allCases.filter { !$0.selectsPlate }, [.library], """
            Exactly one area may open a sheet instead of selecting a plate: Library, through \
            the existing `showOpen` slot. A second would be a second modal door (black-screen law).
            """)
    }

    // MARK: - 3. SCAN — the membership switch covers every plate, with no default

    func testTheAreaSwitchNamesEveryPlateExactlyOnce() throws {
        let lines = try codeLines(Self.studio)
        guard let caseLine = lines.first(where: {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("case bio, composition,")
        }) else {
            return XCTFail("the `StudioMenu` case list is gone or reordered — re-anchor this guard")
        }
        let plates = Set(caseLine.trimmingCharacters(in: .whitespaces)
            .dropFirst("case ".count)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) })
        XCTAssertGreaterThan(plates.count, 5, "parsed \(plates) — the anchor matched the wrong line")

        let body = try member("var area: StudioArea {", in: lines)
        XCTAssertFalse(body.contains { $0.contains("default") }, """
            `StudioMenu.area` has a `default:` — a new plate would then be filed under some area \
            silently instead of failing to compile until someone chooses.
            """)
        var named: [String] = []
        for line in body where line.trimmingCharacters(in: .whitespaces).hasPrefix("case .") {
            let head = line.split(separator: ":").first.map(String.init) ?? ""
            named += head.trimmingCharacters(in: .whitespaces)
                .dropFirst("case ".count)
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: "") }
        }
        XCTAssertEqual(named.count, Set(named).count, "a plate is named twice in `area`: \(named)")
        XCTAssertEqual(Set(named), plates, "`area` does not name exactly the `StudioMenu` cases")
    }

    // MARK: - 4. SCAN — each home belongs to its own area; Library reuses `showOpen`

    func testEachAreaHomeBelongsToItsOwnArea() throws {
        let lines = try codeLines(Self.studio)
        let membership = try member("var area: StudioArea {", in: lines)
        let homes = try member("private static func areaHome(_ area: StudioArea) -> StudioMenu? {",
                               in: lines)
        // Slice 2b (2026-09-30): the arrangement is the Piece STAGE (`StageShell`), not a plate
        // of the instrument, so Compose's home here is the tempo-and-variations plate. ⛔ It read
        // `("compose", "workstation")` from Phase 1 to slice 2b — rewritten as the decision.
        let expected: [(area: String, home: String)] = [
            ("compose", "composition"), ("perform", "sound"),
            ("visuals", "field"), ("settings", "export"),
        ]
        for pair in expected {
            XCTAssertTrue(homes.contains { $0.contains("case .\(pair.area):")
                                           && $0.contains("return .\(pair.home)") },
                          "`areaHome` no longer sends \(pair.area) to .\(pair.home)")
            XCTAssertTrue(membership.contains { $0.contains(".\(pair.home)")
                                                && $0.contains("return .\(pair.area)") }, """
                .\(pair.home) is the home of \(pair.area) but `area` files it elsewhere — the \
                area button would select a plate and then light up a different area.
                """)
        }
        XCTAssertTrue(homes.contains { $0.contains("case .library:") && $0.contains("return nil") },
                      "Library must own no plate — it opens the project list")
        let select = try member("private func selectArea(_ area: StudioArea) {", in: lines)
        XCTAssertTrue(select.contains { $0.contains("showOpen = true") }, """
            Library must reuse the existing `showOpen` slot — the same one the "open" chrome \
            door sets — never a new presentation modifier.
            """)
    }

    // MARK: - 5. SCAN — no modal, same AnyView as the strip

    func testTheAreaRowAddsNoModalAndRidesWithTheStrip() throws {
        let lines = try codeLines(Self.studio)
        let bar = try member("private var areaBar: some View {", in: lines)
            + (try member("private func areaButton(_ area: StudioArea, sharesRow: Bool) -> some View {",
                          in: lines))
        for modal in [".sheet(", ".fullScreenCover(", ".alert(", ".fileImporter(",
                      ".confirmationDialog(", ".popover("] {
            XCTAssertFalse(bar.contains { $0.contains(modal) },
                           "the area row carries `\(modal)` — black-screen law: reuse a slot")
        }
        guard let open = lines.firstIndex(where: { $0.contains("AnyView(VStack(spacing: 0) {") }),
              open + 2 < lines.count else {
            return XCTFail("the shared `AnyView(VStack(spacing: 0) {` wrapper is gone")
        }
        XCTAssertTrue(lines[open + 1].contains("areaBar") && lines[open + 2].contains("menuBar"), """
            `areaBar` must sit directly above `menuBar` INSIDE the same `AnyView` — a sibling \
            `AnyView` would add a child to the root body.
            """)
    }

    // MARK: - helpers

    /// Lines of the member that starts at `declaration`, up to the line that closes it
    /// (the first line indented like the declaration and starting with `}`).
    private func member(_ declaration: String, in lines: [String]) throws -> [String] {
        let hits = lines.indices.filter { lines[$0].contains(declaration) }
        guard hits.count == 1, let start = hits.first else {
            XCTFail("`\(declaration)` found \(hits.count)× in \(Self.studio) — expected once")
            return []
        }
        let indent = lines[start].prefix { $0 == " " }
        let end = lines[(start + 1)...].firstIndex { $0.hasPrefix(indent + "}") } ?? lines.endIndex
        return Array(lines[start..<end])
    }

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources/Echoelmusic")
        guard FileManager.default.fileExists(atPath: sources.path) else {
            throw XCTSkip("source tree not present at \(sources.path) — this test inspects "
                          + "source text, so it SKIPS rather than reporting a green it did "
                          + "not earn")
        }
        return root
    }

    /// Every line that is not a whole-line comment — the prose around `areaBar` names
    /// `showOpen` and `menuBar` too, and must not satisfy the scans.
    private func codeLines(_ path: String) throws -> [String] {
        let text = try String(contentsOf: try repoRoot().appendingPathComponent(path),
                              encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
    }
}
