// TheGenreListsMatchTheirOwnCountTests.swift
// Echoel — #1295b. Four user-facing surfaces do not just STATE the genre count, they ENUMERATE
// the genres: both `release_notes.txt`, `docs/tools.html` and `docs/brainstorming.html`. #1295
// added Nordic Fiddle and moved the NUMBER on all seven claim surfaces — and left all four
// LISTS at the old thirty-two names while the sentence around them said "thirty-three". That
// shipped. This guard exists because it happened, not in case it might.
//
// ⭐ WHY A NUMBER AND ITS OWN LIST DRIFT APART, stated because the mechanism is general: the
// number is one token and `WebsitePagesAreFindableAndHonestTests` holds it, so a session
// updating a genre searches for the numeral, finds every home, and stops. The list has no
// numeral in it. It is the #1343 defect one level out — a second copy of `MusicStyle.offered`
// living in prose — except here the copy sits in the App Store description, where a claim that
// does not match the build is a 2.3 rejection.
//
// ⚠️ WHAT THIS GUARD ASSERTS. That every OFFERED genre's display name appears on each
// enumerating surface, and that the spelled-out number in the same sentence equals the roster
// count. It does NOT parse the list's punctuation — see the ⛔ below for why that design died.
// A display name that is a substring of unrelated prose would give a false GREEN; that is the
// safe direction and it is stated rather than hidden.
//
// ⛔ **THE FIRST DESIGN WAS A LIST PARSER AND IT WAS WRONG ON BOTH TREES.** It located the run
// of names by markers, stopped at punctuation and counted comma-separated items: it returned 49
// and 50 for the two release notes (the stop never matched, so it swallowed later bullets) and
// 34 / 36 for the two pages (the parenthesised shelf lists and an inner " and " each split
// wrong). A checker that brittle is worse than none (#665) — and it failed toward a FALSE RED,
// which is the only reason it announced itself. Two further parser bugs died in the rewrite and
// are recorded at `offeredDisplayNames()`, because each produced a confident wrong answer
// rather than an error.
//
// ⚠️ HONEST GRADING (§0). No local Swift toolchain — **11 assertions across three claims**
// (claim 1 = 5 including the anchor, claim 2 = 4, claim 3 = 2; claims 1 and 2 are loops over
// four surfaces, so the Swift STATEMENT count is smaller — the tally here is assertions MADE,
// because a statement count understates what goes red, #1334). Transcribed in Python and driven
// against BOTH trees. On the parent (`8db9256`) **4 are red and they are ONE finding** (#486):
// all four name the same absence, `Nordic Fiddle`, missing from all four lists while all four
// sentences already said thirty-three. Booking four regressions would be the flattering
// direction (#433/#464). The other **7 are green on both trees**: the roster anchor, the four
// number checks (the number was moved correctly in #1295 — that half was never broken), and
// two counterweights.
// SOURCE-TEXT SCAN (§1): no symbol is called, so nothing here needs `@testable` (#1337).
//
// ⛔ 2026-10-29 (GM28, W6 STORE): THE TWO `release_notes.txt` SURFACES LEFT `enumerating`. The
// store text now describes Echoel Studio 11.0.0 (builds 10004–10017 on the same App Store
// record), and the Studio has no genre roster by design (`docs/dev/NEUPLANUNG_2026-10-18.md`:
// "no genres, no generated notes") — `MusicStyle.offered` is the EARLIER app's roster, which the
// website still enumerates, so `docs/tools.html` and `docs/brainstorming.html` stay. Claim 3's
// first counterweight ("curated genres" in the en-US notes) is INVERTED rather than deleted: the
// Studio release notes must not name a curated roster, in either locale, because a Studio buyer
// would read it as a feature of the app they download. If a roster ever ships in the Studio, put
// its surfaces back into `enumerating` and let claims 1 and 2 pin the list — the message says so.
// Grading for this change (§0, Python, both texts): claim 3's inverted half is RED on the earlier
// release notes (both carried "curated genres"/"kuratierte Genres") and GREEN on the Studio's;
// claims 1 and 2 are unchanged on the two website surfaces. The tally above is history; since
// 2026-10-29 the file makes 8 assertions (claim 1 = 3 including the anchor, claim 2 = 2,
// claim 3 = 3), counted as assertions MADE, not statements (#1334).

