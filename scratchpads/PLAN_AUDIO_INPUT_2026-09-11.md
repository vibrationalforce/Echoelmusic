# PLAN — Audio Input sauber aufsetzen (Founder-Ask 2026-09-11)

**Founder, wörtlich:** „Ist es möglich nochmal mein Vorhaben mit dem Audio Input sauber aufzusetzen? Einmal um
per microphon zum Beispiel auf Konzerten, im Club oder auf Festivals oder andere Audio Inputs die physikalisch
assoziierten visuals zu generieren und andererseits war die Idee per Harmonizer, Granulate Efx, Synthese die
Stimme Autotune artig an die Stimmung anzupassen. Das Biofeedback die Stimmeffekte moduliert sollte klar sein.
Eine Verknüpfung mit der Routing Matrix ist auch klar. Es wäre toll, wenn sich das Biofeedback auch mit den
visuals verbinden lässt ohne das man Sound anhaben muss."

Fünf Asks, in der Reihenfolge, in der sie GEBAUT werden (billigste, unabhängigste zuerst):

| Ask | Was heute da ist (gemessen, vier Lese-Agenten, Baum `65b89bc`) | Scheibe |
|---|---|---|
| (e) Bio → Visuals OHNE Sound | Renderer ist bio-fertig: `MetalBioView` liest kein `transport`/`isPlaying`; `BioVisualParams` ist Foundation-pur; alle Publisher fassen `AudioEngine` nie an. **Lücke = der Startpfad:** `startBioSource()` ist nur aus `startBiofeedback()` erreichbar, das erst `generate` + Transport startet. Ohne Musik verlieren Dish/Depth (`dishDriveTarget = musicLevel + 0.5·touchE`) ihren Antrieb → Spiegel | **S1** |
| (b) Stimme: Harmonizer · Granular · Autotune | GEBAUT, verdrahtet, seit #1024 türlos: `AudioInputPickerView` (814 Zeilen: Monitor-Toggle, Tune-to-key + Character, Harmony-Intervalle, Granular, Latenz, Geräteliste inkl. USB-Interface) kompiliert, `showInput`-Slot lebt ohne Setter. Der Monitorpfad wurde NIE am Gerät hörbar bestätigt (Absturzfamilie `isInputConnToConverter`, zuletzt #1022 Session-Refusal). Zwei unversuchte Hypothesen im Code (`AudioEngine.swift:2679-2690`): #5 `prepare()` vor dem Format-Read, #6 Verbinden auf laufender Engine | **S2** (Tür), **S6** (Hypothese #5, EIGENE Scheibe, damit das nächste Log entscheidbar bleibt) |
| (a) Mic/Line-In → physikalisch assoziierte Visuals | KEIN Visual liest heute den Eingang. `monitorTapWindow` (2048) + `monitorSpectrumFFT` laufen ~15 Hz im Guard-Tick, nur der Howl-Detektor liest sie. `MetalBioView` hat 99 Uniforms, MSL-Spiegel positional ohne Compiler-Check — ein neues Feld ist die teuerste Änderung. Aber die CPU-seitigen Terme `musicLevel` (→ intensity + dish), `touchE` (→ motion/spread/intensity) und `voiceHueBias` (→ hue) EXISTIEREN und sind der Ort, an dem ein Eingangs-Feature ohne Shader-Änderung ankommt | **S3** |
| (c) Bio moduliert Stimm-FX | `ModulationEngine` läuft (100-ms-Poll, ~1 Hz Apply), Matrix persistiert, OSC-Tap live, **genau EIN Ziel** (`seq.tempo`). `FXModTarget` kennt weder Harmonizer noch Granular; die Mic-Kette ist privat in `MonitorInsertAudioUnit`, einzige Tür `applyVoicePreset` (Ganz-Preset). Ehrlicher Weg: Ziele in der MATRIX registrieren, deren Closures die `AudioEngine`-Parameter setzen → `pushVoicePreset()` (der #416-Trichter) | **S4** |
| (d) Routing-Matrix-Verknüpfung | `PatchbayView` = die „Routing"-Tür (Master-Panel), Routen sind Start/Stop-Schalter für Sender. Die Modulations-Matrix hat KEINE Fläche (`ModRoute(` null Produktions-Konstruktionen, #541); `FXModRouteRow` ist das Vorbild in Form | **S5** |
| Stimme „an die Stimmung" | `updateVoiceTune` (15 Hz) kennt Tonhöhe (YIN) + Tonart/Skala aus `StudioDefaultKeys`. Harmonizer-Intervalle sind FEST (4/7 st) — die Harmonie kennt die Tonart nicht | **S7** |

## Council (Sitze einzeilig, Dissens benannt)

- **Architect:** Eingangs-Features NICHT als Bus-Snapshot (47 MainActor-Hops/s bei 1024/48k — die #30/#951-Flut), sondern als lock-geschützter Blatt-Kanal wie `TouchVisualEnergy`, gelesen einmal pro `draw`. Bio→Stimme über die MATRIX (persistiert, OSC-Tap, ein Erzeuger), nicht über einen zweiten `FXBioModulator`-Anhang an eine private Kette.
- **DSP Purist:** Extraktion läuft im 15-Hz-Guard-Tick auf der KOPIE des Fensters, nie im Tap. Parameter-Schreibungen sind plain-`Float`-Stores (bestehende Disziplin). Ein 1-Hz-Sprung auf `harmonizer.mix` ist hörbar → ein Ein-Pol-Glätter im Block, nicht im Tick.
- **Vision-Keeper:** Nichts wird verkauft, was das Gerät nicht bestätigt hat: die drei `CLAIMS.md`-Monitor-Zeilen bleiben GESTRICHEN mit neuem Grund („betürt, unverifiziert"), bis ein `VERIFIED-`Datum steht. „Autotune" bleibt Store-verboten (§ 257); im UI heißt es weiter „Tune to key".
- **Shipper:** Sieben Scheiben, je ein Commit, je ein Wächter; S2 und S6 getrennt (Tür ≠ Hypothese). Keine neue `.sheet` — Kette steht bei 14/13.
- **Skeptic:** Der Monitorpfad kann weiter abstürzen; die Tür zurückzugeben setzt den Founder wieder davor. Mitigation: die Tür ist sein Auftrag, Hypothese #5 folgt sofort als eigene Scheibe, und S3 macht den Eingang auch bei stummem Monitor (`Monitor level 0`) nützlich — auf einem Konzert ist Mic→PA ohnehin Unsinn. **Dissens (nicht geglättet):** die #1024-Begründung („erst munter drauflos, dann verhäddert") gilt; darum kein Umbau der Leiter, nur Tür + eine benannte Hypothese.
- **User-Advocate:** Jeder Ask bekommt eine SICHTBARE Bedienstelle: S1 Toggle im Bio-Panel, S2 Master-Tür, S3 Erklärzeile im Input-Sheet („Monitor level 0 = nur hören, nur Bild"), S4/S5 Matrix-Abschnitt in der Routing-Fläche, S7 „Harmony in key" im Input-Sheet.
- **Aesthetic Maximalist:** Die Abbildung muss physisch lesbar sein: Pegel → Antrieb/Intensität, Tiefen → Schwung (spread), Onset → Stoß (wie Fingerenergie), Helligkeit (Centroid) → Farbton-Bias. Und S7 ist der eigentliche Gewinn: eine Harmonie, die die Tonart des Stücks kennt, statt fester Terz/Quinte.

**Gate:** proceed. Founder-gated: nichts (kein `project.yml`, keine Workflows, kein Plist). Device-Verify: JEDE Scheibe trägt `NEEDS-FOUNDER-VERIFY` am Ort; `founder-verify.py --since` druckt sie beim nächsten Deploy.

## Scheiben

| # | Slice | Dateien (max 3 + Wächter) | Wächter |
|---|---|---|---|
| S1 | **Body only (no sound):** `@State bodyOnly` + `startBodyOnly()/stopBodyOnly()` in `EchoelStudioView` (ruft `startBioSource()` ohne `generate`/Transport; `stopBiofeedback` räumt mit), Toggle im `bioPanel`; in `MetalBioView` Ersatz-Antrieb `bodyDrive = 0.4·breath` wenn `musicLevel == 0` und Bio da (Atem 0,1–0,3 Hz, weit unter dem 3-Hz-Gesetz) | `EchoelStudioView.swift`, `MetalBioView.swift` | `TheBodyPlaysThePictureWithoutSoundTests` |
| S2 | **Mic-Tür zurück:** `masterDoorButton("Audio input") { showInput = true }` im Master-Panel (Slot-Reuse). `TheMicrophoneHasNoDoorTests` → `TheMicrophoneHasOneDoorTests` (genau EIN Setter, Sheet+Picker, Engine, nicht persistiert, CLAIMS bleibt gestrichen bis VERIFIED). Prosa: CLAUDE.md ×3, CLAIMS.md ×3 Begründung, zwei Grabsteine in `EchoelStudioView`, `RoutePlugInWatcher`-Kopf, `BLOCKED-BY-#1024` → `NEEDS-FOUNDER-VERIFY` (4 Marker) | `EchoelStudioView.swift` + Prosa | umbenannter Wächter |
| S3 | **Eingang → Bild:** `Core/AudioFeatureExtractor.swift` (pur: RMS-Pegel, Tief/Mitte/Hoch-Bänder, Centroid 0…1, Onset per Spektralfluss; unter −60 dBFS EXAKT 0), `Core/AudioFeatureChannel.swift` (Lock-Blatt, Onset-Energie zerfällt ~1,2 s wie `TouchVisualEnergy`). `AudioEngine.updateFeedbackGuard` schreibt den Kanal aus dem vorhandenen FFT-Zweig; `monitor: OFF` setzt ihn zurück. `MetalBioView.draw` liest ihn einmal pro Frame: `musicLevel = max(musicLevel, level)`, Onset in den `touchE`-Term, Centroid → kleiner Hue-Bias. KEIN neues Uniform. Erklärzeile im Input-Sheet | `AudioEngine.swift`, `MetalBioView.swift`, `AudioInputPickerView.swift` + 2 neue Core-Dateien | `TheInputFeedsThePictureTests` (+ Unit-Test des Extraktors) |
| S4 | **Stimm-Ziele in der Matrix:** `ModDestinationKey.voiceHarmonyMix/.voiceGranularMix/.voiceGranularPitch/.voiceTuneStrength` + `displayName`; Registrierung in `EchoelmusicApp` neben `tempo` (Closures setzen `audioEngine.voiceHarmonyMix` … geklemmt); Ein-Pol-Glätter für `harmonizer.mix` im Block | `ModulationEngine.swift`, `EchoelmusicApp.swift`, `EchoelHarmonizer.swift` | `TheVoiceStagesAreModulationDestinationsTests` |
| S5 | **Matrix-Fläche:** `modulationSection` in `PatchbayView` (Routen-Zeilen nach `FXModRouteRow`-Vorbild: Toggle · Source-Picker `hasProducer` · Ziel-Picker aus `registeredDestinations` · `EchoelValueField` Depth · Curve-Picker · löschen; „Add route"-Menu; `save()` je Edit). `testNothingInTheAppConstructsAModulationRoute` auf die neue Menge; CLAUDE.md CURRENT-STATE-Zeile + Register-Eintrag | `PatchbayView.swift`, `TheTempoDestinationHasNoRouteTests.swift`, CLAUDE.md | `TheMatrixHasADoorTests` |
| S6 | **Hypothese #5:** `masterEngine.prepare()` zwischen Route-Claim und Format-Read (`AudioEngine.swift:2628`), eigene Sprosse `on: prepared before format read`; Kommentar-Hypothese wird zur Messung | `AudioEngine.swift` | `ThePrepareRungPrecedesTheFormatReadTests` |
| S7 | **Harmony in key:** `Core/DiatonicHarmony.swift` (pur: Skalengrad der erkannten Note → diatonische Terz/Quinte in Halbtönen); `AudioEngine.voiceHarmonyFollowsKey` (Session-lokal, default AUS), in `updateVoiceTune` je Tick die Intervalle nachführen (didSet → `pushVoicePreset`); Toggle „Harmony in key" im Input-Sheet | `AudioEngine.swift`, `AudioInputPickerView.swift` + 1 Core-Datei | `TheHarmonyKnowsTheKeyTests` |

## Was dieser Plan NICHT tut
- Kein Umbau der Monitor-Leiter (#1024-Lehre, DEAD-END `voiceTunePitch`-Live-Rewire).
- Kein Tap ohne Monitor-Route (zweiter I/O-Unit-Start ist die 44.1/48-k-Falle; `MicrophoneManager` bleibt die zweite Engine für den Timbre-Take).
- Kein neues Uniform, kein neues Sheet, kein neuer Bus-Topic.
- „Autotune" nie in Kopie; Voice-Clone bleibt geschlossen (Founder 2026-08-25).
