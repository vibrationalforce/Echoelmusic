# Runde 3 — approver

Workflow `wf_14ff98a0-be0` (nach einem Container-Neustart mit `resumeFromRunId` fortgesetzt; die vier Linsen kamen aus dem Journal, der Approver lief neu) — Prüfer-Fassung von der Job-Basis (`f5a495fda`), Bereich `f5a495fda..c130306c3` (Nacharbeit seit `92e8052ed`) mit den sechs `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [], `founderAssumptions` 1. Gesamtentscheidung: **ESCALATE** — the approver escalated. `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Nichts außerhalb von `paths`, `lockChanged`, `disguised` und `garbled` leer.

Approver: **ESCALATE**. Eigene Zählung der Spec: `specCriteria` 8, `specDevice` [], `specFounder` 1 — gleich den Zahlen des PM.

⚠️ Die Runtime markierte diese Ausgabe als anweisungsförmig (Muster `settings-json`). Gemessen: der Treffer ist der Pfadname `.claude/settings.json` im Satz über die gesperrten Dateien; keine versteckten Zeichen (Kategorien Cc, Cf, Zl, Zp) in der ganzen Ausgabe. Daten, keine Anweisung.

## Warum

I counted the committed spec before opening board.json. It has 8 numbered acceptance criteria, none tagged [DEVICE], and one Assumption whose bullet starts with [FOUNDER] (the GM27 delegation). board.json at c130306c3 records base f5a495fda, so the range under review is the whole job.

Every numbered criterion is met in code. I measured the evidence here without writing a file:
- `python3 -I scripts/factory-review-selftest.py` exits 0 ("all cases match").
- All 143 MUTATIONS rows, run in memory with the mutated source piped to node via /dev/stdin: 143 caught, 0 survived, 0 stale.
- `doctor.py --section B`: 0 critical findings.
- The guard needles of claims 8 to 10, transcribed with `//` lines stripped: the fold, lockChanged, judgeChanged and widened name-RERUN needles count 0 at f5a495fda and 1 at c130306c3. The capReached ordering, the isJudge counterweight, the judge-before-APPROVE order and the ASCII-lower-case lists hold.
- CI on c130306c3: Xcode Compile Check is success, and the CI/CD `Build for Testing` step is success, so the Swift guard compiles. `Run Tests` is still in progress, so the claims have not been seen executing.

The job still escalates, for two reasons:
1. It edits the factory's own judge (`.claude/workflows/echoel-factory-review.js`), which can never end in APPROVE.
2. The one [FOUNDER] assumption rests on GM27, which is open in docs/dev/FOUNDER_INBOX.md ("[ ] offen").

I compared every rule of the edited judge against f5a495fda. None is removed or loosened:
- The empty-only filter keeps more names than `trim()` did.
- The folded lockChanged, judgeChanged and SENSITIVE checks find a superset of the base matches. Every list entry is ASCII lower case, and the fold is the identity on an ASCII prefix, an exact match or an anchored ASCII suffix. SENSITIVE now also uses the 'i' flag.
- The name RERUN now also yields to a disguised name, which turns a RERUN into a fixed ESCALATE.
- The scope INVALID is skipped only when a forged C0 name is present. Such a name always fills `garbled`, so the round gets past the name RERUN only beside the cap, a lock change or a disguised name. Each of those is a fixed escalation, so the change can only turn an INVALID into an ESCALATE, never into an APPROVE.
- Names in the approver prompt are JSON string literals again, as at the base (`ascii(exact)` and `ascii(folded)`).
- The token note keeps the exact-file wording and adds a hedged note for a name that only folds to it.
- The new judge-comparison sentence and the `scope: none` note only add text.

