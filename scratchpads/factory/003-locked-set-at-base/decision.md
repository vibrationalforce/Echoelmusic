# Job 003 — ESCALATE nach Runde 3 (2026-10-20)

## Why

Zwei Gründe, jeder für sich genug:

- **Die Nacharbeitsgrenze ist erreicht** (`MAX_REWORK_ROUNDS` = 2), und Runde 3 (`wf_c8778d4d-f9a`,
  Kopf `61d2d1e37`) lässt drei Majors offen. Alle drei hat der PM mit Attrappen-Agenten nachgestellt
  (`scratchpad`-Probe auf den Selbsttest-Harness, fünf Fälle, alle fünf wie von den Linsen gemeldet):
  1. **Zwei Zähl-Rückfragen stehen VOR den Eskalationsregeln** (security, e2e). Weicht die Zählung des PM
     von der des Approvers ab oder benotet er eine Nummer zu viel, ist es `RERUN` — auch wenn die
     Grenze erreicht ist, die Sperr-Konfiguration geändert wurde oder der Approver selbst eskaliert.
     Gemessen: Runde 3 mit offenem Major und Zählabweichung → `RERUN` statt ESCALATE; eine Änderung an
     `.claude/settings.json` mit Zählabweichung → `RERUN`; ein eskalierender Approver mit einer Nummer zu
     viel → `RERUN`, seine Founder-Frage nur noch im zurückgegebenen Objekt. Weil ein `RERUN` dieselbe
     Runde neu ruft und nichts den Kopf festhält, wäre das ein Weg zu einer dritten Nacharbeit.
  2. **Ein `founder`-Etikett zählt als Code-Beleg** (code). Ein nummeriertes Kriterium, das der Approver
     `founder` nennt und als erfüllt meldet, zählt seit Runde 2 als erfülltes `code`-Kriterium, ohne
     datierten Beleg. An der Basis landete dieselbe Antwort im Boden „kein Code-Kriterium belegt“
     (`RERUN`); am Kopf ist sie APPROVE.
- **Der Job ändert den Prüfer** (`.claude/workflows/echoel-factory-review.js`), und ein Prüfer, den der
  Job geschrieben hat, kann ihn nicht freigeben (Regel 6, aus Runde 1 dieses Jobs). Auch ohne die Grenze
  wäre er hier geendet — so steht es seit Runde 1 in der Spec.

Der Approver hat die Spec selbst gezählt (10 Kriterien, kein `[DEVICE]`, keine `[FOUNDER]`-Annahme —
gleich den Zahlen des PM), `board.json` am Kopf führt die Basis `f61d7872d`, die Sperrliste an der Basis
gelesen, keine gesperrte Datei im Diff. Regel für Regel gegen die Basis: fast alles ist strenger
(Sperrliste von der Basis, feste Eskalation der Sperr-Konfiguration samt Umbenennung und
`settings.local.json`, Prüfer-Regel, gezählte Abnahme, `device` nur mit beiden Lesungen, datierte
Founder-Belege, ASCII-Datenblock); gelockert sind genau die zwei Punkte oben, entfernt ist der alte
`filesInScope 0`-INVALID zugunsten der eigenen Scope-Rechnung, deren Lücke (`""` passiert den Leer-Test)
ein Minor ist.

## Acceptance criteria

| # | Kriterium | Stand |
|---|---|---|
| 1 | Sperrliste mit `git show <base>:`, `board.json`-Basis geprüft | erfüllt — Approver-Prompt, Selbsttest, Wächter-Anspruch 7 |
| 2 | Sperr-Konfiguration eskaliert fest, auch umbenannt | erfüllt — aber Befund 1 oben: eine Zählabweichung schiebt sich davor |
| 3 | Scope aus `changedFiles`, INVALID/RERUN-Fälle | erfüllt — Minor: `""` passiert den Leer-Test |
| 4 | Gezählte Abnahme, Art aus beiden Lesungen, datierte Founder-Belege | erfüllt nach Wortlaut — aber Befund 2 oben: ein erfülltes `founder`-Etikett zählt als Code |
| 5 | ASCII-Datenblock | erfüllt |
| 6 | `since` in Runde 1 und `.`/`//` in `paths` INVALID | erfüllt |
| 7 | Board: `scopeOpen`, `reviewedBy` streng, kaputte Listen gemeldet | erfüllt — 20 kaputte Boards, `--mutate` 16/16 |
| 8 | SKILL.md sagt dasselbe wie der Workflow | erfüllt — Minors: Kosten-Satz, `deviceCriteria`-Lesart, Vorlage `reviewedBy` |
| 9 | Selbsttests 0, `--mutate` fängt jede Zeile | erfüllt — 101 Fälle, 76/76; Board 16/16 |
| 10 | Eine Änderung am Prüfer endet nie in APPROVE | erfüllt — und genau diese Regel eskaliert den Job |

Gates auf `61d2d1e37` (der Commit berührt den Wächter, also läuft CI auf genau diesem Baum):
`Xcode Compile Check` grün (Lauf 39348756755), CI/CD-Schritt `Build for Testing` grün (Lauf 39348756773 —
der Wächter kompiliert), `Run Tests` lief beim Schreiben noch: ob die Ansprüche 1–9 AUSGEFÜHRT grün sind,
sagt erst `scripts/gh-test-verdict.py` auf dem Job-Log. Bis dahin: kompiliert, transkribiert grün,
Ausführung unbelegt. Nichts gerätegeprüft; der Job berührt keine App.

## For the human

**GM27 in `docs/dev/FOUNDER_INBOX.md` §1, erweitert** — eine Frage für Job 001 und Job 003 zusammen:
beide so annehmen und die offenen Befunde als **Job 004** bauen? Empfehlung: **ja**. Beide machen die
Prüfung strenger als an ihrer Basis, sind reines Werkzeug (keine App, kein Store, kein Merge — APPROVE
merged nie) und umkehrbar. Job 004 nimmt die drei Majors (Eskalation vor Zählung, `founder`-Etikett
nie als Code-Beleg) und die Minors der Runde 3 (`""`-Reihenfolge, C1- und Bidi-Steuerzeichen,
`fastlane/Deliverfile`, Spec am Kopf-SHA lesen, die PM-Zahlen nicht vor der Zählung zeigen, ein
Ausweg bei wiederholter Zählabweichung, die SKILL-Sätze). Er wird — erstmals — mit der Fassung des
Prüfers von seiner eigenen Basis geprüft (SKILL.md Schritt 4), also nicht von sich selbst, und endet
über dieselbe Prüfer-Regel wieder bei dir. Unter deiner Delegation ist Job 004 sofort begonnen; ein Nein
zu GM27 nimmt 003 und 004 zurück.

Die vier Einzelfragen des Approvers (Protokoll `reviews/round-3/approver.md`) sind in diese eine
gefaltet: drei davon fragen „in Job 004 reparieren?“, die vierte „annehmen?“.
