# Vier Aufträge für Grok Heavy — umsetzbare Lösungen für Claudes nächsten TestFlight

Stand: 26.10.2026, Europe/Madrid. Auftrag des Founders: Grok neue Arbeit geben, selbst weiterarbeiten und die professionelle Umsetzung der gesamten Vision für Claude vorbereiten.

**Arbeitsbasis:** `main` wurde auf `3f240b3d2d784379d4b645d0a83438b6da77f354` gelesen. Der zusätzliche, tatsächlich veröffentlichte G4-Codecommit ist `21a22939c0cd4f85c120bfc2d8fb89f98ebaddf3` auf `codex/studio-testflight-preparation-2026-10-26`. Diese SHAs sind Messstände, keine Anweisung, einen inzwischen neueren Stand zurückzusetzen.

**So starten:** Diesen Vorspann und genau einen Auftrag G-A bis G-D an Grok geben. Die Aufträge dürfen parallel recherchiert werden. Claude ist danach der eine Integrationsschreiber. Es gibt in dieser Übergabe keine Behauptung, Grok sei bereits gestartet oder habe Ergebnisse geliefert.

## Gemeinsamer Arbeitsvertrag

1. Lies den aktuellen HEAD und die relevanten offenen PRs selbst. Lies `EchoelStudio/CLAUDE.md`, `docs/dev/FOUNDER_PRODUCT_LAW.md` und den vollständigen `scratchpads/PLAN_ONE_POINT_ZERO_COMPLETE_2026-10-25.md`. Das jüngste datierte Founder-Wort gewinnt bei Scope-Konflikten. W0–W10 bleiben das vollständige 1.0-Ziel; alte Verbote generierter Noten oder der Medienfunktionen sind nicht wieder einzuführen.
2. **Liefere eine Lösung mit ausführbaren Referenzprüfungen.** Keine weitere allgemeine Vision, keine Prozentzahl für Fertigstellung und keine Marketingwertung. Jede Empfehlung braucht den bestehenden Besitzer, den neuen Datenvertrag, das Fehlerverhalten und eine konkrete Abnahme.
3. Arbeite ausschließlich in den drei neuen, deinem Auftrag zugewiesenen Dateien unter `scratchpads/grok_testflight_2026-10-26/`. Produktcode, vorhandene Tests, Workflows, `project.yml`, Release-Trigger und `decisions.csv` bleiben außerhalb deines Schreibbereichs. Root/ChatGPT besitzt die G4-Scheibe; Claude besitzt die anschließende Integration. Kein Merge, kein Upload, kein Issue-Schließen.
4. Ohne Checkout lieferst du die drei Dateien vollständig als Anhänge bzw. Copy-Paste-Inhalt. Behaupte dann keinen Commit. Mit Checkout: eigener Branch von frisch gelesenem Stand, ein Commit pro Paket, Diff nach Veröffentlichung zurücklesen. Nur wenn die Sitzung ausdrücklich dazu autorisiert ist, veröffentlichen.
5. Repo-Belege nennen Commit, echten Pfad und Symbol oder wörtlichen Anker. Keine Zeilennummern. `Sources/Echoelmusic` ist eine historische Referenz und kein Nachweis einer Studio-Funktion. Heutige Studio-Besitzer heißen unter anderem `Project`, `ProjectStore`, `EngineSnapshot` und `AudioEngine`.
6. Externe API-/Algorithmus-/Protokollaussagen nur gegen aktuelle Primärquellen prüfen. Dokumentiere URL, Version, Geltungsbereich und Abrufdatum. Ein SDK-Symbol oder mathematisches Paper beweist noch keine Gerätefunktion.
7. Referenzskripte laufen offline mit Python-Standardbibliothek, enthalten keine Netzwerkaufrufe, Gerätezugriffe oder Repository-Schreibaktionen und ändern keine Dateien. Einheitliche Schnittstelle: `python3 G_X_reference.py --selftest --fixtures G_X_FIXTURES.json`. Die konkreten Dateinamen stehen je Auftrag unten. Ausgabe: Anzahl ausgeführter Fälle, Fehler, übersprungene Fälle, Rückgabecode 0 nur bei vollständigem Erfolg. Fehlende/unklare Fixtures ergeben keinen Pass.
8. Erwartungswerte unabhängig herleiten. Ein Generator, der seine eigene Ausgabe als Erwartung benutzt, ist kein Gegenbeweis. Positive und negative Kontrollen, Randfälle und ein bewusst kaputter Kandidat müssen zeigen, dass die Prüfung den jeweiligen Fehler erkennt.
9. Ein Referenzskript beweist seinen modellierten Vertrag. Es ist weder Produktimplementierung noch Geräte-, Klang-, Netzwerk- oder AUv3-Abnahme. In jedem Ergebnis stehen `EXECUTED`, `NOT_RUN` und die geprüfte Umgebung getrennt.
10. Claude-Scheiben: höchstens drei Produkt-/Testdateien je Commit; keine stillen Formatänderungen, keine geänderten alten Golden-Dateien, kein malloc/Lock/ObjC/GCD/I/O im Render. Änderungen am Song gehen durch die vorhandene Befehlstür. Eine größere Funktion wird in mehrere konsistente Scheiben zerlegt.

