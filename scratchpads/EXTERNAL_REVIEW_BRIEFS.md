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

---

## Runde 3 — Dienstag, 20.10.2026, zum Einkopieren am Do 22.10. (Stand `44009af87`)

**Was sich seit Runde 2 geändert hat:** Songformat 2 mit strengem Leser (S-20 bis S-25, `docs/FORMAT.md`);
ein Song ist EINE Datei in „Dateien“ und öffnet sich per AirDrop (E4); die Laufzeit-Härtung aus dem
Ultra-Audit (Audio-Neustart nach gescheitertem Start, Absturz-Schutz beim Start, Kopfhörer, Anruf
während einer Aufnahme, abgestürzte Plugin-Erweiterung, Wechsel der Abtastrate); ein Starttest im
Simulator in der CI; und sieben Korrekturen, die zwei interne Prüfrunden am selben Tag gefunden
haben (Commits `57673cf96` bis `44009af87`). Nichts davon ist auf einem Gerät geprüft. Die App selbst
hat kein Test-Target — nur die drei Pakete haben Tests.

### Auftrag an ChatGPT — wo verliert die App heute Arbeit oder hängt sich auf?

```
Rolle: externer Code-Prüfer für Echoel Studio (iPhone/iPad-Musik-Workstation, Swift 6, keine
externen Abhängigkeiten). Öffentliches Repo: https://github.com/vibrationalforce/Echoelmusic —
Zweig claude/echoelmusic-review-optimize-u5jjpd, Stand 44009af87, Verzeichnis EchoelStudio/.

Lies nur diese Dateien (alle getrackt, alle öffentlich):
- EchoelStudio/CLAUDE.md (Schichten und Gesetze)
- EchoelStudio/App/Engine/AudioEngine.swift (start, configure, resume, wake, healIfStopped,
  restartAudio, enterBackground, pauseFromOutside, der Abtastraten-Zweig in configure)
- EchoelStudio/Engine/Sources/EchoelEngine/AudioRecoveryPolicy.swift
- EchoelStudio/App/Engine/RecordController.swift
- EchoelStudio/App/Documents/DocumentController.swift (restore, beginLaunch, confirmLaunch,
  newSong, open, saveNow, openIncoming)
- EchoelStudio/Core/Sources/EchoelCore/LaunchRecord.swift
- EchoelStudio/App/Engine/PluginHost.swift (unitStopped und die zwei Beobachter)
- EchoelStudio/App/EchoelStudioApp.swift
- .github/workflows/studio.yml (der Schritt "Launch smoke (iOS Simulator)")

Fragen:
1. Arbeit verlieren: gibt es einen Weg (Anruf, Hintergrund, Absturz, Songwechsel, Abtastrate,
   Kopfhörer), auf dem eine Aufnahme, eine Note oder eine Plugin-Einstellung verloren geht,
   obwohl der Nutzer nichts falsch gemacht hat? Datei:Zeile und die Schrittfolge.
2. Hängen: kann eine der Wiederherstellungen (Retry, Interruption .ended, Media-Reset,
   Konfigurationsänderung) sich selbst endlos neu auslösen, oder dauerhaft stillstehen, ohne
   dass der Knopf "Restart audio" erscheint?
3. Absturz-Schutz beim Start: LaunchRecord und DocumentController.restore öffnen nach einem
   abgebrochenen Start einen neuen Song. Gibt es einen Fall, in dem ein gesunder Start als
   abgebrochen zählt (Fehlalarm), oder ein tödlicher Song trotzdem bei jedem Start geöffnet wird?
4. Hintergrund: welche Kombination (spielt, nimmt auf, folgt einer externen Clock, wartet auf
   Eingang) hält die App wach, obwohl sie still ist? Das ist App-Review-Richtlinie 2.5.4.
5. Der Starttest in studio.yml: was kann er NICHT sehen (zum Beispiel einen Absturz erst nach
   20 Sekunden, einen Hänger ohne Absturz, die AUv3-Erweiterung, die er weglässt)? Nenne die
   zwei wichtigsten Lücken.
6. Swift 6: siehst du in diesen Dateien eine Closure, die Apple-Frameworks außerhalb des
   Main-Threads aufrufen, die aber MainActor-isoliert ist (das stürzt mit SIGTRAP ab)?

Form: höchstens 8 Punkte, je Datei:Zeile, "sicher" oder "vermutet", kein Code, keine neuen
Features, nichts zu Gesundheit oder Wellness.
```

