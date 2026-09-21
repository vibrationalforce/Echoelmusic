// TheAutoMergeWaitsForTheGatesTests.swift
// Echoel — #1405. Blocking bundle, because the other suite cannot fail a merge (#208).
//
// ⭐ THIS FILE REPLACES TheAutoMergeWaitsForNoGateTests, AND THE RENAME IS THE POINT (#374).
// (The dead name carries no backticks on purpose — #1311: a tombstone in quote form reads as a
// live pointer to the next person, and to the scan that resolves quoted guard names.)
// That file recorded the opposite state: `auto-merge-claude.yml` decided what reached `main`
// and waited for nothing — no `needs:`, no `workflow_run:`, no conclusion read anywhere, so
// the compile check, the pipeline and the merge ran in PARALLEL and the merge won. Founder
// 2026-09-21: *„auto-merge-claude.yml du hast das alles unter Kontrolle und machste das
// klar."* #1405 built the gate, so a guard still NAMED for the absence would be a lying name
// on the one file whose job is to keep this honest.
//
// ⛔ THE OLD FILE PREDICTED THIS COMMIT AND SAID WHAT IT OWED. Its claim 2 message read:
// *"If that is the founder's repair, this claim has done its job — delete it, and correct the
// CI section of CLAUDE.md in the SAME commit (#456): it currently states that the merge waits
// for nothing."* Both happened here. A `#364` guard that refuses to forbid the correct future
// change, and instead tells that change what it owes, is the pattern — recorded because it was
// cheap and it paid.
//
// WHAT IS NOW PINNED, and why each claim is not the obvious one:
//  1. the anchor (without it every needle below is vacuous, #454)
//  2. the gate reads the compile check by CONCLUSION and the pipeline by one STEP. ⚠️ The step
//     half is the load-bearing one: #396 makes the pipeline's own conclusion `failure` on EVERY
//     push, so a `needs:` or `workflow_run:` on it would block every merge forever. Anyone
//     "simplifying" this poll into a dependency breaks the merge completely, and this claim is
//     what says so at the moment they try.
//  3. absence is REFUSED. The failure mode of a poll is a gate that never runs; if that ever
//     reads as green, the whole repair is decorative.
//  4. the escape hatch stays NARROW. It exists because a push touching only some other workflow
//     starts neither gate — but a widened path list would quietly restore the old behaviour for
//     everything it covers.
//  5. it still pushes straight to `main`, and those pushes are now serialised.
//  6. the counterweight (#343): an ungated merge still could not have shipped, because the
//     TestFlight dispatch is `if: false`. Delete claim 6 and the severity of the whole story
//     changes — which is exactly why it is pinned next to the others.
//  7. the register says the true thing now.
//
// ⚠️ WHY THIS FILE READS ITS TARGET RAW. `SourceText.codeOnly` is a SWIFT stripper: in YAML the
// comment character is `#`, and `//` appears inside URLs, so running it here would mangle the
// file rather than clean it. Adding a YAML stripper would break the one-stripper rule (#453).
// Instead the needles are chosen so a `#`-comment mention cannot satisfy them: the structural
// ones are LINE-ANCHORED, and the rest are shell fragments that only appear in the script.
// ⚠️ The header of the workflow now DOES discuss `needs:` and `workflow_run:` in prose, which is
// precisely why claim 2 asserts what the gate DOES rather than what it does not — a negative
// scan for those two words would be red on its own correct tree.
//
// ⚠️ HONEST LIMITS. This proves what the workflow SAYS, never what GitHub does with it. Branch
// protection lives in repository settings, not in the tree. And a YAML file that parses is not a
// workflow that runs: the poll's jq, its grace period and its refusal path are exercised for the
// first time by the next push, not by this bundle.
//
// ⭐ GRADING (§3). Needles transcribed in Python against both trees. Claims 2, 3, 4 and 7 are
// REGRESSION-SHAPED: red at the parent, because the parent has no gate and CLAUDE.md there says
// so. Claims 1, 5 and 6 are COUNTERWEIGHTS — green on both, and they are what keeps the repair
// from being read as "the merge got safer in every way".

import Foundation
import XCTest
@testable import Echoelmusic

final class TheAutoMergeWaitsForTheGatesTests: XCTestCase {

    private static let workflow = ".github/workflows/auto-merge-claude.yml"

    // MARK: - 1: the anchor — what this workflow is and when it fires

