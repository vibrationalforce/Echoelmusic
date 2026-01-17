# Platform Strategy - Echoelmusic

## Reihenfolge der Entwicklung

```
Phase 1: Shared Core        ████████████████████ 100%
Phase 2: Apple Ecosystem    ████████████████████ 100%
Phase 3: Android            ████████████████████ 100%
Phase 4: Windows/Linux      ████████████████████ 100%
Phase 5: Web (PWA/WASM)     ████████████████████ 100%
```

**Last Updated:** 2026-01-15 | Ralph Wiggum Genius Mode Complete

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

**Status:** ✅ Complete

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

**Implemented:**
- [x] JNI Bridge for EchoelCore (`jni_bridge.cpp`)
- [x] Oboe Audio Engine (`EchoelmusicEngine.cpp`)
- [x] TR-808 Bass Synthesizer (`TR808Engine.cpp`)
- [x] SIMD Optimizations (NEON/AVX2/SSE)
- [x] Bio-reactive modulation
- [x] Health Connect integration
- [ ] Wear OS companion (future)
- [ ] Android Auto support (future)

**Files:**
```
android/app/src/main/cpp/
├── jni_bridge.cpp           # JNI ↔ Kotlin bridge
├── EchoelmusicEngine.cpp    # Oboe audio engine
├── Synth.cpp                # Polyphonic synthesizer
├── TR808Engine.cpp          # 808 bass engine
├── SIMDHelper.h             # SIMD optimizations
└── CMakeLists.txt           # NDK build config
```

## Phase 4: Windows/Linux Desktop

**Status:** ✅ Complete

**Architektur:**
```
┌─────────────────────────────────────┐
│     Qt/Dear ImGui UI                │
├─────────────────────────────────────┤
│     C++ Application Layer           │
├─────────────────────────────────────┤
│     Platform Audio Engine           │
│  (WASAPI/ASIO | ALSA/PipeWire)     │
├─────────────────────────────────────┤
│     EchoelCore (C++)                │
└─────────────────────────────────────┘
```

### Windows

**Technologie:**
- C++17
- WASAPI Exclusive Mode (<10ms latency)
- WASAPI Shared Mode (fallback)
- ASIO Bridge (FlexASIO/ASIO4ALL compatible)

**Implemented:**
- [x] WASAPI Audio Engine (`WindowsAudioEngine.hpp`)
- [x] Exclusive mode for low latency
- [x] Shared mode fallback
- [x] ASIO compatibility bridge
- [x] Device enumeration
- [x] Bio-reactive modulation
- [x] CMake build system

### Linux

**Technologie:**
- C++17
- ALSA (primary)
- PipeWire (modern systems)
- JACK (pro audio)

**Implemented:**
- [x] ALSA Audio Engine (`LinuxAudioEngine.hpp`)
- [x] PipeWire support (`PipeWireAudioEngine.hpp`)
- [x] Mixer control (ALSAMixer)
- [x] Binaural beat generator
- [x] Quantum emulator integration

**Files:**
```
Sources/DSP/
├── WindowsAudioEngine.hpp   # WASAPI + ASIO
├── LinuxAudioEngine.hpp     # ALSA
├── PipeWireAudioEngine.hpp  # PipeWire
└── EchoelmusicDSP.h         # Cross-platform DSP
```

## Phase 5: Web (PWA/WebAssembly)

**Status:** ✅ Complete

**Architektur:**
```
┌─────────────────────────────────────┐
│     React/Svelte UI                 │
├─────────────────────────────────────┤
│     TypeScript Audio Engine         │
├─────────────────────────────────────┤
│     Web Audio API + AudioWorklet    │
├─────────────────────────────────────┤
│     EchoelCore (WASM)               │
└─────────────────────────────────────┘
```

**Technologie:**
- TypeScript (primary)
- WebAssembly (high-performance DSP)
- Web Audio API + AudioWorklet
- WebGL/WebGPU (rendering)
- Web MIDI API

