# AGENTS.md — Echoelmusic Zone-Based Optimization

> **Ausgangslage:** 98K LOC, 126 Dateien, 24 davon 1.000+ Zeilen.
> **Nach SCAN-Phase:** 55K LOC, 89 Dateien, 16 davon 1.000+ Zeilen.
> **Gelöscht:** 26.415 LOC (34 Source-Dateien + 2.859 LOC tote Tests)
>
> **Ansatz:** 5 Zonen, klare Reihenfolge, eine Zone pro Session.

---

## Zone Overview (nach SCAN-Cleanup)

| Zone | Ordner | Dateien | LOC | 1K+ Dateien | Prio | Status |
|------|--------|---------|-----|-------------|------|--------|
| **Z1** Audio Core | Audio/, DSP/, Sound/ | 49 | ~30.000 | 8 | KRITISCH | SCAN ✓ |
| **Z2** Input | MIDI/, Recording/ | 5 | ~3.900 | 1 | HOCH | SCAN ✓ |
| **Z3** Visual | Video/, Views/ | 13 | ~14.300 | 7 | MITTEL | SCAN ✓ |
| **Z4** Platform | Export/ | 1 | ~638 | 0 | MITTEL | SCAN ✓ |
| **Z5** Foundation | Business/, Theme/, Core/, Root | 16 | ~5.600 | 0 | NIEDRIG | SCAN ✓ |

---

## Z1: Audio Core (KRITISCH) — SCAN complete, CLEAN next

### Remaining 1K+ Files (CLEAN phase targets)

| Datei | LOC | Problem |
|-------|-----|---------|
| `Audio/ProSessionEngine.swift` | 1.445 | 42 Methoden, Session-Management zu groß |
| `Audio/ProMixEngine.swift` | 1.286 | Mixer ohne klare Trennung |
| `Audio/BreakbeatChopper.swift` | 1.110 | Standalone, aber monolithisch |
| `Sound/TR808BassSynth.swift` | 1.430 | Synth + Sequencer vermischt |
| `Sound/SynthPresetLibrary.swift` | 1.326 | Preset-Daten + Logik vermischt |
| `Sound/EchoelBass.swift` | 1.255 | Einzelner Synth, zu groß |
| `Sound/EchoelBeat.swift` | 1.234 | Drum Machine, monolithisch |
| `DSP/EchoelDDSP.swift` | 1.105 | Bio-Synth Kern — DO NOT SIMPLIFY |
| `DSP/ClassicAnalogEmulations.swift` | 1.001 | 8 hardware emulations — production-ready |

### Deleted in SCAN (Z1)

- `DSP/AdvancedDSPEffects.swift` (1.245) — 0 refs, stub
- `DSP/EchoelCore.swift` (643) — TheConsole duplicated AnalogConsole
- `Audio/AudioGraphBuilder.swift` (549) — 0 refs
- `Audio/UltraLowLatencyBluetoothEngine.swift` (1.490) — 0 refs
- `Audio/VoiceProfileSystem.swift` (1.110) — 0 refs
- `Audio/VocalAlignmentView.swift` (520) — 0 refs
- `Sound/SynthesisEngineType.swift` (204) — only test refs
- `Audio/EnhancedAudioFeatures.swift` trimmed 1.522→167 (6 dead classes removed)

### DSP/ Verdict: 7/7 production-ready. No further cleanup needed.

### CLEAN-Phase Priorität

1. ProSessionEngine (1.445) — extract TrackManager, AutomationEngine, TransportManager
2. ProMixEngine (1.286) — extract routing from metering from automation
3. SynthPresetLibrary (1.326) — move preset data to JSON
4. TR808BassSynth (1.430) — extract sequencer logic

---

## Z2: Input (HOCH) — SCAN complete

### Remaining Files

| Datei | LOC | Status |
|-------|-----|--------|
| `MIDI/TouchInstruments.swift` | 1.376 | AKTIV — needs splitting |
| `MIDI/MIDIController.swift` | 362 | AKTIV |
| `Recording/RecordingEngine.swift` | 891 | AKTIV |
| `Recording/MicrophoneManager.swift` | ~200 | AKTIV |

