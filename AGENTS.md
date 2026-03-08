# AGENTS.md — Echoelmusic Zone-Based Optimization

> **Problem:** 98K LOC, 126 Dateien, 24 davon 1.000+ Zeilen.
> Ohne Struktur flicken wir Symptome statt Ursachen.
>
> **Ansatz:** 5 Zonen, klare Reihenfolge, eine Zone pro Session.

---

## Zone Overview

| Zone | Ordner | Dateien | LOC | 1K+ Dateien | Prio |
|------|--------|---------|-----|-------------|------|
| **Z1** Audio Core | Audio/, DSP/, Sound/ | 57 | 37.817 | 13 | KRITISCH |
| **Z2** Input | MIDI/, Recording/, Hardware/ | 24 | 11.963 | 5 | HOCH |
| **Z3** Visual | Video/, Views/ | 19 | 18.327 | 15 | MITTEL |
| **Z4** Platform | Performance/, Sequencer/, Export/ | 4 | 2.986 | 2 | MITTEL |
| **Z5** Foundation | Business/, Theme/, Core/, Root | 18 | 6.327 | 1 | NIEDRIG |

---

## Z1: Audio Core (KRITISCH)

**Warum zuerst:** Alles andere baut auf Audio. Wenn Audio instabil ist, ist alles instabil.

### Hotspots (1.000+ LOC)

| Datei | LOC | Problem |
|-------|-----|---------|
| `Audio/EnhancedAudioFeatures.swift` | 1.522 | God-class: Feature-Sammlung |
| `Audio/UltraLowLatencyBluetoothEngine.swift` | 1.490 | BLE + Audio vermischt |
| `Audio/ProSessionEngine.swift` | 1.445 | Session-Management zu groß |
| `Audio/ProMixEngine.swift` | 1.286 | Mixer ohne klare Trennung |
| `Audio/VoiceProfileSystem.swift` | 1.110 | Profil + Analyse vermischt |
| `Audio/BreakbeatChopper.swift` | 1.110 | Standalone, aber zu monolithisch |
| `Sound/TR808BassSynth.swift` | 1.430 | Synth + Sequencer vermischt |
| `Sound/SynthPresetLibrary.swift` | 1.326 | Preset-Daten + Logik vermischt |
| `Sound/EchoelBass.swift` | 1.255 | Einzelner Synth, zu groß |
| `Sound/EchoelBeat.swift` | 1.234 | Drum Machine, monolithisch |
| `DSP/AdvancedDSPEffects.swift` | 1.245 | Mehrere Effekte in einer Datei |
| `DSP/EchoelDDSP.swift` | 1.105 | Bio-Synth Kern (Rausch-basiert) |
| `DSP/ClassicAnalogEmulations.swift` | 1.001 | Mehrere Emulationen in einer Datei |

### Audit-Checkliste Z1

- [ ] Identifiziere tote Code-Pfade (Features die nirgends aufgerufen werden)
- [ ] Prüfe Audio-Thread-Sicherheit: keine Locks, malloc, ObjC, GCD
- [ ] Prüfe alle `EnhancedAudioFeatures` Methoden — welche werden tatsächlich genutzt?
- [ ] Verifiziere Combine-Pipeline: AudioEngine → ProMixEngine → Output
- [ ] Teste Latenz-Pfad: Mic Input → Processing → Speaker Output
- [ ] Prüfe ob `TR808BassSynth` Sequencer-Logik extrahiert werden sollte

### Refactor-Strategie Z1

1. `EnhancedAudioFeatures.swift` aufteilen nach Feature-Gruppen
2. `AdvancedDSPEffects.swift` → je ein File pro Effekt-Kategorie
3. `ClassicAnalogEmulations.swift` → je ein File pro Emulation
4. Audio-Thread Guards systematisch prüfen (vDSP, buffer access)
5. Toten Code entfernen (nicht auskommentieren, löschen)

---

## Z2: Input (HOCH)

**Warum zweite:** MIDI und Recording sind die Eingänge. Ohne stabile Eingänge kein stabiler Output.

### Hotspots (1.000+ LOC)

