# CLAUDE.md - Persistent Memory for Echoelmusic

> Diese Datei wird automatisch von Claude Code gelesen. Update nach JEDER Session!

---

## PROJEKT-STATUS (LESE MICH ZUERST!)

**Letzte Aktualisierung:** 2025-12-10
**Aktueller Branch:** `claude/persistent-chat-state-01JaeSpxowjLhsYUQmPdA7Tf`
**Phase:** Phase 2 abgeschlossen - MIDI 2.0, MPE, Spatial Audio

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

---

## WAS ALS NAECHSTES KOMMT

1. **Phase 3:** Spatial Audio Rendering, Visual Feedback, LED Control
2. **Desktop UI:** MainWindow, TrackView, MixerView (JUCE)
3. **MIDI Engine Integration**
4. **Project Save/Load System**
5. **VST3/AUv3 Plugin Hosting**

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

### 2025-12-10
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
