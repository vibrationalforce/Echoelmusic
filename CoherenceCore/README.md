# CoherenceCore

**Quad-platform biophysical resonance framework for tissue micro-vibration analysis and coherent stimulation.**

> **IMPORTANT DISCLAIMER:** This is a wellness/informational tool only. NOT a medical device. Not intended to diagnose, treat, cure, or prevent any disease. Always consult a healthcare professional before starting any wellness program.

## Overview

CoherenceCore provides:

- **EVM Scanner** - Eulerian Video Magnification for detecting micro-vibrations (1-60 Hz)
- **Frequency Engine** - Precise waveform generation for vibroacoustic therapy (VAT)
- **Multi-Sensor Fusion** - Kalman-filtered combination of camera, IMU, LiDAR sensors
- **Safety Compliance** - 15-minute session limits, amplitude caps, mandatory disclaimers

## Platforms

| Platform | Framework | Status |
|----------|-----------|--------|
| iOS | Expo SDK 52+ | Development |
| Android | Expo SDK 52+ | Development |
| Windows | Tauri 2.0 | Development |
| Linux | Tauri 2.0 | Development |

## Quick Start

### Prerequisites

- Node.js 18+
- npm or yarn
- For mobile: Expo CLI (`npm install -g expo-cli`)
- For desktop: Rust toolchain (`rustup`)

### Installation

```bash
# Clone and install
cd CoherenceCore
npm install

# Build packages
npm run build
```

### Running

```bash
# Mobile (iOS Simulator)
npm run mobile:ios

# Mobile (Android)
npm run mobile:android

# Desktop (development)
npm run desktop:dev

# Run tests
npm test
```

## Architecture

```
CoherenceCore/
├── packages/
│   ├── shared-types/       # Type definitions, constants, safety limits
│   ├── frequency-engine/   # Waveform generation (sine, square, triangle, sawtooth)
│   ├── evm-engine/         # Eulerian Video Magnification processing
│   └── fusion-engine/      # Multi-sensor Kalman filtering
├── apps/
│   ├── mobile/             # Expo React Native app
│   │   ├── app/            # Screens (scan, stimulate, settings)
│   │   └── lib/            # Hooks (useCoherenceEngine)
│   └── desktop/            # Tauri + React app
│       ├── src/            # React frontend
│       └── src-tauri/      # Rust backend with cpal audio
└── docs/                   # Research documentation
```

## Features

### F001: EVM Scanner
Detects tissue micro-vibrations using camera-based Eulerian Video Magnification.

- **Frequency Range:** 1-60 Hz
- **Nyquist Validation:** Automatic check against camera FPS
- **Laplacian Pyramid:** Multi-scale spatial decomposition

### F002: IMU Analyzer
100 Hz accelerometer sampling with FFT for 30-50 Hz detection (mobile only).

### F003-F005: Frequency Presets
Research-backed frequency presets for wellness applications:

| Preset | Frequency | Research |
|--------|-----------|----------|
| Osteo-Sync | 35-45 Hz | Rubin et al. (2006) |
| Myo-Resonance | 45-50 Hz | Judex & Rubin (2010) |
| Neural-Flow | 38-42 Hz | Iaccarino et al. (2016) |
| Vaso-Pulse | 8-12 Hz | Kerschan-Schindl et al. (2001) |
| Lymph-Flow | 1-5 Hz | Piller (2015) |

### F006: VAT Output
Vibroacoustic Therapy audio output via speakers/transducers.

- **Waveforms:** Sine, Square, Triangle, Sawtooth
- **Sample Rate:** 44100 Hz
- **Amplitude Limit:** 80% max (safety)

### F009: Safety Compliance
- 15-minute maximum session duration (auto-cutoff)
- 80% maximum amplitude
- 70% duty cycle limit
- 5-minute cooldown period
- Mandatory disclaimer acknowledgment

### F011: Multi-Sensor Fusion
Kalman-filtered fusion of multiple sensor sources:

- Camera (max 30 Hz @ 4K, 60 Hz @ 1080p)
- LiDAR (effective 7.5 Hz max)
- IMU (50 Hz max)
- Active haptic measurement

## Safety Limits

```typescript
const SAFETY_LIMITS = {
  maxSessionDurationMs: 15 * 60 * 1000,  // 15 minutes
  maxAmplitude: 0.8,                      // 80%
  maxDutyCycle: 0.7,                      // 70%
  cooldownPeriodMs: 5 * 60 * 1000,       // 5 minutes
};
```

## Research Integration

Based on peer-reviewed research on:
- Organ resonance frequencies (MRE studies)
- Tissue acoustic impedance
- Sensor Nyquist limits
- iPhone LiDAR effective sampling (15 Hz, not 60 Hz)

See `docs/ORGAN_RESONANCE_RESEARCH.md` for detailed citations.

## API Reference

### useCoherenceEngine Hook (Mobile)

```typescript
const {
  session,              // Current session state
  safetyLimits,         // Safety configuration
  presets,              // Frequency presets

  // Controls
  selectPreset,         // (presetId) => void
  setFrequency,         // (hz) => void
  setAmplitude,         // (0-1) => void
  setWaveform,          // ('sine'|'square'|'triangle'|'sawtooth') => void

  // Session
  startSession,         // () => Promise<boolean>
  stopSession,          // () => Promise<void>
  toggleSession,        // () => Promise<void>

  // EVM Analysis
  startAnalysis,        // () => Promise<boolean>
  stopAnalysis,         // () => void
  updateFrameRate,      // (fps) => void
} = useCoherenceEngine();
```

### Tauri Commands (Desktop)

```rust
// Session control
start_session()
stop_session()
get_session_state() -> SessionState

// Parameters
set_frequency(frequency_hz: f32)
set_amplitude(amplitude: f32)
set_waveform(waveform: String)

// Configuration
get_presets() -> Vec<FrequencyPreset>
get_safety_limits() -> JSON
get_disclaimer() -> String
check_audio_available() -> bool
```

## Testing

```bash
# Run all tests
npm test

# Run with coverage
npm test -- --coverage

# Run specific package tests
npm test -- packages/frequency-engine
```

**Current Coverage:** 105 tests passing

## Development

### Adding a New Frequency Preset

1. Add to `packages/shared-types/src/index.ts`:
```typescript
'my-preset': {
  name: 'My Preset',
  frequencyRangeHz: [min, max],
  primaryFrequencyHz: default,
  research: 'Citation',
  target: 'Target tissue/system',
}
```

2. Add to desktop `lib.rs`:
```rust
FrequencyPreset {
  id: "my-preset".to_string(),
  name: "My Preset".to_string(),
  // ...
}
```

### Building for Production

```bash
# Mobile
cd apps/mobile
expo build:ios
expo build:android

# Desktop
cd apps/desktop
npm run tauri build
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

Proprietary - All rights reserved.

## Disclaimer

**This software is provided for wellness and informational purposes only.**

- NOT a medical device
- NOT intended to diagnose, treat, cure, or prevent any disease
- NOT a substitute for professional medical advice
- Users should consult healthcare professionals before use
- Stop use immediately if any discomfort occurs

The frequency presets are based on published research but have not been validated for clinical efficacy in this implementation.
