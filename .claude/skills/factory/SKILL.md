---
name: factory
version: 1.0.0
description: |
  Echoel factory — one feature from spec to "approved or escalated" with a bounded review loop:
  the PM writes a spec with Assumptions and Acceptance criteria, builds it, up to four read-only
  lenses review the diff in parallel, at most two rework rounds, then a separate approver either
  approves or escalates to the founder through docs/dev/FOUNDER_INBOX.md. Job state lives on disk
  under scratchpads/factory/<id>/ so it survives context compaction. Use for a multi-file or
  user-facing slice ("/factory <feature>"); skip for a one-line reversible fix.
---

# Factory — Spec → Bau → vier Linsen → höchstens zwei Nacharbeiten → Freigabe oder Founder

**Herkunft (Lernmodus, 2026-10-19).** Ein Instagram-Reel („Claude Code software factory“, Kanal
zazencodes, als Werbung gekennzeichnet) zeigte die Schleife: Spec-Writer → Builder → vier Prüfer
parallel (Security, UX, UI-Design, Code) → „wait for all 4“ → bei Änderungen Builder fortsetzen,
höchstens zwei Runden → Approver → APPROVE (Merge) oder ESCALATE (`decision.md`, Spalte „Needs
human“, Freigabe per `/factory approve <id>`), Zustand als Dateien je Job. Das Reel lag als
Founder-Upload vor (47,2 s); die Endkarten-URL und der Code des Kanals wurden NICHT geöffnet.
Übernommen ist das MUSTER, neu geschrieben für dieses Repo. Verdikt und Messung: die Zeile vom
2026-10-19 in `inspiration.csv` und der Absatz „Factory-Reel“ in `memory/inspiration_intake.md`.

## Was dieses Repo daran anders macht — und warum

| Im Clip | Hier | Grund |
|---|---|---|
| Builder ist ein Subagent | **Der PM (die Hauptsitzung) baut.** Jeder Subagent-Prompt trägt die Nur-Lesen-Klausel. | `.claude/rules/context.md` §5: ein Subagent hat hier schon ungesicherte Arbeit vernichtet. ⚠️ Durchgesetzt wird das durch den PROMPT, nicht durch eine Werkzeugsperre — die Agent-Definitionen unter `.claude/agents/` haben keine `tools:`-Liste. Außerdem gibt es keinen lokalen Compiler — Bauen heißt pushen und Gates lesen, und das bleibt seriell. |
| Approver merged nach `main` | **APPROVE heißt: die Scheibe ist fertig für den Weg, den ihr Baum heute hat.** Die Factory erfindet keinen Merge-Pfad. | Ein zweiter Merge-Weg wäre eine zweite Wahrheit. Welche Gates je Baum zählen, steht in Schritt 6; ob `EchoelStudio/` nach `main` kommt, entscheidet der Founder (F-08b) — das ist nicht geregelt, sondern offen. |
| `needs-human` + `/factory approve` | **ESCALATE schreibt `decision.md` UND eine Zeile in `docs/dev/FOUNDER_INBOX.md`** (Frage · Empfehlung · warum es deine Entscheidung ist), im richtigen Abschnitt (Schritt 6). Antwort im Chat mit der Nummer der Zeile („<Nummer>: ja“). | Eine Frage an den Founder steht genau einmal, mit Datum (Inbox-Regel). |
| Modell je Rolle fest (opus/sonnet) | Die Agenten erben das Sitzungsmodell; der Approver bekommt `effort: 'high'`. | Modell-Overrides nur mit gutem Grund (Workflow-Regel); Qualität kommt hier aus der Messung, nicht aus dem Etikett. |
| UI-Design- und UX-Prüfer getrennt | **Eine UX-Linse** (User-Advocate + CLAIMS + Barrierefreiheit + Uncodixfy) und **eine Domänen-Linse nach Pfad**. | Höchstens vier Prüfer je Lead (`ultracode-teams`); für Echoel ist die teuerste Fehlerklasse die falsche Behauptung, nicht die Pixel. |

## Der Ablauf

1. **Job anlegen.** Nächste Nummer unter `scratchpads/factory/` (`001-kurzer-name`), darin
   `board.json` (`stage: "spec"`) und `spec.md`. Der Ordner liegt unter `scratchpads/`, weil
   neue Top-Level-Ordner Founder-Sache sind.
