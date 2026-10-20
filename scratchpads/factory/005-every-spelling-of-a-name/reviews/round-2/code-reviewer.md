# Runde 2 — code-reviewer

Workflow `wf_b13afc76-111` — Prüfer-Fassung von der Job-Basis (`f5a495fda`), Bereich `f5a495fda..92e8052ed` (Nacharbeit seit `2ee3c736d`) mit den sechs `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [], `founderAssumptions` 1. Gesamtentscheidung: **REWORK** — 1 offener Befund, Nacharbeit 2 von 2; der Approver lief nicht. `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Nichts außerhalb von `paths`. Urteil der Linse: **PASS**.

## Zusammenfassung

Round 2 code review of job 005 (f5a495fda..92e8052ed, rework since 2ee3c736d).

Round-1 findings. All are fixed except half of one ux suggestion (finding 2 below):
- Major (code-reviewer #1 and e2e #1, the same issue), fixed. The scope check is now `if (!forged && changed.length && outsideScope.length === changed.length)` (workflow:332-333). I ran both round-1 repros against the base and the head copy in memory. Cap, forged name inside paths, real name outside: ESCALATE on both, with 'rework cap' and 'name check:'. Lock outside paths beside a forged in-scope name: ESCALATE on both, with 'lock configuration'. Head no longer returns INVALID for either. Three new selftest cases and two mutations pin this.
- code #2 (token-note pin), fixed. Both cases now require '.claude/settings.local.json holds a token', and the 'the exact token file only may hold a token' mutation is caught.
- code #3 (comment wording), fixed: it now says 'in the result (outsideScope, sensitiveOutside)'.
- e2e #2 and security #1, fixed. Swift claims 8 and 9 now require ASCII lower case, and the hook and permissions.ask paths are lower-cased before the subset check.
- security #2, fixed. The 'ANY file system' wording is narrowed to APFS/HFS+ in the comment, SKILL.md and INDEX, and the NTFS and ß→ss gaps are stated.
- ux #1, wording part fixed: `asFound` writes 'a name that folds to it: …' in the reason, in fixedTold and in the judge prompt and reason. The second half of the suggestion (the canonical comparison path) was not done; see minor finding 2.
- ux #2, fixed: the comment and the guard message now say 'counts as the token file for the lock'.

Rules compared with f5a495fda:
- The only base rule the rework changes is the scope INVALID. With any C0 name in a list, a call where every name lies outside paths now goes on instead of returning INVALID.
- Such a name gets past the name RERUN only beside the cap, a lock change or a disguised name. Each of these puts a part into `fixed`, so the round always ends in ESCALATE, never APPROVE. I confirmed this by tracing the code and by an in-memory run.
- So this is INVALID becoming ESCALATE. Criterion 4 asks for exactly that ('in keiner Richtung'), and it is not a path to approval.
- No other rule is removed or loosened. The fold, the yield of the name RERUN to a disguised name, the case-insensitive SENSITIVE match and the two-step token note each only add escalations.

Measured here, on a clean worktree at 92e8052ed:
- Plain `python3 -I scripts/factory-review-selftest.py`: exit 0, 'all cases match'.
- All 136 MUTATIONS rows, run in memory with the mutated source piped through /dev/stdin, so no file was written: 136/136 caught, none survived, none stale.
- `doctor.py --section B`: green.
- `factory-board.py --selftest`: ok. It writes to a self-deleting temp directory outside the repo.
- Swift claims 8-10 transcribed in Python. At f5a495fda the two fold needles and the widened name-RERUN needle are missing and the cap-before-RERUN order fails. At 2ee3c736d and 92e8052ed all are present. The lock and judge entries are ASCII lower case, and the lower-cased subsets hold on all three trees.
- Every other workflow needle the guard reads is still present exactly once.
- The Swift guard is checked by reading only. I see no compile issue, but the build was not run here: only CI/CD `Build for Testing` can prove it compiles.

Two minor findings remain. Neither blocks shipping.

## Befunde

1. **minor** `.claude/workflows/echoel-factory-review.js`:333 — A forged name can skip the scope INVALID while every real name lies outside paths, for example when the PM passed the wrong paths. The round then escalates, but nothing in the reason says that nothing under paths was reviewed, although the lenses and the approver read an empty scoped diff. Reproduced in memory: paths ['nothing'], every lens reports ['.mcp.json', 'scripts/a\u0001']. Base f5a495fda returns INVALID ('none of the 2 changed file(s) ... lies under paths'). Head returns ESCALATE ('the change edits the lock configuration (.mcp.json); noted: name check: ...'). The founder gets an acceptance list graded on nothing and no sign of it; only outsideScope carries the fact. ESCALATE is the outcome criterion 4 asks for, so the decision is right; the gap is in what the reason tells the founder.
   - Vorschlag: When `forged` skips the INVALID and every non-forged name lies outside paths, push a note such as `scope: none of the N named file(s) lies under paths` into `notes`. It then reaches the escalation reason next to 'name check:'. Add one selftest case (wrong paths, lock and a forged name: ESCALATE whose reason names the scope) and a mutation that drops the note.
2. **minor** `.claude/workflows/echoel-factory-review.js`:401 — For a judge name that only folds to the judge, e.g. '.claude/Workflows/Echoel-Factory-Review.js', the approver prompt still says 'Compare every rule of the edited file against `git show ${a.base}:<that file>`'. On the case-sensitive Linux checkout that path does not exist at the base, so there is nothing to compare against. Round 1 (ux #1) also suggested naming the canonical JUDGE_FILES/JUDGE_DIRS path for the comparison. That half was not applied, yet rebuttal.md says 'Nicht eingearbeitet: nichts'. The outcome is still ESCALATE, which is why this is minor.
   - Vorschlag: Where `asFound` reports a fold-only judge name, name the canonical path as the comparison target, e.g. 'compare against `git show ${a.base}:.claude/workflows/echoel-factory-review.js` (or the `.claude/agents/` file it folds to)'. Or record in the rebuttal that this half of ux #1 was left out on purpose.
