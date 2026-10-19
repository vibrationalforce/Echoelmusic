# Job 001 — ESCALATE nach Runde 3 (2026-10-20)

## Why

Die Nacharbeitsgrenze (`MAX_REWORK_ROUNDS` = 2) ist erreicht, und ein Major ist offen
(Ship-Pfad-Linse, Runde 3, `wf_74fa31d5-4ba`): der Approver kennt nicht alle gesperrten Dateien
und liest ihre Liste aus dem Baum, den die Änderung selbst verändern kann.

- `.claude/hooks/**` fehlt: `.claude/settings.json` fragt vor jedem Edit dort
  (`Edit(/.claude/hooks/**)`), und der Hook nennt die Sperre seines eigenen Ordners „the
  founder's“ (`protect-founder-gated.py`, LIMITS). Ein Job, der den Hook ändert, käme durch.
- Der Prompt sagt „read both“, aber nicht von welchem Stand. Ein Job, der `.mcp.json` aus
  `PROTECTED_FILES` streicht und `.mcp.json` ändert, fände danach keine gesperrte Datei mehr.

Die anderen drei Linsen sagen PASS. Der Approver hat den Befund am Kopf `f209ecb16` nachgeprüft
und sieben von acht Kriterien belegt; Kriterium 8 ist eine `[DEVICE]`-Zeile ohne Prüfgegenstand.
Ein dritter Nacharbeitsschritt ist nach der eigenen Regel ausgeschlossen: wer ihn braucht, hat
eine Spec-Frage. Daher ein neuer Job statt Runde 4.

## Acceptance criteria

| # | Kriterium | Stand |
|---|---|---|
| 1 | Workflow syntaktisch gültig, falsche Argumente `INVALID` | erfüllt — `node --check` 0, Argumentprüfung Z. 126–162 |
| 2 | Jeder Agentenaufruf trägt die §5-Klausel wörtlich | erfüllt — 2 von 2 `agent(withReadOnly(` |
| 3 | Jeder `agentType` steht im Roster | erfüllt — 9 von 9 |
| 4 | Die Nacharbeitsgrenze an einer Stelle, der Skill nennt dieselbe Zahl | erfüllt — 2 und 2 |
| 5 | CHANGES ohne Beleg zählt nicht, PASS mit Blocker ist CHANGES, fehlende Antwort `RERUN` | erfüllt — Z. 192–213 |
| 6 | `factory-board.py --selftest` 0, Eintrag in `scripts/INDEX.md` | erfüllt |
| 7 | Der Skill zitiert nur Pfade, die existieren | erfüllt — 15 von 15 |
| 8 | `[DEVICE]` entfällt | ohne Prüfgegenstand — die Markierung war falsch, Job 003 streicht sie |

## For the human

**GM27 in `docs/dev/FOUNDER_INBOX.md` §1.** Frage: Job 001 so annehmen und den offenen Befund als
Job 003 bauen? Empfehlung: ja — es ist ein Satz im Approver-Prompt plus ein Selbsttest-Fall, nur
Werkzeug, macht die Prüfung STRENGER und ist umkehrbar; APPROVE merged nie. Job 003 nimmt auch
die Minors der Runde 3 mit (Liste in `scratchpads/factory/003-locked-set-at-base/spec.md`).
Unter deiner Delegation („du entscheidest alles“) ist Job 003 sofort begonnen worden; ein Nein zu
GM27 nimmt ihn zurück.
