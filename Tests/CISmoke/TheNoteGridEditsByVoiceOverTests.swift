// TheNoteGridEditsByVoiceOverTests.swift
// Echoel — audit 2026-10-03, slice A11Y-1 ("der Noten-Editor ist mit VoiceOver bearbeitbar").
//
// WHAT IT GUARDS. `PartNoteEditor`'s grid let VoiceOver PICK a note (S9 stepping) and the buttons
// below it transpose and quantize the pick — but adding a note, moving it in time and changing its
// length were TOUCH ONLY: a tap on an empty cell, a drag, a drag on the right edge. Five named
// actions now reach them, and each goes through the SAME pure op as its gesture and the SAME one
// writer (`timeline.setClipNotes`), so each is one commit and one Undo, and a refused part
// (`editable == false`) refuses the action exactly as it refuses the gesture.
//
// §1 LIMIT: every claim is a SOURCE-TEXT SCAN — the actions are closures on a `private` view body
// no bundle can instantiate. The pure ops they call are covered end to end elsewhere
// (`ClipNoteEdit`). Whether VoiceOver lists the five actions in its rotor and speaks the
// announcement is a DEVICE PROBE — open, not covered here.
//
// §3 HONEST GRADING against the parent (25be0b50e): this file names no new Swift symbol (every
// needle is text), so it compiles there. Claims 1–4 are red there for ONE absence (#486): the five
// actions and their three helpers do not exist. Claim 5 is a COUNTERWEIGHT, green on both trees:
// the gestures the actions mirror still call the same ops. Stripper `SourceText.codeOnly`:
// PROPHYLAKTISCH (0 verdicts flip — the doc comments name the helpers but no needle is a bare
// helper name; the catalog is read raw, it is JSON).

import Foundation
import XCTest

final class TheNoteGridEditsByVoiceOverTests: XCTestCase {

    private static let editor = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"
    private static let catalog = "Sources/Echoelmusic/Resources/Localizable.xcstrings"
    private static let actions = ["Add a note", "Move earlier", "Move later", "Make longer", "Make shorter"]

    // MARK: - Claim 1 — the five actions sit on the grid, beside the stepping actions

    func testTheGridOffersTheFiveEditActions() throws {
        let code = try source(Self.editor)
        guard let stepping = code.range(of: ".accessibilityAction(named: \"Select previous note\")"),
              let zoom = code.range(of: ".accessibilityZoomAction") else {
            return XCTFail("ANCHOR MISSING: the grid's stepping action or its zoom action")
        }
        // The five live in ONE modifier: inline they tipped the grid's chain past the
        // type-checker's time limit (Compile Check on f28ee9019). The modifier is applied on the
        // grid, between stepping and zoom — the element VoiceOver focuses.
        let between = String(code[stepping.upperBound..<zoom.lowerBound])
        XCTAssertEqual(occurrences(of: ".modifier(NoteEditActions(", in: code), 1, "the modifier is applied once")
        XCTAssertTrue(between.contains(".modifier(NoteEditActions("), "on the grid, between stepping and zoom")
        XCTAssertTrue(between.contains("addNoteByAction(after: pickedOnScreen,"), "add acts on the grid's pick")
        XCTAssertTrue(between.contains("nudgeByAction(pickedOnScreen, bySteps: dStep,"), "nudge acts on the grid's pick")
        XCTAssertTrue(between.contains("stretchByAction(pickedOnScreen, bySteps: dSteps,"), "stretch acts on the grid's pick")
        let actions = try functionBody("private struct NoteEditActions: ViewModifier {", in: code)
        for name in Self.actions {
            XCTAssertEqual(occurrences(of: ".accessibilityAction(named: \"\(name)\")", in: code), 1,
                           "`\(name)` is declared once")
            XCTAssertTrue(actions.contains(".accessibilityAction(named: \"\(name)\")"),
                          "`\(name)` is one of the grid's edit actions")
        }
        XCTAssertTrue(actions.contains("\"Move earlier\") { nudge(-1) }"), "Move earlier is one step back")
        XCTAssertTrue(actions.contains("\"Move later\") { nudge(1) }"), "Move later is one step on")
        XCTAssertTrue(actions.contains("\"Make longer\") { stretch(1) }"), "Make longer is one step")
        XCTAssertTrue(actions.contains("\"Make shorter\") { stretch(-1) }"), "Make shorter is one step")
    }

