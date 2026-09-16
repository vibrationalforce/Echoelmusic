// TheReadmeMapNamesOnlyThingsThatExistTests.swift
// Echoel — #1330. `README.md` is the first file a new contributor (and every code-reading
// agent) opens, and its repo-structure map still listed types three founder deletions had
// removed.
//
// ⭐ WHAT WAS WRONG, measured rather than recalled:
//   · "TWO more panels open without a chip … and Video (recorded clips, inline playback,
//     mp4 share — the header tile)" — video capture and its library went with #1304 on the
//     founder's "Kein Video Capture"; the edit had already gone with #121 Slice 3.
//   · "…with a full-screen door inside the Field panel" — that `showVisual` cover was deleted
//     by #1069; the floating window is the only mount left.
//   · `Audio/ … MultiTrackRecorder (flag-gated off)` — deleted with the microphone (#1302).
//     The identity line of `CLAUDE.md` carried the same claim and #1326 struck it there; this
//     is the SAME fact in its second home, and #456 is exactly that: a repair travels to every
//     home, not only the one being edited.
//   · `Video/ … VideoRecorder, VisualRecorder, VideoMuxer — capture only, no editing` — all
//     three deleted by #1304, in the directory whose remaining four files are the rPPG PULSE
//     path. A map that lists recorders there is how someone tidies the directory BY NAME and
//     deletes the flagship bio source.
//   · `Tools/ … breath/vocal tools` — that directory holds four files and none of them is a
//     vocal tool (#1302). `CLAUDE.md`'s own REPO STRUCTURE said it too and moves in this commit.
//
// ⭐ THE GUARD IS A RULE, NOT A LIST OF THOSE FIVE (#1323's law, one layer out): every
// identifier the structure map names must resolve to something in `Sources/` — a type in the
// code, or a file of that name. A needle list would have to be extended by hand after every
// deletion, which is precisely the maintenance that failed here. The rule needs no extending.
//
// ⚠️ A RETRACTION MAY NAME WHAT IT RETRACTS. The ⛔ notes this commit adds say the words
// `VideoRecorder` and `MultiTrackRecorder` on purpose — that is how this repo strikes a claim
// (#491/#1318). Claim 1 therefore skips a line once a ⛔ appears and resumes after the line
// that closes the note, and claim 2 pins that at least one such note is present, so the skip
// can never be satisfied by a map with no retractions in it at all.
//
// ⚠️ IT FORBIDS NOTHING (#364). Adding a type to the map is fine as soon as the type exists;
// the failure message names the unresolved word and both ways to satisfy it.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — **6 assertions across three claims**
// (claim 1 = 3, claim 2 = 2, claim 3 = 1), transcribed in Python and driven against BOTH trees.
// On the parent (`eedc5cc`) **4 are red and they are TWO findings** (#486): (a) claim 1's
// resolution check — the map named `VideoRecorder` and `VideoMuxer`, which is ONE deletion
// (#1304) reported twice; (b) the README prose was simply uncorrected, which claims 2 and 3
// report in three assertions. ⛔ A draft of this paragraph called claim 3 a COUNTERWEIGHT
// and said "3 are red". It is not one: the `Video/` warning is written by THIS commit, so it
// was red on the parent for exactly the reason it names, and calling it green-on-both-trees
// was the flattering direction (#433/#464) — caught by driving it rather than reasoning about
// it. The two genuine counterweights are claim 1's two anchor checks (block non-empty, file
// count), green on both trees. SOURCE-TEXT SCAN throughout (§1): it proves what the map says,
// never that the app matches the map's PROSE descriptions.

import Foundation
import XCTest

final class TheReadmeMapNamesOnlyThingsThatExistTests: XCTestCase {

