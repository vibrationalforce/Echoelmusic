# 🌈 MASTER UNIVERSAL QUANTUM FREQUENCY TRANSFORMER 🔬

**Echoelmusic Advanced Integration System v2.0**

---

## 📖 OVERVIEW

The **Master Universal Quantum Frequency Transformer** extends the Scientific Frequency-to-Light Transformer with:

✅ **Multi-Source Integration** (Audio, BPM, HRV, EEG, MIDI)
✅ **Precision Tuning** (3-decimal custom A4: 392.000 - 493.883 Hz)
✅ **Precision BPM** (3-decimal: 0.001 - 999.999)
✅ **Microtonal Piano Mapping** (with cent deviations)
✅ **Extended Color Spaces** (RGB, HSV, LAB)
✅ **Quantum Properties** (Photon energy, Planck units)
✅ **Complete Plugin Integration** (All Echoelmusic systems)

---

## 🎯 KEY FEATURES

### 1. Precision Custom Tuning (3 Decimals)

Support for **historical and modern tuning standards** with 0.001 Hz precision:

| Tuning Standard | A4 Frequency | Era/Source |
|----------------|--------------|------------|
| Modern Standard | 440.000 Hz | ISO 16:1975 |
| Verdi Tuning | 432.000 Hz | Giuseppe Verdi preferred |
| Scientific Pitch | 430.539 Hz | C4 = 256 Hz exactly |
| Baroque French | 392.000 Hz | French Baroque period |
| Baroque German | 415.305 Hz | German Baroque |
| Berlin Philharmonic | 443.000 Hz | Current standard |
| Vienna Philharmonic | 444.000 Hz | Current standard |
| New York Philharmonic | 442.000 Hz | Current standard |

**Custom tuning range**: 392.000 - 493.883 Hz

### 2. Precision BPM (3 Decimals)

BPM input with 0.001 precision:
- **Range**: 0.001 - 999.999 BPM
- **Conversion**: BPM / 60.0 = Frequency (Hz)
- **Use cases**: Precise tempo mapping, video sync, lighting automation

### 3. Multi-Source Frequency Integration

Combines frequency data from multiple sources:

| Source | Typical Range | Integration Priority |
|--------|--------------|---------------------|
| **Audio (FFT)** | 20 - 20,000 Hz | Primary |
| **EEG Alpha** | 8 - 13 Hz | Secondary (most stable) |
| **BPM** | 0.001 - 999.999 | Tertiary |
| **HRV** | 0.04 - 0.4 Hz | Quaternary |
| **EEG Delta** | 0.5 - 4 Hz | Available |
| **EEG Theta** | 4 - 8 Hz | Available |
| **EEG Beta** | 13 - 30 Hz | Available |
| **EEG Gamma** | 30 - 100 Hz | Available |

**Selection Logic:**
1. Use audio if present and significant (20-20,000 Hz)
2. Else use Alpha EEG (most stable brain rhythm)
3. Else use BPM frequency
4. Fallback to HRV

### 4. Precise Piano Mapping (Microtonality)

Maps frequencies to 88-key piano with **microtonal accuracy**:

- **Exact Piano Key**: 1.000 - 88.000 (with decimals)
- **Cent Deviation**: -50 to +50 cents from nearest semitone
- **Note Name**: e.g., "A4+13.686 cents" or "C4-7.234 cents"

**Example:**
```
440.000 Hz (A4, 440 Hz tuning) → Key 49.000, "A4"
440.123 Hz (A4, 440 Hz tuning) → Key 49.005, "A4+8.134 cents"
432.000 Hz (A4, 432 Hz tuning) → Key 49.000, "A4"
```

### 5. Extended Color Spaces

Three color space representations:

**RGB** (sRGB, D65 illuminant)
- Range: [0.0 - 1.0] for each channel
- Gamma corrected (IEC 61966-2-1:1999)

**HSV** (Hue, Saturation, Value)
- H: 0 - 360° (color wheel)
- S: 0.0 - 1.0 (color intensity)
- V: 0.0 - 1.0 (brightness)

**LAB** (CIE L\*a\*b\*)
- L: 0 - 100 (lightness)
- a\*: -128 to 127 (green-red axis)
- b\*: -128 to 127 (blue-yellow axis)

### 6. Quantum Properties

**Photon Energy** (eV):
```
E = h × f
```
- h = Planck constant = 6.62607015×10^-34 J⋅s
- f = visual frequency (Hz)
- Converted to electronvolts (eV)

**Quantum Coherence** (0-1):
- Heuristic based on tuning accuracy
- Higher coherence for exact semitones
- Formula: `1 - (abs(cents) / 50)`

