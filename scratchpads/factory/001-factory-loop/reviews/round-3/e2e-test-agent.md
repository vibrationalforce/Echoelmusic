# Runde 3 — e2e-test-agent

Workflow `wf_74fa31d5-4ba`, Bereich `b1cfc8ad1..f209ecb16` mit `paths` (neun), `since` `0b0e8339b`, Dateien im Scope: 19. Urteil: **CHANGES**.

## Zusammenfassung

Ship-path review of job 001, round 3. Full range is b1cfc8ad1..f209ecb16, scoped by 9 paths; the rework is 0b0e8339b..f209ecb16. One new major finding, plus two minors.

All earlier findings from this lens are fixed:
- Round 1, findings 1-4: fixed in round 2.
- Round 2, finding 1 (major, `paths` hid files): fixed. Every lens now lists changed files twice, without and with the scope (echoel-factory-review.js:178-181). A lens that reports filesInScope = 0 makes the round INVALID (:203-204). The approver checks locked files against the unscoped list (:252). Every return object carries `paths` (:170). The selftest checks for the approver's unscoped command (factory-review-selftest.py:92).
- Round 2, finding 2: fixed. The EchoelStudio case points to EchoelStudio/CLAUDE.md "Verifying", which exists at line 73. The skill says an unsigned build proves no entitlement change. It covers a guard missing from the log WINDOW ("kompiliert, Ausführung unbelegt"). I checked studio.yml: it does pass CODE_SIGNING_ALLOWED=NO, and studio-testflight.yml does archive and sign. docs/CLAUDE.md §2 confirms the docs deploy path.
- Round 2, finding 3 (a session-scoped release counted as permanent): fixed at :253-255.