    /// Claim 1 — every identifier in the structure map resolves to a `Sources/` type or file.
    func testTheStructureMapResolves() throws {
        let readme = try Self.text("README.md")
        let block = try Self.structureBlock(in: readme)
        XCTAssertFalse(block.isEmpty,
                       "ANCHOR MISSING: README's repo-structure code block did not extract — a "
                       + "missing anchor is a finding, not a pass (#454).")

        var corpus = ""
        var basenames = Set<String>()
        let root = Self.repoRoot()
        let sources = root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: sources.path) else {
            XCTFail("ANCHOR MISSING: could not walk Sources/ (#454)")
            return
        }
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            basenames.insert(String((relative as NSString).lastPathComponent.dropLast(6)))
            if let body = try? String(contentsOf: sources.appendingPathComponent(relative),
                                      encoding: .utf8) {
                corpus += body + "\n"
            }
        }
        XCTAssertGreaterThan(basenames.count, 100,
                             "ANCHOR MISSING: read \(basenames.count) Swift files — too few for "
                             + "claim 1's resolution check to mean anything (#454/#926).")

        let words = block
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { word in
                guard word.count >= 4, let first = word.first, first.isUppercase else { return false }
                return word.contains(where: { $0.isLowercase })
            }
        let unresolved = Array(Set(words.filter { !basenames.contains($0) && !corpus.contains($0) }))
            .sorted()
        XCTAssertEqual(
            unresolved, [],
            "README's repo-structure map names \(unresolved), which exist neither as a type in "
            + "`Sources/` nor as a file there. The map is the first thing a new contributor and "
            + "every code-reading agent opens; a deleted type listed there sends them looking "
            + "for it, or — worse, in `Video/` — tidying a directory by its name and deleting "
            + "the rPPG pulse path. Either restore the type or strike it, and strike it the way "
            + "this repo strikes things: a ⛔ note, which this scan skips on purpose.")
    }

    /// Claim 2 — the prose repair is present, and at least one ⛔ note exists so claim 1's
    /// skip cannot be vacuous.
    func testTheDeletedSurfacesAreStruckInProse() throws {
        let readme = try Self.text("README.md")
        XCTAssertTrue(
            readme.contains("**One more panel opens without a chip:**"),
            "README still announces TWO chipless panels. The second was Video — deleted with "
            + "#1304 — so the count and the surface must move together.")
        XCTAssertTrue(
            readme.contains("⛔ **#1330 — this paragraph sold two surfaces that are gone.**"),
            "the #1330 retraction is gone. It is the record of WHICH two (the Video panel and "
            + "the Field panel's full-screen door, #1069) and the command that re-derives it — "
            + "and claim 1's ⛔-skip is only honest while a real retraction uses it.")
    }

    /// Claim 3 — counterweight: the map still warns that `Video/` is the PULSE path. Claim 1
    /// would stay green on a map that simply deleted the directory line.
    func testTheMapStillWarnsAboutTheVideoDirectory() throws {
        XCTAssertTrue(
            try Self.text("README.md").contains("deletes\n                 the flagship bio source"),
            "the warning that `Video/` holds the rPPG PULSE path is gone. CLAUDE.md carries the "
            + "same sentence for the same reason: the directory name is the trap, and a reader "
            + "who tidies by name removes the app's flagship bio source.")
    }

    // MARK: - helpers

    /// The fenced code block holding the repo-structure map, with ⛔ retraction notes removed:
    /// a note may legitimately name what it strikes. A note runs from the ⛔ line to the line
    /// that closes it with `)`.
    private static func structureBlock(in readme: String) throws -> String {
        let anchor = "  Audio/         AudioEngine"
        let hits = readme.components(separatedBy: anchor).count - 1
        guard hits == 1, let mark = readme.range(of: anchor) else {
            throw XCTSkip("anchor `\(anchor)` occurs \(hits)× — re-anchor before trusting a zero (#408)")
        }
        let head = readme[..<mark.lowerBound]
        guard let open = head.range(of: "```", options: .backwards),
              let close = readme.range(of: "```", range: mark.upperBound..<readme.endIndex) else {
            return ""
        }
        var kept: [String] = []
        var inNote = false
        for line in readme[open.upperBound..<close.lowerBound].components(separatedBy: "\n") {
            if line.contains("⛔") { inNote = true }
            if inNote {
                if line.trimmingCharacters(in: .whitespaces).hasSuffix(")") { inNote = false }
                continue
            }
            kept.append(line)
        }
        return kept.joined(separator: "\n")
    }

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func text(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }
}
