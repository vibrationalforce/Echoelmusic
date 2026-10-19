# Runde 2 — e2e-test-agent

Workflow `wf_6970a9ab-570`, Bereich `9c0677f03..0b0e8339b` (ohne `paths`), Urteil der Linse: **CHANGES**.

## Zusammenfassung

Ship-path review of job 001, round 2. The job's own commits are 38d840ae8 and 0b0e8339b. The range 9c0677f03..0b0e8339b also contains 1814d6b10 (research notes) and 08ded356a (job 002: two .entitlements files and EchoelStudio/project.yml). This round was called without `paths`. I did not grade 08ded356a here because job 002 has its own review loop. A quick consistency check found no problem: group.com.echoelmusic.shared is the same string in both entitlements files and in PluginUnlock.swift:22, and both targets' CODE_SIGN_ENTITLEMENTS point to their files (EchoelStudio/project.yml:85 and :123).

Round-1 findings:
- 1 (major, founder-locked list): fixed. echoel-factory-review.js:221-224 now reads `.claude/rules/context.md` §3 plus PROTECTED_FILES (`.claude/settings.json`, `.mcp.json`) and asks for a dated record of any release. A small session-scope gap remains (finding 3).
- 2 (head must be a sha): fixed. The SHA regex is at :132 and :136, and every return value carries `range`.
- 3 (when a job counts as done): fixed in SKILL.md step 6, with two gaps left (finding 2).
- 4 (when the guard runs): fixed at TheFactoryReviewersAreReadOnlyTests.swift:31-34.

Measured:
- I re-implemented the guard's claims 1-6 in Python and ran them against both trees (9c0677f03 and 0b0e8339b). All pass on both. Claim 6 is a counterweight, as its header says.
- `python3 -I scripts/factory-review-selftest.py`: "all cases match", exit 0 (node v22.22.0).
- `scripts/factory-board.py --selftest`: exit 0.
- `.claude/`, `Tests/` and `scripts/` are unchanged from 0b0e8339b to the current HEAD edb5a5d7b.
- Neither job-001 commit changes a target, an entitlements file, Info.plist or a project.yml.

Gates:
- 38d840ae8 touches `Tests/**`, so ci.yml, xcode-compile-check.yml and auto-merge-claude.yml do trigger. No run exists on 38d840ae8 or 0b0e8339b themselves; they were pushed together with edb5a5d7b.
- On edb5a5d7b, Xcode Compile Check 39338612342 is in progress and CI/CD 39338612322 is queued. Claim 6 has not run anywhere, so ship status is UNPROVEN.
- The previous version of the guard compiled: CI/CD 39336698967 on 1814d6b10 has `Build for Testing` = success, and its Run Tests step is still in progress.
- Auto-Merge 39336698924 on 1814d6b10 failed with a merge conflict in docs/sitemap.xml. That file is not in this diff, but the branch is not reaching main at the moment.

One major finding: the new `paths` option also narrows the approver's founder-locked-file check, and a misspelled or empty scope yields a review of nothing that passes.

## Befunde

1. **major** `.claude/workflows/echoel-factory-review.js:159` — `paths` scopes everything the agents see, including the safety checks. Line 159 builds the suffix ` -- p1 p2`. It is appended to every lens's `git log`/`git diff` (line 168) and to the approver's diff (line 206). The approver then applies its founder-locked-file rule (221-224) to that scoped diff only. Two failure modes follow. (1) A misspelled or non-matching path produces an empty diff with exit 0. Measured: `git diff 9c0677f03..0b0e8339b -- .claude/skill/factory` prints 0 bytes and exits 0. Each lens is told to 'Review ONLY what this diff changes', so it finds nothing and is graded PASS. The approver checks the acceptance criteria against the repo and can APPROVE. That is a missing review dressed as a pass, which the workflow forbids everywhere else (RERUN at :192-195). (2) Any job file left out of the list bypasses all lenses and the locked-file rule. This range shows the risk: 08ded356a changes EchoelStudio/Support/App/EchoelStudio.entitlements, EchoelStudio/Support/Plugins/EchoelPlugins.entitlements and EchoelStudio/project.yml. A job-002 scope of `EchoelStudio/App EchoelStudio/Plugins` would hide both entitlements files from the ship-path lens. A `.github/workflows/**` change outside the listed paths would reach auto-merge-claude.yml, whose trigger includes `.github/workflows/**`, without ESCALATE. The scope also leaves no trace in the record. Every return value (:194, :198, :236, :264) carries `range` but not `paths`, and the board.json schema (SKILL.md:108) has no `paths` field. A scoped round's reviews/round-N/*.md therefore reads like a review of the full range.
   - Vorschlag: In both prompts, have each agent first run `git diff --name-only ${range}` without the scope and then with it. An empty scoped list is a blocker finding (or have the approver return RERUN). Changed files outside the scope go into the summary. The approver applies the founder-locked rule to the UNSCOPED name list; an interleaved job's locked file then surfaces as a question, which is the safe direction. Echo `paths` in every return object, add `paths` to the board.json schema, and add a selftest case asserting that the approver prompt contains the unscoped `--name-only` command.

2. **minor** `.claude/skills/factory/SKILL.md:89` — The done rule in step 6 has two gaps. (a) It says the gate reading 'steht in Tests/CISmoke/CLAUDE.md §5', but §5 covers only the old app; `grep -i studio Tests/CISmoke/CLAUDE.md` finds one unrelated line 34. The Studio reading lives in EchoelStudio/CLAUDE.md under 'Verifying'. Also, `EchoelStudio/ = Workflow Echoel Studio` overstates that gate: both app builds in studio.yml (iOS Simulator Debug and device Release) pass `CODE_SIGNING_ALLOWED=NO`. A green run therefore proves nothing about entitlements, App Groups, provisioning profiles or upload checks, which is exactly what job 002 changes. Only studio-testflight.yml signs, and job 002's own spec notes that even a signed build failed only in the host with -3000. (b) 'ein neuer Wächter erst, wenn scripts/gh-test-verdict.py ihn nennt' has no way out. Per §5 (#807/#445) the job log is the tail of test.log (`tail -200`), a name absent from it proves nothing, and re-running does not change the window. For a guard outside the window the condition can never be met, which pushes the PM to round it up.
   - Vorschlag: Point the EchoelStudio/ case at EchoelStudio/CLAUDE.md 'Verifying'. State that `Echoel Studio` is an unsigned compile plus tests, and that an entitlements, App Group or profile change needs a signed studio-testflight.yml archive plus a device check, recorded as a `deviceAsks` entry. For an old-app guard missing from the WINDOW, record 'kompiliert nachweislich, Ausführung unbelegt' (§5) rather than 'done' or 'green'.

3. **minor** `.claude/workflows/echoel-factory-review.js:223` — 'A release of a locked file counts only when memory/decisions.md or docs/dev/FOUNDER_INBOX.md records it with a date' accepts any dated record, whatever its scope. The only release on record for the studio workflows is session-scoped: memory/decisions.md:5482 says 'unter dem Standing „EchoelStudio-Workflows und Plist sind für die Sitzung frei“'. An approver in a later session can cite it word for word as a standing release. That is the residual of round-1 finding 1(a): a one-session release turned into a permanent one.
   - Vorschlag: Add one clause: the cited record must show that the release still covers this file now. A release limited to a session or a task does not count outside it; in that case, ESCALATE.
