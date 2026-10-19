# Runde 1 — e2e-test-agent

Range `b1cfc8ad1..9c0677f03` · Workflow `wf_53b5c83e-663` · gesagt: CHANGES

## Zusammenfassung

Ship-path review of b1cfc8ad1..9c0677f03, one commit. One major finding: the approver's list of founder-locked files does not match the repo's rules, so a founder-gated change can be approved without escalation.

Ship surface: the diff changes no target, entitlements file, Info.plist or project.yml (`git diff --stat`). The new guard Tests/CISmoke/TheFactoryReviewersAreReadOnlyTests.swift is picked up by the blocking bundle automatically, because project.yml:474 adds the whole Tests/CISmoke directory as a source. Its idioms (static path lets, #filePath with three deletions, NSRegularExpression, components-count) already compile in 21 to 530 other CISmoke files, and the multi-line literal indentation checks out. It adds no XCTSkip, so the anchor-miss ratchet is unaffected.

Guard transcribed in Python against both trees:
- Head 9c0677f03: claim 1 finds 2 agent calls, 2 wrapped. Claim 2's READ_ONLY matches context.md §5 after whitespace normalisation, and that clause occurs exactly once. Claim 3 finds 9 agentTypes, all on the roster. Claim 4: 2 = 2. Claim 5: the inbox exists.
- Parent b1cfc8ad1: red because the workflow file is absent, which is the intended forward behaviour.

Gates: the commit was pushed together with the docs commit 1814d6b10, so the runs are on that sha. At review time, CI/CD run 39336698967 step "Build for Testing" was in progress, and Xcode Compile Check 39336698910 was in progress (it proves nothing about Tests/). Quick Test succeeded. The new guard therefore has not run anywhere yet, and ship status is UNPROVEN until Build for Testing succeeds and gh-test-verdict.py names TheFactoryReviewersAreReadOnlyTests. Acceptance criteria 1 (`node --check`) and 6 (`--selftest`) are not re-run by any gate.

Out of lens, unverified beyond one grep: .claude/skills/factory/SKILL.md:21 points to `memory/inspiration_intake.md` for the 2026-10-19 verdict. That file has no factory or zazencodes entry at 9c0677f03 or 1814d6b10. The verdict is at inspiration.csv:306, added in 1814d6b10.

## Befunde

### 1. major — `.claude/workflows/echoel-factory-review.js`:191

The approver's escalation trigger lists founder-locked files as '.github/workflows/** other than the studio workflows, the root project.yml, Resources/iOS/Info.plist'. This is a fourth hand-written version of the gate, and it agrees with neither source. (a) The studio-workflow exception exists only as a session-scoped standing permission ('EchoelStudio-Workflows und Plist sind für die Sitzung frei', memory/decisions.md:5482). The always-loaded rule .claude/rules/context.md:111 gates all of `.github/workflows/**` with no exception. The script turns a one-session release into a permanent rule for every future round, and 'the studio workflows' names no files (there are three: studio.yml, studio-testflight.yml, studio-linux.yml). (b) It leaves out `.claude/settings.json` and `.mcp.json`, which are the only two paths the founder-gate hook still enforces (.claude/hooks/protect-founder-gated.py:49-50). (c) The skill says only 'gesperrte Dateien' (.claude/skills/factory/SKILL.md:43), so the skill and the workflow do not agree on what forces ESCALATE. This matters because auto-merge-claude.yml triggers on `.github/workflows/**`, and `.claude/**` changes reach main along with any merged commit. An approved factory slice that edits a studio workflow or the permission grants can therefore reach main without the founder ever being asked.

**Vorschlag:** Do not restate the list. Have the approver read it from its sources: the paths in `.claude/rules/context.md` §3, plus PROTECTED_FILES and PROTECTED_DIRS in `.claude/hooks/protect-founder-gated.py`. Add `.claude/settings.json` and `.mcp.json`. Drop the studio exception, or first record it as a dated founder decision in context.md §3 and cite that. Mirror the same reference in SKILL.md step 2.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 2. minor — `.claude/workflows/echoel-factory-review.js`:124

`head` defaults to the moving ref 'HEAD'. The lenses run in parallel, and the approver runs later, so each agent can resolve HEAD at a different time. If the PM commits during a round, the agents review different ranges, and none of them may match the range the board records. That happened in this very round: 1814d6b10 landed on top of 9c0677f03, and this job's board.json:2 still has `"head": ""`. This round was safe only because the orchestrator passed an explicit sha.

**Vorschlag:** Require `head` to be a resolved sha (reject 'HEAD' and other branch names), or have the PM write it to board.json before calling the workflow. Echo the resolved range in the return value.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 3. minor — `.claude/skills/factory/SKILL.md`:68

'APPROVE → done nach grünen Gates' cannot be satisfied in one case and is undefined in another. Echoelmusic CI/CD reports failure on every push (#396), so it is never green. A pipeline-only job (only `.claude/**`, `scripts/**`, `scratchpads/**`) triggers no gate at all (ci.yml:14-25 path filter; auto-merge-claude.yml has the same paths), and that NOT-TRIGGERED state is neither green nor red. The approver prompt (echoel-factory-review.js:186) also accepts 'the guard that pins it' as evidence. A forward guard in a bundle whose Build for Testing has not finished is unobserved; run 39336698967 was still in Build for Testing during this round.

**Vorschlag:** Spell out what done requires: Xcode Compile Check conclusion, plus the CI/CD step `Build for Testing` = success, plus `gh-test-verdict.py` naming the new guard. Point to Tests/CISmoke/CLAUDE.md §5 rather than restating it. For path-filtered jobs, say 'no run' and name what counts instead (the selftest or a transcription). Tell the approver that a cited guard counts as evidence only once a run has executed it.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

### 4. minor — `Tests/CISmoke/TheFactoryReviewersAreReadOnlyTests.swift`:21

The guard's GRADING header does not say when the guard actually runs. A later commit that touches only `.claude/workflows/echoel-factory-review.js` or the skill (for example, one that drops `withReadOnly(`) starts no gate and no auto-merge, because of the path filters. The guard then turns red on the next unrelated Sources/ or Tests/ commit and gets blamed on that commit. Main stays protected, but the failure lands on the wrong commit. The same applies to the spec's criteria 1 and 6, which no gate re-runs. This behaviour exists already in the repo (TheUltracodeLeadsAreRealAgentsTests shares it); this diff does not introduce it.

**Vorschlag:** Add one header line: the guard fires on the next commit that touches Sources/ or Tests/, not on a `.claude/`-only edit. Whoever edits the workflow should transcribe claims 1-4 before pushing.

**Stand:** in Runde 2 eingearbeitet (Nacharbeits-Commit, siehe `../round-2/`).

