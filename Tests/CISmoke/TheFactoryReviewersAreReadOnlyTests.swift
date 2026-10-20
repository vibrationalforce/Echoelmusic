// TheFactoryReviewersAreReadOnlyTests.swift
// Echoel — the factory's reviewers and approver are read-only agents, and the skill and the
// workflow agree on the loop.
//
// WHY. `.claude/workflows/echoel-factory-review.js` spawns up to five agents per round (four
// lenses and an approver). `.claude/rules/context.md` §5 requires every subagent prompt to carry
// one clause verbatim, because a subagent in this repo once destroyed uncommitted work. A
// workflow that builds a prompt WITHOUT the clause looks exactly like one that does, until it
// runs. The skill (`.claude/skills/factory/SKILL.md`) states the rework cap a second time for
// the reader; two spellings of one number is #416, so the guard ties them together instead.
//
// CLAIMS (all SOURCE-TEXT SCANS, Tests/CISmoke/CLAUDE.md §1 — they prove where text sits,
// not that an agent obeys it)
// 1. Every agent call in the workflow goes through `withReadOnly(`, and there are at least two.
// 2. The workflow's `READ_ONLY` constant is the §5 clause of `.claude/rules/context.md`,
//    whitespace-normalised.
// 3. Every `agentType:` in the workflow is a name on the ultracode roster.
// 4. `MAX_REWORK_ROUNDS` in the workflow equals the number the skill states for it.
// 5. The skill routes an escalation to `docs/dev/FOUNDER_INBOX.md`, and that file exists.
// 6. `withReadOnly` really PREPENDS `READ_ONLY` — claims 1 and 2 would stay green over a wrapper
//    rewritten as `(text) => text`, while no prompt carried the clause (factory job 001, round 1).
// 7. The approver reads the locked set AT THE JOB BASE — `git show ${a.base}:` of
//    `.claude/rules/context.md`, `.claude/hooks/protect-founder-gated.py` and
//    `.claude/settings.json` — never from the tree under review, which the job itself may have
//    edited (factory job 001, round 3; job 003) — and confirms that `board.json` at the head records
//    the same base, so the range under review is the whole job (job 003, round 2).
// 8. Every path the lock is DEFINED by escalates deterministically: each file in the hook's
//    `PROTECTED_FILES` and each `Edit(/…)`/`Write(/…)` file in `permissions.ask` of
//    `.claude/settings.json` is in the workflow's `LOCK_CONFIG`; each directory in the hook's
//    `PROTECTED_DIRS` and each `…/**` entry of `permissions.ask` is in `LOCK_DIRS`; and the
//    predicate `isLockConfig` reads both lists. The hook half must parse on its own, and a file rule in
//    permissions.ask the scan cannot read is a failure, not a skip (job 003, round 2: either would
//    leave a lock path unchecked while the claim stayed green). Three lists of one lock is #416: a path added to the
//    hook or to permissions.ask and not to the workflow would be judged by the approver's discretion
//    again. ⚠️ Fail-closed by design: a ship file the founder puts back under the hook or into
//    permissions.ask (project.yml, Info.plist, .github/workflows/) then ALWAYS escalates a factory job,
//    released or not — a dated release costs one inbox answer, a silent miss costs the lock.
// 9. The judge cannot approve its own edit: `JUDGE_FILES` holds this workflow, `JUDGE_DIRS` holds
//    `.claude/agents/` (the lens definitions the harness loads from the tree under review), the
//    predicate `isJudge` reads both, and the judge branch sits BEFORE the APPROVE branch of the decision
//    (job 003, round 1: the round was reviewed by the very copy it had edited).
// 10. What the round knows from its own measurement escalates before any count is asked again: the
//    fixed escalation has a part for the rework cap and a part for a lock change, `fixed` joins EVERY
//    part (job 004, round 1: as a ternary the cap dropped the lock part and its token note), an
//    escalation the approver pronounces is read beside it in `const escalation = fixed || pronounced ||`,
//    and every RERUN after `phase('Approve')` — `decision: 'RERUN'` and `decision = 'RERUN'` alike — sits
//    AFTER `if (escalation) {`, so neither the spec-count note nor the graded-set note can call the same
//    round again in front of them (job 003, round 3: two count RERUNs stood ahead of the cap and the lock,
//    and a RERUN re-calls a round nothing holds still). And a numbered criterion the approver labels
//    `founder` is never code evidence: `kindOf` maps it to `founderLabel`, and `metCode` admits `code` only.
//
// GRADING (§3). On the parent tree the workflow and the skill do not exist: every claim is red
// by ANCHOR ABSENCE — one absence, reported five times (#486). All five are FORWARD guards for
// files this commit creates; none is a regression. Claim 2's context.md half and claim 5's inbox
// half are COUNTERWEIGHTS, green on both trees. Not compiled here (no toolchain); transcribed
// in Python against both trees.
// Claim 6 (added in the job-001 rework) is a COUNTERWEIGHT: the wrapper already prepended the clause
// on the parent, so it is green on both trees and pins a premise of claims 1–2 (#343).
// Claims 7, 8 and 9 (job 003) are FORWARD guards: on the parent `f61d7872d` the approver read the
// lock files from the working tree and there was no `LOCK_CONFIG`, `LOCK_DIRS` or `JUDGE_FILES`, so
// all three are red there by the change itself, not by an absent anchor; the hook and settings halves
// of claim 8 parse on both trees. Round 2 tightened two claims. Claim 7's board.json needle is red on
// `f61d7872d` and `9237c3c91` and green on `6d168b44a`, the rework that wrote the sentence. Claim 8's two
// additions (the hook half parses on its own, an unreadable file rule fails) hold on every tree — the hook
// has always been double-quoted and permissions.ask has no such rule — so they are counterweights that make
// an empty or skipped parse visible. Probed: removing the needle, single-quoting PROTECTED_FILES or an ask
// rule `Edit(.mcp.json)` turns the claim red.
// Claim 10 (job 004), graded per needle on the parent `73e9ae52d`: the `kindOf`, cap-part, lock-part, join
// and `escalation` needles are FORWARD (red there by the change: the parent mapped a founder label to code
// and built `fixed` after the count RERUNs); the `metCode` needle is a COUNTERWEIGHT — that line did not
// change, the `kindOf` needle carries the fix; the order scan is red there by ANCHOR ABSENCE (no
// `if (escalation) {`). Every needle runs BEFORE the scan's early return, so each gets
// a verdict on the parent. Transcribed in Python against both trees.
//
// WHEN IT RUNS. Only with a commit that touches `Sources/` or `Tests/` (the gates' path filters). An
// edit to the workflow or the skill alone starts no gate, so a red here can land on the NEXT
// unrelated commit. Whoever edits the workflow transcribes claims 1–4 and 6–10 before pushing, and
// runs `scripts/factory-review-selftest.py` for the decision logic, which no guard here can see.
//
// THIS GUARD FORBIDS NOTHING (#364): more lenses, a different cap, a new agent type on the
// roster — each is one consistent edit away from green.

