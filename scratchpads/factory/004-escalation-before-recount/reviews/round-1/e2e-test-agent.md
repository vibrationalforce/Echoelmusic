# Runde 1 — e2e-test-agent

Workflow `wf_630b7969-cf1` — erstmals die Prüfer-Fassung von der Job-Basis (`git show 73e9ae52d:.claude/workflows/echoel-factory-review.js`, SKILL.md Schritt 4), nicht die des Jobs. Bereich `73e9ae52d..dcae95345` mit den sechs `paths` aus `board.json`, `criteria` 10, `deviceCriteria` [], `founderAssumptions` 1. Gesamtentscheidung: **REWORK** — 7 offene Befunde, Nacharbeit 1 von 2; der Approver lief nicht (die Fassung der Basis kehrt bei offenen Befunden vor ihm um). `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Außerhalb von `paths`: nichts. Urteil der Linse: **PASS**.

## Zusammenfassung

Ship-path review of job 004, round 1, over range 73e9ae52d..dcae95345. No blocker or major findings.

Rule comparison against the base copy of .claude/workflows/echoel-factory-review.js: no rule was removed or loosened.
- The decision chain keeps its order: cap/lock, then approver ESCALATE, then founder/questions, then unmet code, then no met code, then judge, then APPROVE.
- Every base RERUN for a missing approver, a count mismatch, an empty acceptance list or a wrongly graded set is still a RERUN, or is now an ESCALATE.
- A founder label on a numbered criterion no longer counts as metCode, and it is met only with a dated record. Under the base rule it counted as code met on met===true alone, so the new rule is stricter.
- SENSITIVE, the control-character check and the unquote-before-empty order are all stricter than before.
- The approver prompt no longer contains any PM number. Both prompts read the spec through `git show ${head}:`.

Checks I ran:
- `python3 -I scripts/factory-review-selftest.py` on a clean tree at dcae95345 printed "all cases match", exit 0. I did not run `--mutate` or the board `--selftest`, because both write temp files and my clause forbids creating files.
- `doctor.py --section B` reports that every path the skill and commands cite exists.
- `factory-board.py --open` parses, and board.json records the base 73e9ae52d.
- I transcribed guard claim 10 in Python. At the head every needle holds, and the RERUN order holds with 1 matched RERUN after `if (escalation) {`. At the base the fixed, escalation and kindOf needles are absent and the `if (escalation) {` anchor is missing.

Gates on dcae95345:
- Xcode Compile Check: success. It compiles Sources/ only and proves nothing about the changed test file.
- CI/CD Build & Test, step `Build for Testing`: success, so TheFactoryReviewersAreReadOnlyTests.swift compiles.
- `Run Tests`: still in progress, so claim 10 has not been observed executing. Its status is "transcribed, no run".
- Full Test Suite (non-blocking): proves nothing (#208).
- No gate runs the JS workflow itself; only the local selftest does.
- The job touches no target, entitlements file, Info.plist or project.yml.

Seven minor findings follow (no blocker or major). Each could be fixed in this job or left for later.

## Befunde

1. **minor** `Tests/CISmoke/TheFactoryReviewersAreReadOnlyTests.swift`:67 — The grading for claim 10 is wrong in the flattering direction (Tests/CISmoke/CLAUDE.md section 3). It says claim 10 is red on the parent 73e9ae52d 'by the change itself, not by an absent anchor'. On the parent, the anchor `if (escalation) {` does not exist, so the guard leaves through `return XCTFail("ANCHOR MISSING ...")` at line 332. The order half is therefore red by ANCHOR ABSENCE, and the kindOf and metCode assertions (lines 349-358) get no verdict on the parent at all. The metCode needle (line 355) matches a line the diff did not change, so it is a COUNTERWEIGHT: green on both trees.
   - Vorschlag: Grade it per section 3: the fixed, escalation and kindOf needles are forward guards; the order scan is red by anchor absence on the parent; the kindOf and metCode assertions get no verdict there because of the early return; metCode is a counterweight.
2. **minor** `Tests/CISmoke/TheFactoryReviewersAreReadOnlyTests.swift`:336 — The order scan only matches the object-literal form `decision: 'RERUN'`. The workflow's other Approve-phase RERUN is written as an assignment, `decision = 'RERUN'` (echoel-factory-review.js:450). Today it sits safely after `if (fixed)`. If a later edit moved it above `if (fixed)`, claim 10 would stay green; only the selftest mutation would catch it.
   - Vorschlag: Also scan for `decision = 'RERUN'` and require it to sit after `if (fixed) {`, or say in the claim text that the assignment form is covered by the selftest only.
3. **minor** `.claude/skills/factory/SKILL.md`:176 — This line overstates what `recount` does (AC8 asks SKILL.md to say the same as the workflow). It reads 'Nur ohne sie ist ein Vermerk `RERUN` (mit `recount: true` ESCALATE)', i.e. every note escalates under recount. The workflow (echoel-factory-review.js:404-405) escalates on recount only when `disagree.length`, meaning the spec count. A wrongly graded set, an empty acceptance list or a missing approver stays RERUN even with `recount: true`. The selftest case 'recount does not excuse a wrongly graded set' expects exactly that RERUN. Line 92 of SKILL.md states it correctly ('Weicht die Zählung dann noch ab').
   - Vorschlag: Change line 176 to say that with `recount: true` only a spec-count note escalates.
4. **minor** `scratchpads/factory/004-escalation-before-recount/spec.md`:25 — The spec assumes fastlane/Pluginfile holds 'Gems, die in der Signier-Lane mit dem App-Store-Connect-Schlüssel laufen'. That is false today. fastlane/Pluginfile:3-4 describes the file as INERT, the Gemfile has no plugins_path eval, and both signing lanes install fastlane with a bare `gem install fastlane:2.225.0` and no bundler (testflight.yml:349, studio-testflight.yml:105). Listing the file as SENSITIVE does no harm, but the stated ship-path reason is wrong.
   - Vorschlag: Change the reason to 'would run in the signing lane once wired' or 'store configuration'; no code change needed.
5. **minor** `.claude/workflows/echoel-factory-review.js`:224 — SENSITIVE covers `^\.github\/workflows\/` but not `.github/actions/`. The composite action `.github/actions/setup-xcodegen` runs inside both TestFlight signing jobs (testflight.yml:341, studio-testflight.yml:69) and in every gate (ci.yml, xcode-compile-check.yml). An edit to it outside `paths` gets no sensitiveOutside or scopeOpen entry. The gap is older than this diff; this job extended the same list (AC7) without closing it.
   - Vorschlag: Add /^\.github\/actions\// next to the workflows pattern in a follow-up job.
6. **minor** `.claude/workflows/echoel-factory-review.js`:274 — The new comment says git prints none of these characters unquoted with core.quotePath=false. That holds for C0 controls and DEL, but not for code points of U+0080 and above (C1, U+2028/2029, bidi, zero-width, BOM): with quotePath=false git prints them raw. This repo's own non-ASCII file names prove it: `git -c core.quotePath=false ls-files` prints names under reports/ with a raw en dash. A real tracked file with such a character would therefore turn every round into a RERUN with no way out. It fails closed, and no tracked name hits the new set today (checked).
   - Vorschlag: Correct the comment. Optionally return INVALID when every lens reports the same flagged name, since then the name is real and a rerun cannot change it.
7. **minor** `.claude/workflows/echoel-factory-review.js`:408 — The new early ESCALATE return (a fixed or approver escalation plus a count note) carries no deviceAsks, founderOpen or unmet. Device requests from that round then exist only inside the raw `approver` object. SKILL.md step 6/7 has the PM fold deviceAsks into the next device round from the return value.
   - Vorschlag: Compute deviceAsks and founderOpen from the acceptance list before the notes branch and include them in the early return, or tell SKILL.md to read them from `approver.acceptance` on an early ESCALATE.
