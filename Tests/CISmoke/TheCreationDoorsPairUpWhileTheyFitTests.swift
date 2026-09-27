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
//    ("above" / "below"), so moving a door beside its partner changes no sentence. And no door
//    scales its text down — a `minimumScaleFactor` would make the row candidate always report a
//    fit (the BioStripView trap `transportRow` documents), and the fallback would never show.
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
// with its whole label readable.

import Foundation
import XCTest

final class TheCreationDoorsPairUpWhileTheyFitTests: XCTestCase {

    private static let viewPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let doors = ["addTrackRow", "importRow", "addMIDITrackRow", "importMIDIRow", "newMIDIPartRow"]

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
        for path in ["Sources/Echoelmusic/Sequencer/AudioImport.swift", "Sources/Echoelmusic/Sequencer/MIDIImport.swift"] {
            let raw = try rawSource(path)
            guard let messages = raw.range(of: "var userMessage: String {") else {
                XCTFail("ANCHOR MISSING: `userMessage` in \(path) (#454)"); continue
            }
            // Brace-bounded (#408): the computed property closes at its own eight-space `}`.
            guard let close = raw.range(of: "\n        }\n", range: messages.upperBound..<raw.endIndex) else {
                XCTFail("ANCHOR MISSING: the end of `userMessage` in \(path) (#454)"); continue
            }
            let tail = String(raw[messages.upperBound..<close.lowerBound])
            XCTAssertTrue(tail.contains("track first."), "\(path): the refusal still asks for a track by name")
            for word in [" above", " below"] {
                XCTAssertFalse(tail.contains(word), "\(path): a refusal names a door by position (`\(word)`) — the doors move")
            }
        }
        let code = try source(Self.viewPath)
        for door in Self.doors {
            guard let start = code.range(of: "private var \(door): some View {") else {
                XCTFail("ANCHOR MISSING: `\(door)` (#454)"); continue
            }
            let rest = code[start.upperBound...]
            let end = rest.range(of: "\n    private ")?.lowerBound ?? rest.endIndex
            XCTAssertFalse(rest[..<end].contains("minimumScaleFactor"),
                           "`\(door)` shrinks its label — the paired row would then always report a fit")
        }
        let view = try rawSource(Self.viewPath)
        guard let plate = view.range(of: ".accessibilityLabel(\"No tracks yet. Tap Add Audio Track, then Import Audio"),
              let plateEnd = view.range(of: "\")", range: plate.upperBound..<view.endIndex) else {
            return XCTFail("the empty plate no longer walks the doors by their labels")
        }
        for word in [" above", " below"] {
            XCTAssertFalse(view[plate.lowerBound..<plateEnd.lowerBound].contains(word),
                           "the empty plate names a door by position (`\(word)`) — the doors move")
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