**Implemented:**
- [x] Web Audio Engine (`AudioEngine.ts`)
- [x] 16-voice polyphonic synthesizer
- [x] Effects chain (reverb, delay)
- [x] Bio Simulator for demos (`BioSimulator.ts`)
- [x] Breathing guide patterns
- [x] AudioWorklet processor
- [x] WASM build configuration
- [x] NPM package ready

**Files:**
```
Sources/EchoelWeb/
├── audio/
│   ├── AudioEngine.ts       # Web Audio synthesizer
│   └── AudioWorklet.ts      # Low-latency processor
├── bio/
│   └── BioSimulator.ts      # Simulated biometrics
├── wasm/
│   └── echoelcore.wasm      # Compiled DSP core
├── index.ts                 # Module exports
├── package.json             # NPM config
└── tsconfig.json            # TypeScript config
```

**Limitations:**
- No HealthKit equivalent (uses simulation)
- Higher audio latency (~20-50ms vs ~10ms native)
- Limited background processing

## Cross-Platform Considerations

### Audio APIs per Platform

| Platform | Low-Latency API | Fallback | Latency |
|----------|-----------------|----------|---------|
| iOS/macOS | Core Audio | AVAudioEngine | <10ms |
| Android | Oboe/AAudio | OpenSL ES | <15ms |
| Windows | WASAPI Exclusive | WASAPI Shared | <10ms |
| Linux | PipeWire | JACK → ALSA | <15ms |
| Web | AudioWorklet | ScriptProcessor | ~20-50ms |

### Bio-Signal Sources

| Platform | API | Data | Status |
|----------|-----|------|--------|
| Apple | HealthKit | HRV, HR, Breathing | ✅ Complete |
| Android | Health Connect | HRV, HR | ✅ Complete |
| Windows | Bluetooth LE | Raw sensor data | ✅ Complete |
| Linux | Bluetooth LE | Raw sensor data | ✅ Complete |
| Web | BioSimulator | Demo mode | ✅ Complete |

### Build System

```
/
├── Package.swift           # Apple platforms
├── build.gradle.kts        # Android
├── CMakeLists.txt          # Desktop (Windows/Linux)
├── package.json            # Web (root)
├── Sources/EchoelWeb/
│   └── package.json        # Web module
└── Makefile                # Cross-platform orchestration
```

### Line Count Summary

| Platform | Files | Lines | Language |
|----------|-------|-------|----------|
| Android | 4 | 915 | C++ |
| Windows | 1 | 641 | C++ |
| Linux | 2 | 750+ | C++ |
| Web | 6 | 1,259 | TypeScript |
| Apple | 244 | 50,000+ | Swift |

## Entscheidungsprinzipien

1. **Core First** - Nie platform-specific Code in Core
2. **Lowest Common Denominator** - Features müssen auf allen Platforms funktionieren (oder graceful degrade)
3. **Native UI** - Jede Platform bekommt native UI, kein Cross-Platform UI Framework
4. **Shared Tests** - Core-Tests laufen auf allen Platforms
5. **Same Architecture** - All platforms follow UI → Bridge → Audio Engine → DSP Core pattern

## Anti-Patterns (Verboten)

- ❌ iOS-only APIs in Core
- ❌ Platform-specific patterns als "Standard"
- ❌ UI Framework im Core
- ❌ Hardcoded Platform-Checks
- ❌ "Works on my machine" Code
- ❌ Blocking audio thread operations
- ❌ Memory allocations in real-time code

## Quality Targets (All Platforms)

| Metric | Target | Notes |
|--------|--------|-------|
| Audio Latency | <20ms | <10ms on native |
| CPU Usage | <30% | During synthesis |
| Memory | <200MB | Runtime footprint |
| Startup Time | <2s | Cold start |
| Frame Rate | 60 FPS | UI rendering |
