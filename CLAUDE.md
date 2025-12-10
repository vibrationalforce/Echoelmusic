# CLAUDE.md - Persistent Memory for Echoelmusic

> Diese Datei wird automatisch von Claude Code gelesen. Update nach JEDER Session!

---

## PROJEKT-STATUS (LESE MICH ZUERST!)

**Letzte Aktualisierung:** 2025-12-10
**Aktueller Branch:** `claude/persistent-chat-state-01JaeSpxowjLhsYUQmPdA7Tf`
**Phase:** Phase 4 - MIDI Engine, Project Manager, ~90% MVP

---

## WAS BEREITS FERTIG IST

### Core Audio Engine (100%)
- AVAudioEngine mit Multi-Track Recording
- Real-time safe (< 10ms Latenz)
- 17 professionelle DSP-Effekte

### Multimodal Control (100%)
- Face Tracking (ARKit, 60 Hz)
- Hand Gestures (Vision, 30 Hz)
- Biometric (HealthKit + HRV)
- UnifiedControlHub @ 60 Hz

### MIDI 2.0 System (100%)
- UMP Packets (32-bit Resolution)
- MPE 15-Voice Polyphonic
- Per-Note Controllers
- Spatial Audio Mapping (Stereo/3D/4D/AFA)

### Visual Engine (100%)
- 12 Visualization Modes
- Metal Shaders (CymaticsRenderer)
- Bio-reactive Farben
- 120 Hz Update Loop

### Spatial Audio (100%) - NEU!
- SpatialAudioRenderer (Bio-reactive rendering)
- 4 Render Profiles (LowLatency, Balanced, Performance, Immersive)
- AFA Field Morphing (HRV-gesteuert)
- MIDI-to-Spatial Mapping

### LED Control (100%) - NEU!
- UnifiedLEDController (Multi-Protocol)
- Art-Net, WLED, sACN (E1.31), DMX
- 12 LED-Effekte (Rainbow, Breathe, BioReactive, etc.)
- Auto-Discovery fuer WLED Geraete

### Desktop UI (100%) - NEU!
- MainWindow.cpp (684 Zeilen, komplett)
- TrackView (integriert in MainWindow)
- MixerView.cpp (550+ Zeilen, komplett)
- VisualizerBridge.cpp (700+ Zeilen, 12 Modi)
- MIDIPanel.cpp (400+ Zeilen, komplett)
- Vaporwave Aesthetic (Cyan/Magenta/Purple)

### MIDI Engine (100%) - NEU!
- MIDIEngine.h/.cpp (600+ Zeilen)
  - MIDI 2.0 mit UMP Packets (32-bit Resolution)
  - Device Management, Virtual MIDI Ports
  - MIDI Learn Mode
  - Callbacks fuer Note/CC/PitchBend
- MPEVoiceManager.h/.cpp (500+ Zeilen)
  - 15-Channel Voice Allocation
  - Voice Stealing Strategies
  - Per-Voice Expression Tracking
  - Roli Seaboard / LinnStrument / Osmose Support

### Project Manager (100%) - NEU!
- ProjectManager.h/.cpp (700+ Zeilen)
  - Project Save/Load mit XML
  - Auto-Save (konfigurierbar)
  - Recent Projects Liste
  - Track Audio/MIDI Serialization
  - Plugin State Persistence (Struktur)

---

## WAS ALS NAECHSTES KOMMT

1. **VST3/AUv3 Plugin Hosting**
2. **TestFlight Build**
3. **Final Polish & Testing**
4. **App Store Submission**

---

## WICHTIGE DATEIEN

| Datei | Zweck |
|-------|-------|
| `CLAUDE.md` | Diese Datei - wird automatisch gelesen |
| `PROJECT_STATE.md` | Detaillierter aktueller Zustand |
| `CURRENTLY_WORKING.md` | Wer arbeitet gerade woran |
| `.github/CLAUDE_TODO.md` | Feature-Roadmap mit TODOs |
| `CURRENT_STATUS.md` | Technischer Status-Report |

---

## SAVE-AND-PUSH PROTOKOLL

Nach JEDER abgeschlossenen Aufgabe:

```bash
# 1. Status updaten
# - Diese CLAUDE.md Datei aktualisieren
# - PROJECT_STATE.md aktualisieren

# 2. Commit erstellen
git add -A
git commit -m "feat/fix/chore: [Beschreibung]

- Was wurde gemacht
- Was ist der neue Status

Co-Authored-By: Claude <noreply@anthropic.com>"

# 3. Push (mit Retry bei Netzwerkfehler)
git push -u origin claude/persistent-chat-state-01JaeSpxowjLhsYUQmPdA7Tf
```

