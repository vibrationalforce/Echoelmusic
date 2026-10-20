# Runde 3 — code-reviewer

Workflow `wf_c2619890-b9f` — Prüfer-Fassung von der Job-Basis (`73e9ae52d`), Bereich `73e9ae52d..d5682ae4d` (Nacharbeit seit `aeb77953d`) mit den sechs `paths` aus `board.json`, `criteria` 10, `deviceCriteria` [], `founderAssumptions` 1. Gesamtentscheidung: **ESCALATE** — rework cap of 2 reached with 2 open finding(s). `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Außerhalb von `paths`: `scratchpads/factory/001-factory-loop/reviews/round-3/security-agent.md` (`108fa2da7`), nicht sensibel. Urteil der Linse: **PASS**.

## Zusammenfassung

Round 3, code lens, job 004. Range 73e9ae52d..d5682ae4d; rework since aeb77953d.

Earlier findings: all four round-2 code-reviewer findings are fixed at the head.
1. Major, the name RERUN in front of the cap: `open` and `capReached` now sit at workflow lines 268-271, ahead of the name check at line 304, which reads `if (garbled.length && !lockChanged.length && !capReached)`.
2. Minor, garbled information lost: `garbled` is now in scopeInfo (line 319) and in a `name check:` note (line 452).
3. Minor, invisible characters outside Cf: `\p{Default_Ignorable_Code_Point}` and non-ASCII Zs are added. Names in `sensitiveOutside` and `judgeChanged` now go through `shownNames`.
4. Minor, the cost sentence: SKILL.md now names the disguised file name.

The other lenses' round-2 findings are also fixed as the rebuttal says:
- No trim() before the hidden-character test (line 282), and an edge-padded name now counts as hidden (line 299).
- The approver is told to count first, and its diff excludes board.json and reviews/ (`approverScope`, line 200). I checked that git accepts that pathspec with and without `paths`.
- The `.github/actions/` reason and the token sentence are corrected.

Rule comparison against `git show 73e9ae52d:.claude/workflows/echoel-factory-review.js`: no rule is removed or loosened for any realistic input. A C0 name, a founder label, an approver count mismatch and a missing approver each now end in RERUN or ESCALATE, never APPROVE. SENSITIVE only grows. One pathological input does lose the cap escalation (minor 2 below).

Checks I ran, none writing a file:
- `python3 -I scripts/factory-review-selftest.py` exits 0.
- Every MUTATIONS row, run in memory through stdin: 116/116 caught, none stale.
- Claim 10 transcribed in Python. Red at 73e9ae52d. At aeb77953d red only on the new cap-before-name-RERUN needle. Green at the head, with 2 RERUNs after `if (escalation) {` and 0 before it.
- `doctor.py --section B`: 0 critical.
- No tracked file name matches the new hidden class, so no existing file escalates.
- Node probes on the head: at the cap, a forged or partly reported name escalates with a `name check:` note. A lock change plus a partly reported name escalates. A null approver at the cap escalates.

Three new minors, no blocker and no major:
1. A disguised name, which SKILL rule 2 calls 'ebenso fest', does not make a name RERUN yield. This contradicts the comment that no file name can hold a fixed escalation in a RERUN loop.
2. At the cap, names the workflow itself marked forged flow on into the scope INVALID.
3. The selftest no longer pins the end of the lens diff command.

Not compiled (no Swift toolchain here) and not device-tested; the job touches no app.

## Befunde

1. **minor** `.claude/workflows/echoel-factory-review.js`:304 — The name RERUN yields to the cap and to a lock change, but not to a disguised name. The workflow comment at lines 344-345 counts a disguised name as one of the three fixed parts, and SKILL.md rule 2 (line 175) says it escalates 'ebenso fest'. The comment at lines 293-294 and SKILL.md:136-137 both claim that no file name can hold a fixed escalation in a RERUN loop. Node probe on the head, round 1: every lens reports A = scripts/a<U+200B>b.py; code-reviewer and security-agent also report B = scripts/c<U+FEFF>d.py, which ux reports as scripts/cd.py. Result: RERUN ('code-reviewer (a file name with an invisible character not every lens reports)', and the same for security-agent). The approver is not spawned and the known disguised-name escalation for A is not returned. Without B, the same input ESCALATEs on A. This is not a loosening against the base (the base APPROVEs both), and AC6 names only the cap and the lock. But the code contradicts its own comment and SKILL.md, and no selftest case pins either behaviour: adding `&& !disguised.length` to line 304 survives every case.
   - Vorschlag: Either add `&& !disguised.length` to the condition at line 304 and add a selftest case (a disguised name plus a second hidden name that only some lenses report -> ESCALATE with a `name check:` note), or narrow the comment at 293-294 and SKILL.md:136-137 to say 'the cap and a lock change' instead of 'a fixed escalation'.
2. **minor** `.claude/workflows/echoel-factory-review.js`:314 — When the name RERUN falls through at the cap or at a lock change (line 304), the names the workflow itself identified as forged (C0, line 301: 'no name a lens copied from git') stay in `changed`. They then reach the scope INVALID at lines 314-317. Node probe on the head: round 3, one open major, paths ['scripts/INDEX.md', '.claude/skills/factory/SKILL.md'], every lens returns both names with a trailing '\n'. Result: INVALID 'none of the 2 changed file(s) ... lies under paths'. That exit blames the call's `paths`, drops the cap escalation and does not reach the founder. The base trimmed the newline and escalated this input at the cap. The trigger is pathological: every lens must corrupt every in-scope name, and an INVALID approves nothing. Still, it is an exit at the cap that the job's Goal says the cap stands in front of.
   - Vorschlag: When the name RERUN falls through, compute the scope checks (lines 307-317) over the names that are not forged, for example `changed.filter(f => !forgedChar.test(f))`. Or skip the all-outside INVALID while `garbled.length` is set. Add a selftest case: the cap plus forged names from every lens -> ESCALATE with reasonHas('rework cap').
3. **minor** `scripts/factory-review-selftest.py`:136 — To fit the approver's new exclusion suffix, the scoped-diff needle lost its closing backtick. It now checks only a prefix for every agent, so the end of the LENS diff command is no longer pinned. In-memory mutation probe: replacing the lens command `git diff ${range}${scope}` with `git diff ${range}${approverScope}` (the lenses would then no longer see board.json and reviews/ in their diff) survives every case. Before this round, the exact backticked string caught such an append.
   - Vorschlag: Keep the prefix for the approver only, which line 140 already pins in full. For the lens prompts, check the exact '`git diff b1cfc8ad1..9c0677f03 -- .claude/skills/factory scripts/INDEX.md`' with the closing backtick, for example `lensPrompts.filter(([, p]) => !p.includes(diff + '`'))`.
