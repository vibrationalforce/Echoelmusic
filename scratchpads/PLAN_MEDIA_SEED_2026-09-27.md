# PLAN — Foto/Video als kreatives Material (MediaSeed), 2026-09-27

Auftrag: Founder-Prompt 2026-09-27 („Foto und Video werden zu kreativem Material …“).
Branch: `feature/media-seed-2026-09-27`, lokal, vom HEAD `dfe9525e6`. **Kein Push** (Founder-Anweisung),
also **kein Compile-Beleg**: CI ist der einzige Compiler, und CI läuft nur auf einen Push.

## 1. Kanonische Besitzer (gemessen, nicht angenommen)

| Frage | Besitzer | Beleg |
|---|---|---|
| Visual-Parameter | sechs `@AppStorage`-Schlüssel `visual.intensity/detail/motion/spread/hue/saturation` + `visual.preset` | `Core/StudioDefaultKeys.swift:259–283`, `EchoelStudioView.applyVisualPreset` |
| Zweiter Schreiber außerhalb des Panels (Präzedenz) | `VisualMoodMap.apply` schreibt direkt in `UserDefaults.standard` | `Studio/MoodPads.swift` |
| Wertebereiche | `VisualPreset.init` klemmt (intensity 0…1,5 · detail 8…90 · hue 0…1 · saturation 0…2) | `Studio/VisualPreset.swift` |
| Mediendateien | `MediaLibrary` (`Media/Image` + `importImage` existieren, **null Aufrufer**) | `Core/MediaLibrary.swift:62` |
| Clips | `ClipStore` (8 Slots, persistiert) · `ClipKind.visual` existiert, **null Erzeuger** | `Sequencer/Clip.swift:61` |
| Zeitachse + Undo | `TimelineStore` (`addRegion` … `HistoryStep`, Undo nur Regionen/Noten/Automation/Quelle) | `Core/TimelineStore.swift` |
| Performance | `ClipLaunchEngine` via `TimelineRegionPlayer` auf `PatternEngine` — **drei Tore lehnen `.visual` ab** | `launchableLaneID`, `isExecutable`, `TrackMix.role` |
| Tür | `WorkstationView` (Import-Zeilen, EIN `.fileImporter`, #W1 verbietet einen zweiten) | `Studio/WorkstationView.swift` |

## 2. Kleinste vollständige Scheiben (je ≤ 3 Sources-Dateien, je ein Commit)

- **MS1 — reiner Kern.** `Core/MediaSeed.swift`: deterministische Analyse eines schon verkleinerten RGBA8-Puffers
  (Dominantfarbe über 36 Farbton-Bins, Helligkeit Rec. 709, HSV-Sättigung, RMS-Kontrast), harte Grenze
  `maxAnalysisSide = 256`, ungültiger Puffer → `nil`. Wächter: Determinismus, Grenzen, Fallback, Tie-Break.
- **MS2 — Seed → vorhandener Visual-Pfad, rückgängig machbar.** `Studio/MediaSeedLook.swift`: Abbildung über
  `VisualPreset.init` (dieselben Klemmen, #416) + `VisualLookSnapshot` (lesen/schreiben der sechs Schlüssel +
  `visual.preset`). Anwenden gibt den Vorher-Schnappschuss zurück = Undo.
- **MS3 — Tür.** `Studio/PhotoSeedDecoder.swift` (ImageIO, `CGImageSourceCreateThumbnailAtIndex` mit
  Maximalgröße, abseits des Main-Actors, abbrechbar) + `Studio/PhotoSeedCard.swift` (PhotosPicker — braucht
  KEINE Berechtigung und KEINEN neuen Modifier —, Vorschau, Vorher/Nachher, „Apply to visuals“, „Undo“) +
  Montage in `WorkstationView`.
- **MS4 — Arrangement.** `.visual`-Clip mit gespeichertem Seed + Region auf einer Visual-Spur (Undo über
  `TimelineStore`). Braucht ein Seed-Feld am `Clip` (persistiertes Format → Decoder mit `try?`).
- **MS5 — Wiedergabe + Performance.** `.visual` ausführbar machen: Regions-Eintritt wendet den Seed an, Stop
  stellt den Vorher-Zustand deterministisch wieder her; die drei Launch-Tore öffnen.
- **MV1 — Video-Kern (rein).** Bewegungsenergie + einfache Transienten aus Pro-Frame-Luma-Rastern; falsche
  Werte (nicht endlich, falsche Rastergröße) werden abgelehnt.
- **MV2 — Video-Import** (PhotosPicker `.videos`, `FileRepresentation` → Kopie nach `Media/Video`, nie ganz in
  den Speicher; `AVAssetImageGenerator` für Proxy-Frame + begrenzte Stichprobe, abbrechbar).

## 3. Harte Grenzen dieses Repos — vor dem Bauen benannt

1. **Kein Swift-Compiler hier, kein Push erlaubt** → nichts ist kompiliert. Wächter werden per Python-Transkription
   benotet (`Tests/CISmoke/CLAUDE.md` §0). Das ist die ehrliche Obergrenze dieser Sitzung.
2. **Kamera-AUFNAHME eines Fotos/Videos: blockiert, nicht vergessen.** `NSCameraUsageDescription` beschreibt
   heute NUR den Puls über die Rückkamera; eine Foto-Aufnahme bräuchte einen neuen Zweck-Text in
   `Resources/iOS/Info.plist` (founder-gated). Außerdem teilt sich die Kamera mit dem rPPG-Pfad
   (`Video/CameraCapture`) — eine zweite `AVCaptureSession` daneben ist ein eigenes Design. **Import über
   PhotosPicker braucht keine Berechtigung** und ist deshalb der erste Weg.
3. **Bio-Shutter: blockiert.** `CMDeviceMotion` braucht `NSMotionUsageDescription` (Info.plist, founder-gated);
   `import CoreMotion` kommt in `Sources/` nicht vor. Atem-Phase gibt es nur als Messung der Bio-Quelle, und
   rPPG darf nicht als Atemmessung ausgegeben werden. Ohne Kamera-Aufnahme gibt es keinen Auslöser, den ein
   Bio-Shutter steuern könnte. Modusnamen („Manuell“, „Ruhiger Moment“, „Automatisch“) kommen mit der Aufnahme.
4. **Video-Audio als Beat/Sampler-Quelle: nicht in diesen Scheiben.** Nächster Integrationspunkt:
   `AVAssetReader` (Audio-Spur → PCM) in eine `Media/Audio`-Kopie, danach der VORHANDENE `AudioImport.commit`-Weg.
   Nichts wird vorgetäuscht.
5. **Visual-Domäne ist ohne Founder-Entscheidung pausiert** — dieser Auftrag IST die Entscheidung für den
   Seed-Pfad. XR/Output bleibt pausiert; es entsteht keine XR-Abstraktion.
6. **#1304 (Video Capture zurückgenommen)**: Product Law 2026-09-24 erlaubt Video wieder als Domäne; Recorder/
   Muxer werden NICHT zurückkopiert. Diese Scheiben lesen Videos, sie nehmen keine auf.
7. **Farbe ist eine DREHUNG, kein Ziel.** `visual.hue` dreht die physikalische Ton→Licht-Farbe (`echoelHue`).
   Ein Foto-Seed setzt die Drehung = Foto-Farbton; das Bild wird dadurch nicht „die Fotofarbe“. Die UI sagt das.

## 4. Stand 2026-09-27 (Branch `feature/media-seed-2026-09-27`, lokal, NICHT gepusht, NICHTS kompiliert)

| Scheibe | Commit | Was |
|---|---|---|
| MS1 | `2b2e2d1d7` | `Core/MediaSeed.swift` — reiner Foto-Kern |
| MS2 | `92a9dfd2e` | `Studio/MediaSeedLook.swift` — Seed → sechs `visual.*`-Schlüssel + Chip, Undo |
| MS3 | `68f9d9a01` | „Photo to Visuals“: Decoder (ImageIO-Thumbnails) + Karte + Montage |
| MV1 | `0b1a2d8f3` | `Core/VideoSeed.swift` — reiner Video-Kern (Bewegung, Transienten, Takte) |
| Review-HIGH/MED | `c9769ca9b` | Permission-Wächter: `import PhotosUI` ≠ `import Photos`; Rot-Farbton zirkulär |
| MV2a | `34e5897d1` | `VideoSeedReader` (AVFoundation, ≤ 48 Frames, Toleranz 0, abbrechbar) + Video → Visual |
| Review-MED | `81ab083b3` | EIN geteiltes `MediaLookUndo`; Undo pro Wert; Anzeige-Raster; „Hue“ |
| Review-LOW | `f2025268b` | Überlauf-Schutz der Zeilenlänge; Kontrast zweipassig (flach = 0) |
| MV2b | `d695503ec` | „Video to Visuals“: Karte + Montage |

## 5. MS4 + MS5 — BEWUSST NICHT GEBAUT in dieser Sitzung, und warum

**Grund (Council, Shipper + Skeptiker):** MS4 allein wäre eine Tür zu einem unsichtbaren Teil — die
Arrange-Fläche zeigt `.visual` nicht (`TrackParts.arrangeable`), der Spieler führt es nicht aus
(`isExecutable` → false, zwei unabhängige Tore). „Place in Song“ ohne MS5 wäre ein Knopf, nach dem nichts
Sichtbares passiert. MS5 fasst `TimelineRegionPlayer` an (1 542 Zeilen, der am dichtesten bewachte Motor) und
dreht mindestens vier Wächter um (#364). Das auf neun UNKOMPILIERTE Commits zu stapeln, ohne dass ein Gate
je gelaufen ist, ist die billigste Art, falsch zu liegen. **Erst ein Gate-Lauf über MS1–MV2, dann MS4+MS5.**

### Design, baufertig (je ≤ 3 Sources-Dateien)

- **MS4a — Datenmodell.** `Sequencer/MediaLook.swift` (neu): `enum MediaLook: Codable, Sendable, Equatable
  { case photo(MediaSeed), video(VideoSeed) }` + `isPlausible`. `Clip.mediaLook: MediaLook?` (Property,
  Init-Parameter mit Default nil, `CodingKeys`, `try?`-Decode — ein alter Build liest den Schlüssel nicht und
  verliert nichts). `.visual`-Clip: `mediaRef` = die verwaltete Kopie (`MediaLibrary.importImage` bzw.
  `importVideo`, beide haben heute NULL Aufrufer), `isEmpty` bleibt die Regel.
- **MS4b — Platzieren.** `Sequencer/VisualPlacement.swift`: reiner Plan (erste Visual-Spur oder neue,
  Start = Ende der letzten Visual-Region auf dem Takt, Länge = 4 Takte Foto / `VideoSeedAnalysis.bars` Video)
  + `@MainActor perform` über `ClipStore` + `TimelineStore.addRegion` (EIN Undo-Schritt). ⚠️ `addLane(kind:)`
  hat KEIN Undo — Spur zuerst, Region danach, und das in der Karte so sagen.
- **MS4c — Arrange zeigt es.** `TrackParts.arrangeable` nimmt `.visual` auf (verschieben/trimmen/
  duplizieren/entfernen laufen dann über die VORHANDENEN `TrackParts`-Wege, quantisiert auf den Takt).
  Wächter mitziehen: `TheTrackInspectorShowsOnlyWiredControlsTests`, `TheTrackPartsAreArrangedThroughTheStoreTests`.
- **MS5a — Ausführen.** `ClipKind.timelineEngineKinds` += `.visual` (Maschine UND Erzeuger jetzt beide da —
  die #1438-Doppelfrage, getrennt beantwortet); `isExecutable(.visual)` = `clip.mediaLook?.isPlausible`.
  `.video` bleibt zu (`testAPartOnlyOnAVideoLaneIsNotASong` bleibt grün).
- **MS5b — Folgen.** Injizierter `VisualLookSink` am Spieler (`begin()` = Schnappschuss bei `play`,
  `show(MediaLook?)` nur bei WECHSEL des klingenden Teils über `soundingRegion(laneID:at:)` — das deckt
  Launch UND Arrangement mit EINER Regel ab —, `end()` in `stop()` UND `handleTransportStopped()` stellt den
  Schnappschuss wieder her = deterministischer Stop). Kein Schreiben pro Schritt, nichts auf dem Audio-Thread
  (Transport-Schritt ist Main-Actor). `launchableLaneID` nimmt `.visual` auf; `applyLaunchTransitions` muss
  eine Visual-Spur ignorieren (prüfen!). Wächter: `TheSessionLaunchesWhatTheSongPlaysTests` („Look“-Spur).

## 6. Offene Stufen danach
Kamera-Aufnahme (Info.plist-Text, Founder) → Bio-Shutter (CMDeviceMotion + `NSMotionUsageDescription`,
Founder; „Ruhiger Moment“ nur bei echter Atemquelle) → Video-Ton als Beat-Quelle (AVAssetReader →
`Media/Audio` → `AudioImport.commit`) → Transienten → Slices → XR/Installation (pausiert).

## 7. Photism-Auswertung → Visual-Pakete V1–V4 (Auftrag 2026-09-28; NUR PLANUNG, nichts davon freigegeben)

**Beweislage, unverändert festgehalten:** `photism.app` ist aus dieser Umgebung nicht erreichbar (Egress-Proxy
blockiert die Domain; alle vier Seiten). Die Angaben unten stammen aus Suchmaschinen-Auszügen der offiziellen
Seiten (`/`, `/start/`, `/online/`, `/lite/`, `/buy/`, `/learn/…`) — SEKUNDÄR, nicht am Manual geprüft. Aus der
Vorarbeit übernommen, nicht reproduziert: Photism Online konnte im bisherigen Testbrowser ohne WebGL nicht
rendern; neun Prüfungen eines unabhängigen Python-Anforderungsmodells bestanden, vier eingebaute Fehler wurden
erkannt — das sind keine ausgeführten Photism-, Swift- oder Gerätetests. Desktop-AU ≠ AUv3-Nachweis,
CC-Learn ≠ MPE-Nachweis, Browserbetrieb ≠ iPhone-Nachweis. Keine fremden Shader, keine Assets.

### 7.1 Was Photism laut Quellen tut — als PRINZIP, nicht als Kopie

| Prinzip (Photism) | Beleg | Für Echoel heißt das |
|---|---|---|
| Drei spielbare Makros HEAT (Bloom/Flash) · REACT (wie hart die Musik das Bild treibt) · BRIGHT (Belichtung); 16 zuweisbare Makros, als Automation im Arrangement | `/`, `/lite/` | Wenige benannte Makros mit EINEM Besitzer statt sechs rohe Schlüssel; Automation über den vorhandenen Parameterweg (`ParameterApplyRouter`), nicht über `@AppStorage` |
| Szenen + Paletten als getrennte Achsen (3+13 Szenen, 6+18 Paletten) | `/lite/` | Szene = `visual.style/styleB/blend` (existiert), Palette = Farbdrehung + Sättigung + MediaSeed; getrennt halten, nie in einem Preset vermischen |
| Bild auf das Fenster ziehen → Fünf-Farben-Palette | `/` | MediaSeed liefert heute EINE Dominantfarbe + Helligkeit/Sättigung/Kontrast; Farbe bleibt eine DREHUNG der physikalischen Ton→Licht-Farbe (§3.7) — keine Palette vortäuschen |
| Plugin-Fenster = Visualizer, Vollbild oder als Ausgabefenster auf jedem Display; Syphon/Spout als saubere Frames | `/`, `/start/` | `ExternalDisplayScene` (#206, nicht-interaktive Szene) IST das; Syphon/Spout haben auf iOS kein Gegenstück, NDI wäre eine Abhängigkeit (Founder-Hold) |
| MP4-Aufnahme direkt aus dem Visual mit dem Track-Audio | `/` | War gebaut (`VideoRecorder`/`VideoMuxer`), Founder: „hat leider nicht geklappt“, mit #1304 gelöscht; `HISTORY_ARCHIVE` F3 = REBUILD-Klasse, „device-log review why it failed BEFORE any rebuild“ |
| MIDI-Mapping per Rechtsklick auf jeden Slider | `/start/` | Kein Visual-Parameter ist heute MIDI- oder automationsfähig (`git grep -n "visual\." Sources/Echoelmusic/Core/EchoelParameterRegistry.swift` → 0). Prioritätsregel Automation↔Hand ist bei Photism NICHT belegt („not stated“) |
| Getrennte Steuersignale Hits / Bass / Helligkeitsenergie | im Auftrag genannt; in den Auszügen NICHT bestätigt | Bei uns bereits als DATENFORM vorhanden: `AudioFeatureFrame` (level · low · mid · high · centroid · onset) + `AudioFeatureChannel.onsetEnergy` — PRODUZENTENLOS seit #1302 |
| PNG-Export, feste Seitenverhältnisse | nicht belegt | Bei uns existiert kein Standbild-Export (`pngData`/`ImageRenderer`/`texture.getBytes` → 0 Treffer) |

### 7.2 Zuordnung: Quelle → Wertebereich → Zeitbasis → Ziel → Stop/Signalverlust → manueller Vorrang → Persistenz

Vier Quellklassen, getrennt, weil sie verschiedene Uhren und verschiedene Ehrlichkeitsregeln haben. **Fehlende
Daten erscheinen nie als Messwert**: jede Zeile nennt den neutralen Wert, den der Verbraucher bei Abwesenheit sieht.

| Quelle | Werte | Zeitbasis | Ziel heute | Stop / Verlust | Hand-Vorrang | Persistenz |
|---|---|---|---|---|---|---|
| **Musikalische Ereignisse** `MusicalFrame` (Erzeuger `PianoRollModel.musicalFrame`, EIN Aufrufer) | notes (Hz, amp 0…1) · rootPitchClass · tempoBPM · beatPhase 0…1 · masterLevel 0…1 | der EINE Sequencer-Tick (`pattern.onTick`, pro Step); `timestamp` = dieselbe Uhr wie Bio | `MetalBioView` (Farbe aus klingenden Noten, `musicLevel` → Energie), `SpectrumAnalysis` → Donuts, Header-Kacheln, Licht (Art-Net/sACN), ADM-OSC, `/echoelmusic/music/*` | Stop → `.silent` (leere Noten, `isSounding` false); hörbare Schwelle `audibleVelocityFloor` am Erzeuger | keiner nötig (reine Beobachtung) | keine |
| — davon **`sectionIndex` / `trackLevels`** | −1 / [] | — | **KEIN Erzeuger und KEIN Verbraucher** (`git grep -n "\.sectionIndex\|\.trackLevels" -- Sources` außerhalb Composer/Frame → 0) | — | — | — |
| **Audioanalyse** `AudioFeatureChannel` (Lock-Blatt, einmal pro Frame gelesen) | level · low · mid · high · centroid · onset, je 0…1; `onsetEnergy` mit 0,6-s-Abfall; exakte 0 unter `energyFloor` | Erzeuger-Takt (Datei nennt ~15 Hz); `maxAgeSeconds` 0,5 → älter gilt als still | `MetalBioView` (`audioHueBias`, `bassSwing`) — Montagepunkt lebt, liefert `.silent` | Alter > 0,5 s → `.silent` (#1244-Skip), kein Nachlaufen | keiner nötig | keine |
| **MIDI / MPE** | Noten + Bend/Press/Slide über `controllerEvents` (SPSC, EIN Verbraucher, monophon); Touch-Noten über `TouchToneChannel` (Lock-Blatt) | ereignisgetrieben; Touch-Blatt einmal pro Frame | Klang: `BioReactiveSynthVoice`; Bild: NUR Touch-Noten (Performer-Farben). **Kein MIDI-CC erreicht einen Visual-Parameter.** MPE IN ist keine Zone (#548/#713): zwei unabhängig ausdrucksgesteuerte Noten sind heute NICHT darstellbar | Note-off → Blatt läuft leer | — | keine |
| **Biofeedback** `latestBio` | HR · HRV · Kohärenz · Atemphase, `isMeasured`-Provenienz je Kanal | ~1 Hz Anwendung (10-Hz-Poll ist die Decke), `BioVisualParams.from` je Frame, Puls ≤ 3 Hz (`FlashGuard`) | `MetalBioView` (hue = Kohärenz-Drehung, pulseHz, Atem), Licht, OSC/ADM | Quelle weg → neutral (0,5 / kein Puls), nie „gemessen“ | — | keine |
| **Look-Parameter** (`visual.style/styleB/blend/intensity/detail/motion/spread/hue/saturation/preset`) | geklemmt in `VisualPreset.init` | — | `MetalBioView`-Uniforms (`intensity`, `ringDensity`, `motion`, `spread`, `hueShift`, `saturation`, `style*`, `blend`) | — | **Hand schreibt direkt** (39 `@AppStorage`-Bindings in 4 Dateien + `EchoelmusicApp.set`); Medien-Look über `MediaLookUndo` (Undo pro Prozess) | **GLOBAL** (`UserDefaults.standard`, Entscheidung 2026-09-27); projektgebunden: NICHTS heute — `Clip.mediaLook` erst mit MS4 |
| **Qualität** `ResourceGovernor` | Tier minimal…high → `visualDetailScale`, `reduceMotion` | Thermik/Batterie/gemessene FPS | `MetalBioView` DETAIL, nie die Bildrate (60 fps gepinnt) | — | `isAutomatic`/`manualTier` | keine |

Klärung global ↔ projektgebunden: Szene/Makros/Palette sind APP-Zustand (wie Photisms Presets); ein Song trägt
nur MEDIEN (Clip + Region, MS4) und künftig Automations-Kurven (Song-Automation über `TimelineStore.setSongAutomation`,
Schlüssel `track.<id>.<base>` — dafür müsste ein Visual-Makro ein registrierter Parameter sein). Ein geladenes Projekt
darf einen globalen Look nie still überschreiben; ein visueller Region-Eintritt schreibt den Look und Stop stellt
den Schnappschuss wieder her (MS5b) — das ist die einzige projektgetriebene Look-Änderung und sie ist deterministisch.

### 7.3 Vier Pakete, abhängig, je kleinster Umfang

**V1 — Datenwege klären, fehlende Erzeuger benennen (Messung, kein Feature).**
Nutzerzweck: bevor ein Makro „auf die Musik reagiert“, muss feststehen, WAS gemessen ist. Vorhanden: alles in 7.2.
Lücke: `sectionIndex`/`trackLevels` ohne Erzeuger UND ohne Verbraucher; `AudioFeatureChannel` ohne Erzeuger.
Umfang: (a) `sectionIndex` bekommt seinen Erzeuger aus der Komposition (die Sektion ist zur Kompositionszeit bekannt —
`BioComposer` reicht `sectionIndex` schon durch; der Roll kennt den Step → Sektion) ODER wird als bewusst ungenutzt
im Dateikopf markiert — Council entscheidet, nicht diese Zeile; (b) `trackLevels` bleibt LEER: ein Erzeuger braucht
Pegel-Taps je Stimme im Audiopfad (heute misst `AudioEngine` nur den Master, 60 Hz) = Audio-Arbeit, die vor jedem
Visual steht — **nicht in V1**; (c) `AudioFeatureChannel`-Erzeuger als Tap am MASTER-Ausgang (nie Mikrofon, #1302):
Render-Callback kopiert allokationsfrei in einen vorallokierten Ring, ein Timer außerhalb des Render-Threads rechnet
`AudioFeatureExtractor` und ruft `publish` — dieselbe Form wie `installMeterTap` + `startMeterPollTimer`.
Abhängigkeiten: `audio-thread-reviewer` PFLICHT für (c). Tests: reiner Extractor (Pegel, Bänder, Onset, Stille = exakte
0), Blatt-Alter → `.silent`, Wächter „`publish(` hat genau EINEN Produktions-Aufrufer“. Gerätenachweis: Master-Tap
kostet nichts Hörbares (Aussetzer-Zähler 0 über 10 min), thermischer Zustand unverändert.

**V2 — Kleine native Erprobung: EINE vorhandene Szene, drei nachweisbar wirksame Makros.**
Nutzerzweck: „Hits, Bass, Helligkeit“ SPIELBAR machen — Photisms HEAT/REACT/BRIGHT als Prinzip. Vorhanden:
`MetalBioView`-Uniforms, `audioHueBias`/`bassSwing`-Montage, `TouchVisualEnergy`-Abfallform. Lücke: kein Makro-Besitzer,
keine Zuordnung Signal→Uniform, die ein Test isolieren kann. Umfang: `Core/VisualMacro.swift` (rein): drei Makros
HEAT (onsetEnergy → `intensity`-Zuschlag + Puls, unter `FlashGuard`), REACT (Skalar, wie stark `low`/`masterLevel`
`motion`/`spread` treiben), BRIGHT (Belichtung = `saturation`/`intensity`-Basis) — jedes Makro mit Neutralwert, der bei
`.silent` EXAKT den heutigen Bildzustand ergibt (Regression: ein Frame ohne Audio ist bit-identisch zum Stand vor V2).
Abhängigkeiten: V1(c). Tests: Isolation (nur Bass → nur die Bass-Uniforms ändern sich), Neutralität bei Stille,
Klemmen/NaN an der Grenze, kein Makro liest den Bus im `body` (Hot-State-Wächter `TheMenuHostReadsNoHotStateTests`
erweitern). Gerätenachweis: Ambient (fast keine Onsets → HEAT ruhig), Trap (808-Sub → REACT sichtbar), House
(4/4 → periodische Hits ohne Flackern ≤ 3 Hz), Dub Techno (Delay-Schwänze → Abfall sichtbar); Framezeiten ≥ 58 fps
median bei `.balanced`. Keine Genre-Erkennung — die vier sind TESTMATERIAL.

**V3 — Presets, Übergänge, Hand-Vorrang konsistent.**
Nutzerzweck: Preset-Wechsel ohne Sprung, Hand gewinnt immer. Vorhanden: `visual.preset` + `applyVisualPreset`,
A/B `style/styleB/blend`, `VisualMoodMap.apply`. Lücke: ein Preset schreibt sechs Schlüssel hart; eine gleichzeitige
Hand-Bewegung wird überschrieben; Automation existiert nicht. Umfang: EIN Übergangs-Owner (Glide der sechs Werte über
~0,3–1 s, `motion`-Glide gibt es schon als Vorbild in `MetalBioView`), Regel „letzter Schreiber gewinnt, Hand bricht
einen laufenden Übergang ab“, und die drei Makros aus V2 als REGISTRIERTE Parameter (`EchoelParameterRegistry`), damit
Song-Automation (`track.<id>.<base>`-Form) und Modulationsmatrix sie erreichen — Automation < Hand, wie bei
`MasterVolumeField`. Abhängigkeiten: V2; Council wegen >1 Datei und Parameterregistrierung. Tests: Presetwechsel
während Hand-Drag (Hand-Wert bleibt), Presetwechsel während Automation (Automation setzt fort, kein Sprung),
Übergang endet exakt am Zielwert. Gerätenachweis: kein Picker-Freeze (10.76.41/50-Gesetz), Wechsel ohne Ruckler.

**V4 — Bildmaterial · externe Ausgabe · Export, je SEPARAT bewertet.**
· Bildmaterial: MS4/MS5 (Clip + Region + Wiedergabe) bleiben der Weg; Photisms Fünf-Farben-Palette wird NICHT
  nachgebaut, solange Farbe eine Drehung ist (§3.7) — erst ein Palettenmodell im Shader wäre die Voraussetzung.
· Externe Ausgabe: `ExternalDisplayScene` existiert; offener Gerätenachweis „Bühne ohne Bedienoberfläche“ (Slice 2).
  Kein Syphon/Spout auf iOS; NDI = Abhängigkeit = Founder-Hold. Kleinster Umfang: Blackout + Makros auf die Bühne
  spiegeln, nichts Neues rendern.
· Export: PNG-Standbild = neuer, kleiner Pfad (Texture-Readback außerhalb des Render-Threads, festes Seitenverhältnis
  aus der Bühnen-Größe); Video = REBUILD-Klasse mit Vorbedingung Geräte-Log-Review (F3). Budget: begrenzter Speicher
  (Ring von N Frames), Audio darf NIE warten (Encoder-Rückstau → Frames fallen lassen, Audio läuft weiter).

### 7.4 Mindest-Abnahmen für V1–V4 (Modelltests ersetzen keine Geräteprüfung)

1. Veraltete Medienanalyse nach neuer Auswahl / Disappear / Projektwechsel: bereits gepinnt (4e, Anspruch 5 in
   `TheMediaLookHasOneWriterTests`; Generation 5.1) — für V2 erweitern: ein Makro-Wert überlebt keinen Projektwechsel.
2. Isolierte Signale, eindeutige Reaktion: je Signal genau eine Uniform-Menge; Stille = Neutral (bit-identisch).
3. Presetwechsel während Hand und während Automation (V3).
4. Stop, Quellenverlust, Neustart ohne veraltete Trigger: `maxAgeSeconds`-Skip + Ring-Reset in `stop()`; kein Onset
   nach Stop.
5. MPE mit zwei unabhängig ausdrucksgesteuerten Noten: **BLOCKIERT** durch den monophonen Verbraucher
   (`PLAN_MPE_ZONES_2026-09-01.md`); als Abnahme aufnehmen, als heute nicht bestehbar markieren.
6. Externe Ausgabe ohne Bedienoberfläche: Gerätelauf mit Beamer/AirPlay, Bühne zeigt nur das Bild.
7. Langsamer Encoder: Speicher gedeckelt, Aussetzer-Zähler 0 (nur V4-Export).
8. A/V-Offset und Drift: Marker-Klick + Blitz-Frame auf der Aufnahme, Offset < 40 ms, Drift < 1 Frame/min (V4).
9. Langlauf 30 min am Zielgerät: Framezeiten (median/p99), Audioaussetzer, Speicher, thermischer Tier — Baseline
   ZUERST ohne V2 messen, Budget = Baseline + höchstens 10 % Framezeit, 0 zusätzliche Aussetzer, kein Tier-Abstieg
   in `.balanced` unter Raumtemperatur.

Zielgerät: das Founder-iPhone (die Geräte-Session ist das knappe Gut; Simulator zählt für keine Zeile hier).
