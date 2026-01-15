# Platform Strategy - Echoelmusic

## Reihenfolge der Entwicklung

```
Phase 1: Shared Core        ████████████████████ 100%
Phase 2: Apple Ecosystem    ████████████████████ 100%
Phase 3: Android            ████████░░░░░░░░░░░░  40%
Phase 4: Windows/Linux      ████░░░░░░░░░░░░░░░░  20%
Phase 5: Web (PWA/WASM)     ████░░░░░░░░░░░░░░░░  20%
```

## Phase 1: Shared Core (EchoelCore)

**Status:** ✅ Complete

**Inhalt:**
- Audio DSP Engine (synthesis, effects, analysis)
- Bio-Signal Processing (HRV, coherence, breathing)
- State Management (unidirectional flow)
- MIDI/OSC Protocols
- Preset System

**Technologie:**
- Swift (primary)
- C++ (performance-critical DSP)
- Platform-agnostic algorithms

**Keine Abhängigkeiten zu:**
- UIKit/AppKit/SwiftUI
- HealthKit
- CoreBluetooth
- Platform-specific APIs

## Phase 2: Apple Ecosystem

**Status:** ✅ Complete

| Platform | Status | Features |
|----------|--------|----------|
| iOS | ✅ 100% | Full app, widgets, shortcuts |
| macOS | ✅ 100% | Native app, menu bar |
| watchOS | ✅ 100% | Complications, workouts |
| tvOS | ✅ 100% | Big screen experience |
| visionOS | ✅ 100% | Immersive spaces |

**Technologie:**
- SwiftUI (UI)
- Combine (reactive)
- HealthKit (biometrics)
- Core Audio (low-latency)
- Metal (GPU rendering)

## Phase 3: Android

**Status:** 🔄 In Progress (40%)

**Architektur:**
```
┌─────────────────────────────────────┐
│     Jetpack Compose UI              │
├─────────────────────────────────────┤
│     Kotlin ViewModel Layer          │
├─────────────────────────────────────┤
│     JNI Bridge                      │
├─────────────────────────────────────┤
│     EchoelCore (C++/Kotlin)         │
└─────────────────────────────────────┘
```

**Technologie:**
- Kotlin + Compose
- Oboe (low-latency audio)
- Health Connect (biometrics)
- Vulkan (GPU rendering)

**TODO:**
- [ ] JNI Bridge for EchoelCore
- [ ] Health Connect integration
- [ ] Wear OS companion
- [ ] Android Auto support

## Phase 4: Windows/Linux Desktop

**Status:** 🔄 Planned (20%)

**Architektur:**
```
┌─────────────────────────────────────┐
│     Qt/Dear ImGui UI                │
├─────────────────────────────────────┤
│     C++ Application Layer           │
├─────────────────────────────────────┤
│     EchoelCore (C++)                │
└─────────────────────────────────────┘
```

**Technologie:**
- C++17
- WASAPI/ASIO (Windows audio)
- PipeWire/JACK (Linux audio)
- Vulkan/OpenGL (rendering)

**TODO:**
- [ ] CMake build system
- [ ] WASAPI/ASIO driver support
- [ ] VST3/CLAP plugin format
- [ ] Linux package (.deb, .rpm, Flatpak)

## Phase 5: Web (PWA/WebAssembly)

**Status:** 🔄 Experimental (20%)

**Architektur:**
```
┌─────────────────────────────────────┐
│     React/Svelte UI                 │
├─────────────────────────────────────┤
│     TypeScript Bridge               │
├─────────────────────────────────────┤
│     EchoelCore (WASM)               │
└─────────────────────────────────────┘
```

**Technologie:**
- WebAssembly (core)
- Web Audio API
- WebGL/WebGPU (rendering)
- Web MIDI API

**Limitations:**
- No HealthKit equivalent
- Higher audio latency
- Limited background processing

## Cross-Platform Considerations

### Audio APIs per Platform

| Platform | Low-Latency API | Fallback |
|----------|-----------------|----------|
| iOS/macOS | Core Audio | AVAudioEngine |
| Android | Oboe/AAudio | OpenSL ES |
| Windows | WASAPI Exclusive | WASAPI Shared |
| Linux | PipeWire | JACK → ALSA |
| Web | AudioWorklet | ScriptProcessor |

### Bio-Signal Sources

| Platform | API | Data |
|----------|-----|------|
| Apple | HealthKit | HRV, HR, Breathing |
| Android | Health Connect | HRV, HR |
| Windows | Bluetooth LE | Raw sensor data |
| Web | Simulated | Demo mode only |

### Build System

```
/
├── Package.swift           # Apple platforms
├── build.gradle.kts        # Android
├── CMakeLists.txt          # Desktop (Windows/Linux)
├── package.json            # Web
└── Makefile                # Cross-platform orchestration
```

## Entscheidungsprinzipien

1. **Core First** - Nie platform-specific Code in Core
2. **Lowest Common Denominator** - Features müssen auf allen Platforms funktionieren (oder graceful degrade)
3. **Native UI** - Jede Platform bekommt native UI, kein Cross-Platform UI Framework
4. **Shared Tests** - Core-Tests laufen auf allen Platforms

## Anti-Patterns (Verboten)

- ❌ iOS-only APIs in Core
- ❌ Platform-specific patterns als "Standard"
- ❌ UI Framework im Core
- ❌ Hardcoded Platform-Checks
- ❌ "Works on my machine" Code