    /// Without this, every claim below is vacuous (#454): a renamed or deleted workflow would
    /// make "contains the gate" fail loudly, but "refuses absence" trivially unprovable.
    func testTheWorkflowExistsAndFiresOnEveryBranchPush() throws {
        let yml = try rawFile(Self.workflow)
        XCTAssertTrue(yml.contains("name: Auto-Merge Claude Branch"), """
            The auto-merge workflow is gone or renamed. Everything else in this file is a \
            statement about it; re-anchor rather than letting the claims pass empty.
            """)
        XCTAssertNotNil(yml.range(of: #"(?m)^\s*-\s*'claude/\*\*'"#, options: .regularExpression), """
            The workflow no longer fires on `claude/**` pushes. If the trigger moved, every \
            claim here about what happens on a work-branch push needs re-measuring.
            """)
    }

    // MARK: - 2: THE GATE — conclusion for one, a STEP for the other

    /// ⭐ THE REPAIR. `Xcode Compile Check` is read by its conclusion; `Echoelmusic CI/CD
    /// Pipeline` is read by the conclusion of ONE STEP, `Build for Testing`.
    ///
    /// ⚠️ THE SECOND HALF IS NOT A STYLE CHOICE AND MUST NOT BE "SIMPLIFIED". #396 makes that
    /// pipeline report `failure` on every push, so its run conclusion carries no information;
    /// a `needs:` or a `workflow_run:` gate on it would block every merge forever. A step
    /// conclusion is not reachable from `needs:` — it has to be polled. This claim is what
    /// stands in the way of the tidier-looking version that does not work.
    func testTheMergeReadsBothGatesBeforeItMerges() throws {
        let yml = try rawFile(Self.workflow)
        XCTAssertTrue(yml.contains("\"Xcode Compile Check\""), """
            The gate no longer names `Xcode Compile Check`. That is the one workflow whose \
            CONCLUSION is honest here — it builds Sources/ alone. Without it a commit that \
            does not compile reaches `main` again, which is the #683 finding this file records.
            """)
        XCTAssertTrue(yml.contains("\"Build for Testing\""), """
            The gate no longer reads the `Build for Testing` STEP. Reading the CI/CD run's own \
            conclusion instead cannot work: #396 makes it `failure` on every push, so the merge \
            would never happen. If this was replaced by a `needs:`/`workflow_run:` dependency, \
            that is the same mistake wearing a tidier shape — re-read the header of the \
            workflow, which explains it at the gate itself.
            """)
        XCTAssertTrue(yml.contains("compile_check=") && yml.contains("build_for_testing="), """
            The gate stopped reporting its two verdicts as step outputs. They are what the job \
            Summary prints, and a gate whose answer is invisible is the `continue-on-error` \
            defect one level up: nobody reads a log nobody is pointed at.
            """)
        XCTAssertTrue(yml.contains("REFUSING TO MERGE"), """
            The refusal message is gone. A gate that computes a verdict and merges anyway is \
            worse than no gate, because the Summary then says a green thing about a red commit.
            """)
    }

    // MARK: - 3: absence is refused, never assumed green

    /// ⚠️ THE FAILURE MODE OF A POLL. A `needs:` cannot be satisfied by a workflow that never
    /// ran; a poll can — it just keeps looking and then has to decide. The decision is REFUSE.
    func testAGateThatNeverRanIsRefusedAndNotAssumedGreen() throws {
        let yml = try rawFile(Self.workflow)
        XCTAssertTrue(yml.contains("never-ran"), """
            The `never-ran` verdict is gone. It is what the poll writes when a gate produced no \
            run at all after the grace period — a path filter kept it out, or it was never \
            queued. If absence now falls through to the merge, an unverified commit reaches \
            `main` exactly as it did before #1405, and the Summary will say the gate was green.
            """)
        XCTAssertTrue(yml.contains(#"[ "$compile" = "success" ] && [ "$testbuild" = "success" ]"#), """
            The success condition is no longer an explicit equality on BOTH verdicts. Written \
            as a negation (`!= "failure"`) it would pass `never-ran`, `timeout`, `cancelled` \
            and `skipped` — every way a gate can fail to say anything. Absence must be refused, \
            and only the positive form does that.
            """)
    }

    // MARK: - 4: the escape hatch exists, and stays narrow

    /// It is there because a push touching only some OTHER workflow triggers this merge and
    /// neither gate — waiting for a run that can never start would deadlock exactly the commits
    /// that repair CI. That is a real hole, and widening it is how the repair gets undone.
    func testTheGateIsSkippedOnlyWhereNoGateCouldHaveRun() throws {
        let yml = try rawFile(Self.workflow)
        XCTAssertTrue(yml.contains("touches_code"), """
            The scope step is gone. Either the gate now waits for runs that can never start \
            (a workflow-only commit deadlocks for 45 minutes and then fails), or the skip \
            became unconditional. Both are worse than the state this claim describes.
            """)
        XCTAssertTrue(yml.contains(#"^(Sources/|Tests/|Package\.swift$|project\.yml$)"#), """
            The path list that decides "this merge changes code" was edited. It must stay the \
            set both gate workflows actually cover; anything added to it is a path that merges \
            WITHOUT verification, which is the #683 behaviour restored for that path. If a gate \
            workflow's own filters changed, change this list to match them — and say so in \
            CLAUDE.md's CI section in the same commit (#456).
            """)
    }

    // MARK: - 5: still a direct push, and now a serialised one

    /// A PR would put the checks in the way without any of the above. There is still no PR —
    /// stated plainly so nobody reads the gate as "we moved to pull requests".
    func testItStillPushesDirectlyToMainAndSerialisesThosePushes() throws {
        let yml = try rawFile(Self.workflow)
        XCTAssertTrue(yml.contains("git push origin main"), """
            The direct push to `main` is gone. If this became a pull request, the checks now \
            stand in the way by themselves and most of this file is redundant — say so in \
            CLAUDE.md's CI section in the same commit.
            """)
        XCTAssertNil(yml.range(of: #"(?m)^\s*-\s*uses:.*create-pull-request"#,
                               options: .regularExpression),
                     "A PR action appeared — see the message above.")
        XCTAssertTrue(yml.contains("group: auto-merge-main"), """
            The concurrency group is gone. It was not needed while this job took seconds; the \
            gate can now hold it for 45 minutes, so two pushes minutes apart would keep two \
            merge jobs open against the same branch and race each other onto `main`.
            """)
    }

    // MARK: - 6: the counterweight — an ungated merge still did not ship

    /// ⚠️ THIS IS WHAT KEEPS THE WHOLE STORY PROPORTIONATE. Remove the `if: false` and an
    /// unverified commit would go from "on main" to "on a tester's phone".
    func testTheMergeDoesNotDispatchTestFlight() throws {
        let yml = try rawFile(Self.workflow)
        XCTAssertTrue(yml.contains("workflow_id: 'testflight.yml'"), """
            The TestFlight dispatch step is gone entirely. That is fine for shipping — but the \
            counterweight now rests on absence rather than on a visible `if: false`, so re-word \
            the severity note at the top of this file.
            """)
        XCTAssertTrue(yml.contains("if: false"), """
            THE DISPATCH IS LIVE AGAIN. Every commit that passes the gate above would now go \
            straight to TestFlight, and every commit that FAILS it would stop being a \
            developer-only problem. Raise it with the founder before the next push.
            """)
    }

    // MARK: - 7: the register says the true thing

    /// The reason the old file existed at all: a workflow that decides what reaches `main`
    /// belongs in the table a session reads to learn what runs here. Now it also has to say
    /// the RIGHT thing about it.
    func testTheActiveWorkflowsTableDescribesTheGate() throws {
        let claude = try rawFile("CLAUDE.md")
        XCTAssertTrue(claude.contains("`auto-merge-claude.yml`"), """
            CLAUDE.md's Active Workflows table no longer names the workflow that decides what \
            reaches `main`. That omission is what the predecessor of this file was written for.
            """)
        XCTAssertTrue(claude.contains("Xcode Compile Check"),
                      "The CI section moved — re-anchor this claim rather than deleting it.")
        XCTAssertFalse(claude.contains("wartet auf KEIN Gate"), """
            CLAUDE.md still states that the merge waits for no gate. Since #1405 it waits for \
            two. If the gate was REMOVED, this is the correct order of repair and claims 2–4 \
            above are red too; if they are green, the prose has drifted from the workflow and \
            the prose is what is wrong (#456).
            """)
        XCTAssertTrue(claude.contains("WARTET SEIT #1405 AUF ZWEI GATES"), """
            The sentence recording that the merge now waits for both gates is gone from \
            CLAUDE.md. A session reads that paragraph before it reasons about what reaches \
            `main`; without it, the next audit re-derives the old finding from scratch.
            """)
    }

    // MARK: - raw file access (see the ⚠️ note in the header: NO Swift stripper here)

    private struct DiagAnchorMissing: Error { let reason: String }

    private func rawFile(_ relativePath: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw DiagAnchorMissing(reason: """
                \(relativePath) is missing while the tree is present — it was renamed or moved. \
                Re-anchor this scan; do not let it skip (#454).
                """)
        }
        return try String(contentsOf: path, encoding: .utf8)
    }
}
