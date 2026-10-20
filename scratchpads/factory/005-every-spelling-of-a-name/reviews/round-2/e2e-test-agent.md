# Runde 2 — e2e-test-agent

Workflow `wf_b13afc76-111` — Prüfer-Fassung von der Job-Basis (`f5a495fda`), Bereich `f5a495fda..92e8052ed` (Nacharbeit seit `2ee3c736d`) mit den sechs `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [], `founderAssumptions` 1. Gesamtentscheidung: **REWORK** — 1 offener Befund, Nacharbeit 2 von 2; der Approver lief nicht. `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Nichts außerhalb von `paths`. Urteil der Linse: **PASS**.

## Zusammenfassung

Ship-path review of job 005, round 2 (rework f5a495fda..92e8052ed, delta since 2ee3c736d).

Round-1 findings:
- The major that code-reviewer and I both raised is fixed. A C0-forged name inside paths, next to a real name outside paths, used to make the call INVALID and lose the cap or lock escalation. I loaded base, round-1 and head in memory under Node, with no file in the repo. The round-1 repro (['scripts/INDEX.md\u0001', '.claude/hooks/x.py'] under paths ['scripts']) gives base ESCALATE, round 1 INVALID, head ESCALATE (lock part kept, 'name check:' noted). The cap repros give the same three results.
- Why the new rule `!forged && ...` is safe: a forged name always makes garbled non-empty. So it gets past the name RERUN only next to the cap, a lock change or a disguised name, and all three are fixed escalations. With a forged name present the decision can be ESCALATE or a missing-lens RERUN, never APPROVE.
- My minor is fixed: the guard now requires each LOCK/JUDGE entry to be ASCII and lower case.
- Code-reviewer's two minors and security's subset minor are fixed. The 'holds a token' wording is pinned. The comment now says the forged name stays in the result, not in the reason text. The subset check compares lower-cased paths.
- Security's overclaim minor is narrowed in the workflow comment, SKILL.md, INDEX and spec, but one sentence of the selftest docstring was missed (minor below).
- The ux minors are fixed. A name that only folds to the lock or judge path is called 'a name that folds to it' in the reason, the approver prompt and the judge reason.

Rule comparison against git show f5a495fda:.claude/workflows/echoel-factory-review.js: no rule is removed or loosened.
- Only an exactly empty entry is dropped now; before, a blank name was dropped too. That is stricter.
- Lock, judge and SENSITIVE are matched on the folded name. The lists are ASCII lower case and the fold never touches an ASCII prefix, so this is a superset.
- The name RERUN now yields to a disguised name, which only turns a RERUN into an ESCALATE.
- With a forged name present the scope INVALID is skipped, and those cases now ESCALATE.
- The exact token file keeps 'holds a token'. A name that only folds to it gets an extra, hedged note.
- Names reach the approver prompt through asFound/shownNames, which still escapes each name with ascii(). The 'cannot break out into the approver prompt' case still passes.
- Selftest: no mutation row was dropped. One was renamed ('blank entries kept' became 'empty entries kept'), and 116 rows became 136.

Measured here:
- `python3 -I scripts/factory-review-selftest.py` exits 0.
- All 136 MUTATIONS, run in memory with no temp file: 136/136 caught, none stale.
- The guard needles of claims 8, 9 and 10, transcribed: 0 hits at f5a495fda and 1 at 2ee3c736d and at head. That is forward and red at base because of the change. The capReached, isLockConfig and isJudge counterweights are 1 on every tree.
- Claim 8's lower-cased subset holds on base and head: hook plus permissions.ask = {.claude/settings.json, .mcp.json, .claude/hooks/}. No list entry is unfolded.
- `doctor.py --section B`: 0 critical. swift-escapes OK. foreign-needles: no broken needle.

Ship path: the diff touches no target, entitlement, Info.plist, project.yml or Sources/ file. Gates for 92e8052ed:
- Xcode Compile Check: success. It compiles Sources/ only and proves nothing about the changed guard file.
- CI/CD Pipeline: Build for Testing success (completed 02:58:43), so TheFactoryReviewersAreReadOnlyTests compiles in this version.
- Run Tests is still in_progress. Whether claims 8 to 10 run is unobserved (#445/#807). Run Tests for 2ee3c736d also still reads in_progress, which may be a stale page (#1416).
- The JS workflow and the Python selftest run in no gate.
- origin/main is at 71fa9b7af, and neither the base nor any job commit is an ancestor of it, so the job has not landed.

Nothing is device-verified; the job touches no app.

## Befunde

1. **minor** `scripts/factory-review-selftest.py`:16 — The docstring still says the fold covers 'every spelling that could be it on a case-insensitive volume'. That is the overclaim security raised in round 1, and the rebuttal says it was narrowed in the comment, SKILL.md, INDEX and spec, but this sentence was missed. NTFS is a case-insensitive volume too, and its aliases (a trailing dot, ::$DATA, 8.3 names) and full case folding (ss for the German sharp s) are not matched. Criterion 6 names this docstring explicitly.
   - Vorschlag: Narrow it the way the workflow comment and SKILL.md now read: every spelling that is the file on an APFS or HFS+ volume (case, normal form, ignorable code points), not NTFS aliases and not full case folding.
