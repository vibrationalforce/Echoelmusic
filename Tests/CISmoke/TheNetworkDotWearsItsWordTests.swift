// TheNetworkDotWearsItsWordTests.swift
// Echoel — interface audit 2026-09-30, Zug 3 ("Status-Leiter in Worten für jeden Hardware-Pfad"),
// second path: the NETWORK outputs (OSC · ADM-OSC · Art-Net · sACN) in the Routing surface.
//
// WHAT IT GUARDS. `NetworkOutputHeader` used to carry the state as a 7 pt SHAPE (filled dot ·
// ring · faint ring) and speak the word — `NetworkSendState.label` — to VoiceOver only. A sighted
// operator had to know the shape grammar; a colour-blind one saw a tile. Now the header renders
// `Text(state.label)` beside the shape, dim and at the 11 pt floor, and the accessibility value is
// the SAME `state.label` — one definition of the word (#416), so eye and ear cannot drift apart.
// The shapes stay: shape-not-colour was the row's original law and the word joins it.
//
// §1 LIMIT: every claim is a SOURCE-TEXT SCAN over `NetworkActivityDot.swift`. The words
// themselves — three distinct, none claiming a confirmed link — are END-TO-END pinned by the
// sibling `TheSendingDotMeansSendingTests` (claims 3–4) and not repeated here (#416). Whether the
// word reads well at 11 pt beside a 7 pt ring on a 375 pt phone is a DEVICE PROBE.
//
// §3 HONEST GRADING, transcribed in Python against the parent (2b3e8e8a2) and this tree: claim 1
// is the DECISION — RED on the parent (no `Text(state.label)` in the header body); claim 2 is red
// on the parent for the same absence (one absence, reported once, #486); claims 3–4 are
// COUNTERWEIGHTS, green on both trees. ZERO regressions claimed. Stripper `SourceText.codeOnly`:
// PROPHYLAKTISCH (0 of 4 verdicts flip — the anchors are code tokens no comment in the file quotes;
// the new doc block above the struct names `state.label` in backticks, not the `Text(` form).

import Foundation
import XCTest

final class TheNetworkDotWearsItsWordTests: XCTestCase {

    private static let leaf = "Sources/Echoelmusic/Studio/NetworkActivityDot.swift"
    private static let head = "struct NetworkOutputHeader: View {"

    // MARK: - Claim 1 — the header RENDERS the word, from the same rung the shape comes from

    func testTheHeaderRendersTheStateWord() throws {
        let body = try headerBody()
        XCTAssertTrue(body.contains("Text(state.label)"),
                      "The network state is a shape AND a word; the word went to VoiceOver only.")
    }

    // MARK: - Claim 2 — eye and ear read ONE string, and the word sits at the 11 pt floor, dim

    func testTheWordAndTheSpokenValueAreTheSameLabel() throws {
        let body = try headerBody()
        XCTAssertTrue(body.contains(".accessibilityValue(state.label)"),
                      "VoiceOver reads the same `label` the eye sees — one definition (#416).")
        guard let word = body.range(of: "Text(state.label)") else {
            return XCTFail("ANCHOR MISSING: `Text(state.label)` — claim 1 says so")
        }
        let after = String(body[word.upperBound...].prefix(160))
        XCTAssertTrue(after.contains(".font(EchoelTheme.font(11))"),
                      "the word is at the 11 pt floor (rule 12), not below it and not shouting")
        XCTAssertTrue(after.contains(".foregroundStyle(EchoelTheme.dim)"),
                      "a status word is dim — the NAME is the row's text, the word is its state")
        XCTAssertEqual(occurrences(of: "state.label", in: body), 2,
                       "exactly two reads of `state.label` in the header: the eye's and the ear's")
    }

    // MARK: - Claim 3 — COUNTERWEIGHT: the three SHAPES stay (shape, not colour)

    func testTheThreeShapesStay() throws {
        let body = try headerBody()
        XCTAssertTrue(body.contains("case .sending:  Circle().fill(EchoelTheme.accent)"), "filled dot")
        XCTAssertTrue(body.contains("case .openIdle: Circle().strokeBorder(EchoelTheme.accent, lineWidth: 2.5)"), "ring")
        XCTAssertTrue(body.contains("case .off:      Circle().strokeBorder(EchoelTheme.border, lineWidth: 1.5)"), "faint ring")
        XCTAssertTrue(body.contains(".accessibilityHidden(true)"),
                      "the shape stays hidden from VoiceOver — the value carries the state")
    }

    // MARK: - Claim 4 — COUNTERWEIGHT: still a LEAF on its own low-rate clock (10.76.50)

    func testTheHeaderStaysALeafOnItsOwnClock() throws {
        let body = try headerBody()
        XCTAssertTrue(body.contains("TimelineView(.periodic(from: .now, by: Self.tick))"),
                      "the 2 Hz re-evaluation stays inside the leaf")
        XCTAssertTrue(body.contains("lastSent: sender.lastSentTimestamp"),
                      "the hot stamp is read HERE, never in the Routing body (sibling claim 5)")
    }

    // MARK: - Helpers

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    /// The `NetworkOutputHeader` struct, brace-matched from its declaration (#408).
    private func headerBody() throws -> String {
        let code = try source(Self.leaf)
        guard let start = code.range(of: Self.head) else {
            throw AnchorMissing(reason: "`\(Self.head)` is gone from \(Self.leaf)")
        }
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex {
            let c = code[index]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(code[start.lowerBound...index]) } }
            index = code.index(after: index)
        }
        throw AnchorMissing(reason: "unbalanced braces after `\(Self.head)`")
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