**Planck Units**:
- Normalized to Planck frequency (1.855×10^43 Hz)
- Shows scale relative to fundamental limit

---

## 💻 USAGE

### Basic Transformation

```cpp
#include "MasterFrequencyTransformer.h"

// Transform with all sources
auto result = MasterFrequencyTransformer::transformAllSources(
    440.0,          // Audio frequency (Hz)
    120.123,        // BPM (3 decimals)
    0.1,            // HRV frequency (Hz)
    {2.0, 6.0, 10.0, 20.0, 40.0},  // EEG [Delta, Theta, Alpha, Beta, Gamma]
    432.000         // Custom A4 tuning (Hz)
);

// Access all data
std::cout << "Dominant Frequency: " << result.dominantFrequency_Hz << " Hz\n";
std::cout << "Visual Frequency: " << result.visualFrequency_THz << " THz\n";
std::cout << "Wavelength: " << result.wavelength_nm << " nm\n";
std::cout << "Piano Key: " << result.exactPianoKey << "\n";
std::cout << "Note: " << result.noteName << "\n";
std::cout << "RGB: (" << result.r << ", " << result.g << ", " << result.b << ")\n";
std::cout << "HSV: (" << result.h << "°, " << result.s << ", " << result.v << ")\n";
std::cout << "Photon Energy: " << result.photonEnergy_eV << " eV\n";
```

### Plugin Integration

```cpp
#include "PluginIntegrationHub.h"

PluginIntegrationHub hub;

// Distribute to ALL Echoelmusic plugins
hub.distributeToAllPlugins(result);

// Check plugin status
auto statusList = hub.getPluginStatusList();
for (const auto& status : statusList)
{
    std::cout << status.name << ": "
              << (status.connected ? "Connected" : "Disconnected")
              << " (Flow: " << status.dataFlowRate << ")\n";
}
```

### UI Component

```cpp
#include "MasterFrequencyTransformerUI.h"

MasterFrequencyTransformerUI transformerUI;

// Add to your component
addAndMakeVisible(transformerUI);

// Process audio
transformerUI.processAudioBuffer(audioBuffer);

// UI handles everything automatically!
```

---

## 🔌 PLUGIN INTEGRATION TARGETS

The Plugin Integration Hub distributes data to:

### Synthesis Engines
- ✅ Spectral Granular Synth
- ✅ Neural Synth
- ✅ Wave Weaver
- ✅ Frequency Fusion (FM)
- ✅ Intelligent Sampler

### Effects Processors
- ✅ Adaptive Reverb
- ✅ Quantum Delay
- ✅ Biometric Filter
- ✅ Spectral Masking

### Analyzers
- ✅ Spectrum Analyzer
- ✅ Phase Analyzer
- ✅ Harmonic Analyzer

### Visual Systems
- ✅ Particle Engine (100k+ particles)
- ✅ Video Sync (DaVinci, Premiere, FCP)
- ✅ Light Controller (DMX, Philips Hue, WLED)
- ✅ Visual Forge

### External Protocols
- ✅ OSC (Open Sound Control)
- ✅ DMX/Art-Net (Stage lighting)
- ✅ MIDI CC (DAW control)

---

## 📊 EXAMPLE USE CASES

### 1. Live Performance with Custom Tuning

Performer uses **432 Hz tuning** (Verdi standard):

```cpp
auto result = MasterFrequencyTransformer::transformAllSources(
    audioFrequency,  // Live audio input
    128.456,         // Precise BPM from Ableton Link
    0.1,             // HRV from biometric sensor
    eegData,         // EEG headband
    432.000          // Verdi tuning
);

// All plugins receive correctly tuned data
pluginHub.distributeToAllPlugins(result);

// Stage lighting syncs to BPM and wavelength
// Video effects sync to color/rhythm
// Particle system responds to EEG states
```

### 2. Microtonal Composition

Composer works with **24-tone equal temperament** (quarter-tones):

```cpp
// Generate quarter-tone scale from A4 (440 Hz)
for (int quarterTones = 0; quarterTones < 48; ++quarterTones)
{
    double freq = 440.0 * std::pow(2.0, quarterTones / 24.0);

    auto result = MasterFrequencyTransformer::transformAllSources(
        freq, 120.0, 0.1, eegData, 440.000
    );

    std::cout << "Quarter-tone " << quarterTones << ": "
              << result.exactPianoKey << " → "
              << result.noteName << " → "
              << result.wavelength_nm << " nm\n";
}
```

### 3. Biofeedback-Driven Visuals

Meditation app uses **HRV and EEG** to drive calming visuals:

