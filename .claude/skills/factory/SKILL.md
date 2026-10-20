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
     sichtbar und einzeln. Markiere founder-klassige mit `[FOUNDER]` am ANFANG des Spiegelstrichs (Scope nach
     `docs/dev/FOUNDER_PRODUCT_LAW.md`, Geld, Recht, Lizenztext, Gesundheitswortlaut, App-Store-Abgabe,
     Nutzerdaten löschen, gesperrte Dateien). Der Approver führt jede `[FOUNDER]`-Annahme als
     Eintrag mit Nummer 0 und Art `founder`; der PM übergibt ihre Zahl als `founderAssumptions`
     (Pflicht, `0` wenn keine), der Approver zählt sie in der Spec selbst nach, und fehlt ein Eintrag,
     ist es `RERUN`. Erfüllt ist er nur mit einem DATIERTEN Beleg — Datei, Zeile oder
     Eintrag, Datum der Antwort (`docs/dev/FOUNDER_INBOX.md` oder `memory/decisions.md`); eine offene
     Zeile ist keine Antwort, und dann eskaliert der Workflow. Ein NUMMERIERTES Kriterium ist nie
     `founder`: braucht es den Founder, gehört es als `[FOUNDER]`-Annahme in die Spec. Etikettiert der
     Approver ein nummeriertes Kriterium trotzdem `founder`, ist es nie ein Code-Beleg: erfüllt nur mit
     demselben datierten Beleg, sonst eskaliert der Workflow — er arbeitet es nie als Nacharbeit ab, und
     eine Eskalation gibt nie frei (Job 003, Runde 3: als `code` gezählt, gab es ohne Beleg frei).
   - **Acceptance criteria** — NUMMERIERT (`1.`, `2.` …), prüfbar, je Kriterium wie es geprüft
     wird (Wächter, Befehl, Datei:Zeile). Was nur ein Gerät, Ohr oder Auge zeigt, steht hier als
     `[DEVICE]` am ANFANG seines Textes (ein Etikett mitten im Satz ist keins): es gilt nie als erfüllt und blockiert die Freigabe trotzdem NICHT — es wird eine
     Geräte-Bitte (Schritt 6). Welche Nummern `[DEVICE]` sind, sagt die SPEC — und zwar nur, wenn
     ZWEI Lesungen übereinstimmen: der PM übergibt sie als `deviceCriteria`, der Approver zählt sie
     selbst nach (`specDevice`) und etikettiert den Eintrag `device`. Fehlt eine der beiden, zählt das
     Kriterium als `code`; widersprechen sich die Zählungen, ist es `RERUN` (Job 003, Runde 2: eine
     veraltete Liste nach eingefügtem Kriterium hätte ein offenes `code`-Kriterium entschuldigt). Eine Freigabe braucht mindestens ein erfülltes `code`-Kriterium. Ein
     Kriterium, das sagt „kein Gerät nötig“, trägt KEIN `[DEVICE]` — sonst ist es eine Geräte-Bitte
     ohne Inhalt (Job 001, Kriterium 8).
   - **Out of scope** — was diese Scheibe absichtlich nicht tut.
   Bei einer bedeutenden Scope-Frage zuerst `the-council`, dann die Spec.