## G-A — W1/W2: gültige Körperquellen und Modulation ohne Dokumentdrift

### Gewünschtes Ergebnis

Claude kann eine echte Quelle bis zur Anzeige und zur musikalischen Modulation anbinden. Demo, fehlender Wert und gültige Messung sind unterscheidbar. Reine Wiedergabe verändert weder Song-JSON noch Undo-Historie.

### Gemessener Ausgangspunkt

- `EchoelStudio/App/Models/BodyFrameSource.swift`: Anfangswerte 72, 0.45, 0.62 und `isActive = true`; kein Gültigkeitszustand.
- `EchoelStudio/App/Models/BodyFramePublisherAdapter.swift`: `update` kopiert die Zahlen; `pushPlaceholder` ist keine Messquelle.
- `EchoelStudio/App/Views/BodyFrameView.swift`: private Konstanten statt Source-Lektüre. Der View ist bei dieser Basis nicht in `StudioView` eingebunden. Daraus folgt nicht, dass die ausgelieferte Studio-Oberfläche schon diese Zahlen zeigt.
- `EchoelStudio/Core/Sources/EchoelCore/Project.swift`: Format 2, kein `modRoutes`-Feld.
- `EchoelStudio/App/Engine/ParameterWriter.swift`, `set(_:to:coalescingKey:)`: schreibt Dokument/Automation oder Plugin-Parameter; ungeeignet als fortlaufender Modulationsschreiber.
- `EchoelStudio/Engine/Sources/EchoelEngine/EngineSnapshot.swift`: vorhandene `PatchAutomation`-/`UnitAutomation`-Kompilierung als Integrationspunkt.
- `scratchpads/W2_MODROUTE_CONCRETE_SKETCH_2026-10-26.md`: den vorgeschlagenen Laufzeitpfad über `ParameterWriter` ausdrücklich korrigieren.

### Genau drei Lieferdateien

1. `G_A_BODY_MODULATION_CONTRACT.md`
2. `G_A_FIXTURES.json`
3. `G_A_reference.py`

### Zu lösender Vertrag

**Body-Daten:** Zustände aus, ausdrücklich markierte Demo, wartet, gültig und ungültig/veraltet. Herkunft, Kanal, Einheit, monotone Erfassungszeit und Qualität getrennt führen. Gültigkeit gilt pro Kanal: ein aktueller Puls macht einen fehlenden HRV- oder Atemwert nicht gültig. Normalisierung ist nicht mit einem Rohwert in Millisekunden zu verwechseln. Die Bedeutung eines Kohärenzindex muss definiert sein; keine Diagnose oder mentale Zustandsbehauptung.

