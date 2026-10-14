# Port-Kandidaten für Schritt 2 — 2026-10-14

**Auftrag:** lesendes Review von `docs/dev/HISTORY_ARCHIVE.md`, Abschnitte A und B. Genau dieser Bericht ist die Änderung. Kein Port, keine Änderung an `Sources/`, `Tests/`, `.github/`, `CLAUDE.md` oder `project.yml`, keine Paketinstallation. Das parallel entstehende Plugin-Fenster ist nicht Gegenstand dieses Reviews.

**Prüfstand:** `main` bei `48ba58a7b33879b0efdc9fea6c96979b44a29197` (im Folgenden **B**). Der Bericht gilt für diesen festen Stand, nicht für spätere Arbeiten auf dem Claude-Branch. Das Archiv wurde an B gelesen; seine letzte Änderung ist `4c443630a949575272743231b9e57bf6747b202e`.

## Ergebnis und Maßstab

Die acht Kandidaten unten enthalten verwertbare DSP-Berechnung. Die größte zusätzliche Produktionsfähigkeit liefern Drum-Kerne, die alten Synth-Engines und ein resonanter Bass. ModalBank und FDN-Reverb sind noch vorhanden und brauchen Wiederanbindung statt Wiederherstellung. Ein sofortiges Zurückkopieren ganzer historischer Dateien ist bei keinem Kandidaten begründet.

Die Auswahl bewertet **zusätzlichen musikalischen Nutzen am Prüfstand**, Breite der Anwendung, nachvollziehbare Mathematik und Port-Risiko. Sie ist eine Review-Empfehlung, keine gemessene Klangqualitätsrangliste. Bestehender Sampler und Grain-Bake werden nicht als neue Rückholarbeit gezählt.

**Drei getrennte Nachweise:**

- **DSP real:** Eine gelesene Implementation berechnet/verändert Samples und schreibt sie in einen Puffer. Das lässt sich statisch von einem Katalog, Mapping oder Platzhalter unterscheiden.
- **Kompiliert:** `ja` nur mit zuordenbarem iOS-Compile-Check und geprüftem Target-Einschluss; `nein` unten ausschließlich für den ausgeschalteten C++-Standard-Build. Ohne passenden Nachweis: `unklar`. Archiv-Y, Dateikommentar und grüner Website-Build reichen nicht.
- **Echte Klangausgabe:** Hier bewusst streng: ein nachgewiesener Lauf mit ausgegebenem Audio, nicht allein eine Render-Funktion. Kein historischer PCM-Mitschnitt, Geräte-Hörtest oder zugeordneter Signaltest-Lauf wurde in diesem Auftrag verifiziert. Deshalb steht bei den Kandidaten **unklar**, auch wenn ein echter und teils angebundener DSP-Pfad vorhanden ist. Das bedeutet nicht „Fassade“.

Die Zeilenzahlen des alten Bestands sind mit `git show … | wc -l` bzw. gleichwertigem Zählen des gelesenen Blobs erhoben. **Port-Schätzungen** umfassen Kern und schmalen Adapter, ohne UI, Presets, Tests oder umfassende Persistenzmigration. Es sind Größenordnungen, keine zugesagten Umfänge.

## Die acht besten Kandidaten

Alle Swift-Pfade in dieser Tabelle beginnen mit `Sources/Echoelmusic/`, außer dem ausdrücklich vollständigen C++-Pfad. Der SHA bezeichnet den **gelesenen Quellstand**, nicht den Löschcommit. Vollständige SHAs und Rückholbefehle stehen im Quellenregister.