3. **Bauen** (`stage: "build"`) — eine Ralph-Scheibe, Wächter im selben Commit, die acht Prüfer
   aus `scripts/INDEX.md` Abschnitt A, dann Commit. Hat die Spec ein `[DEVICE]`-Kriterium, zuerst
   das WIP-Limit prüfen (`docs/dev/FOUNDER_INBOX.md`, Regel 3: höchstens drei gebaute Scheiben
   warten auf ein Geräte-Urteil). **Eine Scheibe, die `docs/`, `ContentPipeline/` oder
   `fastlane/metadata/` anfasst, wird auf dem LOKALEN Commit geprüft, bevor sie gepusht wird**:
   die Linsen lesen das lokale git, und eine reine `docs/`-Delta geht nach dem Push ohne Gate an
   die Website (Schritt 6). **Vor JEDEM Push** muss
   `git log --full-history --oneline origin/<branch>..HEAD -- .claude/settings.local.json` leer sein (für
   einen neuen Branch `origin/main..HEAD`): die Datei hält ein Token, und ein Commit, der sie auch nur kurz
   trug, veröffentlicht es mit dem Push — und der Workflow sieht nur die Netto-Änderung des Bereichs, also nie
   einen Commit, der die Datei anlegt und später wieder löscht. Diese Prüfung ist dafür die einzige. `--full-history` ist Pflicht:
   ohne es übergeht `git log` einen gemergten Seitenast, der die Datei anlegt und wieder löscht, und der
   Push trägt das Token trotzdem (Job 004, Runde 1, nachgemessen). Den Basis-SHA trägst du beim Anlegen ein,
   den Kopf-SHA NACH dem Bau-Commit (ein Commit kann seinen eigenen SHA nicht tragen; der Eintrag
   fährt mit dem nächsten Commit mit). Der Workflow verlangt einen echten SHA, nie `HEAD` — die
   Linsen laufen parallel, und ein beweglicher Name kann ihnen verschiedene Stände zeigen.
