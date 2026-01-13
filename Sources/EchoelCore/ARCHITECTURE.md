# EchoelCore - Bio-Reactive Audio Framework

## Why Not JUCE or iPlug2?

| Framework | Issue for Echoelmusic |
|-----------|----------------------|
| **JUCE** | GPL/Commercial license, bloated binaries (5MB+ for simple plugin), no native CLAP support |
| **iPlug2** | Single maintainer, limited bio-reactive primitives, no native CLAP |
| **nih-plug** | Rust-only (our codebase is C++/Swift), learning curve |

## EchoelCore Design Principles

1. **Zero-Allocation Audio** - All buffers pre-allocated, no heap in RT thread
2. **Lock-Free First** - SPSC queues for all thread communication
3. **Bio-Reactive Native** - First-class support for HRV, heart rate, coherence
4. **CLAP-Native** - Built on CLAP (MIT), with VST3/AU wrappers
5. **Header-Only Core** - Minimal dependencies, easy to integrate
6. **SIMD Everywhere** - AVX2/NEON optimized DSP primitives

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      EchoelCore Framework                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │ Lock-Free   │  │ Bio Bridge  │  │ DSP Primitives          │ │
│  │ Primitives  │  │             │  │                         │ │
│  │             │  │ HRV → Param │  │ • SIMD Filters          │ │
│  │ • SPSCQueue │  │ HR → BPM    │  │ • Oscillators           │ │
│  │ • AtomicRef │  │ Coh → Mix   │  │ • Envelope Generators   │ │
│  │ • RingBuf   │  │ Breath→LFO  │  │ • FFT (no alloc)        │ │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘ │
│         │                │                     │               │
│  ┌──────▼────────────────▼─────────────────────▼─────────────┐ │
│  │                    Audio Engine                            │ │
│  │  • Real-time safe parameter updates                        │ │
│  │  • Pre-allocated voice pool                                │ │
│  │  • Zero-copy buffer management                             │ │
│  └──────────────────────────┬────────────────────────────────┘ │
│                             │                                   │
│  ┌──────────────────────────▼────────────────────────────────┐ │
│  │                   Plugin Wrappers                          │ │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐       │ │
│  │  │  CLAP   │  │  VST3   │  │   AU    │  │  WASM   │       │ │
│  │  │ Native  │  │ Wrapper │  │ Wrapper │  │ Wrapper │       │ │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘       │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Lock-Free Communication Model

```
   SENSOR THREAD                    AUDIO THREAD                UI THREAD
   (HealthKit/BLE)                  (Real-time)                 (Main)
        │                               │                          │
        │  atomic<BioState>             │                          │
        ├──────────────────────────────►│                          │
        │  (relaxed ordering)           │                          │
        │                               │                          │
        │                               │  SPSCQueue<SpectrumData> │
        │                               ├─────────────────────────►│
        │                               │                          │
        │                               │  SPSCQueue<ParamChange>  │
        │                               │◄─────────────────────────┤
        │                               │                          │
```

## Bio-Reactive Parameter Mapping

```cpp
// EchoelCore provides native bio→audio mapping
struct BioState {
    std::atomic<float> hrv{0.5f};         // 0-1 normalized
    std::atomic<float> coherence{0.5f};   // 0-1 HeartMath style
    std::atomic<float> heartRate{70.0f};  // BPM
    std::atomic<float> breathPhase{0.0f}; // 0-1 cycle position
    std::atomic<float> breathRate{6.0f};  // Breaths/min
};

// Mapping declarations (compile-time checked)
BioMapping mappings[] = {
    {Bio::HRV,       Param::FilterCutoff, Curve::Exponential, 0.3f},
    {Bio::Coherence, Param::ReverbMix,    Curve::Linear,      0.5f},
    {Bio::HeartRate, Param::LFORate,      Curve::Logarithmic, 0.2f},
    {Bio::Breath,    Param::GrainDensity, Curve::Sine,        0.4f},
};
```

## CLAP Extensions for Bio-Reactive

EchoelCore defines custom CLAP extensions:

```c
// clap-ext-biofeedback.h
#define CLAP_EXT_BIOFEEDBACK "echoelmusic.biofeedback/1"

typedef struct clap_plugin_biofeedback {
    // Update bio state (called from sensor thread)
    void (*update_bio_state)(
        const clap_plugin_t *plugin,
        float hrv,
        float coherence,
        float heart_rate,
        float breath_phase
    );

    // Get current bio modulation depth
    float (*get_modulation_depth)(
        const clap_plugin_t *plugin,
        clap_id param_id
    );
} clap_plugin_biofeedback_t;
```

## Performance Targets

| Metric | Target | How |
|--------|--------|-----|
| Audio latency | <3ms | Lock-free, pre-allocated |
| Bio→Audio latency | <16ms | Atomic reads, no mutex |
| CPU (8 voices) | <5% | SIMD, no allocation |
| Binary size | <500KB | Header-only, no bloat |
| Memory | <10MB | Fixed pools |

## Comparison with Existing Frameworks

| Feature | JUCE | iPlug2 | EchoelCore |
|---------|------|--------|------------|
| License | GPL/$$$ | MIT | MIT |
| CLAP Support | No | No | Native |
| Bio-Reactive | No | No | Native |
| Lock-Free | Partial | Partial | 100% |
| Binary Size | 5MB+ | 1MB+ | <500KB |
| Dependencies | Many | Some | Header-only |
| WASM | Via iPlug2 | Yes | Yes |

## File Structure

```
EchoelCore/
├── EchoelCore.h              # Single-include header
├── ARCHITECTURE.md           # This file
│
├── Lock-Free/
│   ├── SPSCQueue.h           # Single-producer single-consumer queue
│   ├── AtomicState.h         # Atomic state management
│   └── RingBuffer.h          # Lock-free ring buffer
│
├── Bio/
│   ├── BioState.h            # Bio-reactive state container
│   ├── BioMapping.h          # Parameter mapping system
│   └── BioBridge.h           # Platform-specific bio input
│
├── Audio/
│   ├── AudioEngine.h         # Core audio processing
│   ├── VoicePool.h           # Pre-allocated voice management
│   └── BufferManager.h       # Zero-copy buffer handling
│
├── DSP/
│   ├── SIMDOps.h             # SIMD-optimized operations
│   ├── Filters.h             # IIR/FIR filters
│   ├── Oscillators.h         # Wavetable/analog oscillators
│   └── FFT.h                 # Zero-allocation FFT
│
├── CLAP/
│   ├── CLAPPlugin.h          # CLAP plugin base class
│   ├── CLAPBioExt.h          # Bio-reactive CLAP extension
│   └── CLAPEntry.h           # Plugin entry point
│
└── Platform/
    ├── CoreAudio.h           # macOS/iOS backend
    ├── WASAPI.h              # Windows backend
    ├── ALSA.h                # Linux backend
    └── WebAudio.h            # WASM/Browser backend
```

## Sources & References

- [CLAP Official Repository](https://github.com/free-audio/clap)
- [CLAP Tutorial by Nakst](https://nakst.gitlab.io/tutorial/clap-part-1.html)
- [cameron314/readerwriterqueue](https://github.com/cameron314/readerwriterqueue)
- [rigtorp/SPSCQueue](https://github.com/rigtorp/SPSCQueue)
- [Ross Bencina - Real-time Audio Programming](http://www.rossbencina.com/code/real-time-audio-programming-101-time-waits-for-nothing)
- [HeartDJ Research - HRV Music Generation](https://digitalcommons.dartmouth.edu/masters_theses/205/)
- [nih-plug Rust Framework](https://github.com/robbert-vdh/nih-plug)