### Auftrag an SuperGrok Heavy — was Apple dazu heute sagt (nur mit Quelle)

```
Rolle: externer Rechercheur für Echoel Studio, eine iPhone/iPad-Musik-Workstation in Swift ohne
externe Abhängigkeiten, die eine eigene AUv3-Erweiterung einbettet und fremde Audio Units hostet.
Öffentliches Repo: https://github.com/vibrationalforce/Echoelmusic (Zweig
claude/echoelmusic-review-optimize-u5jjpd, Verzeichnis EchoelStudio/).

Bitte recherchiere den AKTUELLEN Stand (iOS 26.x, Xcode 26.x), nur mit Quelle und Datum:
1. AVAudioSession: Verhalten von Unterbrechungen (Anruf, Siri, Alarm) unter iOS 26 —
   kommt .ended zuverlässig, wann darf eine App im Hintergrund setActive(true) aufrufen, und
   welche Fehlercodes kommen dann? Gab es Änderungen gegenüber iOS 18?
2. App-Review-Richtlinie 2.5.4 (Hintergrund-Audio): ist eine Musik-App, die im Hintergrund
   still auf den Start-Befehl einer externen MIDI-Clock wartet, zulässig? Gibt es dokumentierte
   Ablehnungen oder Apple-Aussagen dazu?
3. AUv3-Erweiterungen: wann sendet iOS kAudioComponentInstanceInvalidationNotification, und
   lädt AUM/Logic/Cubasis eine Unit danach selbst neu? Was ist die empfohlene Reaktion des Hosts?
4. Dokumente: ein eigener Dateityp (exportierter UTType, Paket als eine Datei) in "Dateien" und
   per AirDrop — bekannte Fehler unter iOS 26 beim Öffnen (LSSupportsOpeningDocumentsInPlace,
   Kopie statt Original, Sicherheitsbereich)?
5. Simulator in der CI: "Invalid placeholder attributes" beim Installieren einer unsignierten
   App mit eingebetteter Erweiterung — ist das bekannt, und ist ad-hoc-Signieren
   (CODE_SIGN_IDENTITY=-) der übliche Weg, die Erweiterung mitzutesten?
6. Abtastrate: ein USB-Interface ändert die Ausgaberate mitten in der Sitzung — wie verhalten
   sich AVAudioEngine und gehostete Audio Units, und was liefern andere iOS-DAWs dafür aus?

Form: höchstens 8 Punkte. Jeder Punkt: Behauptung · Quelle (URL) · Datum · "sicher" oder
"vermutet" · was das für Echoel Studio konkret heißt (eine Zeile). Keine Code-Vorschläge,
Gerüchte als Gerüchte, keine Gesundheits- oder Wellness-Themen.
```

**So kommen die Antworten zurück:** in den Chat einfügen; die Sitzung prüft jede Behauptung am Repo
(Lernmodus) und trägt das Ergebnis ins Ledger ein.

## Runde 4 — Donnerstag, 22.10.2026 (Stand `7fd569e65`)

**Diese Runde ersetzt Runde 3.** Runde 3 war für heute vorbereitet und ist nicht verschickt; der Code ist
seitdem weiter. Ihre Fragen, die noch offen sind, stehen hier in der Fassung für den heutigen Code
(Start-Fehlalarm, Hintergrund-Audio, Plugin-Invalidierung, Abtastrate). Was eine interne Prüfrunde
inzwischen selbst beantwortet hat, steht hier nicht mehr.

