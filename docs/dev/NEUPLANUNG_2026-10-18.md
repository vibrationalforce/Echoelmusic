# Echoel: Neuplanung (2026-10-18)

> **Zeitachse und Einstieg seit 2026-10-19: `docs/dev/ECHOEL_VISION_2026-10-19.md`** (§8 Jahre, §11 Entscheidungen). Ableton Link bleibt draußen, bis der Founder es bestellt; ein Kongress-Vortrag nennt den CCC in keiner Kopie (E28).

> Status: **FREIGEGEBEN (Founder 2026-10-18: „OK du entscheidest alles super“).** Die Fragen in §8 sind nach den Empfehlungen entschieden. Entstanden aus drei Bestandsaufnahmen (EchoelStudio, Alt-App, Vertrauens-Audit), zwei Web-Recherchen (Markt, CCC) und drei unabhängigen Entwürfen (Kreativität · Offenheit · Markt), adversarial zusammengeführt. Nichts davon ist gebaut, was nicht schon im Repo steht.

## 0. Entscheidung in fünf Sätzen

1. Echoel wird nicht noch einmal neu geschrieben. Es wird **EchoelStudio** (`EchoelStudio/`) geordnet, weil sein Kern belegt trägt: eine Befehlstür, Snapshot-Übergabe, deterministisches JSON, `ParameterAddress` und null Abhängigkeiten.
2. Es gibt **keine Genres und keine generierten Noten**. Kreativität führen stattdessen drei Dinge: musikalische Rahmen, die der Nutzer selbst setzt (Tonart, Stimmung, Tempo, Takt, Swing), Klang-Presets, die zu einem Instrument gehören, und neutrale Startprojekte, die nichts festnageln.
3. Vor 1.0 kommt genau eine Aufräumphase (P0). Sie behebt nur, was bei der Veröffentlichung einfriert: den doppelten Instrumentenpfad, die dreifache Parameterliste, die uneinheitlichen Befehlsnamen und die Engine-Last in der AUv3-Extension.
4. Vertrauen kommt aus der Struktur, nicht aus Werbetext. Netzwerk gibt es nur in einem Modul, und es ist überall ausgeschaltet, bis man es einschaltet. Dazu kommen ein offenes, dokumentiertes Projektformat, voller Export, kein Konto, keine Telemetrie und ein ehrlicher Demo-Modus.
5. Körper, Visual, Licht und Raum sind verschoben, nicht gestrichen. Sie docken nach 1.0 als Quellen und Ziele an dieselben Adressen an, nie als eigener Bus.

**Warum keiner der drei Entwürfe unverändert übernommen wird:**

- **„Kreativ"**
  - Er legt drei neue Pakete an. Das ist viel Umbau für einen Solo-Founder, der nur über CI bauen kann.
  - Seine Noten-Devices (Euclid-Spur, Variationsgenerator) sind ein Komponist durch die Hintertür und widersprechen „keine generierten Noten".
  - Seine fest benannten Makros (energy, tension) bringen die `MoodProfile`-Bedeutungen zurück, also genau das Genre-Denken, nur kleiner.
- **„Offen"**
  - Er baut Plattform vor Musik: macOS-CLI, JSON-Schema-Export, OSC-Befehlsraum, URL-Schema und App Intents vor dem ersten Store-Release.
  - Damit wiederholt er das Phasen-Schleudern der Legacy-App.
  - `EchoelFormat` aus Core herauszulösen ist Umbau ohne Nutzerwert.
- **„Markt"**
  - Er lässt `EchoelKernels` von Core abhängen. Heute ist DSP Core-frei, und das sollte so bleiben.
  - Er verspricht „nie ein Abo", obwohl die dokumentierte Founder-Entscheidung (v1.1 „Echoel Live" als Jahres-Abo) noch steht.
  - Er will `Tests/CISmoke` nach 1.0 löschen, ohne dass die Lehren daraus gesichert sind.
  - Seine 1.0-Bedingung „vier Hosts gerätegeprüft" ist richtig, aber teuer. Sie gehört in die Plugin-Phase, nicht ins Kompositions-Release.
- **Alle drei**
  - Sie planen Import-Scans als CI-Workflow-Änderung. Für EchoelStudio sind Workflows seit 2026-10-17 freigegeben, aber ein Test ist billiger und läuft auch auf dem Mac. ⛔ Korrigiert 2026-10-22 (S-26 D4): ein Test, der Quelltext liest, verstößt gegen Gesetz 8 in `EchoelStudio/CLAUDE.md`; die Grenze ist der Build (Linux ohne `EchoelHost`) plus ein CI-Schritt im Studio-Gate.
  - Dieselbe Regel lässt sich als gewöhnlicher Test in `EchoelStudio/*/Tests` erzwingen. Außerdem erzwingt SwiftPM die Grenzen zwischen Modulen ohnehin über die Target-Abhängigkeiten.

## 1. Produkt: was Echoel ist und was nicht

**Echoel ist** eine professionelle Musik-Workstation für iPhone und iPad, offline und ohne Konto. Man komponiert und arrangiert mit eigenem Synth, Drums und Sampler, hostet beliebige AUv3, spielt live mit Hardware (Xone:96, Controller) und exportiert alles in offene Formate. Die eigenen Instrumente laufen per AUv3 auch in anderen Hosts. Ein On-Device-Agent bedient jede Funktion über denselben Befehlskatalog wie die Oberfläche (`App/Agent/AgentSession.swift`, FoundationModels, nichts verlässt das Gerät).

