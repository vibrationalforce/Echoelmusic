// TheVisualWindowHasOneShowHideDoorTests.swift
// Echoel — GMMW P1-3 (founder 2026-10-08: „vermeide Unübersichtlichkeit"; and 2026-10-01: „Vermeide
// das es mehrfache Wege zu einem Bereich gibt"). The floating visual window had two show/hide doors
// that wrote the same flag: the head's monitor tile (`WorkspaceView`, on screen on both stages at
// every level) and a "Show/Hide visual window" button in the Instrument's Field panel. Two doors to
// one fact. The tile stays — it is the one that is everywhere — and the Field panel keeps what only
// it offers: Full screen.
//
// WHAT IT PINS (SOURCE-TEXT scans — both views are `private`-membered and no bundle can render them):
// 1. `floatingVisualVisible.toggle()` occurs exactly ONCE in `Sources/` code, and it is the head's
//    tile in `WorkspaceView`: the button whose label is `ImmersiveMonitorMini`.
// 2. The Field panel (`visualPanel`) no longer reads or writes the flag, and still opens Full screen
//    (`openFullscreenVisual()`).
// 3. The four retired words are gone from the catalog — an entry with no source is an orphan.
// ⚠️ It forbids nothing else (#364): the flag keeps its other writers — the launch seed, the Full
// screen door and the pre-take visibility save/restore set it to a VALUE, never toggle it. The tile's
// spoken label is pinned where it already is (`TheChromeSpeaksOneLanguageTests`, #416).
//
// Grading (§0, no Swift toolchain; transcribed into Python and driven against the parent `4d43cd1`
// and this tree): claims 1–3 are REGRESSIONS — red on the parent for their named reason (two
// toggles; the panel reads the flag; four keys present); the Full-screen half of claim 2 is a
// COUNTERWEIGHT, green on both.
// NOT covered: whether a sighted player finds the tile — a device probe. NEEDS-FOUNDER-VERIFY: open
// the Instrument's Field panel → Full screen is there, no "Show/Hide visual window"; tap the head's
// picture tile → the window hides and shows.

import Foundation
import XCTest

final class TheVisualWindowHasOneShowHideDoorTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let workspace = "Sources/Echoelmusic/Studio/WorkspaceView.swift"

    // MARK: 1 — one toggle, and it is the head's tile

    func testTheHeadTileIsTheOneToggle() throws {
        let root = repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            return XCTFail("cannot enumerate Sources/Echoelmusic — a scan that saw nothing is not a pass")
        }
        var toggles: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8) else { continue }
            let hits = SourceText.codeOnly(text).components(separatedBy: "floatingVisualVisible.toggle()").count - 1
            toggles += Array(repeating: relative, count: hits)
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        XCTAssertEqual(toggles, ["Studio/WorkspaceView.swift"],
                       "one show/hide door for the floating visual: the head's monitor tile")

        let workspace = try source(Self.workspace)
        guard let toggle = workspace.range(of: "floatingVisualVisible.toggle()"),
              let label = workspace.range(of: "ImmersiveMonitorMini(active:", range: toggle.upperBound..<workspace.endIndex) else {
            return XCTFail("ANCHOR MISSING: the tile's toggle or its `ImmersiveMonitorMini` label (#454)")
        }
        let between = workspace[toggle.upperBound..<label.lowerBound]
        XCTAssertTrue(between.contains("} label: {"), "the toggle is the action of the button the monitor tile labels")
    }

    // MARK: 2 — the Field panel keeps Full screen and leaves the flag alone

    func testTheFieldPanelKeepsFullScreenOnly() throws {
        let panel = try member("private var visualPanel: some View {", in: try source(Self.studio))
        XCTAssertFalse(panel.contains("floatingVisualVisible"),
                       "the Field panel reads or writes the window flag again — a second show/hide door (GMMW P1-3)")
        XCTAssertTrue(panel.contains("openFullscreenVisual()"), "COUNTERWEIGHT: the Field panel still opens Full screen")
    }

    // MARK: 3 — the retired words left the catalog

    func testTheRetiredWordsLeftTheCatalog() throws {
        let url = repoRoot().appendingPathComponent("Sources/Echoelmusic/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = root["strings"] as? [String: Any] else {
            return XCTFail("ANCHOR MISSING: the catalog's `strings` (#454)")
        }
        XCTAssertGreaterThan(strings.count, 100, "COUNTERWEIGHT: the catalog was read")
        for retired in ["Hide visual window", "Show visual window",
                        "Hide the floating visual window", "Show the floating visual window"] {
            XCTAssertNil(strings[retired], "the catalog still carries `\(retired)` — its button is gone")
        }
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let reason: String }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func source(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(reason: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// The text inside the braces that open at the first `{` from `head` on (#408 — never a window).
    private func member(_ head: String, in text: String) throws -> String {
        guard let start = text.range(of: head),
              let open = text[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: `\(head)` (#454)")
            throw AnchorMissing(reason: head)
        }
        var depth = 1
        var index = text.index(after: open)
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[text.index(after: open)..<index]) }
            default: break
            }
            index = text.index(after: index)
        }
        XCTFail("UNBALANCED: `\(head)` never closes (#454)")
        throw AnchorMissing(reason: head)
    }
}
