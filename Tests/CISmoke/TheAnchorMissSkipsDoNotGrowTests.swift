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
//
// ⭐ LOWERED 89 → 75 (2026-09-25), measured with the same three-line window. ⛔ Claim 1 was
// RED before this: the count had grown to 109 (> 89) since #1240, and a red outside the
// tail-200 job-log window leaves no trace (§5, #807). 30 sites were MISSING-TREE skips whose
// `fileExists` sat outside the window (an enumerator `guard let walk = …` or an
// `isReadableFile` check) — reclassified by putting an explicit
// `FileManager.default.fileExists(atPath:)` on the guard line, which changes no verdict. Four
// were real anchor misses (`bodyOfMember` in TheAUv3FollowsTheHostSampleRateTests and
// TheSensitivityWindowHasADoorTests: missing anchor + unbalanced braces) and now `XCTFail`.
//
// ⭐ THREE CLASSES, NOT TWO (2026-09-28, founder order; triage of f84d4121e, case 14). The count
// reached 77 when the broadcast guard (5d3116308/71e9600f0) added two skips on a RUNTIME
// condition — "a streaming engine is linked" — which is neither a missing tree nor a missing
// text anchor. Raising the
// ratchet would have hidden the next real anchor miss behind them; converting them to
// `XCTSkipIf` would have hidden them from the scan altogether, because the scan only counted
// `throw XCTSkip`. So the scan now (a) COUNTS the conditional forms `XCTSkipIf(`/
// `XCTSkipUnless(` as skip sites too, and (b) knows an explicit third class: a skip whose window
// carries the marker `PRECONDITION-SKIP:` with a reason is a declared precondition, counted
// against its OWN ratchet (`preconditionRatchet`), which also moves down only. The anchor-miss
// ratchet stays 75. Widening the scan found one real anchor miss that `XCTSkipIf` had hidden
// (the Pythagorean counterweight in TheSuggestedToneSystemsDoNotCollapseTheScaleTests), now
// an `XCTFail`. Claim 5 proves the classifier on synthetic input: an unmarked skip of either
// form is an anchor miss, a marker without a reason is an anchor miss, a tree check is not.

import Foundation
import XCTest

final class TheAnchorMissSkipsDoNotGrowTests: XCTestCase {

    /// Today's count after the first two rungs. Lower it when you migrate a site; never raise it.
    private static let ratchet = 75
    /// Lines above a skip in which a `fileExists` check makes it a missing-TREE skip.
    private static let windowLines = 3
    private static let ownFile = "TheAnchorMissSkipsDoNotGrowTests.swift"
    /// Assembled so this file's own text never matches its own needle even if the exclusion moved.
    private static let skipNeedle = "throw XCT" + "Skip"
    /// The conditional forms. They skip exactly like `throw XCTSkip`, and a scan that did not
    /// count them turned a switch to `XCTSkipIf` into a way out of the ratchet.
    private static let conditionalNeedles: [String] = ["XCT" + "SkipIf(", "XCT" + "SkipUnless("]
    /// A declared precondition. Must carry a reason after the colon. Three kinds qualify, and
    /// only these: RUNTIME state (an engine that is not linked), DATA state (a factory with one
    /// entry), and a deliberate STAND-DOWN whose condition is text but whose absence is a
    /// legitimate product state, not a moved anchor (#364 — e.g. a renderer that no longer
    /// reads a uniform). A skip that FOLLOWS a helper which has already called `XCTFail` on the
    /// missing anchor also qualifies, because it cannot fail open. A skip for an anchor that
    /// simply moved never does — that is an `XCTFail`.
    private static let preconditionMarker = "PRECONDITION" + "-SKIP:"
    /// Declared precondition skips today. Moves DOWN only, like `ratchet`; a new one is a
    /// visible decision in the diff, never a silent side door.
    private static let preconditionRatchet = 5
    /// Lines BELOW a conditional skip that still belong to its call (the condition may wrap).
    private static let conditionalTailLines = 2

    /// Claim 1 — the ratchet.
    func testAnchorMissSkipsDoNotGrow() throws {
        let result = try scan()
        let anchorMiss = result.anchorMiss
        XCTAssertLessThanOrEqual(anchorMiss.count, Self.ratchet, """
            \(anchorMiss.count) anchor-miss skips, ratchet is \(Self.ratchet). A missed ANCHOR is a red, \
            not a skip: use XCTFail (and `throw` your own Error if the caller needs to stop); XCTSkip is \
            for a missing TREE only (`fileExists` within \(Self.windowLines) lines above) or a DECLARED \
            runtime precondition (`\(Self.preconditionMarker) <reason>` within the same window). \
            All anchor-miss sites, in file order (the list does not know which are new): \
            \(anchorMiss.map { "\($0.file):\($0.line)" }.joined(separator: ", ")) (#1240, of \(result.total) skip sites)
            """)
        XCTAssertLessThanOrEqual(result.precondition.count, Self.preconditionRatchet, """
            \(result.precondition.count) declared precondition skips, ratchet is \
            \(Self.preconditionRatchet). The marker is for a RUNTIME or DATA condition (an engine \
            that is not linked, a factory with one entry), never for a text anchor that moved. \
            Sites: \(result.precondition.map { "\($0.file):\($0.line)" }.joined(separator: ", "))
            """)
    }

