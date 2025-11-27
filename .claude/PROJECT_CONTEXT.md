# Echoelmusic - Project Context for Claude Sessions

> **WICHTIG:** Diese Datei am Anfang jeder Session lesen!
> Last updated: 2025-11-27

## Project Overview

Echoelmusic ist eine **All-in-One Creative Suite** die folgende Konkurrenten übertreffen soll:
- **DAWs:** Ableton Live, FL Studio, Logic Pro, Reaper
- **Video Editors:** DaVinci Resolve, Final Cut Pro, Premiere Pro, CapCut
- **VJ Software:** Resolume Arena, TouchDesigner
- **Plus:** Content Management, Live Streaming, Worldwide Collaboration, Gig Platform

## Codebase Statistics

- **280 Swift files**
- **136,910 lines of code**
- **Platform:** iOS, iPadOS, macOS, tvOS, watchOS, visionOS

## Architecture

### Main Entry Point
```
EchoelmusicApp.swift → MainNavigationView.swift (ROOT)
```

### Navigation Structure
```
MainNavigationView (8 main tabs)
├── Home → ContentView (Bio-reactive visualization)
├── DAW → DAWMainView
│   ├── Timeline → DAWTimelineView
│   ├── Mixer → DAWMixerView
│   ├── Automation → DAWAutomationEditorView
│   ├── Plugins → DAWPluginRackView
│   ├── Video → DAWVideoTimelineView
│   ├── MIDI → DAWMIDIEditorView
│   ├── Score → DAWScoreView
│   ├── Browser → DAWBrowserView
│   ├── Inspector → DAWTrackInspectorView
│   └── Transport → DAWTransportView
├── Video → VideoEditingView
│   ├── ColorGradingView (1159 lines)
│   ├── ChromaKeyView (441 lines)
│   └── VideoTimelineView (1767 lines)
├── VJ → VJPerformanceView
│   ├── ClipLauncherMatrix (1291 lines)
│   ├── LightingControlView (154 lines)
│   └── ProjectionMappingView
├── Stream → LiveBroadcastControlPanelView (867 lines)
├── Collaborate → EchoelSyncControlPanelView (1388 lines)
├── Work → EoelWorkMainView (Gig Platform)
│   ├── GigSearchView
│   ├── PostGigView
│   └── SubscriptionView
└── Settings → SettingsView (765 lines)
    ├── TuningSettingsView (1027 lines)
    ├── BiofeedbackTranslationToolView (764 lines)
    ├── LightingControlView
    ├── EoelWorkProfileView
    └── LiDARSettingsView
```

## Key Modules

### Instruments (Sources/Echoelmusic/Instruments/, Innovation/)
- `UltraIntelligentInstrumentEngine.swift` (750+ lines) - Unified instrument system
  - **64 instruments** across 9 categories
  - Physical modeling for ALL instruments
  - AI learning (adapts to your playing style)
  - Bio-reactive control (HRV/HR → expression)
  - Instrument morphing
  - Articulations and keyswitches

- `EchoelBass.swift` (950+ lines) - **28 Bass Modes** (NEW!)
  - TR-808 with bridged-T network modeling (authentic analog simulation)
  - TB-303 with diode ladder filter, slides, accents
  - Moog Family: Minimoog, Sub37, Taurus, Voyager, Matriarch
  - Neural Bass Engine with AI sound generation
  - Multi-Sound Morphing Engine (morph up to 4 sources)
  - Modes: 808 Sub, 303 Acid, Moog Classic, Reese, Neuro, Wobble, FM, Wavetable, etc.

- `InnovativeSynthesizers.swift` (800+ lines) - **8 State-of-the-Art Engines** (NEW!)
  - SpectralMorphSynth: FFT-based spectral morphing between sounds
  - NeuralTimbreSynth: Neural network timbre generation
  - QuantumHarmonicSynth: Superposition/entanglement harmonic concepts
  - PhysicalSpectralHybrid: Physical modeling + spectral processing
  - CosmicDroneSynth: Infinite evolving drones for ambient/score
  - LiquidMetalSynth: Fluid dynamics-based synthesis
  - DimensionalRiftSynth: Multi-dimensional waveshaping
  - GranularCloudSynth: Advanced granular with cloud morphing