### Deleted in SCAN (Z2): 13 files, ~6.000 LOC

AudioToQuantumMIDI, MIDI2Types, MIDIToSpatialMapper, PianoRollView, QuantumMIDIOut, VoiceToQuantumMIDI, AudioFileImporter, MixerFFTView, RecordingControlsView, RecordingWaveformView, SessionBrowserView, AudioInterfaceRegistry, HardwareTypes, MIDIControllerRegistry, VideoHardwareRegistry

### CLEAN-Phase: Split TouchInstruments (1.376 → ~400 pro Datei)

---

## Z3: Visual (MITTEL) — SCAN complete

### Remaining 1K+ Files

| Datei | LOC | Problem |
|-------|-----|---------|
| `Views/DAWArrangementView.swift` | 1.530 | **44 @State Variablen** — Top priority split |
| `Views/VideoEditorView.swift` | 1.514 | Video+Audio+Effects in einer View |
| `Video/ProColorGrading.swift` | 1.524 | Color Science + LUTs + UI vermischt |
| `Video/CameraManager.swift` | 1.321 | Kamera-Management |
| `Video/BPMGridEditEngine.swift` | 1.099 | Beat-Grid Editing |
| `Video/VideoEditingEngine.swift` | 1.007 | Video-Editing |

### Deleted in SCAN (Z3): 6 files, ~5.000 LOC

BackgroundSourceManager, ChromaKeyEngine, MultiCamStabilizer, VideoProcessingEngine, AudioRoutingMatrixView, MIDIRoutingView

---

## Z4: Platform (MITTEL) — SCAN complete

**All 1K+ files deleted.** Only `Export/ExportEngine.swift` (638 LOC) remains. Zone healthy.

### Deleted: ClipLauncherGrid, VisualStepSequencer, StemRenderingEngine, UniversalExportPipeline

---

## Z5: Foundation (NIEDRIG) — SCAN complete

**Mostly healthy.** Deleted: `EchoelPaywall.swift` (305), `SPSCQueue.swift` (421).

| Ordner | Dateien | LOC | Notiz |
|--------|---------|-----|-------|
| Core/ | 9 | ~2.800 | Basis-Types, Logger, Config |
| Business/ | 1 | ~312 | Subscriptions |
| Theme/ | 4 | ~2.150 | VaporwaveTheme ist groß (943) |
| Root | 2 | ~328 | App-Entry, MicrophoneManager |

---

## Top 5 Highest-Risk Files (updated)

| # | Datei | LOC | Kernproblem |
|---|-------|-----|-------------|
| 1 | `Views/DAWArrangementView.swift` | 1.530 | **44 @State**, Timeline+Mixer+Effects+Sessions |
| 2 | `Video/ProColorGrading.swift` | 1.524 | **43 Methoden**, Color Science + LUTs + UI |
| 3 | `Views/VideoEditorView.swift` | 1.514 | SwiftUI View mit Video+Audio+Effects |
| 4 | `Audio/ProSessionEngine.swift` | 1.445 | **42 Methoden**, Multi-Track Session |
| 5 | `Sound/TR808BassSynth.swift` | 1.430 | Synth + Sequencer vermischt |

---

## Konkrete Refactoring-Schnitte (CLEAN phase)

### Schnitt 1: DAWArrangementView (1.530 → ~400)
```
DAWArrangementView.swift (1530)
├── DAWTimelineView.swift         ← Timeline-Rendering
├── DAWTrackListView.swift        ← Track-Liste + Auswahl
├── DAWTransportControlsView.swift ← Play/Stop/Record
├── DAWMixerStripView.swift       ← Inline-Mixer
└── DAWArrangementViewModel.swift  ← 44 @State → @Observable
```