```cpp
// Slow breathing (0.1 Hz) + Alpha EEG (10 Hz) = calming colors
auto result = MasterFrequencyTransformer::transformAllSources(
    0.0,              // No audio
    60.000,           // Calm BPM
    breathingRate,    // HRV from breathing (0.1 Hz)
    {1.0, 5.0, 10.0, 8.0, 15.0},  // High Alpha EEG
    440.000
);

// Green-blue calming colors appear
// Particle system flows gently
// Lighting dims and warms
```

### 4. Scientific Frequency Analysis

Researcher analyzes **synesthesia** correlations:

```cpp
// Test all audio frequencies 20-20,000 Hz
for (double freq = 20.0; freq <= 20000.0; freq *= 1.01)
{
    auto result = MasterFrequencyTransformer::transformAllSources(
        freq, 120.0, 0.1, {2,6,10,20,40}, 440.0
    );

    csvExport << freq << ","
              << result.wavelength_nm << ","
              << result.r << "," << result.g << "," << result.b << ","
              << result.exactPianoKey << ","
              << result.photonEnergy_eV << "\n";
}
```

---

## 🧪 SCIENTIFIC VALIDATION

### Unit Tests

All features are validated by comprehensive unit tests:

```cpp
MasterFrequencyTransformerTests tests;
tests.runTest();
```

**Test Coverage:**
- ✅ Custom A4 precision (3 decimals)
- ✅ BPM precision (3 decimals)
- ✅ Multi-source integration
- ✅ Precise piano mapping
- ✅ Microtonal accuracy (sub-cent)
- ✅ Extended color spaces (RGB/HSV/LAB)
- ✅ Quantum properties
- ✅ Historical tuning standards

---

## 📚 SCIENTIFIC REFERENCES

### Musical Tuning & Temperament
1. **Ellis, A. J. (1880).** "On the History of Musical Pitch." *Journal of the Society of Arts*.
2. **Barbour, J. M. (1951).** *Tuning and Temperament: A Historical Survey.* Michigan State College Press.
3. **ISO 16:1975.** Acoustics — Standard tuning frequency (Standard musical pitch)

### Color Science
4. **CIE 1931 Color Space.** ISO 11664-1:2019(E)/CIE S 014-1/E:2006
5. **sRGB Color Space.** IEC 61966-2-1:1999
6. **CIE L\*a\*b\* Color Space.** CIE 1976

### Quantum Physics
7. **CODATA 2018.** Planck constant h = 6.62607015×10^-34 J⋅s (exact)
8. **Planck, M. (1900).** "Zur Theorie des Gesetzes der Energieverteilung im Normalspektrum."

### Biometrics
9. **Task Force (1996).** "Heart rate variability: standards of measurement." *Circulation*, 93(5), 1043-1065.
10. **Niedermeyer, E. & da Silva, F. L. (2005).** *Electroencephalography: Basic Principles.* Lippincott Williams & Wilkins.

---

## ⚠️ IMPORTANT DISCLAIMERS

### NOT Medical or Therapeutic

❌ **NOT a medical device**
❌ **NO therapeutic claims**
❌ **FOR ENTERTAINMENT/RESEARCH ONLY**

### Scientific/Artistic Use Only

✅ Musical performance
✅ Scientific visualization
✅ Art installations
✅ Research and education

---

## 🚀 FUTURE ENHANCEMENTS

### Planned Features
- [ ] **MIDI polyphonic input** (multi-note transformation)
- [ ] **Video frame-by-frame color grading export**
- [ ] **Real-time DAW tempo tracking** (Ableton Link++)
- [ ] **Advanced EEG analysis** (alpha/beta ratios, coherence)
- [ ] **Machine learning** tuning preference detection
- [ ] **VR/AR integration** (color spaces in 3D)
- [ ] **Blockchain** frequency timestamp verification 🤔

### Research Directions
- [ ] **Synesthesia mapping** validation studies
- [ ] **Historical tuning** reconstruction
- [ ] **Biofeedback** optimization algorithms
- [ ] **Cross-cultural** color-sound associations

---

## 📄 LICENSE

Copyright (c) 2025 Echoelmusic Team
Licensed under the same terms as Echoelmusic main project.

---

## 📧 CONTACT

- **Documentation**: `Docs/MASTER_FREQUENCY_TRANSFORMER.md`
- **Original System**: `Docs/FREQUENCY_LIGHT_TRANSFORMER.md`
- **Tests**: `Tests/MasterFrequencyTransformerTests.cpp`
- **Plugin Hub**: `Sources/Integration/PluginIntegrationHub.h`

---

**Built with 🌈🔬🎹 by the Echoelmusic Science Team**

*From Audio to Light - With Ultimate Precision!*