| Rang | Kandidat / Nutzen | Alter Pfad; Quell-SHA | Kompiliert | Echte Klangausgabe | Heutige aufnehmende Datei / Rolle | Bestand → geschätzte Port-Größe |
|---|---|---|---|---|---|---|
| 1 | **808-Kick/Pitch-Hüllkurve + metallische Hi-Hat** (A9): unmittelbar für Beats, Trap und elektronische Grooves | `Sound/TR808BassSynth.swift` + `Sound/EchoelBeat.swift`; [93e332d70][kick] | unklar | unklar; echter Stereo-PCM-Pfad vorhanden | `Sequencer/LaneVoiceRack.swift` als Host einer Percussion-Stimme; Bass-Anteil ggf. `Tools/SubBassVoice.swift` | 886 + 1.318 → **200–320 Zeilen** |
| 2 | **EchoelSynth: FM, Karplus–Strong, Supersaw** (A7): deutlich mehr spielbare Klangfamilien | `Sound/EchoelSynth.swift`; [93e332d70][synth] | unklar | unklar; SourceNode, Synthese und Touch-Notenpfad vorhanden | `Tools/PolySynthVoice.swift` als Voice-Owner; `DSP/SynthPatch.swift` für künftig persistierte Engine-Wahl | 969 → **350–550 Zeilen**, in getrennten Engine-Scheiben |
| 3 | **Resonanter Basskern** (A8): Vierpolfilter, Saw/Pulse und Accent-Amplitude | `Sound/EchoelBass.swift`; [93e332d70][bass] | unklar | unklar; echter Stereo-PCM-Pfad vorhanden | `Tools/SubBassVoice.swift`; Einbindung über `Sequencer/LaneVoiceRack.swift` | 906 → **120–220 Zeilen** für den ausgewählten Kern |
| 4 | **ModalBank als Mallet-/Percussion-Stimme** (A4): Glocken, Platten, Saiten, Glas | `DSP/EchoelModalBank.swift` an [B][modal]; historischer Host `Sequencer/DrumSynthVoice.swift` an [03d0f75dd][drumhost] | ja, siehe K1/K3 | unklar; historischer SourceNode-Ausgang belegt | `Sequencer/LaneVoiceRack.swift`; vorhandenen `DSP/EchoelModalBank.swift` weiterverwenden | 871 Kern + 238 alter Host → **120–220 Zeilen Adapter**, Kern bleibt |
| 5 | **FDN-Reverb** (B2): zusätzlicher algorithmischer Raum für Mix, Dub und Ambient | `DSP/EchoelFDNReverb.swift`; [B][fdn] | ja, siehe K3 | unklar; echter Wet-PCM-Kern, keine Produktionskonstruktion an B gefunden | `DSP/EchoelFXChain.swift` als Algorithmus-Einbindung; Bus-Besitz/CPU vorab festlegen | 282 Kern → **100–180 Zeilen Adapter**, Kern bleibt |
| 6 | **Zweistimmiger Delay-Harmonizer** (B4): kreative Intervalle, Dopplung und Textur | `DSP/EchoelHarmonizer.swift`; [122724de3][harm] | ja, siehe K2 | unklar; Sample-Prozessor und frühere FX-Verkettung vorhanden | `DSP/EchoelFXChain.swift`; vorhandene `DSP/EchoelDelayLine.swift` nutzen | 139 → **130–200 Zeilen** |
| 7 | **Cellular-Textur in der App** (A5): bewegte additive/FM-/Wavetable-Texturen | `DSP/EchoelCellular.swift`; [B][cell] | ja, siehe K3 (App-Target) | unklar; AUv3-Render-Aufruf vorhanden, App-Stimme fehlt | `Sequencer/LaneVoiceRack.swift` als App-Host; `Tools/PolySynthVoice.swift` als bestehende Render-/Command-Referenz | 623 Kern → **120–220 Zeilen Adapter**, Kern bleibt |
| 8 | **Ringmodulation** (aus B9): kleiner eigenständiger Effekt für metallische Percussion und Sounddesign | `Sources/DSP/ModulationSuite.cpp`; [ad3c083d1][ring] | nein im vorgefundenen Standard-Build; Sonderbuild unklar | unklar; Sample-Multiplikation vorhanden, JUCE-Build ausgeschaltet | `DSP/EchoelFXChain.swift` als neue optionale Stufe | 529 Gesamtdatei; 24 Zeilen Ringmod-Funktion → **40–80 Zeilen Swift-Kern/Adapter** |

**„Aufnehmende Datei“ bezeichnet den heutigen Integrationsbesitzer.** `LaneVoiceRack` ist kein DSP-Render-Kernel. Neue Kerne würden getrennt unter `DSP/` liegen; solche neuen Dateien sind hier nur ein möglicher späterer Entwurf. Ein Engine-Selector existiert in `SynthPatch` an B noch nicht. Die Tabelle behauptet weder vorhandene Steckplätze für alle Kandidaten noch eine fertige Integration.

### 1. Kick und Hi-Hat — nur die Tonerzeugung übernehmen

**Beleg:** [TR808BassSynth, Z. 457–595][kick] berechnet Pitch-Verlauf (509–525), Sinus/Sub (528–552), Click, Hüllkurve, Drive und Filter und addiert nach links/rechts (582–585). [EchoelBeat, Z. 914–960][hat] berechnet sechs Rechteckoszillatoren, Band-/Hochpass und exponentiellen Ausklang; der Render-Callback addiert das Ergebnis und schreibt beide Ausgangskanäle (877–892). Das ist echte DSP-Arbeit.

**Audio-Thread:** Die alten `renderAudio`-Funktionen nehmen `voiceLock.try()` und entsperren anschließend. Auch ein Try-Lock verletzt den Auftrag. `TR808BassSynth` baut `voicesToRemove`, hängt Elemente an und sortiert sie im Callback. `EchoelBeat.processSequencerStep` kann `drumPlaybacks.append` aus dem Callback erreichen. Diese Verwaltung entfällt vollständig beim Port; fester Voice-Pool und feste Zustands-/Event-Puffer sind Voraussetzung. Der isolierte Hi-Hat-Sample-Kern zeigt keinen Lock/GCD-Aufruf; die statische Frequenzliste muss vor Audio-Start initialisiert sein.

**Grenze:** „Pitch glide“ ist hier eine Hüllkurve zum Zielton; das belegt keinen vollständigen Legato-Slide zwischen beliebigen Noten. Pegel, Aliasing, Release und Stimmenüberlappung sind nicht hörgeprüft. Der alte Sequencer und das Drum-UI sind keine Port-Kandidaten.

### 2. EchoelSynth — zuerst eine Engine, nicht die gesamte Shell

**Beleg:** [FM Z. 676–699, Pluck Z. 731–759, Supersaw Z. 761–798][synth]. FM moduliert die Trägerphase mit einem zweiten Sinus; Pluck liest und dämpft einen rückgekoppelten Ring; Supersaw summiert verstimmte PolyBLEP-Sägezähne. `renderAudio` ruft `renderEngine`, filtert/hüllt den Samplewert ein und schreibt in Stereo. `Views/MultiTouchInstrumentView.swift` desselben Quellstands ruft `EchoelSynth.shared.noteOn/noteOff` (63, 83–96).

**Audio-Thread:** `voiceLock.try()` (488), dynamisches `voicesToRemove`, `sorted()` (604) und das Kopieren einer Voice mit Array-Feldern (`var v = voices[voiceIndex]`, 496) sind zu entfernen. Mutationen der kopierten `pluckBuffer`-/Unison-Arrays können Copy-on-write auslösen. Die Noise-Befüllung des Pluck-Puffers liegt zwar in `noteOn` (417), darf für einen heutigen Render-Thread-Notenverbraucher nicht dort neu allokieren. Supersaw nutzt `Double.random` pro Sample/Voice (781): keine Echtzeiteignung des System-RNG nachgewiesen; eigener vorbereiteter PRNG-Zustand nötig.