import Foundation
import XCTest

final class TheGenreListsMatchTheirOwnCountTests: XCTestCase {

    /// Surfaces that enumerate the genres, with the sentence's spelled-out number.
    /// ⛔ The two `fastlane/metadata/*/release_notes.txt` entries left on 2026-10-29 — see the
    /// header; `storeNotes` below holds them for the inverted counterweight.
    private static let enumerating = [
        "docs/tools.html",
        "docs/brainstorming.html",
    ]

    /// The Studio store text that must NOT enumerate a genre roster (2026-10-29).
    private static let storeNotes = [
        "fastlane/metadata/en-US/release_notes.txt",
        "fastlane/metadata/de-DE/release_notes.txt",
    ]

    private static let spelled: [String: Int] = [
        "Thirty-two": 32, "Thirty-three": 33, "Thirty-four": 34, "Thirty-five": 35,
        "Thirty-six": 36, "Thirty-seven": 37, "Thirty-eight": 38, "Thirty-nine": 39,
        "Forty": 40, "Forty-one": 41, "Forty-two": 42, "Forty-three": 43, "Forty-four": 44,
        "Forty-five": 45,
        "Zweiunddrei\u{00DF}ig": 32, "Dreiunddrei\u{00DF}ig": 33, "Vierunddrei\u{00DF}ig": 34,
        "F\u{00FC}nfunddrei\u{00DF}ig": 35, "Sechsunddrei\u{00DF}ig": 36,
        "Siebenunddrei\u{00DF}ig": 37, "Achtunddrei\u{00DF}ig": 38, "Neununddrei\u{00DF}ig": 39,
        "Vierzig": 40, "Einundvierzig": 41, "Zweiundvierzig": 42, "Dreiundvierzig": 43,
        "Vierundvierzig": 44, "F\u{00FC}nfundvierzig": 45,
    ]

    /// Claim 1 — every OFFERED genre's display name appears on every enumerating surface.
    /// This is what shipped broken in #1295: Nordic Fiddle was added to the roster, the number
    /// moved on all seven claim surfaces, and all four lists stayed at the old names.
    func testEverySurfaceListsEveryOfferedGenre() throws {
        let names = try Self.offeredDisplayNames()
        XCTAssertGreaterThan(
            names.count, 10,
            "ANCHOR MISSING: could not resolve `MusicStyle.offered` to display names (#454). "
            + "A parser that matches nothing is a finding, never a pass.")
        for path in Self.enumerating {
            let text = try Self.text(path)
            let absent = names.filter { !text.contains($0) }
            XCTAssertTrue(
                absent.isEmpty,
                "\(path) does not name \(absent.count) offered genre(s): \(absent.joined(separator: ", ")). "
                + "The NUMBER in that sentence is one token a grep finds in every home; the LIST "
                + "is not, which is exactly how #1295 shipped a sentence saying thirty-three "
                + "above thirty-two names. On an App Store surface a claim that does not match "
                + "the build is a 2.3 rejection.")
        }
    }

    /// Claim 2 — and the spelled-out number in each sentence is the roster's, not its own.
    func testTheStatedNumberIsTheRosterCount() throws {
        let offered = try Self.offeredDisplayNames().count
        for path in Self.enumerating {
            let text = try Self.text(path)
            guard let stated = Self.statedCount(in: text) else {
                XCTFail("\(path) no longer spells out a genre count this guard knows. Add the "
                        + "new word to `spelled` in the SAME commit — an unparsed number is not "
                        + "a pass (#926).")
                continue
            }
            XCTAssertEqual(
                stated.value, offered,
                "\(path) claims \(stated.value) genres (\"\(stated.word)\"); the roster holds "
                + "\(offered). Measure, never recite: `python3 scripts/genre-prebatch.py "
                + "<empty.json>` prints the roster line. A new genre moves number AND list, in "
                + "the same commit, on every surface.")
        }
    }

