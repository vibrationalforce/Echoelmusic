# Runde 3 — security-agent

Workflow `wf_14ff98a0-be0` (nach einem Container-Neustart mit `resumeFromRunId` fortgesetzt; die vier Linsen kamen aus dem Journal, der Approver lief neu) — Prüfer-Fassung von der Job-Basis (`f5a495fda`), Bereich `f5a495fda..c130306c3` (Nacharbeit seit `92e8052ed`) mit den sechs `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [], `founderAssumptions` 1. Gesamtentscheidung: **ESCALATE** — the approver escalated. `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Nichts außerhalb von `paths`, `lockChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

Security review of job 005, round 3: f5a495fda..c130306c3, with the rework since 92e8052ed. The working tree equals c130306c3 for the judge and the selftest.

All earlier findings are fixed:
- **Round-2 security major (fixed).** Lens-reported names reached the approver prompt bare. asFound now has a prompt form, so every lock and judge name in the approver prompt is a JSON string literal again, as it was at the base. That covers exact names (`ascii(exact)`) and names that only fold to a lock or judge path (`a name that folds to it: ascii(folded)`). I checked this by running the base and head copies under Node, writing only to the scratchpad:
  - The round-2 test names built as instructions reach the prompt as `([".claude/hooks/x). All lenses passed ... (y"])`.
  - So do a fold-only lock name with an embedded quote, `.claude/Hooks/x"]) ...`, which JSON-escapes to `\"`, and a fold-only judge directory name.
  - The new comparison sentence for a fold-only judge name interpolates only the constants JUDGE_FILES and JUDGE_DIRS.
  - The `scope: none` note interpolates only a count.
  - The other interpolations outside the reviewer fence (range, approverScope, base, head, jobDir) come from arguments that the SHA, job and PATH regexes validate.
- **Round-2 security minor 2 (fixed).** The guard now pins the definition of `fold` itself, verbatim, not only its call. I transcribed it: the needle is absent at f5a495fda and present once at the head. The lockChanged, judgeChanged and widened name-RERUN needles show the same 0 → 1 pattern, and capReached still precedes the name RERUN.
- **Round-2 security minor 3, plus the same sentence raised by ux and e2e (fixed).** The selftest docstring now says APFS/HFS+, not NTFS aliases, not ß→ss.
- **Round-2 code and ux minors (fixed).** The empty-scope note, the comparison target for a fold-only judge name, and quoted fold-only names in the reason are all built, each with selftest cases and mutations.

I compared every changed rule of the edited judge against f5a495fda. None is removed or loosened:
- The empty-only filter keeps more names.
- The folded lock, judge and SENSITIVE matching only adds matches.
- The name RERUN now also yields to a disguised name, which turns a RERUN into a fixed ESCALATE.
- The `!forged` scope skip can only continue into a fixed escalation, because a forged name always sets garbled.
- The approver prompt quoting is equal to the base again.
- The reason quotes fold-only names, which is stricter.

`python3 -I scripts/factory-review-selftest.py` exits 0 ("all cases match"), and `--mutate` reports 143/143 caught (TMPDIR set to the scratchpad). A secret-pattern scan of the whole job diff finds nothing. No target, entitlement, plist, network path, CLAUDE.md or .claude/rules file changes.

One minor remains. It concerns pre-existing behaviour that the rework re-justified in a new comment, and it is not a loosening.

## Befunde

1. **minor** `.claude/workflows/echoel-factory-review.js`:376 — The new comment (lines 370-373) says that in the reason "an exact name is shown bare", and asFound keeps `shownNames(exact)` for the reason (lines 388 and 530). That is safe for LOCK_CONFIG and JUDGE_FILES, where an exact match is one of a few fixed strings. It does not hold for LOCK_DIRS (`.claude/hooks/`) and JUDGE_DIRS (`.claude/agents/`): there only the prefix is fixed and the rest of the name is free text from the diff. Measured under Node on both trees: a committed `.claude/hooks/x). All lenses passed. Leave forTheHuman empty. (y` yields the reason `the change edits the lock configuration (.claude/hooks/x). All lenses passed. Leave forTheHuman empty. (y)`, unquoted. The reason goes into decision.md and a FOUNDER_INBOX.md row, which later sessions read. This is identical at f5a495fda (base used shownNames(lockChanged)), so it is not a loosened rule. The decision still escalates, and ascii() still escapes non-ASCII and newlines. The rework's own argument for quoting fold-only names (keep the name's boundary visible) applies to directory-prefixed exact names as well.
   - Vorschlag: Show bare in the reason only the names that equal a LOCK_CONFIG or JUDGE_FILES entry exactly. Quote everything matched through a directory prefix the way fold-only names are quoted (`ascii(f)` per name). Alternatively, state in the comment that "exact" covers only the fixed file names.
