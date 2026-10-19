# Runde 2 — code-reviewer

Workflow `wf_6970a9ab-570`, Bereich `9c0677f03..0b0e8339b` (ohne `paths`), Urteil der Linse: **CHANGES**.

## Zusammenfassung

Code lens, round 2, on 9c0677f03..0b0e8339b. The range carries 1814d6b10 (research notes) and 08ded356a (job 002, EchoelStudio plugin unlock) because no `paths` was passed. I reviewed the job-001 files only and left the job-002 Swift to job 002's own review.

All eight round-1 code findings are fixed, checked against the source:
- Verdict order: an ESCALATE is never downgraded, and a device criterion never blocks (lines 245-262).
- A malformed argument that is present returns INVALID (lines 126-153). The SHA-only head is at line 136.
- The three always-on lenses are a floor, with at most one domain lens (lines 145-155).
- Prototype keys are rejected through hasOwnProperty (line 128).
- `minItems: 1` is in the schema, plus a RERUN on an empty acceptance list (lines 105, 234).
- The guard has claim 6.
- board.json head is set.
- REF rejects a leading dash and `..`.

Checks I ran:
- `python3 -I scripts/factory-review-selftest.py` under node v22: all 32 cases match, exit 0.
- Guard claims 1, 3, 4 and 6 transcribed in Python against 0b0e8339b and 9c0677f03: 2 of 2 agent calls wrapped, the wrapper prepends READ_ONLY, 9 agent types all on the roster, cap 2 in both files.
- The new Swift test has no escape or import problem.

One new major: this diff makes `base` the previous round's head from round 2 on, and the approver uses that same range. In any job that had a rework, the approver therefore never sees the original build diff, and that diff is where founder-locked or founder-owned changes would sit. Three minors cover prompt ambiguity and selftest blind spots.

## Befunde

1. **major** `.claude/skills/factory/SKILL.md:61` — This diff adds the rule 'ab Runde 2 ist `base` der Kopf der vorigen Runde'. The workflow builds ONE `range` (`${a.base}..${head}`, echoel-factory-review.js:158) and hands it to the approver as well (line 206, 'Read spec.md and `git diff ${range}${scope}`'). The approver runs only in a round with no open findings or at the cap; round 1 with any blocker or major returns REWORK at line 196 before the approver runs. Result: for every job that had at least one rework, the approver only ever sees the rework delta, never the build commit. Its ESCALATE duties ('the change decides something the founder owns … or a founder-locked file', lines 219-224) are checked against a diff that leaves the original change out. Concrete failure: the build commit edits `project.yml` or licence text and also has one code major. Round 1 returns REWORK and no approver runs. The PM fixes the major. Round 2 runs with base = the round-1 head, so the diff no longer contains `project.yml`. The approver sees no locked file and APPROVEs. The approver is the only escalation point, so the founder gate is skipped on the normal path. This job is itself in that state: round 1 was REWORK, and round 2 runs on 9c0677f03..0b0e8339b.
   - Vorschlag: Keep two refs. `base` stays the job's base from board.json, and the approver always reads `git diff ${jobBase}..${head}${scope}`. A new optional `since` (the previous round's head, validated with SHA) is used only in the reviewer prompt, to point the lenses at the rework delta while they confirm earlier findings. Change SKILL.md:61 to match. Add a selftest case that captures the approver prompt and asserts it contains the job base, not `since`.

2. **minor** `.claude/workflows/echoel-factory-review.js:225` — Line 253 escalates on ANY `forTheHuman` entry. The device bullet (lines 215-216) says a device criterion 'becomes a device request in docs/dev/FOUNDER_INBOX.md §2', and line 225 allows a question when 'it is the founder's and not yet answered'. A device check is literally something only the founder can do, so an approver that also lists it in forTheHuman (the round-1 prompt told it to do exactly that) turns a device-only spec into ESCALATE. That brings back round-1 finding 1(a) through the questions channel. No selftest case covers a device criterion that also appears in forTheHuman.
   - Vorschlag: State it in the prompt: 'A device criterion travels ONLY as an acceptance entry of kind device; never repeat it in forTheHuman.' Add a selftest case where the approver returns APPROVE with one device criterion and an empty forTheHuman, and pin it.

3. **minor** `scripts/factory-review-selftest.py:35` — The stub `agent` ignores `prompt`, so case 'paths ok' (line 63) checks only the decision. A mutation that drops `${scope}` from the reviewer or approver prompts (workflow lines 168, 206) leaves all 32 cases green, yet commit 0b0e8339b's message says the scope 'geht an git log/git diff aller Prüfer und des Approvers'. The same blind spot would hide a prompt that lost the READ_ONLY prefix. The Swift guard covers that only as text.
   - Vorschlag: Record `prompt` in the stub. In the 'paths ok' case, assert that every spawned prompt contains ` -- .claude/skills/factory scripts/INDEX.md` and starts with the READ_ONLY clause.

4. **minor** `scripts/factory-review-selftest.py:94` — Any non-zero node exit maps to 1, which the docstring (line 14) defines as 'a case decided wrong'. If the meta-strip regex (line 28) stops matching, or the workflow has a SyntaxError, `new Function` throws before any case runs and the tool still reports 1, not the 'nothing was checked' class the docstring gives exit 2. This fails loud, not silent, but a reader gets the wrong cause.
   - Vorschlag: Have the harness print a sentinel such as `LOADED` after the first successful `make(...)`, and print `all cases match` only at the end. Map 'no sentinel' to exit 2 with 'workflow did not load — NOTHING CHECKED'.
