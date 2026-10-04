// TheValueFieldTicksAtItsDetentsTests.swift
// Echoel — Restructure F5a (2026-10-04, `scratchpads/PLAN_RESTRUCTURE_2026-10-04.md` §3/§5).
//
// WHAT WAS MISSING. `EchoelValueField` — every numeric parameter in the app — gave no haptic at
// all. A drag past the row's default felt exactly like a drag past any other number, and the
// keypad's OK confirmed nothing to the hand. The only haptic in the studio was the arrange
// drag's bar tick (UX slice 13b, `.sensoryFeedback(.selection, trigger: landing)`).
//
// THE REPAIR — the same SwiftUI modifier, on the field itself:
//   · a DRAG ticks once when it arrives on, or passes over, the row's default, and when it
//     reaches either range end (`ScrubPrecision.reachesDetent`, pure, driven below);
//   · the keypad's OK confirms with `.success` — triggered from the FIELD, because the pad
//     dismisses in the same turn it commits, and only when the number moved (#375).
// Neither sits on a render path; both are UI modifiers on one leaf view.
//
// HONEST GRADING (Tests/CISmoke/CLAUDE.md §1/§3), transcribed in Python against the parent
// `39d77bf3b` and the worktree:
//   · claim 1 — END-TO-END BEHAVIOUR on the shipped pure function. It names a symbol this
//     commit creates, so the file does NOT compile against the parent: no assertion has a
//     verdict there. FORWARD guard; the table was hand-driven through a Python transcription.
//   · claim 2 — SOURCE-TEXT SCAN, RED on the parent by absence: neither haptic exists there.
//     One absence, reported per needle (#486).
//   · claim 3 — COUNTERWEIGHT, green on both: the pad still dismisses in the turn it commits,
//     which is the reason the OK feedback lives on the field. If the pad stops dismissing,
//     the feedback could move into it — the message says so.
// It does NOT prove the ticks feel right or fire on a device; that is a device probe.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheValueFieldTicksAtItsDetentsTests: XCTestCase {

    private static let field = "Sources/Echoelmusic/Studio/EchoelValueField.swift"
    private static let pad = "Sources/Echoelmusic/Studio/EchoelNumberPad.swift"

    private func reaches(_ old: Double, _ new: Double, standard: Double? = 0.5,
                         lo: Double = 0, hi: Double = 1) -> Bool {
        ScrubPrecision.reachesDetent(from: old, to: new, standard: standard,
                                     lowerBound: lo, upperBound: hi)
    }

    /// 1 — the detent rule, driven end to end.
    func testADragTicksOnArrivingAtTheDefaultOrAnEdge() {
        // Arriving at the default, from either side.
        XCTAssertTrue(reaches(0.49, 0.50), "landing on the default from below is a tick")
        XCTAssertTrue(reaches(0.51, 0.50), "landing on the default from above is a tick")
        // A fast drag jumps over the default between two events — still one tick.
        XCTAssertTrue(reaches(0.40, 0.60), "passing over the default is a tick")
        XCTAssertTrue(reaches(0.60, 0.40), "passing over the default downwards is a tick")
        // Leaving the default is silent; so is any move that touches no detent.
        XCTAssertFalse(reaches(0.50, 0.51), "pulling away from the default is not a tick")
        XCTAssertFalse(reaches(0.20, 0.30), "an ordinary move is not a tick")
        XCTAssertFalse(reaches(0.30, 0.30), "no move is not a tick")
        // The range ends are detents with or without a default.
        XCTAssertTrue(reaches(0.02, 0.00), "reaching the lower end is a tick")
        XCTAssertTrue(reaches(0.98, 1.00), "reaching the upper end is a tick")
        XCTAssertTrue(reaches(0.98, 1.00, standard: nil), "an edge ticks on a row with no default")
        XCTAssertFalse(reaches(0.40, 0.60, standard: nil), "a row with no default has no middle detent")
        // Non-finite input never ticks.
        XCTAssertFalse(reaches(.nan, 0.50), "a NaN old value is not a tick")
        XCTAssertFalse(reaches(0.40, .infinity), "a non-finite new value is not a tick")
        XCTAssertFalse(reaches(0.40, 0.60, standard: .nan), "a NaN default is no detent")
    }

    /// 2 — the field carries both haptics, and the drag tick is gated on a drag.
    func testTheFieldWearsBothHaptics() throws {
        let code = try read(Self.field)
        for needle in [
            ".sensoryFeedback(.selection, trigger: Double(value)) { old, new in",
            "scrubbing && ScrubPrecision.reachesDetent(from: old, to: new,",
            ".sensoryFeedback(.success, trigger: keypadCommits)",
            "if apply(newVal) { onChange(); onCommit(); keypadCommits &+= 1 }",
        ] {
            XCTAssertTrue(code.contains(needle), """
                `EchoelValueField` no longer carries `\(needle)`. The drag ticks at the row's \
                default and range ends, and only during a drag; the keypad's OK confirms only \
                an edit that moved the number (plan §3, F5a).
                """)
        }
    }

    /// 3 — COUNTERWEIGHT: the pad dismisses in the turn it commits, which is why the OK
    /// confirmation is triggered from the field and not from the pad.
    func testThePadDismissesInTheTurnItCommits() throws {
        let code = try read(Self.pad)
        guard let start = code.range(of: "private func commit() {"),
              let end = code[start.upperBound...].range(of: "}") else {
            XCTFail("ANCHOR MISSING: `private func commit() {` in EchoelNumberPad (#454)")
            return
        }
        let body = code[start.upperBound..<end.lowerBound]
        XCTAssertTrue(body.contains("onCommit(snapped(pendingValue))") && body.contains("dismiss()"), """
            `EchoelNumberPad.commit()` changed shape. The OK feedback lives on the field because \
            the pad dismissed in the same turn; if that is no longer true, the feedback may move \
            into the pad — move this claim with it.
            """)
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
}