**Was sich seit Runde 3 geändert hat:** Build 10009 (TestFlight, 21.10.). Der Import der Songs der
früheren Echoelmusic-App ist neu gebaut: ein reiner Kern-Typ `EarlierSongImport` (14 Tests) entscheidet
über Starts hinweg, der Lauf geht im Hintergrund-Task, pausiert zwischen zwei Songs, wenn die App den
Vordergrund verlässt, und startet nur nach einem bestätigten Start (`518e80374..c586087ab`). Die App
fordert seit `a14e1960a` wieder die App Group `group.com.echoelmusic` an, in der die frühere App ihre
Songs abgelegt hat (Signier-Probe grün). Nach einem Neustart der Audio-Dienste baut die App jetzt eine
neue `AVAudioEngine` statt die tote neu zu starten (`cb6e3b09d`). Nichts davon ist auf einem Gerät
geprüft. Die App selbst hat kein Test-Target, nur die drei Pakete.

### Auftrag an ChatGPT — kann der Import Songs verlieren, und versteht man, was er sagt?

```
Rolle: externer Code- und UX-Prüfer für Echoel Studio (iPhone/iPad-Musik-Workstation, Swift 6, keine
externen Abhängigkeiten). Öffentliches Repo: https://github.com/vibrationalforce/Echoelmusic —
Zweig claude/echoelmusic-review-optimize-u5jjpd, Stand 7fd569e65, Verzeichnis EchoelStudio/.

Lies nur diese Dateien (alle getrackt, alle öffentlich):
- EchoelStudio/CLAUDE.md (Schichten und Gesetze)
- EchoelStudio/Core/Sources/EchoelCore/EarlierSongImport.swift und
  EchoelStudio/Core/Tests/EchoelCoreTests/EarlierSongImportTests.swift
- EchoelStudio/Core/Sources/EchoelCore/LegacySong.swift (Songs, project(at:), holdsReadableSong)
- EchoelStudio/Core/Sources/EchoelCore/LaunchRecord.swift
- EchoelStudio/App/Documents/DocumentController.swift (restore, sceneLeft, sceneEntered,
  armImportWait, confirmLaunch, importEarlierSongs, runImport, bring, earlierImportLaunchBegan,
  earlierBases, earlierSongs)
- EchoelStudio/App/Views/StudioView.swift (die Statuszeile unter der Transportleiste)
- EchoelStudio/App/Engine/AudioEngine.swift (replaceEngine, configure, resume, wake,
  healIfStopped, enterBackground) und EchoelStudio/App/Engine/PluginHost.swift
  (mediaServicesReset, unitStopped)
- EchoelStudio/Support/App/EchoelStudio.entitlements,
  EchoelStudio/Support/Plugins/EchoelPlugins.entitlements,
  EchoelStudio/Plugins/Shared/PluginUnlock.swift

Fragen:
1. Import: gibt es eine Schrittfolge (Absturz, Wegwischen, Hintergrund, Speicher voll, zweiter
   Start während der Lauf pausiert ist), nach der ein Song der früheren App fehlt, doppelt in der
   Bibliothek steht oder als "übernommen" gilt, obwohl er nicht geschrieben wurde? Datei:Zeile.
2. Import, die Gegenrichtung: gibt es einen Song, der jeden Start beendet und trotzdem immer wieder
   geöffnet oder gelesen wird? Oder einen gesunden Song, der fälschlich ausgelassen wird?
3. Statuszeile: lies die Sätze, die der Import zeigt (Hinweis und Warnung), so wie eine Musikerin
   sie liest. Was ist unklar, was verdeckt eine andere Meldung, was bleibt zu lange stehen?
4. Start-Fehlalarm: LaunchRecord und restore öffnen nach einem abgebrochenen Start einen neuen
   Song. Zählt ein gesunder Start irgendwo als abgebrochen (zum Beispiel ein Start, den der
   Nutzer nach 2 Sekunden in den Hintergrund schickt)?
5. Neustart der Audio-Dienste: kann replaceEngine zusammen mit resume, wake oder dem Retry die
   Engine zweimal aufbauen, gar nicht aufbauen, oder dauerhaft stillstehen, ohne dass der Knopf
   "Restart audio" erscheint?
6. Hintergrund (App-Review 2.5.4): welche Kombination (spielt, nimmt auf, folgt einer externen
   Clock, Import läuft) hält die App wach, obwohl nichts zu hören ist?
7. Welche zwei Gerätetests würdest du als Erstes machen, und was genau soll man dabei sehen?

Form: höchstens 8 Punkte, je Datei:Zeile, "sicher" oder "vermutet", kein Code, keine neuen
Features, nichts zu Gesundheit oder Wellness.
```

