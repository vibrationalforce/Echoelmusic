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