- `ProfessionalVirtualInstruments.swift` (1,525 lines) - 44 physical modeling instruments
- `NeuralNetworkInstruments.swift` (649 lines) - 8 AI-learning instruments
- `UnifiedSynthesisEngine.swift` (735 lines) - 12 synthesis types + Quantum/Fractal
- `AIAudioDesigner.swift` (793 lines) - Text-to-sound, morphing, style transfer
- `UniversalSoundLibrary.swift` (810 lines) - World instruments database

**Instrument Categories (64 total):**
| Category | Count | Examples |
|----------|-------|----------|
| Keyboards | 8 | Acoustic Piano, Rhodes, Organ, Harpsichord, Clavinet, Celesta, Accordion, Melodica |
| Guitars | 7 | Acoustic, Electric, Bass, Ukulele, Banjo, Mandolin, 12-String |
| Strings | 6 | Violin, Viola, Cello, Contrabass, Harp, String Section |
| Brass | 6 | Trumpet, Trombone, French Horn, Tuba, Saxophone, Brass Section |
| Woodwinds | 6 | Flute, Clarinet, Oboe, Bassoon, Piccolo, Pan Flute |
| Percussion | 8 | Acoustic/Electronic Drums, Orchestral, Mallets, Timpani, World, Hand, 808/909 |
| World/Ethnic | 12 | Sitar, Tabla, Erhu, Koto, Shamisen, Shakuhachi, Didgeridoo, Bagpipes, Steel Drum, Cajon, Oud, Gamelan |
| Synthesizers | 12 | Subtractive, FM, Wavetable, Granular, Additive, Physical Modeling, Vector, Spectral, Pad, Lead, Bass, Pluck |
| Experimental | 5 | Neural Synth, Quantum Synth, Fractal Synth, Bio-Reactive Synth, AI Composer |

**Plugin Bridges:**
- `CLAPPluginBridge.swift` (440 lines) - CLAP plugin hosting
- `VST3PluginBridge.swift` - VST3 plugin hosting
- `DAWPluginHost.swift` - Unified plugin hosting

### Audio/DAW (Sources/Echoelmusic/Audio/, DAW/)
- `AudioEngine.swift` - Main audio engine
- `MasterClockSystem.swift` (687 lines) - BPM sync, Ableton Link
- `CompleteMixerSystem.swift` (753 lines) - Professional mixing
- `MusicalTuningSystem.swift` (760 lines) - 40+ tuning systems
- `AdditionalEffects.swift` (1,406 lines) - Pro effects

- `EchoelCalculator.swift` (600+ lines) - **Sengpiel-Style Audio Toolkit** (NEW!)
  - BPM ↔ ms/Hz/Samples conversion (musical delay times)
  - Delay Time Calculator (1/4, 1/8, 1/16, dotted, triplets)
  - Frequency ↔ MIDI Note ↔ Wavelength conversion
  - dB calculations (dB→ratio, ratio→dB, power/voltage)
  - Room Acoustics (RT60 Sabine/Eyring, room modes)
  - Psychoacoustic calculations (Bark scale, ERB, critical bandwidth)
  - Pre-Delay calculator, filter cutoff helpers

- `GenrePatternLibrary.swift` (1100+ lines) - **35+ Electronic Genres** (NEW!)
  - House: Deep, Tech, Progressive, Acid, Funky, Afro, Melodic, Future
  - Techno: Classic, Minimal, Industrial, Melodic, Hard, Dub
  - D&B: Classic, Liquid, Neurofunk, Jump-Up
  - Jungle, Breakbeat, Breaks
  - Trap (with Hi-Hat Rolls!), Future Bass, Phonk
  - UK Garage, 2-Step, Grime, UK Bass
  - Dubstep, Riddim, Brostep
  - Trance, Psytrance, Hard Trance, Uplifting
  - Ambient, IDM, Downtempo
  - Each genre includes: BPM range, drum patterns, bass patterns, characteristic elements

### Music Theory & Composition Education

**Swift (Sources/Echoelmusic/MusicTheory/):**
- `GlobalMusicTheoryDatabase.swift` (560 lines) - **World Music Education System**
  - 13 music cultures: Western, Arabic, Indian, Chinese, Japanese, African, Celtic, Flamenco, Balkan, Indonesian, Brazilian, Nordic, Middle Eastern
  - Scales and modes for each culture
  - Rhythm patterns and time signatures
  - **IMPORTANT:** Education-focused - "Menschen sollen komponieren, nicht die Maschine!"

