// TheCreationDoorsPairUpWhileTheyFitTests.swift
// Echoel — modes census 2026-09-26, design slice 4: the Workstation's creation doors sit in
// pairs while they fit.
//
// WHAT THIS PINS. Five full-width doors (Add Audio Track · Import Audio · Add MIDI Track ·
// Import MIDI · New MIDI Part) stood one under the other and pushed the song below the fold on
// a phone. Each track door now sits BESIDE its import, in the old order, and the pair stacks
// again where it does not fit.
//
// 1. SOURCE: `creationPair` offers the HORIZONTAL candidate first (`ViewThatFits` takes the
//    first that fits) and a leading-aligned stack as the fallback, both at the doors' 8 pt.
// 2. SOURCE: the mount order is unchanged — audio pair, MIDI pair, New MIDI Part, then the one
//    note line — and every door is mounted exactly once.
// 3. COUNTERWEIGHT: the refusals and the empty plate name the doors by LABEL, never by position
//    ("above", "below", "beside", …), so moving a door beside its partner changes no sentence.
//    And no door scales its text down: `ViewThatFits` must see each label at its real width. (That
//    a `minimumScaleFactor` would make the row always "fit" is the BioStripView premise, inherited
//    and unmeasured — review of 60f1bd2ab; the pin keeps the question from arising.)
//
// Grading (§0, no Swift toolchain): on the parent (`8a0202491`) `creationPair` does not exist,
// so claims 1-2 are red by ONE absence (#486) — FORWARD guards, not regressions. Claim 3 is a
// COUNTERWEIGHT, green on both trees. All three transcribed into Python against both trees,
// plus mutants (candidates swapped; Import Audio moved out of its pair; a door mounted twice).
// NOT covered: whether the pair fits on a given phone and text size, and that nothing clips —
// a device look.
// NEEDS-FOUNDER-VERIFY: Workstation on the phone at the default text size → "Add Audio Track"
// and "Import Audio" side by side, "Add MIDI Track" and "Import MIDI" side by side, "New MIDI
// Part" alone below; at the largest accessibility size every door stands on its own line again
// with its whole label readable; and at one or two sizes in between, whether one pair stacking
// while the other stays side by side looks acceptable (the two pairs decide independently).

import Foundation
import XCTest

final class TheCreationDoorsPairUpWhileTheyFitTests: XCTestCase {

    private static let viewPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let doors = ["addTrackRow", "importRow", "addMIDITrackRow", "importMIDIRow", "newMIDIPartRow"]
    /// Words that place a door by where it sits. `left`/`right` are left out: they occur inside
    /// ordinary words and would false-alarm (#364).
    private static let positionWords = [" above", " below", " beside", "next to", " underneath", "one row"]

    // MARK: 1 — the pair's two candidates

    func testThePairTriesTheRowFirstAndFallsBackToAStack() throws {
        let code = try source(Self.viewPath)
        guard let start = code.range(of: "private func creationPair<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {") else {
            return XCTFail("`creationPair` is gone — the creation doors are one-per-line again")
        }
        let helper = String(code[start.upperBound...])
        guard let pair = sequence(["ViewThatFits(in: .horizontal) {",
                                   "HStack(spacing: 8) {", "content()", "Spacer(minLength: 0)", "}",
                                   "VStack(alignment: .leading, spacing: 8) {", "content()", "}", "}"],
                                  in: helper) else {
            return XCTFail("""
                `creationPair` no longer offers `HStack(spacing: 8)` FIRST and a leading \
                `VStack(spacing: 8)` second — `ViewThatFits` takes the first candidate that fits, \
                so a stack first would never pair the doors, and a row alone would crush them
                """)
        }
        XCTAssertTrue(helper[..<pair.lowerBound].allSatisfy(\.isWhitespace),
                      "the `ViewThatFits` is the helper's whole body, not something further down the file")
    }

    // MARK: 2 — same doors, same order, each once

    func testTheDoorsKeepTheirOrderAndAppearOnce() throws {
        let code = try source(Self.viewPath)
        guard sequence(["creationPair {", "addTrackRow", "importRow", "}",
                        "creationPair {", "addMIDITrackRow", "importMIDIRow", "}",
                        "newMIDIPartRow", "if let note = importNote { importNoteLine(note) }"], in: code) != nil else {
            return XCTFail("""
                the creation doors are no longer mounted as (Add Audio Track | Import Audio), \
                (Add MIDI Track | Import MIDI), New MIDI Part, then the note line — the order the \
                empty plate's sentence walks through
                """)
        }
        let lines = code.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        for door in Self.doors {
            XCTAssertEqual(lines.filter { $0 == door }.count, 1, "`\(door)` must be mounted exactly once")
        }
        XCTAssertEqual(code.components(separatedBy: "creationPair {").count - 1, 2, "two pairs, no more")
    }

