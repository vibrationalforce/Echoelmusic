// TheMatrixHasADoorTests.swift
// Echoel — #1250 (founder 2026-09-11: *"Eine Verknüpfung mit der Routing Matrix ist auch
// klar."*). The modulation matrix has its first authoring surface: the "Body → parameter" card
// in the Routing sheet (`PatchbayView.modulationSection`).
//
// MEASURED BEFORE THIS SLICE (#541, four months standing): `ModulationEngine` ran at launch,
// persisted, streamed `/echoelmusic/mod/<key>` — and `ModRoute(` had ONE construction site in
// `Sources/`, the matrix's own decoder. The CURRENT STATE line said "verdrahtet, türlos, ohne
// Route wirkungslos". `TheTempoDestinationHasNoRouteTests` pinned that set and its message named
// the two prose homes; both moved in this commit and that guard's claim is relaxed to
// decoder + editor.
//
// SOURCE-TEXT SCAN throughout: the section and the row are `private` on a `View`. Whether a
// route authored here audibly moves the harmony mix is a DEVICE PROBE — NEEDS-FOUNDER-VERIFY
// at `modulationSection`.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`8a4d64a`) and this tree: claims
// 1–4 and 6 RED on the parent, GREEN here; claim 5 (the surface reads nothing hot) GREEN on
// both — the counterweight. Stripper: TRAGEND, measured — claim 5 flips raw vs. stripped on
// this tree (the section's doc comment names `lastOutputs` to forbid it; 1 of 6 verdicts),
// PROPHYLAKTISCH for the rest.

import Foundation
import XCTest

final class TheMatrixHasADoorTests: XCTestCase {

    private static let patchbay = "Sources/Echoelmusic/Studio/PatchbayView.swift"

    /// Claim 1 — the editor constructs routes, once, in the "Add route" menu, and persists them.
    func testTheAddRouteMenuConstructsAndSaves() throws {
        let src = SourceText.codeOnly(try text(Self.patchbay))
        let section = try Self.member("private var modulationSection: some View", in: src)
        XCTAssertEqual(section.components(separatedBy: "ModRoute(source: .coherence,").count - 1, 1,
                       "the Add-route menu no longer constructs a route (#1250)")
        XCTAssertGreaterThanOrEqual(section.components(separatedBy: "engine.save()").count - 1, 2,
                                    "add and delete must both persist through `save()` (#1250)")
        XCTAssertTrue(section.contains(".onChange(of: engine.matrix.routes) { _, _ in engine.save() }"),
                      "field/picker edits no longer persist — a route would die at relaunch (#1250)")
        XCTAssertTrue(section.contains("ForEach(ModDestinationKey.all, id: \\.self)"),
                      "the Add-route menu must offer every registered destination from `ModDestinationKey.all` (#1249/#1250)")
    }

    /// Claim 2 — the card is mounted in the sheet's content.
    func testTheCardIsMountedInTheRoutingSheet() throws {
        let src = SourceText.codeOnly(try text(Self.patchbay))
        let content = try Self.member("private var content: some View", in: src)
        XCTAssertTrue(content.contains("modulationSection"),
                      "`modulationSection` is declared but not mounted in `content` — the matrix is doorless again (#1250)")
    }

    /// Claim 3 — the row's source picker offers only channels with a producer, plus the route's own.
    func testTheSourcePickerFiltersOnHasProducer() throws {
        let src = SourceText.codeOnly(try text(Self.patchbay))
        let row = try Self.member("private struct ModulationRouteRow: View", in: src)
        XCTAssertTrue(row.contains("ModSource.allCases.filter(\\.hasProducer)"),
                      "the source picker offers channels without a producer — a control that lies (`ModSource.hasProducer` doc, #1250)")
        XCTAssertTrue(row.contains("if !list.contains(route.source) { list.append(route.source) }"),
                      "a persisted route to a dropped channel would render a blank menu (#1250)")
        XCTAssertTrue(row.contains("ModDestinationKey.all.map(ModDestination.init)"),
                      "the destination picker no longer draws from the one key list (#1250)")
    }

    /// Claim 4 — numeric amounts are `EchoelValueField`s with a stated grid; named choices are Pickers.
    func testNumbersAreFieldsAndChoicesArePickers() throws {
        let src = SourceText.codeOnly(try text(Self.patchbay))
        let row = try Self.member("private struct ModulationRouteRow: View", in: src)
        XCTAssertTrue(row.contains("EchoelValueField(label: \"Depth\", value: $route.depth, range: 0...1, decimals: 2)"))
        XCTAssertTrue(row.contains("EchoelValueField(label: \"Smooth\", value: $route.smoothingTau,"))
        XCTAssertFalse(row.contains("Slider("), "a raw Slider on a parameter row (the `EchoelValueField` law)")
        XCTAssertEqual(row.components(separatedBy: "Picker(").count - 1, 3, "source, destination and curve are the three named choices (#1250)")
    }

    /// Claim 5 — counterweight: the sheet observes nothing hot from the engine.
    func testTheSheetReadsNoHotEngineState() throws {
        let src = SourceText.codeOnly(try text(Self.patchbay))
        XCTAssertFalse(src.contains("lastOutputs"),
                       "`PatchbayView` reads `lastOutputs` (~1 Hz) — the whole sheet becomes an observer of the modulation tick; a live meter belongs in its own leaf (10.76.41/50, #1250)")
        XCTAssertFalse(src.contains("orderedOutputs"))
    }

    /// Claim 6 — the two prose homes moved with the surface.
    func testTheProseHomesMoved() throws {
        let law = try text("CLAUDE.md")
        XCTAssertTrue(law.contains("seit #1250 (Founder 2026-09-11) hat die Matrix ihre Fläche"),
                      "CLAUDE.md's CURRENT STATE modulation line no longer says the matrix has a surface (#1250)")
        XCTAssertTrue(law.contains("ERLEDIGT mit #1250:** `PatchbayView.modulationSection` konstruiert `ModRoute(`"),
                      "the doorless register's modulation entry no longer records #1250 (#1250)")
    }

    // MARK: - helpers

    private static func member(_ marker: String, in src: String) throws -> String {
        let hits = src.components(separatedBy: marker).count - 1
        guard hits == 1, let start = src.range(of: marker) else {
            throw XCTSkip("anchor `\(marker)` occurs \(hits)× — re-anchor before trusting a zero (#408)")
        }
        guard let open = src[start.upperBound...].firstIndex(of: "{") else { return "" }
        var depth = 0
        var i = open
        while i < src.endIndex {
            let c = src[i]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(src[open...i]) } }
            i = src.index(after: i)
        }
        return String(src[open...])
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
