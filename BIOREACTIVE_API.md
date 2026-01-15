# Echoelmusic Bio-Reactive API

> **IMPORTANT HEALTH DISCLAIMER**
>
> This bio-reactive system is designed for **creative and entertainment purposes only**.
>
> - **NOT A MEDICAL DEVICE** - This software is not FDA-approved or CE-marked for medical use
> - **NOT FOR DIAGNOSIS** - Do not use biometric readings for health diagnosis or treatment decisions
> - **NOT FOR MONITORING** - This is not a substitute for clinical heart rate monitors or medical equipment
> - **CONSULT PROFESSIONALS** - Always consult qualified healthcare providers for health concerns
> - **ACCURACY NOT GUARANTEED** - Biometric readings are approximations and may not be accurate
> - **"COHERENCE" IS ARTISTIC** - The "coherence score" is a creative interpretation inspired by HeartMath research, not a validated clinical measurement
>
> By using this API, you acknowledge these limitations and agree to use it responsibly.

---

## Overview

The Bio-Reactive System is the **core innovation** of Echoelmusic - real-time audio/visual modulation based on physiological signals (HRV, Coherence, Heart Rate).

**Unique Selling Point:** No other DAW or audio tool offers this.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    ECHOELMUSIC BIO-REACTIVE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐     ┌──────────────────┐     ┌─────────────┐  │
│  │  BIO INPUT  │────▶│   MODULATOR      │────▶│   OUTPUT    │  │
│  │             │     │                  │     │             │  │
│  │ • Apple Watch│     │ • HRV → Filter   │     │ • Audio DSP │  │
│  │ • Polar H10 │     │ • Coherence→Reverb│    │ • OSC/MIDI  │  │
│  │ • Bluetooth │     │ • Stress → Comp  │     │ • Visuals   │  │
│  │ • Simulated │     │ • HR → Delay     │     │ • Lighting  │  │
│  └─────────────┘     └──────────────────┘     └─────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. BioDataInput (Sources/BioData/)
```cpp
// Supported input sources
enum class SourceType {
    AppleWatch,      // HealthKit (iOS/watchOS)
    PolarH10,        // Bluetooth HR sensor
    BluetoothHR,     // Generic BLE heart rate
    Simulated        // For testing/demo
};
```

### 2. HRVProcessor (Sources/BioData/HRVProcessor.h)
```cpp
// HeartMath-inspired coherence algorithm
class HRVProcessor {
    float calculateCoherence();  // 0-1 coherence score
    float calculateRMSSD();      // HRV variability
    float getStressIndex();      // Derived stress level
};
```

### 3. BioReactiveModulator (Sources/BioData/BioReactiveModulator.h)
```cpp
// Maps bio-data to audio parameters
struct ModulatedParameters {
    float filterCutoff;      // 20-20000 Hz (HRV)
    float reverbMix;         // 0-1 (Coherence)
    float compressionRatio;  // 1-20 (Stress)
    float delayTime;         // 0-2000ms (Heart Rate sync)
    float distortionAmount;  // 0-1 (Stress)
    float lfoRate;           // 0.1-20 Hz (Breathing)
};
```

### 4. BioReactiveAudioProcessor (Sources/DSP/BioReactiveAudioProcessor.h)
```cpp
// Real-time DSP with bio-modulation
class BioReactiveAudioProcessor {
    void prepare(double sampleRate, int blockSize, int channels);
    void process(AudioBuffer& buffer, ModulatedParameters& params);
};
```

---

## Integration Points

### For Plugin Developers (VST3/AU)
```cpp
// In your PluginProcessor::processBlock()
bioFeedback.update();
auto params = bioFeedback.getModulatedParameters();
bioProcessor.process(buffer, params);
```

### For Visual Artists (OSC Output)
```
/echoelmusic/bio/hrv          [float 0-1]
/echoelmusic/bio/coherence    [float 0-1]
/echoelmusic/bio/heartrate    [float 40-200]
/echoelmusic/bio/stress       [float 0-1]
/echoelmusic/mod/filter       [float 20-20000]
/echoelmusic/mod/reverb       [float 0-1]
```

### For Mobile (Swift/iOS)
```swift
// HealthKitManager provides:
healthKitManager.heartRate      // Double (BPM)
healthKitManager.hrvRMSSD       // Double (ms)
healthKitManager.hrvCoherence   // Double (0-100)
```

---

## Modulation Mappings

