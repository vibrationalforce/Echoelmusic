# Runde 2 — ux

Workflow `wf_b13afc76-111` — Prüfer-Fassung von der Job-Basis (`f5a495fda`), Bereich `f5a495fda..92e8052ed` (Nacharbeit seit `2ee3c736d`) mit den sechs `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [], `founderAssumptions` 1. Gesamtentscheidung: **REWORK** — 1 offener Befund, Nacharbeit 2 von 2; der Approver lief nicht. `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Nichts außerhalb von `paths`. Urteil der Linse: **PASS**.

## Zusammenfassung

This is the UX and claims review for round 2 of job 005. The verdict is PASS: I found no blocker or major issue, only three minor ones.

The diff touches no app code, no store text, no website, no CLAIMS.md and no FEATURE_STATUS.md. So health or esoteric wording, VoiceOver, Dynamic Type, contrast, reduce motion, flash rate and the Uncodixfy rules do not apply here. The only sentences a person reads are the escalation reasons (decision.md and the inbox), the approver prompt, SKILL.md, scripts/INDEX.md, the selftest docstring and the guard messages.

My two round-1 minors are fixed:
(1) A name that only folds to the lock or the judge is now shown as "a name that folds to it: …" by the new asFound helper. This holds in the lock part of the reason, the lock line of the approver prompt, the judge prompt and the judge reason. An exact name is never hedged. I checked this in memory: `.claude/Hooks/x.py` gives "(a name that folds to it: …)", and the exact `.claude/settings.local.json` gives "(.claude/settings.local.json); … holds a token: rotate it …".
(2) Workflow line 293 and the guard message now say "counts as the token file for the lock". That matches the hedged "may hold its token" note in the code.

The other lenses' round-1 findings are fixed as the rebuttal says. The forged-name INVALID gap is closed: a forged name in any list skips the scope INVALID, and three cases plus two mutations cover it. The security lens's "any file system" wording is narrowed to APFS/HFS+ in the code comment, SKILL.md and INDEX.md. The selftest docstring was not narrowed (finding 1 below).

The workflow file is edited, so I compared its rules against f5a495fda. No rule is removed or loosened:
- The approver prompt's names still go through ascii(), and its mutation row still exists.
- The scope INVALID is skipped only when a forged name is present. Such a name reaches that line only beside a fixed escalation.
- The fold only adds escalations.

What I ran, all without writing a file:
- `python3 -I scripts/factory-review-selftest.py` exits 0 with "all cases match".
- `python3 -I scripts/doctor.py --section B` reports 0 critical findings.
- I loaded the workflow under Node in memory and read the reason text for padded, case-changed, exact-plus-folded, judge-lookalike and `docs/PRIVACY.html` names. PRIVACY.html is listed as "not covered".

Nothing here is device-verified, and the job touches no app.

## Befunde

1. **minor** `scripts/factory-review-selftest.py`:16 — The docstring still says the fold catches 'every spelling that could be it on a case-insensitive volume'. Criterion 6 asks the docstring to say the same as the code. Rework 1 narrowed this claim in the workflow comment (lines 291-297), SKILL.md and INDEX.md to APFS/HFS+, saying that NTFS aliases and full case folding (ß to ss) are not covered. NTFS is a case-insensitive volume too, so the docstring keeps the over-claim the security lens raised in round 1. The rebuttal lists the comment, SKILL.md, INDEX and the spec as narrowed, but not the docstring.
   - Vorschlag: Reword line 16 to match the others, e.g. 'every spelling that is it on an APFS or HFS+ volume; not NTFS aliases, not ß to ss'.
2. **minor** `.claude/workflows/echoel-factory-review.js`:370 — asFound prints fold-only names through shownNames, which strips the JSON quotes. A name that only folds because of an ASCII-space pad therefore looks exactly like the real lock file. Measured in memory, the founder reads 'the change edits the lock configuration (a name that folds to it: .claude/settings.local.json ); a name that folds to .claude/settings.local.json may hold its token'. The name shown and the exact token file differ only by an invisible trailing space, so the hedge reads as self-contradictory. The founder cannot tell whether to rotate the token. Since rework 1, the approver prompt (line 385, and the judge line 401) has lost the quoted form too: at 2ee3c736d it printed ascii(lockChanged), e.g. [".claude/settings.local.json "], where the name's boundary was visible. Escaping is unchanged, so this is readability, not a loosened rule.
   - Vorschlag: In the fold-only half of asFound, keep each name quoted, e.g. folded.map(f => ascii(f)).join(', '), so a leading or trailing space is visible. Optionally say why it only folds.
3. **minor** `.claude/workflows/echoel-factory-review.js`:401 — For a judge name that only folds, e.g. '.claude/Workflows/echoel-factory-review.js', the prompt now says 'a name that folds to it', but it still tells the approver to compare 'against `git show <base>:<that file>`'. That path does not exist at the base, so the instruction points nowhere. The second half of my round-1 minor (compare against the canonical JUDGE_FILES / LOCK_CONFIG path) was not taken, and the rebuttal does not mention it. The round still escalates, which is why this is minor.
   - Vorschlag: When the judge match is fold-only, name the canonical path in the compare instruction, e.g. 'compare it against `git show <base>:.claude/workflows/echoel-factory-review.js` (or the agents file it folds to)'. Or state in the rebuttal why this is left out.
