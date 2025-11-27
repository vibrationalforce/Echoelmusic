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

### Audio/DAW (Sources/Echoelmusic/Audio/, DAW/)
- `AudioEngine.swift` - Main audio engine
- `MasterClockSystem.swift` (687 lines) - BPM sync, Ableton Link
- `CompleteMixerSystem.swift` (753 lines) - Professional mixing
- `MusicalTuningSystem.swift` (760 lines) - 40+ tuning systems
- `AdditionalEffects.swift` (1,406 lines) - Pro effects

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

- Created `MainNavigationView.swift` (591 lines) - Navigation hub
- Expanded `SettingsView.swift` (354 → 765 lines) - Connected all features
- Expanded `DAWVideoTimelineView.swift` (65 → 487 lines)
- Expanded `CollaborationEngine.swift` (71 → 491 lines)
- Expanded `DAWScoreView.swift` (75 → 773 lines) - Full musical notation editor
- Expanded `AIComposer.swift` (99 → 1129 lines) - AI composition engine
- Expanded `ChatAggregator.swift` (65 → 998 lines) - Multi-platform chat
- Created `.claude/PROJECT_CONTEXT.md` - Session persistence
