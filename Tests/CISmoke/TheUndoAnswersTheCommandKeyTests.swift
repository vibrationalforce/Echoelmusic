// TheUndoAnswersTheCommandKeyTests.swift
// Echoel — UX audit 2026-10-02, slice 13a: ⌘Z undoes and ⇧⌘Z redoes the piece, through the ONE
// history row in the project head.
//
// WHAT IT GUARDS. With a keyboard on an iPad, or on a Mac, every professional editor answers
// ⌘Z. `SongHistoryRow` carries `.keyboardShortcut` on its two buttons, so the keys reach exactly
// the actions a finger reaches — `TimelineStore.undo()` / `redo()` — and nothing else. There is
// deliberately NO `UndoManager` bridge: a second registration would be a second owner of what
// "Undo" means, the defect class `TimelineStore` exists to prevent.
//
// KIND (per this directory's §1): SOURCE-TEXT SCAN. It proves where the modifiers sit — never
// that a hardware keyboard delivers the keys, or that the system menu shows them. Those stay
// device probes. NEEDS-FOUNDER-VERIFY: iPad with a keyboard (or a Mac) → Piece → move a part →
// ⌘Z puts it back, ⇧⌘Z moves it again; with nothing to undo, ⌘Z does nothing.
//
// GRADING (#433, parent = the tree before this slice): claims 1–3 are FORWARD guards — the
// parent has ZERO `KeyboardShortcut("z"` in `Sources/` (measured), so they are red there by
// absence of the new spelling, one absence reported three times (#486). Claims 4 and 5 are
// COUNTERWEIGHTS, green on both trees: the row is mounted once, and no `UndoManager` exists.
// Stripper `SourceText.codeOnly`: TRAGEND on claim 5 — the row's own header names `UndoManager`
// in prose, so the raw count is 1 and the stripped count 0 on this tree.

import Foundation
import XCTest

final class TheUndoAnswersTheCommandKeyTests: XCTestCase {

    private static let row = "Sources/Echoelmusic/Studio/SongHistoryRow.swift"
    private static let needle = "KeyboardShortcut(\"z\""
    private static let helperHead = "private func button(_ title: String, _ systemImage: String"

    // MARK: - Claim 1 — the Z shortcuts live in the history row and nowhere else

    func testOnlyTheHistoryRowOwnsTheZKey() throws {
        let hits = try swiftFiles().filter { path in
            (try? source(path))?.contains(Self.needle) == true
        }
        XCTAssertEqual(hits, [Self.row],
                       "⌘Z / ⇧⌘Z belong to the ONE history row in the head. Found in: \(hits)")
        XCTAssertEqual(occurrences(of: Self.needle, in: try source(Self.row)), 2,
                       "exactly two: Undo and Redo")
    }

    // MARK: - Claim 2 — ⌘Z is on the button that undoes, ⇧⌘Z on the one that redoes

    func testEachKeySitsOnItsOwnAction() throws {
        let code = try source(Self.row)
        guard let undo = code.range(of: "button(String(localized: \"Undo\")"),
              let redo = code.range(of: "button(String(localized: \"Redo\")"),
              undo.upperBound < redo.lowerBound,
              let helper = code.range(of: Self.helperHead) else {
            return XCTFail("ANCHOR MISSING: the Undo / Redo calls or the button helper (#454)")
        }
        let undoCall = String(code[undo.lowerBound..<redo.lowerBound])
        let redoCall = String(code[redo.lowerBound..<helper.lowerBound])
        XCTAssertTrue(undoCall.contains("KeyboardShortcut(\"z\", modifiers: .command)"),
                      "Undo answers ⌘Z")
        XCTAssertTrue(undoCall.contains("timeline.undo()"), "…and ⌘Z undoes")
        XCTAssertFalse(undoCall.contains(".shift"), "Undo carries no shift — that is Redo's key")
        XCTAssertTrue(redoCall.contains("KeyboardShortcut(\"z\", modifiers: [.command, .shift])"),
                      "Redo answers ⇧⌘Z")
        XCTAssertTrue(redoCall.contains("timeline.redo()"), "…and ⇧⌘Z redoes")
    }

    // MARK: - Claim 3 — the key obeys the same gate as the finger

    func testTheDisabledGateGovernsTheKey() throws {
        let helper = try body(of: Self.helperHead, in: try source(Self.row))
        guard let disabled = helper.range(of: ".disabled(!enabled)"),
              let key = helper.range(of: ".keyboardShortcut(shortcut)") else {
            return XCTFail("ANCHOR MISSING: `.disabled(!enabled)` or `.keyboardShortcut(shortcut)` left the helper")
        }
        XCTAssertLessThan(disabled.lowerBound, key.lowerBound,
                          "the availability gate sits on the same button, before the key — ⌘Z never undoes past the history")
    }

    // MARK: - Claim 4 — COUNTERWEIGHT: the row is mounted once, so each key has one owner

    func testTheHistoryRowIsMountedOnce() throws {
        var mounts = 0
        for path in try swiftFiles() {
            let code = try source(path)
            mounts += occurrences(of: "SongHistoryRow()", in: code)
        }
        XCTAssertEqual(mounts, 1, "two mounted rows would register ⌘Z twice")
    }

    // MARK: - Claim 5 — COUNTERWEIGHT: no second history

    func testThereIsNoSecondUndoHistory() throws {
        let hits = try swiftFiles().filter { path in
            let code = try source(path)
            return code.contains("UndoManager") || code.contains("undoManager")
        }
        XCTAssertEqual(hits, [], """
            `TimelineStore` is the one history of the piece. An `UndoManager` registration would be \
            a second owner of what Undo means. Found in: \(hits)
            """)
    }

    // MARK: - Helpers

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func body(of head: String, in code: String) throws -> String {
        guard let start = code.range(of: head),
              let open = code.range(of: "{", range: start.upperBound..<code.endIndex) else {
            throw AnchorMissing(reason: "`\(head)` is gone from \(Self.row) (#454)")
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let c = code[index]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(code[open.lowerBound...index]) } }
            index = code.index(after: index)
        }
        throw AnchorMissing(reason: "unbalanced braces after `\(head)`")
    }

    private func swiftFiles() throws -> [String] {
        let root = try repoRoot()
        let sources = root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            throw AnchorMissing(reason: "cannot enumerate Sources/")
        }
        var out: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            out.append(String(url.path.dropFirst(root.path.count + 1)))
        }
        XCTAssertGreaterThan(out.count, 100, "the walk over Sources/ returned almost nothing — a scan that matches nothing is a finding, never a pass")
        return out.sorted()
    }

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor this scan; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }
}
