# ECHOELMUSIC ARCHITECTURE DOCUMENTATION
# PERMANENT REFERENCE - DO NOT DELETE
# Last Updated: 2025-11-27

## SYSTEM OVERVIEW

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ECHOELMUSIC PLATFORM                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    PRESENTATION LAYER (SwiftUI)                      │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  DAW Module     │ Video Module   │ VJ Module      │ CMS Module      │   │
│  │  ─────────────  │ ─────────────  │ ─────────────  │ ─────────────   │   │
│  │  Arrangement    │ VideoTimeline  │ ClipLauncher   │ ContentAPI      │   │
│  │  PianoRoll      │ VideoEngine    │ OSCManager     │ Marketplace     │   │
│  │  SessionLaunch  │ ChromaKey      │ Effects        │ Social          │   │
│  │  StepSequencer  │ Export         │ Outputs        │ Analytics       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    BUSINESS LOGIC LAYER (Swift)                      │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Audio         │ Recording    │ Stream       │ Collaboration       │   │
│  │  ─────────────  │ ─────────── │ ────────────  │ ─────────────       │   │
│  │  AudioEngine   │ Session      │ RTMPClient   │ WebRTCManager       │   │
│  │  MIDIControl   │ Track        │ SceneManager │ CollabEngine        │   │
│  │  LoopEngine    │ Mixer        │ Analytics    │ SignalingServer     │   │
│  │  EffectsChain  │ Export       │ ChatAggr     │ DataChannels        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    DSP ENGINE LAYER (C++/JUCE)                       │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  CoreDSP        │ Analyzers     │ Synth        │ Effects            │   │
│  │  ──────────────  │ ────────────  │ ────────────  │ ────────────       │   │
│  │  AudioBuffer    │ FFTAnalyzer   │ Oscillators  │ Dynamics(9)        │   │
│  │  SampleRate     │ Spectral      │ Filters      │ Distortion(5)      │   │
│  │  BlockSize      │ Envelope      │ Modulators   │ Spatial(8)         │   │
│  │  Channels       │ OnsetDetect   │ ADSR         │ Modulation(8)      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    GPU ACCELERATION (Metal)                          │   │
│  ├─────────────────────────────────────────────────────────────────────┤   │
│  │  Cymatics.metal        │ AdvancedShaders.metal  │ ChromaKey.metal   │   │
│  │  ─────────────────────  │ ───────────────────────  │ ────────────────  │   │
│  │  Wave interference     │ Particle systems       │ Chroma keying     │   │
│  │  Frequency patterns    │ Kaleidoscope           │ Background sub    │   │
│  │  Mandala generation    │ Fractal generators     │ Color correction  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## MODULE ARCHITECTURE

### 1. DAW MODULE (Digital Audio Workstation)
**Location:** `Sources/Echoelmusic/DAW/`

```
DAW/
├── ArrangementView.swift      # Timeline/Track editor (1,400+ lines)
│   ├── ArrangementEngine      # State management
│   ├── ArrangementTrack       # Track model
│   ├── ArrangementClip        # Clip model
│   ├── AutomationLane         # Parameter automation
│   └── ArrangementMarker      # Timeline markers
│
├── PianoRollView.swift        # MIDI note editor (1,100+ lines)
│   ├── PianoRollEngine        # State management
│   ├── MIDINote               # Note model (pitch, velocity, duration)
│   ├── EditMode               # Select/Draw/Erase/Slice/Velocity/Stretch
│   └── Quantization           # Grid snapping options
│
├── SessionLauncherView.swift  # Clip launcher (1,000+ lines)
│   ├── SessionEngine          # Launch management
│   ├── LaunchClip             # Clip with follow actions
│   ├── SessionTrack           # Track column
│   ├── Scene                  # Horizontal scene rows
│   └── CrossfaderEngine       # A/B deck mixing
│
└── StepSequencerView.swift    # Step sequencer (1,100+ lines)
    ├── StepSequencerEngine    # Pattern management
    ├── SequencerStep          # Step with velocity/prob/gate
    ├── SequencerRow           # Instrument row
    └── Pattern                # Collection of steps
```

**Capabilities:**
- ✅ Multi-track arrangement editing
- ✅ Automation lanes with curves
- ✅ Piano roll with MPE support
- ✅ Session/clip launcher (Ableton-style)
- ✅ Step sequencer (FL Studio-style)
- ✅ Quantization (1/64 to 8 bars)
- ✅ Copy/paste/duplicate
- ✅ Undo/redo system
- ✅ Audio warp modes

---

### 2. VIDEO EDITOR MODULE
**Location:** `Sources/Echoelmusic/VideoEditor/` + `Sources/Echoelmusic/Video/`

