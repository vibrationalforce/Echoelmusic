// TheChromeSpeaksGermanTests.swift
// Echoel — decision E4 of the interface audit (founder 2026-09-30, "Ja": the app speaks German,
// chrome first, ~40 words): every word of the stage seam, the area row and the head transport
// has a German unit in `Localizable.xcstrings`, and the code reaches the catalog for it.
//
// KIND — two kinds, labelled per claim (Tests/CISmoke/CLAUDE.md §1):
//   · END-TO-END for the WORDS: the shipped enums and `ProjectTransport` are driven (they are
//     Foundation-only) and every word they return is looked up as a KEY in the catalog. In the
//     test host the locale is English, so `String(localized:)` returns the key itself — which is
//     exactly the string the catalog is keyed by. Whether iOS then shows the German is a DEVICE
//     PROBE (a German-language device), registered in `docs/dev/FOUNDER_INBOX.md` §2, not proven here.
//   · SOURCE-TEXT for the REACH: a word that an enum returns as a plain `"literal"` is spelled
//     VERBATIM by `Text(candidate.label)` — SwiftUI localises `Text("literal")`, never
//     `Text(someString)`. So the three chrome files must return every user-visible literal
//     through `String(localized:)`. That is the half no runtime check in an English host can see.
//
// WHY THE CATALOG IS THE TRUTH AND NOT THIS FILE (#416). The German words live ONLY in
// `Localizable.xcstrings`; this guard never restates a translation. The one German word it does
// name comes from `docs/dev/GLOSSARY.md`'s own table (claim 5), so the glossary stays the single
// definition of "Stück".
//
// GRADING against the parent (§3). Claims 1, 2, 4 and 5 are FORWARD: the catalog keys they look
// up did not exist on the parent, so every one of them was red there for ONE reason — the
// absence of the 40 entries — counted once (#486). Claim 3 was red on the parent for its named
// reason (33 plain literals in the three files). The counterweights inside claims 1–4 (the enums
// still have their cases, the seven literal keys still occur as `Text("…")` in Sources, the
// catalog's en unit equals the key) are green on both trees. Transcribed in Python against both
// trees before the push; the Swift here is graded only by `Build for Testing` (§0).
//
// WHAT IT DOES NOT FORBID (#364): more chrome words, another language, a reworded sentence. A
// reworded sentence turns the OLD key into an orphan — `StringCatalogIsHonestTests` claim
// `testEveryKeyStillExistsAsALiteralInSources` catches that, not this file; this file catches the
// NEW sentence arriving without its German.

import XCTest
import Foundation
@testable import Echoelmusic

final class TheChromeSpeaksGermanTests: XCTestCase {

    private static let chromeFiles = [
        "Sources/Echoelmusic/Studio/StudioStage.swift",
        "Sources/Echoelmusic/Studio/StudioArea.swift",
        "Sources/Echoelmusic/Studio/ProjectTransport.swift",
    ]

    /// The keys SwiftUI localises by content alone — `Text("Pause")`, `.accessibilityLabel("Guide")`.
    /// No code change carries them, so the counterweight is that each still occurs as such a literal.
    private static let literalKeys = ["Pause", "Guide", "Stage", "Follows pulse", "Locked", "Demo", "Heart rate"]