Opt-in startet einen Produzenten. Opt-out beendet seine Arbeit und invalidiert ausstehende Callbacks. Jeder Quellenwechsel erhält eine Generation, damit ein später alter Callback die neue Quelle nicht überschreibt. Permission denied, Session-Unterbrechung und Quelle getrennt müssen beobachtbare Zustände sein. Datenalter verwendet eine monotone Uhr; ein geänderter Kalender darf keinen frischen Messwert erzeugen.

**Plattformmatrix:** Für Kamera, BLE-HRS und HealthKit/Watch je benötigte Capability/Usage Description, Besitzer, erlaubte Daten, Ablehnung, Hintergrundverhalten und Geräteprüfung angeben. In den gelesenen Studio-Dateien `project.yml`, `Support/Info.plist` und den Entitlements sind die erforderlichen Kamera-/Bluetooth-/Health-Deklarationen nicht vorhanden. Der Satz „nur Publisher anschließen“ ist daher unvollständig. Gated Änderungen als konkreten Review-Diff vorschlagen, nicht ausführen. Der Kamera-Besitzvertrag wird mit G-D abgestimmt; Produktion hat Vorrang.

**Modulation:** Trenne gespeicherte Routen von laufenden Quellwerten. Nutzeraktionen erzeugen Befehle. Die Engine erhält außerhalb des Render-Callbacks aufgelöste, begrenzte Routen und einen geeigneten Snapshot aktueller Quellen. Keine `ProjectStore.perform`-Aufrufe pro Modulationstick.

Als zu prüfender Semantikvorschlag: Basiswert/Automation bestimmen zuerst den normalisierten Ausgangswert; Routen addieren ihren durch Tiefe und Kurve definierten Beitrag; der endgültige Zielwert wird durch den vorhandenen Descriptor begrenzt und zurück in die Parametereinheit überführt. Grok muss die Semantik für logarithmische und gestufte Parameter, Override, Touch/Latch, Glättung, Summierung und mehrere Quellen ausdrücklich festlegen oder eine begründete bessere Variante liefern. Tiefe null muss identisch zum unmodulierten Pfad sein.

LFO-Phase stammt aus der definierten Song-/Sample-Zeit. MIDI-CC-Quellen enthalten Quellenidentität, Kanal und CC; G2 liefert den gemeinsamen Identitätsvertrag. Veraltete oder nicht erlaubte Quellen haben ein definiertes Rückfallverhalten. Route 33 darf nicht still verschwinden, falls 32 als Kapazität gewählt wird: diese Zahl ist zunächst ein zu begründender Vorschlag, kein gemessenes Performancebudget.

**Format 3:** explizite Migration aus Format 1 und 2; alte Golden-Daten unverändert. Neue Versionen werden verständlich abgelehnt. Unbekannte Quellen/Ziele und ungültige Routen werden weder still gelöscht noch in einen anderen Parameter umgedeutet. Die Route speichert IDs und Bedeutung, nicht Render-Slot-Indizes. Jede fehlgeschlagene Mutation erhält das letzte gültige Dokument.

**Offline-Export:** live gelesene Kamera-/BLE-Werte dürfen keinen zufälligen zweiten Render erzeugen. Liefere eine ausdrückliche Auswahl zwischen aufgezeichneten Steuerspuren, eingefrorenem Startzustand oder deaktivierten Live-Quellen und beschreibe, was der Musiker vor dem Export sieht. Biometrische Rohdaten werden nicht beiläufig in Projektpakete aufgenommen.

### Mindestabnahme

