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
Übernommen ist das MUSTER, neu geschrieben für dieses Repo. Verdikt und Messung: die Zeile
`instagram:zazencodes` in `inspiration.csv` und der Absatz „Factory-Reel“ in
`memory/inspiration_intake.md`.

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
     als erfüllt und blockiert die Freigabe trotzdem NICHT — es wird eine Geräte-Bitte (Schritt 6).
     Nur ein so markiertes Kriterium darf der Approver als `device` führen; alles andere ist `code`,
     und eine Freigabe braucht mindestens ein erfülltes `code`-Kriterium.
   - **Out of scope** — was diese Scheibe absichtlich nicht tut.
   Bei einer bedeutenden Scope-Frage zuerst `the-council`, dann die Spec.
3. **Bauen** (`stage: "build"`) — eine Ralph-Scheibe, Wächter im selben Commit, die acht Prüfer
   aus `scripts/INDEX.md` Abschnitt A, dann Commit. Hat die Spec ein `[DEVICE]`-Kriterium, zuerst
   das WIP-Limit prüfen (`docs/dev/FOUNDER_INBOX.md`, Regel 3: höchstens drei gebaute Scheiben
   warten auf ein Geräte-Urteil). **Eine Scheibe, die `docs/`, `ContentPipeline/` oder
   `fastlane/metadata/` anfasst, wird auf dem LOKALEN Commit geprüft, bevor sie gepusht wird**:
   die Linsen lesen das lokale git, und eine reine `docs/`-Delta geht nach dem Push ohne Gate an
   die Website (Schritt 6). Den Basis-SHA trägst du beim Anlegen ein,
   den Kopf-SHA NACH dem Bau-Commit (ein Commit kann seinen eigenen SHA nicht tragen; der Eintrag
   fährt mit dem nächsten Commit mit). Der Workflow verlangt einen echten SHA, nie `HEAD` — die
   Linsen laufen parallel, und ein beweglicher Name kann ihnen verschiedene Stände zeigen.
4. **Prüfen** (`stage: "review"`) — der gespeicherte Workflow:
   `Workflow({name: "echoel-factory-review", args: {job, base, head, round, since, lenses, paths}})`.
   `base` bleibt in JEDER Runde die Basis des Jobs aus `board.json` — der Approver urteilt immer
   über den ganzen Job, weil nur er jedes Kriterium sieht. Ab Runde 2 ist `since` der Kopf der
   vorigen Runde: er zeigt den Linsen nur, was die Nacharbeit geändert hat. Alle drei sind SHAs;
   `round` ist Pflicht. Laufen mehrere Jobs verschränkt auf einem Branch, begrenzt `paths` (bis
   zu 12 Pfade, steht in `board.json`, jede Runde liest es von dort) den Diff auf diesen Job.
   Er versteckt nichts: jede Linse liest zuerst die UNGEFILTERTE Dateiliste und meldet, was außerhalb
   liegt (`outsideScope` — das bekommt einen eigenen Job), der Approver prüft gesperrte Dateien auf
   der ungefilterten Liste, und ein leerer Diff ist `INVALID`, kein Pass.
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
   Ein falsches oder fehlendes Argument (`round: "3"`, kein `round`, `head: "HEAD"`, `base: "main"`,
   eine Linse wie `constructor`) ergibt `INVALID`, nie einen Ersatzwert — ein ersetzter `round`
   hebelte die Nacharbeitsgrenze aus.