4. **Prüfen** (`stage: "review"`) — der gespeicherte Workflow:
   `Workflow({name: "echoel-factory-review", args: {job, base, head, round, since, criteria, deviceCriteria, founderAssumptions, recount, lenses, paths}})`.
   `criteria` (Pflicht) ist die Zahl der Abnahmekriterien der Spec, `deviceCriteria` die Liste
   ihrer `[DEVICE]`-Nummern (`[]` = keine; fehlt sie, gilt `[]` — trägt die Spec dann doch ein
   `[DEVICE]`-Kriterium, widerspricht die Zählung des Approvers, und es ist `RERUN`; mit `recount: true`
   oder neben einer festen Eskalation ESCALATE, Schritt 6),
   `founderAssumptions` (Pflicht, `0` wenn keine) die Zahl ihrer `[FOUNDER]`-Annahmen — damit ZÄHLT der
   Workflow, ob der Approver jede Nummer genau einmal und jede `[FOUNDER]`-Annahme benotet hat, statt
   es zu glauben (Job 001, Runde 3: ein Eintrag gegen acht Kriterien wurde freigegeben). Auch die drei
   Zahlen glaubt er dem PM nicht allein: der Approver zählt die Spec selbst (`specCriteria`,
   `specDevice`, `specFounder`) — ZUERST, aus der Spec allein, bevor er `board.json`, `reviews/` oder die
   Linsen-Berichte liest; sein Prompt nennt keine Zahl des PM, und sein Diff lässt `board.json` und `reviews/`
   aus, die sie tragen. Ganz blind ist das nicht — eine Linse kann die Zahlen zitieren, und `board.json` liest er
   für die `base` doch (Job 004, Runde 2) —, darum heißt es zweite Lesung, nicht unabhängige Messung. Linsen
   und Approver lesen die Spec am Kopf-SHA (`git show <head>:<job>/spec.md`), nie aus dem Arbeitsbaum. Weicht eine
   Zählung ab, ist es `RERUN` — der PM zählt die Spec neu und ruft DIESELBE Runde mit DEMSELBEN `head`
   noch einmal, jetzt mit `recount: true` (ein Boolean; alles andere ist `INVALID`). Weicht die Zählung
   dann noch ab, eskaliert der Workflow: welche Zählung stimmt, entscheidet der Founder. Ein `RERUN`
   ist nie eine neue Runde und nie ein neuer Kopf — hat sich der Kopf geändert, ist es Nacharbeit
   (Schritt 5). Nach einem ESCALATE ruft der PM denselben Job NICHT erneut; die Antwort steht in der
   Inbox.
   **Ändert der Job den Prüfer selbst** — `.claude/workflows/echoel-factory-review.js` oder etwas
   unter `.claude/agents/` (die Linsen-Definitionen) —, läuft die Prüfung sonst mit der Fassung, die der
   Job geschrieben hat (der Harness lädt beide aus dem Arbeitsbaum). Dann holt der PM die Fassung von
   der Job-Basis in den Scratchpad (`git show <base>:.claude/workflows/echoel-factory-review.js`) und
   startet sie mit `Workflow({scriptPath: …, args})` — mit den Argumenten, die DIESE Fassung verlangt
   (die Fassung von Job 003 kennt `recount` nicht und liest die Spec aus dem Arbeitsbaum).
   Das gilt ab Job 004: erst die Fassung von Job 003 kennt die Regel unten (Schritt 6, Regel 6), die
   eine solche Prüfung nie mit APPROVE enden lässt. Job 003 selbst wird mit seiner eigenen Fassung
   geprüft und eskaliert über genau diese Regel.
   **Was der Prüfer-Satz NICHT umfasst:** jede `CLAUDE.md` und alles unter `.claude/rules/` erreichen
   jede Linse und den Approver als Projekt-Anweisung, und zwar aus dem Baum unter Prüfung. Sie stehen
   nicht im Prüfer-Satz, weil fast jeder Job sie anfasst. Stattdessen lesen Linsen und Approver sie bei
   einer Änderung auch an der Basis; eine neue oder gelockerte Regel über Prüfen, Benoten oder Freigeben
   ist für die Linse ein Major und für den Approver eine Founder-Frage. Die Lücke bleibt benannt: eine
   solche Regel, die alle übersehen, wirkt schon in der Runde, die sie prüft.
   `base` bleibt in JEDER Runde die Basis des Jobs aus `board.json` — der Approver urteilt immer
   über den ganzen Job, weil nur er jedes Kriterium sieht. Ab Runde 2 ist `since` der Kopf der
   vorigen Runde: er zeigt den Linsen nur, was die Nacharbeit geändert hat. Alle drei sind SHAs;
   `round` ist Pflicht. Laufen mehrere Jobs verschränkt auf einem Branch, begrenzt `paths` (bis
   zu 12 Pfade, steht in `board.json`, jede Runde liest es von dort) den Diff auf diesen Job.
   Er versteckt nichts: jede Linse meldet die UNGEFILTERTE Dateiliste (`changedFiles`, aus
   `git -c core.quotePath=false diff --name-only --no-renames`: mit `--no-renames` erscheint eine
   verschobene Datei mit altem UND neuem Pfad — sonst verschwände ein weggeschobener Hook aus der
   Sperrprüfung —, und ohne Oktal-Escapes passt ein Name mit Umlaut noch auf sein Präfix; ein Paar
   umschließender Anführungszeichen streicht der Workflow selbst, und nur ein danach LEERER Eintrag fällt
   weg — ein Name nur aus Leerraum, BOM oder NBSP ist nicht leer, `trim()` würde ihn leeren).
   Git druckt jedes Zeichen ab U+0080 ROH, also auch C1-, unsichtbare, Bidi-, Trenn- und Nicht-ASCII-
   Leerzeichen, und füllt keinen Namen auf — ein Name damit oder mit Leerraum am Rand kann eine echte
   Datei sein, gebaut, um wie eine andere auszusehen. Darum wird außer einem Paar Anführungszeichen nichts
   abgeschnitten (`trim()` striche U+FEFF, U+2028, U+2029 und jedes Zs-Leerzeichen am Rand weg). Melden ihn
   ALLE Linsen, eskaliert er fest (Schritt 6, Regel 2); meldet ihn nicht jede, ist es `RERUN` mit den
   Namen derer, die ihn meldeten, und der Approver läuft nicht. Ein C0-Steuerzeichen oder DEL druckt Git
   nie roh: so ein Name ist `RERUN` mit dem Namen der Linse und macht den Aufruf nie `INVALID`. Ist die
   Grenze erreicht, zeigt irgendeine Liste eine Sperr-Änderung oder meldet jede Linse einen versteckten
   Namen — jedes davon eine feste Eskalation —, wird jedes solche `RERUN` ein Vermerk im Grund
   (`name check:`): kein Dateiname hält eine feste Eskalation in einer Schleife. Eine Linse ganz ohne Liste oder mit leerer
   Liste ruft weiterhin zuerst neu: das ist die Linse, nicht der Inhalt des Repos. Und der
   Workflow rechnet daraus SELBST, was im Scope liegt (Git-Pfadregel: ein Pfad deckt sich selbst und
   alles darunter, ein Präfix nur an einem `/`) und was außerhalb (`outsideScope` — das bekommt
   einen eigenen Job; die sensiblen davon kommen als `sensitiveOutside` zurück). Melden alle Linsen
   eine leere Liste oder liegt keine Datei unter `paths`, ist es `INVALID`; meldet eine Linse leer,
   während andere Dateien sehen, oder antwortet sie ganz ohne Liste, ist es `RERUN` mit ihrem Namen —
   sie hat sich verzählt, nicht der Aufruf. `since` gibt es erst ab Runde 2; in Runde 1 ist es
   `INVALID`. Ein Pfad in `paths` hat kein `.`-Segment (`.`, `./x`) und kein `//`.
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
   2. Der Diff ändert die Konfiguration, die die Sperre DEFINIERT — `.claude/settings.json`,
      `.claude/settings.local.json` (gitignoriert, mit `git add -f` aber trackbar, und Claude Code
      wertet sie VOR `settings.json`), `.mcp.json` oder etwas unter `.claude/hooks/`, auch außerhalb
      von `paths` und in jeder Schreibweise, die auf einem APFS- oder HFS+-Volume diese Datei ist
      (verglichen wird der gefaltete Name: versteckte Zeichen und Rand-Leerraum entfernt, NFKC,
      Kleinbuchstaben — `.claude/Hooks/` ist dort `.claude/hooks/`; NTFS-Aliasse wie ein Punkt am Ende
      und die volle Fallfaltung ß→ss deckt das nicht ab, weil Founder-Rechner Apple sind und Sitzungen
      unter Linux laufen; ein nur gefaltet passender Name heißt im Grund „a name that folds to it“)
      → **ESCALATE**, ohne
      Ermessen des Approvers und vor jeder Nacharbeit. Ein Job wird nie an der Sperre gemessen, die
      er selbst geändert hat. Bei `.claude/settings.local.json` sagt der Grund zusätzlich, dass das
      Token zu tauschen und der Commit aus der Geschichte zu entfernen ist; bei einem Namen, der nur
      GEFALTET diese Datei ist, sagt er „kann ihr Token tragen“, nie „trägt“. Ebenso fest eskaliert ein
      Dateiname, den JEDE Linse mit einem versteckten Zeichen meldet (Schritt 4); der Grund zeigt jeden
      Namen escaped (`\uXXXX`). Treffen Grenze, Sperre und ein solcher Name zusammen, nennt der Grund
      jeden Teil — die Token-Notiz geht an der Grenze nicht verloren (Job 004, Runde 1).
   3. Der Approver sagt ESCALATE → **ESCALATE**.
   4. Ein `founder`-Eintrag offen, ein nummeriertes Kriterium mit dem Etikett `founder` ohne datierten
      Beleg oder eine Frage an den Menschen → **ESCALATE**.
   5. Ein `code`-Kriterium offen → **REWORK** (solange Runden übrig sind), sonst ESCALATE.
   6. Alles erfüllt, aber der Diff ändert den PRÜFER (`.claude/workflows/echoel-factory-review.js`,
      `.claude/agents/`, gefaltet verglichen wie die Sperre) → **ESCALATE** statt APPROVE: ein Prüfer, den der Job geschrieben hat, kann
      ihn nicht freigeben. Anders als Regel 2 überspringt das die Nacharbeit NICHT — der Founder soll
      eine fertige Fassung beurteilen.
   7. Sonst **APPROVE**; `device`-Kriterien kommen als `deviceAsks` mit, sensible Dateien außerhalb
      des Scopes als `not covered` im Grund.
   Vorher vergleicht der Workflow die drei Zahlen des PM mit der Zählung des Approvers und zählt
   dann: fehlt eine Nummer 1..`criteria`, steht eine doppelt oder eine darüber, oder sind es weniger
   Nummer-0-Einträge als `founderAssumptions`, oder fehlt der Approver ganz, ist das ein Vermerk.
   **Die Reihenfolge entscheidet:** was die Runde aus EIGENER Messung weiß — die Grenze (Regel 1) und
   eine Änderung an der Sperr-Konfiguration (Regel 2) — und ein ESCALATE oder eine Frage des Approvers an
   den Menschen (Regel 3 und die Frage aus Regel 4) eskalieren VOR jeder Zähl-Rückfrage; der Vermerk steht
   dann im Grund. Ein offener `founder`-Eintrag neben einem Zähl-Vermerk bleibt `RERUN`: die Benotung, aus
   der er stammt, ist selbst ungezählt.
   Nur ohne sie ist ein Vermerk `RERUN`; eine Zählabweichung mit `recount: true` ist ESCALATE, jeder andere
   Vermerk bleibt auch dann `RERUN`. Grund (Job 003, Runde 3): ein
   `RERUN` ruft dieselbe Runde noch einmal, und nichts hält den Kopf über diesen Aufruf still — eine
   Zähl-Rückfrage vor der Grenze hätte die Grenze umgehbar gemacht. Die Art braucht
   beide Lesungen: Nummer 0 ist `founder`; eine Nummer ist `device` nur, wenn sie in `deviceCriteria`
   steht UND der Approver sie `device` nennt; nennt er sie `founder`, ist sie ein Founder-Punkt (Regel 4);
   alles andere ist `code`. Ein `founder`-Eintrag gilt nur als erfüllt, wenn sein Beleg
   `docs/dev/FOUNDER_INBOX.md` oder `memory/decisions.md` UND ein Datum (`JJJJ-MM-TT`) nennt. Der
   Approver prüft außerdem, dass `board.json` am Kopf dieselbe `base` führt, mit der er gerufen
   wurde — sonst eskaliert er, weil der geprüfte Bereich nicht der ganze Job wäre.
   **Welche Dateien gesperrt sind, liest der Approver an der JOB-BASIS** (`git show <base>:` von
   `.claude/rules/context.md` §3, `.claude/hooks/protect-founder-gated.py` und
   `.claude/settings.json`), nie aus dem Baum unter Prüfung — sonst könnte ein Job die Liste
   ändern, an der er gemessen wird. Ändert sich §3 von `context.md`, vergleicht er Basis und Kopf.
   Eine Freigabe ohne ein einziges geprüftes Kriterium ist keine (`RERUN`) — und ebenso eine, deren
   Kriterien alle `device` sind: ohne ein erfülltes `code`-Kriterium hat niemand etwas belegt.
   - **APPROVE** → `stage: "done"` erst, wenn die Gates SEINES Baums es tragen. **Welcher Lauf
     zählt:** je Gate der neueste Lauf auf einem Commit S, der der `head` des Jobs ist oder ein
     Vorfahre im Job, und nach dem sich kein Pfad aus DIESEM Gate mehr geändert hat —
     `git diff --name-only S..<head> -- <die Pfadfilter des Gates>` ist leer (`scripts/gh-run-status.py`,
     Spalte `sha7`). Die Gates sind pfadgefiltert: eine Nacharbeit, die nur `.claude/**` oder
     `scratchpads/**` anfasst, startet keinen Lauf, und der Lauf davor bleibt für die GATES der gültige.
     Ein Lauf vor einer späteren Änderung an gefilterten Pfaden zählt nicht mehr.
     ⚠️ **Für einen Wächter reicht das nicht**: `Tests/CISmoke` sind Quelltext-Scans und lesen Dateien
     außerhalb jedes Pfadfilters (`.claude/**`, `docs/**`, `CLAUDE.md` …). Für einen Wächter, den der Job
     anlegt oder ändert, zählt ein früherer Lauf deshalb nur, wenn AUCH
     `git diff --name-only S..<head> -- <jede Datei, die dieser Wächter liest>` leer ist (welche Dateien das
     sind, sagen seine Lese-Aufrufe — JEDE API, die eine Datei liest oder nach ihr fragt: `text(…)`,
     `String(contentsOf:)`, `Data(contentsOf:)`, `FileManager.default.fileExists`; gefunden mit
     `grep -n 'contentsOf\|fileExists\|text(' <Wächter-Datei>`. In `TheFactoryReviewersAreReadOnlyTests`
     sind das die `text(…)`-Stellen, das `Data(contentsOf:)` auf `.claude/settings.json` (Anspruch 8) und
     die `fileExists`-Prüfung der Inbox). Sonst heißt der Wächter am Kopf „transkribiert, kein Lauf“, nie grün —
     oder ein weiterer Commit berührt die Wächter-Datei und startet den Lauf auf dem letzten Baum
     (Job 003, Runde 2: ein Lauf auf dem Kopf der ersten Nacharbeit hätte sonst einen Workflow-Text
     bestätigt, den die zweite schon geändert hatte):
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
       prüft Schritt 3 sie VOR dem Push. „done“ heißt hier: die Seite STEHT auf `main`. ⚠️ Liegt in
       derselben Delta gegen `main` auch nur eine Nicht-`docs/`-Datei — der Job-Ordner unter
       `scratchpads/factory/` reicht —, setzt der Workflow `docs_only=false`, überspringt den
       Cherry-Pick und endet trotzdem grün; dann nimmt die Seite erst der nächste Code-Merge mit.
     - **Kein Lauf** = der GANZE Job (`git diff --name-only <base>..<head>`, nicht nur der letzte
       Commit) berührt keinen Pfad aus den Filtern der Gates (`Xcode Compile
       Check`: `Sources/**`, `Tests/**`, `project.yml`, `Package.swift`, `Package.resolved`,
       `Resources/iOS/Info.plist`, `scripts/check-infoplist.sh` · CI/CD: `Sources/**`, `Tests/**`,
       `Package.swift`, `project.yml` · `Echoel Studio`: `EchoelStudio/**`; jedes zusätzlich seine
       eigene Workflow-Datei). Typisch: `.claude/**`, `scratchpads/**`, `memory/**`, die `*.csv` im
       Wurzelordner und `scripts/**` außer `check-infoplist.sh`. Dann zählen die `--selftest`s, ihre
       `--mutate`-Läufe und die Python-Transkription, und das Wort heißt „kein Lauf“, nie „grün“.
       Berührt der Job gefilterte Pfade, ist „kein Lauf“ nie die Antwort, auch wenn der letzte Commit
       keinen auslöst — dann gilt die Regel „Welcher Lauf zählt“ oben.
     **Geräte-Bitten** (`deviceAsks`) gehen nicht einzeln in die Inbox: sie werden in eine FAMILIE
     der nächsten Geräte-Runde in `docs/dev/FOUNDER_INBOX.md` §2 eingefaltet, im Budget von fünf je
     Build (Regeln 1 und 4 dort). Ihre Zeilen kommen als `deviceOpen` in `board.json`; ein Job mit
     offenem `deviceOpen` ist „fertig, gerät-unbestätigt“, und `factory-board.py --open` zeigt ihn,
     bis jeder Eintrag ein Feld `verified` mit dem Datum (`JJJJ-MM-TT`) trägt — gesetzt am selben
     Tag, an dem die Inbox-Zeile ihr `[x]` bekommt, nie vorher.
     **Sensible Dateien außerhalb des Scopes** (`sensitiveOutside`: Rechtstext und Lizenzhinweise,
     Datenschutz samt Weiterleitungen und `docs/_headers`, Gesundheit, Barrierefreiheit,
     Entitlements, Privacy-Manifeste, Info.plists, `project.yml`, Workflows und die Composite-Actions
     unter `.github/actions/` (`setup-xcodegen` läuft in beiden Signier-Jobs, im selben Job wie der
     App-Store-Connect-Schlüssel, und in jedem Gate; `setup-asc-api-key` nutzt heute kein Workflow),
     `EchoelStudio/RELEASE`, die Fastlane-Dateien `fastlane/Fastfile`, `Appfile`, `Deliverfile` und
     `Pluginfile`, der `Gemfile` (eine Zeile dort aktivierte die heute inerte `Pluginfile`), Store-Text,
     `ContentPipeline/CLAIMS.md`, `docs/dev/FEATURE_STATUS.md` und `.claude/settings.local.json`, die
     das Token hält — die Liste ist `SENSITIVE` im Workflow, ohne Groß-/Kleinunterscheidung auf dem
     gefalteten Namen geprüft) deckt die Freigabe nicht. Sie kommen als `scopeOpen` in `board.json`, und der Job
     bleibt auf `--open`, bis jeder Eintrag in `reviewedBy` die Nummer eines ANDEREN, FERTIGEN Jobs
     (`stage: "done"`) oder `founder JJJJ-MM-TT` trägt — dieselbe Strenge wie das Datum einer
     Geräte-Prüfung; ein Job im Spec-Stadium oder ein verworfener hat nichts geprüft. Fehlt
     `reviewedBy` oder ist es `null`, ist der Eintrag offen; jeder andere Wert ist ein Befund.
   - **ESCALATE** → `stage: "needs-human"`, `decision.md` mit **Why · Acceptance criteria (je
     erfüllt/offen) · For the human** (Fragen mit Empfehlung), plus die Inbox-Zeile im richtigen
     Abschnitt: §1 für Entscheidungen und Scope, §2 für Geräte-Bitten, §3 nur für gesperrte
     Dateien. Ihre Nummer kommt als `inbox` in `board.json`. Erst greppen, ob die Frage schon dort
     steht.