**C++/JUCE (Sources/MIDI/) - MASTER DATABASE:**
- `WorldMusicDatabase.cpp/.h` (568 lines) - **Complete Style Database with Composition Techniques**
  - **50+ Stile** covering OLD and NEW music
  - Modern: Pop, Rock, Hip-Hop, R&B, Soul, Funk, House, Techno, Trance, DubStep, D&B, Ambient, Synthwave
  - Classical Periods: Medieval, Renaissance, Baroque, Classical, Romantic, Impressionist, Modern
  - Jazz: Dixieland, Swing, Bebop, Cool, Modal, Free, Fusion, Smooth
  - Latin: Salsa, Bossa Nova, Tango, Cumbia, Reggaeton, Samba
  - African: Afrobeat, Highlife, Soukous
  - Asian: Indian Classical, Chinese, Japanese, Gamelan, K-Pop
  - Middle Eastern: Arabic, Persian, Turkish
  - European Folk: Celtic, Nordic, Slavic, Flamenco, Fado

  **Kompositionstechniken pro Stil:**
  - `typicalProgressions` - Akkordfolgen (z.B. I-V-vi-IV)
  - `typicalScales` - Empfohlene Skalen
  - `chromaticismAmount` - Chromatik-Level (0-1)
  - `dissonanceAmount` - Dissonanz-Level (0-1)
  - `complexityLevel` - Komplexitätsgrad (0-1)
  - `syncopationAmount` - Synkopierungs-Level (0-1)
  - `melodicContour` - Melodieführung
  - `rhythmicFeel` - Rhythmus-Charakter

### MIDI (Sources/Echoelmusic/MIDI/ + Sources/MIDI/)

**Swift (Sources/Echoelmusic/MIDI/):**
- `MIDIEffects.swift` (1,490 lines) - Ultra-Intelligence MIDI System
  - EchoelArp: Advanced arpeggiator with euclidean rhythms
  - Intelligent Harmonizer: AI-powered harmony generation
  - Generative Sequencer: Markov chains, cellular automata
  - Bio-Reactive MIDI: HRV/HR → MIDI parameters (UNIQUE!)
  - MIDI LFO, Polyrhythm Generator, and 10+ standard effects

**C++/JUCE Composition Suite (Sources/MIDI/) - PROFESSIONAL TOOLSET:**
- `ChordGenius.cpp/.h` - **500+ Akkordtypen**, AI Progressions, Voice Leading
  - Major, Minor, Dim, Aug, Sus, 7th, 9th, 11th, 13th, Altered, Exotic
  - Genre-specific progressions (Pop, Jazz, R&B, EDM, Classical)
  - Voicing variations (close, open, drop-2, drop-3)
- `MelodyForge.cpp/.h` - **AI Melodie-Generierung**
  - Scale-aware (nie falsche Noten!)
  - Rhythm pattern library, humanization
  - Melodic contour control, motif development
- `BasslineArchitect.cpp/.h` - **Intelligente Bassline-Generierung**
  - Groove Templates: Funk, Rock, EDM, Reggae, Latin, Walking Bass
  - Ghost notes, slides, articulations
- `ArpWeaver.cpp/.h` - **Professioneller Arpeggiator**
  - Genre-specific patterns from WorldMusicDatabase

### Video (Sources/Echoelmusic/Video/, VideoAI/)
- `VideoEditingEngine.swift` (620 lines)
- `ColorGradingSystem.swift` (754 lines) - DaVinci-level grading
- `ChromaKeyEngine.swift` (608 lines) - Green screen
- `AIVideoEditor.swift` (749 lines)

### Collaboration (Sources/Echoelmusic/Collaboration/)
- `EchoelSyncEngine.swift` (1,263 lines) - Ableton Link-style sync
- `WebRTCManager.swift` (844 lines) - Real-time audio
- `WorldwideSyncBridge.swift` (721 lines) - Global sync
- `CollaborationEngine.swift` (491 lines) - Unified coordinator
- `EchoelHeartSync.swift` (466 lines) - Bio-sync

### Streaming (Sources/Echoelmusic/Stream/)
- `StreamEngine.swift` (581 lines) - RTMP streaming
- `SceneManager.swift` - Scene management