- Quellenwechsel, Opt-out, verspäteter Callback, NaN/Inf, Zeitablauf und fehlende Teilkanäle mit erwarteter Zustandsfolge.
- Tiefe null; positive/negative Tiefe; Kollision zweier Routen; Automation plus Modulation; gestufter und logarithmischer Zielparameter.
- Blockgrößen 64, 256 und 1024 über dieselbe Sample-Zeit, mit begründeter Toleranz und identischem Startzustand.
- Kein Anwachsen des Undo-Verlaufs und unverändertes kanonisches JSON bei reiner Wiedergabe.
- Kapazitätsüberschreitung, ungültige IDs und nicht-endliche Parameter: verständlicher Fehler, Dokument unverändert.
- Zwei Offline-Renders mit demselben Dokument, Startzustand und einmal festgelegten aufgezeichneten/eingefrorenen Quellenzustand liefern dieselbe Referenzentwicklung, auch wenn irrelevante Live-Eingänge wechseln. Ein ausdrücklich neu aufgenommener Freeze darf neue Werte enthalten und wird gesondert benannt.

**Erste Claude-Scheiben:** reiner Body-Zustand + Verhaltenstests; Source/Adapter-Lifecycle; Anzeige; eine echte Quelle; ModRoute-Typ/Semantik; Migration; Befehle; Compile-Pfad; Render-Pfad; UI. Für jede Scheibe konkrete Dateinamen und Abnahme angeben. W1/W2 zusammen passen nicht in drei Dateien.

## G-B — W3/W4: Bild, Licht und Raum mit einer Zeitbasis und kontrolliertem Ausgang

### Gewünschtes Ergebnis

Ein Song steuert Visuals und ausdrücklich aktivierte Ausgänge. Es gibt eine Transportwahrheit, sichtbare Ziele und nachvollziehbare Datenfreigaben.

### Ausgangspunkt und Grenzen

Lies Studio `EngineSnapshot`, `EngineCore`, `TempoMap`, `TimeConversion` und `App/Navigation/StudioRouter.swift`. Die Legacy-Typen `MetalBioView`, `ArtNetSender`, `OSCSender`, `ADMOSCSender`, `SpatialSceneOSC` und `BioEgressPolicy` sind Referenzen. Suche ihre aktuellen Pfade, bevor du sie zitierst. Studio besitzt bisher Network MIDI und MIDI-Clock, jedoch nicht das vollständige geplante Verbindungsmodul.

F25 in `docs/dev/FOUNDER_INBOX.md` betrifft konkret die Workflow-Allowlist für `EchoelStudio/App/Connections/ConnectionsOutput.swift`. Das ist eine Integrationsabhängigkeit für W4 und keine Sperre für reine Encoder, W1, W2 oder Referenztests.

### Genau drei Lieferdateien

1. `G_B_VISUAL_CONNECTIONS_CONTRACT.md`
2. `G_B_FIXTURES.json`
3. `G_B_reference.py`

### Zu lösender Vertrag

Ein kompakter Visual-Snapshot enthält Songzeit, Takt-/Tempobezug, Pegel und optional gültige freigegebene Modulationswerte. Renderer, Fenster und Ausgänge konsumieren ihn. Das Zeichnen erzeugt keine zweite Songuhr. Definiere Resampling, Auslassen veralteter Frames, Pause, Hintergrund, externe Displays, Wiederaufnahme und Ressourcenfreigabe.

Die Visual-Fläche muss ohne Bio funktionieren und musikalische Struktur zeigen. Lege eine kleine erste Visual-Familie mit kontrollierbaren Parametern fest, statt den gesamten alten View zu kopieren. Farbe allein trägt keinen Betriebszustand. Reduce Motion, Dynamic Type und die Bedienung mit VoiceOver gelten für die Bedienelemente. Die Blitzgrenze wird anhand einer definierten Helligkeits-/Kontrastfolge geprüft; eine Konstante namens 3 Hz reicht nicht.

Verbindungen beginnen ausgeschaltet. Adresse, Port, Protokoll und aktuelle Aktivität sind sichtbar. Aus einem eingeschalteten Lichtziel folgt keine Freigabe roher Bio-Daten. Definiere getrennt direkte Körperwerte, abgeleitete musikalische Steuersignale und reine Songdaten sowie die jeweils nötige Freigabe. Opt-out, Berechtigungsentzug und Quellenverlust wirken auch auf bereits gefüllte Ausgangspuffer.

