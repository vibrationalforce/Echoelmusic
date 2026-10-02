// TheEmptyStateOffersTheNextStepNotARecipeTests.swift
// Echoel — interface audit 2026-09-30, Gestaltung rule 10 ("Wiedererkennen statt Erinnern":
// an empty state shows the next action as a button, never a recipe). BLOCKING bundle.
//
// THE DEFECT. Two empty states told a first-time user a sequence to remember:
//   · the Workstation's empty plate — "Tap Add Audio Track, then Import Audio — or Add MIDI
//     Track, then Import MIDI or New MIDI Part. A file becomes a part you can play; a new part
//     plays once it has notes." — a four-step recipe, spoken as one VoiceOver sentence;
//   · the instrument plate's first-run line under the grey tiles — "Press Play first — then you
//     can record the loop, save the piece, or export a WAV or MIDI file."
// Both name real controls (that was #355's fix and it stays), but both are RECIPES: the reader
// must hold "first … then …" in memory while looking for the first button. WCAG 3.3.8 and the
// rule say: show the next action, let the next screen show the one after it. On the Workstation
// the next actions ARE buttons on the same plate ("Add Audio Track", "Add MIDI Track"), and once a
// track exists every import and new part is in the tab row's Add menu (UX audit slice 4); on the
// instrument plate Play sits one band up. So the text names the next action and stops.
// ⛔ Slice 4's first sentence said "After that, Add holds every import and new part" — the same
// sequence as "then", and green here only because "after" was not a recipe word (review of
// fe04ad196). It is one now, with its own scanner case.
//
// WHAT THIS GUARDS (SOURCE-TEXT SCAN — it proves the words, not that a user finds the button;
// the device half is a founder look).
//   1. The Workstation empty state carries no recipe word ("first", "then") in any visible
//      literal, and names both doors by their labels.
//   2. COUNTERWEIGHT: those two doors exist as buttons with exactly those words — otherwise
//      claim 1 would be satisfied by naming buttons that are not there.
//   3. The instrument's first-run line (the `if !hasComposed {` block) carries no recipe word
//      and names Play, the control that starts.
//   4. The recipe scanner itself reds on a recipe and stays green on the repaired sentences.
//
// LIMIT, stated (#364): this is scoped to the two empty states the audit found. A refusal such
// as "add an audio track first" (`AudioImport`) is an ANSWER to an action, not an empty state,
// and a lesson summary in `LearnLibrary` ("Start the music first — then a finger on the back
// camera") is a step list by design; neither is scanned here. A NEW empty state with a recipe
// is caught only when it is added to this file.
//
// GRADING against the parent: claims 1 and 3 RED for their named reason (both sentences carry
// "then"; the instrument's carries "first" too); claim 2 green on both trees; claim 4 forward.

import Foundation
import XCTest

final class TheEmptyStateOffersTheNextStepNotARecipeTests: XCTestCase {

    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"

    /// The words a recipe is made of. Tokenised on non-letters, lower-cased, so "First" and
    /// "then," count and "thence" or "firstly" do not.
    private static let recipeWords: Set<String> = ["first", "then", "after"]

    // MARK: 1 — the Workstation empty state names the doors and gives no recipe

    func testTheWorkstationEmptyStateNamesTheDoorsAndGivesNoRecipe() throws {
        let code = try codeOnly(Self.workstation)
        let body = try member("private var emptyState: some View {", in: code)
        let literals = Self.stringLiterals(in: body)
        XCTAssertFalse(literals.isEmpty, "the empty state has no visible text at all — a scan that saw nothing is not a pass")
        let recipe = literals.filter { Self.isRecipe($0) }
        XCTAssertTrue(recipe.isEmpty, """
            The Workstation's empty plate gives a recipe again: \(recipe). Rule 10: an empty state \
            names the next action — the doors on this plate — and stops; the next screen shows the \
            step after it. Not "Tap X, then Y".
            """)
        let joined = literals.joined(separator: " ")
        for door in ["Add Audio Track", "Add MIDI Track"] {
            XCTAssertTrue(joined.contains(door), """
                The empty plate no longer names the door "\(door)". It has to name the buttons \
                that fill it, by their labels (never by position — `TheCreationDoorsPairUpWhileTheyFitTests`).
                """)
        }
    }

    // MARK: 2 — counterweight: the doors exist with those words

