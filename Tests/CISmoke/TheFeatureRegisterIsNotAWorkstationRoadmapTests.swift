// TheFeatureRegisterIsNotAWorkstationRoadmapTests.swift
// Echoel — #1343. `docs/dev/FEATURE_MATRIX.md` calls itself "Truth-source for status: this file
// + the code. If the website disagrees, the code wins." It was carrying, as live text:
//   · a 2026-07-13 block describing "ONE tracks-centric, bio-reactive DAW" with a numbered
//     backlog (B03 · B07 · B08 · B11 · B13–B16 · B18–B20 · B23–B26 · B29 · B30) — the
//     workstation half the founder CUT (`PRODUCT_DEFINITION.md`'s BOUNDARY; #121 Slices 2–4,
//     #166/#167, #1302, #1304 executed it);
//   · a bullet naming the Clips/Arrangement UI **"the open gap (#1)"** — the single most
//     explicitly cut surface in this repo, ranked as the register's top open item;
//   · TWO TestFlight acceptance criteria that cannot pass on a device (`BeatTab`, which was
//     never built at all, plus pads/samples deleted by #166/#167; and "record work", deleted
//     by #1304 — two lines below the file's own ⛔ saying there is no recording);
//   · the genre count, twice, stale by 14 in both places.
//
// ⭐ WHY THIS IS THE EXPENSIVE KIND, and it is the same law three slices in a row have paid
// for: a register fails in BOTH directions, and the false PRESENT TENSE is worse than the
// absence. An absence is found by whoever goes looking for the feature. A line that says
// "open gap (#1)" is READ AS A PRIORITY, and a session working the backlog rebuilds exactly
// what the founder removed twice. An acceptance criterion that cannot pass is worse still:
// it spends a DEVICE session — the scarcest thing this project has, since both remaining
// ship-gate checks are sensory — reporting a failure against a yardstick that was withdrawn.
//
// ⭐ THE SHARPEST SINGLE FINDING was not a stale number, it was a stale PAIR: the line said
// "the enum holds 36 cases, so **17** are not offered". Today the tool prints 50 genres and
// 33 offered — and 50 − 33 is ALSO 17. The DIFFERENCE stayed correct while BOTH operands were
// out by 14, so the one figure a checker would eyeball as confirmation was the one that held.
// That is `.claude/rules/context.md` §2 ("two counts that agree are not a set comparison")
// arriving from a direction that rule had not yet been bitten from.
//
// ⚠️ SCOPE, STATED BECAUSE IT IS A REAL BLINDNESS (#1338). Claims 3 and 4 use BULLET scope and
// require the strike marker to come BEFORE the name — the two-part law #1341 paid for. That
// means they do NOT cover the four dead names inside the 2026-07-13 blockquote
// (`VideoResyncPolicy`, `VideoExportPlan`, `VideoLanePlayer`, `MultiTrackRecorder`): those sit
// in sibling bullets, and the ⛔ this commit writes is at the BLOCK head. Widening the scope to
// "the enclosing blockquote" would excuse every future dead name added anywhere inside it —
// the exact defect #1341 measured. So the block head is prose-only, deliberately, and this
// guard says so rather than pretending to cover it.
//
// ⚠️ HONEST GRADING (§0). No local Swift toolchain — **12 assertions across five claims**
// (claim 1 = 2, claim 2 = 2, claim 3 = 2, claim 4 = 2, claim 5 = 4), transcribed in Python and
// driven against BOTH trees. The count is stated from the transcription's own tally, not from
// reading the file — the #1334/#1340 defect was a header describing its own subject wrongly.
// On the parent (`9c431ed`) **9 are red, and they are NOT nine findings** — booking them all
// as regressions is the flattering direction (#433/#464):
//   · **4 = FOUR GENUINE REGRESSIONS, four distinct absences** (so #486 does not collapse
//     them): the nineteen-name second copy of `MusicStyle.offered`; `BeatTab` unstruck;
//     `fullscreen + record work` unstruck; `LaunchQuantizer` unstruck. Each is a different
//     thing the register claimed, so each is its own finding.
//   · **5 = FORWARD guards** naming prose THIS commit writes (`genre-prebatch.py`, the
//     `50−33` pair, the pointer at the founder decision, the `B23–B26` block head, the
//     window-size note). They are worth having — a retraction quietly swapped back out is
//     exactly what this file is about — but they prove NOTHING about the parent.
// The remaining **3 are green on both trees**: the anchor, plus two counterweights
// (`Truth-source for status`, `RPPGConditioning`). Those are the point of the file: without
// them every claim above passes on a tree that simply deleted the register.
// SOURCE-TEXT SCAN (§1): this is a markdown register; there is no symbol to call, so nothing
// here needs `@testable` (#1337).