Erzeuge bytegenaue Referenzvektoren für die tatsächlich vorgeschlagenen Art-Net-/sACN-/OSC-/ADM-OSC-Nachrichten. Benenne Spezifikationsversion, Adressraum, Byte-Reihenfolge, Padding, Paketlänge, Sequence-Wrap, Universe-/Objektgrenzen und Fehlerfälle. Ein unabhängiger Decoder bzw. ein nachvollziehbar handberechneter Vektor ist die Gegenprobe.

Netzwerk läuft außerhalb des Audio-Callbacks. Übergabepuffer, begrenzte Queue, Drop-/Coalescing-Regel und Reconnect werden explizit. Rückstau darf keinen alten Cue-Sturm auslösen. ADM-OSC steuert Raumobjekte; es ist kein Atmos-Renderer. Mehrkanal-Audio und räumliche Metadaten erhalten getrennte Abnahmen.

Netzwerk-Audio, Internet-Audio, gemeinsames Editieren und ein neuer Master-Clock-Vertrag bleiben eigene spätere Integrationen. Keine Dante-, NDI-, PTP-, Link- oder WebRTC-Kompatibilität aus selbst gebauten ähnlich benannten Komponenten ableiten.

### Mindestabnahme

- Ausgeschaltet: kein zu sendendes Datagramm; deaktiviertes Ziel leert/entwertet pending Arbeit.
- Kein Bio-Opt-in: verbotene Felder fehlen auch bei Reconnect, Fehlerdiagnose und Replay.
- Paket-Golden-Vektoren an Nullwert, Grenzwert, Wrap und ungültigem Wert; positive und negative Decoderkontrolle.
- Eine Transportänderung erzeugt keine zweite unabhängige Zeitbasis; Restart verwirft alte Generationen.
- Messbare Sequenzen für Helligkeit/Flash sowie definierte reduzierte Bewegung.
- Erste Netzstreckenprüfung auf realem Empfänger ausdrücklich `NOT_RUN`, bis Ziel, Version und Trace vorliegen.

**Erste Claude-Scheiben:** Snapshot/Tests; erste Visual-Fläche; Fenster-Lifecycle; Protokollencoder/Tests; Egress-Policy/Tests; benannter Verbindungsbesitzer nach F25; sichtbare Bedienung; echte Empfängerprüfung.

## G-C — W5/W8: DDSP, Granular, Harmonizer, Tonhöhenkorrektur und MPE Out

### Gewünschtes Ergebnis

Claude bekommt begrenzte, reproduzierbar prüfbare Klangprozessoren und ihre Einbaupunkte in den bestehenden Instrument-/Effektpfad. Jede Rückgewinnung begründet, welcher historische Kern tatsächlich brauchbar ist.

### Ausgangspunkt

`EchoelStudio/DSP/Sources/EchoelDSP/`, `EchoelStudio/Engine/Sources/EchoelKernels/`, `InstrumentDevice`, `InstrumentParameter` und die bestehenden Hosted-Processing-Protokolle. In `docs/dev/HISTORY_ARCHIVE.md` A1 und B4–B6 lesen; Legacy-`EchoelDDSP.swift`, `GrainCloud.swift`, `PitchTracker.swift` und `MIDIOutput.swift` jeweils erst lokalisieren. DDSP ist bei dieser Basis noch kein Studio-Gerät. MIDI-Clock-Ausgang ist kein MPE-Notenausgang.

### Genau drei Lieferdateien

1. `G_C_SOUND_RECOVERY_CONTRACT.md`
2. `G_C_FIXTURES.json`
3. `G_C_reference.py`

### Zu lösender Vertrag

