# Runde 2 — ux

Workflow `wf_29831ef4-24e`, Bereich `f61d7872d..6d168b44a` (Nacharbeit seit `9237c3c91`) mit den acht `paths` aus `board.json`, `criteria` 10, `deviceCriteria` [], `founderAssumptions` 0, Urteil der Linse: **CHANGES**. Gesamtentscheidung: **REWORK** (5 Majors). Außerhalb von `paths`: `docs/dev/APP_STORE_CONNECT.md`, `docs/dev/FOUNDER_INBOX.md`, `docs/dev/TODO_FOUNDER_2026-10-19.md` (Commit `532e5b169`, nicht sensibel); `judgeChanged`: `.claude/workflows/echoel-factory-review.js`.

## Zusammenfassung

UX/claims lens, round 2. The round-1 rework diff (9237c3c91..6d168b44a) fixes all three round-1 UX minors. (1) The SENSITIVE list at echoel-factory-review.js:208 now covers docs/privacy/index.html and docs/terms/index.html, docs/_headers and docs/_redirects, docs/accessibility.html, THIRD_PARTY_NOTICES.md and docs/dev/FEATURE_STATUS.md. The selftest exercises these at selftest.py:170-172. (2) reviewedBy is now strict: factory-board.py REVIEWED regex plus scope_problem. null stays open, and 'founder', 'pending', blank, 0, false, the job's own id and a missing job are all findings. (3) 'Wann nicht' (SKILL.md:226-231) takes FEATURE_STATUS.md out of the internal exemption.

The new outward-facing claims hold up:
- Every file the SKILL.md sensitive-category list names exists at head.
- The `sha7` column exists in gh-run-status.py:9.
- The SKILL.md description of guard claims 8 and 9 matches the Swift test.
- `.claude/settings.json` permissions.ask is exactly settings.json, .mcp.json and hooks/**, which matches LOCK_CONFIG and LOCK_DIRS.
- MAX_REWORK_ROUNDS is 2, as the skill's 'at most two rework rounds' says.

Measured (TMPDIR in the session scratchpad, working tree clean at 6d168b44a): factory-review-selftest 'all cases match', --mutate 56/56; factory-board --selftest ok (6 jobs loaded, 15 malformed boards reported), --mutate 12/12; doctor --section B reports 0 critical findings.

The diff touches no app UI, Sources/ copy, website or store text. So VoiceOver, Dynamic Type, contrast, the 3 Hz flash limit, Uncodixfy and EchoelValueField do not apply. There is no health, wellness or esoteric wording.

The diff edits the workflow, so I compared its rules against f61d7872d. One rule is loosened, and it is new in this rework. The base told the approver to find every [FOUNDER] Assumption in the spec itself. Now an omitted, defaulted argument makes the workflow tell the approver, as fact, that there are none. That is reported as major. There is also one documentation minor.

## Befunde

1. **major** `.claude/workflows/echoel-factory-review.js`:311 — This is a loosened rule compared with the base. At f61d7872d:246 the approver was told to grade 'every Assumption tagged [FOUNDER]', which it finds by reading the spec. At head, `founderAssumptions` is optional and defaults to 0 (line 162). When the PM leaves it out, the trusted part of the approver prompt (outside the data markers) states as fact 'No Assumption is tagged [FOUNDER].' The workflow never measured that sentence; it comes only from an omitted argument passed by the builder. That is the party the factory is meant not to believe ('counted, not believed'). The result: an omission now suppresses founder grading, where the base approver read the spec itself and escalated an unanswered [FOUNDER] assumption. This contradicts the base's own principle, kept at line 144: 'round has no default: an omitted round read as 1 would skip the rework cap by omission'. The `criteria` argument follows that principle and is required; `founderAssumptions` does not. The selftest pins the false sentence as intended behaviour (factory-review-selftest.py:137, where the `base` args at :68 leave out founderAssumptions).
   - Vorschlag: Pick one of two fixes. (a) Make `founderAssumptions` required like `criteria`, so an absent value is INVALID. (b) Replace the sentence with the caller's count stated as a count, e.g. 'The caller counted N Assumption(s) tagged [FOUNDER]; read the spec's Assumptions yourself and give EVERY [FOUNDER] tag its own number-0 entry, even beyond that count.' The check at line 352 (`founderEntries < founderAssumptions`) already accepts extra entries. Update the selftest needle at :137 and mutation row :326 to match, and add a case where founderAssumptions is omitted.
2. **minor** `.claude/skills/factory/SKILL.md`:201 — Step 7 says the protocol carries `range`, `since`, `paths`, `criteria` and `deviceCriteria`. But `echo` at echoel-factory-review.js:190 also returns `founderAssumptions`. The board.json template at SKILL.md:209-215 lists none of the three counts, while job 003's own board.json stores `criteria` and `deviceCriteria`. A later round or session therefore cannot read from the board which [FOUNDER] count a verdict used. The round-1 protocol headers name only criteria and deviceCriteria.
   - Vorschlag: Name `founderAssumptions` in step 7. Add `criteria`, `deviceCriteria` and `founderAssumptions` to the board.json template, alongside `paths` ('steht in board.json, jede Runde liest es von dort').
