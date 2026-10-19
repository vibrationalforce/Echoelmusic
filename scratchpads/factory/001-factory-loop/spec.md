# 001 — Die Factory-Schleife selbst

## Goal
Eine Sitzung kann eine mehrteilige Scheibe als Factory-Job fahren: Spec mit Annahmen, Bau durch den
PM, bis zu vier nur lesende Prüf-Linsen parallel, höchstens zwei Nacharbeitsrunden, dann ein
getrennter Approver, der freigibt oder über `docs/dev/FOUNDER_INBOX.md` eskaliert.

## Assumptions
- Der Builder ist der PM, kein Subagent — `.claude/rules/context.md` §5 verlangt Nur-Lesen für jeden Subagenten.
- Jobzustand liegt unter `scratchpads/factory/`, nicht in einem neuen Top-Level-Ordner `factory/` (Top-Level-Ordner sind Founder-Sache).
- APPROVE erfindet keinen Merge-Pfad: es gilt der Weg, den der Baum der Scheibe heute hat; ob `EchoelStudio/` nach `main` kommt, ist Founder-Sache (F-08b).
- Die Agenten erben das Sitzungsmodell; nur der Approver bekommt `effort: 'high'` (keine festen Modell-Etiketten wie im Clip).
- Drei Linsen sind immer an (Code, Security, UX/Claims), eine vierte nach Pfad.
- Das Video ist Inspiration, kein Code: nichts daraus wurde kopiert. Das Reel lag als Founder-Upload vor; die Endkarten-URL und der Code des Kanals wurden nicht geöffnet.

## Acceptance criteria
1. `.claude/workflows/echoel-factory-review.js` ist syntaktisch gültig (in einer async-Hülle mit `node --check` geprüft) und lehnt fehlerhafte Argumente mit `decision: "INVALID"` ab, statt zu raten.
2. Jeder Agentenaufruf im Workflow trägt die Klausel aus `.claude/rules/context.md` §5 wörtlich — Wächter `Tests/CISmoke/TheFactoryReviewersAreReadOnlyTests.swift` Anspruch 1 und 2.
3. Jeder `agentType` im Workflow steht im ultracode-Roster — derselbe Wächter, Anspruch 3.
4. Die Nacharbeitsgrenze ist an EINER Stelle definiert (`MAX_REWORK_ROUNDS` im Workflow) und der Skill nennt dieselbe Zahl — Anspruch 4.
5. Ein CHANGES ohne Befund mit Datei und Schwere blocker/major zählt nicht; ein PASS mit Blocker zählt als CHANGES; eine fehlende Prüfer-Antwort ist kein Pass (`RERUN`).
6. `scripts/factory-board.py --selftest` endet mit 0 und das Werkzeug steht in `scripts/INDEX.md` (`TheToolboxHasAnIndexTests`).
7. Der Skill zitiert nur Pfade, die existieren (`TheAgentRecipesPointAtThisRepoTests` Anspruch 3, `scripts/doctor.py --section B`).
8. Kein Geräte-Kriterium — die Scheibe berührt keine App (bis 2026-10-20 trug die Zeile die Geräte-Marke mit „entfällt“; Job 003: ein Satz ohne Geräte-Bitte trägt keine Geräte-Marke).

## Out of scope
Ein Web-Board als Artifact, ein automatischer Merge, ein Builder-Subagent, eine Änderung an Workflows unter `.github/`.
