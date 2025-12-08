# Echoelmusic Architecture Documentation

## Overview

Echoelmusic is a bio-reactive audio-visual music creation platform that synchronizes audio, visuals, and user bio-data in real-time. This document outlines the architectural decisions, system design, and technical guidelines for the project.

---

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Core Patterns](#core-patterns)
3. [Module Structure](#module-structure)
4. [Data Flow](#data-flow)
5. [Platform Support](#platform-support)
6. [Architecture Decision Records](#architecture-decision-records)

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        ECHOELMUSIC PLATFORM                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │
│  │   Audio     │  │   Visual    │  │  Bio-Data   │  │   MIDI    │  │
│  │   Engine    │  │   Engine    │  │   Engine    │  │  Engine   │  │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬─────┘  │
│         │                │                │               │         │
│         └────────────────┼────────────────┼───────────────┘         │
│                          │                │                         │
│                   ┌──────┴──────┐  ┌──────┴──────┐                  │
│                   │   Unified   │  │  Platform   │                  │
│                   │ Control Hub │  │   Manager   │                  │
│                   │   (60 Hz)   │  │             │                  │
│                   └──────┬──────┘  └─────────────┘                  │
│                          │                                          │
│              ┌───────────┴───────────┐                              │
│              │     Core Services     │                              │
│              │  • Self-Healing       │                              │
│              │  • Error Recovery     │                              │
│              │  • State Management   │                              │
│              │  • Privacy Manager    │                              │
│              └───────────────────────┘                              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Unified Control Hub Pattern

The **Unified Control Hub** is the central orchestrator running at 60 Hz. It:

1. Receives input from all sources (audio, bio-data, MIDI, gestures)
2. Processes and normalizes data
3. Distributes synchronized commands to all output systems
4. Maintains system state consistency

```swift
// Core control loop (simplified)
@MainActor
class UnifiedControlHub {
    private var displayLink: CADisplayLink?

    func startControlLoop() {
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func tick() {
        // 1. Gather inputs
        let audioLevel = audioEngine.currentLevel
        let bioState = bioEngine.currentState
        let midiEvents = midiEngine.pendingEvents

        // 2. Process through decision engine
        let commands = processInputs(audio: audioLevel, bio: bioState, midi: midiEvents)

        // 3. Dispatch to outputs
        visualEngine.update(commands.visual)
        audioEngine.applyEffects(commands.audio)
        hapticEngine.trigger(commands.haptic)
    }
}
```

---

## Core Patterns

### 1. Observer Pattern (Combine Framework)

All state changes propagate through `@Published` properties and Combine publishers.

```swift
class AudioEngine: ObservableObject {
    @Published var currentLevel: Float = 0
    @Published var isPlaying: Bool = false

    // Subscribers automatically receive updates
}
```

### 2. Protocol-Oriented Design

Modules communicate through protocols, enabling testability and platform abstraction.

```swift
protocol AudioBridgeProtocol {
    func initialize(config: AudioConfig) async throws
    func start() async throws
    func stop() async
}

// Platform-specific implementations
#if os(iOS)
class iOSAudioBridge: AudioBridgeProtocol { ... }
#elseif os(Android)
class AndroidAudioBridge: AudioBridgeProtocol { ... }
#endif
```

### 3. Dependency Injection

Services are injected rather than created, improving testability.

```swift
class SessionManager {
    private let audioEngine: AudioEngineProtocol
    private let bioProcessor: BioProcessorProtocol

    init(audioEngine: AudioEngineProtocol, bioProcessor: BioProcessorProtocol) {
        self.audioEngine = audioEngine
        self.bioProcessor = bioProcessor
    }
}
```

### 4. SIMD-First Processing

All audio and numerical processing uses SIMD operations via the Accelerate framework.

```swift
// Instead of:
for i in 0..<buffer.count {
    buffer[i] = buffer[i] * gain
}

// Use:
vDSP_vsmul(buffer, 1, &gain, buffer, 1, vDSP_Length(buffer.count))
```

---

## Module Structure

```
Sources/Echoelmusic/
├── Core/
│   ├── EchoelUniversalCore.swift    # Central state management
│   ├── SelfHealingEngine.swift      # Auto-recovery system
│   └── SystemResilience.swift       # Error handling & memory management
│
├── Audio/
│   ├── AudioEngine.swift            # Core audio processing
│   ├── DSP/                         # Signal processing algorithms
│   └── VocalAlignment/              # Vocal tools
│
├── Visual/
│   ├── UnifiedVisualSoundEngine.swift
│   ├── CymaticsRenderer.swift
│   └── Visualizers/                 # Visualization modes
│
├── Biofeedback/
│   ├── HealthKitManager.swift       # Apple Health integration
│   └── BioParameterMapper.swift     # Bio-to-audio mapping
│
├── MIDI/
│   ├── MIDI2Manager.swift           # MIDI 2.0 UMP support
│   └── MPEZoneManager.swift         # MPE configuration
│
├── Spatial/
│   └── SpatialAudioEngine.swift     # 3D/Ambisonics audio
│
├── Recording/
│   ├── RecordingEngine.swift        # Multi-track recording
│   └── ExportManager.swift          # File export
│
├── Unified/
│   └── UnifiedControlHub.swift      # Central 60 Hz coordinator
│
├── Platforms/
│   ├── UnifiedMultiPlatformLayer.swift
│   ├── PlatformSpecificOptimizations.swift
│   └── iOS/, macOS/, watchOS/, etc.
│
├── Bridges/
│   ├── CrossPlatformAudioBridge.swift
│   └── CrossPlatformVisualBridge.swift
│
├── Privacy/
│   ├── PrivacyManager.swift
│   └── BioDataPrivacyManager.swift
│
├── Science/
│   └── ValidatedBioAlgorithms.swift # Peer-reviewed HRV algorithms
│
└── Accessibility/
    └── ComprehensiveAccessibility.swift
```

---

## Data Flow

### Bio-Reactive Audio Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   HealthKit  │────▶│  Bio Engine  │────▶│  Parameter   │
│  (Raw Data)  │     │ (Processing) │     │   Mapper     │
└──────────────┘     └──────────────┘     └──────┬───────┘
                                                  │
         ┌────────────────────────────────────────┘
         │
         ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│    Audio     │────▶│   Effects    │────▶│   Speaker/   │
│  Generator   │     │  Processing  │     │  Headphones  │
└──────────────┘     └──────────────┘     └──────────────┘
```

### Real-Time Audio Path

```
Input ──▶ Buffer (128-512 samples) ──▶ DSP Chain ──▶ Output
              │                            │
              └──────── < 10ms ────────────┘
                    (Total Latency)
```

---

## Platform Support

| Platform  | Audio API      | Graphics API | Bio API      |
|-----------|----------------|--------------|--------------|
| iOS       | AVAudioEngine  | Metal        | HealthKit    |
| macOS     | AVAudioEngine  | Metal        | HealthKit    |
| watchOS   | AVAudioEngine  | Metal        | HealthKit    |
| tvOS      | AVAudioEngine  | Metal        | -            |
| visionOS  | AVAudioEngine  | Metal        | HealthKit    |
| Android   | Oboe           | Vulkan       | Health Connect |
| Windows   | ASIO/WASAPI    | DirectX/Vulkan | -          |
| Linux     | JACK/PipeWire  | Vulkan/OpenGL | -          |

---

## Architecture Decision Records

### ADR-001: 60 Hz Control Loop

**Status:** Accepted

**Context:** Need to synchronize audio, visual, and bio-data processing with minimal latency.

**Decision:** Implement a central control loop running at 60 Hz using `CADisplayLink` on Apple platforms.

**Consequences:**
- Consistent 16.67ms update interval
- Matches display refresh rate for smooth visuals
- Simplifies synchronization logic
- Higher CPU usage than event-driven approach

---

### ADR-002: Combine for Reactive State

**Status:** Accepted

**Context:** Need reactive state management across all modules.

**Decision:** Use Apple's Combine framework with `@Published` properties.

**Consequences:**
- Native SwiftUI integration
- Type-safe reactive streams
- Apple-platform only (Android uses Kotlin Flow)
- Learning curve for developers new to reactive programming

---

### ADR-003: SIMD-First Audio Processing

**Status:** Accepted

**Context:** Audio processing must meet real-time constraints (<10ms latency).

**Decision:** Use Accelerate framework's SIMD operations for all audio math.

**Consequences:**
- 4-8x performance improvement over scalar code
- Hardware-optimized on all Apple Silicon
- Code is less readable without abstraction layer
- Platform-specific (need equivalent for Android/Windows)

---

### ADR-004: Privacy-First Bio-Data Architecture

**Status:** Accepted

**Context:** Bio-data (heart rate, HRV) is sensitive personal information.

**Decision:** Implement on-device processing by default, encryption for storage, and explicit consent for each data type.

**Consequences:**
- GDPR/CCPA compliance
- User trust
- More complex data flow
- Limited cloud features without explicit consent

---

### ADR-005: Scientific Validation for Bio-Algorithms

**Status:** Accepted

**Context:** HRV and coherence calculations must be credible and reproducible.

**Decision:** Implement algorithms strictly per Task Force of ESC/NASPE (1996) standards with full citations.

**Consequences:**
- Clinical credibility
- Reproducible results
- Can't use proprietary/unvalidated algorithms
- Requires ongoing literature review

---

### ADR-006: Platform Abstraction Layer

**Status:** Accepted

**Context:** Need to support 8 platforms with platform-specific optimizations.

**Decision:** Create unified API layer with platform-specific implementations behind protocols.

**Consequences:**
- Single codebase for business logic
- Platform-optimal performance
- Increased code complexity
- Testing required on all platforms

---

### ADR-007: Accessibility as Core Feature

**Status:** Accepted

**Context:** Music creation should be accessible to users with disabilities.

**Decision:** Build accessibility support into all UI components from the start, targeting WCAG 2.1 AA compliance.

**Consequences:**
- Larger potential user base (+15-20%)
- Legal compliance
- Additional development time
- Some visual-focused features need audio alternatives

---

### ADR-008: Self-Healing Error Recovery

**Status:** Accepted

**Context:** Audio applications must be resilient to errors (device disconnection, interruptions).

**Decision:** Implement automatic error recovery with exponential backoff.

**Consequences:**
- Better user experience
- Reduced support burden
- Risk of masking real issues if logging insufficient
- Complexity in error handling code

---

## Performance Guidelines

### Audio Performance Targets

| Metric | Target | Critical |
|--------|--------|----------|
| Latency | < 10ms | < 20ms |
| Buffer underruns | 0 | < 1/hour |
| CPU usage | < 30% | < 50% |

### Visual Performance Targets

| Metric | Target | Critical |
|--------|--------|----------|
| Frame rate | 60 FPS | 30 FPS |
| Frame time | < 16ms | < 33ms |
| GPU memory | < 256MB | < 512MB |

### Memory Guidelines

- Audio buffers: Pre-allocate, use pools
- Textures: Load on demand, release when hidden
- Caches: Register with `MemoryPressureManager`
- Strings: Avoid allocations in audio thread

---

## Security Considerations

1. **Bio-Data Encryption:** AES-256-GCM for storage
2. **Keychain:** Encryption keys stored in Secure Enclave
3. **Network:** TLS 1.3 for all communications
4. **Biometric Auth:** Required for high-sensitivity data access
5. **No Analytics:** No bio-data sent to analytics services

---

## Contributing

When adding new features:

1. Create an ADR for significant architectural decisions
2. Follow existing patterns (Protocol-Oriented, SIMD-first)
3. Add accessibility support from the start
4. Write tests (target: 80% coverage)
5. Document scientific sources for bio-algorithms

---

*Last Updated: December 2024*
*Version: 2.0*
