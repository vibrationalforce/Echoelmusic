# PLAN: DAW + Beat-Video MVP — Make It Work

## Status Quo

### Was da ist und funktioniert (Backend):
- **AudioEngine** (351 Zeilen): AVAudioEngine mit master mixer, start/stop, node graph — **funktioniert**
- **RecordingEngine** (878 Zeilen): Multi-track Recording, Playback, Retrospective Buffer — **funktioniert**
- **MicrophoneManager** (341 Zeilen): Mic Capture, FFT, YIN Pitch Detection — **funktioniert**
- **NodeGraph** (541 Zeilen): Topologisch sortierter DSP-Graph mit Filter, Compressor — **funktioniert**
- **LoopEngine** (548 Zeilen): Loop Recording + Overdub + Quantisierung — **funktioniert**
- **BPMGridEditEngine** (1095 Zeilen): Beat Detection, Snap, Tap Tempo — **funktioniert**
- **VideoEditingEngine** (994 Zeilen): AVMutableComposition, Ripple/Roll/Slip/Slide Edit — **funktioniert**
- **CameraManager** (1316 Zeilen): Full Camera Control, Recording — **funktioniert**
- **ProColorGrading** (1515 Zeilen): Wheels, Curves, LUT, Scopes — **funktioniert**
- **VideoExportManager** (735 Zeilen): H.264/H.265/ProRes Export — **funktioniert**
- **ChromaKeyEngine** (802 Zeilen): 6-Pass Metal Pipeline — **funktioniert**
- **ProMixEngine** (1282 Zeilen): Channel Strips, Routing — **teilweise**

### Was NICHT funktioniert (UI → Backend Verbindung):
1. **DAWArrangementView** zeigt Mock-Clips, keine echten Audio-Regions
2. **Mixer** zeigt statische Meter, nicht live
3. **VideoEditorView** zeigt Timeline aber kein echtes Video-Preview
4. **Kein echtes Waveform-Rendering** in Tracks
5. **Transport Controls** teilweise verbunden
6. **Kein Video-Clip Import** (UI fehlt)
7. **Effects Panel** rein visuell, tut nichts
8. **Kein Crossfade/Transition** System

---

## Was eine Pro DAW + Video App BRAUCHT

### Referenz-Apps:
- **Cubasis 3**: Unlimited Tracks, 24-bit/96kHz, AU Plugins, Full Mixer, Automation
- **BeatMaker 3**: Pad-based, Sampling, Deep MIDI
- **FL Studio Mobile**: Beat-Making, Desktop Sync
- **CapCut**: Auto Beat-Sync, AI Cuts, Waveform Visualization
- **Logic Pro iPad**: Arrangement + Live Loops, Mixer, Piano Roll

### Was amateur von pro trennt:
1. **GPU-accelerated Waveform Rendering** (nicht Canvas, sondern Metal)
2. **Sample-accurate Playback Sync** (alle Tracks synchron)
3. **Echte Meter** (RMS + Peak, live)
4. **Smooth Scrolling + Pinch-Zoom** auf Timeline
5. **Undo/Redo** überall
6. **Responsive Controls** (kein Lag bei Slider-Bewegungen)
7. **Keyboard Shortcuts** (externe Tastatur)

---

## IMPLEMENTATION PLAN — 6 Phasen

### Phase 1: DAW Arrangement REAL machen (Priorität 1)
**Ziel: Tap Record → Sehe Waveform → Höre Playback**

1. **Waveform Rendering** (DAWArrangementView)
   - Audio-File → Float-Samples → Downsampled Peaks Array
   - SwiftUI Canvas oder Path zum Zeichnen der Waveform
   - Zoom-Level bestimmt Samples-per-Pixel
   - Files: `Sources/Echoelmusic/Views/DAWArrangementView.swift`

2. **Echte Track-Regions aus RecordingEngine**
   - RecordingEngine.currentSession.tracks → DAW Tracks
   - Jeder Track zeigt seine Audio-Regions mit Waveform
   - Region = Audio-File + startTime + duration
   - Files: `DAWArrangementView.swift`, `RecordingEngine.swift`

3. **Transport Bar → AudioEngine verbinden**
   - Play: Alle Tracks synchron abspielen (AudioEngine.schedulePlayback)
   - Stop: AudioEngine.stop()
   - Record: RecordingEngine.startRecording → neuer Track
   - Playhead: Timer-basiert, synced mit BPM
   - Files: `MainNavigationHub.swift`, `AudioEngine.swift`

