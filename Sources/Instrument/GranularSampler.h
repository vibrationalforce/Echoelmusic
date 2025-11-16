#pragma once

#include <JuceHeader.h>
#include "../DSP/SpectralFramework.h"
#include <vector>

/**
 * GranularSampler
 *
 * Real-time granular processing sampler with live input granulation
 * and cloud-based grain distribution.
 *
 * Features:
 * - Real-time granular synthesis from samples
 * - Live input granulation
 * - Multiple grain engines (4 simultaneous)
 * - Cloud-based grain distribution
 * - Spectral grain filtering
 * - Bio-reactive grain manipulation
 * - Visual grain cloud display
 * - Freeze mode for infinite sustain
 */
class GranularSampler : public juce::Synthesiser
{
public:
    static constexpr int maxGrainEngines = 4;

    struct GrainEngine
    {
        bool enabled = true;
        float grainSize = 50.0f;        // ms
        float density = 20.0f;          // grains/sec
        float position = 0.5f;          // 0.0 to 1.0
        float pitch = 0.0f;             // semitones
        float pan = 0.0f;               // -1.0 to 1.0
        float spray = 0.2f;             // randomization amount
    };

    GranularSampler();
    ~GranularSampler() override = default;

    void loadSample(const juce::AudioBuffer<float>& buffer);
    void setLiveInputEnabled(bool enabled);

    std::array<GrainEngine, maxGrainEngines>& getGrainEngines() { return grainEngines; }

    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float breath);

    void prepare(double sampleRate, int maxBlockSize);
    void reset();

private:
    std::array<GrainEngine, maxGrainEngines> grainEngines;
    juce::AudioBuffer<float> sampleBuffer;
    bool bioReactiveEnabled = false;
    double currentSampleRate = 48000.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (GranularSampler)
};
