// TheAgentRecipesPointAtThisRepoTests.swift
// Echoel — #1041. Blocking bundle, because the other suite cannot fail a merge (#208).
//
// WHAT THIS RECORDS. `.claude/agents/*.md` and `.claude/routines/*.md` are PRESCRIPTIVE: they
// hand a subagent the command to run and the fix to apply. A phantom in one of them does not
// merely mislead a reader — it produces a scan over a directory that is not there, or code
// against an API that was never in the tree. Measured 2026-09-06, four defects in three files:
//
//   · `concurrency-reviewer.md` — ALL EIGHT `grep` recipes pointed at `Echoelmusic/`, and two
//     also at `EchoelmusicComplete/`. `ls -d` on both: "No such file or directory". Each recipe
//     still returned the `Sources/` hits, so it half-worked while printing what looks like a
//     broken tool, and `grep -r` over a missing path exits 2, so `&&` chaining after it stopped.
//   · `build-error-resolver.md` — "API Gotchas" prescribed `.value` on `NormalizedCoherence`
//     (0 hits in `Sources/`; the one hit in `Tests/` is a test METHOD name) and listed eight
//     method names of `EchoelBrandFont` (0 hits in `Sources/` AND `Tests/`). The live type is
//     `EchoelTheme`, 1765 references.
//   · `02-issue-triage.md` — routed "sound doesn't react to heartbeat" to a DEEP_RESEARCH doc
//     that does not exist anywhere, and "camera pulse not working" to `isCameraActive` /
//     `BioSourceManager`, both 0 hits (the manager went in the 2026-06-19 cleanup).
//
// ⭐ AND THE SIBLING FILE ALREADY HAD THE DIRECTORY FIX. `ui-state-reviewer.md:18` says in so
// many words that its recipes "pointed at `Echoelmusic/` and `EchoelmusicComplete/`, neither of
// which exists". One agent file was corrected and the other was not — the #456 shape, and the
// third instance of it in a single day (#1035 CLAUDE.md→build-guard, #1038 #1024→CLAIMS.md).
// That is why claim 2 scans the WHOLE tree for the recipe shape rather than one file.
//
// ⛔ THIS GUARD FORBIDS NOTHING (#364). Claim 1 works off an explicit list of names that are
// deliberately dead, and it is red in BOTH directions: a NEW phantom is not on the list, and a
// REVIVED name is on the list while existing again. Either way the message says which edit to
// make. Nothing here stops an agent file naming a real type, adding a recipe, or being deleted.
//
// ⚠️ WHY CLAIM 1 NEEDS A LIST AT ALL, rather than "every backticked Echoel* must exist". That
// simpler rule was written first and MEASURED before it was trusted: it fires on four names
// that are perfectly legitimate — `EchoelDDSPTests` (a test class, so absent from `Sources/`),
// `EchoelmusicFullTests`, `EchoelmusicWatch`, `EchoelmusicWidgets` (scheme and target names in
// `project.yml`). Widening the corpus to Sources+Tests+project.yml+Package.swift clears those,
// and exactly three remain — each a deliberate retraction. A guard tuned until it is quiet is
// decoration; this one was tuned until every remaining hit was a real finding.
//
// ⚠️ AND CLAIM 1 CANNOT TELL AN EPITAPH FROM LIVE ADVICE — say it plainly, because the
// grading below reads better than the guard is. At the parent commit `EchoelBrandFont` was
// cited as a FIX TO APPLY, and claim 1 was green there, because the name is on the list. The
// list is what makes the check quiet enough to survive; it is also why claim 1 catches only
// the FOURTH phantom, never the three already known. Those three are held honest by the
// retraction prose beside them and by the `revived` half above, not by this claim.
//
// ⚠️ HONEST LIMITS. This proves the NAMES resolve and the RECIPE PATHS exist. It cannot know
// whether a recipe finds what it claims to find — `ui-state-reviewer.md` records a
// `grep "@Observable" | grep "class"` that selected 0 of 65 because the attribute sits on its
// own line, and no path check would have caught that. The repaired recipe in
// `concurrency-reviewer.md` carries a `-A 1` and a warning for that reason; verifying its yield
// stays non-zero is a human step, not this file's.
//
// ⭐ #1306 — TWO THINGS THIS FILE COULD NOT SEE, both found while tidying for a deploy.
//
//   1. CLAIM 1 COULD NOT BE GREEN ON ANY TREE, AND HAD NOT BEEN FOR AS LONG AS THE LIST
//      EXISTED. `deliberatelyDead` names types precisely because they are ABSENT — and the
//      list itself is Swift source under `Tests/`, which claim 1 concatenates into the very
//      corpus it searches. Every name on it therefore "existed", the `revived` assertion
//      fired on all three, and the guard was red on a correct tree: #364 in its mirror
//      image. Measured: `grep -rl EchoelBeat Sources Tests --include="*.swift"` returns one
//      path, this file. The corpus now skips self.
//      ⚠️ TWO SECOND-ORDER FACTS, because either alone would have hidden the first. The same
//      self-reference ALSO made the `absent` half vacuous for listed names, in the quiet
//      direction. And `tdd-agent.md` cites `EchoelVoiceAudioUnit` inside a retraction while
//      the type is absent from Sources, Tests and both manifests, and it was never added to
//      the list — a genuine second red, which the first one masked. It is on the list now.
//      ⭐ THE STRUCTURAL LESSON: a guard that reads a directory it lives in reads itself, and
//      a list of absent names is the one payload where that is fatal. In this repo such a red
//      is invisible until a human transcribes it — `Run Tests` reports `failure` on EVERY
//      push (#396) and the job log is a 200-line tail (#807).
//
//   2. THE PHANTOM ACTUALLY IN THE TREE DID NOT START WITH `Echoel`. Five instruction files
//      sent a session to `MonitorInsertAudioUnit` / `Audio/MonitorInsertAU.swift` /
//      `Tests/CISmoke/TheMonitorInsertCarriesTheNeutralChainTests.swift`, all three deleted
//      with the audio input (#1302). Claim 1's needle is `` `Echoel[A-Za-z0-9_]+ `` and could
//      not match any of them. ⭐ Rather than widen the NAME rule — the header above records
//      that the naive form was measured and fires on legitimate names — claim 3 checks the
//      PATHS, which is the half that can be decided by `FileManager` instead of by taste.
//
// ⭐ CLAIM 3 IS THE BLOCKING TWIN OF `scripts/doctor.py` SECTION B (#416: the decision has ONE
// home, the doctor; this only enforces it where a push can see it). Same corpus, same
// `Sources/|Tests/|scripts/` path shape, same PER-LINE obituary exemption — the doctor's own
// comment records that a ±2-line window exempted three LIVE paths and caught nothing extra.
// Deliberately identical, so the WARN and the RED can never disagree; if you change one,
// change the other in the same commit (#456). A doctor WARN is advisory and nothing reads it
// on a push — the same argument #702 used for the law-file ceiling.
//
// ⭐ GRADING (§3). Transcribed in Python against both trees. Claim 2 is FORWARD — eight matching
// recipe lines at the parent, zero here. Claim 1 is a COUNTERWEIGHT, green at the parent too
// for the reason stated above; it goes red on a FOURTH phantom or on a revival. Driven to red
// deliberately (#914): adding "`EchoelPhantomMutant`" to `code-reviewer.md` produced
// `unknown phantoms=['EchoelPhantomMutant']`, and the line was removed again.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheAgentRecipesPointAtThisRepoTests: XCTestCase {

    /// Names that appear in agent instructions, do NOT exist in the tree, and are there on
    /// purpose — each next to a retraction explaining what replaced it. Re-measured by claim 1
    /// on every run, so the list cannot quietly rot into an excuse.
    private static let deliberatelyDead: Set<String> = [
        "EchoelBeat",           // the drum product; deleted by #166/#167, cited by dsp-reviewer
        "EchoelBrandFont",      // never existed; the live type is EchoelTheme (#1041)
        "EchoelmusicComplete",  // a phantom directory; cited by ui-state-reviewer and #1041
        // The AUv3 audio unit; its extension target went 2026-07-24 (#121 Slice 2) and the
        // type occurs zero times in Sources or Tests. `tdd-agent.md` retracts a fourteen-line
        // pattern built on it. Added #1306 — it had been cited-and-absent all along, which is
        // to say claim 1 was RED and #396 hid it.
        "EchoelVoiceAudioUnit"
    ]

    // MARK: - 1: every project name an agent file cites either exists or is a known epitaph

    func testEveryEchoelNameInAnAgentFileResolvesOrIsAKnownEpitaph() throws {
        let root = try repoRoot()
        let corpus = try instructionFiles(under: root)
        XCTAssertFalse(corpus.isEmpty, """
            No `.claude/agents/*.md` or `.claude/routines/*.md` files found. Every claim in \
            this file is a statement about them; re-anchor rather than passing on an empty set.
            """)

        // The tree the names must resolve against — code AND the project/package manifests,
        // because a scheme or target name is a real name that lives in neither Sources nor Tests.
        //
        // ⛔ AND IT INCLUDED THIS VERY FILE UNTIL #1306, WHICH MADE CLAIM 1 RED ON EVERY TREE.
        // `deliberatelyDead` lists the names precisely BECAUSE they are absent — and the list
        // lives in a `.swift` file under `Tests/`, so `tree.contains(name)` found every one of
        // them in the guard's own source and the `revived` assertion fired on all three.
        // Measured on the parent commit: `grep -rl EchoelBeat Sources Tests --include="*.swift"`
        // returns exactly one path, this file. So the claim could not be green on a correct
        // tree, which is #364 in its mirror image — and nobody saw it, because `Run Tests`
        // reports `failure` on EVERY push (#396) and the job log is a 200-line tail (#807),
        // so a red assertion in this bundle is invisible until a human transcribes it.
        //
        // ⚠️ The same self-reference weakened the OTHER half in the quieter direction: a cited
        // name that is on the list also "resolved" against this file, so `absent` could never
        // contain it. Excluding self fixes both halves at once, which is why it is the right
        // cut rather than, say, stripping comments.
        let selfFile = URL(fileURLWithPath: #filePath).lastPathComponent
        var tree = ""
        for relative in ["Sources", "Tests"] {
            let base = root.appendingPathComponent(relative)
            guard let walk = FileManager.default.enumerator(atPath: base.path) else { continue }
            for case let rel as String in walk where rel.hasSuffix(".swift") {
                guard (rel as NSString).lastPathComponent != selfFile else { continue }
                tree += (try? String(contentsOf: base.appendingPathComponent(rel),
                                     encoding: .utf8)) ?? ""
            }
        }
        for manifest in ["project.yml", "Package.swift"] {
            tree += (try? String(contentsOf: root.appendingPathComponent(manifest),
                                 encoding: .utf8)) ?? ""
        }
        XCTAssertTrue(tree.contains("EchoelStudioView"), """
            The tree corpus came back without `EchoelStudioView`, so it did not load. Every \
            name would look dead and this claim would fire on all of them. Fix the reader.
            """)

        let backticked = try NSRegularExpression(pattern: "`(Echoel[A-Za-z0-9_]+)")
        var cited = Set<String>()
        for file in corpus {
            let ns = file.text as NSString
            for m in backticked.matches(in: file.text,
                                        range: NSRange(location: 0, length: ns.length)) {
                cited.insert(ns.substring(with: m.range(at: 1)))
            }
        }

        let absent = cited.filter { !tree.contains($0) }
        let unknownPhantoms = absent.subtracting(Self.deliberatelyDead).sorted()
        XCTAssertTrue(unknownPhantoms.isEmpty, """
            Agent instructions cite \(unknownPhantoms) — no such name exists in `Sources/`, \
            `Tests/`, `project.yml` or `Package.swift`.

            These files are PRESCRIPTIVE: a subagent is told to run the command and apply the \
            fix. A phantom here produces code against an API that was never in the tree — \
            #1041 found `EchoelBrandFont` handing out eight method names of nothing. Either \
            correct the citation to the live name, or, if the name is a deliberate epitaph, \
            add it to `deliberatelyDead` above WITH the retraction that explains what replaced \
            it. Do not add it to the list to silence this.
            """)

        let revived = Self.deliberatelyDead.filter { tree.contains($0) }.sorted()
        XCTAssertTrue(revived.isEmpty, """
            \(revived) is on the `deliberatelyDead` list and EXISTS in the tree again.

            That is good news and still a red (#364): the epitaph beside it in the agent file \
            is now false, and a reader would be told a live thing is gone. Remove the name \
            from the list and correct the prose in the SAME commit (#456).
            """)
    }

    // MARK: - 2: the finding — no recipe scans a directory that is not there

    /// ⭐ Anchored to the recipe SHAPE (`--include="*.swift"`), not to prose, so the retraction
    /// blocks that quote the phantom paths cannot trip it.
    func testNoRecipeScansADirectoryThatDoesNotExist() throws {
        let root = try repoRoot()
        var offenders: [String] = []
        for file in try instructionFiles(under: root) {
            for line in file.text.split(separator: "\n", omittingEmptySubsequences: false) {
                guard line.contains("--include=\"*.swift\"") else { continue }
                if line.contains(" Echoelmusic/") || line.contains(" EchoelmusicComplete/") {
                    offenders.append("\(file.name): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty, """
            \(offenders.count) recipe(s) scan a top-level `Echoelmusic/` or \
            `EchoelmusicComplete/` directory, and neither exists — the source tree is \
            `Sources/Echoelmusic/`:

            \(offenders.joined(separator: "\n            "))

            The recipe still returns the `Sources/` hits, so it half-works while printing what \
            reads as a broken tool, and `grep -r` over a missing path exits 2, which silently \
            stops any `&&` after it. `ui-state-reviewer.md` had this corrected before \
            `concurrency-reviewer.md` did; when you fix a recipe, grep the whole `.claude/` \
            tree for the same shape before calling it done (#456).
            """)

        // COUNTERWEIGHT (#367): a negative over an empty set is not a measurement.
        let recipeLines = try instructionFiles(under: root)
            .flatMap { $0.text.split(separator: "\n") }
            .filter { $0.contains("--include=\"*.swift\"") }
        XCTAssertFalse(recipeLines.isEmpty, """
            No `--include="*.swift"` recipe lines found at all, so claim 2's negative passed \
            over nothing. If the agent files stopped carrying grep recipes, re-anchor this \
            claim on whatever shape replaced them.
            """)
    }

    // MARK: - 3: no instruction file sends a session to a path that is not there

    /// The blocking twin of `scripts/doctor.py` section B. Kept byte-for-byte equivalent to it
    /// on purpose (see the ⭐ block in the header): same corpus, same path shape, same
    /// per-line obituary exemption.
    func testNoInstructionFileCitesARepoPathThatIsNotThere() throws {
        let root = try repoRoot()
        let docs = try pathCitingFiles(under: root)
        XCTAssertFalse(docs.isEmpty, """
            No instruction files found under `.claude/`. Claim 3's negative would pass over an \
            empty set — a scan that matches nothing is a finding, never a pass \
            (`.claude/rules/context.md` §2). Re-anchor the corpus rather than passing.
            """)

        // Only the three roots the doctor checks. `.claude/settings.local.json` is gitignored
        // BY DESIGN and `.github/workflows/decision-review.yml` is named inside its own
        // retraction — widening the shape to every backticked path makes both look like drift.
        let pathLike = try NSRegularExpression(
            pattern: "`(Sources/[\\w/.*-]+|Tests/[\\w/.*-]+|scripts/[\\w/.-]+)`")
        let obituary = try NSRegularExpression(
            pattern: "deleted|removed|no longer|never existed|does not exist|gone with",
            options: [.caseInsensitive])

        var stale: [String] = []
        var citations = 0
        for doc in docs {
            for (i, line) in doc.text.split(separator: "\n",
                                            omittingEmptySubsequences: false).enumerated() {
                let text = String(line)
                let full = NSRange(location: 0, length: (text as NSString).length)
                if obituary.firstMatch(in: text, range: full) != nil { continue }
                let ns = text as NSString
                for m in pathLike.matches(in: text, range: full) {
                    let raw = ns.substring(with: m.range(at: 1))
                    let base = String(raw.split(separator: "*").first ?? "")
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    guard !base.isEmpty else { continue }
                    citations += 1
                    if !FileManager.default.fileExists(
                        atPath: root.appendingPathComponent(base).path) {
                        stale.append("\(doc.name):\(i + 1)  \(raw)")
                    }
                }
            }
        }

        XCTAssertFalse(citations == 0, """
            Claim 3 found no `Sources/` / `Tests/` / `scripts/` path cited in any instruction \
            file at all, so its negative measured nothing (#367). Either the corpus stopped \
            loading or the files stopped citing paths — re-anchor on whatever replaced them.
            """)

        XCTAssertTrue(stale.isEmpty, """
            \(stale.count) instruction file(s) send a session to a repo path that is not there:

            \(stale.joined(separator: "\n            "))

            These files are PRESCRIPTIVE — a subagent is handed the path and told to read or \
            copy it. #1306 found five such citations pointing at `MonitorInsertAU.swift` and \
            its guard, both deleted with the audio input (#1302); a planner following them \
            looked for two files that are not there and had nothing to fall back on.

            THE REPAIR IS NOT "delete the sentence". A document that EXPLAINS a deletion has \
            to name the deleted path, and that is exempt — put one of `deleted`, `removed`, \
            `no longer`, `never existed`, `does not exist` or `gone with` on the SAME LINE as \
            the path. Same line, not nearby: the doctor measured a ±2-line window and it \
            exempted three LIVE paths while catching nothing extra. Then name what replaced \
            it, WITH the command that re-measures it — a replacement citation is a claim with \
            an expiry date, and #1306 had to retract two generations of one.

            This claim forbids nothing (#364): cite any path you like, as long as it exists or \
            its line says it does not.
            """)
    }

    // MARK: - helpers

    private struct DiagAnchorMissing: Error { let reason: String }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        return root
    }

    /// ⭐ `.claude/commands` was NOT in this corpus until #1306, and two of the five phantom
    /// citations it found lived there — `tdd.md` and `multi-plan.md` are handed to a session
    /// by name, exactly as prescriptive as an agent file. Measured before widening: the
    /// directory adds 5 recipe lines for claim 2 with 0 offenders and 1 cited `Echoel*` name
    /// with 0 phantoms, so neither older claim changes verdict.
    private func instructionFiles(under root: URL) throws -> [(name: String, text: String)] {
        var out: [(name: String, text: String)] = []
        for dir in [".claude/agents", ".claude/routines", ".claude/commands"] {
            let base = root.appendingPathComponent(dir)
            guard let items = try? FileManager.default.contentsOfDirectory(atPath: base.path)
            else { continue }
            for item in items.sorted() where item.hasSuffix(".md") {
                guard let text = try? String(contentsOf: base.appendingPathComponent(item),
                                             encoding: .utf8) else { continue }
                out.append(("\(dir)/\(item)", text))
            }
        }
        return out
    }

    /// Claim 3's corpus: everything `instructionFiles` reads, plus the vendored skills, which
    /// the doctor also reads. Kept SEPARATE from `instructionFiles` on purpose — claim 1 must
    /// not start scanning 45 vendored marketing skills for `Echoel*` names it knows nothing
    /// about, while claim 3's path shape is decided by the filesystem and is safe over them.
    private func pathCitingFiles(under root: URL) throws -> [(name: String, text: String)] {
        var out = try instructionFiles(under: root)
        let skills = root.appendingPathComponent(".claude/skills")
        if let dirs = try? FileManager.default.contentsOfDirectory(atPath: skills.path) {
            for dir in dirs.sorted() {
                let file = skills.appendingPathComponent(dir).appendingPathComponent("SKILL.md")
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                out.append((".claude/skills/\(dir)/SKILL.md", text))
            }
        }
        return out
    }
}