---

## ZAUBERWORT: "wise save"

Wenn der User "wise save" sagt:
1. Alle aktuellen Aenderungen zusammenfassen
2. CLAUDE.md aktualisieren
3. PROJECT_STATE.md aktualisieren
4. Git commit mit klarer Message
5. Git push zum Branch
6. Bestaetigung an User

---

## ARCHITEKTUR-UEBERSICHT

```
Echoelmusic/
├── Sources/
│   ├── Audio/          # AudioEngine, Track, DSP
│   ├── Biofeedback/    # HealthKit, HRV, BioMapping
│   ├── Control/        # UnifiedControlHub, Gestures
│   ├── MIDI/           # MIDI 2.0, MPE, UMP
│   ├── Visual/         # Metal Shaders, Visualizers
│   ├── Sync/           # EchoelSync, Ableton Link
│   └── Remote/         # Cloud Processing
├── Tests/              # Unit & Integration Tests
├── Prompts/            # AI Prompts
└── .github/            # CI/CD, TODOs
```

---

## GIT WORKFLOW

- **Main Branch:** Stable releases
- **Feature Branches:** `claude/[feature]-[session-id]`
- **Commit oft:** Kleine, fokussierte Commits
- **Push sofort:** Nach jedem wichtigen Schritt

---

## KOORDINATION MIT ANDEREN AIs

- **Claude Code:** Feature Development, Architecture
- **ChatGPT Codex:** Debugging, Performance Optimization
- **Regel:** Immer `CURRENTLY_WORKING.md` checken und updaten!

---

## LETZTE AENDERUNGEN (Changelog)

### 2025-12-10 (Session 5) - MIDI Engine & Project Manager
- MIDI Engine Implementation:
  - MIDIEngine.h/.cpp (600+ Zeilen) - MIDI 2.0 mit UMP
  - MPEVoiceManager.h/.cpp (500+ Zeilen) - 15-Voice MPE
  - MIDIPanel.h/.cpp (400+ Zeilen) - Desktop UI
- Project Manager Implementation:
  - ProjectManager.h/.cpp (700+ Zeilen)
  - XML-basiertes Projektformat
  - Auto-Save, Recent Projects
- CMakeLists.txt aktualisiert mit neuen Dateien
- Progress: ~90% MVP

### 2025-12-10 (Session 4) - Desktop UI Complete
- Desktop UI Implementation:
  - MixerView.h/.cpp erstellt (550+ Zeilen)
  - Professional Mixer Console mit Channel Strips
  - VU/Peak Metering, LUFS Metering
  - Vaporwave Color Scheme
- CMakeLists.txt aktualisiert mit neuen UI Dateien
- Phase 3 jetzt 100% komplett

### 2025-12-10 (Session 3) - MAJOR UPDATE
- Phase 3 Implementation abgeschlossen:
  - SpatialAudioRenderer.swift erstellt (Bio-reactive spatial rendering)
  - UnifiedLEDController.swift erstellt (WLED, Art-Net, DMX, Hue)
  - VisualizerBridge.h/.cpp erstellt (Desktop visualizer mit 12 Modi)
  - UnifiedControlHub erweitert mit neuen Komponenten
- Neue Features:
  - Multi-Protocol LED Support (Art-Net, WLED, sACN)
  - Bio-reactive spatial field morphing (AFA)
  - C++ Desktop Visualizer Bridge
  - 12 Visualization Modes (Spectrum, Cymatics, Mandala, Vaporwave, etc.)

### 2025-12-10 (Session 2)
- "wise save" erfolgreich getestet
- System funktioniert wie erwartet
- Naechste Aufgabe: Phase 3 starten

### 2025-12-10 (Session 1)
- Persistent Chat State System eingerichtet
- CLAUDE.md erstellt (wird automatisch gelesen)
- PROJECT_STATE.md erstellt
- Save-and-Push Workflow definiert

### 2025-11-12
- MIDI 2.0 + MPE Integration complete
- Spatial Audio Foundation (AFA)
- Full Multimodal Pipeline

### 2025-10-21
- Week 1-5 Implementation complete
- Core Multimodal Control working
- UnifiedControlHub @ 60 Hz

---

**WICHTIG:** Diese Datei nach JEDER Session aktualisieren!