### Auftrag an SuperGrok Heavy — was sich in den letzten Tagen geändert hat (nur mit Quelle)

```
Rolle: externer Rechercheur für Echoel Studio, eine iPhone/iPad-Musik-Workstation in Swift ohne
externe Abhängigkeiten, die eine eigene AUv3-Erweiterung einbettet, fremde Audio Units hostet und
Songs einer früheren App aus deren App-Group-Container übernimmt. Öffentliches Repo:
https://github.com/vibrationalforce/Echoelmusic (Zweig claude/echoelmusic-review-optimize-u5jjpd,
Verzeichnis EchoelStudio/).

Bitte recherchiere den Stand von HEUTE (iOS 26.x, Xcode 26.x), nur mit Quelle und Datum. Wo es
nichts Neues seit dem 1.10.2026 gibt, sag das in einem Satz, statt Älteres aufzuzählen:
1. Neue iOS-/Xcode-Versionen und Betas der letzten zwei Wochen: Release Notes zu AVAudioEngine,
   AVAudioSession, Audio Units, App Groups, StoreKit oder TestFlight, die eine Musik-App betreffen.
2. AVAudioSession.mediaServicesWereResetNotification: was empfiehlt Apple heute (neue Engine und
   neue Knoten, oder Neustart der alten)? Gibt es Hinweise, dass gehostete Audio Units danach neu
   instanziiert werden müssen?
3. App Groups: eine App-Group-ID wurde am App-ID-Eintrag entfernt und wieder eingetragen. Bleibt der
   Container auf einem Gerät mit der früheren App-Version erhalten, wenn ein Update dieselbe Gruppe
   wieder anfordert? Was sagen Apple-Doku oder Entwicklerforen?
4. Unterbrechungen unter iOS 26 (Anruf, Siri, Alarm): kommt .ended zuverlässig, und welche Fehler
   liefert setActive(true) im Hintergrund?
5. App-Review 2.5.4: ist eine Musik-App zulässig, die im Hintergrund still auf den Start-Befehl einer
   externen MIDI-Clock wartet? Dokumentierte Ablehnungen oder Apple-Aussagen.
6. kAudioComponentInstanceInvalidationNotification: wann sendet iOS sie, und laden AUM, Logic für
   iPad oder Cubasis eine abgestürzte Unit selbst neu?
7. Abtastrate: ein USB-Interface wechselt die Ausgaberate mitten in der Sitzung. Wie verhalten sich
   AVAudioEngine und gehostete Units, und was liefern andere iOS-DAWs dafür aus?

Form: höchstens 8 Punkte. Jeder Punkt: Behauptung · Quelle (URL) · Datum · "sicher" oder
"vermutet" · was das für Echoel Studio konkret heißt (eine Zeile). Keine Code-Vorschläge,
Gerüchte als Gerüchte, keine Gesundheits- oder Wellness-Themen.
```

**So kommen die Antworten zurück:** in den Chat einfügen; die Sitzung prüft jede Behauptung am Repo
(Lernmodus) und trägt das Ergebnis ins Ledger ein.

**Antworten: beide am 22.10. eingetroffen und gemessen** (Workflow `wf_c4738df5-31a`; Ledger `memory/inspiration_intake.md` 2026-10-22, `inspiration.csv`). ChatGPT `[verified 6/7]` → ADOPT→PRODUCT: Dublette bei Prozessende vor der Marke, verschiebbare Platznummern, Aufgabe gesunder Songs, Fehlalarm unter 3 s Hintergrund, Hintergrund-Engine bei Clock-Follow und Transport ohne Ende; die Messung fand dazu drei schwerere Befunde (Export ohne Medien nach dem Öffnen, Songwechsel während des Exports, Öffnen nach gescheitertem Speichern verwirft Änderungen). Quelle formal kontaminiert (U+2060), kein Satz kopiert. Grok `[verified 4/8]` → WATCH: die vier Repo-Hälften (Reset, Rückkehr, Invalidation, Ratenwechsel) stimmen, die externen Punkte bleiben ungeöffnet.