| Datei | LOC | Problem |
|-------|-----|---------|
| `MIDI/TouchInstruments.swift` | 1.376 | Alle Touch-Instrumente in einem File |
| `MIDI/QuantumMIDIOut.swift` | 1.088 | MIDI-Output zu komplex |
| `MIDI/AudioToQuantumMIDI.swift` | 855 | Audio→MIDI Conversion |
| `MIDI/PianoRollView.swift` | 849 | View-Logik + MIDI gemischt |
| `Recording/RecordingEngine.swift` | 891 | Knapp unter 1K, aber komplex |

### Audit-Checkliste Z2

- [ ] `TouchInstruments` — welche Instrumente sind aktiv / welche Placeholder?
- [ ] `PianoRollView` — View-Logik von MIDI-Logik trennen
- [ ] Recording-Pipeline: ist der Pfad MicrophoneManager → RecordingEngine → Export sauber?
- [ ] Hardware-Abstraktion: werden alle 4 Hardware-Dateien gebraucht?
- [ ] MIDI 2.0 / MPE: funktioniert es wirklich oder nur Stubs?

### Refactor-Strategie Z2

1. `TouchInstruments.swift` → je ein File pro Instrument-Typ
2. `PianoRollView.swift` → View + ViewModel trennen
3. Recording-Pipeline dokumentieren und vereinfachen
4. Ungenutzte MIDI-Features identifizieren und entfernen

---

## Z3: Visual (MITTEL)

**Warum dritte:** Video und Views sind die User-Facing-Schicht. Muss funktionieren, aber erst wenn Audio+Input stabil.

### Hotspots (1.000+ LOC)

| Datei | LOC | Problem |
|-------|-----|---------|
| `Views/DAWArrangementView.swift` | 1.530 | Größte View-Datei |
| `Views/VideoEditorView.swift` | 1.514 | Zweitgrößte View |
| `Video/ProColorGrading.swift` | 1.524 | Color-Grading Engine |
| `Video/CameraManager.swift` | 1.321 | Kamera-Management |
| `Video/BackgroundSourceManager.swift` | 1.177 | Hintergrund-Quellen |
| `Video/BPMGridEditEngine.swift` | 1.099 | Beat-Grid Editing |
| `Video/VideoProcessingEngine.swift` | 1.036 | Video-Verarbeitung |
| `Video/MultiCamStabilizer.swift` | 1.035 | Multi-Cam Stabilisierung |
| `Video/VideoEditingEngine.swift` | 1.007 | Video-Editing |
| `Video/ChromaKeyEngine.swift` | 805 | Chroma Key |
| `Views/SessionClipView.swift` | 996 | Session Clips |
| `Views/AudioRoutingMatrixView.swift` | 983 | Audio-Routing UI |
| `Views/MIDIRoutingView.swift` | 944 | MIDI-Routing UI |
| `Views/EchoelFXView.swift` | 905 | FX UI |
| `Views/MainNavigationHub.swift` | 820 | Navigation |

### Audit-Checkliste Z3

- [ ] Welche Views sind tatsächlich navigierbar / sichtbar?
- [ ] Video-Engine: wird ProColorGrading wirklich genutzt oder ist es Feature-Bloat?
- [ ] MultiCamStabilizer + VideoProcessingEngine — Überlappung?
- [ ] DAWArrangementView — braucht dringend Aufteilung in Sub-Views
- [ ] VideoEditorView — dito

### Refactor-Strategie Z3

1. Große Views in Komponenten aufteilen (ViewBuilder, extracted subviews)
2. Video-Engines: Prüfen ob alle 10 Dateien nötig sind
3. View-Models aus Views extrahieren wo noch nicht geschehen
4. `@State` / `@Binding` Audit — unnötige Re-Renders finden

---

## Z4: Platform (MITTEL)

**Kleine Zone, klare Aufgaben.**

| Datei | LOC | Status |
|-------|-----|--------|
| `Performance/ClipLauncherGrid.swift` | 1.009 | Audit nötig |
| `Export/StemRenderingEngine.swift` | 822 | Audit nötig |
| `Sequencer/VisualStepSequencer.swift` | 517 | OK |
| `Export/ExportEngine.swift` | 638 | OK |

### Audit-Checkliste Z4

- [ ] ClipLauncherGrid — funktioniert der Clip-Launch? Ist es getestet?
- [ ] StemRenderingEngine — korrekte Audio-Separation?
- [ ] Sequencer — ist VisualStepSequencer mit dem Audio-Sequencer synchron?

---

