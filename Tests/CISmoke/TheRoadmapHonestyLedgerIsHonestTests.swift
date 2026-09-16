// TheRoadmapHonestyLedgerIsHonestTests.swift
// Echoel — #1344. `docs/dev/ROADMAP.md` calls itself "the single source of truth for *how we
// get there*" and carries a section literally headed "Honesty ledger (review every session)".
// Four things in it were not true:
//
//   1. **NOW item 1** — "Push a TestFlight build … *(DoD step; do before adding more.)*" The
//      freeze it assumed was lifted 2026-07-17/07-31 and every green round ships since
//      (v10.79.472 is the latest `.deploy/release` commit). Worse than stale: the parenthetical
//      makes it a GATE on all further work, at position 1 of the list a planning session reads
//      first. A finished item still phrased as a blocker costs more than a missing one.
//   2. **"Bus `bioFrames`/`bioEvents` reserved but undrained"** — `bioEvents` HAS a consumer.
//      `EngineBus.swift` says so in its own words: "the SOLE consumer
//      (`OSCSender.drainAndSendEvents`)". Only `bioFrames` is undrained.
//   3. **"Xcode/Tuist-only build errors … `Project.swift` issues"** — this repo does not use
//      Tuist; the generator is XcodeGen and its manifest is `project.yml`. And `Project.swift`
//      is a LIVE Echoel file (`Sources/Echoelmusic/Core/Project.swift`), so following the note
//      opens a real file with nothing to do with the build system — the `BioModulation` trap
//      from `CLAUDE.md`, where the obvious reach lands on a same-named neighbour.
//   4. **"the rule stays: it is what keeps the DSP layer portable"** — `.claude/rules/
//      swift-audio.md`, which is ALWAYS LOADED, says the opposite in as many words: "Reason =
//      hygiene + one-way dependency, **not** portability and **not** AUv3", and forbids writing
//      "Linux-testable" with a counter-example. The rule itself is right; a planning register
//      that gives an always-loaded rule a DIFFERENT reason is the more dangerous half, because
//      whoever obeys it for the wrong reason applies it in the wrong place.
//
// ⭐ FINDING 2 IS THE ONE WORTH THE FILE, and it is not about the bus. The identical false
// sentence was corrected on 2026-08-28 "in drei Dateien zugleich" — `CLAUDE.md` records that
// verbatim — and the one home the repair did not reach was the list whose own heading says
// "review every session". **#456 says a repair travels to EVERY home; this is #456 failing on
// its own correction.** The durable rule: MEASURE which homes a sentence has (`git grep` the
// distinctive phrase across the repo, not just the files you happen to be editing) — do not
// remember them.
//
// ⚠️ THIS GUARD FORBIDS NOTHING THAT IS TRUE (#364). If `bioFrames` ever gets a consumer, or a
// TestFlight gate is deliberately reinstated, claim 1/2 goes red and its message names the
// prose to move in the same commit.
//
// ⚠️ HONEST GRADING (§0). No local Swift toolchain — **10 assertions across three claims**
// (claim 1 = 5, claim 2 = 3, claim 3 = 2), transcribed in Python and driven against BOTH trees.
// ⚠️ Claim 1's five are the anchor plus ONE PER FORBIDDEN PHRASE, driven by a loop over four
// cases — in Swift that is two statements, not five. The count here is the transcription's own
// tally of ASSERTIONS MADE, because a statement count would understate what goes red (#1334).
// On the parent (`a578342`) **7 are red, and they are FOUR findings, not seven** (#486/#433):
// each of the four defects above contributes one regression assertion, and three further
// assertions are FORWARD guards naming prose this commit writes. The remaining **2 are green
// on both trees** — counterweights, without which claim 1 passes on a tree that deleted the
// ledger or the NOW list outright.
// ⛔ **THE FIRST DRAFT OF CLAIM 1 WAS RED ON ITS OWN TREE, and the reason is worth more than
// the fix.** It scanned for the four phrases with a bare `XCTAssertFalse(text.contains(...))`
// — and the repairs in this very commit QUOTE the retracted wording verbatim, which is how
// this repo strikes a claim. So the guard hit its own retraction: the #491 trap, from the
// inside. The session's own law („a guard green on the tree it was written to catch is worth
// less than none”) has a mirror image: **a guard red on the tree it was written FOR is the
// same design error, and only the §0 transcription against BOTH trees shows either.** The
// repair is not weaker prose — it is bullet scope with a position comparison, the mechanism
// #1341 already paid for.
// SOURCE-TEXT SCAN (§1): markdown registers plus one Swift file read as text; no symbol is
// called, so nothing here needs `@testable` (#1337).

import Foundation
import XCTest

final class TheRoadmapHonestyLedgerIsHonestTests: XCTestCase {

    private static let roadmap = "docs/dev/ROADMAP.md"
    private static let bus = "Sources/Echoelmusic/Core/EngineBus.swift"

