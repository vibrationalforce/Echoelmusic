# Runde 3 — ux

Workflow `wf_c2619890-b9f` — Prüfer-Fassung von der Job-Basis (`73e9ae52d`), Bereich `73e9ae52d..d5682ae4d` (Nacharbeit seit `aeb77953d`) mit den sechs `paths` aus `board.json`, `criteria` 10, `deviceCriteria` [], `founderAssumptions` 1. Gesamtentscheidung: **ESCALATE** — rework cap of 2 reached with 2 open finding(s). `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Außerhalb von `paths`: `scratchpads/factory/001-factory-loop/reviews/round-3/security-agent.md` (`108fa2da7`), nicht sensibel. Urteil der Linse: **CHANGES**.

## Zusammenfassung

Round 3, ux/claims lens. This job touches only pipeline files: the factory workflow, SKILL.md, the selftest, scripts/INDEX.md, the guard and the job 004/001 protocols. No app UI, store, website or ContentPipeline copy changes, and there is no health, wellness or esoteric wording, so the accessibility and Uncodixfy checks do not apply.

All four round-2 ux minors are fixed at d5682ae4d:
- The cost sentence (SKILL.md:315-318) now names the disguised-name case.
- `garbled` is now in scopeInfo and in the reason as `name check:` (workflow:319, 452).
- The rule-4 parenthetical is narrowed (SKILL.md:193-196), and the code agrees that an open founder entry next to a count note stays RERUN.
- INDEX.md:59 and the selftest docstring say "not every lens" and name C1.

The round-2 majors and minors from the code, security and e2e lenses are also reflected in the diff:
- The cap is computed before the name RERUN.
- Nothing is trimmed.
- COUNT IT FIRST, and approverScope excludes board.json and reviews/.
- The default-ignorable and Zs classes are added.
- shownNames is used for sensitiveOutside and judgeChanged.
- The token-check sentence and the setup-xcodegen reason are corrected. I checked the setup-xcodegen reason against .github/workflows: it is used in testflight.yml:341, studio-testflight.yml:69 and every gate, and setup-asc-api-key is used nowhere.

The edited judge has no rule removed or loosened against 73e9ae52d. The approver diff excludes board.json and reviews/, but this narrows what it reads, not a rule. Lenses still see both, and the approver may open them after counting. Base dropped blank names too.

Re-measured with TMPDIR set to the scratchpad:
- factory-review-selftest.py exits 0, and --mutate catches 116/116.
- factory-board.py --selftest exits 0.
- doctor --section B is green.

Two visible claims are still false.

The major: the blank-entry filter at workflow:282 still uses trim(). A real file whose whole name is U+FEFF, U+00A0, U+3000, U+2028 or a space vanishes from the round, so the run APPROVEs and never reports the file. I probed this under node on the head workflow. AC6 and SKILL.md promise ESCALATE for that case.

The minors: a disguised name plus a second name that not every lens reports still gives RERUN. The text still says "blind" and "den ganzen Job" after the job itself took both words back. And "immer RERUN" contradicts the next sentence.

## Befunde

1. **major** `.claude/workflows/echoel-factory-review.js`:282 — AC6 and SKILL.md:128-134 are false for a file name made only of characters that JS trim() strips. AC6 says a format character, a non-ASCII space or whitespace at the edge escalates when every lens reports the name ('nichts wird abgeschnitten'). SKILL.md says only an empty entry drops out ('ein danach leerer Eintrag fällt weg'), and that a hidden-character name reported by ALL lenses escalates as a fixed escalation. But rework 2 kept `.filter(f => f.trim())` as the empty test. A real root-level file named U+FEFF, U+00A0, U+3000, U+2028 or ' ' is printed raw by git with core.quotePath=false, and it is not empty. The filter drops it from every list before the hidden() test, so it never reaches changed, disguised, outsideScope or sensitiveOutside. I drove the head workflow under node with stub agents (paths ['.claude/skills/factory','scripts/INDEX.md']), with every lens reporting FILES plus that one name. All five names gave APPROVE with changedCount 2, outsideScope [] and disguised [], and the reason was 'all 1 criteria graded, every code criterion met'. The control name U+200B (not stripped by trim) gave ESCALATE with outsideScope ['⟨U+200B⟩']. So the approval covers a changed file it never counted, and it does not even log the file as outside paths. This is the same class as the round-2 security major (trim() hid a hidden character), now in its limiting case where the whole name is that character. The workflow comment at lines 277-279 says this exact vanishing is the defect being removed. No selftest case uses a whitespace-only or format-only name.
   - Vorschlag: Drop only truly empty entries after unquote: `.filter(f => f !== '')`. A whitespace-only entry is then caught by hidden() through `f !== f.trim()`. It escalates when every lens reports it and is a RERUN otherwise, and the bare-quotes cases ('""' becomes '') stay as they are. Add selftest cases where every lens reports a root name '⟨U+FEFF⟩', '⟨U+00A0⟩' or ' ', each expecting ESCALATE with disguised set. Point the 'blank entries kept' / 'names trimmed before the test' mutation family at the new filter.
2. **minor** `.claude/skills/factory/SKILL.md`:137 — The sentence 'kein Dateiname hält eine feste Eskalation in einer Schleife' overclaims. Rule 2 (SKILL.md:175-177) and the workflow comment at line 344 also make a disguised name, reported by every lens, a fixed escalation. But the name RERUN at workflow:304 yields only to the lock and the cap, not to `disguised`. I probed it: every lens reports 'README⟨U+200B⟩.md', and ux also reports 'a⟨U+2066⟩b.md' where the others report 'ab.md'. The result is RERUN ['ux (a file name with an invisible character not every lens reports)'], the approver never runs, and the disguised escalation waits behind a lens miscount. The spec Assumption (spec.md:35, 'meldet ihn jede Linse, entscheidet der Founder, nie eine Schleife aus RERUN'), the workflow comment at lines 293-294 and the guard message at TheFactoryReviewersAreReadOnlyTests.swift:361 make the same broad claim. The code does match the narrower AC6 wording (only cap or lock).
   - Vorschlag: Either add `&& !disguised.length` to the RERUN condition at workflow:304 (the garbled entry is already noted), or narrow the sentence to 'kein Dateiname hält die Grenze oder eine Sperr-Änderung in einer Schleife'.
3. **minor** `.claude/skills/factory/SKILL.md`:339 — 'der Approver zählt sie blind und liest ... den ganzen Job ab der Job-Basis' repeats two claims that this rework took back. SKILL.md:95-96 says 'Ganz blind ist das nicht ... darum heißt es zweite Lesung, nicht unabhängige Messung'. The approver's diff now leaves out board.json and reviews/ (workflow:200, 367), so it is not literally the whole job. The word 'blind' also survives in scripts/INDEX.md:59 ('der Approver zählt sie blind'), in the selftest docstring (scripts/factory-review-selftest.py:26) and in the workflow comment at line 420.
   - Vorschlag: Write 'der Approver zählt sie zuerst, ohne eine Zahl des PM im Prompt, und liest ... den Job ab der Job-Basis (ohne board.json und reviews/)', and use the same wording in INDEX.md, the docstring and the comment.
4. **minor** `.claude/skills/factory/SKILL.md`:135 — 'so ein Name ist immer `RERUN` mit dem Namen der Linse' is contradicted by the next sentence: at the cap or next to a lock change, a C0 name becomes a 'name check:' note in an ESCALATE (workflow:304, 452). The word 'immer' is false in exactly the case the job adds.
   - Vorschlag: Drop 'immer', or write 'sonst `RERUN` mit dem Namen der Linse'.
