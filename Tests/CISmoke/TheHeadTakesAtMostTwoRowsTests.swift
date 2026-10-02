// TheHeadTakesAtMostTwoRowsTests.swift
// Echoel — the project head takes AT MOST TWO ROWS on a phone, with fixed places: the summary
// with the transport (Instrument stage), then the pulse pill with Undo · Redo (founder
// 2026-10-01: „Vermeide das es mehrfache Wege zu einem Bereich gibt … Viele Bereiche sind zu groß
// und füllen den Bildschirm aus. Vermeide slop.").
//
// WHY: on a 375 pt phone the Instrument stage ALWAYS took the head's third candidate — the
// summary's ideal width beside Play · Record · ⓘ never fit, so `ViewThatFits` fell to the last
// shape, the pill and the worded Undo/Redo each on a row of their own: ≈152 pt of head over a
// ≈25 pt instrument panel. The repair is not a smaller font; it is a LAST candidate that is two
// rows, so a phone can never get a third, and two things that make two rows fit: the history as
// glyphs (the compact Record's idiom), and ⓘ beside the history instead of beside the transport.
//
// ⭐ DAW SHELL S1b-1 (2026-10-02, inbox E18): the ⓘ LEFT THE HEAD — the guide switch is the Guide
// toggle in the mark's ≡ menu (`WorkspaceView.topBar`, pinned by `TheGuideHasADoorTests`). Claims
// 2–4 were rewritten in that commit to the new pieces, at least as strictly: every row is still
// pinned EXACTLY, `tools` (history + ⓘ) is gone with nothing re-wrapping the history, and the head
// now asserts it carries NO guide switch at all — a second one would be a second address.
//
// THE SIX CLAIMS:
// 1. `ViewThatFits` in `ProjectHeader.body` has exactly TWO candidates, and the last is a
//    `VStack` of exactly TWO rows (STRUCTURE — depth-0 lines of the brace-matched block).
// 2. Row 1 is the summary with the transport, row 2 the pill with the history; the head holds no
//    `tools` wrapper and no guide switch (S1b-1); the transport group carries no history (so
//    Undo · Redo stay on both stages).
// 3. The one-line candidate carries the same four pieces — one place per control in every shape.
// 4. The accessibility stack keeps every control, the transport on the last line.
// 5. The summary yields at the PLACE, never at a number: the status word has priority and the
//    tempo readout cannot wrap (`.fixedSize()`).
// 6. `SongHistoryRow` shows its word only at accessibility sizes, on the head's own switch, keeps
//    44 pt in both directions, and still SPEAKS its full label (COUNTERWEIGHT: the label).
//
// WHAT KIND OF GREEN THIS IS (§1): SOURCE-TEXT SCAN, every claim. It proves where the pieces sit
// and which candidate is last; it does NOT prove that two rows fit a 375 pt phone in German —
// every width in the header comment is an ESTIMATE. DEVICE PROBE, open: a 375 pt iPhone in
// German, both stages, with the demo source playing (the pill's „Demo" tag) and with a locked
// camera pulse; the AX1 stack; VoiceOver on the glyph-only Undo/Redo.
//
// HONEST GRADING (§3), against the parent tree (`430b20307`): the file compiles there (it names
// no new symbol). Claim 1 is a REGRESSION (three candidates; the last `VStack` has three
// depth-0 lines). Claims 2, 3 and 4 are red by ONE ANCHOR ABSENCE (`let tools =` does not exist
// there, and neither do the rows that name it — one finding, #486). Claim 5 is a REGRESSION
// (no priority, no `.fixedSize()`). Claim 6's word gate is a REGRESSION (the word is
// unconditional); its label needle is a COUNTERWEIGHT (green on both trees). Transcribed in
// Python against both trees: parent 5 findings (1 + one absence + 5 + 6a + 6b), work tree 0.

import Foundation
import XCTest

final class TheHeadTakesAtMostTwoRowsTests: XCTestCase {

    private static let header = "Sources/Echoelmusic/Studio/ProjectHeader.swift"
    private static let history = "Sources/Echoelmusic/Studio/SongHistoryRow.swift"

    // MARK: 1 — two candidates, and the last one is two rows

    func testThePhoneShapeIsTheLastCandidateAndHasTwoRows() throws {
        let body = try member("var body: some View", in: try code(Self.header))
        let fits = try member("ViewThatFits(in: .horizontal)", in: body)
        let candidates = topLevelLines(of: fits)
        XCTAssertEqual(candidates.count, 2, """
            `ViewThatFits` in `ProjectHeader.body` holds \(candidates.count) candidates: \(candidates). \
            Two is the design — one line, else two rows. A third candidate is a third row on a phone: \
            `ViewThatFits` falls to its LAST shape whenever nothing fits, so the last one is the one \
            a 375 pt phone gets (founder 2026-10-01, „zu groß").
            """)
        guard let last = candidates.last, last.hasPrefix("VStack(") else {
            return XCTFail("ANCHOR MISSING: the last `ViewThatFits` candidate is not a `VStack` (#454): \(candidates)")
        }
        let rows = topLevelLines(of: try lastCandidate(last, in: fits))
        XCTAssertEqual(rows.count, 2, "the phone shape has \(rows.count) rows: \(rows) — at most two (founder 2026-10-01)")
        XCTAssertTrue(rows.allSatisfy { $0.hasPrefix("HStack(") }, "each of the two rows is one line of pieces: \(rows)")
    }