7. **Protokoll** — die Workflow-Rückgabe schreibt der PM nach `reviews/round-<n>/<linse>.md`;
   sie trägt `range`, `since`, `paths`, `criteria`, `deviceCriteria`, `founderAssumptions` und `recount`, also
   steht dort, über welchen Diff und welche Zählung geurteilt wurde. Die drei Zahlen stehen auch in
   `board.json`, wie `paths`: jede Runde liest sie von dort. `board.json` führt nur der PM, und zwar im
   SELBEN Commit wie die Widerlegung oder Nacharbeit, die die Runde abschließt — sonst zeigt das
   Board eine Runde, deren Antwort schon im Baum steht. Überblick:
   `python3 -I scripts/factory-board.py --open`.

## `board.json`

```json
{"id": "001-kurzer-name", "title": "…", "stage": "spec|build|review|approve|needs-human|done|dropped",
 "round": 1, "base": "<sha>", "head": "<sha>", "since": "<sha der vorigen Runde>",
 "lenses": ["code-reviewer", "security-agent", "ux"], "paths": ["<pfad>"],
 "criteria": 5, "deviceCriteria": [], "founderAssumptions": 0,
 "inbox": "<Inbox-Nummer>", "deviceOpen": [{"ask": "<Kurztext>", "inbox": "<§2-Familie>", "verified": "JJJJ-MM-TT"}],
 "scopeOpen": [{"file": "<pfad außerhalb von paths>", "reviewedBy": "<Nummer eines anderen, fertigen Jobs oder founder JJJJ-MM-TT>"}],
 "history": [{"stage": "spec", "date": "2026-10-19", "note": "…"}]}
```

