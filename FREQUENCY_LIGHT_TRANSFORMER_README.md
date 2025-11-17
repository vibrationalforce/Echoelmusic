# 🌈 FREQUENCY-TO-LIGHT TRANSFORMER - QUICK START

**Scientific Audio-to-Light Transformation via Octave Shifting**

---

## ⚡ WHAT IS THIS?

Transform **audio frequencies** (20 Hz - 20 kHz) into **visible light** (380-780 nm) using **mathematically correct octave shifting**!

```
A4 (440 Hz) × 2^40 = 484 THz ≈ 620 nm (Orange-Red) 🌈
```

**100% Physics. 0% Mysticism.** 🔬

---

## 🎯 KEY FEATURES

✅ **Octave Transformation**: `f_light = f_audio × 2^n`
✅ **CIE 1931 Color Science**: Industry-standard color matching
✅ **Real-time FFT Analysis**: Automatic frequency detection
✅ **Multi-format Export**: OSC, DMX, JSON, CSV
✅ **Scientific Validation**: Unit-tested accuracy

---

## 🚀 QUICK START

### 1. Include the Headers

```cpp
#include "Sources/Visualization/ScientificFrequencyLightTransformer.h"
#include "Sources/Visualization/FrequencyLightTransformerUI.h"
#include "Sources/Visualization/FrequencyLightExporter.h"
```

### 2. Transform a Frequency

```cpp
// Transform A4 (440 Hz) to light
auto result = ScientificFrequencyLightTransformer::transformToLight(440.0);

std::cout << "Light: " << result.lightFrequency_THz << " THz\n";
std::cout << "Wavelength: " << result.wavelength_nm << " nm\n";
std::cout << "Color: " << result.color.perceptualName << "\n";
```

### 3. Use the UI Component

```cpp
FrequencyLightTransformerUI transformerUI;

// Process audio
transformerUI.processAudioBuffer(audioBuffer);

// Get results
auto transform = transformerUI.getCurrentTransform();
```

### 4. Export Data

```cpp
// OSC
FrequencyLightExporter::sendOSC(transform, "127.0.0.1", 7000);

// DMX/Art-Net
auto dmx = FrequencyLightExporter::createDMXPacket(transform);
FrequencyLightExporter::sendArtNet(dmx, "192.168.1.100", 6454);

// JSON
FrequencyLightExporter::saveJSON(transform, outputFile);
```

---

## 📊 EXAMPLE RESULTS

| Audio | Note | Light | Wavelength | Color |
|-------|------|-------|------------|-------|
| 440 Hz | A4 | 484 THz | 620 nm | Orange-Red |
| 1000 Hz | B5 | 539 THz | 556 nm | Green |
| 5000 Hz | D#8 | 686 THz | 437 nm | Blue |

---

## 🎨 USE CASES

### VJ Performances
- Resolume Arena (OSC)
- TouchDesigner (CHOP)
- MadMapper (video mapping)

### Stage Lighting
- DMX512 fixtures
- Art-Net networks
- LED installations

### Scientific Visualization
- Frequency analysis
- Color perception research
- Audio-reactive art

---

## 🧪 RUN TESTS

```cpp
FrequencyLightTransformerTests tests;
tests.runTest();
```

**All tests validate scientific accuracy!** ✅

---

## 📚 DOCUMENTATION

Full documentation: **[Docs/FREQUENCY_LIGHT_TRANSFORMER.md](Docs/FREQUENCY_LIGHT_TRANSFORMER.md)**

Includes:
- Complete scientific foundation
- Implementation guide
- Export format specifications
- Integration examples
- Scientific references

---

## 📁 FILE STRUCTURE

```
Sources/Visualization/
├── ScientificFrequencyLightTransformer.h    # Core algorithm
├── FrequencyLightTransformerUI.h            # UI component
└── FrequencyLightExporter.h                 # Export tools

Sources/CreativeTools/
└── FrequencyLightTransformerTool.h          # Complete tool

Tests/
└── FrequencyLightTransformerTests.cpp       # Unit tests

Docs/
└── FREQUENCY_LIGHT_TRANSFORMER.md           # Full documentation
```

---

## 🔬 SCIENTIFIC FOUNDATION

### Octave Transformation
```
f_light = f_audio × 2^n
```
Preserves musical intervals in light domain!

### Color Science
- **CIE 1931** color matching functions
- **sRGB** color space (IEC 61966-2-1:1999)
- **D65** illuminant standard

### Neuroscience
- Cone responses (S, M, L)
- Visual cortex mapping
- Photopic luminosity V(λ)

**Peer-reviewed references included!** 📚

---

## ⚠️ IMPORTANT

**NOT a medical device. NOT therapeutic. For entertainment/research only!**

✅ Scientific visualization
✅ Live performance
✅ Art installations
❌ Medical claims
❌ Therapeutic promises

---

## 🌟 HIGHLIGHTS

### Unique to Echoelmusic
- **Pure octave method** (not logarithmic)
- **Full CIE 1931 implementation**
- **Multi-format export**
- **Scientific validation**

### Production-Ready
- Real-time performance
- Low latency
- Industry-standard protocols
- Comprehensive testing

---

## 🚀 GET STARTED NOW!

1. **Include headers** from `Sources/Visualization/`
2. **Transform frequency**: `transformToLight(440.0)`
3. **Export data**: OSC/DMX/JSON
4. **Visualize light**: Use UI component

**It's that simple!** 🎉

---

## 📧 NEED HELP?

- **Full Docs**: `Docs/FREQUENCY_LIGHT_TRANSFORMER.md`
- **Tests**: `Tests/FrequencyLightTransformerTests.cpp`
- **Examples**: See documentation for integration examples

---

**Transform Sound into Light - Scientifically!** 🌈🔬

*Built with JUCE | Validated by Science | Powered by Echoelmusic*
