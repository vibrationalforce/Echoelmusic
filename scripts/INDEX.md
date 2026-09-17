# `scripts/` — the toolbox, and WHEN to reach for each tool

**Warum diese Datei existiert (#1359).** Der Ordner hatte 24 Werkzeuge und kein
Inhaltsverzeichnis. Acht davon laufen in jedem Zyklus, weil sie in den Anweisungsdateien
namentlich stehen. **ZWEI standen in KEINER: `window-margins.py` und `doorless-state.py`**
— gemessen mit `git grep` über `CLAUDE.md`, `.claude/**` und `Tests/CISmoke/CLAUDE.md`,
null Treffer für beide. Sie wurden nur gefunden, wenn sich jemand an sie erinnerte.

⛔ **Die erste Fassung dieses Absatzes sagte DREI und zählte `needle-reachability.py` mit —
falsch, und zwar in genau der Datei, die gegen das Verlieren von Werkzeugen geschrieben
wird.** Das Werkzeug steht sehr wohl in `Tests/CISmoke/CLAUDE.md` §#808, mit Befehl und
Auslöser. Es ist hier trotzdem in Abschnitt B, weil sein Auslöser eng ist — aber „nirgends
genannt" war eine Behauptung über einen NACHBARN aus dem Gedächtnis, und die ist in diesem
Repo eine MESSUNG (das Gesetz steht im Kopf von `GenreBatchFourteenBTests`). Zwei
`git grep` haben sie in Sekunden widerlegt.

Der Auslöser für diese Datei war derselbe Fehler im Kleinen: ich habe für einen
Patch-Kommentar fast einen Wegwerf-Parser getippt, obwohl `genre-prebatch.py --patch` seit
#1351 existiert und seine eigene Abdeckung druckt — der #1350-Fehler, im selben Zyklus.

⭐ **Das GESETZ dieser Datei ist die dritte Spalte, nicht die erste.** Ein Verzeichnis, das
nur sagt, WAS ein Werkzeug tut, wird beim Suchen nicht gelesen — man sucht ja, weil man das
Werkzeug nicht kennt. Gelesen wird die Zeile, die sagt, **WANN** man es holt. Wer hier
etwas einträgt, schreibt den Auslöser, nicht die Beschreibung.

⚠️ **Kein Werkzeug hier ändert eine Datei.** Alle sind read-only und drucken Befunde.
Ein Befund ist eine FRAGE, keine Diagnose — das steht in mehreren der Skripte noch einmal
in eigenen Worten, und es gilt für alle.

---

## A — DIE ACHT PRÜFER: jeder Zyklus, vor jedem Commit, alle müssen mit 0 enden

| Werkzeug | Wann |
|---|---|
| `swift-escapes.py` | Immer. Fängt die eine Compile-Fehlerklasse (ungültige Escape-Sequenz in einem Swift-String), die ein Web-Zyklus ohne Toolchain sonst erst am Gate sieht. |
| `dead-needles.py` | Immer. Findet Wächter, die auf einem KORREKTEN Baum rot sind — die Sorte, die tagelang unsichtbar bleibt, weil das Job-Log nur `tail -200` ist (#807). |
| `count-pins.py --all` | Immer. Eine gepinnte ZAHL in `Tests/CISmoke`, die nicht mehr zu ihrer Quelle passt. |
| `moved-needles.py` | Immer, und besonders bei einer LÖSCHUNG: welcher Wächter ankert auf einer Zeile, die dieser Diff entfernt? |
| `foreign-needles.py` | Immer. Wächter, die eine NICHT-Swift-Datei lesen (`docs/`, `fastlane/metadata`, `CLAUDE.md`) — ist die Nadel dort noch wahr? |
| `diag-ladder.py --source` | Immer. Die Absturz-Leiter aus der QUELLE; mit einem Pfad auf ein `echoel_diag.log` liest dasselbe Werkzeug das GERÄT. |
| `founder-verify.py --selftest` | Immer. Ohne `--selftest` druckt es die Geräte-Prüfliste; **mit `--since <sha>` nur das, was seit einem Deploy neu beantwortbar ist** — diese Form gehört in JEDE Build-Notiz. |
| `genre-prebatch.py --selftest` | Immer. Ohne Flagge rechnet es eine Genre-Scheibe vor; **`--patch "<Name>"` beantwortet jede Frage über einen Patch-NACHBARN** und druckt seine eigene Abdeckung (#1350). |

## B — DIE DREI MIT DEM ENGEN AUSLÖSER (zwei davon standen nirgends)

Sie gehören nicht in den Acht-Satz — sie sind nicht bei jedem Commit sinnvoll. Sie haben
einen ENGEREN Auslöser, und ohne die dritte Spalte ist ein enger Auslöser unsichtbar.
⚠️ `needle-reachability.py` steht bereits in `Tests/CISmoke/CLAUDE.md` §#808; es ist hier
der Vollständigkeit halber. `window-margins.py` und `doorless-state.py` standen nirgends.

| Werkzeug | Wann |
|---|---|
| `needle-reachability.py` | **Sobald ein neuer Wächter eine RUNTIME-Nadel schreibt** (`SomeType.f(x).contains("lit")`). Eine SCAN-Nadel prüft man beim Schreiben per `grep`; eine Runtime-Nadel kann niemand ohne Compiler prüfen — #808 blieb so zwei Monate rot. |
| `window-margins.py` | **Sobald ein ⛔-Block über eine bereits geprüfte Stelle geschrieben wird.** Ein Fenster `…prefix(N)` zählt auch die Leerzeichen gestrippter Kommentare mit; Prosa über der Zusicherung schiebt die Nadel aus dem Fenster und macht einen Wächter auf KORREKTEM Code rot. |
| `doorless-state.py` | **Nach einer Löschung, und beim Suchen nach einem Knopf ohne Schalter.** Non-private `var` mit Default, auf einem lebenden Pfad gelesen, nirgends geschrieben. ⚠️ Ein Treffer ist eine FRAGE — eine DSP-Konstante ohne Schreiber ist richtig so. |

## C — GATE-LESER: wenn CI rot ist oder man ihr nicht glaubt

| Werkzeug | Wann |
|---|---|
| `gh-run-status.py <datei>` | Wenn ein `mcp__github__actions_*`-Dump ins Token-Limit läuft und in eine Datei geschrieben wurde. Eine Zeile je Lauf. ⚠️ Für den bloßen Status eines Laufs ist die UNAUTHENTIFIZIERTE `api.github.com`-Route billiger — öffentliches Repo, kein Token. |
| `gh-test-verdict.py <datei>` | Wenn ein Job-Log gelesen werden muss. Druckt Build-Verdikt plus fehlgeschlagene UND übersprungene Tests namentlich (ein Skip ist kein Pass, #806). **Erst die `WINDOW`-Zeile lesen, bevor man ein Grün zitiert** (#807). |
| `doctor.py --section A\|B\|C\|D` | Bevor man „die Gates sind grün" als Beleg nimmt, und nach jeder Feature-Löschung. **Sektionsweise fahren** — der Gesamtlauf ist schon einmal im 2-Minuten-Timeout stumm gestorben. Exit 2 heißt INSTRUMENT UNAVAILABLE, also KEINE Aussage über das Repo. |

## D — DEPLOY UND PROJEKT: founder-nah, selten, nie blind

| Werkzeug | Wann |
|---|---|
| `preflight-check.sh` | Vor einem TestFlight-Deploy, auf dem Mac. |
| `check-secrets.sh` | Wenn der Deploy an der Secret-Prüfung scheitert. Erwartet `ASC_*` in der Umgebung. |
| `check-testflight.sh` | Lokaler Helfer zum Diagnostizieren des TestFlight-Workflows; liest den Token aus `.claude/settings.local.json` (gitignored). ⚠️ Diese Datei existiert in einer Web-Sitzung NICHT. |
| `check-infoplist.sh` | Nach `xcodegen generate` — die Plist bleibt vollständig und wahr. Sie selbst ist founder-gated: berichten, nicht editieren. |
| `generate-xcode-project.sh` · `install-hooks.sh` · `build-guard.sh` | Einrichtung auf dem Mac. `build-guard.sh` hängt als pre-push-Hook. |
| `test-asc-api.rb` | Nur wenn die App-Store-Connect-Anmeldung selbst fraglich ist. |

## E — MEDIEN UND INHALT: Pipeline, nie in `Sources/`

| Werkzeug | Wann |
|---|---|
| `analyze-youtube.py` | Ein YouTube-Link soll durch das Inspirations-Tor. Holt Metadaten + Transkript. |
| `render-og-cover.py` | `docs/og-image.svg` hat sich geändert — die PNG-Sozialkarte neu rendern. ⛔ #1312: diese Karte hat AUv3 als PIXEL behauptet, in jeder Link-Vorschau, und stand in keinem Text-Scan. |

---

⚠️ **Wer ein Werkzeug hinzufügt, trägt es hier ein — `TheToolboxHasAnIndexTests` wird sonst
rot.** Der Wächter verbietet das neue Werkzeug NICHT (#364); er verlangt die Zeile, die
sagt, wann man es holt. Ein Werkzeug, das niemand findet, ist teurer als keines: es sieht
aus wie erledigte Arbeit und wird trotzdem noch einmal getippt.
