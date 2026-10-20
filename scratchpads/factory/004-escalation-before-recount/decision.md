# Job 004 — ESCALATE nach Runde 3 (2026-10-20)

## Why

Zwei Gründe, jeder für sich genug, und so in der Spec von Anfang an vorgesehen:

- **Die Nacharbeitsgrenze ist erreicht** (`MAX_REWORK_ROUNDS` = 2), und Runde 3 (`wf_c2619890-b9f`, Kopf
  `d5682ae4d`, geprüft mit der Prüfer-Fassung der Basis `73e9ae52d`) lässt EINEN Sachverhalt offen, den zwei
  Linsen als Major melden (security, ux) und der Approver selbst nachgestellt hat: **der Leer-Test
  `.filter(f => f.trim())` wirft einen Namen weg, der NUR aus Zeichen besteht, die `trim()` entfernt** — ein
  Leerzeichen, NBSP, BOM, U+2028, U+3000. Vom PM nachgemessen: `Boolean(c.trim())` ist für alle fünf `false`,
  für U+200B `true`; ein Wegwerf-Repo mit den Dateien ` ` und NBSP druckt `git show --name-only` beide roh. So
  eine Datei an der Wurzel fiele aus jeder Liste, bevor `hidden()` sie prüft, und eine Abnahme deckte eine
  Datei, die sie nie gezählt hat. Das ist der Grenzfall des Majors aus Runde 2 (`trim()` verbarg Rand-Zeichen):
  Nacharbeit 2 nahm `trim()` aus dem `map`, ließ es aber im Leer-Test stehen.
- **Der Job ändert den Prüfer** (`.claude/workflows/echoel-factory-review.js`) und kann nie in APPROVE enden.

Der Approver hat die Spec ZUERST selbst gezählt (10 Kriterien, kein `[DEVICE]`, eine `[FOUNDER]`-Annahme —
gleich den Zahlen des PM), `board.json` am Kopf führt die Basis `73e9ae52d`, die Sperrliste an der Basis
gelesen, keine gesperrte Datei im Diff. Regel für Regel gegen die Basis: fast alles ist strenger (feste
Eskalation vor jeder Rückfrage, `founder`-Etikett nur mit datiertem Beleg, SENSITIVE breiter, versteckte
Namen eskalieren). Gelockert ist EIN pathologischer Fall: wenn an der Grenze JEDE Linse JEDEN Namen mit einem
C0-Zeichen verfälscht, endet der Kopf in einem Scope-INVALID statt in der Grenz-Eskalation der Basis. Ein
INVALID gibt nichts frei; verloren ist nur der Hinweis an den Founder.

## Acceptance criteria

| # | Kriterium | Stand |
|---|---|---|
| 1 | Grenze/Sperre → ESCALATE vor jeder Abweichung, jeder Teil im Grund, frühe Eskalation trägt alles mit | erfüllt |
| 2 | Approver-ESCALATE oder Founder-Frage vor jeder Zähl-Rückfrage | erfüllt |
| 3 | `founder`-Etikett nie Code-Beleg | erfüllt |
| 4 | Prompt ohne PM-Zahl, Zählung ZUERST, Diff ohne `board.json`/`reviews/`, Spec am Kopf | erfüllt |
| 5 | `recount` | erfüllt |
| 6 | Dateinamen: entquoten, leer prüfen, nichts abschneiden | **offen** — der Leer-Test schneidet doch ab (Major oben) |
| 7 | SENSITIVE + Token-Notiz | erfüllt |
| 8 | SKILL.md sagt dasselbe wie der Workflow | **offen** — drei Sätze (Minors unten) |
| 9 | Selbsttests 0, `--mutate` fängt jede Zeile | erfüllt — 116/116 |
| 10 | Wächter-Anspruch 10 | erfüllt — transkribiert, Basis rot, Kopf grün |

Minors der Runde 3 (Protokolle unter `reviews/round-3/`):
- Ein Namens-`RERUN` weicht der Grenze und der Sperre, aber nicht einem `disguised`-Namen (code, ux, e2e) —
  der Kommentar „no file name can hold a fixed escalation in a RERUN loop“ und SKILL.md:137 sind dafür falsch.
- `isLockConfig` und SENSITIVE vergleichen mit Groß-/Kleinschreibung (security, schon an der Basis so): auf
  einem Dateisystem ohne Unterscheidung (APFS-Standard auf dem Mac) ist `.claude/Hooks/…` derselbe Ordner wie
  `.claude/hooks/`. Unter Linux nicht messbar, die Abhilfe macht die Prüfung nur strenger.
- Ein Token-Dateiname, den nur eine Linse auffüllt, verliert an der Grenze die „rotate it“-Notiz (security).
- An der Grenze bleiben verfälschte C0-Namen in `changed` und lösen den Scope-INVALID aus (code, Approver).
- Die Selbsttest-Nadel für den Linsen-Diff verlor ihr Ende (code): eine Mutation, die den Linsen den
  Approver-Diff gibt, überlebt.
- Drei Sätze: SKILL.md:135 „immer `RERUN`“, SKILL.md:339 und INDEX/Docstring/Workflow-Kommentar „blind“ (ux, e2e).

Gates auf `dcae95345`: `Xcode Compile Check` grün, `Build for Testing` grün, `Run Tests` Exit 65 (#396-Form),
160 Tests im Fenster grün, 0 Fehler; der Factory-Wächter liegt NICHT im Fenster (1910 s Lücke). Also:
kompiliert, transkribiert grün, Ausführung unbelegt. Die Läufe auf `aeb77953d` und `d5682ae4d` liefen beim
Schreiben noch. Nichts gerätegeprüft; der Job berührt keine App.

## For the human

**GM27 in `docs/dev/FOUNDER_INBOX.md` §1, erweitert** — weiter EINE Frage, jetzt für die Jobs 001, 003 und
004: so annehmen und die offenen Befunde als **Job 005** bauen? Empfehlung: **ja** (der Approver empfiehlt
dasselbe). Alle drei machen die Prüfung strenger als an ihrer Basis, sind reines Werkzeug (keine App, kein
Store; APPROVE merged nie) und umkehrbar. Job 005 nimmt den Leer-Test (`f !== ''`), das Ausweichen vor
`disguised`, den Vergleich ohne Groß-/Kleinschreibung für Sperre, Prüfer und SENSITIVE, den C0-Scope-Fall,
die Selbsttest-Nadel und die drei Sätze. Er wird mit der Prüfer-Fassung von SEINER Basis (= Kopf dieses Jobs)
geprüft und endet über dieselbe Prüfer-Regel wieder bei dir. Unter deiner Delegation ist Job 005 sofort
begonnen; ein Nein zu GM27 nimmt 003, 004 und 005 zurück.

Die vier Einzelfragen des Approvers (`reviews/round-3/approver.md`) sind in diese eine gefaltet: die erste IST
GM27, die zweite und dritte fragen „in Job 005 reparieren?“, die vierte (der schmalere Approver-Diff) ist der
Zweck von Kriterium 4 und mit dem Ja angenommen.
