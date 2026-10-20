# Runde 1 — code-reviewer

Workflow `wf_1edd4391-ce0` — Prüfer-Fassung von der Job-Basis (`f5a495fda`), Bereich `f5a495fda..2ee3c736d` mit den sechs `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [], `founderAssumptions` 1. Gesamtentscheidung: **REWORK** — 2 offene Befunde, Nacharbeit 1 von 2; der Approver lief nicht. `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Nichts außerhalb von `paths`. Urteil der Linse: **CHANGES**.

## Zusammenfassung

I checked the job 005 diff (f5a495fda..2ee3c736d) against the spec and against the base copy of the workflow. Most of it holds:
- Only an entry that is exactly '' is dropped now.
- The name RERUN yields to the cap, a lock change and a disguised name.
- lockChanged, judgeChanged and SENSITIVE are matched on the folded name. I compared these rules with the base copy: each folded set contains the base set, so lock, judge and sensitive catch more names and lose none.
- The token note now has a second, weaker wording for a name that only folds to the token file.
- The lens-diff pin is back.
- The Swift guard needles for claims 8 to 10 match the code at head and are missing at base.
- The plain selftest exits 0. I also ran all 131 mutation rows in memory, writing no file: 131 caught, none stale.

One rule is looser than at base. The scope INVALID check now leaves C0-forged names out entirely. If every lens forges the names inside paths while a real name lies outside, a capped round (or one with a lock change) returns INVALID, where the base escalated. That breaks criterion 4 and the code comment's own reason for the change. I ran it to confirm: base ESCALATE with the rework cap, head INVALID "none of the 1 changed file(s) ... lies under paths". There are also two minor findings: a gap in the token-note tests and one comment that overstates what reaches the reason.

## Befunde

1. **major** `.claude/workflows/echoel-factory-review.js`:329 — The scope INVALID test is now `named.length && named.every(f => !inScope(f))`, and `named` leaves out every C0-forged name. This lets forged names turn a fixed escalation into INVALID, the very thing the comment at lines 324-326 and criterion 4 rule out. Repro, run in memory: round 3 with open majors, paths ['scripts'], every lens reports ['docs/outside.md', 'scripts/INDEX.md\n']. Base f5a495fda returns ESCALATE ("rework cap of 2 reached ...; noted: name check: ..."). Head 2ee3c736d returns INVALID ("none of the 1 changed file(s) ... lies under paths"). The same happens with a lock change in place of the cap, e.g. ['.mcp.json', 'scripts/INDEX.md\n']. INVALID sends the PM back to call again, which reopens the re-call loophole that the cap escalation exists to close. SKILL.md ("macht den Aufruf nie INVALID") and scripts/INDEX.md ("nie ein Scope-INVALID") also become untrue for this input. The selftest only covers the case where every name is forged (line 293), so nothing catches the partial case.
   - Vorschlag: Make the call INVALID only when NO listed name, forged or not, lies under paths and at least one unforged name exists: `if (named.length && changed.every(f => !inScope(f)))`. The all-forged case keeps passing (named is empty). Add a selftest case: at the cap with forged in-scope names plus a real out-of-scope name, expect ESCALATE with 'rework cap' and 'name check:'.
2. **minor** `scripts/factory-review-selftest.py`:225 — The two cases for the real token file (lines 223-225 and 356-358) only check `reasonHas('rotate it and remove the commit')`. The new weaker note ("a name that folds to ... may hold its token: if it does, rotate it and remove the commit ...") contains the same phrase. I ran a mutation in memory that gives the exact `.claude/settings.local.json` the weaker "may hold" wording (workflow line 366): every selftest case still matched. So nothing pins the stronger "holds a token" statement for a committed token.
   - Vorschlag: In both cases, assert that the reason includes '.claude/settings.local.json holds a token'. Add a MUTATIONS row that replaces the exact-file note with the folded wording.
3. **minor** `.claude/workflows/echoel-factory-review.js`:326 — The comment says a forged name "still counts as outside and as sensitive below — nothing a lens reported leaves the reason". Forged names only ever come with an ESCALATE, and on that path `reason` never lists outsideScope or sensitiveOutside; only the APPROVE branch adds "not covered". The forged name survives in the returned scopeInfo, and through it in board scopeOpen, not in the reason text. Criterion 6 asks that comments say the same as the code.
   - Vorschlag: Reword to "nothing a lens reported leaves the result (outsideScope / sensitiveOutside)", or add the forged sensitive names to the escalation reason.
