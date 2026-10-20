# Runde 1 — ux

Workflow `wf_1edd4391-ce0` — Prüfer-Fassung von der Job-Basis (`f5a495fda`), Bereich `f5a495fda..2ee3c736d` mit den sechs `paths` aus `board.json`, `criteria` 8, `deviceCriteria` [], `founderAssumptions` 1. Gesamtentscheidung: **REWORK** — 2 offene Befunde, Nacharbeit 1 von 2; der Approver lief nicht. `judgeChanged`: `.claude/workflows/echoel-factory-review.js`. Nichts außerhalb von `paths`. Urteil der Linse: **PASS**.

## Zusammenfassung

UX/claims lens, round 1. No earlier reviews exist for this job (the job directory holds only spec.md and board.json). The diff changes no app code and no user-facing copy: no store text, website, CLAIMS.md, FEATURE_STATUS.md or Swift UI. So the questions about health, wellness or esoteric wording, accessibility and Uncodixfy do not apply. The only text a person sees is the escalation reason the founder reads in decision.md and the inbox, plus the approver prompt.

Because the diff changes .claude/workflows/echoel-factory-review.js, I compared every rule against f5a495fda. No rule is removed or loosened:
- Dropping only empty entries (filter f !== '' instead of f.trim()) keeps more names.
- lockChanged, judgeChanged and sensitiveOutside now match the folded name (hidden characters removed, padding trimmed, NFKC, lower case), and the SENSITIVE regexes match case-insensitively. Each match is a superset of the old one: the lists are ASCII lower case, and folding can only remove non-ASCII or C0 characters, which never breaks an ASCII prefix.
- The name RERUN now yields to a disguised name. That turns a RERUN into an ESCALATE carrying a 'name check:' note, never into an APPROVE.
- The scope INVALID now ignores C0-forged names. A name that is all-forged can only pass the garbled check beside the cap or a lock change, and both end in ESCALATE. A mixed set where every real name lies outside paths is still INVALID.
- The token note keeps the exact check and adds a hedged note for names that only fold to the token file.
- The approver change is a comment only ('blind count' became 'own count, made first'); its prompt and the board/reviews exclusion are unchanged.

SKILL.md, scripts/INDEX.md and the selftest docstring match the code: only empty entries drop out, the fold, the yield to a disguised name, and a C0 name never causing INVALID. There are two minor wording issues.

## Befunde

1. **minor** `.claude/workflows/echoel-factory-review.js`:371 — Founder-facing reason sentences overstate a fold-only match. For a name that only FOLDS to the lock (e.g. '.claude/settings.local.json ' reported by one lens, or a U+FEFF lookalike), the reason says 'the change edits the lock configuration (...)', and the token note in the same sentence hedges 'a name that folds to .claude/settings.local.json may hold its token: if it does'. The founder reads a certainty and a doubt about the same name side by side. Line 364 says the reason avoids 'calling the lookalike the token file', but this clause calls it the lock configuration. The same certainty sits in the approver prompt (line 376 'This change edits the configuration that defines the lock'; line 392 'This change edits the factory's own judge'), where it can flow into forTheHuman, and in the judge reason (line 512 '... edits the factory's own judge (...), which cannot approve itself') for '.claude/Workflows/...'. On a case-sensitive checkout that file is not the judge the harness runs, and `git show <base>:<that file>` (line 392) finds no such path at the base. The escalation itself is correct, which is why this is minor.
   - Vorschlag: Split exact matches from fold-only matches when building the text: keep 'edits the lock configuration (X)' for exact names, and for fold-only names write e.g. 'a name that folds to the lock configuration (X)'. Do the same in fixedTold and the judge prompt and reason, and tell the approver to compare against the canonical path (JUDGE_FILES / LOCK_CONFIG) rather than the lookalike.
2. **minor** `.claude/workflows/echoel-factory-review.js`:293 — The comments contradict the code and each other (criterion 6: workflow comments must say what the code does). Line 292-293 says 'a padded token name is still the token file', and the guard message at Tests/CISmoke/TheFactoryReviewersAreReadOnlyTests.swift:301 repeats 'a token name a lens padded is still the token file'. The code at lines 366-368 deliberately says only 'may hold its token' for such a name. Line 364 and SKILL.md:181 ('kann ihr Token tragen, nie trägt') say the reverse of line 293.
   - Vorschlag: Reword line 293 and the test message at :301 to match the code: a padded name 'counts as the token file for the lock' or 'may be the token file', not 'is still the token file'.
