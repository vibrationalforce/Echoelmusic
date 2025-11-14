# Echoelmusic Desktop Engine

JUCE-based audio processing and synthesis engine for the Echoelmusic system.

## Status

🚧 **In Development** - Architecture planning phase

This component is currently being designed. The iOS app is functional and can be developed independently.

## Overview

The Desktop Engine receives biofeedback data from the iOS app via OSC and generates real-time audio using JUCE's audio processing framework.

## Features (Planned)

- **OSC Server**: Receives biofeedback data on UDP port 8000
- **Audio Synthesis**: Multiple synthesis engines (subtractive, granular, sampler)
- **Effects Processing**: Reverb, delay, filter, distortion
- **Spatial Audio**: Dolby Atmos, Ambisonics, Binaural rendering
- **Parameter Mapping**: Biofeedback → audio parameters
- **Analysis**: FFT spectrum, RMS/Peak metering, sent back to iOS
- **LED Control**: UDP socket for external LED controllers

## Requirements

### Software

- **JUCE Framework**: 7.0 or later
  - Download: https://juce.com/get-juce/download
- **IDE**:
  - macOS: Xcode 15+
  - Windows: Visual Studio 2022
  - Linux: GCC 9+ or Clang 10+
- **CMake**: 3.22+ (optional, for custom builds)

### Hardware

- **Audio Interface**: Recommended for low-latency (< 10ms)
- **CPU**: Multi-core recommended (audio processing is CPU-intensive)
- **Network**: WiFi connection to iOS device

## Quick Start

### 1. Install JUCE

```bash
# Via git
git clone https://github.com/juce-framework/JUCE.git ~/JUCE
cd ~/JUCE
git checkout 7.0.9  # Or latest stable

# Or download from https://juce.com/get-juce/download
```

### 2. Create Project in Projucer

Since the project is in planning phase, you'll create it:

```bash
cd ~/JUCE
open Projucer.app  # macOS
# or
./Projucer  # Linux/Windows
```

In Projucer:
1. File → New Project
2. Type: **Standalone Application**
3. Name: **Echoelmusic**
4. Location: `Echoelmusic/desktop-engine/`

### 3. Add Required Modules

Select these JUCE modules:
- `juce_audio_basics`
- `juce_audio_devices`
- `juce_audio_processors`
- `juce_audio_utils`
- `juce_core`
- `juce_data_structures`
- `juce_events`
- `juce_graphics`
- `juce_gui_basics`
- `juce_osc` ← **Critical for OSC communication**

### 4. Create Source Files

Create this structure in `Source/`:

```
Source/
├── Main.cpp                    # Entry point
├── MainComponent.h/cpp         # Main UI and audio
├── OSC/
│   ├── OSCManager.h/cpp        # OSC server implementation
│   └── OSCReceiver.h/cpp       # Message parsing
├── Audio/
│   ├── EchoelSynth.h/cpp       # Synthesis engine
│   ├── AudioProcessor.h/cpp    # Main audio processor
│   └── Effects/
│       ├── Reverb.h/cpp
│       ├── Delay.h/cpp
│       └── Filter.h/cpp
├── DSP/
│   ├── BioMapper.h/cpp         # Biofeedback → audio mapping
│   └── Analysis.h/cpp          # Spectrum, RMS analysis
└── LED/
    └── LEDController.h/cpp     # UDP LED control
```

### 5. Implement OSC Server

Use template from `/docs/osc-protocol.md`:

**OSC/OSCManager.h**:
```cpp
#pragma once
#include <JuceHeader.h>

class OSCManager : public juce::OSCReceiver,
                   private juce::OSCReceiver::Listener<juce::OSCReceiver::MessageLoopCallback>
{
public:
    OSCManager();
    ~OSCManager() override;

    bool initialize(int port = 8000);
    void shutdown();

    // Callbacks for received biofeedback
    std::function<void(float)> onHeartRateReceived;
    std::function<void(float)> onHRVReceived;
    std::function<void(float, float)> onPitchReceived;

    // Send analysis back to iOS
    void sendAudioAnalysis(float rmsDb, float peakDb);
    void sendSpectrum(const std::vector<float>& bands);

private:
    void oscMessageReceived(const juce::OSCMessage& message) override;

    juce::OSCSender oscSender;
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(OSCManager)
};
```

