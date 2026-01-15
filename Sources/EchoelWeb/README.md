# Echoelmusic Web Module

Bio-reactive audio synthesis for web browsers using Web Audio API.

## Features

- 🎹 **16-voice polyphonic synthesizer** - Full ADSR envelopes, filters, effects
- 🫀 **Bio-reactive modulation** - HRV coherence drives audio parameters
- ⚡ **AudioWorklet support** - Real-time DSP on dedicated audio thread
- 🔧 **WebAssembly DSP** - Native-speed synthesis via WASM
- 🧘 **Breathing guides** - Coherence, box breathing, 4-7-8 patterns

## Quick Start

```typescript
import { createAudioEngine, createBioSimulator } from '@echoelmusic/web';

// Initialize audio engine
const audio = await createAudioEngine();
if (!audio) throw new Error('Web Audio not supported');

// Start bio simulator (demo mode)
const bio = createBioSimulator('calm');
bio.start();

// Connect bio data to audio
bio.onData((data) => {
    audio.setBioModulation(data);
});
audio.setBioModulationEnabled(true);

// Play notes
audio.noteOn(60, 100);  // Middle C, velocity 100
setTimeout(() => audio.noteOff(60), 500);
```

## Low-Latency Mode (AudioWorklet)

For lowest latency (~10ms vs ~50ms), use the AudioWorklet-based synthesizer:

```typescript
import { createWorkletSynth } from '@echoelmusic/web';

const context = new AudioContext();
const synth = await createWorkletSynth(context);

if (synth) {
    synth.connect(context.destination);
    synth.noteOn(60, 100);

    // Update bio modulation
    synth.setBioModulation(75, 0.8, 0.5);
}
```

## WebAssembly (Highest Performance)

For maximum performance, use the WASM DSP core:

```typescript
// Load WASM module
import createModule from './wasm/echoelcore.js';

const Module = await createModule();
const synth = new Module.SynthEngine();

synth.setSampleRate(48000);
synth.noteOn(60, 100);

// Process audio block
const buffer = new Float32Array(256);
synth.processBlock(buffer.byteOffset, 256);
```

## API Reference

### AudioEngine

| Method | Description |
|--------|-------------|
| `noteOn(note, velocity)` | Play a MIDI note (0-127) |
| `noteOff(note)` | Release a note |
| `allNotesOff()` | Release all notes |
| `setWaveform(type)` | 'sine', 'triangle', 'sawtooth', 'square' |
| `setFilterCutoff(hz)` | Filter cutoff 20-20000 Hz |
| `setFilterResonance(q)` | Filter resonance 0-1 |
| `setEnvelope({a,d,s,r})` | ADSR in ms (sustain 0-1) |
| `setReverbMix(mix)` | Reverb wet/dry 0-1 |
| `setDelayTime(sec)` | Delay time 0-2 seconds |
| `setBioModulation(data)` | Set bio-reactive parameters |

### BioSimulator

| Method | Description |
|--------|-------------|
| `start()` | Begin simulation |
| `stop()` | Stop simulation |
| `setState(state)` | 'calm', 'active', 'meditation', 'stress' |
| `onData(callback)` | Subscribe to bio data updates |
| `getCurrentData()` | Get current bio metrics |

### BreathingGuide

| Pattern | Inhale | Hold | Exhale | Hold |
|---------|--------|------|--------|------|
| relaxation | 4s | - | 6s | - |
| coherence | 5s | - | 5s | - |
| box | 4s | 4s | 4s | 4s |
| 478 | 4s | 7s | 8s | - |
| energizing | 4s | - | 2s | - |

## Browser Support

| Browser | Version | Notes |
|---------|---------|-------|
| Chrome | 66+ | Full support |
| Firefox | 76+ | Full support |
| Safari | 14.1+ | Full support |
| Edge | 79+ | Full support |

### Feature Detection

```typescript
import { checkBrowserCapabilities, isSupported } from '@echoelmusic/web';

if (!isSupported()) {
    console.error('Web Audio not supported');
}

const caps = checkBrowserCapabilities();
console.log('AudioWorklet:', caps.audioWorklet);
console.log('Web MIDI:', caps.webMidi);
console.log('WebGPU:', caps.webGPU);
```

## Build

```bash
# Install dependencies
npm install

# Development
npm run dev

# Build for production
npm run build

# Run tests
npm test

# Type check
npm run typecheck
```

## Build WASM Module

```bash
# Requires Emscripten SDK
source /path/to/emsdk/emsdk_env.sh

# Build
emcc wasm/wasm_exports.cpp \
    -o wasm/echoelcore.js \
    -s WASM=1 \
    -s EXPORTED_RUNTIME_METHODS=['ccall','cwrap'] \
    -s ALLOW_MEMORY_GROWTH=1 \
    --bind \
    -O3
```

## Architecture

```
┌─────────────────────────────────────────┐
│            Application Layer            │
├─────────────────────────────────────────┤
│  AudioEngine  │  BioSimulator  │  MIDI  │
├───────────────┴────────────────┴────────┤
│           AudioWorklet Thread           │
│    (Real-time DSP, no GC pauses)       │
├─────────────────────────────────────────┤
│         WebAssembly DSP Core            │
│   (C++ compiled, native performance)    │
├─────────────────────────────────────────┤
│            Web Audio API                │
└─────────────────────────────────────────┘
```

## License

MIT License - See LICENSE file for details.

## Links

- [Main Repository](https://github.com/echoelmusic/echoelmusic)
- [Documentation](https://docs.echoelmusic.com)
- [API Reference](./API_REFERENCE.md)
