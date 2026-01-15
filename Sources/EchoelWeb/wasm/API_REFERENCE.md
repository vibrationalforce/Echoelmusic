# Echoelmusic WebAssembly API Reference

## Overview

The WebAssembly module (`echoelcore.wasm`) provides native-speed DSP for web browsers. It's compiled from C++ using Emscripten and exposes a `SynthEngine` class with full synthesis capabilities.

## Build Instructions

```bash
# Install Emscripten SDK
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk && ./emsdk install latest && ./emsdk activate latest
source ./emsdk_env.sh

# Build WASM module
cd Sources/EchoelWeb/wasm
emcc wasm_exports.cpp \
    -o echoelcore.js \
    -s WASM=1 \
    -s MODULARIZE=1 \
    -s EXPORT_NAME='createEchoelCore' \
    -s EXPORTED_RUNTIME_METHODS=['ccall','cwrap'] \
    -s ALLOW_MEMORY_GROWTH=1 \
    --bind \
    -O3

# Output files:
# - echoelcore.js   (loader)
# - echoelcore.wasm (binary)
```

## Usage

### Loading the Module

```typescript
// ES Module import
import createEchoelCore from './echoelcore.js';

async function init() {
    const Module = await createEchoelCore();
    const synth = new Module.SynthEngine();
    return synth;
}
```

### Basic Synthesis

```typescript
const synth = await init();

// Configure
synth.setSampleRate(48000);
synth.setOscType(2);  // Sawtooth
synth.setFilterCutoff(5000);
synth.setFilterResonance(0.3);

// Play note
synth.noteOn(60, 100);  // Middle C, velocity 100

// Process audio
const bufferSize = 256;
const buffer = new Float32Array(bufferSize);
synth.processBlock(buffer.byteOffset, bufferSize);

// Release note
synth.noteOff(60);
```

### Integration with Web Audio API

```typescript
const context = new AudioContext();
const Module = await createEchoelCore();
const synth = new Module.SynthEngine();
synth.setSampleRate(context.sampleRate);

// Create ScriptProcessor (or AudioWorklet)
const processor = context.createScriptProcessor(256, 0, 2);

processor.onaudioprocess = (e) => {
    const output = e.outputBuffer.getChannelData(0);
    synth.processBlock(output.byteOffset, output.length);

    // Copy to right channel
    e.outputBuffer.getChannelData(1).set(output);
};

processor.connect(context.destination);
```

## API Reference

### SynthEngine Class

#### Constructor

```cpp
SynthEngine()
```

Creates a new synthesizer engine with 16 voices.

#### Methods

| Method | Parameters | Description |
|--------|------------|-------------|
| `setSampleRate` | `float sr` | Set sample rate (default: 48000) |
| `noteOn` | `int note, int velocity` | Start playing a MIDI note (0-127) |
| `noteOff` | `int note` | Release a MIDI note |
| `allNotesOff` | - | Release all playing notes |
| `process` | - | Process and return single sample |
| `processBlock` | `uintptr_t ptr, int frames` | Process block of samples |
| `setOscType` | `int type` | Set oscillator waveform |
| `setFilterCutoff` | `float hz` | Set filter cutoff (20-20000) |
| `setFilterResonance` | `float res` | Set filter resonance (0-1) |
| `setAttack` | `float ms` | Set attack time in ms |
| `setDecay` | `float ms` | Set decay time in ms |
| `setSustain` | `float level` | Set sustain level (0-1) |
| `setRelease` | `float ms` | Set release time in ms |
| `setMasterVolume` | `float vol` | Set master volume (0-1) |
| `setBioModulation` | `float hr, float coh, float phase` | Set bio-reactive modulation |

#### Oscillator Types

| Value | Type |
|-------|------|
| 0 | Sine |
| 1 | Triangle |
| 2 | Sawtooth (default) |
| 3 | Square |

### Memory Management

The WASM module uses Emscripten's memory management. When passing buffers:

```typescript
// Allocate buffer in WASM memory
const bufferSize = 256;
const ptr = Module._malloc(bufferSize * 4);  // 4 bytes per float
const buffer = new Float32Array(Module.HEAPF32.buffer, ptr, bufferSize);

// Process
synth.processBlock(ptr, bufferSize);

// Use buffer data...
console.log(buffer[0]);

// Free when done
Module._free(ptr);
```

### Performance Tips

1. **Reuse buffers** - Don't allocate on every process call
2. **Use processBlock** - More efficient than per-sample processing
3. **Match sample rates** - Set WASM sample rate to match AudioContext
4. **Avoid GC pauses** - Pre-allocate all memory before real-time processing

## DSP Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      SynthEngine                            │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐       ┌─────────┐  ┌─────────┐   │
│  │ Voice 0 │  │ Voice 1 │  ...  │Voice 14 │  │Voice 15 │   │
│  └────┬────┘  └────┬────┘       └────┬────┘  └────┬────┘   │
│       │            │                 │            │         │
│       └────────────┴────────┬────────┴────────────┘         │
│                             │                               │
│                    ┌────────▼────────┐                      │
│                    │   Soft Clipper  │                      │
│                    └────────┬────────┘                      │
│                             │                               │
│                    ┌────────▼────────┐                      │
│                    │  Master Volume  │                      │
│                    └────────┬────────┘                      │
│                             │                               │
│                          Output                             │
└─────────────────────────────────────────────────────────────┘

Voice Architecture:
┌─────────────────────────────────────────┐
│                 Voice                    │
├─────────────────────────────────────────┤
│  ┌────────────┐     ┌────────────┐      │
│  │ Oscillator │────▶│   Filter   │      │
│  │ (PolyBLEP) │     │   (SVF)    │      │
│  └────────────┘     └─────┬──────┘      │
│                           │             │
│                    ┌──────▼──────┐      │
│                    │  Envelope   │      │
│                    │   (ADSR)    │      │
│                    └──────┬──────┘      │
│                           │             │
│                        Output           │
└─────────────────────────────────────────┘
```

## Bio-Reactive Modulation

The `setBioModulation` method allows real-time modulation based on biometric data:

| Parameter | Range | Effect |
|-----------|-------|--------|
| heartRate | 40-200 BPM | Currently unused (reserved) |
| coherence | 0-1 | Adds +2000Hz to filter cutoff at max |
| breathPhase | 0-1 | Currently unused (reserved) |

```typescript
// High coherence = brighter sound
synth.setBioModulation(75, 0.8, 0.5);
```

## Error Handling

The WASM module performs bounds checking internally:

- Note values are clamped to 0-127
- Velocity values are clamped to 0-127
- Filter cutoff is clamped to 20-20000 Hz
- Resonance is clamped to 0-1
- Volume is clamped to 0-1

No exceptions are thrown; invalid values are silently clamped.

## File Sizes (Optimized Build)

| File | Size | Compressed |
|------|------|------------|
| echoelcore.wasm | ~45 KB | ~15 KB (gzip) |
| echoelcore.js | ~25 KB | ~8 KB (gzip) |

## Browser Compatibility

| Browser | WASM | SharedArrayBuffer | Notes |
|---------|------|-------------------|-------|
| Chrome 57+ | ✅ | ✅ | Full support |
| Firefox 52+ | ✅ | ✅ | Full support |
| Safari 11+ | ✅ | ✅ (15.2+) | Full support |
| Edge 79+ | ✅ | ✅ | Full support |

## License

MIT License - See main repository for details.
