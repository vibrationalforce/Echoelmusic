# Runde 3 — ux

Workflow `wf_c8778d4d-f9a`, Bereich `f61d7872d..61d2d1e37` (Nacharbeit seit `6d168b44a`) mit den acht `paths` aus `board.json`, `criteria` 10, `deviceCriteria` [], `founderAssumptions` 0. Gesamtentscheidung: **ESCALATE** — rework cap of 2 reached with 3 open finding(s). `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Außerhalb von `paths`: die drei `docs/dev`-Dateien aus `532e5b169`, nicht sensibel. Urteil der Linse: **PASS**.

## Zusammenfassung

UX/claims lens, round 3, range f61d7872d..61d2d1e37, rework since 6d168b44a. I did not run the selftests (the task allowed no file creation); every claim below was checked by reading the source.

Earlier UX findings are all fixed.
- Round-2 major: `founderAssumptions` is now required (workflow:168-169, selftest case "founderAssumptions absent -> INVALID"). The sentence "No Assumption is tagged [FOUNDER]." is gone. The prompt now gives the PM's numbers as the PM's report and asks the approver to count the spec itself (workflow:332-336). The workflow compares the two counts and returns RERUN on a mismatch (workflow:366-375).
- Round-2 minor: step 7 now names `founderAssumptions` (SKILL.md:232), and the board.json template carries all three counts (SKILL.md:245). Job 003's board.json now records `founderAssumptions` 0.
- Round-1 minors: confirmed fixed in round 2 and still in place (wider SENSITIVE list, strict `reviewedBy`, FEATURE_STATUS.md taken out of the "internal sentence" exemption).

Rule comparison against the base, required because the diff edits the workflow. I found no removed or loosened rule:
- The base kindOf trusted the approver's label alone. The head needs both the PM's list and the label for `device`, makes number 0 `founder`, and escalates an unmet numbered criterion labelled `founder`.
- The base read the locked set from the tree under review. The head reads it at the job base.
- The lock configuration now skips the rework exit and escalates, which is stronger than the base.
- Every new check (count mismatch, a lens with no list or an empty list, control characters in a name) ends in RERUN, INVALID or ESCALATE, never in APPROVE.
- The diff changes no CLAUDE.md and nothing under .claude/rules/.

New claims I checked against the repo:
- `fastlane/Fastfile` (setup_signing lanes) and `fastlane/Appfile` exist.
- `.claude/settings.local.json` is gitignored (.gitignore:132) and untracked.
- The guard's `text(` calls exist.
- Inbox row GM27 exists and is open.
- The decision order in SKILL.md step 6 matches workflow:416-445.

The diff is pipeline-only. It touches no app UI, Sources/ copy, website or store text, so VoiceOver, Dynamic Type, contrast, the 3 Hz flash limit, Uncodixfy and EchoelValueField do not apply. "health" appears only as a category label for sensitive files. There is no wellness or esoteric wording.

Five new minors: four places where SKILL.md, the workflow comment or the template drifted from the code, and one place where the approver is shown the PM's numbers before it counts (anchoring). None is blocking. This job also escalates by design under rule 6, because it edits the workflow that reviews it.

## Befunde

1. **minor** `.claude/skills/factory/SKILL.md`:266 — The 'Wann nicht' cost sentence says the approver runs 'only in the round without open findings or at the cap'. This job added a third case: a change to the lock configuration skips the rework exit and goes to the approver while findings are still open and rounds remain (workflow:301-302, `&& !lockChanged.length`; selftest case 'lock config skips the rework exit'). The sentence predates the job, but the job made it untrue. Criterion 8 asks SKILL.md to say what the workflow does.
   - Vorschlag: Append 'oder wenn der Diff die Sperr-Konfiguration ändert' to the approver clause.
2. **minor** `.claude/skills/factory/SKILL.md`:79 — Step 4 says an omitted `deviceCriteria` makes every criterion `code`, 'die strenge Lesart'. The workflow comment says the same at workflow:158. Since this rework, an omitted list defaults to [], and workflow:371 compares it with the approver's `specDevice`. On a spec that tags any criterion [DEVICE], the result is RERUN ('[DEVICE]: PM [], approver [n]'), not code grading. The sentence is true only for a spec with no [DEVICE] tag.
   - Vorschlag: In both places, say 'fehlt sie, gilt []; trägt die Spec ein [DEVICE], ist das eine Zählabweichung (RERUN)'. Optionally add a selftest case with deviceCriteria omitted and specDevice [2].
3. **minor** `.claude/workflows/echoel-factory-review.js`:401 — For an unmet numbered criterion that the approver labels `founder`, the log line prints 'criterion N labelled founder, graded as code'. But lines 411 and 426 escalate that criterion as a founder item, and line 448 returns it in `founderOpen`. The PM reading the run sees 'graded as code' next to an ESCALATE that counts the same criterion as a founder criterion.
   - Vorschlag: Leave founder-labelled unmet numbered criteria out of this log, or log them as 'labelled founder on a numbered criterion: escalates as a founder question'.
4. **minor** `.claude/workflows/echoel-factory-review.js`:332 — The approver prompt gives the PM's three numbers in the line just before it asks for an independent count (333-334). The workflow already compares the two counts itself (366-375), so the approver does not need the PM's numbers. Showing them anchors the count it is meant to check: an approver that echoes them back makes the comparison PM against PM. SKILL.md:82-85 ('der Approver zählt die Spec selbst') describes a blind count, and this one is not blind. Spec criterion 4 currently requires naming the numbers as the PM's claim, so a change here needs the spec changed too.
   - Vorschlag: Either leave the PM's numbers out of the prompt and ask only for specCriteria/specDevice/specFounder (the orchestrator compares), or keep them and state in SKILL.md that the count is not blind.
5. **minor** `.claude/skills/factory/SKILL.md`:247 — The board.json template still says `reviewedBy` is '<Nummer eines anderen Jobs oder founder JJJJ-MM-TT>'. Lines 222-224 and 254, and factory-board.py scope_problem, now require another job that is DONE. A PM who copies the template can name a job that is still in spec or review, and the board then reports a finding.
   - Vorschlag: Change the template value to '<Nummer eines anderen, fertigen Jobs oder founder JJJJ-MM-TT>'.
