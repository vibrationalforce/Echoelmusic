// TheBlockingBundleKnowsWhatItCompilesTests.swift
// Echoel — #1422. Which files the merge gate actually compiles, pinned instead of remembered.
//
// THE FACT. `project.yml`'s blocking `EchoelmusicTests` target sources `Tests/CISmoke` and
// nothing else; the `Echoelmusic` scheme — the one CI/CD's step 9 `Build for Testing` builds —
// tests that target alone. `Tests/EchoelmusicTests` lives in a SEPARATE target
// (`EchoelmusicFullTests`) behind the non-blocking `full-tests.yml`. So **no blocking gate
// compiles `Tests/EchoelmusicTests`.**
//
// ⚠️ THIS IS NOT A NEW DISCOVERY AND THIS FILE DOES NOT CLAIM TO BE ONE — a large minority of
// the files in this directory already say it in prose ("the suite no gate compiles", "runs
// only under `full-tests.yml`", "#208"). **No count is written here on purpose** (#818: a
// number in a comment is a date, and this one moves every time a guard is written);
// `filesDependingOnTheFact()` below computes it, and claim 1 prints it at the moment it
// becomes relevant. What is new is that NOTHING MAKES THE FACT FAIL. It is load-bearing, held
// in many comments and zero assertions, and `project.yml`'s own comment announces the change
// that would falsify every one of them at once: *"SLICE 2 repoints `sources` at
// Tests/EchoelmusicTests."*
//
// ⭐ WHY IT IS LOAD-BEARING, with the case that produced this file. #1421 needed to fold three
// ADM-OSC leaves into one packed message. The obvious shape — widen `admMessages`'s return
// type from `[(String, Float)]` to `[(String, [Float])]` — would have broken about fifteen
// call sites, ALL of them in `Tests/EchoelmusicTests`, and **both gates would have gone
// green.** The slice was designed additively BECAUSE this fact was measured first. A session
// that does not know it will reach for the obvious refactor and ship a silently broken suite.
//
// ⛔ AND THIS GUARD FORBIDS NOTHING (#364). Repointing the blocking target at the full suite is
// the improvement #208 wants and the comment promises. When it happens this file goes red, on
// purpose, and its message names what else has to move in the same commit — the same job
// `ThePulseReadoutHasNoDoorTests` does for its six prose sites. Red here means "you changed
// something 79 comments describe", never "you may not".
//
// Claim 4 is the sibling hole, and it is the one with no prose at all: `ci.yml` runs NO
// `swift build` and NO `swift test`, so `Package.swift` is exercised by neither gate. A
// manifest-only breakage lands on the founder's Mac, where `swift build` is step 2 of the
// Ralph loop, with no CI signal at all. That is why task #89 (release/acquire via
// `Synchronization.Atomic`, which needs Swift 6 language mode under a tools-version-5.10
// manifest) is held rather than guessed at from a web session.
//
// Grading (§0, no Swift toolchain in a web session): all four claims are text assertions over
// `project.yml` and `.github/workflows/ci.yml`, transcribed into Python and driven against
// this tree — GREEN. There is no RED-on-parent to show and that is honest: this guard records
// a fact that is ALREADY true, so it is green on both trees. Its value is the day it stops
// being true. Mutation-checked instead: each needle was flipped in a scratch copy and each
// claim went red. NOT compile-verified: a transcription does not run Swift's type checker.
//
// ⚠️ READS `project.yml` AND `ci.yml`, EDITS NEITHER — both are founder-gated ("report, do not
// edit"). Reading them is what `DeviceFamilyIsPhoneOnlyTests` and
// `ThePrivacyManifestIsDeclaredForBothTargetsTests` already do.

import Foundation
import XCTest

