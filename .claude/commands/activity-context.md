Add a new activity context with scientific frequency mappings and biometric parameter presets.

**Required Input**: Activity name (e.g., "DeepMeditation", "HIIT", "CreativeFlow", "PowerNap", "Driving")

**Activity Context Categories**:
- Meditation & Mindfulness (10 types)
- Fitness & Exercise (15 types)
- Work & Focus (12 types)
- Recovery & Healing (18 types)
- Creative & Artistic (8 types)
- Sleep & Rest (6 types)
- Social & Performance (10 types)
- Specialized (7 types)

**Files to Create/Update**:

1. **C++ Context Mapping**:
   - `Sources/Mappings/Contexts/{ActivityName}Context.cpp`
   - `Sources/Mappings/Contexts/{ActivityName}Context.h`

2. **Swift Integration**:
   - Update `Sources/Echoelmusic/Biofeedback/BioParameterMapper.swift`

3. **Tests**:
   - `Tests/Contexts/{ActivityName}ContextTests.cpp`

**Template Structure**:

```cpp
// {ActivityName}Context.h
#pragma once
#include "ActivityContext.h"

class {ActivityName}Context : public ActivityContext {
public:
    {ActivityName}Context();

    // Biometric thresholds
    struct Thresholds {
        float hrvCoherenceMin = 60.0f;    // 0-100
        float hrvCoherenceMax = 100.0f;
        float heartRateMin = 50.0f;       // BPM
        float heartRateMax = 70.0f;
        float respirationRate = 6.0f;     // breaths/min
    };

    // Audio mappings
    struct AudioMapping {
        float baseFrequency = 432.0f;     // Hz (healing freq)
        float binauralBeat = 10.0f;       // Hz (alpha waves)
        float reverbWet = 0.5f;           // 0.0-1.0
        float spatialWidth = 0.8f;        // 0.0-1.0
    };

    // Visual mappings
    struct VisualMapping {
        Color lowCoherenceColor;          // RGB (red)
        Color highCoherenceColor;         // RGB (green)
        int particleCount = 100;
        float particleSpeed = 1.0f;
    };

    // Light mappings (DMX/Art-Net)
    struct LightMapping {
        int brightness = 80;              // 0-100%
        float colorTemp = 4000.0f;        // Kelvin
        float pulseFequency = 0.1f;       // Hz
    };

    Thresholds getThresholds() const override;
    AudioMapping getAudioMapping(float hrvCoherence) const override;
    VisualMapping getVisualMapping() const override;
    LightMapping getLightMapping() const override;

    // Scientific validation
    std::string getScientificBasis() const override;
    std::vector<std::string> getCitations() const override;
};
```

**Scientific Mapping Guidelines**:

**Brainwave States**:
- Delta (0.5-4 Hz): Deep sleep, healing
- Theta (4-8 Hz): Meditation, creativity
- Alpha (8-13 Hz): Relaxation, flow state
- Beta (13-30 Hz): Focus, alertness
- Gamma (30-100 Hz): Peak performance

**HRV Coherence Zones** (HeartMath):
- 0-40: Low (stress, anxiety) → Red visuals, delta waves
- 40-60: Medium (transition) → Yellow/orange
- 60-100: High (optimal, flow) → Green visuals, alpha/theta

**Frequency Mappings**:
- 432 Hz: "Healing frequency" (controversial but popular)
- 528 Hz: "Love frequency" (Solfeggio)
- 396-963 Hz: Solfeggio scale
- 110 Hz: Endorphin release research
- 40 Hz: Gamma wave (focus)

**Activity-Specific Examples**:

```cpp
// DeepMeditation
Thresholds {
    .hrvCoherenceMin = 70.0f,
    .hrvCoherenceMax = 100.0f,
    .heartRateMin = 50.0f,
    .heartRateMax = 60.0f,
    .respirationRate = 4.0f  // Very slow breathing
}
AudioMapping {
    .baseFrequency = 432.0f,
    .binauralBeat = 4.0f,  // Theta waves
    .reverbWet = 0.8f,     // High reverb for spaciousness
    .spatialWidth = 1.0f
}

// HIIT (High-Intensity Interval Training)
Thresholds {
    .hrvCoherenceMin = 20.0f,
    .hrvCoherenceMax = 50.0f,
    .heartRateMin = 140.0f,
    .heartRateMax = 180.0f,
    .respirationRate = 30.0f  // Rapid breathing
}
AudioMapping {
    .baseFrequency = 440.0f,
    .binauralBeat = 25.0f,  // Beta waves for energy
    .reverbWet = 0.1f,      // Dry for clarity
    .spatialWidth = 0.5f
}

// CreativeFlow
Thresholds {
    .hrvCoherenceMin = 60.0f,
    .hrvCoherenceMax = 80.0f,
    .heartRateMin = 60.0f,
    .heartRateMax = 80.0f,
    .respirationRate = 8.0f
}
AudioMapping {
    .baseFrequency = 432.0f,
    .binauralBeat = 10.0f,  // Alpha waves for creativity
    .reverbWet = 0.6f,
    .spatialWidth = 0.9f
}
```

**Implementation Checklist**:
- [ ] Define biometric thresholds (research-backed)
- [ ] Map to audio parameters (frequency, binaural beats)
- [ ] Map to visual parameters (colors, particle behavior)
- [ ] Map to light parameters (brightness, color temp)
- [ ] Add scientific citations
- [ ] Create smooth transitions between contexts
- [ ] Test with real biometric data
- [ ] Validate against published research

**Scientific Validation**:
```cpp
std::string getScientificBasis() const override {
    return "Alpha waves (8-12 Hz) associated with relaxed alertness "
           "and creative flow states. Studies show binaural beats at "
           "10 Hz can entrain brainwaves to alpha frequency.";
}

std::vector<std::string> getCitations() const override {
    return {
        "Jirakittayakorn, N. & Wongsawat, Y. (2017). Brain responses "
        "to 40-Hz binaural beat. Int J Psychophysiol, 120, 96-107.",

        "McCraty, R. (2015). Heart-brain neurodynamics: The making of "
        "emotions. HeartMath Research Center, Institute of HeartMath.",

        "Wahbeh, H. et al. (2007). Binaural beat technology in humans. "
        "J Altern Complement Med, 13(1), 25-32."
    };
}
```

**Swift Integration**:
```swift
// Update BioParameterMapper.swift
enum ActivityContext: String, CaseIterable {
    // ... existing contexts
    case {activityName} = "{Activity Name}"

    var bioThresholds: BioThresholds {
        switch self {
        case .{activityName}:
            return BioThresholds(
                hrvCoherenceMin: 60.0,
                hrvCoherenceMax: 100.0,
                heartRateMin: 50.0,
                heartRateMax: 70.0
            )
        // ... other cases
        }
    }
}
```

**Testing Requirements**:
- Unit tests for parameter ranges
- Validation against scientific literature
- User experience testing with real sensors
- Transition smoothness tests
- Edge case handling (sensor disconnection)

**Documentation**:
- Add to COMPLETE_FEATURE_LIST.md
- Document scientific basis in ARCHITECTURE_SCIENTIFIC.md
- Add user guide entry
- Include in activity context picker UI

**UI Integration**:
- Add to activity selection menu
- Display real-time parameter mappings
- Show coherence zone indicators
- Provide context-switch animations