    // MARK: 3 — counterweights: nothing names a position, nothing hides the misfit

    func testNoSentenceNamesADoorByPositionAndNoDoorShrinksItsLabel() throws {
        // Review of 60f1bd2ab, LOW: every sentence the two import types SAY — refusals, the
        // success note, the empty-part note — not only `userMessage`. Comments are stripped, so
        // a doc comment may still explain the layout; a string literal may not.
        for path in ["Sources/Echoelmusic/Sequencer/AudioImport.swift", "Sources/Echoelmusic/Sequencer/MIDIImport.swift"] {
            let code = try source(path)
            XCTAssertTrue(code.contains("track first.\""), "\(path): the refusal still asks for a track by name")
            // Review of 4f62d6867, LOW-7: only the STRING LITERALS — an identifier or a log
            // line is not a sentence a musician reads (#364).
            let said = stringLiterals(in: code)
            XCTAssertFalse(said.isEmpty, "\(path): no string literal found — a scan that saw nothing is not a pass")
            for word in Self.positionWords {
                XCTAssertFalse(said.contains { $0.contains(word) },
                               "\(path): a sentence names a door by position (`\(word)`) — the doors move")
            }
        }
        let code = try source(Self.viewPath)
        for door in Self.doors + ["creationPair"] {
            let declaration = door == "creationPair"
                ? "private func creationPair<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {"
                : "private var \(door): some View {"
            guard let start = code.range(of: declaration) else {
                XCTFail("ANCHOR MISSING: `\(door)` (#454)"); continue
            }
            let rest = code[start.upperBound...]
            guard let end = rest.range(of: "\n    private ")?.lowerBound else {
                XCTFail("ANCHOR MISSING: the member after `\(door)` (#454)"); continue
            }
            XCTAssertFalse(rest[..<end].contains("minimumScaleFactor"),
                           "`\(door)` shrinks its label — the pair's fit test should see every label at its real width")
        }
        let view = try rawSource(Self.viewPath)
        guard let plate = view.range(of: ".accessibilityLabel(\"No tracks yet. Tap Add Audio Track, then Import Audio"),
              let plateEnd = view.range(of: "\")", range: plate.upperBound..<view.endIndex) else {
            return XCTFail("the empty plate no longer walks the doors by their labels")
        }
        guard let shown = view.range(of: "Text(\"Tap Add Audio Track, then Import Audio"),
              let shownEnd = view.range(of: "\")", range: shown.upperBound..<view.endIndex) else {
            return XCTFail("the empty plate's visible sentence no longer walks the doors by their labels")
        }
        for word in Self.positionWords {
            XCTAssertFalse(view[plate.lowerBound..<plateEnd.lowerBound].contains(word),
                           "the empty plate's spoken sentence names a door by position (`\(word)`) — the doors move")
            XCTAssertFalse(view[shown.lowerBound..<shownEnd.lowerBound].contains(word),
                           "the empty plate's visible sentence names a door by position (`\(word)`) — the doors move")
        }
    }

    // MARK: helpers

    /// Where `tokens` occur in order with nothing but whitespace between them, or nil.
    private func sequence(_ tokens: [String], in text: String) -> Range<String.Index>? {
        var from = text.startIndex
        while let first = text.range(of: tokens[0], range: from..<text.endIndex) {
            var end = first.upperBound
            var matched = true
            for token in tokens.dropFirst() {
                guard let next = text.range(of: token, range: end..<text.endIndex),
                      text[end..<next.lowerBound].allSatisfy(\.isWhitespace) else { matched = false; break }
                end = next.upperBound
            }
            if matched { return first.lowerBound..<end }
            from = first.upperBound
        }
        return nil
    }

    /// The contents of every `"…"` literal in comment-stripped source, escapes kept as written.
    /// Multi-line `"""` literals are not split out — neither import type uses one for a sentence.
    private func stringLiterals(in code: String) -> [String] {
        var found: [String] = []
        var current = ""
        var inside = false
        var escaped = false
        for ch in code {
            if inside {
                if escaped { current.append(ch); escaped = false }
                else if ch == "\\" { current.append(ch); escaped = true }
                else if ch == "\"" { found.append(current); current = ""; inside = false }
                else { current.append(ch) }
            } else if ch == "\"" {
                inside = true
            }
        }
        return found
    }

    private func rawSource(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return text
    }

    private func source(_ relativePath: String) throws -> String {
        SourceText.codeOnly(try rawSource(relativePath))
    }
}
