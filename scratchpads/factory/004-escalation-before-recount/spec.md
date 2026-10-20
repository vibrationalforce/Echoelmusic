# 004 — Keine Rückfrage hebt eine feste Eskalation auf, und ein `founder`-Etikett belegt keinen Code

## Goal
Eine Eskalation, die der Workflow aus eigener Messung kennt (Grenze erreicht, Sperr-Konfiguration geändert)
oder die der Approver ausspricht, steht vor jeder Zähl-Rückfrage, und ein Kriterium gilt nur dann als
belegter Code, wenn es als Code benotet ist.

## Assumptions
- Herkunft: die drei offenen Majors und die Minors aus Job 003, Runde 3 (`wf_c8778d4d-f9a`,
  `scratchpads/factory/003-locked-set-at-base/decision.md`). Alle drei Majors hat der PM vor dem Bau mit
  Attrappen nachgestellt (fünf Fälle, alle fünf wie gemeldet).
- [FOUNDER] Dieser Job beginnt unter der Delegation des Founders, solange GM27 (`docs/dev/FOUNDER_INBOX.md` §1)
  offen ist; ein Nein zu GM27 nimmt Job 003 und diesen Job zurück.
- Geprüft wird dieser Job mit der Prüfer-Fassung an SEINER Basis (`git show <base>:.claude/workflows/echoel-factory-review.js`
  in den Scratchpad, `Workflow({scriptPath})`, SKILL.md Schritt 4) — erstmals nicht mit der eigenen. Weil er den
  Prüfer ändert, eskaliert er am Ende über dieselbe Prüfer-Regel; das ist gewollt.
- Fest heißt: aus der eigenen Messung des Workflows (die Befunde der Linsen, die Dateiliste), nicht aus einer
  Antwort des Approvers. Bei einer festen Eskalation ist ein fehlender, leerer oder verzählter Approver ein
  Vermerk im Grund, nie ein `RERUN` — ein `RERUN` ruft dieselbe Runde noch einmal, und nichts hält dabei den
  Kopf fest.
- Der Approver zählt die Spec BLIND: er bekommt die Zahlen des PM nicht zu sehen, damit seine Zählung eine
  zweite Lesung ist und kein Echo. Weicht sie ab, bleibt es beim ersten Mal `RERUN`; mit `recount: true`
  (der PM hat neu gezählt und ruft erneut) ist eine zweite Abweichung `ESCALATE` statt einer Schleife.
- `fastlane/Deliverfile` (Abgabe-Konfiguration: `submit_for_review`, `automatic_release`) und
  `fastlane/Pluginfile` (Gems, die in der Signier-Lane mit dem App-Store-Connect-Schlüssel laufen) sind
  Ship-Flächen wie `Fastfile` und `Appfile`.
- Dieser Job hat kein Geräte-Kriterium: er berührt keine App.

## Acceptance criteria
1. Grenze erreicht oder Sperr-Konfiguration geändert → `ESCALATE`, gleich ob der Approver nichts, eine leere
   Liste, eine abweichende Zählung oder eine falsch benotete Menge liefert; der Grund nennt die Abweichung —
   Selbsttest-Fälle und Mutationen.
2. Sagt der Approver `ESCALATE` oder stellt er eine Frage an den Founder, ist es `ESCALATE` vor jeder
   Zähl-Rückfrage, mit Vermerk der Abweichung — Selbsttest-Fälle.
3. Ein nummeriertes Kriterium mit `founder`-Etikett zählt nie als Code-Beleg: erfüllt nur mit datiertem
   Beleg in `FOUNDER_INBOX` oder `memory/decisions.md`, sonst `ESCALATE`; das Log nennt es nicht `code` —
   Selbsttest-Fälle.
4. Der Approver-Prompt nennt keine Zahl des PM; Linsen und Approver lesen die Spec am Kopf-SHA
   (`git show <head>:<job>/spec.md`) — Selbsttest-Prompt-Fälle.
5. `recount: true` macht eine Zählabweichung zu `ESCALATE`; ohne es bleibt sie `RERUN`; `recount` ist ein
   Boolean oder fehlt, sonst `INVALID` — Selbsttest-Fälle.
6. Dateinamen der Linsen: erst entquotet, dann auf leer geprüft (`""` → `RERUN`); C1-Steuerzeichen,
   Zeilen- und Absatztrenner, Bidi- und Null-Breite-Zeichen → `RERUN` mit dem Namen der Linse —
   Selbsttest-Fälle.
7. `SENSITIVE` umfasst `fastlane/Deliverfile` und `fastlane/Pluginfile`; eine Änderung an
   `.claude/settings.local.json` sagt im Grund, dass das Token zu tauschen und der Commit zu entfernen ist —
   Selbsttest-Fälle.
8. `SKILL.md` sagt dasselbe wie der Workflow: die Reihenfolge der Eskalation, `recount`, die blinde Zählung,
   ein `RERUN` ruft dieselbe Runde mit demselben Kopf, nach `ESCALATE` kein neuer Aufruf desselben Jobs,
   der Kosten-Satz (der Approver läuft auch bei einer Sperr-Änderung), die Lesart eines fehlenden
   `deviceCriteria`, die `reviewedBy`-Vorlage (ein FERTIGER Job), die Lese-Liste eines Wächters über jede API,
   die Token-Prüfung vor dem Push — und zitiert nur Pfade, die existieren (`scripts/doctor.py --section B`).
9. Beide Selbsttests enden mit 0, und `--mutate` fängt jede Zeile seiner Tabelle — aus dem Repo nachrechenbar.
10. `TheFactoryReviewersAreReadOnlyTests` Anspruch 10: die feste Eskalation steht im Workflow-Code VOR beiden
    Zähl-Rückfragen (`disagree` und die benotete Menge), und `metCode` schließt das `founder`-Etikett aus —
    in Python gegen Basis und Kopf transkribiert.

## Out of scope
Eine Sperre gegen einen zweiten Aufruf derselben Runde (der Workflow hat kein Gedächtnis zwischen Aufrufen —
SKILL.md regelt es), eine Änderung an `.claude/hooks/`, `.claude/settings.json` oder `.claude/agents/`,
`factory-board.py`.