Für jeden Prozessor eine Tabelle: Bedarf, historischer Nachweis, wiederverwendbarer Kern, verworfene alte Besitzer, neuer Studio-Besitzer, vorbereiteter Speicher, Renderfunktion, Parameter, Reset, Live-/Offline-Unterschiede. Keine neue Extension oder Umwidmung des für alte Sessions erhaltenen Subtyps `echl`.

DDSP als viertes eingebautes Instrument vorbereiten. Die bestehenden Parameter-/Preset-Tabellen, InstrumentKernel-Protokolle und die heutige Dokumentrepräsentation nutzen. Den Namen DDSP nicht als Beleg für ein trainiertes neuronales Modell verwenden; nur die tatsächlich vorhandene Synthesemethode beschreiben.

Granular: fester Grain-/Stimmenpool, reproduzierbarer Seed, definierter Stimmenraub, Samplegrenzen, Loops, Rate-Wechsel, Reset und dokumentierte Lautstärkenormalisierung. Kein ungebremstes Summieren oder Wachstum im Render.

Pitch-Tracking und Korrektur: definierter Musikrahmen, nicht stimmhaftes/unsicheres Signal, Attack/Release, Notenwechsel, Latenz und Formantverhalten. „Tonhöhe korrigiert“ verlangt eine Referenzabweichung und einen Hörvergleich, nicht nur ein Parameterfeld. Harmonizer verwendet erst einen geprüften Pitch-Pfad; Intervallnamen sind Benutzersteuerung und kein Qualitätsbeweis.

Live und Clip-Offline verwenden dieselbe musikalische Semantik. Lookahead, Tail, Bypass und Latenzkompensation werden explizit. CPU- und Latenzbudgets sind Messziele, keine erreichten Zahlen.

MPE **Out** getrennt lösen: Zonen-/Member-Zuordnung, Pitch-Bend-Range, Stimmenidentität, Note-On/Off-Reihenfolge, Kanalwiederverwendung, All-Notes-Off und Disconnect. Die bekannten G2/G3-Reparaturen sind Voraussetzungen für verlässliche Identität; sie werden nicht nebenbei neu implementiert. MPE Out beweist weder MPE In noch UMP-Typ 4.

### Mindestabnahme

Referenzen für Stille, Impuls, Sinus, Zweiton, Geräusch, Sample-Sprung, extreme endliche Parameter und verschiedene Blockgrößen. Toleranzen aus Referenz und Algorithmus herleiten. Prüfen: endliche Ausgabe, begrenzte Amplitude, Reset ohne gehaltene Stimmen, deterministischer Offline-Render, korrektes Zeit-/Frequenzverhalten und kontrollierte Parameterwechsel.

Für MPE: zwei Noten unabhängig biegen/drücken, eine freigeben, andere bleibt; Voice-Steal und Wiederverbindung geben keine falsche Stimme frei. Golden-Ereignisfolgen prüfen Kanal und Reihenfolge. Den realen Seaboard-/Empfängertest separat offen lassen.

Das Referenzskript muss mindestens einen gewählten DSP-Vertrag und die MPE-Ereigniszustandsmaschine ausführbar gegen unabhängig hergeleitete Fixtures prüfen. Fehlende professionelle DSP-Teilalgorithmen im Ergebnis ausdrücklich markieren, nicht mit Sinus-Platzhaltern als fertig darstellen.

**Erste Claude-Scheiben:** je Algorithmus reiner Kern + Tests; Kerneladapter + Tests; Parameter-/Preset-Anbindung; Bedienung; Live-/Offline-Abnahme. Klangqualität zusätzlich mit pegelangepasstem A/B-Hörvergleich beurteilen.

## G-D — W7/W9/W10 und Design: Medienbesitz, Videozeit und editierbare Assistenz

### Gewünschtes Ergebnis

Video, Gesicht/Bewegung und Assistenz ordnen sich in eine professionelle Produktionsoberfläche ein. Aufnahme und Transport bleiben bedienbar, Modellantworten ändern keine falschen Ziele und alle Ergebnisse bleiben editierbar.

### Ausgangspunkt