What I measured:
- I transcribed all six guard claims to Python and ran them against f209ecb16 and 0b0e8339b. All pass on both trees: 2 of 2 agent calls are wrapped, the clause appears exactly once, all 9 agentTypes are on the roster, and both files state the cap as 2.
- `python3 -I scripts/factory-review-selftest.py` printed "all cases match" and exited 0.
- `scripts/factory-board.py --selftest` exited 0.
- Those two runs used the working tree. The job files there are identical to f209ecb16.
- The scope covers every file touched by the job-001 commits: 9c0677f03, 38d840ae8, 0b0e8339b, f209ecb16, and inspiration.csv from 1814d6b10. The 36 files outside the scope belong to job 002, to research notes and to docs commits.
- None of the 55 changed files is a founder-locked path: no root project.yml, no .github/workflows/**, no Resources/iOS/Info.plist, no .claude/settings.json, no .mcp.json.
- The scoped diff changes no target, no entitlements file and no Info.plist.

Gates:
- f209ecb16 touches only .claude/, scripts/factory-*, scripts/INDEX.md, scratchpads/, memory/ and inspiration.csv. No workflow triggers on those paths, so the commit has NO run at all. That is neither green nor red.
- The final guard file has not changed since 38d840ae8, and it is part of edb5a5d7b. On that commit, Xcode Compile Check 39338612342 succeeded, but that gate builds Sources/ only and proves nothing about the guard. In CI/CD 39338612322 the step `Build for Testing` succeeded, so the guard compiles. Run Tests is still in progress, so its execution is unobserved (#445).
- The guard on edb5a5d7b scans the 0b0e8339b version of the workflow. The f209ecb16 version has been checked only by my transcription.
- Ship status: UNPROVEN until Run Tests finishes and gh-test-verdict.py names TheFactoryReviewersAreReadOnlyTests.

## Befunde

1. **major** `.claude/workflows/echoel-factory-review.js:251` — The approver's list of founder-locked files leaves out a path the repo gates, and the change under review can rewrite the list. (a) The prompt defines locked files as '.claude/rules/context.md §3 names plus PROTECTED_FILES in .claude/hooks/protect-founder-gated.py'. That misses `.claude/hooks/**`. `.claude/settings.json:35` asks before any edit there (`Edit(/.claude/hooks/**)`), and the hook says in its own docstring that its directory is not covered by the hook and that this gate is the founder's (protect-founder-gated.py:62-64; PROTECTED_DIRS = () at :50). A job that edits the hook can therefore be APPROVED without ESCALATE. (b) The prompt says 'read both' but not from which tree, so the approver reads the working tree, which already contains the change under review. Concrete case: one job drops `.mcp.json` from PROTECTED_FILES at protect-founder-gated.py:49 and edits `.mcp.json`. The approver then reads the edited tuple and finds no locked file. The same happens if a job adds an exception to context.md §3, which is the very place the round-1 fix pointed releases to. Neither settings.json `permissions.ask` (lines 32-35) nor PROTECTED_FILES contains any of the three §3 paths today, so this prompt is the only factory check on `.github/workflows/**`, `project.yml` and `Resources/iOS/Info.plist`. A change to `.github/workflows/**` reaches main through auto-merge-claude.yml, whose path filter includes it.
   - Vorschlag: Change one sentence of the approver prompt. Read the locked set as it stands at the job base: `git show ${a.base}:.claude/rules/context.md` (§3), `git show ${a.base}:.claude/hooks/protect-founder-gated.py` (PROTECTED_FILES and PROTECTED_DIRS) and `git show ${a.base}:.claude/settings.json` (`permissions.ask`). Also count any change to those three files, or to anything under `.claude/hooks/`, in the unscoped name list as itself locked. Add one selftest case asserting that the approver prompt contains `git show <base>:.claude/rules/context.md`. In SKILL.md step 2 ('gesperrte Dateien'), mirror the reference instead of restating the list.

2. **minor** `.claude/skills/factory/SKILL.md:118` — The round-2 fix overcorrects. '`scripts/**` gehört NICHT dazu' (it does not count as a no-run path) is false for every file in scripts/ except one. Xcode Compile Check's path filter names only `scripts/check-infoplist.sh` (xcode-compile-check.yml:19), and no other workflow filters on scripts/. So `scripts/factory-board.py`, `scripts/factory-review-selftest.py` and `scripts/INDEX.md`, the scripts this very job edits, start no run. Root files that this job's range also touches, such as `inspiration.csv` and `decisions.csv`, fall into no bucket at all. The rule also never says that the gate run must contain the job head. Measured on this job: f209ecb16 has no run, and the newest `Build for Testing` (CI/CD 39338612322 on edb5a5d7b) compiled the guard against the 0b0e8339b version of the workflow. A PM following step 6 either waits for a gate that never starts, or cites an older run as covering head.
   - Vorschlag: Write: 'kein Lauf = everything outside the gates' path filters: `.claude/**`, `scratchpads/**`, `memory/**`, root `*.csv`, and `scripts/**` except `scripts/check-infoplist.sh`'. Add one clause: a gate counts only from a run whose sha contains the job head; otherwise say 'kein Lauf auf <head>' and name the transcription.

3. **minor** `scratchpads/factory/001-factory-loop/spec.md:24` — Criterion 8, '[DEVICE] entfällt — die Scheibe berührt keine App' (does not apply: the slice touches no app), carries the tag that the new rule at echoel-factory-review.js:243 now reads literally ('kind device: only a criterion the spec tags [DEVICE]'). Under that rule the approver must file it as device with met false. APPROVE then reports '1 device request(s) for the next build's device round'. The PM writes a `deviceOpen` entry, and `factory-board.py --open` keeps this pipeline-only job open until someone dates a check that does not exist. The phantom ask would also land in a §2 device family whose Studio budget of five is already full (FOUNDER_INBOX.md:166-174, SP1-SP5).
   - Vorschlag: Drop the tag from the line ('8. Kein Geräte-Kriterium — die Scheibe berührt keine App.', i.e. no device criterion). Or state in SKILL.md step 2 that a non-applicable device line is written without `[DEVICE]`.