```
VideoEditor/
└── VideoTimelineView.swift    # Complete NLE (1,800+ lines)
    ├── VideoTimelineEngine    # State management
    ├── VideoClip              # Clip model with effects
    ├── VideoTrack             # Track layer
    ├── VideoEffect            # 30+ effects
    ├── VideoTransition        # Transitions
    └── KeyframeAnimation      # Keyframe system

Video/
├── VideoEditingEngine.swift   # Core video processing
├── VideoExportManager.swift   # Export pipeline
├── ChromaKeyEngine.swift      # Chroma key processing
├── CameraManager.swift        # Camera input
├── BackgroundSourceManager.swift # Virtual backgrounds
└── Shaders/
    └── ChromaKey.metal        # GPU chroma keying
```

**Capabilities:**
- ✅ Multi-track video timeline
- ✅ 30+ video effects (blur, color, distortion, etc.)
- ✅ Keyframe animation system
- ✅ Transitions (fade, dissolve, wipe, etc.)
- ✅ Chroma key / green screen
- ✅ Speed control (0.1x - 10x)
- ✅ Export (4K, HDR, ProRes, H.265)
- ✅ Timeline markers

---

### 3. VJ MODULE
**Location:** `Sources/Echoelmusic/VJ/`

```
VJ/
├── ClipLauncherMatrix.swift   # VJ clip system (1,200+ lines)
│   ├── VJEngine               # State management
│   ├── VJClip                 # Video/image/generator clip
│   ├── VJDeck                 # A/B deck system
│   ├── VJEffect               # 30+ real-time effects
│   └── VJOutput               # Multi-output (NDI, Syphon, Spout)
│
└── OSCManager.swift           # OSC protocol (1,000+ lines)
    ├── OSCServer              # UDP server
    ├── OSCClient              # UDP client
    ├── OSCMessage             # Message builder
    ├── OSCBundle              # Timetag bundles
    └── OSCRouter              # Address routing
```

**Capabilities:**
- ✅ 8x8 clip matrix (64 clips)
- ✅ Dual deck system (A/B)
- ✅ Crossfader with curves
- ✅ Audio reactivity (FFT)
- ✅ Beat sync / tempo tap
- ✅ 30+ real-time effects
- ✅ Full OSC 1.0/1.1 protocol
- ✅ Resolume/TouchDesigner integration
- ✅ Multi-output (NDI, Syphon, Spout)

---

### 4. AUDIO ENGINE
**Location:** `Sources/Echoelmusic/Audio/` + `DSP/`

```
Audio/
├── AudioEngine.swift          # Core audio graph
├── AudioConfiguration.swift   # Session setup
├── MIDIController.swift       # MIDI I/O
├── LoopEngine.swift           # Loop recording
├── EffectsChainView.swift     # Effects UI
├── EffectParametersView.swift # Parameter controls
├── DSP/
│   └── PitchDetector.swift    # YIN pitch detection
├── Effects/
│   └── BinauralBeatGenerator.swift
└── Nodes/
    ├── CompressorNode.swift
    ├── ReverbNode.swift
    ├── DelayNode.swift
    ├── FilterNode.swift
    ├── NodeGraph.swift
    └── EchoelmusicNode.swift

DSP/
└── AdvancedDSPEffects.swift   # Additional effects
```

---

### 5. STREAMING MODULE
**Location:** `Sources/Echoelmusic/Stream/`

```
Stream/
├── StreamEngine.swift         # Core streaming
├── RTMPClient.swift           # RTMP protocol
├── SceneManager.swift         # OBS-like scenes
├── ChatAggregator.swift       # Multi-platform chat
└── StreamAnalytics.swift      # Viewer analytics
```

---

### 6. COLLABORATION MODULE
**Location:** `Sources/Echoelmusic/Collaboration/`

```
Collaboration/
├── CollaborationEngine.swift  # Core collaboration
└── WebRTCManager.swift        # WebRTC implementation (900+ lines)
    ├── SignalingClient        # WebSocket signaling
    ├── PeerConnection         # ICE/STUN/TURN
    ├── CollaborationRoom      # Room management
    └── DataChannel            # Chat/MIDI/Transport sync
```

---

### 7. CMS MODULE
**Location:** `Sources/Echoelmusic/CMS/`

```
CMS/
└── ContentManagementAPI.swift # REST API client (1,000+ lines)
    ├── APIClient              # HTTP client
    ├── ProjectAPI             # Project CRUD
    ├── AssetAPI               # Asset management
    ├── MarketplaceAPI         # Store/purchases
    ├── SocialAPI              # Posts/comments/follows
    └── AnalyticsAPI           # Usage analytics
```

---

### 8. AUTHENTICATION MODULE
**Location:** `Sources/Echoelmusic/Platform/`