4. **Live Metering**
   - installTap auf masterMixer → RMS berechnen (vDSP)
   - @Published var masterLevel: Float auf AudioEngine
   - Transport Bar zeigt Level-Meter
   - Per-Track metering beim Playback
   - Files: `AudioEngine.swift`, `DAWArrangementView.swift`

### Phase 2: Mixer REAL machen
**Ziel: Fader bewegen → Lautstärke ändert sich**

1. **Channel Strips mit echtem Audio-Routing**
   - Jeder Track → eigener AVAudioPlayerNode
   - Volume Fader → node.volume
   - Pan → node.pan
   - Mute/Solo → node.volume = 0 / andere muten

2. **Live VU Meter pro Channel**
   - installTap pro PlayerNode → RMS
   - Peak Hold mit Decay
   - Grün/Gelb/Rot Zones

3. **Master Bus**
   - Master Fader
   - Master Metering (Stereo)
   - Export-Punkt

### Phase 3: Video Editor REAL machen
**Ziel: Video importieren → auf Timeline → Play → Export**

1. **Video Import**
   - PHPickerViewController für Video-Auswahl
   - AVAsset laden → Clip erstellen
   - Thumbnail-Generierung für Timeline

2. **Video Preview**
   - AVPlayer in VideoEditorView einbetten
   - Composition aus VideoEditingEngine.buildComposition()
   - Playback synchron mit Timeline-Playhead

3. **Timeline mit echten Clips**
   - Drag-to-reorder
   - Trim-Handles an Clip-Enden
   - Split-Tool (Razor)
   - BPM Grid Overlay funktioniert bereits

4. **Beat-Sync Schnitt**
   - BPMGridEditEngine.detectBeats() auf Audio-Track
   - Auto-Cut Vorschläge an Beat-Positionen
   - One-Tap Beat-Sync (wie CapCut)

### Phase 4: Audio ↔ Video Bridge
**Ziel: Audio-Timeline und Video-Timeline synchron**

1. **Unified Transport**
   - Ein Play/Stop für beide
   - Ein Playhead-Position für Audio + Video
   - BPM als gemeinsame Zeitbasis

2. **Audio-Track als Video-Referenz**
   - Audio importieren → Beat Detection
   - Video-Clips automatisch an Beats schneiden
   - Audio Waveform unter Video-Timeline

### Phase 5: Polish & Pro-Feel
**Ziel: App fühlt sich professionell an**

1. **Smooth Scrolling + Pinch-Zoom**
   - Timeline: MagnificationGesture für Zoom
   - ScrollViewReader für Position
   - Momentum Scrolling

2. **Keyboard Shortcuts**
   - Space = Play/Pause
   - R = Record
   - Z = Undo
   - Cmd+S = Save
   - Cmd+E = Export

3. **Haptic Feedback**
   - UIImpactFeedbackGenerator bei Button-Taps
   - UISelectionFeedbackGenerator bei Snap

4. **Loading States**
   - ProgressView beim Import
   - Skeleton-Views beim Laden

### Phase 6: Export & Share
**Ziel: Fertiges Projekt exportieren**

1. **Audio Export** (existiert via ExportManager)
   - WAV, M4A, AIFF
   - Stems (einzelne Tracks)

2. **Video Export** (existiert via VideoExportManager)
   - H.264, H.265, ProRes
   - Resolution/Quality Picker

3. **Share Sheet**
   - AirDrop, Files, Social Media

---

## REIHENFOLGE (Ralph Wiggum Lambda)

```
Cycle 1: Waveform Rendering in DAWArrangementView
Cycle 2: Echte Track-Regions aus RecordingEngine
Cycle 3: Transport → AudioEngine verbinden
Cycle 4: Live Master Metering
Cycle 5: Mixer Channel Strips mit echtem Audio
Cycle 6: Video Import + PHPicker
Cycle 7: Video Preview mit AVPlayer
Cycle 8: Video Timeline mit echten Clips
Cycle 9: Unified Transport (Audio + Video)
Cycle 10: Beat-Sync Auto-Cut
Cycle 11: Pinch-Zoom + Smooth Scroll
Cycle 12: Keyboard Shortcuts
Cycle 13: Polish + Haptics
```

Jeder Cycle = 1 Commit. Build muss nach jedem Cycle grün sein.

---

## NICHT IN DIESEM PLAN

- Bio-Feedback / Health (rausgeschmissen)
- AI/ML Features
- Streaming / SharePlay
- Lighting / DMX
- Spatial Audio
- Apple Watch
- Android
- AUv3 Plugin Hosting
- External MIDI Controller Support (später)
