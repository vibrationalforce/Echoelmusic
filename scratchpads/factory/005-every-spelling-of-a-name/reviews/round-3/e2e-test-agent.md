# Runde 3 — e2e-test-agent

Workflow `wf_14ff98a0-be0` (nach einem Container-Neustart mit `resumeFromRunId` fortgesetzt; die vier Linsen kamen aus dem Journal, der Approver lief neu) — Prüfer-Fassung von der Job-Basis (`f5a495fda`), Bereich `f5a495fda..c130306c3` (Nacharbeit seit `92e8052ed`) mit den sechs `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [], `founderAssumptions` 1. Gesamtentscheidung: **ESCALATE** — the approver escalated. `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Nichts außerhalb von `paths`, `lockChanged`, `disguised` und `garbled` leer. Urteil der Linse: **PASS**.

## Zusammenfassung

Ship-path review of job 005, round 3. Job range f5a495fda..c130306c3, rework delta 92e8052ed..c130306c3.

Earlier findings, checked against the head:
- My round-1 major (a forged name inside paths made the call INVALID) and my round-1 minor (the lists must be ASCII lower case) were already fixed in round 2. Both still hold at the head.
- My round-2 minor is fixed: the selftest docstring at scripts/factory-review-selftest.py:16-17 now says "APFS or HFS+ volume; not NTFS aliases, not ß to ss".
- Security's round-2 major is fixed. asFound(…, true) keeps every lock and judge name a JSON string literal in the approver prompt (workflow:375-378, 393, 409). I ran it in memory under Node. The prompt reads `defines the lock ([".claude/settings.local.json"]; a name that folds to it: [".claude/Settings.local.json "])` and `own judge (a name that folds to it: [".Claude/Workflows/echoel-factory-review.js"])`. The selftest case "a lock and a judge name built as an instruction stay quoted in the approver prompt" passes, and three mutations pin it.
- Security's other minors are fixed: the guard now pins the fold definition (Swift:307-308), and the docstring is narrowed.
- Code-reviewer minor 1 is fixed: the `scope: none …` note (workflow:335, 488).
- Code-reviewer minor 2 and ux minor 3 are fixed: a fold-only judge name now gets a comparison sentence that names the file it folds to.
- Ux minor 2 is fixed: a fold-only name stays quoted in the reason.
- The round-2 rebuttal corrects the false "nothing left out" in round 1.

Rule comparison of the edited judge against `git show f5a495fda:.claude/workflows/echoel-factory-review.js`: no rule is removed or loosened.
- The rework only puts back the base's JSON quoting in the approver prompt.
- It adds a note. The note can never change a decision: a forged name always fills `garbled`, so it reaches that line only beside a fixed escalation.
- It adds a sentence built from the constants JUDGE_FILES and JUDGE_DIRS, run through ascii().

Measured, without writing a file:
- `python3 -I scripts/factory-review-selftest.py`: exit 0, "all cases match".
- All 143 MUTATIONS rows, run in memory through /dev/stdin: 143/143 caught, 0 survived, 0 stale. The unmutated source through the same path exits 0. 136 rows grew to 143 (7 new), none dropped, and 4 rows had their old text updated.
- The 11 workflow needles of guard claims 8-10, transcribed in Python on four trees: f5a495fda 8/11 (the fold-definition, lockChanged and judgeChanged needles are FORWARD), 2ee3c736d 11/11, 92e8052ed 11/11, c130306c3 11/11.
- `doctor.py --section B`: 0 critical.
- The factory board lists job 005 in Review, round 3, with no error.

Ship path:
- The diff touches no target, entitlement, Info.plist, project.yml, `.github/` or `Sources/` file.
- `Xcode Compile Check` for c130306c3 is success. It compiles `Sources/` only and proves nothing about the changed guard.
- CI/CD `Build for Testing` for c130306c3 is success (completed 03:12:23), so TheFactoryReviewersAreReadOnlyTests compiles, including the new fold pin.
- `Run Tests` is still in_progress. Whether claims 8-10 executed is unobserved (#445/#807).
- The JS workflow and the Python selftest run in no gate.
- Auto-Merge for c130306c3 is in progress. For 92e8052ed, Auto-Merge waited for the gates, which passed, but its 'Merge to main' step failed. origin/main is still 71fa9b7af and f5a495fda is not an ancestor of it, so the job has not landed. That failure does not come from this diff.
- Nothing is device-verified; the job touches no app.

One minor finding remains, below. VERDICT: PASS.

## Befunde

1. **minor** `Tests/CISmoke/TheFactoryReviewersAreReadOnlyTests.swift`:308 — The new pin matches the whole `const fold = ...` line exactly. Its stated reason, and the security suggestion it implements, only need `.toLowerCase()` inside the fold definition. A correct refactor would turn this blocking-bundle claim red: reordering the steps, adding a step, or renaming `hiddenChars`. The message would then say fold 'no longer strips hidden characters and padding, applies NFKC and lower-cases', which would be false (#364: forbid no correct work; #367: fail only for the named reason). It is latent today: the needle matches workflow:298 once, and Build for Testing compiled it.
   - Vorschlag: Anchor on the invariant instead. Find the line that starts with `const fold = (f) =>` in workflowCode() and assert that it contains `.toLowerCase()` (and `normalize('NFKC')` if NFKC should be pinned too). Narrow the message to what is checked.
