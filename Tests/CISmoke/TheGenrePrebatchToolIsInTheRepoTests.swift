// TheGenrePrebatchToolIsInTheRepoTests.swift
// Echoel — #1320. Blocking bundle. Every claim is a FILE-CONTENT SCAN
// (`Tests/CISmoke/CLAUDE.md` §1): it proves the tool is present and self-contained, never
// that its arithmetic is right. The tool proves that about itself with `--selftest`, which
// nothing in this bundle can run (no Python step in the Xcode test action) — that limit is
// named here rather than implied.
//
// ⭐ WHY THIS FILE EXISTS, AND IT IS NOT ABOUT GENRES. The pre-batch calculator was authored
// in a SESSION SCRATCHPAD and stayed there through five genre batches, while
// `scratchpads/PLAN_GENRE_WELT_2026-09-11.md` cited it BY THAT PATH as the measurement every
// remaining batch must run first. A scratchpad dies with its container. The plan's own recipe
// was one session away from being unrunnable, and the next session would have gone back to
// remembering — which is precisely what #1286 paid five false prose claims for.
//
// ⚠️ IT WAS FOUND BY RUNNING THE RECIPE, NOT BY THINKING ABOUT IT. The G11c row says "measure
// first with the tool"; the command returned `No such file`. That is the durable lesson and
// it generalises past this tool: **a RECIPE is only as durable as the tool it names**, the
// same shape as the repo's "a pointer is only as durable as what it points at" (#1142), one
// level out.
//
// ⚠️ WHAT CLAIM 2 IS AND IS NOT. It is a negative scan, and negative scans are normally the
// #491 trap — but the retraction of the old path lives in the PLAN, not in the script, so this
// needle cannot hit its own tombstone. It would go red if someone re-introduced an absolute
// scratchpad path or split the table extractor back out into a second scratchpad file, which
// are the two ways this tool becomes unrunnable again.
//
// ⚠️ HONEST GRADING. No local Swift toolchain (§0). **8 assertions across five claims**
// (claim 1 = 2, claim 2 = 2, claim 3 = 1, claim 4 = 2, claim 5 = 1). All were transcribed in
// Python and driven against BOTH trees. On the PARENT tree (`f6b399f`) **all five methods
// fail, and that is ONE finding** (#486) — the tool is not in the repo, and every red is that
// one absence from another angle. On today's tree all 8 are green.
//
// ⚠️ ONE NUANCE WORTH STATING, because it is the difference between this guard working and
// looking like it works: claim 2's two assertions are NEGATIVE, so on a tree without the tool
// they would both pass over an empty string — vacuously green on exactly the tree they exist
// to catch. What fails that method on the parent is `text()` itself, which XCTFails on a
// missing file rather than skipping (#454). The anchor is load-bearing for claim 2 in a way it
// is not for the others; remove it and this file goes quiet precisely when it matters.
//
// Claims 4 and 5 are COUNTERWEIGHTS (#343): without them a zero-byte file named
// `scripts/genre-prebatch.py` would satisfy claims 1–3.
import Foundation
import XCTest

final class TheGenrePrebatchToolIsInTheRepoTests: XCTestCase {

    private static let toolPath = "scripts/genre-prebatch.py"
    private static let planPath = "scratchpads/PLAN_GENRE_WELT_2026-09-11.md"

    // MARK: - claim 1 — the tool is here and it is the whole tool

    func testTheToolIsInTheRepository() throws {
        let tool = try text(Self.toolPath)
        XCTAssertTrue(tool.contains("1 LEAD CEILING"), """
            \(Self.toolPath) no longer prints the lead-ceiling section. That is check 1 of the \
            seven the batch template requires BEFORE writing a genre; a tool missing it sends \
            a session back to remembering the palette, which is the #1286 failure.
            """)
        XCTAssertTrue(tool.contains("7 BASS GRAMMAR"), """
            \(Self.toolPath) no longer prints the bass-grammar section. That is the check that \
            told #1290 `pedalDrone` does not exist — the difference between an EMPTY figure and \
            an ABSENT one, which its own comment records as a finding, not a pass.
            """)
    }

    // MARK: - claim 2 — it is self-contained, which is the point of moving it

    func testTheToolCarriesNoScratchpadPointer() throws {
        let tool = try text(Self.toolPath)
        XCTAssertFalse(tool.contains("/tmp/claude"), """
            \(Self.toolPath) contains an absolute session-scratchpad path. That is exactly what \
            #1320 removed: a scratchpad dies with its container, so the tool would be \
            unrunnable in the next session while the plan still names it as required.
            """)
        XCTAssertFalse(tool.contains("mstable2"), """
            \(Self.toolPath) reaches for `mstable2.py` again. Its table extractor was folded in \
            on purpose — a tool in the repo that shells out to a scratchpad file is not in the \
            repo, it just looks like it.
            """)
    }

    // MARK: - claim 3 — the recipe names the durable path

    func testThePlanCitesTheRepositoryPath() throws {
        XCTAssertTrue(try text(Self.planPath).contains("scripts/genre-prebatch.py"), """
            `\(Self.planPath)` no longer names `scripts/genre-prebatch.py`. The plan is where \
            the next genre batch reads what to run first; a recipe pointing anywhere else is \
            how this tool went missing in the first place.
            """)
    }

    // MARK: - claim 4 (counterweight) — it still reads the shipped tree

    func testTheToolStillMeasuresTheShippedTree() throws {
        let tool = try text(Self.toolPath)
        XCTAssertTrue(tool.contains("Sequencer"), """
            \(Self.toolPath) no longer resolves the `Sequencer` source directory. Without it \
            the tool measures nothing and claims 1–3 would be green over a stub.
            """)
        XCTAssertTrue(tool.contains("BassGrammar.swift"), """
            \(Self.toolPath) no longer reads `BassGrammar.swift`, so its figure list would come \
            from somewhere other than the enum. A parser that matches nothing is a finding, \
            never a pass (`.claude/rules/context.md` §2) — and this tool already learned that \
            once.
            """)
    }

    // MARK: - claim 5 (counterweight) — it can prove its own checks still bite

    func testTheToolCanTestItself() throws {
        XCTAssertTrue(try text(Self.toolPath).contains("def selftest"), """
            \(Self.toolPath) lost its `--selftest`. It drives the two sharpest checks against \
            candidates BUILT FROM THE TREE — a fingerprint clone that must clash, and an \
            unshipped `BassGrammar` case that must be named absent. A needle that only ever \
            runs on passing input is verified by nothing (#808). ⚠️ No CI step runs it; it is \
            the founder's and a session's command, and this assertion only pins that it exists.
            """)
    }

    // MARK: - file access (§0 — FAIL on a missing anchor, never skip it away)

    private func text(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("scripts").path) else {
            throw XCTSkip("repo tree not present under \(root.path)")
        }
        guard let body = try? String(contentsOf: root.appendingPathComponent(relative),
                                     encoding: .utf8), !body.isEmpty else {
            XCTFail("""
                ANCHOR MISSING: \(relative) could not be read or is empty while the tree is \
                present — a missing anchor is a finding, not a pass (#454).
                """)
            return ""
        }
        return body
    }
}
