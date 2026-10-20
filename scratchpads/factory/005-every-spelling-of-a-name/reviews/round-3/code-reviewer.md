# Runde 3 — code-reviewer

Workflow `wf_14ff98a0-be0` (nach einem Container-Neustart mit `resumeFromRunId` fortgesetzt; die vier Linsen kamen aus dem Journal, der Approver lief neu) — Prüfer-Fassung von der Job-Basis (`f5a495fda`), Bereich `f5a495fda..c130306c3` (Nacharbeit seit `92e8052ed`) mit den sechs `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [], `founderAssumptions` 1. Gesamtentscheidung: **ESCALATE** — the approver escalated. `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Nichts außerhalb von `paths`, `lockChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

Code review of job 005, round 3: the whole job f5a495fda..c130306c3, with rework 2 (92e8052ed..c130306c3) read first.

Round-2 findings: every one is fixed, and I checked each against the head.
- Security major (bare names in the approver prompt) is fixed. `asFound(..., inPrompt = true)` writes `ascii(exact)` and `ascii(folded)`, so each lock or judge name outside the fence is a JSON string literal again, as at the base. In memory, `.claude/hooks/a"b.py` reaches the prompt as `([".claude/hooks/a\"b.py"])`. A new case and three mutation rows pin it.
- Security minor (fold definition not pinned) is fixed. Claim 8 now requires the whole `const fold = ... .toLowerCase()` line. Transcribed with the guard's own `//`-line filter, it occurs 0 times at f5a495fda and once at 92e8052ed and at c130306c3. So it is FORWARD, as the header says.
- The docstring overclaim (three lenses) is fixed: line 16 now names APFS/HFS+ and excludes NTFS aliases and ß→ss.
- ux minor 2 is fixed: a fold-only name is quoted in the reason, e.g. `a name that folds to it: ".claude/settings.local.json "`.
- ux minor 3 and code minor 2 are fixed: a fold-only judge name now gets "compare it against the file it folds to ([...JUDGE_FILES...], or ... under [...JUDGE_DIRS...])". An exact judge name does not get that sentence, and a case pins this.
- Code minor 1 is fixed: `nothingUnderPaths` adds a `scope: none of the N listed name(s) lies under paths ...` note.
- The rebuttal also corrects the false "Nicht eingearbeitet: nichts" from round 1.

Rules compared with git show f5a495fda:.claude/workflows/echoel-factory-review.js. None is removed or loosened:
- The empty-only filter keeps more names than the base did.
- The folded lock, judge and SENSITIVE matches find a superset of the base matches. Every list entry is ASCII lower case, and the fold never changes an ASCII prefix, an exact `===` match or a `$`-anchored suffix.
- The name RERUN now also yields to a disguised name, which only turns a RERUN into an ESCALATE.
- A forged name skips the scope INVALID, but such a name only gets past the name RERUN beside the cap, a lock change or a disguised name. Each of those puts a part into `fixed`, so the notes path always returns ESCALATE, never APPROVE.
- The two-step token note is stricter than before.
- The new note and the judge comparison sentence only add text.

Measured here, writing no file:
- `python3 -I scripts/factory-review-selftest.py`: exit 0, "all cases match".
- All 143 MUTATIONS rows, run in memory with the mutated source piped to node via /dev/stdin: 143/143 caught, none stale.
- `doctor.py --section B`: 0 critical.
- Swift claims 8 and 9 transcribed on three trees. The fold, lockChanged and judgeChanged needles count 0/0/0 at f5a495fda and 1/1/1 at 92e8052ed and c130306c3. The isLockConfig, isJudge and branch-order counterweights are 1 on every tree.
- The new Swift assertion is a plain literal with no escape, and its string interpolation matches the neighbouring assertions. Its compile is not proven here: only CI/CD Build for Testing can show that.

I traced several edge cases in memory under Node: forged names inside and outside paths, a padded name under a lock directory, a mix of exact and fold-only judge names, and a quote character in a lock name. Two minor findings remain. Neither blocks shipping.

## Befunde

1. **minor** `.claude/workflows/echoel-factory-review.js`:335 — `nothingUnderPaths = forged && changed.every(f => !inScope(f))` decides by where a FORGED name lies. The comment four lines above (line 327) says that 'whether a forged name lies under paths says nothing, in either direction'. A C0 name is no name git printed, so a forged name inside paths says nothing about whether the scoped diff is empty, yet it suppresses the note. Reproduced in memory: paths ['scripts'], every lens reports ['.mcp.json', 'scripts/INDEX.md\u0001']. The result is ESCALATE ('the change edits the lock configuration (.mcp.json); noted: name check: ...') with no 'scope: none' note, although `git diff <range> -- scripts` may be empty. This matches the spec's wording ('kein gelisteter Name') and the deliberate selftest case 'a forged name under paths gets no empty-scope note' (selftest:320). The decision is right (ESCALATE); only the founder-facing hint is missing in this direction.
   - Vorschlag: Decide over the names git could have printed: `forged && changed.filter(f => !forgedChar.test(f)).every(f => !inScope(f))`. Word the note as 'no name git could print lies under paths'. Turn the selftest case at :320 around so that it expects the note, or else state in the comment at :333-334 that a forged in-scope name deliberately suppresses the note.
2. **minor** `.claude/workflows/echoel-factory-review.js`:371 — The new comment says the reason shows 'an exact name ... bare and a fold-only name stays quoted, so a padding space is visible'. That holds for LOCK_CONFIG files, but not for a padded name under a lock DIRECTORY. `isLockConfig` uses `startsWith('.claude/hooks/')` on the raw name, so '.claude/hooks/x.py ' counts as exact and is shown bare. Reproduced in memory, with every lens reporting it, the reason reads 'the change edits the lock configuration (.claude/hooks/x.py ); a changed file name hides a control or invisible character (.claude/hooks/x.py ); ...'. The trailing space is invisible in both parts. Same for '.claude/agents/x.md ' through `isJudge`. This is not a regression: the base showed every name bare. But the comment promises more than the code does.
   - Vorschlag: Quote every name in the reason whose `hidden(f)` is true, in asFound's exact half and in the disguised part: use `ascii(f)` instead of `ascii(f).slice(1, -1)`. Or narrow the comment to 'a fold-only name stays quoted'.
