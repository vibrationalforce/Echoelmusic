// TheTransportIsFeltWhenItStartsAndStopsTests.swift
// Echoel — Restructure F5b (2026-10-04, `scratchpads/PLAN_RESTRUCTURE_2026-10-04.md` §3/§5).
//
// WHAT WAS MISSING. The ONE Play / Stop (`ProjectPlayStopButton`) started and stopped everything
// and gave the hand nothing. On a stage, eyes on the room, the only way to know the transport
// moved was to look back at the screen or wait for sound.
//
// THE REPAIR — `.sensoryFeedback(trigger: running)`: `.start` when the transport begins to run,
// `.stop` when it ends, whatever ended it (the tap, the space bar, the end of the song). It is
// keyed on the derived `running`, which changes on a gesture or at a song's end, never per tick.
//
// WHY IT CANNOT BUZZ TWICE. The button has two mounts — the head on the Instrument stage, the
// Workstation's bar on the Piece stage — and they are mutually exclusive by construction:
// `headCarriesTransport` is `self != .piece`, and `StageShell` builds `ArrangeStage` only
// `if stage == .piece`. Claim 2 pins both halves; a stage that showed both would feel every
// start twice.
//
// HONEST GRADING (Tests/CISmoke/CLAUDE.md §1/§3). SOURCE-TEXT SCAN over comment-stripped
// `Sources/`, transcribed in Python against the parent `a585fa507` and the worktree:
//   · claim 1 — RED on the parent by absence: the haptic does not exist there. A REGRESSION
//     guard from here on.
//   · claim 2 — COUNTERWEIGHT, green on both: two mounts, mutually exclusive.
// It does NOT prove the haptic is felt; that is a device probe.

import Foundation
import XCTest

final class TheTransportIsFeltWhenItStartsAndStopsTests: XCTestCase {

    private static let header = "Sources/Echoelmusic/Studio/ProjectHeader.swift"

    /// 1 — the ONE Play / Stop starts and stops with a haptic, inside the button's own builder.
    func testThePlayStopButtonIsFelt() throws {
        let code = try read(Self.header)
        guard let start = code.range(of: "private func playStopButton(running: Bool"),
              let end = code[start.upperBound...].range(of: "private func startSong()") else {
            XCTFail("ANCHOR MISSING: `playStopButton(running:` … `startSong()` in ProjectHeader (#454)")
            return
        }
        let builder = code[start.upperBound..<end.lowerBound]
        XCTAssertTrue(builder.contains(".sensoryFeedback(trigger: running) { _, isRunning in isRunning ? SensoryFeedback.start : SensoryFeedback.stop }"), """
            The ONE Play / Stop no longer gives `.start` / `.stop` as the transport begins and \
            ends (plan §3, F5b). Keep it keyed on `running`, never on a ticking value.
            """)
    }

    /// 2 — COUNTERWEIGHT: two mounts, never on screen together, so a change is felt once.
    func testTheTwoMountsNeverStandTogether() throws {
        var mounts = 0
        for path in ["Sources/Echoelmusic/Studio/ProjectHeader.swift",
                     "Sources/Echoelmusic/Studio/WorkstationView.swift"] {
            mounts += try read(path).components(separatedBy: "ProjectPlayStopButton(source:").count - 1
        }
        XCTAssertEqual(mounts, 2, "the Play / Stop has \(mounts) mounts — a third may stand beside one of these and buzz twice")
        XCTAssertTrue(try read("Sources/Echoelmusic/Studio/StudioStage.swift")
                        .contains("public var headCarriesTransport: Bool { self != .piece }"),
                      "the head's mount no longer stands only off the Piece stage")
        XCTAssertTrue(try read("Sources/Echoelmusic/Studio/StageShell.swift").contains("if stage == .piece {"),
                      "the Workstation (and its mount) no longer stands only on the Piece stage")
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