Studio `Project`, `ProjectStore`, `ProjectCodec`, `Command`, `CommandCatalog`, `App/Documents/DocumentController.swift`, `AudioEngine`, `RecordController`, `StudioRouter`, `App/Agent/AgentSession.swift` und `Core/Sources/EchoelCore/AgentTools.swift` lesen. Die Assistenz besitzt bereits eine Menü-Tür bei `agent.isOffered`, eine Verfügbarkeitsprüfung, `AgentExecutor.run` und einen `documentGeneration`-Schutz. Diese Teile erhalten.

Archiv F1/F3 und I4/I5 prüfen. Der alte Video-Recorder ist kein erwiesen brauchbarer Kern: Archiv und Produktgesetz dokumentieren „hat leider nicht geklappt“. AVFoundation/VideoToolbox übernehmen Codec/Container; keine alte Subsystemkopie.

### Genau drei Lieferdateien

1. `G_D_MEDIA_AGENT_DESIGN_CONTRACT.md`
2. `G_D_FIXTURES.json`
3. `G_D_reference.py`

### Zu lösender Vertrag

**Kamera:** ein Besitzer für Produktionsvideo, rPPG und Gesicht. Produktion hat Vorrang. Definiere Anforderung, Zuteilung, Freigabe, Unterbrechung, Ablehnung und Wiederaufnahme. Wenn Quellen nicht gleichzeitig möglich sind, wird die nachrangige Quelle sichtbar pausiert. Front-/Rückkamera-Gleichzeitigkeit braucht Gerätebeleg. G-A konsumiert diesen Vertrag und erfindet keinen zweiten Kamera-Manager.

**Video:** nichtdestruktive Clips/Referenzen im Song, Undo, Paketmedien und Migration. Song-/Sample-Zeit wird in Präsentationszeit übersetzt. Definiere Startversatz, Taktschnitt bei Tempoänderung, variable Framerate, verlorene Frames, Audio-Interruption, Stopp, Tail und abgebrochenen Export. Ein erfolgreicher Dateischreibvorgang allein ist kein Synchronitätsbeleg.

**Gesicht/Bewegung:** lokale, begrenzte kreative Steuersignale mit Herkunft, Gültigkeit und Opt-in. Keine Gefühls-, Diagnose- oder Bewusstseinsinferenz. Start/Stop und Kameraübergabe erzeugen eine neue Generation; alte Samples erreichen W2 nicht mehr.

**Assistenz:** Die vorhandene Befehlstür, der vorhandene Songwechsel-Schutz und ein Undo pro Request bleiben. Ergänze ein konkretes Konzept für Änderungen am selben Song während einer Modellantwort: stabile Ziel-IDs statt später erneut interpretierter Spurpositionen, validierter relevanter Ausgangszustand, entfernte Ziele, umgeordnete Spuren und gleichzeitige MIDI-/Touch-Änderung. Ein abgebrochener Turn darf keine weiteren Tools ausführen. Bereits angewandte Teilaktionen werden klar benannt und rückgängig gemacht; die gewählte Teilresultat-Policy wird getestet.

Musikalischer Rahmen muss im Modellkontext und in der Validierung ankommen. Ein Modelltext „Done“ ist kein Ergebnis; erfolgreiche Befehlsübernahme ist der Beleg. W10 verwendet in diesem Auftrag ausschließlich die vorhandene On-device-Modellgrenze. Ohne verfügbares Modell bleibt die manuelle Workstation nutzbar. Ein Cloudfallback gehört nicht zu diesem Paket.