    // MARK: - helpers

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CISmoke
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources/Echoelmusic").path) else {
            throw XCTSkip("source tree not present — this guard reads source text and skips rather than earning a green (#454)")
        }
        return root
    }

    private func catalogStrings() throws -> [String: Any] {
        let url = try repoRoot().appendingPathComponent("Sources/Echoelmusic/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = object["strings"] as? [String: Any] else {
            throw XCTSkip("Localizable.xcstrings is not the JSON shape this guard reads — re-anchor (#454)")
        }
        return strings
    }

    /// The German unit of `key`, or nil when the key or its `de` unit is missing.
    private func german(_ key: String, in strings: [String: Any]) -> (state: String, value: String)? {
        guard let entry = strings[key] as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any],
              let de = localizations["de"] as? [String: Any],
              let unit = de["stringUnit"] as? [String: Any],
              let state = unit["state"] as? String,
              let value = unit["value"] as? String else { return nil }
        return (state, value)
    }

    private func assertGerman(_ words: [String], _ what: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let strings = try catalogStrings()
        XCTAssertFalse(words.isEmpty, "no \(what) to check — the enum lost its cases? (#454)", file: file, line: line)
        for word in words {
            guard let de = german(word, in: strings) else {
                XCTFail("""
                    \(what) "\(word)" has no German unit in Localizable.xcstrings. A chrome word without \
                    its `de` entry reverts to English for a German user while the words around it stay \
                    German (StringCatalogIsHonestTests names why that is worse than all-English). Add the \
                    key with a translated `de` unit — the catalog, never this file, holds the German (#416).
                    """, file: file, line: line)
                continue
            }
            XCTAssertEqual(de.state, "translated", "\(what) \"\(word)\": a `new` unit ships nothing (xcstringstool skips it)", file: file, line: line)
            XCTAssertFalse(de.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(what) \"\(word)\": empty German", file: file, line: line)
        }
    }

    private func codeOnly(_ relative: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relative)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw XCTSkip("\(relative) is not on disk — re-anchor this guard (#454)")
        }
        return SourceText.codeOnly(text)
    }

    // MARK: - claim 1 — END-TO-END: every stage and area word is a catalog key with a German unit

    func testEveryStageAndAreaWordHasAGermanUnit() throws {
        let stage = StudioStage.allCases.flatMap { [$0.label, $0.spokenHint] }
        let area = StudioArea.allCases.flatMap { [$0.label, $0.spokenHint] }
        XCTAssertEqual(StudioStage.allCases.count, 2, "counterweight: the seam still has its two stages")
        XCTAssertEqual(StudioArea.allCases.count, 5, "counterweight: the area row still has its five areas")
        try assertGerman(stage, "stage word")
        try assertGerman(area, "area word")
    }

    // MARK: - claim 2 — END-TO-END: every head-transport word and hint is a catalog key with a German unit

    func testEveryTransportWordHasAGermanUnit() throws {
        let statuses: [ProjectTransport.Status] = [.stopped, .paused, .playingInstrument, .playingSong, .recording]
        let plays: [ProjectTransport.PlayAction] = [.startSong, .startSongAndInstrument, .resumeInstrument, .unavailable]
        var words = statuses.map(ProjectTransport.statusWord)
        for running in [false, true] {
            words.append(ProjectTransport.buttonWord(running: running))
            for play in plays {
                words.append(ProjectTransport.buttonLabel(running: running, play: play))
                words.append(ProjectTransport.buttonHint(running: running, play: play))
            }
        }
        words += [ProjectTransport.stopHint, ProjectTransport.instrumentRunningCaption,
                  ProjectTransport.unsavedName, ProjectTransport.projectName(nil), ProjectTransport.projectName("  ")]
        // counterweight — the English words the sibling guard pins are unchanged in the English host
        XCTAssertEqual(ProjectTransport.statusWord(.playingSong), "Playing piece")
        XCTAssertEqual(ProjectTransport.buttonWord(running: true), "Stop")
        try assertGerman(Array(Set(words)).sorted(), "transport word")
    }

    // MARK: - claim 3 — SOURCE-TEXT: the three chrome files return no plain literal

    func testTheThreeChromeFilesReturnOnlyLocalizedLiterals() throws {
        // A `return "Piece"` is spelled verbatim by `Text(candidate.label)`; only
        // `return String(localized: "Piece")` reaches the catalog. Interpolated strings
        // (`return "\(lane.name) · …"`) are composed, not looked up, and are not this claim's.
        let plain = try NSRegularExpression(pattern: #"return "[A-Za-z][^"\\]*""#)
        let bareLet = try NSRegularExpression(pattern: #"static let (stopHint|instrumentRunningCaption|unsavedName) = ""#)
        var wrapped = 0
        for relative in Self.chromeFiles {
            let code = try codeOnly(relative)
            let range = NSRange(code.startIndex..., in: code)
            let offenders = plain.matches(in: code, range: range).map { String(code[Range($0.range, in: code)!]) }
            XCTAssertEqual(offenders, [], """
                \(relative) returns a user-visible literal without `String(localized:)`. SwiftUI \
                localises `Text("literal")` by content but spells `Text(someString)` verbatim, so a \
                word this enum returns as a plain literal can never be German on the stage seam, the \
                area row or the head. Wrap it — and add its `de` unit to Localizable.xcstrings.
                """)
            XCTAssertEqual(bareLet.numberOfMatches(in: code, range: range), 0, "\(relative): a bare `static let … = \"` hint")
            wrapped += code.components(separatedBy: "String(localized:").count - 1
        }
        XCTAssertGreaterThanOrEqual(wrapped, 30, "counterweight: the three files still carry their ~33 localised words (measured 34 sites on 2026-09-30)")
    }

    // MARK: - claim 4 — the seven literal keys are translated AND still spelled as literals on screen

    func testTheLiteralChromeKeysAreTranslatedAndStillOnScreen() throws {
        try assertGerman(Self.literalKeys, "literal chrome key")
        // counterweight: SwiftUI can only find them if the literal is still written as `"…"`
        let root = try repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            throw XCTSkip("cannot walk Sources/Echoelmusic (#454)")
        }
        var haystack = ""; var files = 0
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            if let text = try? String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8) {
                haystack += SourceText.codeOnly(text); files += 1
            }
        }
        XCTAssertGreaterThan(files, 250, "the walk saw too few files to mean anything (#454)")
        for key in Self.literalKeys {
            XCTAssertTrue(haystack.contains("\"\(key)\""), """
                "\(key)" is a catalog key but no longer a literal in Sources — the German is an orphan. \
                Either the word was reworded (add the new key, retire this one) or it now travels as \
                a String variable, which SwiftUI spells verbatim (wrap it in String(localized:)).
                """)
        }
    }

    // MARK: - claim 5 — the German for "Piece" is the glossary's word, read from the glossary

    func testTheGermanPieceIsTheGlossaryWord() throws {
        let glossary = try repoRoot().appendingPathComponent("docs/dev/GLOSSARY.md")
        guard let text = try? String(contentsOf: glossary, encoding: .utf8),
              let row = text.split(separator: "\n").first(where: { $0.hasPrefix("| piece |") }) else {
            throw XCTSkip("docs/dev/GLOSSARY.md has no `| piece |` row — re-anchor (#454)")
        }
        let cells = row.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        guard cells.count >= 2 else { throw XCTSkip("glossary row shape changed (#454)") }
        let wort = cells[1]
        let strings = try catalogStrings()
        for key in ["Piece", "Playing piece", "Unsaved piece", "Play the piece"] {
            guard let de = german(key, in: strings) else { XCTFail("\"\(key)\" has no German unit"); continue }
            XCTAssertTrue(de.value.contains(wort), """
                the German for "\(key)" is "\(de.value)" and does not carry the glossary word "\(wort)" \
                (docs/dev/GLOSSARY.md, row `piece`). One word per thing holds in German too.
                """)
        }
    }
}