**Port-Schnitt:** zuerst 2-Operator-FM oder Karplus–Strong mit fixen Zuständen und bestehendem Note-/Tuning-Vertrag. Die Schätzung deckt die drei ausgewählten Engines insgesamt ab. Unison existiert bereits im heutigen DDSP; ein weiterer Unison-Regler allein wäre kein hinreichender Nutzen. Das historische „Chorus“-Stück (567–575) skaliert nur die Amplitude und enthält keine verzögerte Stimme; nicht als geprüften Chorus übernehmen.

### 3. Bass — Filter behalten, 303-Versprechen zurücknehmen

**Beleg:** [EchoelBass Z. 815–835][bassfilter] enthält Rückkopplung und vier zustandsbehaftete Tiefpassstufen. Die Acid-Variante mischt Saw/Pulse und verstärkt die Amplitude über `acidAccent` (738–753). Das ist ein brauchbarer Ausgangspunkt für einen eigenständigen resonanten Bass, keine validierte Hardware-Emulation.

**Archivkorrektur:** `acidSlide` kommt im gelesenen Blob nur als Konfigurationsfeld und Preset-Argument vor (118, 213), nicht im Render-Zweig. Accent verstärkt dort die Amplitude; der Kommentar „filter env“ wird von dieser Stelle nicht umgesetzt. Die „Growl-Formanten“ (778–791) multiplizieren das Signal mit frequenzabhängigen Faktoren, haben dort aber keinen resonanten Filterzustand. **303-Slide und Formantfilter sind aus diesem Kern nicht als funktionierende Merkmale zurückholbar.**

**Audio-Thread:** gleiche Lock-/Array-Verwaltung wie EchoelSynth (`renderAudio` 509–655). Nur Filterzustand, Oszillator und Hüllkurve extrahieren. Die Filterfrequenz-Normierung und Stabilität bei hoher Resonanz müssen gemessen werden. `moogLadderFilter` und `tanh` sind in der `@MainActor`-Klasse nicht `nonisolated`, obwohl der Render-Pfad sie aufruft: zusätzliche Isolationsfrage, kein aus dem Archivtext ableitbarer Compile-Nachweis.

### 4. ModalBank — bestehenden Kern wieder anbinden

**Beleg:** [aktueller Kern, `excite`/`noteOn` Z. 478–519 und `render` Z. 583–662][modal]. Die Bank summiert gedämpfte Sinusmoden und schreibt in den vorgegebenen Buffer. [Alter Host Z. 69–78, 124–129, 212–234][drumhost] konstruiert die Bank, ruft `render` und kopiert Samples zum `AVAudioSourceNode`. `LaneDrumKitVoice.swift` desselben Elternstands stellt die alte Kit-Hülle dar; deren Wiederherstellung ist nicht empfohlen.

**Audio-Thread:** `render`, `noteOn`/`excite` und übergebene Materialänderungen gehören in einen eindeutig besessenen Render-Zustand. Der heutige Kern verwendet vorangelegte Mode-/Scratch-Arrays. In diesen Schleifen wurden keine expliziten Allokations-, Lock- oder GCD-Aufrufe gefunden. Das ist kein instrumentierter Allokationsnachweis. Materialtabellen/lazy Initialisierung vorher aufwärmen; keine gemeinsam gehaltenen Array-Kopien. Die alte Übergabe mit gewöhnlichen Zählern/Scalars ist durch Kommentare nicht als Swift-speichermodellsicher bewiesen und wird nicht als Vorlage freigegeben.

**Heute:** keine Produktionskonstruktion von `EchoelModalBank` an B gefunden. `LaneVoiceKind.drums` existiert, aber `TrackInstrument.drums.voiceKind` liefert `.poly`; ein Enum-Case ist kein funktionierendes Drum-Instrument.

### 5. FDN-Reverb — bewahrter Kern, kontrollierter neuer Aufrufer

**Beleg:** [Z. 156–211][fdn] lesen acht Delay-Lines, bilden die Wet-Summe, wenden Feedback-Gains und die Hadamard-Mischung an und schreiben zurück. `processInPlace` (136–144) verändert den übergebenen Buffer. Das ist ein Reverb-Kern, kein Raum-Parameter-Modell allein.

**Audio-Thread:** `processInPlace` → `renderSample` → `allpass`/`hadamard8` → `EchoelDelayLine.read/write`. Keine explizite Allokation/Lock/GCD in diesem gelesenen Pfad; Buffer müssen exklusiv und vorbereitet sein. **Nicht in den Callback:** `process(_:)` allokiert das Ausgabe-Array (124); `setRoom` ersetzt Array-Zustände und nutzt `map` (105–109). Auch „control-rate“ erlaubt keine ungesicherte parallele Mutation von Render-Zustand. Neue Konfiguration nur über einen definierten sicheren Übergang.

**Grenze:** Delay-Kapazitäten werden aus dem initialen Raum gewählt; spätere größere Räume werden laut tatsächlichem Pfad am Delay-Leser begrenzt. Die gewünschte größere Hallzeit ist dann nicht allein durch die neuen Parameter belegt. Vor Integration Bus-/Send-Besitz und Stereo-Strategie festlegen; der Kern ist mono, kein fertiger Stereo-Send. CPU und Klangqualität unklar.

### 6. Harmonizer — als kreativer Effekt, nicht als fertige Stimmkorrektur