`id` muss gleich dem Ordnernamen sein; `factory-board.py` meldet eine Abweichung, statt zu raten.
Ein `deviceOpen`-Eintrag ohne `verified` ist offen; `verified` kommt erst mit dem Datum der
Geräte-Antwort. Ein `scopeOpen`-Eintrag ohne `reviewedBy` (oder mit `null`) ist offen; ein
`reviewedBy`, das weder einen anderen, fertigen Job dieser Factory noch `founder JJJJ-MM-TT` nennt,
ist ein Befund. Jeder Wert wird GANZ gelesen: ein angehängter Zeilenumbruch ist kein Datum. Beide
Listen müssen Listen von Objekten sein; alles andere — auch `null` oder eine Zahl — meldet das Board
als Befund.

## Wann nicht

Eine Ein-Zeilen-Reparatur, ein reiner Tippfehler, ein Satz in einer INTERNEN Datei (`docs/dev/`
außer `FEATURE_STATUS.md`, `memory/`, `scratchpads/`): direkt, ohne Factory (Council-Regel gegen
Trivia). `docs/dev/FEATURE_STATUS.md` ist eines der zwei Register, aus denen Store, Website und
Content ihre Behauptungen holen. Ein Satz auf der
Website, im Store-Text oder in `ContentPipeline/` ist dagegen eine Behauptung nach außen und läuft
durch die Factory — die UX-Linse prüft genau das. Die Factory kostet bis zu fünf Agentenläufe je Runde — vier Linsen,
der Approver nur in der Runde ohne offene Befunde, an der Grenze, bei einer Änderung an der
Sperr-Konfiguration oder bei einem Dateinamen, den jede Linse mit einem versteckten Zeichen meldet (die
beiden überspringen die Nacharbeit); sie lohnt sich ab mehreren
Dateien, einer sichtbaren Fläche oder einer Behauptung nach außen.

