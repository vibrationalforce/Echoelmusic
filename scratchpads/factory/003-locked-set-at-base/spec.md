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
- Der PM übergibt die Zahl der Kriterien (`criteria`) und die Nummern der `[DEVICE]`-Kriterien
  (`deviceCriteria`). Ein Eintrag mit Nummer 0 ist eine `[FOUNDER]`-Annahme.
- Sensible Flächen außerhalb des Scopes (Rechtstext, Datenschutz, Gesundheit, Entitlements,
  Privacy-Manifeste, Store-Text) deckt eine Freigabe nicht; sie kommen als `scopeOpen` ins Board.
- Dieser Job hat kein Geräte-Kriterium: er berührt keine App.

## Acceptance criteria
1. Der Approver-Prompt liest die Sperrliste mit `git show <base>:` aus `.claude/rules/context.md`,
   `.claude/hooks/protect-founder-gated.py` und `.claude/settings.json` — Selbsttest-Fall und
   `TheFactoryReviewersAreReadOnlyTests` Anspruch 7.
2. Eine Änderung an `.claude/settings.json`, `.mcp.json` oder unter `.claude/hooks/` ergibt ESCALATE,
   auch wenn der Approver APPROVE sagt — Selbsttest-Fall.
3. Der Workflow rechnet Scope und Außerhalb selbst aus `changedFiles`: leer bei allen Linsen →
   `INVALID`, leer bei einer → `RERUN` mit ihrem Namen, Scope leer → `INVALID` — Selbsttest-Fälle.
4. `criteria` ist Pflicht; benotet der Approver nicht genau die Nummern 1..criteria je einmal, ist
   es `RERUN`; ein `device`-Etikett außerhalb von `deviceCriteria` zählt als `code`; ein erfülltes
   `founder`-Kriterium ohne Verweis auf `FOUNDER_INBOX` oder `memory/decisions.md` bleibt offen —
   Selbsttest-Fälle.
5. Der Datenblock im Approver-Prompt ist reines ASCII (kein U+2028, keine Gedankenstrich-Marker) und
   dekodiert zum selben JSON — Selbsttest-Fall.
6. `since` in Runde 1 ist `INVALID` — Selbsttest-Fall.
7. `factory-board.py`: `scopeOpen` hält einen fertigen Job auf `--open`, bis jeder Eintrag
   `reviewedBy` trägt; ein `deviceOpen`, der keine Liste von Objekten ist, wird gemeldet statt
   abzustürzen — `--selftest` mit Mutationen.
8. `SKILL.md` sagt dasselbe wie der Workflow: Argumente, Sperrliste von der Basis, `verified`-Datum
   statt `VERIFIED-…`, die genaue Kein-Lauf-Liste, Website erst „done“ auf `main`, „Docs-Satz“ nur
   intern — und zitiert nur Pfade, die existieren (`scripts/doctor.py --section B`).
9. Der Selbsttest endet mit 0, und jede der gezielten Mutationen an den neuen Regeln wird gefangen.

## Out of scope
Ein Pro-Lauf-Token in den Markern (der Harness erlaubt kein `Math.random`), eine Prüfung der Rechts-
und Gesundheitstexte selbst, eine Änderung an `.claude/hooks/` oder `.claude/settings.json`.