**Beleg:** [Z. 76–100 und 114–137][harm] schreiben in vier Delay-Lines, lesen je zwei versetzte Taps, überblenden mit Cosinusfenstern und addieren zwei feste Intervalle zum trockenen Stereo-Eingang. Vor der Entfernung des Audioeingangs (`a86d57192^`) konstruiert `EchoelFXChain` den Harmonizer und ruft `processStereo` in der Kette (217, 496). Die Datei war also nicht bloß ein Parameterschema.

**Audio-Thread:** `processStereo` und `shiftVoice` samt Delay-Lesern/-Schreibern. Keine explizite Allokation, Locks oder GCD in den gelesenen Kernfunktionen; die vier Lines werden in `init` erzeugt. Plain mutable Properties/`@unchecked Sendable` sind keine gesicherte Thread-Übergabe. Für den Port Parameter als begrenzten Render-Snapshot übernehmen; Reset, Warm-up und Pegelbegrenzung bewusst anbinden.

**Grenze:** rund 50 ms Lesefenster, hörbare Delay-/Chorus-Artefakte möglich; kein nachgewiesener Formanterhalt, keine validierte Pitch-Correction. Für kreative Harmonien kann das unabhängig vom defekten alten PhaseVocoder nützlich sein. Die im Archiv formulierte zwingende Abhängigkeit „erst B6“ ist für diesen engeren Zweck nicht technisch erforderlich. Den alten Mikrofon-Graph nicht mitportieren.

### 7. Cellular — aktuelle reparierte Fassung verwenden

**Beleg:** [Z. 413–464][cell] rufen die CA-Evolution, berechnen die gewählte Syntheseform und schreiben Samples. An B konstruiert `Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift` die Textur (32), stellt additive Synthese ein (198) und ruft `textureRef.render` (768). Die App-Integration ist die offene Arbeit; der AUv3-Kern muss nicht wiederhergestellt werden.

**Audio-Thread:** `render` samt `evolve1D/evolve2D` und Wavetable-/Additive-/FM-Renderern. Frühere Whole-Array-Zuweisungen wurden wegen Copy-on-write entfernt; nicht durch eine alte Fassung zurückbringen. `init`/`seed` und große Konfigurationen vorbereitet halten. Der aktuelle Render-Pfad glättet **für jedes Sample alle Zellen** (435–438); keine CPU-Zusage ohne Messung. Die 1-D-Evolution schreibt sequenziell in dasselbe Zellarray (348–352), weshalb die klassischen synchronen Wolfram-Regeln nicht allein durch ihre Namen nachgewiesen sind.

### 8. Ringmodulation — kleiner Port, schwächerer historischer Laufnachweis

**Beleg:** [ModulationSuite Z. 432–455][ring] berechnet einen Sinus-Träger, multipliziert jeden Eingangssample damit und mischt trocken/nass. Diese 24 Zeilen sind eigenständig verständlich und bringen einen bisher in der aktuellen FX-Kette nicht vorhandenen Effekt.

**Audio-Thread:** Phasenfortschritt, `sin`, Multiplikation und Wet/Dry-Mischung; keine Allokation, Lock oder GCD im isolierten historischen Funktionskörper. Für Swift zwei begrenzte Kanal-/Trägerzustände nach gewünschter Stereo-Semantik, rateabhängiger Phasen-Wrap und geglättete Parameter. Keine JUCE-Abhängigkeit übernehmen.

**Wichtige Abgrenzung:** [Z. 461–490][bode] enthalten **keinen vollständigen Bode-/Single-Sideband-Shifter**. `sine` wird berechnet, aber nicht verwendet; der Ausgang ist `input * cosine`, der Vorzeichenparameter wird mit `abs` entfernt. Das ist eine weitere Ringmodulation, kein Beleg für gerichtete Frequenzverschiebung. Kein entsprechendes Produktversprechen aus dem Header übernehmen.

## Prüfung aller Einträge aus A und B

Diese Tabelle dokumentiert die Abdeckung des Archivs, auch für Nicht-Kandidaten. `D28`, `D03`, `DJ`, `DH`, `DI`, `DD` und `DS` bezeichnen die unten vollständig aufgelösten Löschcommits; gelesen wurde jeweils **deren erster Elternstand**. `B` bezeichnet den heutigen Prüfstand. „PCM vorhanden“ bewertet den Code, nicht einen in diesem Auftrag durchgeführten Audiolauf.