    /// Claim 3 — counterweights. Without these, claims 1 and 2 pass on a tree that deleted the
    /// enumerations outright, which is not the repair. ⛔ 2026-10-29: the first half is INVERTED —
    /// the store text describes Echoel Studio, which has no genre roster, so the release notes
    /// must not name a curated one (header). The website half is unchanged.
    func testTheSurfacesStillCarryAListAndANumber() throws {
        for path in Self.storeNotes {
            let notes = try Self.text(path).lowercased()
            XCTAssertFalse(notes.contains("curated genre") || notes.contains("kuratierte genre"), """
                \(path) names a curated genre roster, but the Echoel Studio build on this App Store \
                record has no genres (GM28; NEUPLANUNG: "no genres"). That is the earlier app's \
                release note returning to a listing that no longer describes it. If a roster ships \
                in the Studio, add this surface back to `enumerating` in the SAME commit so claims 1 \
                and 2 pin its list and its number — do not leave a roster claim unguarded.
                """)
        }
        XCTAssertTrue(try Self.text("docs/tools.html").contains("curated genres across"),
                      "`docs/tools.html` no longer enumerates the genres. The list is what a "
                      + "visitor reads; a bare number says nothing about whether their music is "
                      + "in there.")
    }

    // MARK: - parsing

    private static func statedCount(in text: String) -> (word: String, value: Int)? {
        for (word, value) in spelled where text.contains(word + " ") { return (word, value) }
        return nil
    }

    /// The display names of the OFFERED genres, read out of the source.
    ///
    /// ⛔ TWO PARSER BUGS DIED HERE AND BOTH ARE WORTH THE COMMENT, because each produced a
    /// confident wrong number:
    ///  1. Counting `.case` tokens in the `offered` array WITHOUT stripping `//` comments lands
    ///     one too high — several comments there quote a case name (`` `.folk` ``) in prose.
    ///  2. Scanning the WHOLE file for `case .x: return "Y"` resolves each genre to the LAST
    ///     such switch, which is `leadPatchName` — every genre came back as "Warm Strings" or
    ///     "Deep Sub", and every surface then read as missing all 34 names. The regex matched
    ///     something plausible, which is worse than matching nothing (§2). Scope to the
    ///     `displayName` property's own switch.
    private static func offeredDisplayNames() throws -> [String] {
        let source = try text("Sources/Echoelmusic/Sequencer/MusicStyle.swift")

        guard let arrayStart = source.range(of: "static let offered: [MusicStyle] = ["),
              let arrayEnd = source.range(of: "\n    ]", range: arrayStart.upperBound..<source.endIndex)
        else { return [] }
        var cases: [String] = []
        for rawLine in source[arrayStart.upperBound..<arrayEnd.lowerBound]
            .split(separator: "\n", omittingEmptySubsequences: false) {
            let code = rawLine.range(of: "//").map { rawLine[rawLine.startIndex..<$0.lowerBound] }
                ?? rawLine
            for piece in code.split(separator: ",") {
                let name = piece.trimmingCharacters(in: .whitespaces)
                if name.hasPrefix("."), name.count > 1 { cases.append(String(name.dropFirst())) }
            }
        }

        guard let propStart = source.range(of: "public var displayName: String {"),
              let propEnd = source.range(of: "\n    }\n", range: propStart.upperBound..<source.endIndex)
        else { return [] }
        let block = source[propStart.upperBound..<propEnd.lowerBound]
        var map: [String: String] = [:]
        for line in block.split(separator: "\n") {
            guard let dot = line.range(of: "case ."),
                  let colon = line.range(of: ":", range: dot.upperBound..<line.endIndex),
                  let openQuote = line.range(of: "\"", range: colon.upperBound..<line.endIndex),
                  let closeQuote = line.range(of: "\"", range: openQuote.upperBound..<line.endIndex)
            else { continue }
            let key = String(line[dot.upperBound..<colon.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            map[key] = String(line[openQuote.upperBound..<closeQuote.lowerBound])
        }
        return cases.compactMap { map[$0] }
    }

    private static func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
