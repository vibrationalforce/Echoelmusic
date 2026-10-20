# Runde 3 — ux

Workflow `wf_14ff98a0-be0` (nach einem Container-Neustart mit `resumeFromRunId` fortgesetzt; die vier Linsen kamen aus dem Journal, der Approver lief neu) — Prüfer-Fassung von der Job-Basis (`f5a495fda`), Bereich `f5a495fda..c130306c3` (Nacharbeit seit `92e8052ed`) mit den sechs `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [], `founderAssumptions` 1. Gesamtentscheidung: **ESCALATE** — the approver escalated. `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Nichts außerhalb von `paths`, `lockChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

UX/claims lens, round 3 of job 005. Verdict PASS: no blocker or major findings, two minors.

The diff changes no app code and no user-facing product copy. It touches no Sources/, no docs/ website, no fastlane metadata, no CLAIMS.md and no FEATURE_STATUS.md. So health, wellness or esoteric wording, VoiceOver, Dynamic Type, contrast, reduce motion, flash rate and the Uncodixfy rules do not apply. The only sentences a person reads are the escalation reason (decision.md and the inbox), the approver prompt, SKILL.md, scripts/INDEX.md, the selftest docstring and the guard messages.

Every round-2 finding is fixed in 92e8052ed..c130306c3:
- ux 1, security 3 and e2e 1: the selftest docstring (lines 16-17) now says APFS/HFS+, not NTFS aliases, not ß to ss.
- ux 2: in the reason, a name that only folds to the lock now stays quoted. Measured in memory: `(a name that folds to it: ".claude/settings.local.json ")`, so the trailing space is visible. An exact name is still shown bare.
- ux 3 and code 2: for a judge name that only folds, the approver prompt now names the file to compare against (JUDGE_FILES, or the file of the same folded name under JUDGE_DIRS). An exact judge name does not get that sentence.
- security 1 (major): in the approver prompt, lock and judge names are JSON string literals again, as at the base. Measured: `defines the lock ([".claude/settings.json"]; a name that folds to it: [".Claude/settings.json"])`. An instruction-shaped name stays inside `["..."]`.
- security 2: guard claim 8 now pins the `fold` definition. Transcribed in Python: the four needles occur 0 times at f5a495fda and once each at c130306c3.
- code 1: the reason now notes `scope: none of the N listed name(s) lies under paths ...` when a forged name skips the INVALID. That can only happen beside a fixed escalation, so the note never creates a new RERUN path.

The workflow is edited, so I compared every rule against f5a495fda. No rule is removed or loosened:
- Every name outside the reviewer fence in the approver prompt goes through ascii(), as at the base.
- The fold only adds matches for lock, judge and SENSITIVE. The lists are ASCII lower case, and fold is the identity on ASCII.
- The scope INVALID is skipped only when a forged name is present. Such a name gets past the name RERUN only with the cap, a lock change or a disguised name, and each of those escalates.
- The new judge sentence and the scope note only add information.

No CLAUDE.md or .claude/rules/ file is touched.

What I ran: `python3 -I scripts/factory-review-selftest.py` exits 0 ('all cases match'). `python3 -I scripts/doctor.py --section B` reports 0 critical findings. I loaded the head workflow under Node in memory (stub agents, nothing written) and read the reason and prompt text for 9 cases: exact plus fold-only lock, padded token from one lens, exact token, fold-only and exact judge, fold-only agents, wrong paths with a forged name and a lock change, cap with a forged name, NBSP from all lenses. I did not run `--mutate`, because it writes temp copies. Nothing is device-verified, and the job touches no app.

## Befunde

1. **minor** `.claude/workflows/echoel-factory-review.js`:409 — The new approver sentence says as a fact that 'A name that only folds to the judge has no copy at the base under that spelling'. Git paths are case-sensitive, so a lookalike such as `.claude/Agents/x.md` can already exist at the base if an earlier commit added it, and this job can then modify it. In that case the sentence is false, and it steers the approver away from the lookalike's real base copy toward a canonical file that may not exist. The round still escalates, so this only affects how accurate the forTheHuman comparison is.
   - Vorschlag: Hedge it, e.g. 'A name that only folds to the judge may have no copy at the base under that spelling: compare it against its own base copy if `git show` finds one, else against the file it folds to (...)'.
2. **minor** `.claude/workflows/echoel-factory-review.js`:488 — The new `scope: none ...` note is joined to the `name check:` note with '; ', the same separator used between the lenses inside the name check. Measured, the founder reads 'noted: name check: code-reviewer (...); security-agent (...); ux (...); scope: none of the 2 listed name(s) lies under paths, ...', where the scope note looks like a fourth name-check entry. This is readability only; the facts are all present.
   - Vorschlag: Join the lens entries inside `name check:` with ', ' (or join the notes with ' | '), so each note reads as a separate item in decision.md.