    // MARK: - Claim 2 — each action is ONE commit through the one writer, via the gesture's pure op

    func testEachActionIsOneCommitThroughTheOneWriter() throws {
        let code = try source(Self.editor)
        let ops = [
            ("private func addNoteByAction(", "ClipNoteEdit.adding("),
            ("private func nudgeByAction(", "ClipNoteEdit.moving("),
            ("private func stretchByAction(", "ClipNoteEdit.resizing("),
        ]
        for (head, op) in ops {
            let body = try functionBody(head, in: code)
            XCTAssertEqual(occurrences(of: "timeline.setClipNotes(", in: body), 1, "`\(head)` commits once — one Undo")
            XCTAssertEqual(occurrences(of: op, in: body), 1, "`\(head)` uses the gesture's pure op `\(op)`")
            XCTAssertFalse(body.contains("clipStore.update"), "`\(head)` writes through the timeline, never past it")
        }
        XCTAssertTrue(try functionBody("private func nudgeByAction(", in: code).contains("dPitch: 0,"),
                      "a nudge moves in time only")
    }

    // MARK: - Claim 3 — a refused part refuses the action, as it refuses the gesture

    func testARefusedPartRefusesTheAction() throws {
        let code = try source(Self.editor)
        for head in ["private func addNoteByAction(", "private func nudgeByAction(", "private func stretchByAction("] {
            let body = try functionBody(head, in: code)
            XCTAssertTrue(body.contains("guard editable,"), "`\(head)` checks `editable` first")
        }
        XCTAssertTrue(try functionBody("private func stretchByAction(", in: code).contains("ids.count == 1"),
                      "a stretch needs exactly one picked note — the drag edge belongs to one note")
    }

    // MARK: - Claim 4 — the names and the spoken suffixes are catalogued

    func testTheActionNamesAreCatalogued() throws {
        let code = try source(Self.editor)
        XCTAssertEqual(occurrences(of: "AccessibilityNotification.Announcement(named + suffix).post()", in: code), 1,
                       "the edit announcement is spoken from one place")
        let url = try repoRoot().appendingPathComponent(Self.catalog)
        let root = try JSONSerialization.jsonObject(with: try Data(contentsOf: url)) as? [String: Any]
        let strings = root?["strings"] as? [String: Any] ?? [:]
        XCTAssertGreaterThan(strings.count, 400, "ANCHOR MISSING: the string catalog read as nearly empty (#454)")
        for key in Self.actions + [", added", ", moved", ", resized"] {
            XCTAssertNotNil(strings[key], "`\(key)` has no catalog entry")
        }
    }

    // MARK: - Claim 5 — COUNTERWEIGHT: the gestures the actions mirror still use the same ops

    func testTheGesturesStillUseTheSameOps() throws {
        let tap = try functionBody("private func tap(", in: try source(Self.editor))
        XCTAssertTrue(tap.contains("ClipNoteEdit.adding("), "a tap on an empty cell still adds through the pure op")
        XCTAssertTrue(tap.contains("timeline.setClipNotes("), "and commits through the one writer")
    }

    // MARK: - Helpers

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func functionBody(_ head: String, in code: String) throws -> String {
        guard let start = code.range(of: head) else {
            throw AnchorMissing(reason: "`\(head)` is gone")
        }
        guard let open = code[start.upperBound...].firstIndex(of: "{") else {
            throw AnchorMissing(reason: "no body after `\(head)`")
        }
        var depth = 1
        var index = code.index(after: open)
        while index < code.endIndex {
            let c = code[index]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(code[start.lowerBound...index]) } }
            index = code.index(after: index)
        }
        throw AnchorMissing(reason: "unbalanced braces after `\(head)`")
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