| Archiv | Gelesener Code / Stand | Befund und Entscheidung |
|---|---|---|
| A1 DDSP / PolySynthVoice | B: `DSP/EchoelDDSP.swift`, `Tools/PolySynthVoice.swift` | Echte harmonische/Noise-Berechnung und `renderStereo` → Voice-Ausgabe. Bereits vorhanden. Kein Rückholkandidat. |
| A2 SubBassVoice | B: `Tools/SubBassVoice.swift` | Eigener SourceNode/Render-Pfad für Sub und Charakter. Vorhandener Aufnahmeort für gezielten Bass-Kern, keine Wiederherstellung der gesamten alten Bass-Shell. |
| A3 BioReactiveSynthVoice | B: `Tools/BioReactiveSynthVoice.swift` | DDSP-Render vorhanden. **Archiv veraltet:** `renderOnAudioThread` ruft jetzt `fxChain.processBufferMono` (1008–1011); „eigene FX-Kette nie benutzt“ gilt an B nicht mehr. |
| A4 ModalBank | B + DD: `DSP/EchoelModalBank.swift`, `Sequencer/DrumSynthVoice.swift`, `LaneDrumKitVoice.swift`, `DrumNoteMap.swift` | Echte modale Sample-Erzeugung und historischer SourceNode. Wiederanbindung: Rang 4. |
| A5 Cellular | B: `DSP/EchoelCellular.swift`, AUv3-AudioUnit | Echte Samples und AUv3-Aufrufer; keine App-Konstruktion gefunden. Rang 7. Aktuell 623 statt der im Archiv genannten 563 Zeilen. |
| A6 SamplerVoice | B: `Sequencer/SamplerVoice.swift`, `LaneVoiceRack.swift`, `BeatPlayer.swift`, `EchoelmusicApp.swift` | **Archiv veraltet:** `LaneVoiceRack.setSample` → `loadSampleIfNeeded` → `loadSample` (612–645); App verdrahtet `setSample` (1240), Preview lädt ebenfalls (BeatPlayer 132). Ein fehlender Ladepfad ist heute kein Port-Auftrag. Geräteverhalten unklar. |
| A7 EchoelSynth | D28: `Sound/EchoelSynth.swift` + `Views/MultiTouchInstrumentView.swift` | Echte FM-/Pluck-/Saw-Berechnung, tatsächliche Render- und Note-Callsites. Historischer erfolgreicher Audio-Build nicht belegt. Rang 2. „Chorus“ dort nur Amplitudenmodulation. |
| A8 EchoelBass | D28: `Sound/EchoelBass.swift` | Echte Oszillatoren/Vierpolfilter; `acidSlide` ungenutzt, Growl-„Formanten“ ohne zustandsbehafteten Bandpass. Rang 3 nur für den begrenzten Kern. |
| A9 Drums / 808 | D28: `Sound/EchoelBeat.swift`, `TR808BassSynth.swift`; DD: Drum-Hosts; D03: `android/app/src/main/cpp/TR808Engine.cpp`; DJ: `Sources/Synthesis/DrumSynthesizer.cpp` | Swift: reale Kick-/Hat-Samples → Rang 1. Android: ebenfalls Sample-Loop; `processSine` teilt die Phase zwischen Grundton und Obertonaufrufen, daher kein ungeprüfter Ersatz. C++: reale Syntheseformeln, Standard-JUCE-Build aus. Android-Lauf/Compile unklar. |
| A10 SampledInstrumentVoice | DS: `Tools/SampledInstrumentVoice.swift` | Echter `AVAudioUnitSampler`-Adapter: Bank laden, `startNote`, Graph attach. Bleibt bei fehlendem Soundfont stumm (`isReady`). Asset im ausgelieferten Bundle/Lizenz/Output hier unklar; keine neuen Assets/Abhängigkeiten für Schritt 2 empfohlen. |
| A11 EchoelQuant | D03: `Quantum/EchoelQuant.swift` | `step`/FFT und `render` (713 ff.) berechnen Werte und schreiben Audio. Echte Rechenarbeit, aber Produktionsaufruf, Klangnutzen, CPU und Lauf unklar. Forschungsreserve, kein früher Port. |
| A12 C++ Synth-Suite | DJ: `Sources/DSP/EchoSynth.cpp`, `WaveForge.cpp`, `SampleEngine.cpp`; `Sources/Synth/WaveWeaver.cpp`, `FrequencyFusion.cpp`; `Sources/Instrument/RhythmMatrix.cpp` | Render-/Sample-Loops in allen sechs Dateien vorhanden. Standard-Build ausgeschlossen. Teilmerkmale sind Fassade: z. B. `WaveForge.loadCustomWavetable` ignoriert Argumente; WaveWeaver-Filter nennt selbst einen Placeholder. SampleEngine variiert Abspielschritt, kein unabhängig nachgewiesener Time-Stretch. Swift-Kerne aus A7 haben Vorrang. |
| A13 Metronome / Bibliothek / Orchestrator / Scoring | B: `Audio/MetronomeVoice.swift`; D28: `Sound/UniversalSoundLibrary.swift`, `InstrumentOrchestrator.swift`; D03: `Orchestral/CinematicScoringEngine.swift` | Metronom: vorhandener PCM-Ausgang. Bibliothek/Orchestrator: Offline-Synthese → `AVAudioPCMBuffer` → `schedulePlayback`; deshalb nicht pauschal klanglos. Ihr „granular“ erzeugt überlappende Hann-gefensterte Sinus/Saw-Grains (311–335), keine Sample-Granular-Engine. Weltinstrumenten-Katalog nicht klanglich validiert. CinematicScoring: Engine-Instanz + Timer/Listen, kein Noten-Audiowriter im gelesenen Event-Pfad (685–779): Fassade als Klangerzeuger. |
| B1 FXChain / Characters / Modulation | B: `DSP/EchoelFXChain.swift` und Voice-Callsites | Aktuelle Sample-Kette vorhanden (479–495). Bestehende Stufen nicht erneut importieren. Genre-/Character-Klangqualität wurde nicht hörbewertet. |
| B2 FDN | B: `DSP/EchoelFDNReverb.swift` | Echte Delay-/Feedback-Mathematik, keine Produktionskonstruktion gefunden. Rang 5. |
| B3 Faltung / SpaceReverb | B: `DSP/EchoelSpaceReverb.swift`, DDSP-Convolution-Gate; DJ: `Sources/DSP/ConvolutionReverb.cpp` | Space: reale ER-/Tail-Faltung über `EchoelConvolution`, ohne Produktionskonstruktion. Allokierende Offline-API und vorbereiteter In-place-Pfad getrennt. Lange IR/CPU und Übergabe offen; vorerst hinter FDN. DDSP-Gate nicht als live belegt. C++ ruft JUCE-Convolution, Standard-Build aus. |
| B4 Harmonizer | DH: `DSP/EchoelHarmonizer.swift`; DI: frühere FXChain; DJ: `Sources/DSP/Harmonizer.cpp` | Swift: echter Zwei-Tap-Prozessor, Rang 6. C++: Mehrstimmenpfad mit lokalen `AudioBuffer`-Allokationen in `process` (62, 67, 80); kein Grund, diesen Wrapper zurückzuholen. |
| B5 Granular | DH: `DSP/EchoelGranular.swift`; B: `DSP/GrainCloud.swift`, `Sequencer/GrainBake.swift`, `TimelineAudioSink.swift` | Historischer fester Grain-Pool liest echte Delay-Samples. **Bereits weitergeführt:** `GrainBake` konstruiert GrainCloud (90), `TimelineAudioSink` ruft den Bake auf (266). Kein zweiter Port des alten Mic-Pfads. Die Pauschalaussage „UniversalSoundLibrary-Granular fake“ ist enger zu fassen, siehe A13. |
| B6 Pitch / PhaseVocoder / Formant | DI: `Sequencer/VoicePitchCorrector.swift`; D28: `Audio/VocalProcessing/PhaseVocoder.swift`, `Sources/EchoelVoice/VocalDSPKernel.swift`; DJ: `Sources/DSP/PitchCorrection.cpp` | Corrector: reale Skalen-/Cents-Berechnung; Backend/Monitoring im alten AudioEngine-Pfad beschrieben, nicht selbst ausgeführt. PhaseVocoder: teilweise reale STFT, aber erhebliche konkrete Defekte, siehe unten. VocalDSPKernel nennt PhaseVocoder, benutzt in `pitchShiftBlock` (486–513) blocklokales lineares Resampling und Zero-Fill. C++ allokiert im `process`. Kein früher Port dieser Gesamtsysteme. |
| B7 Vocoder | DI: `Studio/VocoderCore.swift`; DJ: `Sources/DSP/Vocoder.cpp` | Swift ist ausschließlich Mapping/Daten, kein Audio-Vocoder (Dateikopf und Typen bestätigt). C++ enthält Carrier-/Band-Summen, Standard-Build aus. DSP-Abhängigkeiten/Audio-Lauf nicht vollständig validiert; nachrangig. |
| B8 Spectral / Resonance / De-Esser | DJ: `Sources/DSP/SpectralSculptor.cpp`, `ResonanceHealer.cpp`, `DeEsser.cpp` | FFT/FIFO-/Gain- und Envelope-Berechnung vorhanden; keine trainierte „AI“ dadurch belegt. ResonanceHealer verwendet Frequency-only-FFT vor Inverse und allokiert Dry-Buffer (82, 113, 138): kein geprüfter Rekonstruktionskern. Standard-Build aus; neutraler DSP-Neuentwurf allenfalls später. |
| B9 Dynamics / Tone | D28: `DSP/ClassicAnalogEmulations.swift`, `NeveInspiredDSP.swift`; DJ: VintageEffects, LofiBitcrusher, UnderwaterEffect, TapeDelay, ClassicPreamp, HarmonicForge, ModulationSuite, FETCompressor, OptoCompressor, FormantFilter (je `Sources/DSP/*.cpp`) | Reale Filter-/Envelope-/Sättigungsberechnung vorhanden, Markenemulationen unbelegt. Underwater/FormantFilter allokieren lokale AudioBuffer im Prozess. Ringmod-Kern Rang 8; „Bode“ widerlegt. Stereo-Link bei FET/Opto wird berechnet, aber der lokale Sidechain-Wert nicht an `processSample` übergeben: weitere Header nicht ungeprüft übernehmen. Gesamte Abhängigkeitsketten nicht vollständig RT-zertifiziert. |
| B10 ProMix-Effektliste | D28: `Audio/ProMixEngine.swift`, `Audio/MixerDSPKernel.swift`, `Audio/Nodes/NodeGraph.swift` | Benannte Merkmale nicht gleich implementierte Effekte: `pitchShift/harmonizer/vocoder` → `FilterNode`, Modulation → `DelayNode` (MixerDSPKernel 446–481). **Archivzahl korrigiert:** am Elternstand sind fünf Node-Klassen im Factory-Switch, einschließlich `SaturationNode`, nicht vier. Ein Audio-Prozess-Einstieg existiert; historische Live-Erreichbarkeit bleibt unklar. Keine Rückholung des Effektkatalogs. |