import Foundation
import XCTest

final class TheFeatureRegisterIsNotAWorkstationRoadmapTests: XCTestCase {

    private static let matrix = "docs/dev/FEATURE_MATRIX.md"

    /// Claim 1 — no second copy of `MusicStyle.offered`. The register enumerated nineteen
    /// display names on one line; the array had already moved on twice.
    func testTheRegisterDoesNotEnumerateTheOfferedGenres() throws {
        let text = try Self.text(Self.matrix)
        XCTAssertFalse(text.isEmpty, "ANCHOR MISSING: could not read \(Self.matrix) (#454).")
        // Display names that were in the transcribed list and are stable strings.
        let names = ["Self-Observation", "Deep Ambient", "Drift", "Contemplation", "Vaporwave",
                     "Sci-Fi", "Classical", "Dub Techno", "Acid Techno", "Deep House",
                     "Uplifting Trance", "Tech House", "Minimal Techno", "Detroit Techno",
                     "Deep Tech", "Dark Minimal", "Psy Prog House", "Still Drone",
                     "Ambient Pulse"]
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let hits = names.filter { line.contains($0) }.count
            XCTAssertLessThan(
                hits, 6,
                "a line of the feature register lists \(hits) genre display names. That is a "
                + "SECOND COPY of `MusicStyle.offered` (#416), and the first one drifted by "
                + "fourteen before anyone noticed — while seven user-facing surfaces stayed "
                + "current because `WebsitePagesAreFindableAndHonestTests` holds them. Name the "
                + "measurement instead: `python3 scripts/genre-prebatch.py <empty.json>`.")
        }
    }

    /// Claim 2 — the register names the command that measures the genre count, rather than a
    /// literal. #818: delete the rotted number, ship the command.
    func testTheGenreCountIsACommandNotALiteral() throws {
        let text = try Self.text(Self.matrix)
        XCTAssertTrue(
            text.contains("scripts/genre-prebatch.py"),
            "the register no longer names the tool that measures the genre count. A literal "
            + "here is a date, not a fact (#818) — it was `19` while the tree said `33`.")
        XCTAssertTrue(
            text.contains("50−33"),
            "the retraction that records the stale PAIR is gone. The point is not the old "
            + "number: it is that `36−19` and `50−33` are both 17, so the difference a "
            + "reviewer eyeballs as confirmation was the only figure that held while both "
            + "operands were out by fourteen (`.claude/rules/context.md` §2).")
    }

    /// Claim 3 — `BeatTab` may only appear in a bullet whose strike marker comes FIRST. It was
    /// a TestFlight acceptance criterion for a tab that was never built.
    func testTheUnpassableAcceptanceCriteriaAreStruck() throws {
        let text = try Self.text(Self.matrix)
        for (offset, bullet) in Self.bullets(in: text) where bullet.contains("`BeatTab`") {
            _ = offset
            guard let strike = bullet.range(of: "⛔"),
                  let name = bullet.range(of: "`BeatTab`"),
                  strike.lowerBound < name.lowerBound else {
                XCTFail(
                    "`BeatTab` is claimed in the feature register without a strike marker ahead "
                    + "of it. It was never built (the `StudioRoot` TabView plan is recorded in "
                    + "`CLAUDE.md` as never implemented) and the pads and sample library it "
                    + "names went with #166/#167. An acceptance criterion that CANNOT pass "
                    + "spends a device session — the scarcest thing this project has — "
                    + "reporting a failure against a withdrawn yardstick.")
                return
            }
        }
        XCTAssertFalse(
            text.contains("fullscreen + record work"),
            "the SECOND unpassable acceptance criterion is back. `record work` stood in the "
            + "EchoelVis acceptance line two lines BELOW the file's own ⛔ saying there is no "
            + "recording (#1304) — a register that undoes its own marker two lines later. "
            + "⚠️ Strike `record`, not `fullscreen`: the floating window's `fullscreen` SIZE "
            + "survives; what #1069 deleted was the separate fullscreen chrome.")
    }

    /// Claim 4 — same rule for `LaunchQuantizer`, the type that made the cut Clips/Arrangement
    /// UI read as the register's number-one open item.
    func testTheCutArrangementUIIsNotTheOpenGap() throws {
        let text = try Self.text(Self.matrix)
        for (_, bullet) in Self.bullets(in: text) where bullet.contains("`LaunchQuantizer`") {
            guard let strike = bullet.range(of: "⛔"),
                  let name = bullet.range(of: "`LaunchQuantizer`"),
                  strike.lowerBound < name.lowerBound else {
                XCTFail(
                    "`LaunchQuantizer` is claimed in the feature register without a strike "
                    + "marker ahead of it. The type does not exist (`git grep -c \"enum "
                    + "LaunchQuantizer\\|struct LaunchQuantizer\" -- Sources` → 0) and the "
                    + "bullet that named it called the Clips/Arrangement UI \"the open gap "
                    + "(#1)\" — the most explicitly cut surface in this repo, ranked first.")
                return
            }
        }
        XCTAssertTrue(
            text.contains("Editor ≠ Workstation") || text.contains("GRENZE"),
            "the retraction no longer points at the decision that cut the workstation half. "
            + "Without that pointer the strike reads as an opinion, and the next session "
            + "re-litigates it instead of reading `PRODUCT_DEFINITION.md`.")
    }

    /// Claim 5 — counterweights. Without these, claims 1–4 are green on a tree that simply
    /// deleted the register, or that deleted the surviving things along with the dead ones.
    func testTheRegisterStillSaysWhatItIsAndWhatSurvived() throws {
        let text = try Self.text(Self.matrix)
        XCTAssertTrue(
            text.contains("Truth-source for status"),
            "the register no longer declares itself the truth source. That sentence is why its "
            + "false present tense was expensive — removing it is not the repair.")
        XCTAssertTrue(
            text.contains("`RPPGConditioning`"),
            "the 2026-07-13 block's SURVIVING core is gone from the register. `RPPGConditioning` "
            + "is the live rPPG path today — the reason that block gets a marker rather than a "
            + "deletion is that parts of it are still true.")
        XCTAssertTrue(
            text.contains("B23–B26"),
            "the 2026-07-13 block head lost its retraction. That block is the only place the "
            + "cut B-series backlog is still written down, and a numbered backlog reads as an "
            + "order. ⚠️ This assertion is the ONLY thing holding it: claims 3 and 4 use "
            + "BULLET scope, so the four dead names inside that block "
            + "(`VideoResyncPolicy`, `VideoExportPlan`, `VideoLanePlayer`, `MultiTrackRecorder`) "
            + "are NOT covered — widening scope to the blockquote would excuse every dead name "
            + "added inside it later, which is the defect #1341 measured.")
        XCTAssertTrue(
            text.contains("FloatingVisualWindow.WindowSize"),
            "the note that `fullscreen` survives as a WINDOW SIZE is gone. #1069 deleted the "
            + "SECOND, separate fullscreen chrome and the VJ overlay, not the floating window's "
            + "own `fullscreen` case — a careless repair strikes a surface that exists.")
    }

    // MARK: - markdown scope (#1341): the unit is the BULLET, never the blank-line paragraph

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
