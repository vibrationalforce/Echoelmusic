# Runde 1 — security-agent

Workflow `wf_1edd4391-ce0` — Prüfer-Fassung von der Job-Basis (`f5a495fda`), Bereich `f5a495fda..2ee3c736d` mit den sechs `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [], `founderAssumptions` 1. Gesamtentscheidung: **REWORK** — 2 offene Befunde, Nacharbeit 1 von 2; der Approver lief nicht. `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Nichts außerhalb von `paths`. Urteil der Linse: **PASS**.

## Zusammenfassung

Security review of job 005, round 1. There are no earlier reviews in scratchpads/factory/005-every-spelling-of-a-name/ (the job directory holds only board.json and spec.md), so there were no earlier findings to check. The diff edits the judge (.claude/workflows/echoel-factory-review.js), so I compared every changed rule against f5a495fda. No rule is removed or loosened; each change is stricter or equal.

(1) The empty-entry filter changed from `.filter(f => f.trim())` to `.filter(f => f !== '')`. More names now reach the hidden-character test. A whitespace-only name either escalates as `disguised` (every lens reports it) or is a name RERUN (only some lenses do). It can never reach APPROVE.

(2) `lockChanged`, `judgeChanged` and `sensitiveOutside` now test `fold(f)`. I checked that this never drops a match the old exact test made, by running it over every Unicode code point after the `.claude/hooks/` and `.claude/agents/` prefixes and before or after the open-ended SENSITIVE patterns (`.xcprivacy`, `.entitlements`, `Info.plist`, `/project.yml`, `.github/workflows|actions/`, `fastlane/metadata/`): zero cases. The exact LOCK_CONFIG and JUDGE_FILES names fold to themselves. Over all non-ASCII code points, the only gap between Python's full case folding and the JS NFKC-plus-lowercase fold is ß → ss, which no lock or judge name contains.

(3) The name RERUN now also yields to `disguised`. `disguised` is a fixed escalation (`fixedParts`, and the REWORK exit is skipped for it), so this turns a RERUN into ESCALATE with a `name check:` note, never into APPROVE. Lens names reach the approver only through `ascii()`.

(4) The scope INVALID now counts only names without C0 characters. Calls that used to be INVALID and now continue are the ones where every name is forged. Those only get this far beside a lock change or the cap (otherwise the name RERUN fires first), so they end in ESCALATE. The opposite cases now return INVALID, which is a call error back to the PM and never an approval.

(5) The token note: the exact file keeps the "holds a token" wording, and a name that only folds to it says "may hold".

Nothing in the diff is a secret. The fold and per-call `new RegExp` have no ReDoS risk, and lone surrogates do not make them throw. Lens prompts are unchanged; the selftest now pins the lens diff to the closing backtick.

Measured here: `python3 -I scripts/factory-review-selftest.py` exits 0 ("all cases match"), and `--mutate` reports 131/131 mutations caught (with TMPDIR set to the scratchpad). Transcribing the new needles of claims 8, 9 and 10 gives 0 occurrences at the base and 1 at the head, and every LOCK/JUDGE list entry is lower case on both trees.

Two minor findings remain, both about documentation accuracy and future guard behaviour.

## Befunde

1. **minor** `Tests/CISmoke/TheFactoryReviewersAreReadOnlyTests.swift`:304 — The new lower-case claim (every LOCK_CONFIG/LOCK_DIRS entry must equal its lowercased() form) contradicts the exact-case subset check at line 285 (`files.isSubset(of: lockFiles)`, where `files` holds the hook's PROTECTED_FILES and the permissions.ask paths as written). If a mixed-case path such as `Edit(/Resources/iOS/Info.plist)` is ever added to permissions.ask or to the hook (`.claude/rules/context.md` §3 already calls `Resources/iOS/Info.plist` founder-gated), the two assertions cannot both pass. That invites loosening the guard rather than escalating the path (#364). The same pattern is at line 331 for the judge lists. No impact today: every current lock path is lower case.
   - Vorschlag: Lowercase the hook and permissions.ask side before the subset check (`Set(files.map { $0.lowercased() }).isSubset(of: lockFiles)`), so that writing a mixed-case lock path in folded form satisfies both claims.
2. **minor** `.claude/workflows/echoel-factory-review.js`:291 — The comment ('A name that could be one of them on ANY file system counts as one') and SKILL.md:174 ('in JEDER Schreibweise, die auf irgendeinem Dateisystem diese Datei sein kann') claim more than `fold()` does. NTFS treats `.claude/settings.json.` (trailing dot), `.claude/hooks./x.py`, `.claude/settings.json::$DATA` and 8.3 short names as the same file, and fold matches none of them. Full Unicode case folding also maps ß to ss, which fold does not; that touches the SENSITIVE names `docs/accessibility.html` and `docs/impressum.html`. The founder works on macOS and sessions run on Linux, so there is no practical bypass. The text just promises a guarantee the code does not have.
   - Vorschlag: Narrow both texts to what is folded: case-insensitive and normalization-insensitive APFS/HFS+ (including the HFS+ ignorable code points). Optionally say that NTFS aliases and full case folding (ß/ss) are not covered.