Die beiden weiteren expliziten W10-Fähigkeiten ebenfalls lösen: **Klang aus einem Satz** übersetzt eine Klangbeschreibung in eine überprüfbare, editierbare Entscheidung innerhalb der vorhandenen Instrument-/Parameter-/Effektstruktur. Unterscheide bloße Preset-Auswahl von tatsächlichen Parameteränderungen; ein Modelltext allein erzeugt keinen neuen Klang. **Arrangement-Vorschläge** liefern editierbare Clip-/Zeit-/Track-Operationen mit stabilen IDs, gültigen Befehlen, Konfliktregel und Undo. Keine vorhandene Komposition ohne entsprechende Nutzerhandlung überschreiben. Für beide Fähigkeiten konkrete Beispielanfragen, resultierende Befehle und ablehnbare Gegenbeispiele liefern.

**Design:** Liefere konkrete Zustände und Aktionen für iPhone, iPad, große Schrift und VoiceOver, auf den vorhandenen Seiten Tracks/Arrange/Session/Mixer und dem bestehenden Präsentationsslot. Keine neue Dashboard-Hülle. Prüfe besonders: wartenden Clip-Start abbrechen; sichtbares MIDI-Aufnahmeziel; VoiceOver-Automationsbearbeitung; Mixer ohne unzugängliche feste Breiten; gewählten/fehlenden Audioeingang verständlich zeigen; laufenden Transport trotz Scrollen erreichen. Vorher aktuellen Code gegen diese älteren Designbefunde prüfen, statt sie als unbehobene Fehler vorauszusetzen.

### Mindestabnahme

- Kamera-Übergaben, Permission denied, Hintergrund/Unterbrechung und alte Callbacks als Zustandsfolgen.
- A/V-Referenz mit bekannten Impuls-/Bildmarken: Startversatz und Drift berechenbar; reales Gerät bleibt zusätzlicher Test.
- Schnitt/Undo/Neuladen/Export reproduzierbar; Quelldatei unverändert.
- Alter Modellturn erreicht weder anderen Song noch umnummerierte oder entfernte Ziele.
- Abbruch, Toolfehler und Teilergebnis erzeugen den definierten Zustand und ein überprüfbares Undo.
- Klangbeschreibung führt zu den belegten editierbaren Preset-/Parameteränderungen; Undo, Neuladen und Export erhalten das erwartete Ergebnis.
- Arrangement-Vorschlag benutzt stabile Track-/Clip-IDs, bleibt editierbar und hat einen reproduzierbaren Undo-/Redo-Weg; ein inzwischen geändertes Ziel wird nicht still überschrieben.
- Jede zentrale Aktion mit VoiceOver erreichbar; Aufnahme- und Fehlerzustand nicht ausschließlich farblich dargestellt.
- Referenzskript prüft Kamera-Zustandsmaschine, Zeitumrechnung und Zielidentität. Keine Behauptung, dadurch sei AVFoundation oder das Sprachmodell ausgeführt worden.

**Erste Claude-Scheiben:** reine Zeit-/Kamera-Policy + Tests; Medienmodell/Migration; Befehle/Undo; Capture; Export; Gesicht-/Bewegungsquelle; Assistenz-Lifecycle/ID-Tests; UI jeweils getrennt.

## Gemeinsame Rückgabe an Claude

Jedes Paket endet mit: gelesener SHA, konkrete drei Dateien, ausgeführte Befehle und Resultate, noch ungeprüfte Fälle, erste drei implementierbare Claude-Scheiben mit höchstens drei Dateien je Scheibe und Abhängigkeiten zu den anderen Paketen. Konflikte werden benannt und mit einer empfohlenen Lösung versehen; kein stilles Vermischen unterschiedlicher Annahmen.

Die gemeinsame Engineering-Abnahme steht in `scratchpads/TESTFLIGHT_ACCEPTANCE_2026-10-26.json`; der Integrations- und Releaseablauf in `scratchpads/CLAUDE_TESTFLIGHT_HANDOVER_2026-10-26.md`. Diese Dateien sind Vorbereitung, keine Geräteabnahme. W6 (Kaufprodukt, Verträge, Preis, Store-Texte und Einreichen) gehört in Claudes Release-Checkliste und die bestehenden Founder-Einträge; Grok trifft keine kommerziellen Entscheidungen.