import Foundation
import XCTest

final class TheFactoryReviewersAreReadOnlyTests: XCTestCase {

    private static let workflowPath = ".claude/workflows/echoel-factory-review.js"
    private static let skillPath = ".claude/skills/factory/SKILL.md"

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        return dir
    }

    private func text(_ relativePath: String) -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let t = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return t
    }

    /// The workflow without its full-line `//` comments, so prose about an agent call is not
    /// counted as one. Only whole comment lines are dropped: a `//` inside a string survives.
    private func workflowCode() -> String {
        text(Self.workflowPath)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    private func normalised(_ s: String) -> String {
        s.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).joined(separator: " ")
    }

    /// The first capture group of `pattern` in `haystack`, or nil.
    private func firstCapture(_ pattern: String, in haystack: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = haystack as NSString
        guard let m = regex.firstMatch(in: haystack, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 1, m.range(at: 1).location != NSNotFound else { return nil }
        return ns.substring(with: m.range(at: 1))
    }

    func testEveryAgentCallCarriesTheReadOnlyClause() {
        let code = workflowCode()
        let calls = occurrences(of: "agent(", in: code)
        let wrapped = occurrences(of: "agent(withReadOnly(", in: code)
        XCTAssertGreaterThanOrEqual(calls, 2, """
            The factory workflow makes fewer than two agent calls (lenses + approver). Either the \
            file did not load or the loop changed shape; re-anchor rather than passing.
            """)
        XCTAssertEqual(calls, wrapped, """
            \(calls - wrapped) agent call(s) in \(Self.workflowPath) do not go through \
            `withReadOnly(`. Every subagent prompt must carry the §5 clause of \
            `.claude/rules/context.md` verbatim — a subagent here once destroyed uncommitted work.
            """)
    }

    func testTheWrapperPrependsTheClause() {
        XCTAssertTrue(workflowCode().contains("const withReadOnly = (text) => `${READ_ONLY}"), """
            `withReadOnly` in \(Self.workflowPath) no longer starts with `${READ_ONLY}`. Claims 1 and \
            2 only see that every agent call goes through the wrapper and that the constant is right; \
            this is the line that puts one into the other.
            """)
    }

    func testTheClauseIsTheOneTheContextRulesDefine() {
        let rules = normalised(text(".claude/rules/context.md"))
        guard let start = rules.range(of: "*read-only inspection only"),
              let end = rules.range(of: "report findings as text.*", range: start.upperBound..<rules.endIndex)
        else { return XCTFail("ANCHOR MISSING: the §5 clause in .claude/rules/context.md (#454)") }
        let clause = String(rules[rules.index(after: start.lowerBound)..<rules.index(before: end.upperBound)])
        guard let constant = firstCapture("const READ_ONLY = '([^\\n]*)'", in: workflowCode()) else {
            return XCTFail("ANCHOR MISSING: `const READ_ONLY = '…'` in \(Self.workflowPath) (#454)")
        }
        XCTAssertEqual(normalised(constant), clause, """
            The workflow's READ_ONLY clause drifted from `.claude/rules/context.md` §5. Copy it \
            again from there; the rule says verbatim.
            """)
    }

    func testEveryAgentTypeIsOnTheRoster() {
        let skill = text(".claude/skills/ultracode-teams/SKILL.md")
        guard let start = skill.range(of: "<!-- ultracode-roster: begin -->"),
              let end = skill.range(of: "<!-- ultracode-roster: end -->"),
              start.upperBound < end.lowerBound else {
            return XCTFail("ANCHOR MISSING: ultracode-roster markers (#454)")
        }
        let roster = Set(String(skill[start.upperBound..<end.lowerBound])
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        let code = workflowCode()
        guard let regex = try? NSRegularExpression(pattern: "agentType: '([A-Za-z0-9-]+)'") else {
            return XCTFail("agentType pattern did not compile")
        }
        let ns = code as NSString
        let used: Set<String> = Set(regex.matches(in: code, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range(at: 1)) })
        XCTAssertGreaterThanOrEqual(used.count, 3, "fewer than three agent types found — the scan matched nothing useful")
        XCTAssertTrue(used.isSubset(of: roster), """
            The factory workflow spawns \(used.subtracting(roster).sorted()), which is not on the \
            ultracode roster. A skill name or an invented type kills the run (the 16-agent \
            sweep that spawned `echoel-marketing`).
            """)
    }

    func testTheSkillStatesTheWorkflowsReworkCap() {
        guard let inCode = firstCapture("const MAX_REWORK_ROUNDS = ([0-9]+)", in: workflowCode()) else {
            return XCTFail("ANCHOR MISSING: `const MAX_REWORK_ROUNDS` in \(Self.workflowPath) (#454)")
        }
        guard let inSkill = firstCapture("`MAX_REWORK_ROUNDS` = ([0-9]+)", in: text(Self.skillPath)) else {
            return XCTFail("ANCHOR MISSING: \"`MAX_REWORK_ROUNDS` = N\" in \(Self.skillPath) (#454)")
        }
        XCTAssertEqual(inSkill, inCode, """
            The skill says \(inSkill) rework rounds, the workflow enforces \(inCode). Change both \
            in one commit.
            """)
    }

    /// Every string between a pair of `quote` characters in `list` (the odd pieces of a split).
    private func quoted(_ list: String, by quote: String) -> Set<String> {
        let pieces = list.components(separatedBy: quote)
        var found = Set<String>()
        var index = 1
        while index < pieces.count {
            found.insert(pieces[index])
            index += 2
        }
        return found
    }

    func testTheApproverReadsTheLockAtTheJobBase() {
        let code = workflowCode()
        for file in [".claude/rules/context.md", ".claude/hooks/protect-founder-gated.py", ".claude/settings.json"] {
            XCTAssertTrue(code.contains("git show ${a.base}:\(file)"), """
                The approver prompt in \(Self.workflowPath) no longer reads `\(file)` with \
                `git show ${a.base}:`. Read from the working tree, the locked set is the one the job \
                under review may have edited — the job would be judged by its own rules.
                """)
        }
        XCTAssertTrue(code.contains("Confirm that \\`git show ${head}:${jobDir}/board.json\\` records base ${a.base}"), """
            The approver prompt in \(Self.workflowPath) no longer checks that board.json at the head records \
            the base it was called with. A wrong base reviews part of the job as if it were the whole.
            """)
    }

    /// The quoted strings of the JavaScript array `const <name> = [...]` in the workflow, or nil.
    private func workflowList(_ name: String) -> Set<String>? {
        guard let body = firstCapture("const \(name) = \\[([^\\]]*)\\]", in: workflowCode()) else { return nil }
        return quoted(body, by: "'")
    }

    func testEveryLockedPathEscalatesDeterministically() {
        let hook = text(".claude/hooks/protect-founder-gated.py")
        guard let hookFileList = firstCapture("PROTECTED_FILES = \\(([^)]*)\\)", in: hook),
              let hookDirList = firstCapture("PROTECTED_DIRS = \\(([^)]*)\\)", in: hook) else {
            return XCTFail("ANCHOR MISSING: `PROTECTED_FILES = (…)` / `PROTECTED_DIRS = (…)` in .claude/hooks/protect-founder-gated.py (#454)")
        }
        guard let lockFiles = workflowList("LOCK_CONFIG"), let lockDirs = workflowList("LOCK_DIRS") else {
            return XCTFail("ANCHOR MISSING: `const LOCK_CONFIG = [...]` / `const LOCK_DIRS = [...]` in \(Self.workflowPath) (#454)")
        }
        let settingsURL = repoRoot().appendingPathComponent(".claude/settings.json")
        guard let data = try? Data(contentsOf: settingsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let permissions = json["permissions"] as? [String: Any],
              let ask = permissions["ask"] as? [String] else {
            return XCTFail("ANCHOR MISSING: permissions.ask in .claude/settings.json (#454)")
        }
        let hookFiles = quoted(hookFileList, by: "\"")
        XCTAssertFalse(hookFiles.isEmpty, """
            PROTECTED_FILES in .claude/hooks/protect-founder-gated.py parsed empty. The scan reads double-quoted \
            strings; a hook rewritten with other quotes would leave only permissions.ask checked here.
            """)
        var files = hookFiles
        var dirs = Set(quoted(hookDirList, by: "\"").map { $0.hasSuffix("/") ? $0 : $0 + "/" })
        for entry in ask where ["Edit(", "Write(", "MultiEdit("].contains(where: { entry.hasPrefix($0) }) {
            guard let path = firstCapture("^(?:Edit|Write|MultiEdit)\\(/(.+)\\)$", in: entry) else {
                XCTFail("""
                    permissions.ask entry `\(entry)` is a file rule this scan cannot read (it expects \
                    `Edit(/<repo path>)`). A rule it skips is a lock path it never compares with LOCK_CONFIG.
                    """)
                continue
            }
            if path.hasSuffix("/**") {
                dirs.insert(String(path.dropLast(2)))
            } else {
                files.insert(path)
            }
        }
        XCTAssertFalse(files.isEmpty, "PROTECTED_FILES and permissions.ask parsed empty — the scan matched nothing useful")
        XCTAssertTrue(files.isSubset(of: lockFiles), """
            The lock is defined over \(files.subtracting(lockFiles).sorted()), which the factory workflow's \
            LOCK_CONFIG does not escalate. Add it to LOCK_CONFIG in the same commit, or a job that edits it \
            is judged by the approver's discretion instead of escalating.
            """)
        XCTAssertTrue(dirs.isSubset(of: lockDirs), """
            The lock covers the director(ies) \(dirs.subtracting(lockDirs).sorted()), which the workflow's \
            LOCK_DIRS does not escalate. Add each with its trailing slash.
            """)
        XCTAssertTrue(workflowCode().contains(
            "const isLockConfig = (f) => LOCK_CONFIG.includes(f) || LOCK_DIRS.some(d => f.startsWith(d))"), """
            `isLockConfig` in \(Self.workflowPath) no longer reads both LOCK_CONFIG and LOCK_DIRS; the lists \
            above would be checked against a predicate that ignores them.
            """)
    }

    func testTheJudgeCannotApproveItsOwnEdit() {
        let code = workflowCode()
        guard let judgeFiles = workflowList("JUDGE_FILES"), let judgeDirs = workflowList("JUDGE_DIRS") else {
            return XCTFail("ANCHOR MISSING: `const JUDGE_FILES = [...]` / `const JUDGE_DIRS = [...]` in \(Self.workflowPath) (#454)")
        }
        XCTAssertTrue(judgeFiles.contains(Self.workflowPath), """
            JUDGE_FILES no longer names \(Self.workflowPath). The harness runs that file from the tree under \
            review, so a job that edits it would be approved by its own edit.
            """)
        XCTAssertTrue(judgeDirs.contains(".claude/agents/"), """
            JUDGE_DIRS no longer names `.claude/agents/`, the lens definitions the harness loads from the tree \
            under review.
            """)
        XCTAssertTrue(code.contains("const isJudge = (f) => JUDGE_FILES.includes(f) || JUDGE_DIRS.some(d => f.startsWith(d))"), """
            `isJudge` in \(Self.workflowPath) no longer reads both JUDGE_FILES and JUDGE_DIRS.
            """)
        guard let judgeBranch = code.range(of: "} else if (judgeChanged.length) {"),
              let approveBranch = code.range(of: "decision = 'APPROVE'") else {
            return XCTFail("ANCHOR MISSING: the judge branch or `decision = 'APPROVE'` in \(Self.workflowPath) (#454)")
        }
        XCTAssertLessThan(judgeBranch.lowerBound, approveBranch.lowerBound, """
            The judge branch no longer comes before APPROVE in the decision ladder, so an edit to the judge \
            could end in APPROVE.
            """)
    }

    func testTheFixedEscalationComesBeforeEveryRecount() {
        let code = workflowCode()
        XCTAssertTrue(code.contains(
            "const kindOf = (c) => c.number === 0 ? 'founder' : c.kind === 'founder' ? 'founderLabel'"), """
            `kindOf` in \(Self.workflowPath) no longer keeps a founder-labelled criterion apart from code; a \
            criterion the approver calls the founder's would again count as code evidence.
            """)
        XCTAssertTrue(code.contains(
            "const metCode = acceptance.filter(c => kindOf(c) === 'code' && c.met === true)"), """
            `metCode` in \(Self.workflowPath) no longer admits `code` only; an approval could rest on a \
            criterion that is the founder's.
            """)
        XCTAssertTrue(code.contains("if (capReached) fixedParts.push("), """
            The fixed escalation in \(Self.workflowPath) no longer has a part for the rework cap; a capped round \
            could be called again for a count instead of escalating.
            """)
        XCTAssertTrue(code.contains("if (lockChanged.length) fixedParts.push(`the change edits the lock configuration"), """
            The fixed escalation in \(Self.workflowPath) no longer has a part for a lock change; an edit to the \
            lock could be called again for a count instead of escalating.
            """)
        XCTAssertTrue(code.contains("const fixed = fixedParts.join('; ')"), """
            `fixed` in \(Self.workflowPath) no longer keeps every part: a capped round that also commits the \
            token would drop the instruction to rotate it (job 004, round 1).
            """)
        XCTAssertTrue(code.contains("const escalation = fixed || pronounced ||"), """
            The count-note branch of \(Self.workflowPath) no longer reads `fixed` and `pronounced` first, so a \
            count RERUN could stand in front of an escalation the round already knows.
            """)
        let ns = code as NSString
        let approve = ns.range(of: "phase('Approve')")
        guard approve.location != NSNotFound else {
            return XCTFail("ANCHOR MISSING: `phase('Approve')` in \(Self.workflowPath) (#454)")
        }
        let tail = NSRange(location: NSMaxRange(approve), length: ns.length - NSMaxRange(approve))
        let escalation = ns.range(of: "if (escalation) {", options: [], range: tail)
        guard escalation.location != NSNotFound,
              let rerun = try? NSRegularExpression(pattern: "decision\\s*[:=]\\s*'RERUN'") else {
            return XCTFail("ANCHOR MISSING: `if (escalation) {` after `phase('Approve')` in \(Self.workflowPath) (#454)")
        }
        let reruns = rerun.matches(in: code, range: tail)
        XCTAssertGreaterThan(reruns.count, 0, """
            ANCHOR MISSING: no RERUN after `phase('Approve')` in \(Self.workflowPath) — the scan below would \
            pass over nothing (#454).
            """)
        for match in reruns {
            XCTAssertGreaterThan(match.range.location, escalation.location, """
                A RERUN in the Approve phase of \(Self.workflowPath) (offset \(match.range.location), either \
                `decision: 'RERUN'` or `decision = 'RERUN'`) stands before `if (escalation) {`: a count note would \
                call the same round again ahead of the cap, the lock or the approver's own ESCALATE.
                """)
        }
    }

    func testEscalationsGoToTheFounderInbox() {
        XCTAssertTrue(text(Self.skillPath).contains("docs/dev/FOUNDER_INBOX.md"), """
            The factory skill no longer routes ESCALATE to `docs/dev/FOUNDER_INBOX.md`. A question \
            to the founder stands there once, with a date, or it is not asked.
            """)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: repoRoot().appendingPathComponent("docs/dev/FOUNDER_INBOX.md").path),
            "docs/dev/FOUNDER_INBOX.md is gone — re-point the factory's escalation lane")
    }
}