    // MARK: 2 — fixed places: summary with transport, pill with Undo · Redo

    func testEachRowHoldsItsTwoPieces() throws {
        let body = try member("var body: some View", in: try code(Self.header))
        let fits = try member("ViewThatFits(in: .horizontal)", in: body)
        guard let last = topLevelLines(of: fits).last else {
            return XCTFail("ANCHOR MISSING: no `ViewThatFits` candidate (#454)")
        }
        let rows = topLevelLines(of: try lastCandidate(last, in: fits))
        XCTAssertEqual(rows, ["HStack(spacing: 8) { summaryView; transportPair }",
                              "HStack(spacing: 8) { pulsePill; history }"], """
            The phone rows moved. Row 1 is the summary with Play · Record (empty on the Piece \
            stage, so the place gets the whole width there); row 2 is the pulse pill with \
            Undo · Redo. Every control keeps ONE place on both stages — the founder's „one \
            way to an area" applied to the head itself.
            """)
        // S1b-1: the ⓘ moved to the mark's ≡ menu. The head must not keep a second guide switch
        // (two addresses for one setting) nor re-wrap the history in a one-child `tools` stack.
        let head = try code(Self.header)
        for gone in ["guideButton", "guideVisible", "let tools"] {
            XCTAssertFalse(head.contains(gone), """
                `ProjectHeader` carries `\(gone)` again. The guide's one switch is the Guide toggle \
                in the mark's ≡ menu (DAW shell S1b-1); a second one here is a second address for \
                one setting, and a `tools` wrapper around the history alone is structure kept for \
                a test.
                """)
        }
        let pair = try member("let transportPair = Group", in: body)
        XCTAssertTrue(pair.contains("if carriesTransport {"), "the transport stays behind the stage gate (A3b)")
        XCTAssertFalse(pair.contains("history"), """
            Undo · Redo are inside the transport group — they would vanish with Play on the Piece \
            stage, and row 1 would carry three neighbours of the summary
            """)
    }

    // MARK: 3 — the one-line candidate carries the same pieces

    func testTheOneLineShapeCarriesTheSamePieces() throws {
        let body = try member("var body: some View", in: try code(Self.header))
        let fits = try member("ViewThatFits(in: .horizontal)", in: body)
        guard let first = topLevelLines(of: fits).first else {
            return XCTFail("ANCHOR MISSING: no `ViewThatFits` candidate (#454)")
        }
        XCTAssertEqual(first, "HStack(spacing: 10) { summaryView; transportPair; pulsePill; history }", """
            the one-line shape (a wide screen) no longer carries exactly the four pieces of the two \
            rows — a shape that drops one loses a control; one that adds a piece carries it twice
            """)
    }

    // MARK: 4 — the accessibility stack keeps every control

    func testTheAccessibilityStackKeepsEveryControl() throws {
        let body = try member("var body: some View", in: try code(Self.header))
        let stack = try member("if dynamicTypeSize.isAccessibilitySize", in: body)
        let column = try member("VStack(alignment: .leading, spacing: 6)", in: stack)
        XCTAssertEqual(topLevelLines(of: column),
                       ["summaryView; pulsePill; history", "HStack(spacing: 8) { transportPair }"], """
            the accessibility stack changed — at large text every piece keeps a line, the history \
            with its words (claim 6), and Play · Record stay one tap away on the last line
            """)
    }

    // MARK: 5 — the summary yields at the place, never at a number