    /// Claim 2 — the first two rungs stay migrated.
    func testTheTwoSampledSitesFailInsteadOfSkipping() throws {
        let gain = try text("Tests/CISmoke/TheMasterGainMovesInSmallStepsTests.swift")
        XCTAssertTrue(gain.contains("return XCTFail(\"`stop(reason:)` is gone from AudioEngine.swift"),
                      "the `stop(reason:)` anchor miss skips again instead of failing (#1240)")
        // ⚠️ THE PATH MOVED WITH AUDIO IMPORT V1 (2026-09-22): the file was
        // `TheAudioLanesHaveNoProducerTests.swift` until the audio lanes got a producer and
        // its NAME became a false statement (#374). Carried here in the same commit, because
        // `text(_:)` SKIPS a missing file — a stale path would have turned this claim into a
        // silent pass, which is the exact defect the ratchet above exists to prevent (#456).
        let lanes = try text("Tests/CISmoke/TheAudioLaneProducerIsTheImportDoorTests.swift")
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
        let sites = try scan().total
        XCTAssertGreaterThan(sites, 100,
                             "the scan found \(sites) `throw XCTSkip` sites — the bundle has hundreds; a scan that finds none is a broken scan, not a clean bundle (#1240)")
    }

    /// Claim 5 — the classifier on synthetic input, so "echte Ankerfehler werden weiter erkannt"
    /// is a measurement and not a promise. Each case is one skip site in a tiny fake file.
    func testTheClassifierStillCatchesARealAnchorMiss() {
        let skip = "throw XCT" + "Skip(\"x\")"
        let skipIf = "try XCT" + "SkipIf(flag, \"x\")"
        let skipUnless = "try XCT" + "SkipUnless("
        // Concatenations hoisted out of the array literal: the literal below then holds only
        // plain strings and names, which keeps the type-checker off the #E2 path (§2 of
        // Tests/CISmoke/CLAUDE.md).
        let bareMarker = "// " + Self.preconditionMarker
        let reasonedMarker = "// " + Self.preconditionMarker + " engine linked"
        let cases: [(name: String, lines: [String], expected: SkipClass)] = [
            ("bare throw, no tree check, no marker",
             ["guard let a = text.range(of: \"anchor\") else {", skip, "}"], .anchorMiss),
            ("conditional form, no tree check, no marker",
             ["let found = text.contains(\"anchor\")", skipIf], .anchorMiss),
            ("marker WITHOUT a reason",
             [bareMarker, skip], .anchorMiss),
            ("marker too far above the skip",
             [reasonedMarker, "", "", "", "", skip], .anchorMiss),
            ("tree check above a throw",
             ["guard FileManager.default.fileExists(atPath: p) else {", skip, "}"], .missingTree),
            ("tree check inside a wrapped conditional",
             [skipUnless, "    FileManager.default.fileExists(atPath: p),", "    \"x\")"], .missingTree),
            ("declared precondition with a reason",
             ["guard !engineAvailable else {", reasonedMarker, skip, "}"], .precondition),
        ]
        for c in cases {
            let site = c.lines.firstIndex { $0.contains("XCT" + "Skip") } ?? 0
            XCTAssertEqual(Self.classify(lines: c.lines, at: site), c.expected,
                           "classifier case \"\(c.name)\" — if this moved, the ratchet no longer measures what it says")
        }
    }

    // MARK: - Scan

    private struct Site { let file: String; let line: Int }
    enum SkipClass { case missingTree, precondition, anchorMiss }
    private struct ScanResult { var anchorMiss: [Site] = []; var precondition: [Site] = []; var total = 0 }

    /// Every skip site over `Tests/CISmoke/*.swift`, this file excluded, by class.
    private func scan() throws -> ScanResult {
        let dir = try repoRoot().appendingPathComponent("Tests/CISmoke")
        guard FileManager.default.fileExists(atPath: dir.path) else {
            throw XCTSkip("Tests/CISmoke is not at \(dir.path) — this scan reads the bundle's own files and cannot run without them")
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".swift") && $0 != Self.ownFile }.sorted()
        var result = ScanResult()
        for name in names {
            let lines = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
                .components(separatedBy: "\n")
            for index in lines.indices where Self.isSkipSite(lines[index]) {
                result.total += 1
                switch Self.classify(lines: lines, at: index) {
                case .missingTree: break
                case .precondition: result.precondition.append(Site(file: name, line: index + 1))
                case .anchorMiss: result.anchorMiss.append(Site(file: name, line: index + 1))
                }
            }
        }
        return result
    }

    private static func isSkipSite(_ line: String) -> Bool {
        line.contains(skipNeedle) || conditionalNeedles.contains { line.contains($0) }
    }

    /// The window is the skip line plus `windowLines` above it; a conditional skip also owns
    /// the next `conditionalTailLines`, because its condition may wrap onto them. A tree check
    /// anywhere in that window wins; otherwise a marker with a non-empty reason in the lines
    /// ABOVE (or on) the skip makes it a precondition; anything else is an anchor miss.
    static func classify(lines: [String], at index: Int) -> SkipClass {
        let above = lines[max(0, index - windowLines)...index]
        let conditional = conditionalNeedles.contains { lines[index].contains($0) }
        let tail = conditional ? lines[index..<min(lines.count, index + 1 + conditionalTailLines)] : []
        if above.contains(where: { $0.contains("fileExists") }) || tail.contains(where: { $0.contains("fileExists") }) {
            return .missingTree
        }
        let declared = above.contains { line in
            guard let at = line.range(of: preconditionMarker) else { return false }
            return !line[at.upperBound...].trimmingCharacters(in: .whitespaces).isEmpty
        }
        return declared ? .precondition : .anchorMiss
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
