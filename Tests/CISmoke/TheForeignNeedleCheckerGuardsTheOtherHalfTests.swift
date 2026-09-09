// TheForeignNeedleCheckerGuardsTheOtherHalfTests.swift
// Echoel — #1191: the checker for needles asserted against files that are not Swift, and the
// two properties whose quiet loss would turn it back into a green that means nothing.
//
// WHY THE TOOL EXISTS. #1190 slimmed a paragraph in `CLAUDE.md` and, in its first form,
// merged two sentences into one. Meaning identical; both literal needles of
// `TheVocalChainStopsAtTheAutotuneTests` claim 5 gone. All four rot-checkers exited 0, and
// they were right to: `dead-needles.py` gates every shape on the guard file naming ONLY
// `Sources/` paths (that gate is what keeps its false-alarm rate at zero), and
// `moved-needles.py` diffs `-- Sources` ONLY (#1182). Nothing watched the other half —
// `CLAUDE.md`, `project.yml`, `docs/*.html`, `ContentPipeline/CLAIMS.md`, `decisions.csv`,
// `fastlane/metadata/`, `Resources/iOS/Info.plist`, and `Tests/CISmoke/CLAUDE.md` itself.
//
// ⛔ WHAT THIS FILE ACTUALLY GUARDS ARE TWO REPAIRS, not the tool's existence. Both were
// found by DRIVING it, not by reading it, and both fail SILENTLY if removed:
//   1. the VACUOUS-PASS EXIT. Zero needles extracted returns 2, not 0. Without it, one wrong
//      character in a regex turns the whole checker into a permanent green — the exact
//      mechanism that made `continue-on-error` invisible for fourteen hours (`doctor`).
//   2. the GUARD'S OWN COMMENTS being blanked before assertions are extracted. Its first real
//      run reported one finding, and the finding was the CHECKER'S:
//      `TheNeedleCheckerNamesBothErrorDirectionsTests` RETRACTED an assertion and kept it
//      quoted in a `//` block explaining why (#491, recorded on purpose). Read raw, that
//      withdrawn line parses as live. A checker with false alarms is a checker nobody runs
//      (#665), so this is not cosmetic.
//
// KIND (§1): **PREVENTIVE, source-text scans.** No claim here drives Python. They pin that the
// tool is present, carries its origin and the sibling gap it fills, keeps both repairs, and
// that the directory law points a session at it. Graded honestly: none of these would have
// caught #1190 — the TOOL would have, and these keep the tool from rotting into a green.
//
// ⚠️ #364 — THIS FORBIDS NO FUTURE WORK. Widening the loader shapes, adding a fourth blind
// spot, or folding the whole thing into `dead-needles.py` are all legitimate. Claim 4 names
// what has to move with the vacuous-pass exit; claim 5 names the prose home. Replace the tool
// and this file points at the replacement in the same commit, or it goes with it.
//
// GRADING (§3), transcribed in Python against `git show HEAD:<path>` and the worktree,
// every assertion driven, not only the changed ones:
//   · 0 REGRESSIONS. Nothing here was red on the parent for the reason its name gives.
//   · 2 FORWARD guards — claim 1's `#1182` needle and claim 5's directory-law needle are red
//     on the parent because THIS commit writes both texts. Booking them as regressions would
//     be the flattering-direction defect; they are named as forward and that is all they are.
//   · 6 COUNTERWEIGHTS, green on both trees, and they are the point of the file: they are
//     what goes red the day someone removes the vacuous-pass exit or the comment blanking.
//   · 0 anchor absences.
// The file compiles against the parent (it names no new symbol), so the verdicts above are
// real verdicts, not "not gradable".
//
// ⚠️ AND THIS FILE IS ITSELF INSIDE THE TOOL'S REACH, which is deliberate: every needle below
// is asserted against a `.py` file, so `scripts/foreign-needles.py` checks its own pin. If a
// needle here stops matching, the tool says so before CI does.

import XCTest

final class TheForeignNeedleCheckerGuardsTheOtherHalfTests: XCTestCase {

    private static let checker = "scripts/foreign-needles.py"
    private static let sibling = "scripts/moved-needles.py"
    private static let dirLaw = "Tests/CISmoke/CLAUDE.md"

