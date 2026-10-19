# Externe Prüf-Aufträge — SuperGrok Heavy · ChatGPT (2026-10-16 → 2026-11-06)

Founder 2026-10-16: „Schreib in den kommenden 3 Wochen immer wieder zwischendurch Aufträge um
supergrok Heavy und ChatGPT nach Feedback und aktuellen Entwicklungen zu fragen. So können wir
sicherstellen, dass wir unseren Plan verfolgen Echoelmusic wirklich nutzbar zu machen."

**Ablauf:** Montags und donnerstags schreibt die Sitzung hier eine neue Runde (je ein Auftrag pro
Modell, zugeschnitten auf das, was seit der letzten Runde gebaut wurde). Der Founder kopiert den
Auftrag in SuperGrok Heavy bzw. ChatGPT und fügt die Antwort hier im Chat ein. Die Antwort läuft
durch den Lernmodus (`.claude/skills/learn-mode/SKILL.md`): gesäubert, jede Behauptung gemessen,
einmal geloggt (`inspiration.csv`, `memory/inspiration_intake.md`), dann Verdikt.

**Was rausgeht (Lernmodus „Was RAUSGEHT"):** die öffentliche Repo-URL, der Zweig, Dateipfade und
Auszüge GETRACKTER Dateien. Nie: `.claude/settings.local.json`, Diagnose-Logs (Puls/Atem =
Gesundheitsdaten), App-Store-Schlüssel, Tester-Feedback, Geräte-Logs echter Nutzer.

**Rolle der fremden Modelle:** PRÜFER, nie Bauer. Höchstens 8 Punkte, jeder mit Datei und Zeile
oder Quelle mit Datum, je „sicher" oder „vermutet", kein Code. Die Bilanz je Quelle:
`python3 -I scripts/learn-intake.py --tally`.

---

## Runde 1 — Donnerstag, 16.10.2026 (Stand `39f954d`)

### Auftrag an SuperGrok Heavy — aktuelle Entwicklungen

```
Rolle: externer Prüfer für Echoelmusic, ein iPhone-first Musik- und Multimedia-Instrument
(Swift, null externe Abhängigkeiten, alles auf dem Gerät). Öffentliches Repo:
https://github.com/vibrationalforce/Echoelmusic — Zweig claude/echoelmusic-review-optimize-u5jjpd.

Wir bauen gerade eine Assistenz-Schicht: Eine Bitte in eigenen Worten ("make the selected track
3 dB quieter") geht an Apples On-Device-Sprachmodell (Foundation Models). Das Modell darf nur
VORSCHLAGEN — höchstens 3 Schritte aus 3 erlaubten Befehlen (Stück beschreiben, Spurlautstärke,
Teil kopieren). Erst ein Tap auf "Apply" ändert das Stück; Undo nimmt es zurück; ändert sich die
Auswahl vorher, wird abgewiesen. Zugang heute nur über Siri/Kurzbefehle ("Ask Echoelmusic").
Dateien: Sources/Echoelmusic/EchoelAI/EchoelModelPlanner.swift,
Sources/Echoelmusic/EchoelAI/EchoelAgentDesk.swift, Sources/Echoelmusic/Studio/EchoelAppIntents.swift.

Bitte recherchiere die AKTUELLEN Entwicklungen der letzten 4 Wochen (Stand heute), nur mit Quelle
und Datum:
1. Apple Foundation Models / Apple Intelligence: Änderungen an Verfügbarkeit, Kontextgröße,
   Guided Generation, Tool Calling, Latenz auf iPhone — und was davon für "Vorschlag statt
   Ausführung" relevant ist.
2. App Intents / Siri: Wie lange wartet Siri auf ein perform(), das ein On-Device-Modell
   aufruft (Sekunden)? Gibt es neue Muster für "Ergebnis in der App bestätigen"?
3. Musik-Software mit Sprach-/Agenten-Bedienung (Logic, Ableton, Bitwig, BandLab, neue Startups):
   was ist wirklich ausgeliefert, was ist Ankündigung?
4. On-Device-Musikgenerierung (symbolisch/MIDI) auf Apple-Hardware: neue Modelle mit Lizenz,
   Größe, Latenz.

Form: höchstens 8 Punkte. Jeder Punkt: Behauptung · Quelle (URL) · Datum · "sicher" oder
"vermutet" · was das für Echoelmusic konkret heißt. Keine Code-Vorschläge. Gerüchte als
Gerüchte kennzeichnen.
```

### Auftrag an ChatGPT — Nutzbarkeit des neuen Ablaufs

```
Rolle: externer UX- und Workflow-Prüfer für Echoelmusic (iPhone-Musik-Instrument, Swift).
Öffentliches Repo: https://github.com/vibrationalforce/Echoelmusic —
Zweig claude/echoelmusic-review-optimize-u5jjpd, Stand 39f954d.

Lies nur diese Dateien:
- Sources/Echoelmusic/EchoelAI/EchoelAgentDesk.swift (proposePlan, applyProposal,
  discardProposal, proposalSentence)
- Sources/Echoelmusic/Studio/AgentReportBanner.swift (die Zeile mit Apply / Discard / Stop / Undo)
- Sources/Echoelmusic/Studio/EchoelAppIntents.swift (AskEchoelIntent)
- docs/dev/FEATURE_STATUS.md §1b (was gebaut, aber noch nicht ausgeliefert ist)

Ablauf, den wir abnehmen wollen: Absicht sagen → Vorschlag oder Rückfrage → Apply →
normales, bearbeitbares Ergebnis im Stück → Undo.

Fragen:
1. Versteht ein Musiker VOR dem Apply, was sich ändert? Ist der Satz
   "Echoel would make Keys 3.0 dB quieter. Nothing changes until you tap Apply." klar genug?
2. Wo kann der Ablauf hängen bleiben (Siri wartet, App im Hintergrund, Auswahl gewechselt,
   anderes Stück geöffnet)? Nenne Datei und Zeile.
3. Was fehlt, damit das im Alltag einer Produktion wirklich benutzt wird — ohne neues Fenster,
   ohne neuen Chat-Bereich?
4. Welche zwei Gerätetests würdest du als erstes machen, und was genau soll man sehen?

Form: höchstens 8 Punkte, je Datei:Zeile, "sicher" oder "vermutet", kein Code.
```

**Antworten:** _(hier im Chat einfügen; die Sitzung loggt sie im Lernmodus)_

---

## Runde 2 — Montag, 19.10.2026 (Stand `a66e0e5`)

**Was sich seit Runde 1 geändert hat:** Echoel ist am 17.10. neu aufgesetzt — `EchoelStudio/` ist die
neue App (drei Swift-Pakete `EchoelCore` · `EchoelDSP` · `EchoelEngine` ohne Abhängigkeiten, App,
EINE AUv3-Erweiterung). Der Bauplan `docs/dev/NEUPLANUNG_2026-10-18.md` ist vom Founder freigegeben:
keine Genres, keine generierten Noten, Phase P0 (Ordnung) vor P1 (Komponieren) vor P2 (eigene AUv3 +
ein Kauf → 1.0). Seit Runde 1 sind P0.1–P0.5 gebaut (eine Parametertabelle, Songformat `docs/FORMAT.md`
mit Golden-Files, Netzwerk-API-Scan, abgewiesene unspielbare Spur, musikalischer Kontext, Vorwärts-
kompatibles Öffnen), die Kaufkennung ist aus dem offenen Kern in die Plugin-Schicht gezogen, und Core
und DSP laufen erstmals auf Linux (Core 201/201, DSP 64/64, Swift 6.2.4). Der Agent aus Runde 1 lebt
in `EchoelStudio/App/Agent/` weiter und läuft ab P1 mit. Runde 1 ist noch unbeantwortet; ihre Fragen
(Foundation Models, Siri-Wartezeit, Agenten-DAWs, On-Device-MIDI-Modelle) werden hier NICHT
wiederholt — sie können zusammen mit Runde 2 beantwortet werden.

### Auftrag an SuperGrok Heavy — aktuelle Entwicklungen (P0/P1/P2-Zuschnitt)

```
Rolle: externer Prüfer für Echoel Studio, eine iPhone/iPad-Musik-Workstation in Swift ohne externe
Abhängigkeiten (alles auf dem Gerät). Öffentliches Repo: https://github.com/vibrationalforce/Echoelmusic
— Zweig claude/echoelmusic-review-optimize-u5jjpd, Verzeichnis EchoelStudio/ (Bauplan:
docs/dev/NEUPLANUNG_2026-10-18.md §3 und §5).

Was gerade gebaut wird: ein Instrumentenpfad für eigene AUv3-Units (eine Erweiterung, Synth · Drums ·
Sampler, Effekte frei, Instrumente hinter EINEM nicht-verbrauchbaren Kauf), AUv3-Hosting fremder
Plugins, Swift-6-Pakete, die auch auf Linux bauen und testen (swift:6.2-Container, XCTest).

Bitte recherchiere die AKTUELLEN Entwicklungen der letzten 3 Wochen (Stand heute), nur mit Quelle
und Datum:
1. iOS 26.x / Xcode 26.x: Änderungen an AUv3-Erweiterungen, die in einer App eingebettet sind
   (Registrierung, auval, Darstellung der Plugin-Oberfläche in fremden Hosts, Speicherlimit der
   Erweiterung). Gibt es neue Pflichten oder Abweisungsgründe im App Review für Audio-Unit-Apps?
2. StoreKit 2: ein Kauf in der App soll Inhalte INNERHALB der Erweiterung freischalten (die
   Erweiterung läuft im fremden Host). Was ist Apples aktueller Weg (Transaction.currentEntitlements
   aus der Erweiterung, App Group, Receipt)? Gab es dazu Änderungen oder bekannte Fehler?
3. Swift 6.2 auf Linux: Stand von swift-corelibs-xctest gegenüber Swift Testing für Pakete, die
   @MainActor-Typen testen — ist XCTest dort noch der empfohlene Weg, oder wird Swift Testing für
   Linux-CI nahegelegt? Bekannte Fallen bei der Test-Erkennung (Discovery) in 6.2.x.
4. CoreMIDI auf iOS 26: Network MIDI (MIDINetworkSession, Verbindungsrichtlinie), MIDI 2.0 / UMP,
   MIDI-Clock-Ausgabe — was hat sich geändert, was ist deprecated?
5. Ableton Link: aktueller Lizenzstand des Link-SDK (Bedingungen für eine kommerzielle iOS-App),
   Alternativen für Tempo-Sync ohne Fremdcode (MIDI-Clock, MTC), und was andere iOS-DAWs dafür
   ausliefern.
6. Wettbewerb der letzten Wochen: Logic Pro für iPad, Cubasis, AUM, Drambo, Koala, BandLab,
   neue Einsteiger — was ist WIRKLICH ausgeliefert zu (a) AUv3-Hosting mit In-App-Kauf von
   Instrumenten, (b) Projektformaten, die ein Dritter lesen kann, (c) Offline-Export mit
   Lautheitsmessung? Ankündigungen als Ankündigungen markieren.

Form: höchstens 8 Punkte. Jeder Punkt: Behauptung · Quelle (URL) · Datum · "sicher" oder
"vermutet" · was das für Echoel Studio konkret heißt (eine Zeile). Keine Code-Vorschläge.
Gerüchte als Gerüchte kennzeichnen. Keine Gesundheits- oder Wellness-Themen.
```

### Auftrag an ChatGPT — Nutzbarkeit dessen, was seit 17.10. gebaut ist

```
Rolle: externer UX- und Workflow-Prüfer für Echoel Studio (iPhone/iPad-Musik-Workstation, Swift).
Öffentliches Repo: https://github.com/vibrationalforce/Echoelmusic —
Zweig claude/echoelmusic-review-optimize-u5jjpd, Stand a66e0e5, Verzeichnis EchoelStudio/.

Lies nur diese Dateien (alle getrackt, alle öffentlich):
- docs/dev/NEUPLANUNG_2026-10-18.md §1 (was Echoel ist und was nicht) und §5 (Bauphasen P0–P2)
- EchoelStudio/CLAUDE.md (Schichten, die neun Gesetze)
- EchoelStudio/Core/Sources/EchoelCore/CommandCatalog.swift (die Befehlsnamen — sie werden in P0
  EINGEFROREN, weil MIDI-Mappings und Agenten-Protokolle sie speichern)
- EchoelStudio/Core/Sources/EchoelCore/Command.swift (apply: was abgewiesen wird)
- EchoelStudio/App/Views/StudioView.swift, ArrangeView.swift, TrackListView.swift,
  SoundPanel.swift, MixerView.swift (die Oberfläche)
- EchoelStudio/App/Documents/DocumentController.swift (exportWAV, exportMIDI)
- EchoelStudio/App/Store/StoreView.swift und EchoelStudio/Plugins/Shared/PluginUnlock.swift
  (ein Kauf schaltet die Instrumente frei; Effekte sind frei)
- EchoelStudio/App/Agent/AgentView.swift (die Assistenz, die ab P1 mitläuft)

Abnahmekriterium P1 aus dem Bauplan: auf dem Gerät Ton in unter 3 Sekunden; ein Song mit vier
Spuren im Flugmodus erstellt, gespeichert, wieder geöffnet, als WAV exportiert.

Fragen:
1. Befehlsnamen (CommandCatalog.swift): welche Namen würde ein Musiker oder eine MIDI-Controller-
   Nutzerin missverstehen, welche zwei Befehle wirken wie Dubletten, welcher fehlt für den
   Vier-Spuren-Song? Datei:Zeile. Das zählt doppelt, weil die Namen danach nicht mehr änderbar sind.
2. Erster Ton: welche Taps liegen zwischen App-Start und dem ersten gespielten Ton, und wo kann
   der Weg abbrechen (keine Spur, kein Instrument, Kauf-Dialog vor dem ersten Ton)? Datei:Zeile.
3. Abweisungen (Command.swift apply): welche Abweisung sieht der Nutzer NICHT als Satz auf dem
   Schirm, sondern nur als "nichts passiert"? Nenne die Stelle.
4. Kauf-Grenze: ist aus StoreView.swift und PluginUnlock.swift klar, was frei ist und was
   gekauft wird, BEVOR jemand den Kauf-Dialog sieht? Was würde Apple im Review daran stören?
5. Export: reicht WAV + MIDI für die Übergabe an Logic/Ableton, oder fehlt vor 1.0 ein Stem-Export?
   Begründe aus dem, was DocumentController.swift heute tut.
6. Welche zwei Gerätetests würdest du als Erstes machen, und was genau soll man dabei sehen?

Form: höchstens 8 Punkte, je Datei:Zeile, "sicher" oder "vermutet", kein Code, keine neuen
Features vorschlagen, nichts zu Gesundheit oder Wellness.
```

**Antworten: beide am 19.10. eingetroffen und gemessen** (Workflow `wf_13fad8af-ca3`; Ledger `memory/inspiration_intake.md` 2026-10-19, `inspiration.csv`). ChatGPT `[verified 28/31]` → ADOPT→PRODUCT: zwei Bug-Scheiben (stille `try?`-Abweisung bei Namen über 128 Zeichen an drei Stellen; `exportWAV` wartet nicht auf `mediaLoad`), vier Katalog-Namen in den P0-Posten, Store-Satz „in Echoel frei“, kein Stem-Pfad; Quelle formal kontaminiert (U+2060), kein Satz kopiert. Grok `[verified 3/8]` → WATCH: Extension liest `currentEntitlements` selbst, LUFS im Export real, `.anyone` sitzt bei `MIDIInput.swift:437` (unsere :398 war veraltet), vier externe Behauptungen ungeöffnet.