| Bio Signal | Audio Parameter | Relationship |
|------------|-----------------|--------------|
| HRV (high) | Filter Cutoff | Higher HRV = brighter sound |
| Coherence (high) | Reverb Mix | Higher coherence = more spacious |
| Stress (high) | Compression | Higher stress = more controlled |
| Heart Rate | Delay Time | Synced to heartbeat rhythm |
| Breathing | LFO Rate | Synced to breath cycle |

---

## Use Cases

### 1. Live Performance (DJ/Producer)
- Performer's heart rate controls the energy
- Coherence affects the "vibe" (reverb/space)
- Audience sees the connection (visuals sync)

### 2. Meditation/Wellness App
- Coherence guides the user to calm state
- Audio becomes more harmonious as user relaxes
- Gamification through sound quality

### 3. Wellness & Meditation Music
- Multidimensional Brainwave Entrainment synced to HRV (scientifically validated: Goessl 2017)
- Brainwave entrainment (Delta/Theta/Alpha/Beta/Gamma)
- Personalized relaxation soundscapes

> **Wellness Feature Disclaimer**
>
> These features are for **general wellness and relaxation only**:
>
> - **Not medical treatment** - Brainwave entrainment and HRV-synced audio are not proven medical therapies
> - **Subjective effects** - Individual experiences vary; relaxation is not guaranteed
> - **No health claims** - We make no claims about treating anxiety, depression, insomnia, or any condition
> - **Seizure risk** - If you have epilepsy or a history of seizures, consult a doctor before using audio/visual entrainment
> - **Stop if unwell** - Discontinue use if you experience dizziness, nausea, or discomfort
> - **Not a substitute** - This is not a replacement for professional mental health treatment
>
> Scientific references are provided for transparency, not as endorsement of medical efficacy.

### 4. Creative Tool
- "Happy accidents" from bio-modulation
- Unique, unrepeatable recordings
- Human element in electronic music

---

## External Integration

### Ableton Live (via Max for Live)
```
[receive echoelmusic_hrv] → [scale 0 1 0.5 4] → [live.dial @varname filter]
```

### TouchDesigner / Resolume (via OSC)
```python
# Receive OSC from Echoelmusic
coherence = args[0]  # /echoelmusic/bio/coherence
visual_intensity = coherence * glow_amount
```

### Lighting (DMX via OSC)
```
/echoelmusic/bio/coherence → DMX Channel 1 (intensity)
/echoelmusic/bio/heartrate → DMX Channel 2 (strobe rate)
```

---

## Files

```
Sources/
├── BioData/
│   ├── BioReactiveModulator.h    # Parameter mapping
│   └── HRVProcessor.h            # Coherence algorithm
├── DSP/
│   ├── BioReactiveDSP.h/.cpp     # Core DSP engine
│   └── BioReactiveAudioProcessor.h # JUCE integration
├── Visualization/
│   ├── BioReactiveVisualizer.h/.cpp # Visual feedback
└── Echoelmusic/ (Swift)
    ├── Biofeedback/
    │   └── HealthKitManager.swift # Apple Watch integration
    └── Platforms/watchOS/
        └── WatchApp.swift         # watchOS app
```

---

## Health & Safety Guidelines

### Before Using Bio-Reactive Features

1. **General Health** - Ensure you are in good health before using biometric features
2. **Medical Conditions** - Consult a doctor if you have:
   - Heart conditions or arrhythmias
   - Epilepsy or seizure disorders
   - Anxiety disorders or panic attacks
   - Any condition affected by stress or stimulation
3. **Pacemakers/Implants** - Consult your cardiologist before using heart rate monitoring
4. **Pregnancy** - Consult your healthcare provider before using biofeedback features

### During Use

- **Stay Hydrated** - Drink water during extended sessions
- **Take Breaks** - Rest every 30-60 minutes
- **Stop if Unwell** - Discontinue immediately if you feel dizzy, nauseous, or unwell
- **Safe Environment** - Use in a safe, seated position if using immersive features

### Emergency Contact

If you experience a medical emergency, **call emergency services immediately**:
- **USA**: 911
- **EU**: 112
- **UK**: 999
- **Australia**: 000

---

## License & IP

**Copyright (c) 2024-2026 Echoelmusic**

The Bio-Reactive System is proprietary technology.
Contact for licensing: [TBD]

---

## For Potential Partners

This technology is ready for:
- [ ] Plugin integration (VST3/AU/AAX)
- [ ] Mobile app (iOS/watchOS)
- [ ] Hardware integration (wearables)
- [ ] Visual software (TouchDesigner, Resolume)
- [ ] DAW integration (Ableton, Logic)

**Interested? Let's talk.**