2. **Spec schreiben** — vier Abschnitte, nicht mehr:
   - **Goal** — ein Satz, was der Nutzer danach kann.
   - **Assumptions** — jede Entscheidung, die du für den Founder triffst („du entscheidest alles“),
     sichtbar und einzeln. Markiere founder-klassige mit `[FOUNDER]` (Scope nach
     `docs/dev/FOUNDER_PRODUCT_LAW.md`, Geld, Recht, Lizenztext, Gesundheitswortlaut, App-Store-Abgabe,
     Nutzerdaten löschen, gesperrte Dateien). Der Approver führt jede `[FOUNDER]`-Annahme als
     Kriterium der Art `founder`; ist sie in der Inbox oder in `memory/decisions.md` nicht
     beantwortet, eskaliert der Workflow — das ist eine Approver-Einstufung, kein Textscan der Spec.
   - **Acceptance criteria** — prüfbar, je Kriterium wie es geprüft wird (Wächter, Befehl,
     Datei:Zeile). Was nur ein Gerät, Ohr oder Auge zeigt, steht hier als `[DEVICE]`: es gilt nie
     als erfüllt und blockiert die Freigabe trotzdem NICHT — es wird eine Bitte in
     `docs/dev/FOUNDER_INBOX.md` §2.
   - **Out of scope** — was diese Scheibe absichtlich nicht tut.
   Bei einer bedeutenden Scope-Frage zuerst `the-council`, dann die Spec.
3. **Bauen** (`stage: "build"`) — eine Ralph-Scheibe, Wächter im selben Commit, die acht Prüfer
   aus `scripts/INDEX.md` Abschnitt A, dann Commit. Den Basis-SHA trägst du beim Anlegen ein,
   den Kopf-SHA NACH dem Bau-Commit (ein Commit kann seinen eigenen SHA nicht tragen; der Eintrag
   fährt mit dem nächsten Commit mit). Der Workflow verlangt einen echten SHA, nie `HEAD` — die
   Linsen laufen parallel, und ein beweglicher Name kann ihnen verschiedene Stände zeigen.
4. **Prüfen** (`stage: "review"`) — der gespeicherte Workflow:
   `Workflow({name: "echoel-factory-review", args: {job, base, head, round, lenses}})`.
   Linsen: immer `code-reviewer`, `security-agent`, `ux` — der Workflow fügt die drei selbst
   hinzu, ein Aufrufer kann sie nicht abwählen. `lenses` nennt höchstens EINE Domänen-Linse
   (`[]` = keine; zwei sind `INVALID`) nach dem, was der Diff anfasst —
   `audio-thread-reviewer` (Render-Pfad, `DSP/`, Engine),
   `bio-safety-reviewer` (Bio, HealthKit, Bio-Texte), `ui-state-reviewer` (SwiftUI-Zustand,
   Modals), `concurrency-reviewer` (Actors, Sendable), `dsp-reviewer` (DSP-Mathematik),
   `e2e-test-agent` (Targets, Entitlements, Plist).
   Der Workflow wartet auf ALLE Linsen. Ein Befund zählt nur mit Datei und Schwere
   blocker/major; ein „CHANGES“ ohne solchen Befund wird als PASS gewertet, ein „PASS“ mit
   Blocker als CHANGES — das Wort folgt dem Beleg. Eine fehlende Antwort ist kein Pass (`RERUN`).
   Ein vorhandenes, aber falsches Argument (`round: "3"`, `head: "HEAD"`, eine Linse wie
   `constructor`) ergibt `INVALID`, nie einen Ersatzwert — ein ersetzter `round` hebelte die
   Nacharbeitsgrenze aus.
5. **Nacharbeit** — `decision: "REWORK"`: der PM behebt jeden offenen Befund (oder widerlegt ihn
   mit Messung in `reviews/round-<n>/rebuttal.md`), committet, ruft mit `round + 1` erneut.
   **Höchstens `MAX_REWORK_ROUNDS` = 2 Nacharbeitsrunden**; bleibt in Runde 3 etwas offen, eskaliert
   der Workflow selbst. Eine dritte Nacharbeit gibt es nicht — wer sie braucht, hat eine
   Spec-Frage, keine Code-Frage.