## Warum PhaseVocoder nicht unter den ersten acht steht

Das Archiv bezeichnet ihn als besonders wertvolle DSP und nennt Laroche–Dolson-Phase-Locking und LPC. Der gelesene [481-Zeilen-Blob][phase] rechtfertigt diese Aussagen nicht:

1. `advancePhases` (285–310) behandelt jeden Bin unabhängig; keine Peak-/Nachbarbindung ist implementiert. Die Überschrift belegt kein Phase-Locking.
2. `estimateSpectralEnvelope` (381–423) mittelt Log-Magnituden. Kein LPC-Solver und keine echte Cepstrum-Transformation in dieser Funktion. `preserveTransients` wird nicht im Stretch-Pfad verwendet; `detectTransient` ist dort nicht angebunden.
3. `pitchShift` streckt mit `1 / pitchRatio` (137), `resample` kürzt nochmals um `pitchRatio` (430). Bereits aus der Längenrechnung folgt für lange Eingaben näherungsweise `N / ratio²` statt `N` (zuzüglich Fenster-/Hop-Ränder). `prefix(input.count)` füllt zu kurze Resultate nicht auf. Das ist ein statisch abgeleiteter Defekt, keine in diesem Auftrag gemessene Audiodauer.
4. `performFFT` legt vier Arrays pro Frame an (219–227), `performIFFT` weitere (245–255), die Formantkorrektur nochmals mehrere. Ungeeignet für den Audio-Thread in dieser Form.
5. FFT-Packung/DC-/Nyquist-Handhabung, OLA-Normalisierung und Randbehandlung sind nicht durch einen hier verifizierten Null-/Sinus-/Impuls-Lauf abgesichert. Nicht als „transparent“ oder „formanterhaltend“ freigeben.

