# 003 — Die Sperrliste gilt von der Job-Basis, die Abnahme wird gezählt statt geglaubt

## Goal
Ein Factory-Job kann seine eigene Prüfung nicht aufweichen: die gesperrten Dateien werden so
gelesen, wie sie an der Job-Basis standen, eine Änderung an der Sperr-Konfiguration eskaliert
immer, und der Workflow zählt selbst, ob der Approver jedes Kriterium der Spec benotet hat.

## Assumptions
- Herkunft: der offene Major aus Job 001, Runde 3 (Ship-Pfad-Linse, `wf_74fa31d5-4ba`), und die
  Minors derselben Runde. Job 001 ist eskaliert (Inbox GM27); dieser Job ist die dort empfohlene
  Nachfolge und beginnt unter der Delegation des Founders — ein Nein zu GM27 nimmt ihn zurück.
- Die Konfiguration, die die Sperre DEFINIERT, ist `.claude/settings.json`, `.mcp.json` und alles
  unter `.claude/hooks/` (alle drei stehen in `permissions.ask`). Eine Änderung daran entscheidet die
  Factory nie selbst: deterministisch ESCALATE, ohne Ermessen des Approvers.
- `.claude/rules/context.md` §3 wird NICHT deterministisch gesperrt, weil die Datei auch anderes
  Gesetz trägt; der Approver vergleicht §3 an Basis und Kopf.
- Die Linsen melden die UNGEFILTERTE Dateiliste (`changedFiles`); was im Scope liegt und was
  draußen, rechnet der Workflow selbst nach Git-Pfadregeln. Eine Linse, die eine leere Liste
  meldet, während andere Dateien sehen, hat sich verzählt (`RERUN`), nicht der Aufruf.
- Der PM übergibt die Zahl der Kriterien (`criteria`), die Nummern der `[DEVICE]`-Kriterien
  (`deviceCriteria`) und die Zahl der `[FOUNDER]`-Annahmen (`founderAssumptions`, hier 0). Ein Eintrag mit
  Nummer 0 ist eine `[FOUNDER]`-Annahme.
- Sensible Flächen außerhalb des Scopes (Rechtstext, Datenschutz, Gesundheit, Entitlements,
  Privacy-Manifeste, Store-Text) deckt eine Freigabe nicht; sie kommen als `scopeOpen` ins Board.
- Der PRÜFER selbst gehört zu dem, was ein Job nicht aufweichen darf (Runde 1, Security-Linse; der Harness
  lädt `.claude/workflows/echoel-factory-review.js` und `.claude/agents/` aus dem Arbeitsbaum, also prüft ein
  Job, der sie ändert, sich mit seiner eigenen Fassung). Ein solcher Job durchläuft die Nacharbeit, endet aber
  nie in APPROVE. **Dieser Job eskaliert deshalb am Ende** — gewollt, er gehört zu GM27.
- Dieser Job hat kein Geräte-Kriterium: er berührt keine App.

## Acceptance criteria
1. Der Approver-Prompt liest die Sperrliste mit `git show <base>:` aus `.claude/rules/context.md`,
   `.claude/hooks/protect-founder-gated.py` und `.claude/settings.json` und prüft, dass `board.json` am
   Kopf dieselbe `base` führt — Selbsttest-Fall und `TheFactoryReviewersAreReadOnlyTests` Anspruch 7.
2. Eine Änderung an `.claude/settings.json`, `.mcp.json` oder unter `.claude/hooks/` ergibt ESCALATE,
   auch wenn der Approver APPROVE sagt und auch wenn die Datei weggeschoben wird (Dateiliste mit
   `--no-renames`); jeder Pfad, über den Hook und `permissions.ask` die Sperre definieren, steht in der
   festen Liste — Selbsttest-Fälle und Anspruch 8.
3. Der Workflow rechnet Scope und Außerhalb selbst aus `changedFiles`: leer bei allen Linsen →
   `INVALID`, leer oder ohne Liste bei einer → `RERUN` mit ihrem Namen, eine fehlende Linse → `RERUN`,
   Scope leer → `INVALID`; sensible Dateien außerhalb kommen als `sensitiveOutside` zurück —
   Selbsttest-Fälle.
4. `criteria` ist Pflicht; benotet der Approver nicht genau die Nummern 1..criteria je einmal oder
   weniger `[FOUNDER]`-Annahmen als `founderAssumptions`, ist es `RERUN`; die Art folgt allein der Spec
   (ein `device`- oder `founder`-Etikett auf einer anderen Nummer zählt als `code`, Nummer 0 ist immer
   `founder`); ein erfüllter `founder`-Eintrag ohne Verweis auf `FOUNDER_INBOX` oder
   `memory/decisions.md` samt Datum bleibt offen — Selbsttest-Fälle.
5. Der Datenblock im Approver-Prompt ist reines ASCII (kein U+2028, keine Gedankenstrich-Marker) und
   dekodiert zum selben JSON; Dateinamen der Linsen erreichen den Prompt nur auf demselben Weg —
   Selbsttest-Fälle.
6. `since` in Runde 1 ist `INVALID`, ein `paths`-Eintrag mit `.`-Segment oder `//` ebenso —
   Selbsttest-Fälle.
7. `factory-board.py`: `scopeOpen` hält einen fertigen Job auf `--open`, bis jeder Eintrag in
   `reviewedBy` einen anderen Job oder `founder JJJJ-MM-TT` nennt (`null` bleibt offen, jeder andere Wert
   ist ein Befund); ein `deviceOpen` oder `scopeOpen`, der keine Liste von Objekten ist, wird gemeldet
   statt abzustürzen — `--selftest` und `--mutate`.
8. `SKILL.md` sagt dasselbe wie der Workflow: Argumente, Sperrliste von der Basis, `verified`-Datum
   statt `VERIFIED-…`, welcher Gate-Lauf zählt und „kein Lauf“ über den ganzen Job, Website erst „done“
   auf `main`, „Docs-Satz“ nur intern und ohne `FEATURE_STATUS.md` — und zitiert nur Pfade, die
   existieren (`scripts/doctor.py --section B`).
9. Beide Selbsttests enden mit 0, und `--mutate` beider Werkzeuge fängt jede Zeile ihrer Tabelle — aus
   dem Repo nachrechenbar, eine veraltete Zeile ist ein Fehler.
10. Eine Änderung am Prüfer (`.claude/workflows/echoel-factory-review.js`, `.claude/agents/`) endet nie
   in APPROVE: Nacharbeit wie immer, sonst ESCALATE; SKILL.md sagt, wie ab Job 004 die Fassung von der
   Basis prüft — Selbsttest-Fälle und Anspruch 9.

## Out of scope
Ein Pro-Lauf-Token in den Markern (der Harness erlaubt kein `Math.random`), eine Prüfung der Rechts-
und Gesundheitstexte selbst, eine Änderung an `.claude/hooks/` oder `.claude/settings.json`.