6. **Freigabe** (`stage: "approve"`) — der Approver hat weder gebaut noch geprüft. Er führt JEDES
   Kriterium mit Art (`code` · `device` · `founder`), erfüllt/offen und Beleg. Der Workflow
   entscheidet daraus, stärkste Regel zuerst — ein ESCALATE wird nie zu REWORK herabgestuft:
   1. Grenze erreicht (Befunde offen in Runde 3) → **ESCALATE**.
   2. Der Approver sagt ESCALATE → **ESCALATE**.
   3. Ein `founder`-Kriterium offen oder eine Frage an den Menschen → **ESCALATE**.
   4. Ein `code`-Kriterium offen → **REWORK** (solange Runden übrig sind), sonst ESCALATE.
   5. Sonst **APPROVE**; `device`-Kriterien kommen als `deviceAsks` mit.
   Eine Freigabe ohne ein einziges geprüftes Kriterium ist keine (`RERUN`).
   - **APPROVE** → `stage: "done"` erst, wenn die Gates SEINES Baums es tragen — die Lesart steht in
     `Tests/CISmoke/CLAUDE.md` §5 und wird hier nicht wiederholt. Kurz: Alt-App (`Sources/`,
     `Tests/`) = `Xcode Compile Check` plus der CI/CD-Schritt `Build for Testing`, und ein neuer
     Wächter erst, wenn `scripts/gh-test-verdict.py` ihn nennt; `EchoelStudio/` = Workflow
     `Echoel Studio`; nur `.claude/**`, `scripts/**`, `scratchpads/**`, `docs/**` = **kein Lauf** —
     dann zählen die `--selftest`s und die Python-Transkription, und das Wort heißt „kein Lauf“, nie
     „grün“. Jede `deviceAsks`-Zeile geht als Bitte in `docs/dev/FOUNDER_INBOX.md` §2.
   - **ESCALATE** → `stage: "needs-human"`, `decision.md` mit **Why · Acceptance criteria (je
     erfüllt/offen) · For the human** (Fragen mit Empfehlung), plus die Inbox-Zeile im richtigen
     Abschnitt: §1 für Entscheidungen und Scope, §2 für Geräte-Bitten, §3 nur für gesperrte
     Dateien. Ihre Nummer kommt als `inbox` in `board.json`. Erst greppen, ob die Frage schon dort
     steht.
7. **Protokoll** — die Workflow-Rückgabe schreibt der PM nach `reviews/round-<n>/<linse>.md`;
   `board.json` führt nur der PM. Überblick: `python3 -I scripts/factory-board.py --open`.

## `board.json`

```json
{"id": "001-kurzer-name", "title": "…", "stage": "spec|build|review|approve|needs-human|done|dropped",
 "round": 1, "base": "<sha>", "head": "<sha>", "lenses": ["code-reviewer", "security-agent", "ux"],
 "inbox": "<Inbox-Nummer>", "history": [{"stage": "spec", "date": "2026-10-19", "note": "…"}]}
```

`id` muss gleich dem Ordnernamen sein; `factory-board.py` meldet eine Abweichung, statt zu raten.

## Wann nicht

Eine Ein-Zeilen-Reparatur, ein reiner Tippfehler, ein Docs-Satz: direkt, ohne Factory
(Council-Regel gegen Trivia). Die Factory kostet bis zu fünf Agentenläufe je Runde — vier Linsen,
der Approver nur in der Runde ohne offene Befunde oder an der Grenze; sie lohnt sich ab mehreren
Dateien, einer sichtbaren Fläche oder einer Behauptung nach außen.

## Was die Factory nicht ersetzt

CI (der einzige Compiler), das Gerät (der einzige Beleg für Klang, Bild, Puls), den Founder
(Scope, Geld, Recht) und `the-council` (Abwägung vor einer schwer umkehrbaren Entscheidung).
Sie ersetzt das, was in dieser Sitzung zu spät kam: die Prüfrunde NACH dem Commit, die eine
falsche Behauptung erst fand, als sie schon in drei Dateien stand.

Wächter: `Tests/CISmoke/TheFactoryReviewersAreReadOnlyTests.swift` — jede `agent(`-Stelle des
Workflows trägt die Nur-Lesen-Klausel, der Wrapper stellt sie wirklich voran, jeder `agentType`
ist ein Roster-Name, und die Rundenzahl hier ist die des Workflows. ⚠️ Er läuft erst mit dem
nächsten Commit, der `Sources/` oder `Tests/` berührt — eine reine `.claude/`-Änderung startet
kein Gate. Wer den Workflow ändert, transkribiert die Ansprüche vor dem Push und fährt
`python3 -I scripts/factory-review-selftest.py` — die Entscheidungslogik unter Node mit
Attrappen-Agenten, ein Fall je Zweig von Schritt 6.