See full implementation in `/docs/osc-protocol.md`.

### 6. Build

**macOS**:
```bash
cd desktop-engine/Builds/MacOSX
xcodebuild -configuration Release
open build/Release/Echoelmusic.app
```

**Windows**:
```bash
cd desktop-engine\Builds\VisualStudio2022
msbuild Echoelmusic.sln /p:Configuration=Release
.\build\Release\Echoelmusic.exe
```

**Linux**:
```bash
cd desktop-engine/Builds/LinuxMakefile
make CONFIG=Release
./build/Echoelmusic
```

## Planned Architecture

```
┌─────────────────────────────────────────────┐
│         ECHOELMUSIC DESKTOP ENGINE          │
└─────────────────────────────────────────────┘

┌──────────────────┐
│   OSC Server     │ ← UDP Port 8000
│   (8000)         │
└────────┬─────────┘
         │
         │ /echoel/bio/heartrate
         │ /echoel/bio/hrv
         │ /echoel/audio/pitch
         ▼
┌──────────────────┐
│  Parameter       │
│  Mapper          │ → Heart Rate → Tempo
│                  │ → HRV → Reverb
│                  │ → Pitch → Harmony
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Audio Engine    │
│  • Synthesizers  │
│  • Samplers      │
│  • Granular      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Effects Chain   │
│  • Reverb        │
│  • Delay         │
│  • Filter        │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Spatial Audio   │
│  • Dolby Atmos   │
│  • Binaural      │
└────────┬─────────┘
         │
         ├─────────────┐
         ▼             ▼
┌──────────────┐  ┌──────────────┐
│ Audio Output │  │   Analysis   │
│ (Interface)  │  │   • RMS      │
└──────────────┘  │   • Spectrum │
                  └──────┬───────┘
                         │
                         ▼
                  ┌──────────────┐
                  │  OSC Sender  │ → UDP to iOS (8001)
                  └──────────────┘
```

## Configuration

### Audio Settings

Configure via JUCE's `AudioDeviceManager`:

```cpp
// In MainComponent constructor
audioDeviceManager.initialise(0, 2, nullptr, true);

// Set sample rate
audioDeviceManager.getAudioDeviceSetup().sampleRate = 48000;

// Set buffer size (lower = less latency, higher CPU)
audioDeviceManager.getAudioDeviceSetup().bufferSize = 256;
```

### OSC Settings

```cpp
// In initialization
oscManager.initialize(8000);  // Bind to port 8000

// Set callbacks
oscManager.onHeartRateReceived = [this](float bpm) {
    // Update tempo based on heart rate
    float tempo = mapRange(bpm, 40.0f, 200.0f, 60.0f, 180.0f);
    audioProcessor.setTempo(tempo);
};
```

## Testing

### Unit Tests (JUCE)

```bash
# Build tests
cd desktop-engine/Builds/MacOSX
xcodebuild -scheme "Echoelmusic - Tests"

# Run tests
./build/Release/EchoelmusicTests
```

### OSC Testing

**Receive OSC (Desktop as server)**:
```bash
# Terminal 1: Run Desktop Engine
./Echoelmusic

# Terminal 2: Send test messages
oscsend localhost 8000 /echoel/bio/heartrate f 75.0
```

**Monitor OSC traffic**:
```bash
# Install oscdump
brew install liblo

# Monitor incoming messages
oscdump 8000
```

## Performance

### Target Metrics

- **Latency**: < 5ms (audio processing)
- **CPU Usage**: < 50% (on modern CPUs)
- **Memory**: < 500 MB
- **Buffer Size**: 256 samples @ 48kHz = 5.3ms

### Optimization

1. **Use SIMD**:
   ```cpp
   #include <juce_dsp/juce_dsp.h>
   juce::dsp::SIMDRegister<float> simdVector;
   ```

2. **Lock-free queues**:
   ```cpp
   juce::AbstractFifo parameterQueue;
   ```

3. **Table lookups** for oscillators:
   ```cpp
   juce::dsp::LookupTableTransform<float> sineTable(
       [](float x) { return std::sin(x); },
       0.0f, juce::MathConstants<float>::twoPi, 1024
   );
   ```

