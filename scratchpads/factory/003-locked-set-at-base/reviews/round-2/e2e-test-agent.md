# Runde 2 — e2e-test-agent

Workflow `wf_29831ef4-24e`, Bereich `f61d7872d..6d168b44a` (Nacharbeit seit `9237c3c91`) mit den acht `paths` aus `board.json`, `criteria` 10, `deviceCriteria` [], `founderAssumptions` 0, Urteil der Linse: **CHANGES**. Gesamtentscheidung: **REWORK** (5 Majors). Außerhalb von `paths`: `docs/dev/APP_STORE_CONNECT.md`, `docs/dev/FOUNDER_INBOX.md`, `docs/dev/TODO_FOUNDER_2026-10-19.md` (Commit `532e5b169`, nicht sensibel); `judgeChanged`: `.claude/workflows/echoel-factory-review.js`.

## Zusammenfassung

Ship-path lens, round 2. Ranges: whole job f61d7872d..6d168b44a; rework delta 9237c3c91..6d168b44a. One commit in the range is not part of the job: 532e5b169 changes docs/dev/APP_STORE_CONNECT.md, FOUNDER_INBOX.md and TODO_FOUNDER_2026-10-19.md, so those three files fall outside the job's paths. None of them is in SENSITIVE. The job touches no app target, entitlement, Info.plist, privacy manifest or project.yml, and no file under .claude/settings.json, .mcp.json, .claude/hooks/ or .claude/agents/.

Round-1 findings from this lens:
- (1) major, SKILL "a run on the head" rule: fixed. SKILL.md:150-180 now counts the newest run on the head or an ancestor, and keys "Kein Lauf" to the whole job.
- (2) claim 8: fixed. It now reads PROTECTED_DIRS and the permissions.ask Edit(...) entries, and its header documents the fail-closed choice.
- (3) SENSITIVE: fixed. project.yml, .github/workflows/, EchoelStudio/RELEASE and docs/privacy|terms/index.html are in, and a selftest case covers them.
- (4) judge: fixed with JUDGE_FILES/JUDGE_DIRS and a rule placed before APPROVE.
- The auto-merge observation was rebutted with a reason. I accept the rebuttal.

Workflow rules compared one by one against `git show f61d7872d:.claude/workflows/echoel-factory-review.js`: none is removed or loosened toward APPROVE.
- INVALID-on-empty became INVALID or RERUN.
- The REWORK exit is skipped when the lock config changes, which forces ESCALATE.
- capReached is narrower, but the lockChanged rule covers the gap.
- founderOpen now needs a dated record.
- The lock list is read at the base, including PROTECTED_DIRS and permissions.ask.
- The name lists use --no-renames.
- since is rejected in round 1, and the PATH check is stricter.
- One change of route: a numbered criterion that the approver labels 'founder' and leaves unmet now goes to REWORK instead of ESCALATE. AC4 asks for this, and it can never reach APPROVE.