```
Platform/
└── AuthenticationManager.swift # Auth system (800+ lines)
    ├── EmailPasswordAuth      # Traditional auth
    ├── AppleSignIn            # Sign in with Apple
    ├── BiometricAuth          # Face ID / Touch ID
    ├── KeychainManager        # Secure storage
    └── SessionManager         # Token refresh
```

---

## C++ DSP ENGINE

**Location:** `cpp/` (201 files)

```
cpp/
├── core/                      # Core DSP infrastructure
│   ├── AudioBuffer.hpp/cpp    # Buffer management
│   ├── SampleRate.hpp/cpp     # Sample rate handling
│   └── BlockSize.hpp/cpp      # Block processing
│
├── analyzers/                 # Audio analysis
│   ├── FFTAnalyzer.hpp/cpp    # Spectrum analysis
│   ├── SpectralAnalyzer.hpp/cpp
│   ├── EnvelopeFollower.hpp/cpp
│   └── OnsetDetector.hpp/cpp
│
├── synth/                     # Synthesis
│   ├── Oscillator.hpp/cpp     # Oscillators
│   ├── Filter.hpp/cpp         # Filters
│   ├── ADSR.hpp/cpp           # Envelopes
│   └── Modulator.hpp/cpp      # Modulators
│
└── effects/                   # 45+ effects
    ├── dynamics/              # Compressor, Limiter, Gate, etc. (9)
    ├── distortion/            # Overdrive, Bitcrush, etc. (5)
    ├── modulation/            # Chorus, Flanger, Phaser, etc. (8)
    ├── spatial/               # Reverb, Delay, Convolver, etc. (8)
    └── filter/                # EQ, Filter Bank, etc. (15)
```

---

## METAL SHADERS

**Location:** `Sources/Echoelmusic/Visual/Shaders/` + `Video/Shaders/`

| Shader | Purpose | Features |
|--------|---------|----------|
| `Cymatics.metal` | Cymatics visualization | Wave interference, frequency patterns |
| `AdvancedShaders.metal` | Visual effects | Particles, kaleidoscope, fractals |
| `ChromaKey.metal` | Video compositing | Chroma keying, background substitution |

---

## PLATFORM SUPPORT

| Platform | Version | Status |
|----------|---------|--------|
| iOS | 15.0+ | ✅ Full support |
| iPadOS | 15.0+ | ✅ Multi-window, Stage Manager |
| macOS | 12.0+ | ✅ Native Mac app |
| watchOS | 8.0+ | ✅ Companion app |
| tvOS | 15.0+ | ✅ Big screen mode |
| visionOS | 1.0+ | ✅ Spatial audio & controls |

---

## DATA FLOW

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Input      │     │   Process    │     │   Output     │
├──────────────┤     ├──────────────┤     ├──────────────┤
│ Microphone   │────▶│ AudioEngine  │────▶│ Speakers     │
│ MIDI Device  │────▶│ DSP Effects  │────▶│ RTMP Stream  │
│ Camera       │────▶│ VideoEngine  │────▶│ NDI/Syphon   │
│ OSC Input    │────▶│ VJ Engine    │────▶│ Recording    │
│ WebRTC       │────▶│ Collab Room  │────▶│ Cloud Sync   │
│ REST API     │────▶│ CMS Engine   │────▶│ Local Files  │
└──────────────┘     └──────────────┘     └──────────────┘
```

---

## BUILD CONFIGURATION

### Swift Package
```swift
// Package.swift
platforms: [
    .iOS(.v15),
    .macOS(.v12),
    .watchOS(.v8),
    .tvOS(.v15),
    .visionOS(.v1)
]
```

### C++ Build
```cmake
# CMakeLists.txt
set(CMAKE_CXX_STANDARD 17)
target_link_libraries(EchoelmusicDSP PRIVATE juce::juce_audio_processors)
```

---

## FILE COUNTS

| Category | Count | Lines (est.) |
|----------|-------|--------------|
| Swift Files | 113 | ~35,000 |
| C++ Files | 201 | ~40,000 |
| Metal Shaders | 3 | ~1,500 |
| Documentation | 60+ | ~10,000 |
| **TOTAL** | **377+** | **~86,500** |

---

## VERSION HISTORY

| Version | Date | Changes |
|---------|------|---------|
| 0.1.0 | Initial | Core audio engine |
| 0.2.0 | Audio nodes, MIDI |
| 0.3.0 | Video editing, chroma key |
| 0.4.0 | Streaming, collaboration |
| 0.5.0 | 2025-11-27 | Complete UI layer (DAW, Video, VJ, CMS) |

---

*This documentation is automatically maintained. DO NOT DELETE.*