---

## Runde 5 — Samstag, 24.10.2026 (Stand `b0f4e8b36`), vorgezogen von Montag

**Founder 2026-10-24:** „Gib mir Deep Research und Review Aufträge für DeepSeek, Mistral und vor allem ChatGPT Astra sehr hoch, super Grok Heavy.“ Diese Runde deckt deshalb vier Modelle ab. Hier stehen nur die drei Aufträge zum Code. Die Aufträge zu Förderung, Promo und Recht enthalten persönliche Rahmendaten und stehen nur im privaten Doc „Echoel · Deep Audit Förderung oder Unabhängigkeit“, Tab „KI-Aufträge“.

**Was sich seit Runde 4 geändert hat:** Starter-Song beim ersten Start, Tonart und Skala mit „Keys Follow Scale“, Stem-Export, Sampler- und Drum-Werte auf der Sound-Seite samt Automation, Song teilen als saubere Kopie, Song umbenennen (Factory 006/007). Nichts davon ist auf einem Gerät geprüft.

**Bilanz bisher** (`python3 -I scripts/learn-intake.py --tally`, 24.10.): ChatGPT Astra 50/57 · Mistral 36/44 · SuperGrok Heavy 43/65 · DeepSeek 10/24. DeepSeek bekommt deshalb nur einen engen Auftrag mit öffentlichem Code.

### Auftrag an ChatGPT (Astra, höchste Stufe) — Code- und Bedien-Prüfung

```
Rolle: externer Code- und UX-Prüfer für Echoel Studio (iPhone/iPad-Musik-Workstation, Swift 6, keine externen Abhängigkeiten). Öffentliches Repo: https://github.com/vibrationalforce/Echoelmusic, Zweig claude/echoelmusic-review-optimize-u5jjpd, Stand b0f4e8b36, Verzeichnis EchoelStudio/.

Lies nur diese Dateien (alle öffentlich):
- EchoelStudio/CLAUDE.md
- EchoelStudio/Core/Sources/EchoelCore/StarterProject.swift und MusicalContext.swift, dazu ihre Tests in EchoelStudio/Core/Tests/EchoelCoreTests/
- EchoelStudio/Core/Sources/EchoelCore/Automation.swift und EchoelStudio/App/Views/AutomationViews.swift
- EchoelStudio/App/Views/SoundPanel.swift, StudioView.swift, RenameSongView.swift
- EchoelStudio/App/Documents/DocumentController.swift (Umbenennen, Teilen, Speichern)
- EchoelStudio/App/Engine/AudioEngine.swift (Stem-Export) und EchoelStudio/Engine/Tests/EchoelEngineTests/StemRenderTests.swift
- EchoelStudio/DSP/Sources/EchoelDSP/Sampler.swift, DrumKit.swift und EchoelStudio/Engine/Sources/EchoelKernels/SamplerKernel.swift, DrumKernel.swift

Fragen:
1. Starter-Song: Was hört und sieht jemand beim allerersten Start? Kann der Starter einen gespeicherten Song überschreiben?
2. Tonart und Skala: Wenn „Keys Follow Scale“ an ist und man die Tonart während gehaltener Noten wechselt, bleibt eine Note hängen oder klingt falsch?
3. Stems: Haben alle Stems exakt dieselbe Länge und denselben Startpunkt, auch mit Effekt-Fahnen, Automation und einer stummen Spur?
4. Sampler und Drums: Kann ein Wert auf der Sound-Seite oder eine Automation einen Klick, eine Stille oder einen Wert außerhalb des Bereichs erzeugen?
5. Umbenennen und Teilen: Gibt es eine Schrittfolge, nach der ein Song doppelt, leer oder unter altem Namen geteilt wird?
6. Welche zwei Gerätetests würdest du zuerst machen, und was genau soll man sehen oder hören?

Form: höchstens 8 Punkte, je Datei:Zeile, „sicher“ oder „vermutet“, kein Code, keine neuen Features.
```

