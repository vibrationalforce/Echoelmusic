# Echoelmusic Desktop Plugins

## 🎹 JUCE-FREE Desktop Audio Plugins

This directory contains the **iPlug2-based** desktop plugin implementation.
100% JUCE-free, MIT licensed, no fees!

## Supported Formats

| Format | License | Platform | Status |
|--------|---------|----------|--------|
| **CLAP** | MIT | All | ✅ Recommended |
| **VST3** | GPLv3 | All | ✅ Ready |
| **AU** | Apple | macOS | ✅ Ready |
| **AAX** | Avid | All | ⚠️ Needs SDK |
| **Standalone** | MIT | All | ✅ Ready |

## Quick Start

### 1. Clone iPlug2

```bash
cd ThirdParty
git clone https://github.com/iPlug2/iPlug2
cd iPlug2
git submodule update --init --recursive
```

### 2. Build Desktop Plugins

```bash
mkdir build && cd build

# macOS/Linux
cmake -DUSE_IPLUG2=ON ..
make -j8

# Windows
cmake -DUSE_IPLUG2=ON -G "Visual Studio 17 2022" ..
cmake --build . --config Release
```

### 3. Install Plugins

Built plugins are in:
- `build/Echoelmusic_VST3.vst3`
- `build/Echoelmusic_CLAP.clap`
- `build/Echoelmusic_AU.component` (macOS)
- `build/Echoelmusic_Standalone`

Copy to your DAW's plugin folder.

## Architecture

```
Sources/Desktop/
├── IPlug2/
│   ├── EchoelmusicPlugin.h      # Plugin interface
│   ├── EchoelmusicPlugin.cpp    # Plugin implementation
│   └── config.h                 # Plugin metadata
├── DSP/
│   └── EchoelmusicDSP.h         # JUCE-free DSP engine
├── CMakeLists.txt               # Build configuration
└── README.md                    # This file
```

## DSP Engine (JUCE-Free)

The DSP engine is 100% JUCE-free and includes:

- **Oscillators**: Sine, Triangle, Saw, Square, Pulse, Noise
- **Anti-Aliasing**: PolyBLEP for alias-free waveforms
- **Filters**: State Variable (12dB), Moog Ladder (24dB)
- **Envelopes**: ADSR with adjustable curves
- **LFO**: Multiple waveforms, sync options
- **Reverb**: Schroeder algorithm
- **Denormal Protection**: CPU-safe processing

## Bio-Reactive Features

The desktop plugin supports bio-reactive parameters:

```cpp
// From external source (OSC, MIDI CC, etc.)
plugin->UpdateBioData(hrv, coherence, heartRate);
```

### Parameter Mapping

| Bio Signal | Audio Effect |
|------------|--------------|
| HRV | Filter Cutoff (±30%) |
| Coherence | Reverb Mix (0-50%) |
| Heart Rate | LFO Rate (±20%) |

## License

- **iPlug2**: MIT License
- **CLAP SDK**: MIT License
- **VST3 SDK**: GPLv3 (free for open source)
- **Our Code**: MIT License

**Total Cost: $0** 💰

## Comparison: iPlug2 vs JUCE

| Feature | iPlug2 | JUCE |
|---------|--------|------|
| License | MIT | GPL/Commercial |
| Cost | FREE | $0-$2000/year |
| VST3 | ✅ | ✅ |
| AU | ✅ | ✅ |
| CLAP | ✅ | ❌ |
| AAX | ✅ | ✅ |
| Learning Curve | Medium | Medium |
| Community | Growing | Large |

## Support

- iPlug2 Docs: https://iplug2.github.io/
- CLAP: https://cleveraudio.org/
- Issues: Create a GitHub issue