## Was die Factory nicht ersetzt

CI (der einzige Compiler), das Gerät (der einzige Beleg für Klang, Bild, Puls), den Founder
(Scope, Geld, Recht) und `the-council` (Abwägung vor einer schwer umkehrbaren Entscheidung).
Sie ersetzt das, was in dieser Sitzung zu spät kam: die Prüfrunde NACH dem Commit, die eine
falsche Behauptung erst fand, als sie schon in drei Dateien stand.

Wächter: `Tests/CISmoke/TheFactoryReviewersAreReadOnlyTests.swift` — jede `agent(`-Stelle des
Workflows trägt die Nur-Lesen-Klausel, der Wrapper stellt sie wirklich voran, jeder `agentType`
ist ein Roster-Name, die Rundenzahl hier ist die des Workflows, der Approver liest die Sperrliste
an der Job-Basis und prüft die Basis in `board.json`, jeder Pfad, über den die Sperre definiert ist (Hook und `permissions.ask`), eskaliert
fest, der Prüfer kann seine eigene Änderung nicht freigeben, die feste Eskalation steht vor jeder
Zähl-Rückfrage, und ein `founder`-Etikett ist kein Code-Beleg. ⚠️ Er läuft erst mit dem
nächsten Commit, der `Sources/` oder `Tests/` berührt — eine reine `.claude/`-Änderung startet
kein Gate. Wer den Workflow ändert, transkribiert die Ansprüche vor dem Push und fährt
`python3 -I scripts/factory-review-selftest.py` — die Entscheidungslogik unter Node mit
Attrappen-Agenten, ein Fall je Zweig von Schritt 6, dazu die PROMPTS, die die Attrappen bekommen
(Nur-Lesen-Klausel zuerst, `paths` an jedem Diff-Befehl, die Linsen mit dem Diff bis zum schließenden
Backtick, jeder liest die Spec am Kopf-SHA, der Approver zählt sie ZUERST — keine Zahl des PM im Prompt,
`board.json` und `reviews/` nicht im Diff — und liest die Sperrliste und den Job ab der Job-Basis, der Datenblock ist ASCII auf einer Zeile und kann
seine Marker nicht schließen). Lädt der Workflow nicht, endet es mit 2, nie mit „grün“. `--mutate` legt jede Zeile seiner
Mutationstabelle einmal an eine Kopie des Workflows und verlangt, dass ein Fall rot wird; eine
Zeile, deren Text der Workflow nicht mehr genau einmal enthält, ist ein Fehler, kein Überspringen.
`python3 -I scripts/factory-board.py --selftest` (und `--mutate`) prüft das Board ebenso, auch dass ein
kaputtes `deviceOpen` oder `scopeOpen` gemeldet wird statt abzustürzen.