final class TheBlockingBundleKnowsWhatItCompilesTests: XCTestCase {

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        return dir
    }

    private func text(_ relativePath: String) -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let t = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath). A guard that cannot find its "
                    + "subject is not a pass — re-anchor it (#454).")
            return ""
        }
        return t
    }

    /// How many files in this directory assert, in prose, that the other suite is ungated.
    /// Counted at FAILURE time rather than pinned as a literal: a number in a comment is a
    /// date, not a fact (#818), and this one moves every time a guard is written.
    private func filesDependingOnTheFact() -> [String] {
        let needles = ["no gate compiles", "only under `full-tests.yml`", "continue-on-error",
                       "cannot fail a merge", "sources ONLY `Tests/CISmoke`", "#208"]
        let dir = repoRoot().appendingPathComponent("Tests/CISmoke")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else {
            return []
        }
        return names.filter { $0.hasSuffix(".swift") }.filter { name in
            guard let t = try? String(contentsOf: dir.appendingPathComponent(name),
                                      encoding: .utf8) else { return false }
            return needles.contains(where: t.contains)
        }.sorted()
    }

    // MARK: 1 — the blocking target compiles THIS directory

    func testTheBlockingTargetSourcesOnlyTheSmokeDirectory() {
        let yml = text("project.yml")
        guard let start = yml.range(of: "  EchoelmusicTests:\n    type: bundle.unit-test") else {
            return XCTFail("ANCHOR MISSING: no `EchoelmusicTests` unit-test target in "
                           + "project.yml. The blocking bundle was renamed or restructured — "
                           + "re-anchor this walk rather than deleting it (#454).")
        }
        let block = String(yml[start.lowerBound...].prefix(300))
        let dependents = filesDependingOnTheFact()
        XCTAssertTrue(block.contains("- path: Tests/CISmoke"), """
            The blocking `EchoelmusicTests` target no longer sources `Tests/CISmoke`.

            IF YOU REPOINTED IT AT THE FULL SUITE, that is the improvement #208 asks for and
            project.yml's own comment promises — this red is the checklist, not a veto.
            \(dependents.count) files in Tests/CISmoke currently assert in PROSE that the other
            suite is compiled by no gate ("no gate compiles", "runs only under full-tests.yml",
            "#208", "cannot fail a merge"). All \(dependents.count) become false in the same
            instant. Re-derive the list with the needles in `filesDependingOnTheFact()` and pull
            the ones that matter in the SAME commit (#456), then rewrite this claim.

            WHY IT MATTERS BEYOND TIDINESS: #1421 wanted to widen a public return type whose
            only other call sites live in Tests/EchoelmusicTests. Both gates would have gone
            green on a broken suite. The slice was designed additively because this fact was
            measured first.
            """)
        XCTAssertFalse(block.contains("- path: Tests/EchoelmusicTests"), """
            The blocking target now ALSO sources Tests/EchoelmusicTests. See the message above:
            the change may well be right, but \(dependents.count) prose headers in this
            directory describe the old arrangement and go stale together.
            """)
    }

    // MARK: 2 — the full suite is a separate target, on the non-blocking path

    func testTheFullSuiteIsItsOwnTarget() {
        let yml = text("project.yml")
        guard let start = yml.range(of: "  EchoelmusicFullTests:\n    type: bundle.unit-test") else {
            return XCTFail("ANCHOR MISSING: no `EchoelmusicFullTests` unit-test target in "
                           + "project.yml. Re-anchor rather than deleting (#454).")
        }
        let block = String(yml[start.lowerBound...].prefix(300))
        XCTAssertTrue(block.contains("- path: Tests/EchoelmusicTests"), """
            `EchoelmusicFullTests` no longer sources Tests/EchoelmusicTests. That target exists
            to reveal the full suite's true state WITHOUT gating it; if it stopped pointing at
            the suite, `full-tests.yml` is now reporting on something else — which is the exact
            shape of the 2026-07-28 defect that created the `doctor` skill (a workflow that
            reported success for a build that had not happened).
            """)
    }

    // MARK: 3 — the merge gate's scheme tests the blocking bundle

    func testTheSchemeTheMergeGateBuildsTestsTheBlockingBundle() {
        let yml = text("project.yml")
        XCTAssertTrue(yml.contains("\n      targets:\n        - EchoelmusicTests\n"), """
            The `Echoelmusic` scheme no longer names `EchoelmusicTests` as its test target.
            CI/CD step 9 runs `xcodebuild build-for-testing -scheme Echoelmusic`, so this line
            is what decides which test files the MERGE GATE compiles. An empty test-target list
            here is not a neutral state: it is the false green this repo already paid for once
            ("`test-without-building -scheme Echoelmusic` now actually runs a test target (was
            empty → 0 tests)" — project.yml's own comment).
            """)
    }

    // MARK: 4 — the SwiftPM manifest is exercised by NO blocking gate

    func testNoBlockingWorkflowBuildsThePackageManifest() {
        let ci = text(".github/workflows/ci.yml")
        for command in ["swift build", "swift test"] {
            XCTAssertFalse(ci.contains(command), """
                `ci.yml` now runs `\(command)`. If somebody added it, that CLOSES a real hole
                and this claim should be rewritten in the same commit — say so rather than
                deleting the file.

                THE HOLE, while it is open: both gates go through `xcodebuild` with
                SWIFT_VERSION 6.0 from project.yml. `Package.swift` declares
                `swift-tools-version: 5.10` and is built by NEITHER. A change that compiles
                under Xcode but not under SwiftPM — the concrete case is `import
                Synchronization`, whose `Atomic` is a noncopyable-generics type — would show
                NO red anywhere and would land on the founder's Mac, where `swift build` is
                step 2 of the Ralph loop. That is why task #89 is held rather than guessed.
                """)
        }
    }
}