## Z5: Foundation (NIEDRIG)

**Stabil, wenig Handlungsbedarf.**

| Ordner | Dateien | LOC | Notiz |
|--------|---------|-----|-------|
| Core/ | 10 | 3.231 | Basis-Types, Logger, Config |
| Business/ | 2 | 617 | Subscriptions, IAP |
| Theme/ | 4 | 2.151 | VaporwaveTheme ist groß (943) |
| Root | 2 | 328 | App-Entry, MicrophoneManager |

### Audit-Checkliste Z5

- [ ] Core-Types: sind alle Protocols tatsächlich implementiert?
- [ ] VaporwaveTheme: 943 LOC für ein Theme — kann das vereinfacht werden?
- [ ] Business-Logik: StoreKit 2 korrekt implementiert?

---

## Workflow pro Zone

```
Phase 1: SCAN (30 min)
├── Lies jede Datei der Zone (Read tool)
├── Markiere: AKTIV / STUB / TOT
├── Dokumentiere echte Abhängigkeiten
└── Output: Zone-Status in scratchpads/ZONE_Z{n}_AUDIT.md

Phase 2: CLEAN (1-2h)
├── Lösche toten Code (nicht auskommentieren!)
├── Extrahiere überlappende Logik
├── Teile 1K+ Dateien auf wenn sinnvoll
└── Jede Änderung = 1 Commit

Phase 3: VERIFY (30 min)
├── swift build (muss kompilieren)
├── swift test --filter [Zone-relevante Tests]
├── Prüfe: keine neuen Warnings
└── Output: Update scratchpads/SESSION_LOG.md
```

---

## Parallele Agenten pro Zone

Für große Zonen (Z1, Z3) können 3 Agenten parallel arbeiten:

```
Zone Z1 Beispiel:
  Agent 1: Audio/ (41 Dateien, 23K LOC) — Engine + Mixer + Session
  Agent 2: DSP/ (8 Dateien, 6.6K LOC) — Effects + DDSP + Emulations
  Agent 3: Sound/ (8 Dateien, 7.9K LOC) — Synths + Sampler + Presets

Zone Z3 Beispiel:
  Agent 1: Video/ (10 Dateien, 10K LOC) — Engines + Processing
  Agent 2: Views/ (9 Dateien, 8.3K LOC) — UI Komponenten
  Agent 3: Cross-cutting — Wo referenziert Video Views und umgekehrt?
```

---

## Metriken-Ziele

| Metrik | Jetzt | Ziel | Warum |
|--------|-------|------|-------|
| Dateien > 1.000 LOC | 24 | < 10 | Lesbarkeit, Wartbarkeit |
| Durchschnitt LOC/Datei | 779 | < 500 | Übersichtlichkeit |
| Toter Code | Unbekannt | 0 | Weniger = weniger Bugs |
| Test Coverage | ~1.060 Methoden | +20% | Kritische Pfade absichern |
| Build Warnings | Unbekannt | 0 | Warnings werden zu Errors |

---

## Reihenfolge der Arbeit

```
Session N:    Z1 Audio Core — SCAN
Session N+1:  Z1 Audio Core — CLEAN (Audio/)
Session N+2:  Z1 Audio Core — CLEAN (DSP/ + Sound/)
Session N+3:  Z1 Audio Core — VERIFY
Session N+4:  Z2 Input — SCAN + CLEAN
Session N+5:  Z2 Input — VERIFY
Session N+6:  Z3 Visual — SCAN
Session N+7:  Z3 Visual — CLEAN (Video/)
Session N+8:  Z3 Visual — CLEAN (Views/)
Session N+9:  Z3 Visual — VERIFY
Session N+10: Z4 + Z5 — SCAN + CLEAN + VERIFY
```

**Jede Session endet mit einem lauffähigen Build.**

---

## Regeln

1. **Eine Zone pro Session.** Nicht springen.
2. **Toter Code wird gelöscht**, nicht auskommentiert.
3. **Jede Datei > 1.000 LOC wird geprüft** — nicht automatisch aufgeteilt, aber bewusst entschieden.
4. **Kein Feature-Arbeit** während Optimization.
5. **Jeder Commit baut.** Kein "wird später gefixt".
6. **scratchpads/ wird aktualisiert** am Ende jeder Session.
7. **Tests vor und nach** jedem Refactoring.
