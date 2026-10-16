// TheArrangePlateSwitchesToSessionTests.swift
// P1 (founder 2026-10-16, „Und integrierten Performance Modus"): the Arrange plate has two views
// of ONE song, as in Live — Arrangement (the timeline) and Session (scenes launched on the bar),
// switched by a segmented control at its top. Before, the scene launcher stood under the canvas
// and the track column, a screen below the parts, and the founder did not find it.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claim 1 is END-TO-END on the pure `ArrangeMode` (every row of the truth table).
//   · Claims 2–3 are SOURCE-TEXT SCANS of `WorkstationView`: one switch, the timeline gated on
//     it, the ONE launcher mount gated on it.
//   · NOT CLAIMED (DEVICE PROBE): that the switch reads well at 375 pt and that launching from
//     the Session view sounds on the bar. NEEDS-FOUNDER-VERIFY (P1): Piece → Arrange → "Session",
//     play the piece, launch a scene — does it switch on the next bar?
//
// HONEST GRADING against the parent (§3): the file does not compile there (`ArrangeMode` is new),
// so no assertion has a verdict on the parent. Hand-transcribed: claim 1 is the CAPABILITY, its
// focus rows are the COUNTERWEIGHT (an open editor is never stranded by the switch), claims 2–3
// are FORWARD guards. Mutants: Session still shows the timeline (1) · focus hides the editor (1) ·
// a second launcher mount (3) · launcher ungated (3) · switch inside the mixer branch (2).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheArrangePlateSwitchesToSessionTests: XCTestCase {

    // MARK: 1 — the truth table

    func testEachViewShowsItsOwnHalfAndFocusKeepsTheEditor() {
        XCTAssertTrue(ArrangeMode.arrangement.showsTimeline(focused: false))
        XCTAssertFalse(ArrangeMode.arrangement.showsScenes(focused: false),
                       "Arrangement and Session are two views — the scenes are not under the timeline")
        XCTAssertFalse(ArrangeMode.session.showsTimeline(focused: false))
        XCTAssertTrue(ArrangeMode.session.showsScenes(focused: false))
        XCTAssertTrue(ArrangeMode.session.showsTimeline(focused: true), """
            An open editor keeps the timeline in either view — switching to Session must never \
            strand the part being edited.
            """)
        XCTAssertFalse(ArrangeMode.session.showsScenes(focused: true), "focus gives the editor the plate")
        XCTAssertTrue(ArrangeMode.arrangement.showsTimeline(focused: true))
        XCTAssertEqual(ArrangeMode.allCases.map(\.rawValue), ["arrangement", "session"],
                       "raw values are persisted — rename a label, never a case")
        XCTAssertNotEqual(ArrangeMode.arrangement.label, ArrangeMode.session.label)
        XCTAssertTrue(ArrangeMode.sessionNote.contains("Arrangement"),
                      "the Session note says where scenes are made")
    }

    // MARK: 2 — one switch, at the top of the arrangement branch, gating the timeline

    func testTheSwitchStandsOverTheTimelineItGates() throws {
        let view = try source("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertEqual(view.components(separatedBy: "arrangeModePicker").count - 1, 2,
                       "declared once, placed once")
        XCTAssertTrue(view.contains(".pickerStyle(.segmented)"), "a named choice is a segmented picker")
        guard let mixer = view.range(of: "PieceMixerView(voiceCapacity:"),
              let place = view.range(of: "if !focused { arrangeModePicker }"),
              let gate = view.range(of: "if arrangeMode.showsTimeline(focused: focused) {"),
              let canvas = view.range(of: "ArrangeCanvasView(rows: arrangeRows") else {
            return XCTFail("ANCHOR MISSING: the mixer branch, the switch, its gate or the canvas (#408)")
        }
        XCTAssertLessThan(mixer.lowerBound, place.lowerBound, "the switch is in the arrangement branch, not the mixer's")
        XCTAssertLessThan(place.lowerBound, gate.lowerBound)
        XCTAssertLessThan(gate.lowerBound, canvas.lowerBound, "the canvas is inside the timeline gate")
    }

    // MARK: 3 — the ONE launcher mount is the Session view's

    func testTheOneLauncherMountIsGatedOnTheSessionView() throws {
        let view = try source("Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertEqual(view.components(separatedBy: "SessionLaunchView(playFrom:").count - 1, 1)
        guard let plate = view.range(of: "if pieceView == .arrange && !focused {"),
              let gate = view.range(of: "if arrangeMode.showsScenes(focused: focused) {",
                                    range: plate.upperBound..<view.endIndex),
              let mount = view.range(of: "SessionLaunchView(playFrom:",
                                     range: gate.upperBound..<view.endIndex) else {
            return XCTFail("ANCHOR MISSING: the plate gate, the Session gate or the mount (#408)")
        }
        XCTAssertLessThan(gate.lowerBound, mount.lowerBound)
        XCTAssertFalse(view[plate.upperBound..<gate.lowerBound].contains("}"),
                       "the Session gate is the first thing inside the plate gate")
    }

    // MARK: helpers

    private struct Unreadable: Error {}

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw Unreadable()
        }
        return SourceText.codeOnly(text)
    }
}