    func testTheNamedDoorsExistWithThoseWords() throws {
        let code = try codeOnly(Self.workstation)
        for door in ["Add Audio Track", "Add MIDI Track"] {
            XCTAssertEqual(Self.occurrences(of: "Text(\"\(door)\")", in: code), 1, """
                `Text("\(door)")` is not exactly once in WorkstationView — the empty plate names \
                this button; if its label changed, the plate's sentence changes in the same commit.
                """)
        }
    }

    // MARK: 3 — the instrument's first-run line names Play and gives no recipe

    func testTheFirstRunLineNamesPlayAndGivesNoRecipe() throws {
        let code = try codeOnly(Self.studio)
        let anchor = "if !hasComposed {"
        XCTAssertEqual(Self.occurrences(of: anchor, in: code), 1, "`\(anchor)` must be unique in the stripped studio source — the block below keys on it (#408)")
        guard let start = code.range(of: anchor) else { return XCTFail("ANCHOR MISSING: `\(anchor)`") }
        let rest = code[start.upperBound...]
        guard let end = rest.range(of: "\n            }") else { return XCTFail("ANCHOR MISSING: the end of the first-run block") }
        let literals = Self.stringLiterals(in: String(rest[..<end.lowerBound]))
        XCTAssertFalse(literals.isEmpty, "the first-run block has no visible text — a scan that saw nothing is not a pass")
        let recipe = literals.filter { Self.isRecipe($0) }
        XCTAssertTrue(recipe.isEmpty, """
            The instrument's first-run line gives a recipe again: \(recipe). Rule 10: name Play, \
            the control that starts (#355b), and what follows once it plays — not "first … then".
            """)
        XCTAssertTrue(literals.joined(separator: " ").contains("Play"), """
            The first-run line no longer names Play. The greyed tiles under the transport are the \
            first thing a new user meets; this sentence has to name the control that starts \
            (`CopyNamesTheLiveControlTests` keeps the positive half).
            """)
    }

    // MARK: 4 — the scanner itself

    func testTheRecipeScannerRedsOnARecipe() {
        XCTAssertTrue(Self.isRecipe("Tap Add Audio Track, then Import Audio"))
        XCTAssertTrue(Self.isRecipe("Press Play first — then you can record the loop"))
        XCTAssertTrue(Self.isRecipe("First, add a track."), "capitalised and punctuated still counts")
        XCTAssertTrue(Self.isRecipe("to begin. After that, Add holds every import"), "\"after that\" is \"then\" (slice 4 review)")
        XCTAssertFalse(Self.isRecipe("Add Audio Track or Add MIDI Track to begin."))
        XCTAssertFalse(Self.isRecipe("Play starts the music."))
        XCTAssertFalse(Self.isRecipe("Thence and firstly are other words"), "tokens, not substrings")
        XCTAssertEqual(Self.stringLiterals(in: "Text(\"a\") + \"b\"").count, 2)
    }

    // MARK: - helpers

    private static func isRecipe(_ literal: String) -> Bool {
        let tokens = literal.lowercased().split { !$0.isLetter }.map(String.init)
        return tokens.contains { recipeWords.contains($0) }
    }

    /// The `"…"` literals of a code fragment, in order. The fragments scanned here carry no
    /// escaped quotes; a literal that did would fragment, which reads as MORE literals, never fewer.
    private static func stringLiterals(in code: String) -> [String] {
        let parts = code.components(separatedBy: "\"")
        guard parts.count >= 3 else { return [] }
        return stride(from: 1, to: parts.count - 1, by: 2).map { parts[$0] }
    }

    private static func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    /// The member's text from its declaration to the next top-level `private` member.
    private func member(_ declaration: String, in code: String) throws -> String {
        guard let start = code.range(of: declaration) else {
            throw XCTSkip("ANCHOR MISSING: `\(declaration)` — the member moved; re-anchor, do not let the scan pass on nothing")
        }
        let rest = code[start.upperBound...]
        guard let end = rest.range(of: "\n    private ") else {
            throw XCTSkip("ANCHOR MISSING: the member after `\(declaration)`")
        }
        return String(rest[..<end.lowerBound])
    }

    private func repoRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) else {
            throw XCTSkip("repository root not found from \(#filePath) — source scan skipped, not passed")
        }
        return url
    }

    private func codeOnly(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("\(relativePath) is absent — the file moved; update the path, do not let the scan pass on nothing")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}
