# Runde 2 — was eingearbeitet ist, was nicht, und warum

Workflow `wf_29831ef4-24e` auf `f61d7872d..6d168b44a` (Nacharbeit seit `9237c3c91`): REWORK, fünf Majors
(code einer, security zwei, ux einer, e2e einer). Die Befunde aus Runde 1 bestätigen die Linsen als
behoben oder widerlegt. Vier der fünf neuen Majors sind EINE Lücke von zwei Seiten gesehen: die Zahlen des PM wurden dem
Approver als Tatsache gesagt und dann gegen sich selbst gezählt. Jeder Befund ist vor der Reparatur mit
Attrappen-Agenten nachgestellt (`scripts/factory-review-selftest.py`), nicht geglaubt.

**Eingearbeitet (alle fünf Majors):**
- **`founderAssumptions` fehlte = 0, und der Prompt sagte „No Assumption is tagged [FOUNDER].“** (code, ux,
  security). Nachgestellt: ohne Argument war die Prüfung `0 < 0` und eine offene `[FOUNDER]`-Annahme kam
  durch. `founderAssumptions` ist jetzt Pflicht wie `criteria` (fehlt → `INVALID`, Fall „founderAssumptions
  absent“), und der Satz ist weg: der Prompt nennt die Zahl als Angabe des PM und verlangt einen
  Nummer-0-Eintrag für JEDE `[FOUNDER]`-Annahme der Spec.
- **Die Zählung selbst war geglaubt** (security). Neu: der Approver meldet aus seiner eigenen Lesung der Spec
  `specCriteria`, `specDevice` und `specFounder` (Pflichtfelder im Schema). Weicht eine von den Zahlen des PM
  ab, ist es `RERUN` mit beiden Werten — der PM zählt neu und ruft dieselbe Runde. Fälle: „the PM undercounts
  the criteria“ (4 gegen 3), „an omitted [FOUNDER] assumption“, „an approver that did not count“, und „the same
  [DEVICE] numbers in another order agree“ gegen eine reihenfolge-empfindliche Mutation.
- **`deviceCriteria` allein machte ein Kriterium unblockierend** (security). Nachgestellt mit der Antwort der
  Linse: `[1 code erfüllt, 2 code OFFEN, 3 code erfüllt]` bei `deviceCriteria [2]` war APPROVE. Jetzt doppelt
  geschlossen: die abweichende Zählung ist `RERUN` („a stale deviceCriteria“), und selbst bei gleicher Zählung
  ist eine Nummer nur `device`, wenn PM-Liste UND Approver-Etikett es sagen — sonst `code` („a code label
  inside deviceCriteria is code“, vorher als APPROVE gepinnt). Die Log-Zeile behauptet nicht mehr „per the
  spec“.
- **„Welcher Lauf zählt“ übersah, was ein Wächter liest** (e2e). Richtig: dieser Wächter liest
  `.claude/workflows/…`, `.claude/rules/context.md`, `.claude/skills/…`, `.claude/hooks/…` und
  `.claude/settings.json` — keiner davon steht in einem Pfadfilter. SKILL.md sagt jetzt: für einen Wächter,
  den der Job anlegt oder ändert, zählt ein früherer Lauf nur, wenn auch der Diff über jede Datei, die er
  liest, leer ist; sonst „transkribiert, kein Lauf“. Das deckt sich jetzt mit dem Wächter-Absatz derselben
  Datei. Für diese Nacharbeit heißt das: der Lauf auf `6d168b44a` belegt die Ansprüche 7–9 NICHT für den
  neuen Kopf — dieser Commit berührt die Wächter-Datei selbst, startet also einen eigenen Lauf.

**Eingearbeitet (alle zehn Minors):**
- code: ein offenes nummeriertes Kriterium mit `founder`-Etikett eskaliert statt nachzuarbeiten (Regel 4) ·
  Board-Fälle `scopeOpen: null` und `deviceOpen: 5`, die Mutation „scopeOpen list check dropped“ entfernt
  nur noch den Typtest · `DATE`/`REVIEWED` mit `fullmatch` (gemessen: `re.match` mit `$` nahm
  `"founder 2026-10-20\n"`), und ein Prüfer-Job zählt nur in `stage: "done"` · Anspruch 8 verlangt die
  Hook-Hälfte für sich und wird rot bei einer Datei-Regel in `permissions.ask`, die er nicht lesen kann
  (geprobt: `Edit(.mcp.json)`, einfach gequotete `PROTECTED_FILES`).
- security: `CLAUDE.md` und `.claude/rules/` — Linsen und Approver lesen sie bei einer Änderung an der Basis,
  eine Regel über Prüfen/Benoten/Freigeben ist Major bzw. Founder-Frage; die verbleibende Lücke steht in
  SKILL.md Schritt 4. Nicht in den Prüfer-Satz aufgenommen, weil fast jeder Job eine `CLAUDE.md` anfasst und
  dann keiner mehr freigegeben würde · `.claude/settings.local.json` in `LOCK_CONFIG` und `SENSITIVE` ·
  Dateiliste mit `git -c core.quotePath=false`, ein Paar Anführungszeichen wird gestrichen („a quoted hook
  name“ mit Oktal-Escapes eskaliert), ein Name mit Steuerzeichen ist `RERUN` mit dem Namen der Linse.
- ux: Schritt 7 nennt `founderAssumptions`, die `board.json`-Vorlage trägt die drei Zahlen.
- e2e: `fastlane/Fastfile` und `fastlane/Appfile` in `SENSITIVE` · Anspruch 7 pinnt jetzt auch den
  `board.json`-Satz (Spec-Kriterium 1 zitierte ihn dort, er stand nur im Selbsttest).

**Messung nach der Nacharbeit:** `factory-review-selftest.py` 101 Fälle, `--mutate` 76/76;
`factory-board.py --selftest` 6 geladen, 20 kaputte Boards gemeldet, `--mutate` 16/16;
`doctor.py --section B` 0 kritisch. Wächter-Ansprüche 1–9 in Python auf `f61d7872d`, `9237c3c91`,
`6d168b44a` und dem Arbeitsbaum transkribiert: am Kopf alle grün. Die Spec hat weiter 10 Kriterien;
2, 3, 4, 7 und 8 sind im Wortlaut an die Nacharbeit angepasst, die Nummern sind unverändert.