### Auftrag an SuperGrok Heavy — was sich für iOS-Musik-Apps geändert hat (nur mit Quelle)

```
Rolle: externer Rechercheur für Echoel Studio, eine iPhone/iPad-Musik-Workstation in Swift, die eine eigene AUv3-Erweiterung einbettet, fremde Audio Units hostet und Plugins als einmaligen In-App-Kauf verkaufen will. Öffentliches Repo: https://github.com/vibrationalforce/Echoelmusic (Zweig claude/echoelmusic-review-optimize-u5jjpd, Verzeichnis EchoelStudio/).

Nur der Stand seit dem 10.10.2026, nur mit Quelle und Datum. Wo es nichts Neues gibt, sag das in einem Satz.
1. Neue iOS-, iPadOS- und Xcode-Versionen und Betas: Release Notes zu AVAudioEngine, AVAudioSession, Audio Units, App Groups, StoreKit, TestFlight.
2. App-Review-Regeln zu In-App-Käufen, die eine AUv3-Erweiterung freischalten: Was ist erlaubt, wenn der Kauf in der App passiert und die Erweiterung ihn über eine App Group liest? Dokumentierte Ablehnungen oder Freigaben.
3. Was iOS-DAWs und Hosts (AUM, Logic Pro für iPad, Cubasis, Loopy Pro, Drambo) zuletzt bei AUv3 geändert haben.
4. Neue Preis- oder Steuerregeln im App Store für Deutschland und die EU.

Form: höchstens 8 Punkte. Jeder Punkt: Behauptung · Link · Datum · „sicher“ oder „vermutet“ · eine Zeile, was das für Echoel Studio heißt. Keine Code-Vorschläge.
```

### Auftrag an DeepSeek (DeepThink) — Echtzeit-Sicherheit und Rechenfehler in Sampler und Drums

```
Rolle: DSP-Prüfer für Echtzeit-Audio in Swift. Du prüfst, du schreibst keinen Code.

Öffentliches Repo: https://github.com/vibrationalforce/Echoelmusic, Zweig claude/echoelmusic-review-optimize-u5jjpd, Stand b0f4e8b36.

Lies nur:
- EchoelStudio/DSP/Sources/EchoelDSP/Sampler.swift
- EchoelStudio/DSP/Sources/EchoelDSP/DrumKit.swift
- EchoelStudio/Engine/Sources/EchoelKernels/SamplerKernel.swift
- EchoelStudio/Engine/Sources/EchoelKernels/DrumKernel.swift
- die Tests dazu: EchoelStudio/DSP/Tests/EchoelDSPTests/SamplerTests.swift, DrumKitTests.swift, EchoelStudio/Engine/Tests/EchoelKernelsTests/SamplerKernelTests.swift, DrumKernelTests.swift

Fragen:
1. Läuft auf dem Audio-Thread etwas, das Speicher anlegt, sperrt, Dateien liest oder auf einen anderen Thread wartet?
2. Welche Eingaben (NaN, unendlich, 0, negative Werte, sehr kurze Samples, Tonhöhe am Rand) erzeugen Stille, einen Knack, einen Absturz oder einen Wert außerhalb des Bereichs?
3. Stimmt die Interpolation beim Abspielen in anderer Tonhöhe, und gibt es Fehler am Ende einer Schleife?
4. Welcher Fall fehlt in den Tests?

Form: höchstens 8 Punkte, jeder mit Datei:Zeile, „sicher“ oder „vermutet“, kein Code. Wenn du eine Datei nicht lesen kannst, sag das, statt zu raten.
```

**So kommen die Antworten zurück:** in den Chat einfügen; die Sitzung prüft jede Behauptung am Repo (Lernmodus) und trägt das Ergebnis ins Ledger ein.
