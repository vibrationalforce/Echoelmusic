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
