# DSP Module (C++)

Cross-platform Digital Signal Processing library for Windows, Linux, and macOS.

## Components

### DynamicEQ
8-band dynamic equalizer with per-band compression:
- Multiple filter types (Bell, Shelf, Cut, Notch)
- Per-band dynamics processing
- Bio-reactive modulation
- 12/24/48 dB/octave slopes

### SpectralSculptor
FFT-based spectral manipulation:
- Real-time FFT (up to 8192 bins)
- Spectral freeze/blur/smear
- Frequency shifting
- Harmonic enhancement
- Robotize/Whisper effects

### HardwareEcosystem
Universal hardware device registry:
- 60+ Audio interfaces
- 40+ MIDI controllers
- DMX/Art-Net controllers
- Cameras and capture cards
- Video switchers

## Build

```bash
mkdir build && cd build

# Pure native mode (recommended)
cmake .. -DUSE_JUCE=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build . --parallel

# With JUCE (optional, for VST3/AU)
cmake .. -DUSE_JUCE=ON -DCMAKE_BUILD_TYPE=Release
```

## Platform-Specific APIs

| Platform | Audio API | Notes |
|----------|-----------|-------|
| macOS | Core Audio | Native, lowest latency |
| Windows | WASAPI/ASIO | ASIO for pro audio |
| Linux | PipeWire/JACK | PipeWire recommended |

## Usage (C++)

```cpp
#include "DynamicEQ.h"
#include "SpectralSculptor.h"

using namespace Echoelmusic::DSP;

// Dynamic EQ
DynamicEQ eq;
eq.setSampleRate(48000);
eq.setBandFrequency(0, 100.0f);
eq.setBandGain(0, 3.0f);
eq.process(leftChannel, rightChannel, numSamples);

// Spectral processing
SpectralSculptor sculpt(2048);
sculpt.setMode(SpectralMode::BioReactive);
sculpt.setBioModulation(coherence, heartRate, breathPhase);
sculpt.process(input, output, numSamples);
```

## Thread Safety

All DSP classes are designed for single-threaded audio processing.
Create separate instances for multi-threaded use.
