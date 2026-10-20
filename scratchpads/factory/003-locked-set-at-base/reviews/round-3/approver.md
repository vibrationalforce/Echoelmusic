# Runde 3 — approver

Workflow `wf_c8778d4d-f9a`, Bereich `f61d7872d..61d2d1e37` (Nacharbeit seit `6d168b44a`) mit den acht `paths` aus `board.json`, `criteria` 10, `deviceCriteria` [], `founderAssumptions` 0. Gesamtentscheidung: **ESCALATE** — rework cap of 2 reached with 3 open finding(s). `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Außerhalb von `paths`: die drei `docs/dev`-Dateien aus `532e5b169`, nicht sensibel.

Approver: **ESCALATE**. Eigene Zählung der Spec: `specCriteria` 10, `specDevice` [], `specFounder` 0 — gleich den Zahlen des PM.

## Warum

This job has to escalate for two reasons. The rework cap is reached with three open majors, and it edits the factory's own judge (.claude/workflows/echoel-factory-review.js).

Checks I made:
- board.json at 61d2d1e37 records base f61d7872d, so the range covers the whole job.
- I took the locked set from the base (hook PROTECTED_FILES = .claude/settings.json and .mcp.json, PROTECTED_DIRS empty; permissions.ask = the same two files plus .claude/hooks/**; context.md §3 = .github/workflows/**, project.yml and Resources/iOS/Info.plist). No locked file appears in the unscoped list of changed files.
- The three docs/dev files from commit 532e5b169 lie outside the job's paths and are not locked.
- The diff changes no CLAUDE.md and nothing under .claude/rules/.

My own count of the spec: 10 numbered criteria, no criterion tagged [DEVICE], and no Assumption tagged [FOUNDER]. Assumption 5 mentions both tags only inside its text; it is not tagged.

Rule-by-rule against the base: most rules got stricter.
- kindOf now needs both the PM's list and the approver's label for 'device'.
- An Assumption entry (number 0) needs a dated record.
- The locked set is read at the job base.
- A lock-config change skips the rework exit.
- A judge edit never approves.

Two rules got looser (I read both in the code; the lenses reproduced both with stub agents):
- (a) Two count checks now run before the escalation steps: the spec-count check and the graded-set check. Both return RERUN. At the base, once the approver returned any acceptance entry, the cap, or an approver ESCALATE, always escalated. At head a count mismatch turns those escalations into a RERUN, and a re-call on a new head could get past the cap. A lock change is not exposed this way, because it stays in the base..head range and escalates on the next call.
- (b) A numbered criterion that the approver labels 'founder' and marks met now counts as met code. At the base, a set of entries that were all founder-labelled hit the RERUN floor ("no code criterion met").

One check the base had was removed: INVALID when any lens reports filesInScope 0. Its replacement, the empty-list RERUN, has a gap: unquote runs after the empty-name filter, so a lens list of '""' passes.

Other measurements:
- `python3 -I -B scripts/factory-review-selftest.py` printed "all cases match".
- The lenses report 76/76 mutations caught for the workflow selftest and 16/16 for factory-board.py.
- Gates on head 61d2d1e37 were still running when the lenses looked, and I did not check them. So guard claims 7-9 are transcribed only: not compiled, not run.

I graded criterion 3 as met despite the '""' gap, and criterion 8 as met despite three small SKILL.md drifts; the UX lens lists them.

## Abnahme

- **1** (code, erfüllt) — The head workflow's approver prompt contains `git show ${a.base}:` for all three files and the sentence "Confirm that `git show ${head}:${jobDir}/board.json` records base ${a.base}"; the prompt I received shows both. Selftest scripts/factory-review-selftest.py:142-144. Guard Tests/CISmoke/TheFactoryReviewersAreReadOnlyTests.swift:204-213 (testTheApproverReadsTheLockAtTheJobBase). The selftest prints "all cases match".
- **2** (code, erfüllt) — In the head workflow, lockChanged gives ESCALATE in the decision ladder, ahead of the approver's decision, and lockChanged skips the rework exit. The name list runs with --no-renames and quotePath=false, and one pair of quotes is stripped. Selftest scripts/factory-review-selftest.py:197-206 (the four lock files, a quoted hook name, and the local settings outside the paths). Guard claim 8 is at TheFactoryReviewersAreReadOnlyTests.swift:225-266. Caveat: a count mismatch is checked first and returns RERUN. That is not an APPROVE, and the lock file stays in base..head, so it escalates on the next call; see forTheHuman (a).
- **3** (code, erfüllt) — The head workflow has the noList, garbled, all-empty INVALID, blind-lens, all-outside INVALID and missing-lens branches, and returns sensitiveOutside. The selftest section '-- scope from changedFiles --' starts at scripts/factory-review-selftest.py:169, and all cases match. Caveats (minor, not founder-level): a lens list of '""' passes the empty check because unquote runs after the filter; C1 controls and U+2028 pass the control-character regex.
- **4** (code, erfüllt) — Head workflow: the required checks for criteria and founderAssumptions (lines ~155-172); the disagree block comparing specCriteria, specDevice and specFounder (~366-376); the ungraded/surplus/founderEntries check; kindOf (~399); citesRecord with FOUNDER_INBOX|memory/decisions.md plus a date; founderLabelled. The prompt I received reads "The PM reports 10 ... Do not take these numbers from the PM". Selftest '-- counted acceptance --' starts at scripts/factory-review-selftest.py:230. This follows the spec's own rule that everything except number 0 is code; the floor that loosened relative to the base is in forTheHuman (b).
- **5** (code, erfüllt) — The block I received is ASCII: every '--' is written '--' and every non-ASCII character as \uXXXX. The head workflow passes the reviews and the lens file names through ascii(); the security lens confirmed that names go through ascii() in the approver prompt. The fence cases start at scripts/factory-review-selftest.py:259, and all cases match.
- **6** (code, erfüllt) — Head workflow, line 152: 'since is the previous round head; round 1 has none'. Selftest scripts/factory-review-selftest.py:93 (since in round 1), :114 (paths '.') and :117 (paths with //), all INVALID; all cases match.
- **7** (code, erfüllt) — `python3 -I -B scripts/factory-board.py --open` runs on the real scratchpads/factory without error. The code-reviewer lens confirmed scope_problem and the null/number boards (023/024) and the fullmatch on DATE and REVIEWED. The e2e lens measured --selftest exit 0 and --mutate 16/16.
- **8** (code, erfüllt) — .claude/skills/factory/SKILL.md:89-100 (judge version taken from the base, from job 004 on; CLAUDE.md and .claude/rules/ not covered); :166-168 (locked set at the base, §3 compared); :178-208 (the gate-run rule including the files a guard reads, 'kein Lauf', website done on main); :214 (verified date); :262-263 (FEATURE_STATUS.md). The code-reviewer lens measured doctor.py --section B with 0 critical findings. Minor drifts are still open, none founder-level: the omitted-deviceCriteria sentence at :79, the approver-run sentence at :266, the reviewedBy template at :247, and the guard read example at :182.
- **9** (code, erfüllt) — I ran `python3 -I -B scripts/factory-review-selftest.py`: 'all cases match'. I did not run --mutate myself, because it writes temp files. Two lenses report --mutate 76/76 caught with 0 stale (code-reviewer, run in memory) and factory-board --selftest exit 0 with --mutate 16/16 (e2e-test-agent).
- **10** (code, erfüllt) — Head workflow: the judgeChanged ESCALATE branch comes before APPROVE. JUDGE_FILES and JUDGE_DIRS feed isJudge. Guard claim 9 is at TheFactoryReviewersAreReadOnlyTests.swift:279-300. Selftest scripts/factory-review-selftest.py:221-229 (judge edit -> ESCALATE, lens-definition edit -> ESCALATE, unmet criterion or open finding still reworks, lookalikes are not the judge). SKILL.md:89-91 covers job 004.

## Fragen an den Founder (vom Approver)

1. Job 003 reached the rework cap with three majors still open. Do you accept it as it stands, a stricter judge than the base with the gaps written down, and carry the open findings into job 004? Or should it be undone? This depends on GM27 (docs/dev/FOUNDER_INBOX.md:146, still open), under whose delegation job 003 was started.
   - Empfehlung: Accept job 003 and answer GM27 yes. Open job 004 for: (a) the escalation order, (b) the founder-label floor, the '""' unquote order, the C1/U+2028 control characters, the anchoring order in the approver prompt, a tie-break for a repeated count disagreement, fastlane/Deliverfile in SENSITIVE, and reading spec.md at the head sha. Job 004 is then reviewed by job 003's judge taken from the base. Almost every rule is stricter than at f61d7872d, the change is pipeline-only and reversible, and an APPROVE never merges.
   - Warum deine: The cap is the factory's own stop rule, and per SKILL.md an escalation there goes to the founder. The change also edits the factory's judge, which cannot approve itself.
2. Loosened rule (a), compared with the base: the new spec-count RERUN and graded-set RERUN now run before the escalation ladder. At f61d7872d, once the approver returned any acceptance entry, the rework cap and an approver ESCALATE always escalated. At head, a count mismatch returns RERUN first, and the approver's founder question survives only inside the returned approver object. A re-call on a new head after fixes could therefore get past the cap, which amounts to a third rework that SKILL.md forbids. Should the escalation order be restored?
   - Empfehlung: Yes. In job 004, check capReached, lockChanged, approver.decision === 'ESCALATE' and forTheHuman before the two count checks. If any of them holds, return ESCALATE and put the disagreement into reason. Add selftest cases for a miscount at the cap and a miscount with a lock change, plus a mutation row.
   - Warum deine: The instruction for this review requires every removed or loosened rule of the edited judge to reach the founder, and this one weakens the rework cap, the factory's own stop rule.
3. Loosened rule (b), compared with the base: a numbered criterion that the approver labels 'founder' and marks met now counts as met code, with no dated record. At the base, if every met entry was founder-labelled, the round hit the RERUN floor ('no code criterion met'). At head the same answer gives APPROVE (code-reviewer, measured on both copies; the head selftest pins it at scripts/factory-review-selftest.py:253). Should such an entry pass only on a dated record and never count as code evidence?
   - Empfehlung: Yes. Exclude kind 'founder' from metCode, and treat a met numbered founder-labelled entry without a FOUNDER_INBOX/decisions.md record and date as founderOpen. Flip selftest case 253 and add mutation rows.
   - Warum deine: This is a loosened rule of the edited judge, which the review instruction sends to the founder. It also governs what counts as founder evidence.
4. Removed rule, compared with the base: the INVALID for any lens reporting filesInScope 0 is gone, replaced as AC3 asks by the workflow computing the scope from changedFiles, with a RERUN for an empty list. In the replacement, unquote runs after the empty-name filter, so a lens list of '""' gets past both the all-empty INVALID and the blind-lens RERUN (code-reviewer probed it: APPROVE path). Is fixing this in job 004 acceptable instead of now?
   - Empfehlung: Yes, in job 004: unquote first, then filter empty names, and add a selftest case where ['""'] gives RERUN. git never prints such a name, so the risk is a lens that did not run the name list, not an attack.
   - Warum deine: This is a removed rule of the edited judge, which the review instruction sends to the founder.