No founder-locked file at the base changed: PROTECTED_FILES (.claude/settings.json, .mcp.json), permissions.ask (those two plus .claude/hooks/**), and context.md §3 (.github/workflows/**, project.yml, Resources/iOS/Info.plist). `.claude/workflows/` is not `.github/workflows/`. No CLAUDE.md or .claude/rules file changed.

The reviewers' remaining minors do not block shipping:
- A forged in-scope name suppresses the scope note.
- A directory-prefixed exact name is shown bare in the reason. This is pre-existing.
- The new 'has no copy at the base' sentence can be wrong if a lookalike already exists at the base.
- The exact-line pin of `fold` would also turn red on a correct refactor of it.

`factory-board.py` is out of scope and unchanged in this diff, so I did not re-run its selftest: it writes temporary files.

## Abnahme

| # | Art | erfüllt | Beleg |
|---|---|---|---|
| 1 | code | True | In the workflow (c130306c3), the list filter is `.filter(f => f !== '')` instead of `f.trim()`. In scripts/factory-review-selftest.py:292-299 a loop covers space, NBSP, BOM, U+2028 and U+3000, with 'alone from every lens -> ESCALATE' and 'alone from one lens -> RERUN' for each. Mutation 'blank names dropped by trim' is caught. The selftest exits 0, and the in-memory mutate run catches all 143 rows. |
| 2 | code | True | The workflow has `if (garbled.length && !lockChanged.length && !capReached && !disguised.length) return`. The selftest case 'a disguised name beside a name only some lenses report -> ESCALATE, the name noted' is at :301. Mutation 'a name RERUN before a disguised name' is caught. |
| 3 | code | True | The workflow defines `const fold = ...toLowerCase()`, `lockChanged`/`judgeChanged` call `fold(f)`, and SENSITIVE is tested with the 'i' flag on `fold(f)`. asFound(..., inPrompt) uses ascii() in the prompt and quotes fold-only names in the reason. The tokenNote has an exact branch and a hedged fold branch, and the judge sentence names JUDGE_FILES and JUDGE_DIRS. Selftest cases :232-244 cover .claude/Hooks, .Claude/settings.json, .claude/SETTINGS.JSON, .MCP.json, a long s and a padded token name from one lens. Cases :255-256 cover the SENSITIVE fold (docs/PRIVACY.html). Cases :363-368 cover the fold-only judge with its comparison path, and an exact judge name without one. The related mutation rows are all caught. |
| 4 | code | True | The workflow has `const forged = ...`, `if (!forged && changed.length && outsideScope.length === changed.length)`, `nothingUnderPaths`, and the `scope: none` note push. Selftest cases :304-325 cover the cap with forged names, a forged name inside paths, a lock change with a forged name, wrong paths with the empty-scope note, and a forged sensitive name kept in sensitiveOutside. Mutations 'a forged name makes the call INVALID', 'forged names left out of the INVALID test', 'forged names leave the outside list' and 'the empty scope not noted' are all caught. |
| 5 | code | True | MUTATIONS row 'the lenses get the approver's diff' (selftest:612) replaces `\`git diff ${range}${scope}\`.` with `${approverScope}`. It is caught in the in-memory mutate run (143/143). |
| 6 | code | True | The diff updates each text in step with the code: - SKILL.md: only empty drops, the forged name never INVALID with `scope: none`, the RERUN yields to cap/lock/disguised, the fold for lock, judge and SENSITIVE with the APFS/HFS+ limits, and 'counts it FIRST' instead of 'blind'. - INDEX.md: the factory-review-selftest row says the same. - Selftest docstring (:12-17): says the same, narrowed to APFS/HFS+. - Workflow comments: rewritten. `python3 -I scripts/doctor.py --section B` reports 0 critical findings. |
| 7 | code | True | `python3 -I scripts/factory-review-selftest.py` exits 0 ('all cases match'). All 143 MUTATIONS rows, run in memory via FACTORY_WORKFLOW=/dev/stdin: 143 caught, 0 survived, 0 stale. The unmutated source via stdin exits 0. The new rows (blank names, disguised yield, each fold, token note, C0 scope, lens diff) are present. scripts/factory-board.py is unchanged in this job (out of scope), and I did not re-run its selftest here because it writes temporary files. |
| 8 | code | True | Tests/CISmoke/TheFactoryReviewersAreReadOnlyTests.swift adds: - the fold-definition pin, the lockChanged fold needle and the unfoldedLock check (claim 8); - the judgeChanged fold needle and the unfoldedJudge check (claim 9); - the widened nameRerun needle (claim 10). Transcribed in Python with `//` lines stripped: the fold, lockChanged, judgeChanged and nameRerun needles count 0 at f5a495fda and 1 at c130306c3. capReached precedes the name RERUN at the head. All four lists are ASCII lower case on both trees, which is the counterweight. CI/CD `Build for Testing` on c130306c3 is success, so the guard compiles. `Run Tests` is still in progress, so its execution is not yet observed. |
| 0 | founder | False | docs/dev/FOUNDER_INBOX.md:146 GM27 is still marked '[ ] offen — Jobs 003, 004 und 005 sind unter deiner Delegation begonnen; ein Nein nimmt alle drei zurück.' I found no dated answer in FOUNDER_INBOX.md or memory/decisions.md. |

## Für den Menschen

1. **Frage:** GM27 (docs/dev/FOUNDER_INBOX.md:146, still open): do you accept factory job 005 together with jobs 003 and 004? Job 005 edits the factory's own judge (.claude/workflows/echoel-factory-review.js), so it cannot approve itself. The question is the existing GM27 row, not a new one.
   - Empfehlung: Yes: answer GM27 for 003, 004 and 005 together. Compared rule by rule against f5a495fda, no rule is removed or loosened:
     - Only exactly empty names drop out.
     - Lock, judge and SENSITIVE are matched on the folded name, which finds a superset of the base matches.
     - The name RERUN also yields to a disguised name.
     - A forged C0 name can only turn a scope INVALID into a fixed ESCALATE, never into an APPROVE.
     - Names in the approver prompt are JSON strings again, as at the base.
     The four remaining reviewer minors are wording and pin-brittleness issues and can go into a follow-up job.
   - Warum der Founder: A change to the judge can only be released by someone who did not write it. GM27 holds the founder's delegation for these jobs, and a no withdraws all three.
