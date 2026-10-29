# Echoelmusic - Vollständige Feature-Liste

**Stand:** 2026-10-29 (Phase 3 komplett - 75% MVP)  
**Repo:** `vibrationalforce/Echoelmusic` (früher `blab-ios-app`)  
**Interne Struktur:** Ordner heißen noch `Sources/Blab/` und `Tests/BlabTests/`

---

## Kernidentität

**Echoelmusic** ist ein professionelles bio-reaktives Musiksystem für iPhone, bei dem dein Körper das Instrument ist. Dein Herzschlag, Atem und deine Bewegungen werden in Echtzeit zu Musik, visuellen Effekten und Lichtinstallationen.

**Konzept:** Breath → Sound → Light → Consciousness

**Gebaut für:** Installation · Event · Content · Kino · Theater · Performance

**Wissenschaftlich fundiert, nicht esoterisch** - keine Wellness-Begriffe, keine Chakren, keine Solfeggio-Frequenzen.

---

## 10 Implementierte Hauptsysteme

### 1. Audio Engine ✅

**Kern:**
- Real-time Voice Processing (AVAudioEngine)
- FFT Frequenzanalyse
- YIN Pitch Detection Algorithmus
- Audio Effects: Reverb, Delay, Compressor, Filter
- Modulare Node-Graph-Architektur

**Synthesizer:**
- Polyphoner Synth (8 Stimmen, `PolySynthVoice`)
- Sub-Bass Voice (`SubBassVoice`)
- Vollständiger Patch-Editor (`soundPanel` hinter Sound-Chip)
- Preset-System (Favorites/Community/Save-as)

**Binaural Beat Generator:**
8 Brainwave-Zustände: Delta (0.5-4 Hz), Theta (4-8 Hz), Alpha (8-13 Hz), Beta (13-30 Hz), Gamma (30-100 Hz), SMR, Schumann Resonance, 40 Hz Gamma

**GELÖSCHT seit #1302:** Audio-Eingang (Mikrofon), Multi-Track Recorder, Vocal Chain

---

### 2. Spatial Audio System ✅ (Phase 3)

**6 Spatial Modi:**
1. Stereo - Standard L/R
2. 3D Sphere - 61-Punkt Fibonacci-Verteilung
3. 4D Orbital - Rotation + Elevation
4. AFA (Acoustic Field Array)
5. Binaural - Brainwave Entrainment
6. Ambisonics - Higher-Order Ambisonics

**Head Tracking:**
- 60 Hz Tracking (CMMotionManager)
- Dynamische 3D-Audio-Anpassung
- iOS 19+ AVAudioEnvironmentNode Support
- AirPods Pro Integration