### Schnitt 2: SynthPresetLibrary (1.326 → ~300 + JSON)
```
SynthPresetLibrary.swift (1326)
├── SynthPresetLibrary.swift       ← Lade-Logik (~300 LOC)
└── Resources/Presets/
    ├── bass_presets.json
    ├── pad_presets.json
    ├── lead_presets.json
    └── fx_presets.json
```

### Schnitt 3: TouchInstruments (1.376 → ~400 pro Datei)
```
TouchInstruments.swift (1376)
├── MIDI/Instruments/TouchPianoController.swift
├── MIDI/Instruments/TouchDrumPadController.swift
├── MIDI/Instruments/TouchXYPadController.swift
└── MIDI/Instruments/TouchInstrumentProtocol.swift
```

### Schnitt 4: ProColorGrading (1.524 → ~400 pro Datei)
```
ProColorGrading.swift (1524)
├── Video/ColorScience.swift       ← Farb-Algorithmen
├── Video/LUTManager.swift         ← LUT Laden + Anwenden
├── Video/GradingEngine.swift      ← Pipeline-Orchestrierung
└── Video/GradingPresets.swift     ← Preset-Daten
```

---

## Directory Health Scorecard (updated)

| Ordner | Status | Notiz |
|--------|--------|-------|
| **Audio/** | GELB | Dead code removed, 3 files >1K need splitting |
| **Views/** | ROT | 2 God-Views >1.5K LOC |
| **Video/** | ROT | 4 files >1K LOC |
| **Sound/** | GELB | 4 files >1K LOC, but all actively used |
| **DSP/** | GESUND | 7/7 production-ready, no cleanup needed |
| **MIDI/** | GELB | TouchInstruments (1.376) needs splitting |
| **Recording/** | GESUND | Under 1K LOC |
| **Core/** | GESUND | Sauber modularisiert |
| **Export/** | GESUND | Single file, 638 LOC |
| **Business/** | GESUND | Single file, <400 LOC |
| **Theme/** | GESUND | Stable |

---

## Metriken

| Metrik | Vorher | Jetzt | Ziel |
|--------|--------|-------|------|
| Source-Dateien | 126 | 89 | — |
| Source LOC | 78.919 | 54.700 | — |
| Test LOC | 19.164 | 15.603 | — |
| Gesamt LOC | 98.083 | 70.303 | — |
| Dateien > 1.000 LOC | 24 | 16 | < 10 |
| Durchschnitt LOC/Datei | 779 | 615 | < 500 |
| Toter Code | Unbekannt | 0 | 0 ✓ |

---

## Workflow pro Zone

```
Phase 1: SCAN ✓ DONE for all zones
├── Lies jede Datei der Zone
├── Markiere: AKTIV / STUB / TOT
├── Lösche toten Code
└── Output: Zone-Status in scratchpads/

Phase 2: CLEAN (next)
├── Teile 1K+ Dateien auf wo sinnvoll
├── Extrahiere überlappende Logik
└── Jede Änderung = 1 Commit

Phase 3: VERIFY
├── swift build (muss kompilieren)
├── swift test
└── Output: Update scratchpads/SESSION_LOG.md
```

---

## Reihenfolge der nächsten Arbeit

```
Next:     Z1 Audio Core — CLEAN (ProSessionEngine, ProMixEngine)
Then:     Z1 Audio Core — CLEAN (Sound/ splits)
Then:     Z3 Visual — CLEAN (DAWArrangementView, VideoEditorView)
Then:     Z2 Input — CLEAN (TouchInstruments split)
Then:     Z3 Visual — CLEAN (ProColorGrading, Video/)
Finally:  VERIFY all zones
```

---

## Regeln

1. **Eine Zone pro Session.** Nicht springen.
2. **Toter Code wird gelöscht**, nicht auskommentiert.
3. **Jede Datei > 1.000 LOC wird geprüft** — nicht automatisch aufgeteilt, aber bewusst entschieden.
4. **Kein Feature-Arbeit** während Optimization.
5. **Jeder Commit baut.** Kein "wird später gefixt".
6. **scratchpads/ wird aktualisiert** am Ende jeder Session.
7. **Tests vor und nach** jedem Refactoring.