5. **Nacharbeit** — `decision: "REWORK"`: der PM behebt jeden offenen Befund (oder widerlegt ihn
   mit Messung in `reviews/round-<n>/rebuttal.md`), committet, ruft mit `round + 1` und
   `since` = dem `head` der geprüften Runde erneut.
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
   Eine Freigabe ohne ein einziges geprüftes Kriterium ist keine (`RERUN`) — und ebenso eine, deren
   Kriterien alle `device` sind: ohne ein erfülltes `code`-Kriterium hat niemand etwas belegt.
   - **APPROVE** → `stage: "done"` erst, wenn die Gates SEINES Baums es tragen:
     - **Alt-App** (`Sources/`, `Tests/`) = `Xcode Compile Check` plus der CI/CD-Schritt
       `Build for Testing`, ein neuer Wächter erst, wenn `scripts/gh-test-verdict.py` ihn nennt —
       Lesart in `Tests/CISmoke/CLAUDE.md` §5. Fehlt er im `WINDOW`, heißt es „kompiliert, Ausführung
       unbelegt“.
     - **`EchoelStudio/`** = Workflow `Echoel Studio` — Lesart in `EchoelStudio/CLAUDE.md`
       „Verifying“. Das ist ein UNSIGNIERTER Build mit Tests: eine Änderung an Entitlements, App
       Group oder Profil beweist er nicht. Die braucht einen signierten `studio-testflight.yml`-Lauf
       plus eine Geräte-Prüfung, also ein `[DEVICE]`-Kriterium.
     - **Website** (`docs/**`) = kein Gate, aber **eine Veröffentlichung**: `auto-merge-docs.yml`
       nimmt eine reine `docs/`-Delta nach `main`, und der Deploy folgt (`docs/CLAUDE.md` §2). Darum
       prüft Schritt 3 sie VOR dem Push.
     - Nur `.claude/**`, `scratchpads/**`, `memory/**` = **kein Lauf** — dann zählen die
       `--selftest`s und die Python-Transkription, und das Wort heißt „kein Lauf“, nie „grün“.
       ⚠️ `scripts/**` gehört NICHT dazu: `scripts/check-infoplist.sh` steht im Pfadfilter von
       `Xcode Compile Check`.
     **Geräte-Bitten** (`deviceAsks`) gehen nicht einzeln in die Inbox: sie werden in eine FAMILIE
     der nächsten Geräte-Runde in `docs/dev/FOUNDER_INBOX.md` §2 eingefaltet, im Budget von fünf je
     Build (Regeln 1 und 4 dort). Ihre Zeilen kommen als `deviceOpen` in `board.json`; ein Job mit
     offenem `deviceOpen` ist „fertig, gerät-unbestätigt“, und `factory-board.py --open` zeigt ihn,
     bis jede Zeile ein `VERIFIED-JJJJ-MM-TT` trägt.
   - **ESCALATE** → `stage: "needs-human"`, `decision.md` mit **Why · Acceptance criteria (je
     erfüllt/offen) · For the human** (Fragen mit Empfehlung), plus die Inbox-Zeile im richtigen
     Abschnitt: §1 für Entscheidungen und Scope, §2 für Geräte-Bitten, §3 nur für gesperrte
     Dateien. Ihre Nummer kommt als `inbox` in `board.json`. Erst greppen, ob die Frage schon dort
     steht.
7. **Protokoll** — die Workflow-Rückgabe schreibt der PM nach `reviews/round-<n>/<linse>.md`;
   sie trägt `range`, `since` und `paths`, also steht dort, über welchen Diff geurteilt wurde.
   `board.json` führt nur der PM. Überblick: `python3 -I scripts/factory-board.py --open`.

## `board.json`

```json
{"id": "001-kurzer-name", "title": "…", "stage": "spec|build|review|approve|needs-human|done|dropped",
 "round": 1, "base": "<sha>", "head": "<sha>", "since": "<sha der vorigen Runde>",
 "lenses": ["code-reviewer", "security-agent", "ux"], "paths": ["<pfad>"],
 "inbox": "<Inbox-Nummer>", "deviceOpen": [{"ask": "<Kurztext>", "inbox": "<§2-Familie>", "verified": "JJJJ-MM-TT"}],
 "history": [{"stage": "spec", "date": "2026-10-19", "note": "…"}]}
```

`id` muss gleich dem Ordnernamen sein; `factory-board.py` meldet eine Abweichung, statt zu raten.
Ein `deviceOpen`-Eintrag ohne `verified` ist offen; `verified` kommt erst mit dem Datum der
Geräte-Antwort.

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
Attrappen-Agenten, ein Fall je Zweig von Schritt 6, dazu die PROMPTS, die die Attrappen bekommen
(Nur-Lesen-Klausel zuerst, `paths` an jedem Diff-Befehl, der Approver liest ab der Job-Basis, ein
Prüfer-Text kann die Datenmarker nicht schließen). Lädt der Workflow nicht, endet es mit 2, nie mit
„grün“.