**Dateien:**
- `Spatial/SpatialAudioEngine.swift`
- `Spatial/ARFaceTrackingManager.swift` (⚠️ Face Tracking GELÖSCHT #1301)
- `Spatial/HandTrackingManager.swift`

---

### 3. Visual Engine ✅

**5 Visualisierungsmodi:**
1. Cymatics - Schallwellen-Muster (Chladni-Platten-Stil)
2. Mandala - Geometrische Muster basierend auf Frequenzen
3. Waveform - Klassische Wellenform
4. Spectral - Spektrogramm
5. Particles - Partikel-System

**Features:**
- Metal-beschleunigte Grafik (60+ FPS, 120 FPS auf ProMotion)
- Bio-reaktive Farben (HRV → Hue)
- MIDI/MPE Parameter Mapping
- Flash-Safety: Max 3 Hz (W3C WCAG Epilepsie-Compliance)

**Dateien:**
- `Visual/MIDIToVisualMapper.swift` ⭐ Phase 3
- `Visual/CymaticsRenderer.swift`
- `Visual/VisualizationMode.swift`
- `Visual/Modes/` (5 Modi)
- `Views/MetalBioView.swift`

---

### 4. LED/Lighting Control ✅ (Phase 3)

**Ableton Push 3:**
- 8×8 RGB LED Grid (64 LEDs)
- SysEx-Kommunikation
- 7 LED Patterns: Spiral, Wave, Pulse, Breathe, Rainbow, Strobe, Chase

**DMX/Art-Net:**
- 512 DMX Kanäle
- UDP Socket (Port 6454)
- WS2812/RGBW LED Strip Support
- 6 Light Scenes: Sunrise, Sunset, Ocean, Forest, Desert, Meditation

**sACN (E1.31):**
- Professionelles Lichtnetzwerk-Protokoll
- Streaming ACN Support

**Bio-reaktive Steuerung:**
- HRV → Lichtfarben
- Atemrhythmus → Pulsgeschwindigkeit
- Stimmhöhe → Helligkeit

**Dateien:**
- `LED/Push3LEDController.swift` ⭐ Phase 3
- `LED/MIDIToLightMapper.swift` ⭐ Phase 3

---

### 5. MIDI System ✅

**MIDI 2.0:**
- Vollständiges MIDI 2.0 Protokoll
- 32-Bit Auflösung
- Bidirektionale Kommunikation

**MPE (MIDI Polyphonic Expression):**
- MPE OUTPUT ✅ (#713, schaltbar)
- MPE INPUT ❌ (nicht gebaut - #548)
- 15 MPE Zonen (registriert, nicht verdrahtet)
- Per-Note Kontrolle: Pitch Bend, Pressure (Press), Timbre (Slide)

**MIDI Export:**
- `MIDIFileExporter` - funktionierend und getestet
- Tür: Export-Schacht in UI

**Dateien:**
- `MIDI/MIDI2Manager.swift`
- `MIDI/MPEZoneManager.swift`
- `MIDI/MIDI2Types.swift`
- `MIDI/MIDIToSpatialMapper.swift`

---

### 6. Biofeedback System ✅

**Bio-Quellen (4):**
1. **HealthKit** - Heart Rate, HRV (Abfrage alle 500ms, Sensor 4-5s)
2. **Kamera rPPG** - Remote Photoplethysmography (funktioniert auf Gerät, kein externes HW nötig)
3. **Universal BLE HR (0x180D)** - Polar, Wahoo, Garmin, jeder Standard-Gurt
4. **Demo-Generator** - für Testing

**Gemessene Parameter:**
- Heart Rate (bpm)
- HRV (Heart Rate Variability)
- HeartMath Coherence (wissenschaftlich validiert)
- Atemrhythmus (Phase & Tiefe)
- RMSSD, SDNN, pNN50 (opt-in, Clinical HRV Detail)

**Bio → Klang Mappings (LIVE - alle haben Produzenten):**
- Coherence → Filter Cutoff, Brightness, Harmonicity, Noise Level
- HRV → Brightness
- Heart Rate → Vibrato Depth & Rate, Brightness
- Breath Phase → Amplitude (Atem-Anschwellen)

**Geschützte DSP-Algorithmen (READ-ONLY):**
- BioEventGraph (DELLY, Rausch 2012)
- HilbertSensorMapper (1D→2D Hilbert Curve)
- BioSignalDeconvolver (Tracy, Rausch 2017)

**Dateien:**
- `Bio/HealthKitBioPublisher.swift`
- `Bio/CameraRPPGBioPublisher.swift`
- `Bio/BioEventGraph.swift` (PROTECTED)
- `Biofeedback/HealthKitManager.swift`
- `Biofeedback/BioParameterMapper.swift`

⚠️ **GELÖSCHT #1301:** Face Tracking, Body Pose, alle Gesichts-/Kopf-/Körper-Felder

---

### 7. Input Modalities ✅

**Aktive Inputs:**
- ✅ Voice (Mikrofon + Pitch Detection) - ⚠️ GELÖSCHT #1302
- ✅ Biometrics (HealthKit, rPPG, BLE)
- ✅ MIDI Input (mono voice, Noten + Pitch Bend + Expression)
- ✅ OSC Input (#1255 - Remote Control)
- ❌ Face Tracking (GELÖSCHT #1301)
- ❌ Hand Gestures (gebaut, nicht verdrahtet)
- ❌ Head Tracking (gebaut, nicht verdrahtet)

**Dateien:**
- `MicrophoneManager.swift` - GELÖSCHT #1302
- `Unified/GestureRecognizer.swift`
- `Unified/GestureToAudioMapper.swift`
- `Unified/FaceToAudioMapper.swift` - GELÖSCHT #1301
- `Unified/GestureConflictResolver.swift`

---

### 8. Unified Control Hub ✅ (Phase 3 - ZENTRAL)

**Das Herzstück:**
- 60 Hz Control Loop
- Multi-modale Sensor Fusion
- Priority-based Input Resolution
- Real-time Parameter Distribution

**Orchestriert:**
- Audio (Synth, Effects)
- Spatial Audio (6 Modi)
- Visual (5 Modi)
- LED (Push 3, DMX, sACN)
- MIDI Output

**Dateien:**
- `Unified/UnifiedControlHub.swift` ⭐ Phase 3
- Konstruiert beim App-Start (`EchoelmusicApp.swift`)

**Architecture:**
```
Bio + Gesten + Stimme + MIDI
           ↓
  Unified Control Hub (60 Hz)
           ↓
  ┌────────┼────────┐
  ↓        ↓        ↓
Audio   Visual    LED
```

---

### 9. Recording System ✅ (80% Complete)

**Timeline & Workstation:**
- Multi-track Timeline Editor (`WorkstationView`)
- Audio Import (#F1 - Import Audio)
- Audio Playback (`AudioLanePlayer`)
- MIDI Tracks (arrangieren)
- Mixer (volle Mix-Kontrolle)

**Session Management:**
- `TimelineStore` - Projektdaten
- `ClipStore` - Clip-Verwaltung
- Persistierung als JSON

**Export:**
- MIDI Export ✅ (funktioniert)
- Audio Export (`SingleExport` - WAV/M4A/CAF)
- Master Export (LUFS mastering)

**GELÖSCHT #1302:**
- Multi-Track Recorder (Datei)
- Audio-Eingang (kein Mikrofon)

**Dateien:**
- `Recording/RecordingEngine.swift` - GELÖSCHT #1302
- `Recording/Session.swift`
- `Recording/Track.swift`
- `Recording/ExportManager.swift`
- `Recording/AudioFileImporter.swift`
- `Recording/MixerView.swift`
- `Sequencer/TimelineStore.swift` (das ECHTE Session-System)

---

### 10. UI Components ✅

**Root View:**
- `Studio/EchoelStudioView.swift` - Das EINE Instrument
- Menu-Bar mit Chips (jeder öffnet ein Dropdown-Panel)
- `WorkspaceView` - Workstation-Root seit 2026-09-30

**Panels:**
- `soundPanel` - Patch Editor (hinter Sound-Chip)
- `bioPanel` - Bio-Feedback (hinter Puls-Pille)
- `mixerPanel` - Mixer-Kontrollen
- `visualPanel` - Visual-Einstellungen
- `masterPanel` - Master-Controls
- `moodPanel` - Mood-Parameter
- `tempoToolsPanel` - Tempo-Tools
- `effectsPanel` - FX-Chain

**Komponenten:**
- `BioMetricsView.swift` - Bio-Display
- `SpatialAudioControlsView.swift` - Spatial Controls
- `HeadTrackingVisualization.swift` - Head Tracking Display
- `FloatingVisualWindow` - Schwebendes Visual-Fenster
- `ParticleView.swift` - Partikel-System

**UI-Regel:**
- `EchoelValueField` für ALLE numerischen Parameter (kein Slider/Stepper)
- Tap-to-Type mit eigenem Nummernpad (`EchoelNumberPad`)
- Pinch-to-Zoom (Dynamic Type)

---

## Offene Protokolle & Integration

### OSC (Open Sound Control)

**Output (`OSCSender`):**
```
/echoelmusic/bio/heart/bpm
/echoelmusic/bio/heart/hrv
/echoelmusic/bio/heart/rmssd (opt-in)
/echoelmusic/bio/heart/sdnn
/echoelmusic/bio/heart/pnn50
/echoelmusic/bio/breath/rate
/echoelmusic/bio/breath/phase
/echoelmusic/bio/coherence
/echoelmusic/bio/synthetic (1=Demo, 0=Körper)
/echoelmusic/bio/event/breath/inhale | exhale
/echoelmusic/bio/event/heartbeat (nur BLE-Gurt)
/echoelmusic/mod/<key>
/echoelmusic/music/{tempo,key/root,beat/phase,level/master,note/count}
```

**Input (`OSCReceiver` #1255):**
```
/echoelmusic/ctrl/{bpm,key,scale,genre,visualStyle,blackout}
```
Port: 8001, Opt-in AUS, Sender-Allowlist

### ADM-OSC (Immersive Object)

**Output (`ADMOSCSender`):**
```
/adm/obj/{n}/*
```

**Input (`ADMObjectInput` seit Spatial S1):**
Object n = Track n

### Art-Net & sACN

- Art-Net: 512 Channels, UDP Port 6454
- sACN (E1.31): DMX over E1.31

---

## AUv3 Instrument Plugin ✅

**Seit #1385 (2026-09-20):**
- Target: `EchoelmusicAUv3`
- Type: `aumu` / `echl`
- Reines Swift, in App eingebettet
- **LÄDT in AUM** (device-verified #1386)
- Logic/GarageBand: nicht verifiziert

**Scope:**
- Echoel IST ein Plugin
- Echoel HOSTET nichts (kein AUv3 Host)

---

## Modulations-Matrix ✅

**Seit #1250:**
- Routing-Fläche in `PatchbayView`
- Body → Parameter Mappings
- Default-Matrix: LEER (keine Routes ohne User-Action)

**Registrierte Ziele:**
- `ModDestinationKey.tempo`
- Alle automatisierbaren Synth-Parameter (Projektion von `PolySynthVoice.automatableBases`)

**Engine:**
- 100ms Update-Loop
- Läuft beim App-Start
- Persistiert in Projekt-Dokument

**Dateien:**
- `Core/ModulationEngine.swift`
- `PatchbayView.modulationSection` (UI)

---

## Tempo-System (T1·T2·T3 Invariant)

**Zwei Modi:**
1. **Flow** - Tempo folgt Puls (40-160 BPM, auto)
2. **Loop** - User stellt Tempo fest (Studio Lock)

**Quellen (4):**
1. Nutzer-Geste (Lock, Field-Edit, Tap, Projekt)
2. Flow-Servo (nur bei `.flowFree`)
3. Automation Lane
4. Modulation Route (`.modulationRoute`)

**Geloggt:**
Jede Tempo-Änderung mit `tempoSource=`

**Wächter:**
`Tests/CISmoke/TempoInvariantTests.swift`

---

## Plattform-Support

**Aktuell ausgeliefert:**
- ✅ iPhone (universal)

**Kompiliert, nicht eingebettet:**
- ⏳ Apple Watch (Target existiert, kein Transport Phone↔Watch)

**Geplant:**
- 🔵 iPad (braucht: funktionierende Bio-Quelle + Adaptivität)
- 🔵 Vision/XR (natürliche Ausgabe-Plattform)
- 🔵 Mac (kein Target)

**iOS-Versionen:**
- Minimum: iOS 15.0
- Empfohlen: iOS 16+
- Optimiert: iOS 19+ (Apple Spatial Audio Features)

**Device Family:**
- Phone only (`TARGETED_DEVICE_FAMILY = "1"`)
- 5 Settings + Wächter zu ändern für iPad

---

## Code-Metriken

**Dateien:**
- 60+ Swift-Dateien (`git ls-files 'Sources/**/*.swift' | wc -l`)
- 0 Metal-Dateien (Shader inline kompiliert)

**Zeilen:**
- 15.000+ Zeilen Swift
- Phase 3: 2.228 Zeilen (optimiert)

**Qualität:**
- 0 Force Unwraps ✅
- 0 Compiler Warnings ✅
- ~40% Test Coverage (Ziel: >80%)

**Dependencies:**
- ZERO externe Dependencies
- 100% Swift
- Frameworks: AVFoundation, CoreAudio, Metal, HealthKit, CoreMotion, ARKit, Vision, CoreMIDI, Network, WeatherKit

---

## Performance Targets

| Metric | Target | Aktuell |
|--------|--------|---------|
| Control Loop | 60 Hz | ✅ 60 Hz |
| Visual FPS | 60 FPS (gepinnt) | ✅ 60 FPS |
| Audio Latency | <10ms | ✅ <10ms |
| CPU Usage | <30% | ✅ |
| Memory | <200MB | ✅ |
| Bio Apply Rate | ~1 Hz (dedupliziert) | ✅ ~1 Hz |

---

## Was NICHT da ist (bewusst)

**GELÖSCHT (Founder-Entscheidung):**
- ❌ Audio-Eingang (#1302 - "kein Mikrofon")
- ❌ Video Capture (#1304 - "kein Video Capture")
- ❌ Face Tracking (#1301 - "Face komplett entfernen")
- ❌ Multi-Track Recorder (#1302 - Datei gelöscht)
- ❌ Beat-Maker / Drums (#166/#167 - klingt nicht)
- ❌ Piano Roll Editor (#475 - View gelöscht)
- ❌ RTMP Broadcast (nie verlinkt)
- ❌ Harmonizer (#1305 - "kein Harmonizer")
- ❌ Granularsynthese (#1305)
- ❌ Autotune (#1305)

**Nicht verdrahtet (vorhanden, aber unerreichbar):**
- Hand Tracking (Vision Framework - gebaut, keine Tür)
- Head Tracking (CMMotionManager - gebaut, keine Tür)
- Mehrere unverdrahtete DSP-Kerne (siehe `CLAUDE.md` Register)

**ROADMAP (geplant):**
- Phase 5: AI Composition Layer (0%)
- Phase 6: Networking & Collaboration
- Phase 7: AUv3 Plugin Enhancement (Plugin ist da, Hosting nicht)
- Phase 8: Vision Pro / XR
- Phase 9: Distribution & Publishing
- Phase 10: Polish & Release

---

## Git-Struktur

**Branch:** Run `git branch --show-current`  
**Remote:** `github.com/vibrationalforce/Echoelmusic`  
**Team ID:** via `APPLE_TEAM_ID` Secret  
**App ID:** 6757957358  
**Bundle:** `com.echoelmusic.app`  
**App Group:** `group.com.echoelmusic`

**Targets (5):**
1. Echoelmusic (App, universal)
2. EchoelmusicWidget (Widget)
3. EchoelmusicWatch (Watch, nicht eingebettet)
4. EchoelmusicAUv3 (AUv3 Instrument, seit #1385)
5. EchoelmusicTests + CISmoke (Tests)

---

## Dokumentation

**Im Repo:**
- `README.md` - Haupt-Übersicht
- `CLAUDE.md` - Entwicklungs-Gesetze (immer-geladen)
- `.claude/rules/` - Engineering/Swift/Audio Rules
- `memory/` - Persistente Knowledge Base
- `docs/dev/` - Entwicklungs-Docs
- `scratchpads/` - Session-Logs

**Wichtige Docs:**
- `docs/dev/FOUNDER_PRODUCT_LAW.md` - Produkt-Gesetz
- `docs/dev/HISTORY_ARCHIVE.md` - Was gelöscht wurde & warum
- `docs/dev/FEATURE_STATUS.md` - Was funktioniert/fehlt
- `memory/project_knowledge.md` - Projekt-Kern
- `Tests/CISmoke/CLAUDE.md` - Test-Wächter-Disziplin

---

## Für neue Chat-Sessions

**Repo-Name:** Echoelmusic  
**Interne Ordner:** `Sources/Blab/` und `Tests/BlabTests/` (noch nicht umbenannt)  
**Package Name:** "Blab" (in `Package.swift`)  

**Status:** Phase 3 komplett, 75% MVP, alle 10 Hauptsysteme implementiert

**Wichtigste Dateien beim Session-Start:**
1. `CLAUDE.md` - Die Gesetze
2. `memory/project_knowledge.md` - Projekt-Kern
3. `memory/decisions.md` - Entscheidungen
4. `scratchpads/SESSION_LOG.md` (tail) - Neueste Sessions
5. Dieses Dokument - Feature-Übersicht

---

_Erstellt: 2026-10-29_  
_Für: Neue Chat-Sessions nach Repo-Umbenennung_