Local checks:
- `factory-review-selftest.py`: exit 0, all cases match. `--mutate`: 56/56 mutations caught.
- `factory-board.py --selftest`: ok. `--mutate`: 12/12 caught.
- Claims 7, 8 and 9 transcribed in Python against 6d168b44a: all green. The hook has PROTECTED_DIRS=(), so the directory comes only from permissions.ask, which contains Edit(/.claude/hooks/**).
- `doctor.py --section B` reports no dead path in the factory skill.
- The "Kein Lauf" filter list in SKILL matches xcode-compile-check.yml, ci.yml and studio.yml at head.
- .deploy/release no longer triggers anything (testflight.yml has it frozen), so leaving it out of SENSITIVE is correct.

Gate state on head 6d168b44a:
- Xcode Compile Check, run 39345875423: success. It builds Sources/ only and proves nothing about this job.
- CI/CD, run 39345875384: Build for Testing succeeded, so the Swift for claims 8 and 9 compiles. Run Tests was still in progress when I checked, so whether the guard passes is not yet observed.
- Round-1 CI/CD run 39343249655: gh-test-verdict.py reports 0 failures and 161 tests seen passing, but TheFactoryReviewersAreReadOnlyTests does not appear in the 200-line window. Its execution there is also unobserved (#445).
- Auto-merge run 39343249776 failed at "Merge to main" with Merge Status: conflict, so job commits have not reached main through automation.
- No gate runs the selftests or factory-board.py.

New findings: one major. The rule that lets an earlier gate run stay valid ignores that CISmoke guards read files outside the gate's path filters. Two minors: SENSITIVE misses the Fastfile and Appfile that the live Studio signing step runs, and AC1 cites claim 7 for a check it does not pin.

## Befunde

1. **major** `.claude/skills/factory/SKILL.md`:155 — The new 'Welcher Lauf zählt' rule (lines 150-157) says a rework that touches only `.claude/**` or `scratchpads/**` starts no run, 'und der Lauf davor bleibt der gültige'. Validity is decided by `git diff --name-only S..<head> -- <gate filters>` alone. CISmoke guards are source scans and read files outside every gate filter. This job's own guard reads `.claude/workflows/echoel-factory-review.js` (line 86), `.claude/rules/context.md` (133), `.claude/skills/ultracode-teams/SKILL.md` (148), `.claude/skills/factory/SKILL.md` (175, 283), `.claude/hooks/protect-founder-gated.py` (214) and `.claude/settings.json`. None of these is in the filters of xcode-compile-check.yml, ci.yml or studio.yml. Failure: round 2 asks for rework, and the PM edits only the workflow, for example moving the judge branch after APPROVE or renaming `isJudge`. No gate starts. The rule then declares CI/CD run 39345875384 on 6d168b44a valid, although claims 8 and 9 in it were computed against the old workflow text. A later job that adds a guard over docs/ or CLAUDE.md would close 'done' on a verdict for a tree that no longer exists. The rule also contradicts SKILL.md:246-248 in the same file, which says a pure `.claude/` change starts no gate and the claims must be transcribed before the push.
   - Vorschlag: Qualify the rule. An earlier run stays valid only if the diff from S to the head is also empty over every path read by a guard the job adds or changes. For TheFactoryReviewersAreReadOnlyTests that means the six files above. Otherwise that guard counts as 'transkribiert, kein Lauf' for the head, never as green. Alternatively, require one more commit that touches the guard file, so that a run starts on the final tree.
2. **minor** `.claude/workflows/echoel-factory-review.js`:208 — The comment at line 206 says SENSITIVE covers 'ship surfaces', but the list matches only `fastlane/metadata/`. `fastlane/Fastfile` and `fastlane/Appfile` are on the live Studio ship path: `.github/workflows/studio-testflight.yml:107` runs `fastlane ios setup_signing` with the App Store Connect key, and that lane (`fastlane/Fastfile:133`) revokes and recreates signing certificates. If an interleaved commit outside the job's paths edits the Fastfile, the round produces no sensitiveOutside or scopeOpen row.
   - Vorschlag: Add `/^fastlane\/(Fastfile|Appfile)$/` to SENSITIVE, plus one OUTSIDE entry in the selftest.
3. **minor** `Tests/CISmoke/TheFactoryReviewersAreReadOnlyTests.swift`:196 — AC1 says the board.json base check is proven by 'Selbsttest-Fall und TheFactoryReviewersAreReadOnlyTests Anspruch 7'. Claim 7 (lines 196-206) checks only the three `git show ${a.base}:` needles and never reads the `git show ${head}:${jobDir}/board.json` sentence. That sentence is pinned only by the selftest (factory-review-selftest.py:136, mutation row :315), and no CI gate runs the selftest. The spec therefore attributes this half of AC1 to a gate that does not check it.
   - Vorschlag: Either add the needle `Confirm that \`git show ${head}:${jobDir}/board.json\` records base ${a.base}` to claim 7, or reword AC1 so the board check cites only the selftest.