    private func root() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("Package.swift").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func rawFile(_ relative: String) throws -> String {
        let url = root().appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relative) not in this tree — nothing to grade (#454: a missing TREE skips).")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - 0 · the tool exists at all

    /// A guard whose every claim degrades to a skip has no failure mode (#739). `rawFile(_:)`
    /// skips on a partial checkout, which is right; one claim must treat absence as absence.
    func testTheForeignNeedleCheckerIsStillInTheRepository() {
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: root().appendingPathComponent(Self.checker).path), """
            `\(Self.checker)` is gone. It is the only thing in this repo that notices when a
            guard's literal stops matching a file that is not Swift — the #1190 class, where a
            prose edit cut two needles and all four other checkers exited 0. If it was replaced
            or folded into `dead-needles.py`, point this file and the directory law at the
            replacement in the SAME commit; if it was deleted on purpose, this test goes with
            it and #1190's lesson needs a new home.
            """)
    }

    // MARK: - 1 · it carries its origin and the sibling gap it fills

    func testTheCheckerRecordsWhyItExistsAndWhichGapItFills() throws {
        let src = try rawFile(Self.checker)
        XCTAssertTrue(src.contains("#1190"), """
            The checker lost its origin. Without "#1190" a reader cannot find the failure that
            justifies the tool, and a tool without a paid-for failure behind it is the kind
            this repo deletes.
            """)
        XCTAssertTrue(src.contains("#1182"), """
            The checker stopped citing #1182 — the measurement that `moved-needles.py` diffs
            `-- Sources` ONLY. That citation is the whole argument for a SECOND checker rather
            than a widening of an existing one. Without it the next reader sees duplication.
            """)
    }

    // MARK: - 2 · repair one: the vacuous-pass exit

    func testAnEmptyScanIsAFindingAndNotAPass() throws {
        let src = try rawFile(Self.checker)
        XCTAssertTrue(src.contains("INSTRUMENT UNAVAILABLE"), """
            The checker lost its vacuous-pass exit. Zero needles extracted must return 2, not
            0 (`.claude/rules/context.md` §2 — a parser that matches nothing is a finding,
            never a pass). Without it one wrong character in a loader regex turns the whole
            tool into a permanent green, which is the `continue-on-error` mechanism this
            repo already paid fourteen hours for. If the exit code moved, move this needle
            with it; do not delete the property.
            """)
    }

    // MARK: - 3 · repair two: the guard's own comments are blanked first

    func testARetractedAssertionInACommentIsNotAnAssertion() throws {
        let src = try rawFile(Self.checker)
        XCTAssertTrue(src.contains("strip_comments(raw)"), """
            The checker stopped comment-blanking the guard file before extracting assertions.
            That was its FIRST real finding and the finding was its own: a guard in this
            bundle retracted an assertion and kept it quoted in a `//` block explaining why
            (#491, on purpose), so a raw read parses the withdrawn line as live and reports a
            needle nobody asserts. A checker with false alarms is a checker nobody runs
            (#665). `dead-needles.py` strips the file it SEARCHES for the same reason; the
            assertion side needs it too (#456).
            """)
    }

    // MARK: - 4 · polarity is carried, not assumed

    func testBothAssertionDirectionsAreHandled() throws {
        let src = try rawFile(Self.checker)
        XCTAssertTrue(src.contains("want_present"), """
            The checker stopped carrying POLARITY. `XCTAssertFalse(x.contains(...))` demands
            ABSENCE, and this repo writes many of those deliberately — a retracted wording
            that must not come back. The hand sweep that preceded this tool ignored polarity
            and reported two findings that were not real; with the signs reversed the same
            bug waves a real break through in silence.
            """)
    }

    // MARK: - 5 · a session is pointed at it

    func testTheSiblingAndTheDirectoryLawNameTheChecker() throws {
        let moved = try rawFile(Self.sibling)
        XCTAssertTrue(moved.contains("foreign-needles.py"), """
            `\(Self.sibling)` stopped pointing at its sibling. Its own SCOPE warning is where a
            session reads that `-- Sources` is all it diffs — that is the moment the other half
            has to be named, or the gap is documented and unmanned (#456: the prose moves in
            EVERY home).
            """)
        let law = try rawFile(Self.dirLaw)
        XCTAssertTrue(law.contains("foreign-needles.py"), """
            `\(Self.dirLaw)` stopped naming the checker. It lists the three needle-rot shapes
            and their commands; a fourth tool nobody is told to run is a tool nobody runs.
            """)
    }
}