**Langfristig** (Founder Product Law, `docs/dev/FOUNDER_PRODUCT_LAW.md`) wird daraus die Steuerzentrale für Installationen und Bühne: Licht (Art-Net/sACN), Raum (ADM-OSC), Visual und Körper als Modulationsquelle.

**Echoel ist nicht:**
- eine Wellness-, Meditations- oder Therapie-App;
- ein „Mach-einen-Hit-im-Stil-X"-Generator;
- ein Cloud-Dienst;
- ein Nachbau von Spezialinfrastruktur (Codecs, Dante, NDI, RTMP, Plugin-SDKs).

**Warum keine Genres.** In der Legacy-App besaß das Genre jede Achse zugleich: Tempo, Skala, Harmonie, Rhythmus, Klang und Mix (`Sources/Echoelmusic/Sequencer/MusicStyle.swift`, 58 Fälle, 41 angeboten). Jedes neue Genre kostete Patches, FX, Unterscheidbarkeits-Wächter und eine eigene Hörprobe des Founders. Die Tempo-Oktavfaltung produzierte nachweislich Fehler: ein schneller Körper machte die Musik langsamer (`DSP/StudioCalculator.genreTempo`, #1271). Der Founder sagt selbst, dass das die Kreativität lähmt, und NEUSTART legt fest: „Keine Genres, keine generierten Noten".

**Was die drei nützlichen Aufgaben der Genres jetzt übernimmt:**

| Aufgabe des Genres | Ersatz, den der Nutzer kontrolliert |
|---|---|
| Kohärenz (alles in Tonart, Tempo und Klang stimmig) | **`MusicalContext`** im Projekt: Tonart, Skala/Stimmung (`TuningSystem`, aus Legacy portiert, in Studio gibt es noch kein Stimmungsmodell — geprüft), Takt, Tempo mit Lock und Swing als Zahl. Jedes Feld ist eine `ParameterAddress`, also automatisierbar, per MIDI-Learn erreichbar und vom Agenten steuerbar. Skalen-Lock wirkt nur auf das, was gespielt wird (Tastatur und Pads), und erzeugt keine Noten. |
| Klangidentität | **Presets gehören dem Instrument** (Patch plus Effektkette), nicht einem Stil. |
| Schneller Start mit einem Tap | **Startprojekte**, benannt nach Aufbau statt nach Stil: „Leer", „Skizze: Synth + Drums", „Sampler-Chop", „Live-Set: 8 Szenen". Es sind gewöhnliche `.echoel`-Dateien, nichts darin ist fixiert. |

Benutzerdefinierte Makros ohne vorgegebene Bedeutung kommen mit der Modulationsphase (P5).

**Annahme:** Ohne Genres droht ein leeres Blatt. Ob Startprojekte und Presets das auffangen, zeigt nur eine Geräte-Session.

## 2. Prinzipien (je überprüfbar)

**Kreativität**
1. Nichts komponiert ungefragt. Jede Note im Projekt stammt aus Spiel, Eingabe oder Import. Prüfbar per Test: kein Befehl erzeugt Noten ohne explizite Noten-Payload.
2. Jeder musikalische Rahmen ist eine `ParameterAddress`. Prüfbar per Test: jedes Feld von `MusicalContext` ist im `CommandCatalog` adressierbar.
3. Kein Preset und kein Startprojekt sperrt ein Feld. Jeder Wert bleibt danach editierbar.
4. Vom Tap bis zum Ton höchstens 3 s, gemessen auf dem Gerät (Geräte-Check, kein CI-Test).

**Offenheit**
1. Das Projektformat ist dokumentiert (`docs/FORMAT.md`). Ein Golden-File-Test liest jede Beispieldatei aus dem Repo.
2. Alles Erstellte ist exportierbar: Mix-WAV, Stems, MIDI und das Projektpaket.
3. Nur offene Protokolle: AUv3, MIDI 1.0/2.0, OSC, Art-Net, sACN, ADM-OSC. Kein proprietäres SDK.
4. Befehlsnamen sind ab 1.0 eingefroren. Entfernen geht nur über Deprecation, umbenannt wird nie.

**Vertrauen**
1. `import Network`/`URLSession` gibt es nur im Modul `EchoelIO` (ab P4). Ein Test scannt die Quellen und schlägt sonst fehl.
2. Keine Analytics-, Crash- oder Werbe-SDKs. Das Privacy-Label lautet „Data Not Collected" (`Support/App/PrivacyInfo.xcprivacy` sagt das heute schon).
3. Jede Verbindung ist standardmäßig aus und in einer Liste „Verbindungen" sichtbar und abschaltbar.
4. Bio-Werte verlassen das Gerät nie ohne Opt-in pro Ziel. Die Egress-Policy ist fail-closed (Vorbild `Sources/Echoelmusic/Core/BioEgressPolicy.swift`).
5. Nach außen wird nur behauptet, was ausgeliefert ist. Store-Text wird gegen `docs/dev/FEATURE_STATUS.md` geprüft.

**Profi-Qualität**
1. Render-Thread: keine Locks, keine Allokation, kein ObjC, kein I/O, kein GCD.
2. Eine Tür für jede Dokumentänderung (`ProjectStore.perform`). Ein Batch ist alles oder nichts.
3. Ein `.sheet(item:)`-Enum. Heißer Zustand wird nur in Blatt-Views gelesen.
4. Feste Kapazitäten (32 Slots, 64 Spuren, 8 Returns; `EngineCore.swift:27,115`) melden sich als Validierungsfehler statt Spuren still zu verwerfen (`limited(toSlots:)`).
5. Jedes eigene AUv3 besteht `auval` und eine Geräteprüfung in mindestens zwei Hosts, bevor es verkauft wird.

## 3. Architektur

### Schichten und Module

Bewusst nur **eine** neue Target-Gruppe vor 1.0, alle im bestehenden `EchoelStudio/Engine`-Paket. Kein neues Top-Level-Verzeichnis.

| Modul | Aufgabe | darf importieren |
|---|---|---|
| **EchoelDSP** (bleibt) | Reine Prozessoren: Oszillator, Filter, Hüllkurve, PolySynth, DrumKit, Sampler, EQ, Kompressor, Delay, Reverb, Loudness | Foundation (Accelerate nur hinter `canImport`) |
| **EchoelCore** (bleibt, erweitert) | `Project`, `Command`, `CommandCatalog`, `ProjectStore`/Undo, Codec, Validierung, `ParameterAddress`, `TempoMap`, `PlaybackPlan`, **neu:** `MusicalContext`, `TuningSystem`, `DeviceRef`, die Parametertabelle je eingebautem Gerät | Foundation, Observation |
| **EchoelKernels** (neu, Target im Engine-Paket) | `InstrumentKernel`/`EffectKernel` plus Synth-, Drum-, Sampler- und vier Effekt-Kernels. Die Indizes werden aus der Core-Tabelle abgeleitet. **Einziger Weg zur DSP.** | DSP, Core (nur Werttypen der Tabelle) |
| **EchoelEngine** (verschlankt) | Render-Schleife, Snapshot-Übergabe, Sequencer, Mixer, Meter, Ringe. **Neu:** `EngineTap` als Lese-Ring (Playhead, Beat-Phase, Pegel) | Core, Kernels, Synchronization. **Kein AVFoundation, kein `AUAudioUnit`.** |
| **EchoelHost** (neu, Target im Engine-Paket) | `HostedUnit`, `HostedEffect`, `StandardEffectUnit`, `SampleFile` | Kernels, Core, AVFoundation, AudioToolbox. **Nicht Engine** (seit 2026-10-22, S-26 D1.3): die Engine spielt eine geladene Unit über `HostedInstrument`/`HostedProcessor` aus den Kernels, also braucht die Hülle keinen Engine-Typ, und die Erweiterung kann Kerne plus Hülle ohne Engine linken |
| **App** | SwiftUI, Controller, Dokumente, Store, Agent, MIDI-Eingang | alles oben, StoreKit, FoundationModels, CoreMIDI |
| **AUv3-Extension** | Eigene Instrumente und Effekte, Lizenzprüfung | Kernels, Host, DSP, Core-Werttypen, AudioToolbox. **Nicht Engine** (umgesetzt 2026-10-22, S-26 D1.4: kein `import EchoelEngine` in `Plugins/`, das Produkt ist nicht gelinkt) |
| *ab P4* **EchoelIO** | OSC ein/aus, Art-Net, sACN, ADM-OSC, Network-MIDI-Policy | Foundation, `EchoelSense` (nur die Ausgaberegel als Werttyp), Network je `canImport`. **Nicht Core, nicht Engine** (seit 2026-10-19): die Bindung an `EngineTap` ist eine dünne Brücke in der App |
| *ab P6* **EchoelSense** | Puls- und Atemschätzer, HRV-Kohärenz, Ausgaberegel, BLE-Herzgurt; Kamera-Puls (rPPG) bleibt in der App. Ausgabe als eigene Werttypen; die App-Brücke bildet sie auf `ModSource` ab | Foundation; AVFoundation, CoreBluetooth je `canImport`. **Nie IO, nie Core** (seit 2026-10-19). |

⭐ **Warum EchoelIO und EchoelSense seit 2026-10-19 nicht an Core und Engine hängen:** sie sind das Förderobjekt des Prototype-Fund-Antrags (`docs/dev/FOERDERUNG_PROTOTYPE_FUND_2026.md` §7.5), und der verspricht zwei Pakete, „die jede Anwendung nutzen kann“. Hingen sie an Core, zöge eine Licht-App das Dokumentmodell der Workstation mit. Die Kopplung an `EngineTap` und `ModSource` sitzt deshalb in einer dünnen Brücke der App; die Pakete kennen die Workstation nicht.

**Abhängigkeitsregeln:**
- Abhängigkeiten zeigen nur nach unten; SwiftPM-Targets erzwingen das.
- Systemframeworks prüft kein Test (Gesetz 8: Tests lesen keinen Quelltext), sondern der Build und ein CI-Schritt (seit 2026-10-22, S-26 D4): auf Linux ist `EchoelHost` nicht deklariert, also scheitert dort jeder Kern- oder Engine-Code, der ein Apple-Framework oder die Hülle importiert (`studio-linux.yml`, misst); im Studio-Gate vergleicht „Imports only where named“ die Importe jeder Bibliothek mit ihrer Zeile, und „Extension carries no engine code“ liest die gelinkte Erweiterung (`studio.yml`, blockiert).
- DSP bleibt Core-frei. Das ist heute schon so und wird nicht aufgegeben.

### Dokumentmodell

Was bleibt: `formatVersion`, neuere Dateien werden abgelehnt, Wachstum über `decodeIfPresent`, das `.echoel`-Paket, `Media.isSafePath`, Validierung an der Tür und beim Decode.

**Vor 1.0 ändern** (danach friert es ein):
- `InstrumentDevice` (geschlossenes Enum) wird zu **`DeviceRef`**: entweder `.builtin(id, version)` oder `.audioUnit(type, subtype, manufacturer)`.
  - Jedes Gerät bekommt `params: [ParamID: Double]`, validiert gegen seine Tabelle.
  - Damit bekommen Drums und Sampler endlich Dokumentparameter (Schuld 3, `SamplerKernel.swift:23-31`).
  - ⭐ **Entschieden 2026-10-23: kein eigener Typ `DeviceRef` — das Format trägt ihn schon.** Ein eingebautes Gerät steht als Name in `device` (ein unbekannter Name bleibt wörtlich erhalten), ein Audio Unit als `plugin` mit den drei Codes (`docs/FORMAT.md` „Instrument“, „Plugin component“). Die Werte jedes Geräts stehen in `values`, werden an der Tür gegen dessen Tabelle geprüft und beim Gerätewechsel behalten (P1 A5a). Ein einzelner Wert `.builtin | .audioUnit` wäre ein Rückschritt: das getrennte `plugin`-Feld hält das gewählte Plugin, während die Spur ein eingebautes Gerät spielt, und der Wechsel zurück stellt es wieder her. **Aufgeschoben ist nur `version`:** sie kommt als zusätzliches Feld mit Formatwechsel, wenn zum ersten Mal eine DSP-Änderung alte Songs nicht verändern darf (Fehlerkorrekturen wie Klickschutz fallen nicht darunter).
- `Project.context: MusicalContext` (siehe §1).
- `ParameterAddress.Owner` bekommt `.device(track, slot)` und `.send(track, slot)`.
  - Ein `ModSource`-Typ wird **reserviert** (leer in 1.0), damit Bio, LFO und OSC-Eingang später ohne Formatbruch andocken.
- Clips bleiben `notes` + `controls`. Allgemeine Event-Spuren (Cue, OSC, DMX, Raumobjekt) kommen erst mit P4 als neue Spurart, über eine `formatVersion`-Migration statt durch Vorab-Spekulation.
- Die Migration v1 → v2 läuft über eine Kette im Codec mit Golden-Files pro Version.

### Befehlskatalog

59 Fälle (`Core/Sources/EchoelCore/Command.swift`). Vor 1.0 werden die Namen **einmal** geordnet, danach sind sie eingefroren:
- `mixer.input`/`mixer.output` statt `track.input` neben `mixer.output`;
- `tempo.*` (inklusive `project.tempo`);
- `clip.notes.*`, `clip.controls.*`;
- **eine** `insert.*`-Familie mit Ziel, so wie `MixerTarget` es für Lautstärke und Pan schon tut. Aus 10 Befehlen werden etwa 5.

Jeder Befehl trägt ein `since`. Der Katalog bleibt die eine Quelle für UI, MIDI-Learn und das Agent-Schema. `AgentTools.swift:10` (`"drums"` als Spurart) wird an das Dokument angeglichen.

### Engine

- **Ein Instrumentenpfad.** Die per Slot fest verdrahteten 32×`PolySynth`/`DrumKit`/`Sampler` und die `switch`-Dispatches (in `EngineCore`: die Slot-Arrays, ihr Aufbau, der Render-`switch`, `silence()` und die Live-Wege) werden durch vorab allokierte `InstrumentKernel`-Instanzen ersetzt. Das sind dieselben Objekte, die die AUv3 nutzt.
- Damit verschwindet auch die Drift in `silence()` (`EngineCore.silence()` gibt die Drums nicht frei).
- Die drei handgeschriebenen Synth-Parameterlisten (`Instrument.swift`, `InstrumentPatch.swift:27`, `SynthKernel.swift:29`) werden zu einer Tabelle.
- Beibehalten: der atomare Snapshot-Zeiger mit Freigabe auf dem Main-Thread, `MeterBank` im Blatt (`MixerView.swift:110`) und die Mixer-Werte außerhalb des Plans.

### Plugins

- Eine Extension (`com.echoelmusic.app.auv3`), ein Produkt (`com.echoelmusic.app.pro`).
- Der Subtyp **`aumu/echl` bleibt registriert** (`project.yml:86`), damit gespeicherte AUM-Sessions weiter öffnen.
- Der Demo-Modus (2 s Stille alle 30 s, `Plugins/Shared/InstrumentAudioUnit.swift:195`) gilt heute **nur** für Instrumente. Ob Effekte gesperrt oder frei sind, ist eine Founder-Entscheidung (§8).
- Die doppelten Komponenten-IDs (`eEQ5` in der App, `xEQ5` in der Extension, `OwnPlugins.swift`) werden dokumentiert. Ihre Zusammenlegung wird nur geprüft, wenn ein Host-Test Probleme zeigt.

### Erweiterungspunkte Körper/Visual/Licht/Raum

| Domäne | Andockpunkt | eigener Bus? |
|---|---|---|
| Körper | `ModSource.bio.*` → `ModRoute` → `ParameterAddress` | nein |
| Licht/Raum/OSC | lesen `EngineTap` plus Event-Spuren, senden über `EchoelIO` | nein |
| Visual | liest `EngineTap` in einem Blatt-View (Metal) | nein |

Kollaboration (das „D" in DMMW) braucht Befehle, die ihre eigene Umkehrung tragen. Heute ist Undo snapshot-basiert. Das ist bewusst **nach** 1.0, wird aber nicht verbaut: Befehle bleiben reine Werte.

## 4. Ordnung im Repository

**Bleibt und ist die Zukunft:**
- `EchoelStudio/` (Core, DSP, Engine, App, Plugins, Support, `project.yml`);
- `LegacySong.swift`, der Importpfad für alte Songs;
- `docs/` (Website).

**Wird verschoben (P0, innerhalb `EchoelStudio/Engine`):**
- `StandardEffectUnit.swift`, `HostedUnit`, `HostedEffect` und `SampleFile` gehen ins Target `EchoelHost`;
- `InstrumentKernel.swift`, `SynthKernel.swift`, `DrumKernel`, `SamplerKernel` und die Effekt-Kernels gehen ins Target `EchoelKernels`.

**Wird portiert, wenn die Phase kommt** (Kern übernehmen, nie ein Subsystem zurückkopieren):

| Phase | Legacy-Dateien |
|---|---|
| P0 | `Sources/Echoelmusic/Sequencer/MicrotonalTuning.swift` (Typ `TuningSystem`) nach Core |
| P4 | `Sync/OSCSender.swift`, `OSCReceiver.swift`, `ADMOSCSender.swift`, `ArtNetSender.swift`, `SACNSender.swift`, `Core/SpatialSceneStore.swift` |
| P6 | `Core/BioEgressPolicy.swift`, `Video/CameraCapture.swift`, `CameraAnalyzer.swift`, `RPPGConditioning.swift`, `PulsePeriodEstimator.swift`, `Bio/CameraRPPGBioPublisher.swift`, `Bio/HRVCoherence.swift`, `Bio/PolarH10BioPublisher.swift` |

Achtung bei der P6-Zeile: Diese Dateien liegen in `Video/`, sind aber der Puls-Pfad. Nie nach Verzeichnis aufräumen.

**Wird nie portiert:** `MusicStyle.swift`, `BioComposer.swift`, `GenrePatches.swift`, `GenreFX.swift`, `GenreIdiom.swift`, `MoodPreset`/`MoodStorage`, `StudioCalculator.genreTempo` und die Genre-Wächter (`GenreFamilyDistinctnessTests` und verwandte).

**Wird archiviert, nach 1.0 und nur per Founder-Entscheidung:**
- `Sources/Echoelmusic`, `Sources/EchoelmusicAUv3`, `Tests/CISmoke`, `Tests/EchoelmusicTests`, die Root-`Package.swift`;
- `memory/LEDGER_COUNTS.md` und `scratchpads/SESSION_LOG.md` gehen auf den Tag `legacy-final` plus einen Archiv-Branch.

Vorher wird `docs/dev/LESSONS.md` geschrieben (maximal 2 Seiten). Es hält die teuer gelernten Regeln fest, die nicht verloren gehen dürfen:
- Sheet-Ketten-Absturz;
- heißer Zustand in View-Bodies;
- kein `Task { @MainActor }` pro Frame;
- `@Sendable` bei Off-Main-Callbacks;
- Record-Route-Refcount (#299);
- `echl`-Subtyp;
- Lebenszyklus-Sprossen **vor** dem Aufruf;
- NaN-sicheres `clamped(to:)`.

**Achtung:** Die Root-`CLAUDE.md` wird von blockierenden Legacy-Tests gelesen (z. B. `TheLawFileStaysUnderItsCeilingTests`, Zitat-Wächter). Sie zu kürzen geht erst zusammen mit der Archivierung, sonst wird das Legacy-Gate rot. Bis dahin bekommt sie oben nur einen Verweis auf diesen Plan.

**Doku-Regeln gegen Wildwuchs:**
1. Eine `CLAUDE.md` pro App, unter 15 KB (`EchoelStudio/CLAUDE.md` hat heute etwa 5 KB). Ihre veralteten Abschnitte Layout und Verifying werden in P0 korrigiert.
2. Jede Entscheidung steht an genau einem Ort: `decisions.csv`. Andere Dokumente verweisen nur.
3. Keine Zahlen und keine Zeilennummern in Prosa. Stattdessen steht dort der Befehl, der sie misst.
4. Tests prüfen Verhalten, nicht Kommentartext.
5. Geschichte lebt in Git, nicht in Dateien, die eine Sitzung lädt.
6. Dieser Plan ersetzt die Reihenfolge-Teile von `NEUSTART_2026-10-17.md`. NEUSTART und `FOUNDER_PRODUCT_LAW.md` bekommen je eine Kopfzeile, die hierher zeigt. Das löst den Widerspruch der drei Gesetzesdateien (`AUDIT_ECHOELSTUDIO_2026-10-18.md` §7).

## 5. Bauphasen

| Phase | Inhalt | fertig wenn | was ausgeliefert wird |
|---|---|---|---|
| **P0 Ordnung** | Targets Kernels/Host, ein Instrumentenpfad, eine Parametertabelle, `DeviceRef`, `MusicalContext` + `TuningSystem`, Befehlsnamen ordnen und einfrieren, Kapazitätsfehler sichtbar machen, Import-Grenze (Linux-Build + CI-Schritt, kein Quelltext-Test), `docs/FORMAT.md` plus Golden-Files, Network-MIDI-Gerätename als `.private` loggen, `EchoelStudio/CLAUDE.md` korrigieren | Core-, DSP- und Engine-Tests grün; App- und AUv3-Build grün; die Extension linkt kein `EngineCore`; ein neues eingebautes Gerät braucht nur eine Tabelle plus einen Kernel; altes Song-Format migriert; **kein Verhaltensunterschied für den Nutzer** | TestFlight-Build, intern |
| **P1 Komponieren** | Startprojekte, Instrument-Presets, Skalen-Lock auf Tastatur und Pads, Stem- und Projektpaket-Export, UTType-Registrierung (`EchoelStudio/project.yml`) | auf dem Gerät: Ton in unter 3 s; Song mit 4 Spuren im Flugmodus erstellt, gespeichert, neu geöffnet und exportiert; die Stems öffnen in einer Desktop-DAW | öffentliche TestFlight-Beta |
| **P2 Eigene AUv3 + Kauf → 1.0** | Lizenz- und Demo-Flow für alle verkauften Units, `auval` lokal auf dem Founder-Mac (oder als Schritt in `studio.yml`, macOS-Runner), Wiederherstellen des Kaufs, Store-Text aus `FEATURE_STATUS` | `auval` besteht; Units laden und spielen in AUM und GarageBand auf dem Gerät, Tonhöhe geprüft bei 44,1 und 48 kHz (die Legacy-Vorhersage war +8,8 %); Kauf im Flugmodus wiederhergestellt; 1.0 besteht das App Review | **App Store 1.0** |
| **P3 Live** | MIDI-Clock ein/aus, Szenen-Launch-Mapping für die Xone:96, Network MIDI mit Peer-Liste und „nur bekannte Hosts" statt `.anyone` (`MIDIInput.swift:437`, `setNetwork(_:)`), Ableton Link nur nach Council-Entscheidung | Founder spielt 30–60 min ein Set auf dem Gerät mit Hardware, ohne Aussetzer und ohne Menü-Freeze, Log gesichert | 1.1 |
| **P4 Bühnen-I/O** | `EchoelIO`, `EngineTap`, Event-Spuren (Cue/OSC/DMX/Raumobjekt), OSC/Art-Net/sACN/ADM-OSC portiert, Bildschirm „Verbindungen" | eine Wasser-/Licht-/Klang-Installation läuft 4 h von Echoel aus | 1.2 |
| **P5 Modulation** | `ModRoute` (LFO, Hüllkurvenfolger, MIDI-CC, benutzerdefinierte Makros ohne vorgegebene Bedeutung), Auswertung im Render-Pass mit fester Routen-Obergrenze | Filter-Sweep über Makro plus LFO ist automatisierbar, per MIDI-Learn erreichbar und mit einem Schritt rückgängig; CPU auf einem älteren iPhone gemessen | 1.3 |
| **P6 Körper** | `EchoelSense`: rPPG und BLE-Gurt als `ModSource`, Egress-Policy portiert, sichtbares „Aus" | der Puls lockt auf dem Gerät; Text gegen die Markenregeln geprüft; Bio sendet ohne Opt-in nichts nach außen | 1.4 |
| **P7 Visual, dann Raum** | Metal-Visual aus `EngineTap`, externer Bildschirm, Raum-Rendering zuletzt | Blitzrate ≤ 3 Hz per Test; Geräte-Check | später |

⚠️ **Förder-Reihenfolge (2026-10-19):** die PAKET-Hälften von P4 und P6 (`EchoelIO`, `EchoelSense`) sind das Förderobjekt. Mit Förderzusage werden sie im Förderzeitraum Juni–November 2027 gebaut, und zwar `EchoelSense` vor `EchoelIO` (M2/M3) — nicht vorher, sonst fördert der Antrag fertige Arbeit. Die App-Hälften (Event-Spuren, `EngineTap`, die Brücken) folgen der Tabelle oben. Ohne Zusage gilt die Tabelle unverändert.

Der Agent ist bereits gebaut. Er läuft ab P1 mit. Wo das Modell fehlt, ist er ausgeblendet, statt durch die Cloud ersetzt zu werden.

## 6. Vertrauen (CCC-Sicht)

**Öffentliche Zusagen, die die Architektur erzwingt** (jede ist heute schon wahr oder wird es durch die genannte Phase):
1. Kein Konto, kein eigener Server, keine Telemetrie, kein Crash-SDK. Diagnose ist ein lokales Log, das der Nutzer selbst exportiert.
2. Offline voll nutzbar. **Annahme:** Die Kaufprüfung offline über den StoreKit-Cache wird vor jeder öffentlichen Aussage im Flugmodus getestet (P2).
3. Netzwerk nur in einem Modul, jede Verbindung standardmäßig aus und in „Verbindungen" sichtbar (P3/P4). Bis dahin gibt es genau zwei Netzwerkstellen: StoreKit und Network MIDI als Opt-in.
4. Der Song ist lesbarer Text: versioniertes JSON mit sortierten Schlüsseln plus eigene Mediendateien, Spezifikation in `docs/FORMAT.md` (P0).
5. Alles ist exportierbar: Mix, Stems, MIDI und Projektpaket (P1).
6. Der KI-Assistent läuft auf dem Gerät. Jede Aktion ist sichtbar und mit einem Schritt rückgängig zu machen.
7. Berechtigungen werden nur bei Bedarf abgefragt: Mikrofon beim Öffnen des Eingangs (`AudioEngine.swift:162-167`), lokales Netz bei Network MIDI.
8. Gesundheitsdaten (Herzfrequenz/HRV; DSGVO Art. 9, **Annahme**, rechtlich nicht geprüft) verlassen das Gerät nie ohne Opt-in pro Ziel. Klinische Felder brauchen einen eigenen Schalter (P6).
9. Ein ehrlicher Demo-Modus, in klaren Worten genannt, ohne Ablaufdatum.
10. Null Fremdcode im Binary.

**Lizenz.**
- **Empfehlung: MIT behalten.**
  - Begründungen:
    - Das Repo ist bereits öffentlich und MIT-lizenziert (`LICENSE`).
    - Eine neue Lizenz gilt ohnehin nicht rückwirkend für schon veröffentlichte Stände.
    - MIT ist ohne Ausnahmeklausel mit dem App Store verträglich. Bei GPL gibt es Präzedenzfälle der Entfernung (GNU Go 2010, VLC 2011).
  - Was ergänzt wird:
    - Das Jahr in `LICENSE` wird aktualisiert (heute „2024-2025").
    - Ein DCO-Hinweis für Beiträge sorgt dafür, dass die Store-Verteilung rechtlich gedeckt bleibt.
    - Ein README-Abschnitt sagt offen: „Wer den Code selbst baut, kann die Sperre entfernen. Der Kauf bezahlt signierte Builds, Updates und die Entwicklung."
- **Alternative**, falls dem Founder Copyleft wichtig ist: MPL-2.0 für die App, Apache-2.0 für Core und DSP. Das ist App-Store-verträglich, wie Firefox iOS zeigt (**Annahme**).
- **Nicht** „source-available" (BSL/PolyForm) wählen und es dann „Open Source" nennen.

**Reproduzierbarkeit, ehrlich.**
- Was möglich ist:
  - öffentliche CI;
  - getaggte Releases;
  - Commit-Hash im About-Screen;
  - Actions per SHA pinnen (`.github/workflows/studio.yml`).
- Was nicht möglich ist: Ein Byte-für-Byte-Vergleich des Store-Binaries ist auf iOS wegen FairPlay nicht möglich. Das wird offen dokumentiert.

**Sicherheitskontakt.**
- `SECURITY.md` im Repo-Root (GitHub zeigt sie an) und `/.well-known/security.txt` nach RFC 9116 auf der Website (`docs/`).
- Inhalt: eine Disclosure-Policy mit 90-Tage-Frist, Danksagung und Safe-Harbor-Zusage (keine rechtlichen Schritte gegen Forschung in gutem Glauben).
- Die Kontaktadresse legt der Founder fest.
- **Annahme:** Damit Jekyll `.well-known/` ausliefert, braucht es eventuell einen `include`-Eintrag. Das ist vor dem Veröffentlichen zu prüfen.
- Jährlich ein kurzer Transparenzbericht („0 Anfragen, 0 gespeicherte Nutzerdaten").

## 7. Markt

**Positionierung:** „Own your sound. Own your files."
- Eine vollständige Workstation für iPhone und iPad: eigene Instrumente, AUv3-Hosting, Live mit Hardware.
- Offline, ohne Konto, ohne Abo-Zwang, mit offenem Format.
- Zweite Ebene ab 1.2: „From studio to stage". Dieselbe App steuert Licht und Raum über offene Protokolle. Das ist der Bezug zum Founder als Installationskünstler.

**Preis** (Marktrecherche: das Band von AUM, Drambo und BeatMaker 3 ist akzeptiert):
- Die App ist kostenlos und vollständig, inklusive Speichern und Export. Eingebaute Instrumente sind in der App frei (`OwnPlugins.swift:1-4`).
- Ein Non-Consumable „Pro" für etwa 24,99–29,99 € schaltet die eigenen AUv3 in fremden Hosts frei.
- Später werden nur **neue** Instrumente separat verkauft, nie bereits verkaufte Funktionen.
- Schriftliche Zusage: Gekauftes wird nie zum Abo (§8, entschieden).

**Kanäle:**
1. Loopy-Pro-/Audiobus-Forum: Entwickler-Thread mit Beta und Changelog.
2. Öffentliche TestFlight-Beta, beworben über das Forum und r/ipadmusic.
3. r/ipadmusic und r/iOSmusicproduction, mit [Listen]-Posts, die die verwendeten Apps nennen.
4. Pressekit für Synthtopia, CDM, MusicRadar, MusicTech, Gearnews, Sound On Sound.
5. YouTube-Demo-Kanäle mit frühem Zugang.
6. Patchstorage für Presets und Startprojekte.
7. CCC und Hamburg: Call for Art bzw. ein Talk zum 40C3. Gezeigt wird die Signalkette, kein Produktpitch. **Annahme:** Termin und CfP 2026 noch nicht geprüft.
8. Installationsnetzwerke (Ars Electronica, CTM, Mutek) ab 1.2.

**Do / Don't**

| Do | Don't |
|---|---|
| nur nennen, was im Build ist | „coming soon" im Store-Text |
| Besitz zuerst: einmal kaufen, offline, kein Konto | den Deal für bestehende Käufer ändern |
| Privacy präzise: „Data Not Collected", lokal, keine Fremd-SDKs | Wellness-, Heilungs-, Meditations- oder Therapie-Sprache |
| offene Standards beim Namen nennen | „Mach Musik wie X" oder Genre-Versprechen |
| Demos auf echtem Gerät, keine Renderings | behaupten, die KI mache die Musik |
| Biofeedback (ab 1.4) als wissenschaftliche Modulationsquelle mit Messgrenzen | eine CCC-„Empfehlung" behaupten |

**Migration der Tester:**
- Studio nutzt dieselbe Bundle-ID `com.echoelmusic.app` (`EchoelStudio/project.yml:55`), also denselben App-Store-Eintrag und dieselbe TestFlight-Gruppe.
- Der erste Start bietet den einmaligen Song-Import aus der App Group an (`LegacySong.swift`, `DocumentController.swift:342-368`).
- Die Release-Notiz sagt klar, dass Bio, Visual und Licht pausiert sind und in späteren Versionen zurückkommen. Konkrete Versionsnummern nennt sie nicht.
- AUM-Sessions mit `echl` laden weiter. Bisherige Tester werden zuerst eingeladen.

## 8. Risiken und offene Founder-Entscheidungen

1. **Abo oder Einmalkauf — ENTSCHIEDEN: Einmalkauf.** Schon mit der Neustart-Entscheidung vom 2026-10-17 (`decisions.csv`) ersetzt; die Pläne vom 2026-07-10 zum Jahres-Abo „Echoel Live" gelten nicht mehr. Die Community straft Abos für Werkzeuge ab (Logic iPad, Audiobus 2025).
   - **Empfehlung:** Einmalkauf, schriftlich „kein Abo für Gekauftes". Ein Abo höchstens für einen echten laufenden Dienst (z. B. Kollaboration). Vor jedem Store-Text entscheiden.
2. **Effekte frei oder gesperrt in fremden Hosts — ENTSCHIEDEN: frei.** Heute haben die Effekt-Units der Extension keinen Demo-Modus.
   - **Empfehlung:** Effekte frei, als Einstieg und Goodwill. Gesperrt bleiben nur Instrumente. Das passt zum heutigen Code.
3. **P0 verzögert 1.0 — ENTSCHIEDEN: P0 zuerst, strikt begrenzt.** Umbau ohne sichtbaren Gewinn. Nach 1.0 ist er aber teurer, weil Namen und Format einfrieren.
   - **Empfehlung:** P0 strikt auf die Liste in §5 begrenzen, keine Feature-Arbeit, kein Verhaltensunterschied.
4. **AUv3-Kompatibilität ist nur in AUM gemessen.** Für GarageBand gibt es eine Tonhöhen-Vorhersage von +8,8 % bei 44,1 kHz.
   - **Empfehlung:** Kein Verkauf, bevor AUM und GarageBand auf dem Gerät bei beiden Abtastraten bestanden sind. Logic folgt danach.
5. **Legacy archivieren und Ableton Link.**
   - **Empfehlung Legacy:** Ab sofort eingefroren; Archivierung nach Store-1.0 mit `docs/dev/LESSONS.md` vorab.
   - **Empfehlung Link:** Die Council-Entscheidung fällt in P3. Mit LinkKit (freier C++-Code, laut Code-Style zulässig) endet die Aussage „null Fremdcode". Bis dahin deckt MIDI-Clock die Lücke.

## 9. Nächste drei Schritte

1. **Entscheidung festhalten:** dieser Plan als `docs/dev/NEUPLANUNG_2026-10-18.md`, eine Zeile in `decisions.csv` („Keine Genres; Studio wird geordnet, nicht neu geschrieben; P0 vor 1.0") und Verweis-Kopfzeilen in NEUSTART und `FOUNDER_PRODUCT_LAW.md`. Die Fragen 1 und 2 aus §8 gehen in `docs/dev/FOUNDER_INBOX.md`.
2. **Erste P0-Scheibe, klein und testbar:** eine Parametertabelle für den Synth in Core, aus der die Parameter-Indizes von `SynthKernel` und `PatchField` abgeleitet werden (erledigt, P0.1; einen Typ `SynthKernel.Indices` gab es nie), plus ein Test, dass die Tabelle und beide Verbraucher übereinstimmen. Danach `silence()` über alle Gerätetypen (Drums-Lücke in `EngineCore.silence()`) mit Test.
3. **Format sichern, bevor es einfriert:** `docs/FORMAT.md` (Schema v1) plus zwei Golden-Files mit Round-Trip-Test in `EchoelStudio/Core/Tests`. UTType (`EchoelStudio/project.yml`) und `auval` (`studio.yml`) sind für EchoelStudio freigegeben (Founder 2026-10-17) und folgen in P1/P2.