Ein späterer Port müsste zuerst Dauer, Tonhöhe, Unity-Rekonstruktion, Rand-/Kurzbuffer und Allokationsfreiheit nachweisen. Das ist mehr als Wiederanbindung. Der heutige Code enthält bereits andere Audio-Tempo-/Pitch-Pfade; der alte Klassenname begründet keine zweite Wahrheit.

## Audio-Thread-Grenze für alle späteren Ports

Im Render-Callback und **allen transitiv aufgerufenen** Funktionen gilt: **keine Allokation, kein Lock (auch kein Try-Lock), kein GCD**. Ebenso keine Datei-/Asset-Ladevorgänge, kein UI-/Actor-Hop und kein unkontrollierter System-RNG. DSP-Konfiguration und Pufferkapazitäten vor dem Start vorbereiten; Note-/Parameterübergaben müssen zum heutigen Besitzer passen.

Besonders zu prüfen: Copy-on-write bei Arrays und kopierten Voices, erste Berührung lazy initialisierter Tabellen, Deinitialisierung/ARC-Freigaben, geänderte Blockgröße/Samplerate und gleichzeitiger Presetwechsel. `@unchecked Sendable`, „atomic-width“ und Kommentare mit „zero allocation“ sind keine Messung. FDN/Modal/Cellular/Harmonizer sind **Kandidaten für einen prüfbaren Echtzeitpfad**, nicht durch diesen Leseauftrag vollständig als RT-sicher zertifiziert.

## Build-Nachweise und offene Grenzen

| ID | Verifizierte Evidenz | Aussagegrenze |
|---|---|---|
| K1 | [iOS Device Compile erfolgreich][build-modal] an `03d0f75dd3ab2a7c1c36f2e141fa9e6bb9756ceb`; `project.yml` nimmt `Sources/Echoelmusic` auf | Belegt Kompilierung des historischen Modal-/Drum-Quellstands; kein Hörnachweis. |
| K2 | [iOS Device Compile erfolgreich][build-harm] an `122724de3598511e12fd02ccfe93598000361eae`; Target-Einschluss gelesen | Belegt Harmonizer-Quellstand. Der separate iOS-Build-&-Test-Check ist rot; nicht zu „alle Tests grün“ umdeuten. |
| K3 | [iOS Device Compile erfolgreich][build-current] an `d1811fa858f7886cbc2b7c5254bdf6f2017e2f59` | ModalBank, FDNReverb, Cellular und `project.yml` sind gegenüber B bytegleich. Belegt diese Dateien im App-Target dieses Builds, nicht einen AUv3-Host-Lauf. Gesamt-Sources sind nicht bytegleich: WaveformReducer/WaveformSketch unterscheiden sich. Auch hier separater iOS-Test-Check rot. |
| K4 | Check-Runs an `93e332d70e8d9b69e7a8d1fb928cc5af741a80c5` gelesen | Gefundene grüne Build-/Deploy-Checks wurden nicht als iOS-DSP-Compile akzeptiert; EchoelSynth/Bass/Beat/TR808 bleiben `unklar`. |
| K5 | [CMakeLists Z. 108–119 und 191 ff.][cmake] an `ad3c083d1e27192c084d702f8db7c2a0e21245fd`: `USE_JUCE` default OFF; `ThirdParty/JUCE` fehlt im Tree | C++-Kandidaten werden im vorgefundenen Standard-Build nicht kompiliert. „Niemals auf irgendeiner Maschine kompiliert“ ist nicht bewiesen. |

Die iOS-Compile-Workflows der herangezogenen historischen Stände wurden gelesen: `xcodebuild build` für iOS Release, dessen tatsächlicher Exit-Code aus `PIPESTATUS[0]` weitergegeben wird. Verwendet wurden GitHub-Check-Run-Metadaten; vollständige historische Build-Logs und Testresultate wurden nicht ausgewertet. Der direkte Job-GET über den Connector war für diesen Endpunkt nicht verfügbar. Lokal fehlen Swift/Xcode; kein lokaler Build, kein Testlauf und keine Paketinstallation durchgeführt. Ein grüner Website-Check an B ist ausdrücklich kein iOS-Nachweis.

## Reproduzierbare Quellen

Gelöschte Dateien wurden tatsächlich mit `git show <Löschcommit>^:<Pfad>` gelesen, nicht aus Commit-Beschreibungen rekonstruiert. Noch vorhandene Kerne wurden mit dem festen B-Stand verglichen. Kurz-IDs im Text lösen sich so auf:

| ID | Löschcommit | Gelesener erster Elternstand |
|---|---|---|
| D28 | `3dfd8cc0a13722928d020eff5a7ebe7c972e3dbd` | `93e332d70e8d9b69e7a8d1fb928cc5af741a80c5` |
| D03 | `f6afae7ea01b93db6f7653c5ee48555825c12867` | `6fa82fb7c2e12e1a2015e916cf4bd84aaad5b0a0` |
| DJ | `48811de03bd533db910cd4f59ad4501f82df6c84` | `ad3c083d1e27192c084d702f8db7c2a0e21245fd` |
| DH | `0127665621de49eb3328d5e76f0d92b96affa379` | `122724de3598511e12fd02ccfe93598000361eae` |
| DI | `a86d571929f7c66d869c2b314faf6c96dbb5f519` | `fab8054b2e202dc74759d7e26f1339a79c95a016` |
| DD | `6ea6e45c76a881acbe0a5ff8584c622623f4485b` | `03d0f75dd3ab2a7c1c36f2e141fa9e6bb9756ceb` |
| DS | `6c9258b1aba06252eb58444f65438f7d63d35c59` | `f39d1ca3e6f488ad4e40ec1771d760064101782e` |

