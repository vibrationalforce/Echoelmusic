# Runde 3 — e2e-test-agent

Workflow `wf_c2619890-b9f` — Prüfer-Fassung von der Job-Basis (`73e9ae52d`), Bereich `73e9ae52d..d5682ae4d` (Nacharbeit seit `aeb77953d`) mit den sechs `paths` aus `board.json`, `criteria` 10, `deviceCriteria` [], `founderAssumptions` 1. Gesamtentscheidung: **ESCALATE** — rework cap of 2 reached with 2 open finding(s). `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Außerhalb von `paths`: `scratchpads/factory/001-factory-loop/reviews/round-3/security-agent.md` (`108fa2da7`), nicht sensibel. Urteil der Linse: **PASS**.

## Zusammenfassung

Round 3 ship-path review of job 004, range 73e9ae52d..d5682ae4d (rework since aeb77953d). The diff touches 18 files. One of them, scratchpads/factory/001-factory-loop/reviews/round-3/security-agent.md, lies outside paths and is not sensitive. The diff touches no target, entitlements file, Info.plist, project.yml, .github/, fastlane/, Gemfile, Resources/ or EchoelStudio/ file (grep over the name list: 0 hits).

Round-2 findings, checked at the head:
- My round-2 major (the approver's count was not blind) is fixed.
  - The prompt at workflow:364-368 says COUNT IT FIRST and names no PM number.
  - The approver's diff uses approverScope (workflow:200), which excludes board.json and reviews/. I ran the same pathspec with git on this job: it drops board.json and every reviews/ file and keeps spec.md.
  - board.json is read for its base field only (workflow:406).
  - spec.md:21-25 and SKILL.md:93-97 now say the count is a second reading, not an independent measurement.
- My round-2 minor (the reason given for .github/actions/) is fixed at SKILL.md:265-266 and spec.md:30-31. I verified the new reason:
  - setup-xcodegen runs in the signing jobs at testflight.yml:341 (ios) and studio-testflight.yml:69, before the ASC key is written in the same job.
  - It also runs in ci.yml, pr-check.yml, full-tests.yml and xcode-compile-check.yml.
  - setup-asc-api-key is used by no workflow.
- The code major is fixed: capReached is now computed at line 271, before the name RERUN at line 304, which yields to the cap and to a lock change.
- The security major is fixed: line 282 no longer trims, and `hidden()` at line 299 catches padding.
- The minors are fixed:
  - Default_Ignorable code points and Zs spaces are in the class.
  - shownNames() is used at lines 494 and 499.
  - garbled is in scopeInfo and in a 'name check:' note.
  - The cost sentence, the token sentence, the order comment, the rule-4 parenthetical and the INDEX wording are corrected.

Rule comparison against `git show 73e9ae52d:.claude/workflows/echoel-factory-review.js`: no rule is removed or loosened.
- At the base, every C0 name was a RERUN. At the head it becomes an ESCALATE with a note at the cap or next to a lock change.
- The base never escalated a disguised name, and the head adds that.
- The base approved a met criterion labelled founder as code; the head now requires a dated record.
- SENSITIVE gains .github/actions/, Gemfile, Deliverfile and Pluginfile.
- The approver's diff now leaves out the job's own board and protocols. AC4 asks for this. Those files are not compiled into any target, and the lenses still see them.

What I ran (no repo file written):
- `python3 -I scripts/factory-review-selftest.py`: exit 0, all cases match.
- Every MUTATIONS row, applied in memory and fed to node through a pipe: 116 of 116 caught, none stale.
- Guard claim 10 transcribed in Python on comment-stripped code:
  - Red at 73e9ae52d: no `if (escalation) {` anchor, and every needle except the metCode counterweight fails.
  - Red at aeb77953d only at the new name-yields needle.
  - Green at the head: cap defined before the name RERUN, and both Approve-phase RERUNs after `if (escalation) {`.
- `doctor.py --section B`: 0 critical.
- Token check: `git log --full-history` over the range = 0, and `rev-list --objects | grep settings.local.json` = 0.
- No tracked name (out of 3247) hits the hidden class. The 12 non-ASCII names (umlauts, en dashes) stay ordinary.
- I did not run factory-board.py --selftest: it writes temp files, and the script is unchanged.

Gates on d5682ae4d:
- Xcode Compile Check: success. It compiles Sources/ only and proves nothing about the guard.
- CI/CD Build for Testing: success, so the edited guard compiles.
- CI/CD Run Tests: still in progress, so claim 10 is transcribed but not yet seen executing (unobserved, #445).
- Full Test Suite (non-blocking): in progress, and it proves nothing anyway (#208).
- No gate runs the JS workflow.
- Context outside this diff: Auto-Merge waited for both gates, then 'Merge to main' failed with Merge Status = conflict, as it did on aeb77953d. Nothing from this branch reaches main until that conflict is resolved.

New findings: two minors, no blocker or major.

## Befunde

1. **minor** `.claude/workflows/echoel-factory-review.js`:304 — A disguised name is one of the workflow's own fixed escalations, but a second hidden name can hold it in a RERUN. The workflow treats the disguised name as a fixed escalation: it is a fixedParts entry at line 354, the comment at 344-345 says so, and SKILL.md:133 says 'eskaliert er fest (Schritt 6, Regel 2)'. But the name RERUN at line 304 yields only to `lockChanged` and `capReached`, not to `disguised`. The comment at lines 293-294 says 'no file name can hold a fixed escalation in a RERUN loop', and SKILL.md:137 says 'kein Dateiname hält eine feste Eskalation in einer Schleife'. For the disguised part, both are false. Node probe on d5682ae4d: every lens reports scripts/a<U+200B>b.py, and ux also reports scripts/c<U+200B>d.py. Result: RERUN 'ux (a file name with an invisible character not every lens reports)', and the approver never runs. This holds in round 1, and also in round 3 with no open finding. The spec (AC6) asks only that the cap and the lock suppress the name RERUN, so the code meets the spec to the letter. The comment and the SKILL sentence claim more than the code does, and no selftest case covers a disguised name combined with a partially reported one.
   - Vorschlag: Either add `&& !disguised.length` to the condition at line 304 and add a selftest case plus a mutation for it. Or narrow the comment at 293-294 and SKILL.md:137 to say 'the cap or a lock change' instead of 'a fixed escalation'.
2. **minor** `.claude/skills/factory/SKILL.md`:339 — SKILL.md:339 still says 'der Approver zählt sie blind', which is left over from my round-2 major. The same file at SKILL.md:95-97, and spec.md:21-25, now say the count is 'Ganz blind ... nicht' and 'zweite Lesung, nicht unabhängige Messung'. The sentence sits in the description of what the selftest checks in the prompts, where 'blind' means only that the prompt names no PM number. That is true there, but the unqualified word contradicts the corrected paragraph 240 lines earlier, and AC8 asks for one consistent account. scripts/INDEX.md:59 already qualifies the word ('blind — keine Zahl des PM im Prompt —').
   - Vorschlag: Write 'der Approver bekommt keine Zahl des PM und zählt zuerst' (or the INDEX qualifier) instead of 'zählt sie blind'.
