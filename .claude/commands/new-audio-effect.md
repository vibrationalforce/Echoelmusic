Create a new JUCE C++ audio effect processor with full implementation including processor, editor, parameters, and tests.

**Required Input**: Effect name (e.g., "BiometricReverb", "HRVCompressor")

**Files to Create**:
1. `Sources/DSP/{EffectName}.cpp` - Main processor implementation
2. `Sources/DSP/{EffectName}.h` - Header with parameters
3. Test file with unit tests for the effect

**Template Structure**:

```cpp
// {EffectName}.h
#pragma once
#include <JuceHeader.h>

class {EffectName} : public juce::AudioProcessor {
public:
    {EffectName}();
    ~{EffectName}() override;

    void prepareToPlay(double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;
    void processBlock(juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    // Parameters
    juce::AudioProcessorValueTreeState parameters;

private:
    // DSP state
    double sampleRate = 44100.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR({EffectName})
};
```

**Implementation Guidelines**:
- Use JUCE DSP module for processing
- Implement parameter smoothing for artifact-free changes
- Add SIMD optimization where applicable
- Target <3ms latency
- Include bypass functionality
- Add dry/wet mix parameter

**Testing Requirements**:
- Unit tests for parameter ranges
- Audio processing tests (silence, DC offset, phase)
- Performance benchmarks
- Latency measurement

**Parameter Conventions**:
- All parameters 0.0-1.0 range for UI
- Use AudioProcessorValueTreeState
- Add parameter listeners for real-time updates
- Include automation support

**Integration**:
- Add to CMakeLists.txt
- Update DSP factory/registry
- Add to iOS Swift bridge if needed
- Document in COMPLETE_FEATURE_LIST.md
