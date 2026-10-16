// TheTypedRequestTakesTheSiriRoadTests.swift
// GSIDMMW C2c (2026-10-16): "Ask Echoel" inside the app. Until now a request in the person's own
// words could only arrive by Siri or Shortcuts (`AskEchoelIntent`, C2b) — a door a musician at the
// instrument does not see. The ≡ menu's "Ask Echoel" opens one typed line in the agent banner; the
// line hands the words to the SAME `AgentReportBanner.ask` the intent calls, so the model still
// only PROPOSES and nothing changes until Apply.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claim 1 is END-TO-END over a fresh `EchoelAgentDesk`: the line opens and closes and changes
//     nothing else on the desk.
//   · Claims 2–4 are SOURCE-TEXT SCANS — the row is a `private` View no bundle can instantiate:
//     the menu door is a Button, the row's one ask sits behind `canAsk` in `send()`, and the banner
//     file carries no presentation modifier (the root's sheet chain, black-screen law).
//   · DEVICE PROBE, open: the keyboard rises with the line, Send on the keyboard asks, VoiceOver
//     reads label and hint, and the proposal lands under it.
//
// HONEST GRADING against the parent (D2's commit, §3): claim 1 does not COMPILE there (it names
// `beginTypedRequest`, which this commit creates) — ONE absence (#486), a FORWARD guard; claims 2–4
// are red there by ANCHOR ABSENCE (no menu row, no `AgentRequestRow`), also forward. Claim 4's
// no-modal half is a COUNTERWEIGHT, green on both trees. Mutants, each turning its claim red: the
// door wired to `ask` directly (2) · `send()` without the `canAsk` guard, so an empty line or a
// second request while the model is busy reaches it (3) · the line as an `.alert` with a text field
// (4).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheTypedRequestTakesTheSiriRoadTests: XCTestCase {

    // MARK: 1 — the line opens and closes; nothing else on the desk moves

    func testTheTypedLineOpensAndClosesAndChangesNothingElse() {
        let desk = EchoelAgentDesk()
        XCTAssertFalse(desk.isTypingRequest, "the line is closed until the person opens it")
        desk.beginTypedRequest()
        XCTAssertTrue(desk.isTypingRequest)
        XCTAssertNil(desk.notice, "opening the line is not a request")
        XCTAssertNil(desk.pendingProposal)
        XCTAssertFalse(desk.isWorking)
        desk.endTypedRequest()
        XCTAssertFalse(desk.isTypingRequest)
        XCTAssertNil(desk.notice)
    }

    // MARK: 2 — the ≡ menu's door is a Button that only opens the line

    func testTheMenuDoorOnlyOpensTheLine() throws {
        let root = try code("Sources/Echoelmusic/Studio/WorkspaceView.swift")
        XCTAssertTrue(root.contains("Button { AgentReportBanner.beginTypedRequest() } label: {"),
                      "the menu row opens the line and does nothing else — through the banner, so the root never names the desk")
        let banner = try code("Sources/Echoelmusic/Studio/AgentReportBanner.swift")
        XCTAssertTrue(banner.contains("static func beginTypedRequest() { EchoelAgentDesk.shared.beginTypedRequest() }"),
                      "the banner hands the open straight to the desk")
        XCTAssertTrue(root.contains("Label(\"Ask Echoel\", systemImage: \"text.cursor\")"),
                      "the row has a spoken title, not only a glyph (#480)")
        XCTAssertFalse(root.contains("AgentReportBanner.ask("), "the root never asks the model itself")
        XCTAssertEqual(root.components(separatedBy: "beginTypedRequest()").count - 1, 1)
    }

    // MARK: 3 — the row asks once, behind its guard, with the words cut to what the planner reads

    func testTheRowAsksOnceBehindItsGuard() throws {
        let banner = try code("Sources/Echoelmusic/Studio/AgentReportBanner.swift")
        guard let row = banner.range(of: "private struct AgentRequestRow: View {") else {
            return XCTFail("`AgentRequestRow` moved — re-anchor")
        }
        let body = String(banner[row.lowerBound...])
        guard let send = body.range(of: "private func send() {") else {
            return XCTFail("`AgentRequestRow.send()` moved — re-anchor")
        }
        let sendBody = String(body[send.upperBound...])
        guard let guardLine = sendBody.range(of: "guard canAsk else { return }"),
              let ask = sendBody.range(of: "Task { await AgentReportBanner.ask(asked) }") else {
            return XCTFail("send() lost its guard or its ask")
        }
        XCTAssertLessThan(guardLine.lowerBound, ask.lowerBound, "nothing is asked before the guard")
        XCTAssertTrue(body.contains("private var canAsk: Bool { !request.isEmpty && !desk.isModelBusy && !desk.isWorking }"),
                      "an empty line, a busy model or a running request cannot ask")
        XCTAssertTrue(body.contains(".prefix(EchoelModelPlanner.requestLimit)"),
                      "the draft is cut where the planner cuts it (#416), not at a second number")
        XCTAssertTrue(banner.contains("if desk.isTypingRequest {\n            AgentRequestRow()\n        }"),
                      "the banner shows the line while it is open")
    }

    // MARK: 4 — no modal: an inline row in the root's column

    func testTheLineIsNoModal() throws {
        let banner = try code("Sources/Echoelmusic/Studio/AgentReportBanner.swift")
        for modal in [".sheet(", ".fullScreenCover(", ".alert(", ".popover(", ".confirmationDialog("] {
            XCTAssertFalse(banner.contains(modal), "the agent banner presents `\(modal)` — the sheet-chain law")
        }
    }

    private func code(_ path: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
    }
}
