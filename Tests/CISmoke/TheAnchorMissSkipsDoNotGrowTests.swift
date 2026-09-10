// TheAnchorMissSkipsDoNotGrowTests.swift
// Echoel — #1240 (audit 2026-09-10 `tests-guards-2`, Ultraplan row 19). A ratchet on the one
// fail-open path this bundle has: an XCTSkip thrown when an ANCHOR is missing.
//
// THE RISK. Two kinds of skip live in `Tests/CISmoke`. The honest one guards a missing TREE
// (`FileManager.default.fileExists` → `throw XCTSkip`): the file is not there, the guard
// cannot read it, and saying so beats a green it did not earn. The other kind fires when the
// file IS there and a quoted anchor is not — a rename of `stop(reason:)` or of a creator's
// signature. Under `xcodebuild test-without-building` a skip does not fail the job, so that
// second kind turns a broken guard into a quiet green; the only thing that would notice is
// `scripts/gh-test-verdict.py`'s skip needle, derived rather than observed (#806) and read over
// a 200-line tail (#807). Measured on the parent: 393 `throw XCTSkip` sites, 302 within three
// lines of `fileExists`, **91** anchor-miss skips. The bundle's own law already says it
// (`XCTSkip … would have been green`, #454); nothing enforced it.
//
// WHAT THIS PINS. (1) THE RATCHET: the number of anchor-miss skips — a `throw XCTSkip` line
// with no `fileExists` in the three lines above it, this file excluded — is at most
// `ratchet`. It moves DOWN only: a migration lowers the constant in the same commit; a new
// guard that needs a skip for a missing anchor uses `XCTFail` instead (the two rungs below are
// the template). (2) THE FIRST TWO RUNGS: the two sites the audit sampled now `XCTFail`.
// (3) THE DETECTOR'S OWN PROSE: `gh-test-verdict.py` no longer quotes a file count that was
// stale by 31 files within weeks — it carries the command. (4) COUNTERWEIGHT: the scan finds
// SOMETHING (a parser that matches nothing is a finding, never a pass — `.claude/rules/
// context.md` §2).
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`ec8dd2b`) and this tree with the
// same three-line-window algorithm in Python: claim 1 RED on the parent (91 > 89), GREEN here;
// claims 2 and 3 RED there, GREEN here; claim 4 GREEN on both.

import Foundation
import XCTest

final class TheAnchorMissSkipsDoNotGrowTests: XCTestCase {

    /// Today's count after the first two rungs. Lower it when you migrate a site; never raise it.
    private static let ratchet = 89
    /// Lines above a skip in which a `fileExists` check makes it a missing-TREE skip.
    private static let windowLines = 3
    private static let ownFile = "TheAnchorMissSkipsDoNotGrowTests.swift"
    /// Assembled so this file's own text never matches its own needle even if the exclusion moved.
    private static let skipNeedle = "throw XCT" + "Skip"

    /// Claim 1 — the ratchet.
    func testAnchorMissSkipsDoNotGrow() throws {
        let (anchorMiss, sites) = try scan()
        XCTAssertLessThanOrEqual(anchorMiss.count, Self.ratchet, """
            \(anchorMiss.count) anchor-miss skips, ratchet is \(Self.ratchet). A missed ANCHOR is a red, \
            not a skip: use XCTFail (and `throw` your own Error if the caller needs to stop); XCTSkip is \
            for a missing TREE only (`fileExists` within \(Self.windowLines) lines above). New sites: \
            \(anchorMiss.suffix(3).map { "\($0.file):\($0.line)" }.joined(separator: ", ")) (#1240, of \(sites) skip sites)
            """)
    }

    /// Claim 2 — the first two rungs stay migrated.
    func testTheTwoSampledSitesFailInsteadOfSkipping() throws {
        let gain = try text("Tests/CISmoke/TheMasterGainMovesInSmallStepsTests.swift")
        XCTAssertTrue(gain.contains("return XCTFail(\"`stop(reason:)` is gone from AudioEngine.swift"),
                      "the `stop(reason:)` anchor miss skips again instead of failing (#1240)")
        let lanes = try text("Tests/CISmoke/TheAudioLanesHaveNoProducerTests.swift")
        XCTAssertTrue(lanes.contains("throw AnchorMissing(name: name)") && lanes.contains("XCTFail(\"`func \\(name)` is not in TimelineStore.swift"),
                      "the creator-anchor miss in `body(of:in:)` skips again instead of failing (#1240)")
    }

    /// Claim 3 — the detector carries the command, not a stale pair of numbers.
    func testTheVerdictScriptMeasuresInsteadOfQuoting() throws {
        let script = try text("scripts/gh-test-verdict.py")
        XCTAssertFalse(script.contains("358 files in `Tests/CISmoke`"),
                       "`gh-test-verdict.py` quotes a file count again — it was stale by 31 files within weeks (#1240)")
        XCTAssertTrue(script.contains("git grep -l XCTSkip -- 'Tests/CISmoke/*.swift' | wc -l"),
                      "`gh-test-verdict.py` lost the command that re-derives the skip-capable file count (#1240)")
    }

    /// Claim 4 — counterweight: the scan finds skip sites at all.
    func testTheScanFindsSkipSites() throws {
        let (_, sites) = try scan()
        XCTAssertGreaterThan(sites, 100,
                             "the scan found \(sites) `throw XCTSkip` sites — the bundle has hundreds; a scan that finds none is a broken scan, not a clean bundle (#1240)")
    }

    // MARK: - Scan

    private struct Site { let file: String; let line: Int }

    /// (anchor-miss sites, total skip sites) over `Tests/CISmoke/*.swift`, this file excluded.
    private func scan() throws -> ([Site], Int) {
        let dir = try repoRoot().appendingPathComponent("Tests/CISmoke")
        guard FileManager.default.fileExists(atPath: dir.path) else {
            throw XCTSkip("Tests/CISmoke is not at \(dir.path) — this scan reads the bundle's own files and cannot run without them")
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".swift") && $0 != Self.ownFile }.sorted()
        var anchorMiss: [Site] = []
        var total = 0
        for name in names {
            let lines = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
                .components(separatedBy: "\n")
            for (index, line) in lines.enumerated() where line.contains(Self.skipNeedle) {
                total += 1
                let window = lines[max(0, index - Self.windowLines)...index].joined(separator: "\n")
                if !window.contains("fileExists") { anchorMiss.append(Site(file: name, line: index + 1)) }
            }
        }
        return (anchorMiss, total)
    }

    private func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func text(_ relativePath: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relativePath) not present at \(url.path) — this test reads repo files as text, so it SKIPS rather than reporting a green it did not earn")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