### Lighting (Sources/Echoelmusic/Core/Lighting/)
- `SmartLightingAPIs.swift` (561 lines) - Philips Hue, WiZ, DMX512, Art-Net
- `UnifiedLightingController.swift` (207 lines) - 21+ systems

### Backend (Sources/Echoelmusic/Core/EoelWork/)
- `EchoelmusicWorkBackend.swift` (688 lines) - Firebase, Stripe, AI matching

### Biofeedback (Sources/Echoelmusic/Biofeedback/)
- `BiofeedbackSonification.swift` (523 lines) - HRV → Audio
- `FrequencyToVisualMapper.swift` (527 lines) - Frequency → Color
- `BioParameterMapper.swift` (363 lines)

### VJ/Visual (Sources/Echoelmusic/VJ/, Visual/)
- `ClipLauncherMatrix.swift` (1,291 lines) - 8x8 clip launcher
- `OSCManager.swift` (1,020 lines) - OSC protocol
- `CymaticsRenderer.swift` (259 lines) - GPU cymatics

## Unique Features (Competitive Advantages)

1. **Biometric Integration** - HRV/HR → Audio parameters (unique)
2. **All-in-One Suite** - DAW + Video + VJ + Streaming (unique combo)
3. **Mobile-First** - Full DAW on iPad/iPhone
4. **40+ Tuning Systems** - World music support
5. **DaVinci-Level Color Grading** - Professional video
6. **Multi-Platform** - iOS, iPad, Mac, Vision Pro, tvOS, watchOS

## Recently Expanded Files (2025-11-27)

These files were stubs and have been expanded to full implementations:
- `DAWScoreView.swift` (75 → 773 lines) - Full musical notation editor
- `AIComposer.swift` (99 → 1129 lines) - AI composition with Markov chains
- `ChatAggregator.swift` (65 → 998 lines) - Multi-platform streaming chat

## DO NOT DELETE

These files exist and should NOT be recreated:
- `BiofeedbackSonification.swift` - NOT ScientificSonification
- `CymaticsRenderer.swift` - NOT CymaticsEngine
- All files in Core/Lighting/ - Already complete
- All files in Core/EoelWork/ - Already complete

## Session Guidelines

1. **Before creating new files:** Search if similar functionality exists
2. **Before deleting files:** Confirm they are duplicates
3. **After implementing features:** Ensure they're connected to navigation
4. **Commit frequently:** Don't batch too many changes

## Recent Changes (2025-11-27)

**Session 4 (Current) - Complete Instrument & Audio Toolkit Session:**
- Created `EchoelBass.swift` (950+ lines) - 28 Bass Modes with TR-808, TB-303, Moog
- Created `InnovativeSynthesizers.swift` (800+ lines) - 8 State-of-the-Art Synthesis Engines
- Created `EchoelCalculator.swift` (600+ lines) - Sengpiel-Style Audio Toolkit
- Created `GenrePatternLibrary.swift` (1100+ lines) - 35+ Electronic Genres
- Verified `GlobalMusicTheoryDatabase.swift` exists - 13 World Music Cultures

**Session 3:**
- Created `UltraIntelligentInstrumentEngine.swift` (750+ lines) - Unified 64-instrument system
- Created `InstrumentBrowserView.swift` (550+ lines) - Professional instrument browser UI
- Updated `PROJECT_CONTEXT.md` with comprehensive instrument documentation

**Session 2:**
- Expanded `MIDIEffects.swift` (647 → 1490 lines) - Ultra-Intelligence MIDI System
  - EchoelArp, Intelligent Harmonizer, Generative Sequencer, Bio-Reactive MIDI

**Session 1:**
- Created `MainNavigationView.swift` (591 lines) - Navigation hub
- Expanded `SettingsView.swift` (354 → 765 lines) - Connected all features
- Expanded `DAWVideoTimelineView.swift` (65 → 487 lines)
- Expanded `CollaborationEngine.swift` (71 → 491 lines)
- Expanded `DAWScoreView.swift` (75 → 773 lines) - Full musical notation editor
- Expanded `AIComposer.swift` (99 → 1129 lines) - AI composition engine
- Expanded `ChatAggregator.swift` (65 → 998 lines) - Multi-platform chat
- Created `.claude/PROJECT_CONTEXT.md` - Session persistence
