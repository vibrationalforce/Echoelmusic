# Runde 3 — code-reviewer

Workflow `wf_74fa31d5-4ba`, Bereich `b1cfc8ad1..f209ecb16` mit `paths` (neun), `since` `0b0e8339b`, Dateien im Scope: 19. Urteil: **PASS**.

## Zusammenfassung

Code lens, round 3, on b1cfc8ad1..f209ecb16 scoped to the nine job-001 paths (19 files). The rework delta is 0b0e8339b..f209ecb16. I reviewed the job-001 files only.

All four round-2 code findings are fixed, checked against the source at f209ecb16:
- major (the approver saw only the rework): `range` is still `${a.base}..${head}` (echoel-factory-review.js:166). The approver prompt reads it as "the whole job from its base" (line 232). The new `since` is used only in the lens prompt (line 182). Selftest case "since: lenses read the rework, the approver the whole job" (factory-review-selftest.py:96-103) asserts that the approver prompt contains the base and not `since`.
- minor (a device criterion leaking into forTheHuman): fixed by the approver prompt at lines 244-245.
- minor (the stub ignored prompts): fixed at selftest:44 and 80-95. Those checks cover the clause coming first, the scoped diff and log for every agent, and the approver's unscoped name list.
- minor (exit cause): fixed. A LOADED sentinel (selftest:35) feeds exit 2 at lines 153-155.

The other lenses' round-2 findings are also fixed or rebutted in the code they point at:
- `paths`/`since` are echoed in every return after the argument check (line 170).
- The approver checks locked files against the unscoped list (line 252), with a date-and-scope rule for releases (lines 253-255).
- The fence escape (line 228). I checked that `--` can no longer appear in the replaced output, and the selftest JSON.parse round-trip holds.
- `!metCode` returns RERUN (lines 291-294).
- `round` is required (lines 144-146).
- `base` and `since` must be SHAs (lines 137, 142).
- `deviceOpen` in factory-board.py.
- The CSV and intake wording.
- The job-002 PrivacyInfo rebuttal is outside this scope.

Checks I ran:
- `FACTORY_VERBOSE=1 python3 -I scripts/factory-review-selftest.py` under node v22.22.0: every case OK, exit 0.
- Guard claims 1-6 transcribed in Python against f209ecb16: 2 of 2 agent calls are wrapped, the wrapper prepends the clause, the clause equals context.md §5, all 9 agentTypes are on the roster, the cap is 2 in both files, and the inbox route exists.
- inspiration.csv parses as 306 rows of 8 columns.
- Every path the skill and workflow cite exists.
- PROTECTED_DIRS is empty, so §3 plus PROTECTED_FILES covers all five locked paths.

I did not run `factory-board.py --selftest` because it writes to a temp dir. Reading its expected sets by hand, it should pass.

No blocker or major. Four minors follow.

## Befunde

1. **minor** `.claude/skills/factory/SKILL.md:124` — Step 6 says a job stays on `--open` until every deviceOpen row 'ein `VERIFIED-JJJJ-MM-TT` trägt'. The schema in the same file (line 140, `"verified": "JJJJ-MM-TT"`, and line 145) and the tool's check (scripts/factory-board.py:30, `DATE = ^\d{4}-\d{2}-\d{2}$`, applied at line 61) accept only a bare date. A PM who follows line 124 literally writes `"verified": "VERIFIED-2026-10-20"`. factory-board.py then reports 'deviceOpen verified must be YYYY-MM-DD', exits 1, and drops the job from the printed board through the `continue` at line 64. The failure is loud, but two spellings of one field in one file is the #416 shape.
   - Vorschlag: Line 124: 'bis jede Zeile ein `verified`-Datum (JJJJ-MM-TT) trägt'. Keep the VERIFIED-marker convention for the FOUNDER_INBOX row, not for board.json.

2. **minor** `.claude/workflows/echoel-factory-review.js:203` — `empty` fires when ANY one lens reports filesInScope 0. The round then returns INVALID with 'found no changed file in <range>', even if the other lenses counted files. The comment above (lines 201-202) justifies this with 'the same call again would see the same nothing'. That holds when every lens agrees, but not when one model miscounted while the others saw a real diff. In that case the PM is told the range or paths are wrong when they are not. The only selftest case (factory-review-selftest.py:104) makes all three stubs return 0, so the disagreement case is unpinned.
   - Vorschlag: Return INVALID only when every answering lens reports 0. If lenses disagree, return RERUN naming the zero-count lens. Add a selftest case where one lens returns 0 and the others return 3.

3. **minor** `scripts/factory-board.py:58` — The new branch 'deviceOpen must be a list of objects' (lines 57-60) has no selftest case. The selftest (lines 112-123) covers a valid list, an all-verified list and a bad date only. If the isinstance check is removed or inverted, a board with `"deviceOpen": "AUM"` goes on to line 61. There `d.get` on a str raises AttributeError, and the tool dies with a traceback instead of printing a finding. The selftest stays green over that mutation.
   - Vorschlag: Add an 008 board with `"deviceOpen": "AUM"` (and/or `["AUM"]`), raise the expected problem count to 5, and keep the loaded-ids assertion unchanged.

4. **minor** `.claude/workflows/echoel-factory-review.js:142` — `since` is validated as a SHA but is accepted in any round, including round 1. The lens prompt (line 182) then states 'This is a rework round' and asks the lens to confirm earlier findings that do not exist. Nothing breaks, but it is a present-but-meaningless argument, and the argument check exists to refuse those (lines 127-128).
   - Vorschlag: Add `if (has('since') && round === 1) problems.push('since is the previous round head; round 1 has none')`, plus a selftest case.