Beispielbefehle für die Gegenprüfung (reine Leseoperationen):

```bash
git show 3dfd8cc0a13722928d020eff5a7ebe7c972e3dbd^:Sources/Echoelmusic/Sound/EchoelSynth.swift
git show 3dfd8cc0a13722928d020eff5a7ebe7c972e3dbd^:Sources/Echoelmusic/Sound/EchoelBass.swift
git show 3dfd8cc0a13722928d020eff5a7ebe7c972e3dbd^:Sources/Echoelmusic/Sound/EchoelBeat.swift
git show 3dfd8cc0a13722928d020eff5a7ebe7c972e3dbd^:Sources/Echoelmusic/Sound/TR808BassSynth.swift
git show 0127665621de49eb3328d5e76f0d92b96affa379^:Sources/Echoelmusic/DSP/EchoelHarmonizer.swift
git show 48811de03bd533db910cd4f59ad4501f82df6c84^:Sources/DSP/ModulationSuite.cpp
git show 48ba58a7b33879b0efdc9fea6c96979b44a29197:Sources/Echoelmusic/DSP/EchoelModalBank.swift
git show 48ba58a7b33879b0efdc9fea6c96979b44a29197:Sources/Echoelmusic/DSP/EchoelFDNReverb.swift
git show 48ba58a7b33879b0efdc9fea6c96979b44a29197:Sources/Echoelmusic/DSP/EchoelCellular.swift
```

Für weitere A/B-Dateien steht der jeweilige Pfad in der Prüftabelle. Diese ist eine gezielte Algorithmus-/Anbindungsprüfung, kein Vollbeweis jeder historischen Hilfsbibliothek. Ungeprüft bleiben insbesondere Geräteklang, messbare Audioqualität/CPU, alle alten C++-Header-Abhängigkeiten und AUv3-Interop der möglichen Ports.

**Empfohlene nächste Entscheidung:** einen Drum- oder FM-Kern als erste eng begrenzte Scheibe auswählen. Wer zunächst einen bereits erhaltenen und compile-belegten Kern anbinden möchte, beginnt mit ModalBank. Die Auswahl und Umsetzung bleiben beim Hauptautor; dieser PR enthält ausschließlich diesen Bericht.


[kick]: https://github.com/vibrationalforce/Echoelmusic/blob/93e332d70e8d9b69e7a8d1fb928cc5af741a80c5/Sources/Echoelmusic/Sound/TR808BassSynth.swift#L457-L595
[hat]: https://github.com/vibrationalforce/Echoelmusic/blob/93e332d70e8d9b69e7a8d1fb928cc5af741a80c5/Sources/Echoelmusic/Sound/EchoelBeat.swift#L797-L981
[synth]: https://github.com/vibrationalforce/Echoelmusic/blob/93e332d70e8d9b69e7a8d1fb928cc5af741a80c5/Sources/Echoelmusic/Sound/EchoelSynth.swift#L475-L798
[bass]: https://github.com/vibrationalforce/Echoelmusic/blob/93e332d70e8d9b69e7a8d1fb928cc5af741a80c5/Sources/Echoelmusic/Sound/EchoelBass.swift#L509-L846
[bassfilter]: https://github.com/vibrationalforce/Echoelmusic/blob/93e332d70e8d9b69e7a8d1fb928cc5af741a80c5/Sources/Echoelmusic/Sound/EchoelBass.swift#L738-L846
[modal]: https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/DSP/EchoelModalBank.swift#L478-L662
[drumhost]: https://github.com/vibrationalforce/Echoelmusic/blob/03d0f75dd3ab2a7c1c36f2e141fa9e6bb9756ceb/Sources/Echoelmusic/Sequencer/DrumSynthVoice.swift#L69-L234
[fdn]: https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/DSP/EchoelFDNReverb.swift#L99-L211
[harm]: https://github.com/vibrationalforce/Echoelmusic/blob/122724de3598511e12fd02ccfe93598000361eae/Sources/Echoelmusic/DSP/EchoelHarmonizer.swift#L59-L138
[cell]: https://github.com/vibrationalforce/Echoelmusic/blob/48ba58a7b33879b0efdc9fea6c96979b44a29197/Sources/Echoelmusic/DSP/EchoelCellular.swift#L286-L464
[ring]: https://github.com/vibrationalforce/Echoelmusic/blob/ad3c083d1e27192c084d702f8db7c2a0e21245fd/Sources/DSP/ModulationSuite.cpp#L432-L455
[bode]: https://github.com/vibrationalforce/Echoelmusic/blob/ad3c083d1e27192c084d702f8db7c2a0e21245fd/Sources/DSP/ModulationSuite.cpp#L458-L490
[cmake]: https://github.com/vibrationalforce/Echoelmusic/blob/ad3c083d1e27192c084d702f8db7c2a0e21245fd/CMakeLists.txt#L105-L119
[phase]: https://github.com/vibrationalforce/Echoelmusic/blob/93e332d70e8d9b69e7a8d1fb928cc5af741a80c5/Sources/Echoelmusic/Audio/VocalProcessing/PhaseVocoder.swift#L126-L445
[build-modal]: https://github.com/vibrationalforce/Echoelmusic/actions/runs/30599971561/job/91060313414
[build-harm]: https://github.com/vibrationalforce/Echoelmusic/actions/runs/34709852133/job/103596504014
[build-current]: https://github.com/vibrationalforce/Echoelmusic/actions/runs/38534095149/job/115752663476
