// TheToolButtonIsOneStyleTests.swift
// Echoel — Restructure F1 (2026-10-04, `scratchpads/PLAN_RESTRUCTURE_2026-10-04.md`).
//
// WHAT WAS WRONG. The app had no `ButtonStyle` at all. The small filled tool button — the note
// tools, the part bar, undo/redo — lived as three private `func button(` copies in
// `SelectedPartBar`, `PartNoteEditor` and `SongHistoryRow`, and they had already drifted: the
// note tools had no 44 pt WIDTH floor, the other two did. Each copy repeated colour, padding,
// tap frame, fill and hit shape; a fourth surface would have copied one of the three.
//
// THE REPAIR. `EchoelToolButtonStyle` in `EchoelTheme.swift` owns the look; the callers keep
// only what differs by place (the label's icon size and words, `.disabled`, the shortcut).
//
// HONEST GRADING (Tests/CISmoke/CLAUDE.md §1/§3). SOURCE-TEXT SCAN over `Sources/`. Transcribed
// by hand against the parent `4919d7001`: claim 1 RED there (no such style), claim 2 RED (three
// `func button(` bodies carry `.fill(EchoelTheme.fill)`), claim 3 RED (no `buttonStyle(Echoel…`).
// Claim 4 is a COUNTERWEIGHT on the style itself (pressed = opacity, never scale — Uncodixfy).
// It does NOT prove the buttons look right on a device; that is a device glance.

import XCTest

final class TheToolButtonIsOneStyleTests: XCTestCase {

    private static let theme = "Sources/Echoelmusic/Studio/EchoelTheme.swift"
    private static let adopters = [
        "Sources/Echoelmusic/Studio/SelectedPartBar.swift",
        "Sources/Echoelmusic/Studio/PartNoteEditor.swift",
        "Sources/Echoelmusic/Studio/SongHistoryRow.swift",
    ]

    /// 1 — exactly one declaration of the style in `Sources/`.
    func testTheToolStyleIsDeclaredOnce() throws {
        var hits: [String] = []
        for (path, text) in try swiftSources() where text.contains("struct EchoelToolButtonStyle") {
            hits.append(path)
        }
        XCTAssertEqual(hits, [Self.theme], """
            `EchoelToolButtonStyle` must be declared exactly once, in EchoelTheme.swift — found \
            in \(hits). A second declaration is the drift this style exists to end.
            """)
    }

    /// 2 — no private `button(` helper in `Studio/` re-paints the tool look by hand.
    func testNoButtonHelperCopiesTheToolLook() throws {
        var copies: [String] = []
        for (path, text) in try swiftSources() where path.contains("/Studio/") {
            var rest = Substring(text)
            while let head = rest.range(of: "func button(") {
                let body = try block(after: head.upperBound, in: rest, path: path)
                if body.contains(".fill(EchoelTheme.fill)") { copies.append(path) }
                rest = rest[head.upperBound...]
            }
        }
        XCTAssertTrue(copies.isEmpty, """
            A `func button(` helper paints the tool look itself (`.fill(EchoelTheme.fill)`) in \
            \(copies). Use `.buttonStyle(EchoelToolButtonStyle())` — the look has one owner.
            """)
    }

    /// 3 — the three former copies wear the style.
    func testTheThreeFormerCopiesWearTheStyle() throws {
        for path in Self.adopters {
            let code = try read(path)
            guard let head = code.range(of: "func button(") else {
                return XCTFail("ANCHOR MISSING: `func button(` in \(path) (#454)")
            }
            let body = try block(after: head.upperBound, in: Substring(code), path: path)
            XCTAssertTrue(body.contains(".buttonStyle(EchoelToolButtonStyle("), """
                \(path)'s `button(` no longer wears `EchoelToolButtonStyle`.
                """)
        }
    }

    /// 4 — COUNTERWEIGHT: the style floors both axes at 44 and dims on press without scaling.
    func testTheStyleKeepsTheFloorAndDimsWithoutScaling() throws {
        let code = try read(Self.theme)
        guard let head = code.range(of: "struct EchoelToolButtonStyle: ButtonStyle") else {
            return XCTFail("ANCHOR MISSING: `struct EchoelToolButtonStyle: ButtonStyle` (#454)")
        }
        let style = try block(after: head.upperBound, in: Substring(code), path: Self.theme)
        XCTAssertTrue(style.contains(".frame(minWidth: EchoelTheme.controlTapHeight, minHeight: EchoelTheme.controlTapHeight)"),
                      "the tool style must floor BOTH axes at the 44 pt tap height")
        XCTAssertTrue(style.contains(".contentShape(Rectangle())"),
                      "without a content shape a plain-label button hits only its glyphs (#485)")
        XCTAssertTrue(style.contains("configuration.isPressed ? EchoelTheme.pressedOpacity : 1"),
                      "a pressed tool button dims through the one pressed-opacity token")
        XCTAssertFalse(style.contains("scaleEffect"), "Uncodixfy: no scale on tap — opacity and colour only")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    private func root() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }

    private func read(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: root().appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// Every `.swift` file under `Sources/`, comment-stripped, keyed by repo-relative path.
    /// A walk that finds nothing FAILS — an empty walk would pass claims 1 and 2 vacuously.
    private func swiftSources() throws -> [(String, String)] {
        let sources = root().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            XCTFail("ANCHOR MISSING: cannot walk Sources/ (#454)")
            throw AnchorMissing(name: "Sources/")
        }
        var out: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            guard let cut = url.path.range(of: "/Sources/", options: .backwards) else { continue }
            let relative = "Sources/" + String(url.path[cut.upperBound...])
            out.append((relative, SourceText.codeOnly(text)))
        }
        guard out.count > 100 else {
            XCTFail("the Sources/ walk found only \(out.count) Swift files — the scan cannot be trusted")
            throw AnchorMissing(name: "Sources/ walk")
        }
        return out
    }

    /// The text between the first `{` after `start` and its matching `}` — string-literal aware.
    private func block(after start: String.Index, in code: Substring, path: String) throws -> Substring {
        guard let open = code[start...].firstIndex(of: "{") else {
            XCTFail("UNBALANCED: no body after the anchor in \(path) (#454)")
            throw AnchorMissing(name: path)
        }
        var depth = 0
        var inString = false
        var index = open
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
                    if depth == 0 { return code[code.index(after: open)..<index] }
                }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: the body after the anchor in \(path) never closes (#454)")
        throw AnchorMissing(name: path)
    }
}