    func testTheSummaryYieldsAtThePlaceNeverAtANumber() throws {
        let header = try code(Self.header)
        let summary = try member("private func summary(", in: header)
        guard let status = summary.range(of: "Text(ProjectTransport.statusWord(status))"),
              let next = summary.range(of: "ProjectPositionReadout()", range: status.upperBound..<summary.endIndex) else {
            return XCTFail("ANCHOR MISSING: the status word before the position readout in `summary(` (#454)")
        }
        XCTAssertTrue(summary[status.upperBound..<next.lowerBound].contains(".layoutPriority(1)"), """
            the status word lost its priority — beside the transport on a 375 pt phone it would be \
            the child that is squeezed, and the place (the one child built to truncate) would keep \
            its width
            """)
        let tempo = try member("struct ProjectTempoReadout: View", in: header)
        XCTAssertTrue(tempo.contains(".fixedSize()"), "the tempo readout may wrap again — a number never wraps or yields")
        // COUNTERWEIGHT (#343), on the PLACE's own modifiers — the name line truncates too, so a
        // file-wide `.truncationMode(.tail)` would stay green with the place's ellipsis gone.
        guard let place = summary.range(of: "Text(place)"),
              let tail = summary.range(of: ".truncationMode(.tail)", range: place.upperBound..<summary.endIndex) else {
            return XCTFail("ANCHOR MISSING: `Text(place)` → `.truncationMode(.tail)` in `summary(` (#454)")
        }
        XCTAssertFalse(summary[place.upperBound..<tail.lowerBound].contains("Text("),
                       "counterweight: the place still truncates at its tail — the ONE child that yields")
    }

    // MARK: 6 — the history is glyphs, with the word at accessibility sizes

    func testTheHistoryShowsItsWordOnlyAtLargeText() throws {
        let row = try code(Self.history)
        XCTAssertTrue(row.contains("@Environment(\\.dynamicTypeSize) private var dynamicTypeSize"),
                      "the history reads the text-size setting — the switch the head stacks on")
        XCTAssertTrue(row.contains("let words = dynamicTypeSize.isAccessibilitySize"),
                      "the word follows the head's own accessibility switch, not a second threshold (#416)")
        let button = try member("private func button(", in: row)
        guard let gate = button.range(of: "if words {"),
              let word = button.range(of: "Text(title)", range: gate.upperBound..<button.endIndex) else {
            return XCTFail("""
                `Text(title)` is not behind `if words {` in `SongHistoryRow.button(` — at the default \
                size the worded pair does not fit the head's second row beside the pill
                """)
        }
        let between = button[gate.upperBound..<word.lowerBound]
        XCTAssertFalse(between.contains("}"), "the word is the first thing inside the gate, not a later sibling")
        XCTAssertTrue(button.contains(".frame(minWidth: 44, minHeight: 44)"), "a glyph-only button keeps 44 pt both ways")
        // COUNTERWEIGHT (#343): without the word on screen, the label is what VoiceOver says.
        XCTAssertTrue(button.contains(".accessibilityLabel(label)"), "the glyph-only button must still speak its full label")
        for title in ["button(String(localized: \"Undo\")", "button(String(localized: \"Redo\")"] {
            XCTAssertTrue(row.contains(title), "`\(title)` is gone — the history lost a direction")
        }
    }

    // MARK: helpers

    /// A missed anchor FAILS (with `XCTFail` first) and stops the claim — never a skip (#806).
    private struct AnchorMissing: Error { let name: String }

    /// Non-blank lines that START at brace depth zero inside `block` (the text between its outer
    /// braces), trimmed. One SwiftUI child per line is this file's own style; a child written over
    /// several lines appears once, as its first line.
    private func topLevelLines(of block: String) -> [String] {
        var lines: [String] = []
        var depth = 0
        var lineStartDepth = 0
        var current = ""
        var inString = false
        var previous: Character = " "
        for ch in block {
            if ch == "\n" {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if lineStartDepth == 0, !trimmed.isEmpty { lines.append(trimmed) }
                current = ""
                lineStartDepth = depth
                continue
            }
            current.append(ch)
            if ch == "\"", previous != "\\" { inString.toggle() }
            if !inString {
                if ch == "{" { depth += 1 }
                if ch == "}" { depth -= 1 }
            }
            previous = ch
        }
        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if lineStartDepth == 0, !trimmed.isEmpty { lines.append(trimmed) }
        return lines
    }

    /// The body of the LAST candidate, searched from its own line backwards — an earlier
    /// candidate may open with the same `VStack(…)` spelling, and the first match would grade the
    /// wrong shape (#367: on the parent tree the second and third candidates began identically).
    private func lastCandidate(_ line: String, in fits: String) throws -> String {
        guard let start = fits.range(of: line, options: .backwards) else {
            XCTFail("ANCHOR MISSING: `\(line)` (#454)")
            throw AnchorMissing(name: line)
        }
        let head = line.hasSuffix("{") ? String(line.dropLast()) : line
        return try member(head, in: String(fits[start.lowerBound...]))
    }

    /// The text strictly between the outer braces of the block that follows `anchor` (#408);
    /// string-literal aware, so `"{"` in a literal cannot unbalance it.
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code.range(of: "{", range: start.upperBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: `\(anchor)` (#454)")
            throw AnchorMissing(name: anchor)
        }
        var depth = 1
        var index = open.upperBound
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
                    if depth == 0 { return String(code[open.upperBound..<index]) }
                }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: `\(anchor)` never closes (#454)")
        throw AnchorMissing(name: anchor)
    }

    private func code(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }
}
