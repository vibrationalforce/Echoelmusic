// ABoxAddsToTheSelectionTests.swift
// Echoel — Phase 3 / Creation Workflow, MIDI editor slice M9: a box adds to the selection.
//
// WHAT IT PINS. A tap adds a note to the selection (or takes it out) since M1. A box — press,
// hold and slide on an empty cell — REPLACED the selection with what it touched, so a selection
// could not be built from two boxes, and every note picked two octaves away or in the bar before
// was dropped without a word. Since M9 the boxed notes JOIN the selection (`NoteGridGesture
// .boxing`), and the canvas lights that same set while the finger slides: the preview is the
// commit. Deselect (M6) is the way to start over.
//
// 1. END-TO-END BEHAVIOUR (`NoteGridGesture`, pure): a real box resolved on the grid touches one
//    note, and the selection that box leaves holds it AND the note picked before; a box over a
//    note already picked keeps it (a box never takes a note out — that is the tap's toggle); an
//    empty box leaves the selection as it was.
// 2. SOURCE: the release and the live preview ask the same `boxing`.
//
// Grading (§0, no Swift toolchain in a web session): `resolve` and `RollHitTest.marquee` were
// transcribed into Python on this geometry (the `ANoteDragIsOneCommitAtReleaseTests` grid). On the
// parent (`3723e000d`) this file does NOT compile — `NoteGridGesture.boxing` is new — so no
// assertion has a verdict there: claim 1 is a FORWARD guard (one absence, #486); its
// counterweights are the resolved box touching exactly one note (the premise) and the empty box.
// Claim 2 is a scan of the same new call.
// NOT covered: the finger feel on a device.
// NEEDS-FOUNDER-VERIFY: Workstation → Notes on a part → tap one note → box two others in the same
// octave view → all three are lit, and Delete removes all three; Deselect clears them.

import Foundation
import XCTest
@testable import Echoelmusic

final class ABoxAddsToTheSelectionTests: XCTestCase {

    private static let editorPath = "Sources/Echoelmusic/Studio/PartNoteEditor.swift"
    private static let grid = NoteGridGesture.Grid(stepWidth: 22, rowHeight: 14, rows: 48...72,
                                                   partSteps: 16)

    // MARK: 1 — END-TO-END

    func testABoxJoinsTheSelectionItDoesNotReplaceIt() {
        let a = Note(pitch: 60, startStep: 2, lengthSteps: 2)     // x 44…88,  y 168…182
        let c = Note(pitch: 62, startStep: 10)                    // x 220…242, y 140…154
        // A box from an empty cell (step 9, pitch 63) over `c` only.
        guard case .marquee(let boxed, _, _, _, _) =
                NoteGridGesture.resolve(startX: 210, startY: 135, dx: 40, dy: 25,
                                        visible: [a, c], picked: [a.id], grid: Self.grid) else {
            return XCTFail("ANCHOR MISSING: a hold on an empty cell must draw a box")
        }
        XCTAssertEqual(boxed, [c.id], "premise: the box touches exactly the one note it was drawn over")
        XCTAssertEqual(NoteGridGesture.boxing(boxed, into: [a.id]), [a.id, c.id], """
            the box added `c` and kept `a`, picked before — a box that replaced the selection \
            dropped every note picked elsewhere, and two boxes could never make one selection
            """)
        XCTAssertEqual(NoteGridGesture.boxing([c.id], into: [c.id]), [c.id],
                       "a box over a picked note keeps it — taking a note out is the tap's toggle")
        XCTAssertEqual(NoteGridGesture.boxing([], into: [a.id]), [a.id],
                       "an empty box leaves the selection as it was")
    }

    // MARK: 2 — SOURCE

    func testTheReleaseAndThePreviewAskTheSameRule() throws {
        let editor = try source(Self.editorPath)
        guard let box = editor.range(of: "case .marquee(let ids, _, _, _, _):"),
              let move = editor.range(of: "case .move(let ids, let dPitch, let dStep):",
                                       range: box.upperBound..<editor.endIndex) else {
            return XCTFail("ANCHOR MISSING: the release's box case (#454)")
        }
        XCTAssertTrue(editor[box.upperBound..<move.lowerBound]
                        .contains("picked = RollSelection(ids: Array(NoteGridGesture.boxing(ids, into: picked.ids)))"),
                      "the release keeps the selection and adds the box")
        XCTAssertTrue(editor.contains("case .marquee(let ids, _, _, _, _)?: return NoteGridGesture.boxing(ids, into: picked)"),
                      "the canvas lights the same set while the finger slides — the preview is the commit")
    }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}