4. **Profile with Instruments** (macOS):
   ```bash
   instruments -t "Time Profiler" ./Echoelmusic
   ```

## OSC Protocol

See `/docs/osc-protocol.md` for complete specification.

### Received Messages (iOS → Desktop)

- `/echoel/bio/heartrate <float: bpm>`
- `/echoel/bio/hrv <float: ms>`
- `/echoel/audio/pitch <float: hz> <float: confidence>`
- `/echoel/scene/select <int: id>`
- `/echoel/param/<name> <float: value>`

### Sent Messages (Desktop → iOS)

- `/echoel/analysis/rms <float: db>`
- `/echoel/analysis/peak <float: db>`
- `/echoel/analysis/spectrum <float[]>`
- `/echoel/status/cpu <float: percentage>`

## Development Roadmap

### Phase 1: OSC Communication ✅
- [x] Project structure
- [x] OSC server implementation
- [x] Message parsing
- [x] Test with iOS app

### Phase 2: Audio Engine 🚧
- [ ] Basic synthesis (sine, saw, square waves)
- [ ] ADSR envelopes
- [ ] Simple parameter mapping
- [ ] Audio output

### Phase 3: Effects 🔜
- [ ] Reverb (using juce_dsp)
- [ ] Delay line
- [ ] Filter (LP, HP, BP)
- [ ] Master output chain

### Phase 4: Advanced Features 🔜
- [ ] Granular synthesis
- [ ] Sample playback
- [ ] Spatial audio (Dolby Atmos)
- [ ] LED control (UDP socket)

### Phase 5: Polish 🔜
- [ ] GUI for monitoring
- [ ] Parameter automation
- [ ] Preset system
- [ ] Performance optimization

## Debugging

### Enable JUCE Logging

```cpp
// In Main.cpp
DBG("Heart rate received: " + juce::String(bpm));
```

### Console Output

**macOS**:
```bash
# Run from terminal to see console
./Echoelmusic.app/Contents/MacOS/Echoelmusic
```

**Windows**:
```bash
# Console already visible
Echoelmusic.exe
```

### Audio Debugging

```cpp
// Log audio callback info
void getNextAudioBlock(const juce::AudioSourceChannelInfo& bufferToFill) {
    DBG("Buffer size: " + juce::String(bufferToFill.numSamples));
    DBG("Sample rate: " + juce::String(getSampleRate()));
}
```

## Common Issues

### Issue: "juce_osc module not found"

**Solution**: Update JUCE to 7.0+ (juce_osc added in v7.0)

```bash
cd ~/JUCE
git pull
git checkout 7.0.9
```

### Issue: High CPU usage

**Solutions**:
- Increase buffer size (512 or 1024 samples)
- Optimize DSP code (use SIMD, table lookups)
- Profile with Instruments/Visual Studio Profiler

### Issue: Audio crackling

**Solutions**:
- Increase buffer size
- Close other audio applications
- Use dedicated audio interface

### Issue: OSC messages not received

**Solutions**:
```bash
# Check if port 8000 is in use
lsof -i :8000  # macOS/Linux
netstat -an | findstr 8000  # Windows

# Test with oscdump
oscdump 8000
```

## Resources

### JUCE Documentation
- Tutorial: https://docs.juce.com/master/tutorial_osc_sender_receiver.html
- API: https://docs.juce.com/master/group__juce__osc.html

### OSC Specification
- OSC 1.0 Spec: http://opensoundcontrol.org/spec-1_0

### Audio DSP
- JUCE DSP Module: https://docs.juce.com/master/group__juce__dsp.html
- Digital Filters: https://ccrma.stanford.edu/~jos/filters/

## Contributing

For development guidelines, see `/docs/architecture.md`.

## Next Steps

1. **Create JUCE project** in Projucer
2. **Implement OSCManager** (see template above)
3. **Test OSC communication** with iOS app
4. **Build audio synthesis engine**
5. **Add parameter mapping**

## License

Proprietary - Tropical Drones Studio, Hamburg

---

**Back to main docs**: [../README.md](../README.md)
**OSC Protocol**: [../docs/osc-protocol.md](../docs/osc-protocol.md)
**Architecture**: [../docs/architecture.md](../docs/architecture.md)
