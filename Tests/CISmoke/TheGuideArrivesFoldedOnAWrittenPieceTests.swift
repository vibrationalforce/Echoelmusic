// TheGuideArrivesFoldedOnAWrittenPieceTests.swift
// Echoel — the "Create a piece" steps arrive OPEN on a beginner's plate and FOLDED on a piece
// that already has notes, and they never fold themselves while the player works (Workstation
// redesign A6, founder 2026-10-01).
//
// WHY: the founder, beside the tablet mockup — *„Gestalte alles so um, dass ich Echoelmusic als
// Workstation ernsthaft vertreten kann."* Five onboarding rows at the top of a written song read
// as a tutorial, not a workstation. But the review of c672c2adf already paid for the naive fix:
// the card used to fold ITSELF once a part held notes — exactly when Play and Save become the
// next steps — so the fold is decided ONCE, from the facts the card arrives with.
//
// THE THREE CLAIMS:
// 1. One pure rule decides the arrival: open without notes, folded with notes (RUNTIME, on
//    `ComposeGuide.opensExpanded`, driven through `ComposeGuide.facts` so the rule reads the
//    model's own "has notes" and not a re-typed one).
// 2. The card seeds its fold from that rule through `State(initialValue:)` in its `init` — the
//    one SwiftUI spelling that is read once per identity — and has no `= true` literal left.
// 3. Counterweights: nothing re-derives the fold (no `.onChange(`/`.onAppear`/`.task` — the
//    card's existing guard bans them too), the header tap still toggles it, and the header line
//    still names the next step, so a folded card is never a silent one.
//
// GRADING (§0/§3, no Swift toolchain in a web session — transcribed in Python against both
// trees): claim 1 is a FORWARD guard on a function this commit creates — it cannot compile on the
// parent, so no assertion in this file has a verdict there; re-derived by hand: an empty document
// → `hasNotes` false → open; a written part → folded. Claims 2–3 are SOURCE scans: work tree
// green; on the parent claim 2 would be red by ABSENCE (`opensExpanded`), one absence (#486), and
// claim 3 green (counterweights). DEVICE PROBE, open: a returning player finds the steps behind
// the header and does not miss them.

import XCTest
@testable import Echoelmusic

final class TheGuideArrivesFoldedOnAWrittenPieceTests: XCTestCase {

    private static let view = "Sources/Echoelmusic/Studio/WorkstationView.swift"

    // MARK: 1 — one rule decides the arrival

    func testTheGuideArrivesOpenOnlyWithoutNotes() {
        let empty = ComposeGuide.Facts(hasMIDITrack: false, hasPart: false, hasNotes: false,
                                       canPlay: false, isPlaying: false, canSave: false)
        XCTAssertTrue(ComposeGuide.opensExpanded(empty), "an empty song is the beginner's plate — the steps arrive open")

        let partNoNotes = ComposeGuide.Facts(hasMIDITrack: true, hasPart: true, hasNotes: false,
                                             canPlay: false, isPlaying: false, canSave: true)
        XCTAssertTrue(ComposeGuide.opensExpanded(partNoNotes), "an empty part still needs step 3 shown")

        let written = ComposeGuide.Facts(hasMIDITrack: true, hasPart: true, hasNotes: true,
                                         canPlay: true, isPlaying: false, canSave: true)
        XCTAssertFalse(ComposeGuide.opensExpanded(written), "a written piece arrives folded")

        // Through the model's own reading of a document, not a hand-built flag (#416).
        let fresh = ComposeGuide.facts(document: TimelineDocument(), clips: [], canPlay: false, isPlaying: false)
        XCTAssertTrue(ComposeGuide.opensExpanded(fresh), "a fresh document opens the steps")
    }

    // MARK: 2 — the card seeds its fold once, from that rule

    func testTheCardSeedsItsFoldOnceFromTheRule() throws {
        let card = try member("private struct ComposeGuideCard: View {", in: SourceText.codeOnly(try text(Self.view)))
        XCTAssertTrue(card.contains("@State private var expanded: Bool"),
                      "the fold is view state with no literal default")
        XCTAssertTrue(card.contains("_expanded = State(initialValue: ComposeGuide.opensExpanded(facts))"),
                      "the init seeds it from the one rule — read once per identity")
        XCTAssertFalse(card.contains("@State private var expanded = true"),
                       "the old always-open literal is back — a written piece would arrive with five tutorial rows")
    }

    // MARK: 3 — counterweights: nothing re-derives it, the tap and the header line remain

    func testNothingFoldsTheCardWhileThePlayerWorks() throws {
        let card = try member("private struct ComposeGuideCard: View {", in: SourceText.codeOnly(try text(Self.view)))
        for banned in [".onChange(", ".onAppear", ".task", "expanded = ComposeGuide", "expanded = false"] {
            XCTAssertFalse(card.contains(banned), """
                the card carries `\(banned)` — the fold must not follow the facts after arrival \
                (review of c672c2adf: it hid Play and Save exactly when they became the next steps)
                """)
        }
        XCTAssertTrue(card.contains("expanded.toggle()"), "the player's own tap still folds and opens it")
        XCTAssertTrue(card.contains("Text(ComposeGuide.headerDetail(facts))"),
                      "a folded card still names the next step in its header line")
    }

    // MARK: helpers

    /// The brace-matched body after `anchor` (#408); string-literal aware, so `"{"` in a literal
    /// cannot unbalance it.
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            XCTFail("ANCHOR MISSING: `\(anchor)` (#454)")
            return ""
        }
        var depth = 1
        var index = start.upperBound
        var inString = false
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
                    if depth == 0 { return String(code[start.upperBound..<index]) }
                }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: `\(anchor)` never closes (#454)")
        return ""
    }

    private func text(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
