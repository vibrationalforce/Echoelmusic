# Runde 3 — code-reviewer

Workflow `wf_c8778d4d-f9a`, Bereich `f61d7872d..61d2d1e37` (Nacharbeit seit `6d168b44a`) mit den acht `paths` aus `board.json`, `criteria` 10, `deviceCriteria` [], `founderAssumptions` 0. Gesamtentscheidung: **ESCALATE** — rework cap of 2 reached with 3 open finding(s). `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Außerhalb von `paths`: die drei `docs/dev`-Dateien aus `532e5b169`, nicht sensibel. Urteil der Linse: **CHANGES**.

## Zusammenfassung

Code lens, round 3, range f61d7872d..61d2d1e37 (rework since 6d168b44a), with the eight paths from board.json. The commit 532e5b169 (three docs/dev files) is not part of this job.

Round-2 findings, checked against 61d2d1e37. Every one is fixed:
- founderAssumptions is now required (workflow 168-172, selftest 101).
- The approver reports its own count as specCriteria, specDevice and specFounder, and any mismatch is RERUN (367-376).
- A criterion is device only when the PM's list AND the approver's label say so (399).
- An unmet numbered criterion labelled founder escalates (411, 426).
- Boards with "scopeOpen": null and "deviceOpen": 5 are reported (board 023/024).
- DATE and REVIEWED use fullmatch, and a reviewer job must be in stage done (65, 77).
- Claim 8 needs the hook half on its own and fails on a file rule it cannot read (Swift 241-255).
- Claim 7 pins the board.json needle (213). The needle count is 0 at f61d7872d and 9237c3c91 and 1 at 6d168b44a and 61d2d1e37, as the guard header says.
- SKILL.md has the run rule for guards (178-185), founderAssumptions in step 7, and the three counts in the board.json template.
- quotePath, settings.local.json, the CLAUDE.md/rules prompt lines and Fastfile/Appfile are all in.

What I measured:
- `python3 -I scripts/factory-review-selftest.py` exits 0.
- Its 76 mutation rows, run in memory (source passed through an env var, no temp file): 76/76 caught, 0 stale.
- `doctor.py --section B`: 0 critical findings.
- I probed the board functions read-only against the real scratchpads/factory.
- I probed the edited workflow with stub agents. For the rule comparison I ran the base copy (`git show f61d7872d:`) on the same answers.

New findings: one major and two minors.
- The major is a rule loosened relative to the base. The base's floor "no code criterion met, so RERUN" no longer holds when the approver labels numbered criteria 'founder'. A numbered criterion labelled founder, met:true, with no record now counts as code-met. Measured on the same approver answer: base RERUN, head APPROVE. This also contradicts AC4, which says a met founder entry without a dated record stays open.
- Minor 1: unquote runs after the empty-name filter, so a lens list of `""` defeats both the all-empty INVALID and the blind-lens RERUN.
- Minor 2: the new exact-equality count check has no way out when the approver keeps miscounting. "Tagged [FOUNDER]" is not defined by position, and this job's own spec mentions the tag inside an Assumption.

Housekeeping: loading the two scripts through importlib refreshed scripts/__pycache__/factory-board.cpython-313.pyc and factory-review-selftest.cpython-313.pyc. The directory is gitignored and already existed; I deleted nothing. The CI gates on 61d2d1e37 (Xcode Compile Check, CI/CD) were still in progress when I checked, so the Swift edit to claim 8 is transcribed, not compiled.

## Befunde

1. **major** `.claude/workflows/echoel-factory-review.js`:406 — This rule is loosened relative to the base workflow. At f61d7872d (kindOf, base line 269), an entry labelled 'founder' never counted toward metCode. So an approval whose only met entries were founder-labelled hit the floor `!metCode.length` and returned RERUN with 'no code criterion met with evidence' (base 291-294). At head, kindOf (line 399) turns every numbered founder-labelled entry into 'code'. metCode (line 406) then counts it when met:true, and founderLabelled (line 411) catches only the unmet case. I measured the same approver answer, criteria 1 and acceptance [{number:1, kind:'founder', met:true, evidence:'the founder said so'}], on both copies: base RERUN, head APPROVE ('all 1 criteria graded, every code criterion met'). The approver itself marks the evidence as a founder decision, yet with no dated record the entry passes as code proof. That contradicts AC4 ('ein erfüllter founder-Eintrag ohne Verweis auf FOUNDER_INBOX oder memory/decisions.md samt Datum bleibt offen') and the head's own citesRecord rule (lines 402-404). The selftest pins the loosened behaviour as intended: scripts/factory-review-selftest.py:253, 'a founder label on a numbered criterion is code (met -> APPROVE)'.
   - Vorschlag: Let a numbered founder-labelled entry pass only on a dated record, and never count it as code evidence. Use `const founderLabelled = acceptance.filter(c => c.number >= 1 && c.kind === 'founder' && !(c.met === true && citesRecord(c)))`, and add `&& c.kind !== 'founder'` to metCode, which restores the base floor. Flip selftest case 253 to RERUN (or ESCALATE without a record), add a case with no record that must ESCALATE, and add a mutation row for each change.
2. **minor** `.claude/workflows/echoel-factory-review.js`:269 — The empty-name filter runs BEFORE unquote: `.filter(f => typeof f === 'string' && f.trim()).map(f => unquote(f.trim()))`. A lens entry `""` (a bare pair of quotes) passes the filter and then becomes the empty string. The list is then non-empty, so the all-empty INVALID (line 275) and the blind-lens RERUN (line 277) are both skipped. Probed with stub agents: every lens returns ['""'] → APPROVE; one lens returns ['""'] while the others return real lists → APPROVE, where an empty list gives RERUN. git never prints such a name, so this is a lens that did not run the name list but is not caught as one.
   - Vorschlag: Unquote first and filter after: `.map(f => typeof f === 'string' ? unquote(f.trim()) : '').filter(f => f.trim())`. Then add a selftest case: a lens whose list is ['""'] gets RERUN, the same as an empty list.
3. **minor** `.claude/workflows/echoel-factory-review.js`:372 — The new spec-count check is exact equality (specCriteria/specDevice/specFounder against the PM's numbers). On a mismatch the workflow returns RERUN, and the SKILL tells the PM to recount and call the same round again (.claude/skills/factory/SKILL.md:84-85). Nothing says what happens when the PM's recount still differs from the approver's, so a wrong approver count loops RERUN with no exit. Such a miscount is plausible because 'tagged [FOUNDER]' is defined by no position (SKILL.md:43, approver prompt 333-336). This job's own spec mentions `[FOUNDER]` and `[DEVICE]` inside an Assumption bullet that is not a founder assumption (scratchpads/factory/003-locked-set-at-base/spec.md:21-25). Before this round a surplus founder entry was harmless, because the check was `>=`.
   - Vorschlag: Define the tag by position in SKILL.md step 2 and in the approver prompt, for example 'an Assumption whose bullet starts with [FOUNDER]', and the same for criteria starting with [DEVICE]. Also state the tie-break in SKILL.md step 4: a second disagreement on the same head escalates to the founder instead of rerunning again.