    /// Claim 1 — none of the four false statements stands UNSTRUCK. Bullet scope with a
    /// position comparison (#1341): the marker must come before the phrase, and a bullet is the
    /// unit — never the blank-line paragraph.
    func testTheLedgerNoLongerCarriesTheFourFalseStatementsUnstruck() throws {
        let text = try Self.text(Self.roadmap)
        XCTAssertFalse(text.isEmpty, "ANCHOR MISSING: could not read \(Self.roadmap) (#454).")

        let cases: [(phrase: String, why: String)] = [
            ("reserved but undrained",
             "`bioEvents` HAS a sole consumer, `OSCSender.drainAndSendEvents`, and "
             + "`EngineBus.swift` says so itself \u{2014} only `bioFrames` is reserved. This exact "
             + "sentence was corrected in THREE files on 2026-08-28 and this ledger, whose own "
             + "heading says \"review every session\", was the home the repair missed (#456)."),
            ("Tuist",
             "this repo does not use Tuist; the generator is XcodeGen and its manifest is "
             + "`project.yml`. The old wording also said \"`Project.swift` issues\", and that is "
             + "a LIVE Echoel file under `Core/` \u{2014} the note sent readers to the wrong file."),
            ("keeps the DSP layer portable",
             "`.claude/rules/swift-audio.md` is ALWAYS LOADED and says the reason is hygiene "
             + "plus a one-way dependency, explicitly NOT portability, with `EchoelWSOLA.swift` "
             + "as the counter-example. One decision, one definition (#416)."),
            ("do before adding more",
             "the TestFlight freeze was lifted 2026-07-17/07-31 and every green round ships "
             + "(`git log --oneline -- .deploy/release`). A finished item phrased as a blocker, "
             + "at position 1 of the list a planning session reads first, costs more than a "
             + "missing one."),
        ]

        for item in cases {
            for (_, bullet) in Self.bullets(in: text) where bullet.contains(item.phrase) {
                guard let strike = bullet.range(of: "\u{26D4}"),
                      let phrase = bullet.range(of: item.phrase),
                      strike.lowerBound < phrase.lowerBound else {
                    XCTFail(
                        "\"\(item.phrase)\" stands in `\(Self.roadmap)` with no strike marker "
                        + "ahead of it in the same bullet. " + item.why
                        + " If the claim became TRUE again, that is legal (#364): move this "
                        + "guard and the prose it names in the SAME commit.")
                    return
                }
            }
        }
    }

    /// Claim 2 — the retractions are recorded, not silently swapped. The point of this repo's
    /// marker discipline: a quietly corrected register teaches nothing.
    func testTheRetractionsAreRecorded() throws {
        let text = try Self.text(Self.roadmap)
        XCTAssertTrue(
            text.contains("VIERTE Zuhause"),
            "the #456 retraction is gone. The finding is not the bus fact — it is that the same "
            + "sentence was fixed in three files and missed the one headed \"review every "
            + "session\".")
        XCTAssertTrue(
            text.contains("`project.yml`"),
            "the ledger no longer names the real manifest. Striking `Project.swift` without "
            + "naming `project.yml` leaves a reader with no file to open.")
        XCTAssertTrue(
            text.contains(".deploy/release"),
            "the retraction of NOW item 1 no longer carries the command that shows the item is "
            + "done. A struck item without its evidence is re-litigated on the next read.")
    }

    /// Claim 3 — counterweights. Without these, claim 1 is green on a tree that deleted the
    /// ledger, or on one where the bus really did lose its consumer and nobody said so.
    func testTheLedgerAndTheConsumerBothStillExist() throws {
        let roadmapText = try Self.text(Self.roadmap)
        XCTAssertTrue(
            roadmapText.contains("Honesty ledger"),
            "the honesty ledger section is gone. Deleting it is not the repair — the section is "
            + "the only place the known structural gaps are written down.")
        let busText = try Self.text(Self.bus)
        XCTAssertTrue(
            busText.contains("OSCSender.drainAndSendEvents"),
            "`EngineBus` no longer names `OSCSender.drainAndSendEvents` as `bioEvents`' sole "
            + "consumer. That sentence is the EVIDENCE for the ledger repair above; if the "
            + "consumer really went away, the ledger's old wording becomes true again and both "
            + "it and `CLAUDE.md`'s architecture line must move in the same commit (#364).")
    }

    // MARK: - markdown scope (#1341): the unit is the BULLET, never the blank-line paragraph.
    // ⚠️ Granularity stated on purpose: ONE marker excuses everything after it IN THAT BULLET.
    // Two of the four phrases above live in the same long "CI verification gap" bullet, so one
    // ⛔ covers both — correct here (one author, one edit), and the known limit of this scope.
    // Widening to the paragraph is what made the #1341 draft green on its own defect.

    private static func bullets(in text: String) -> [(String.Index, String)] {
        var out: [(String.Index, String)] = []
        var start = text.startIndex
        var idx = text.startIndex
        func flush(_ end: String.Index) {
            let piece = String(text[start..<end])
            if !piece.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                out.append((start, piece))
            }
        }
        while idx < text.endIndex {
            let lineEnd = text[idx...].firstIndex(of: "\n") ?? text.endIndex
            let line = text[idx..<lineEnd]
            let bare = line.drop(while: { $0 == ">" || $0 == " " || $0 == "\t" })
            let starts = bare.hasPrefix("- ") || bare.hasPrefix("* ") || bare.hasPrefix("+ ")
                || bare.hasPrefix("#") || bare.first.map { $0.isNumber } == true
                || bare.isEmpty
            if starts && idx > start {
                flush(idx)
                start = idx
            }
            idx = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
        }
        flush(text.endIndex)
        return out
    }

    private static func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
