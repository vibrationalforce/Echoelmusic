#pragma once

#include <JuceHeader.h>
#include "SpectralFramework.h"
#include <vector>
#include <array>

/**
 * QuantumDelay - Multi-Dimensional Delay Network
 *
 * Advanced delay effect with 16 independent delay lines, spectral processing,
 * granular delays, and neural feedback networks.
 *
 * Features:
 * - 16 independent delay lines with full routing matrix
 * - Spectral delay (frequency-dependent timing)
 * - Granular delay (grain-based processing)
 * - Neural feedback network (ML-controlled evolution)
 * - Diffusion scatter effects
 * - Spectral freezing
 * - Bio-reactive delay modulation
 */
class QuantumDelay
{
public:
    static constexpr int numDelayLines = 16;

    enum class DelayType
    {
        Classic,            // Time-based
        Spectral,           // FFT-based, different delay per frequency
        Granular,           // Grain-based
        Diffusion,          // Scatter effect
        PitchShifting,      // Pitch-shifted delay
        Reverse,            // Reverse delay
        Freeze              // Infinite hold
    };

    struct DelayLine
    {
        bool enabled = true;
        DelayType type = DelayType::Classic;
        float delayTime = 250.0f;      // ms
        float feedback = 0.5f;          // 0.0 to 1.0
        float mix = 0.5f;
        float pan = 0.0f;               // -1.0 to +1.0

        // Modulation
        float lfoRate = 0.5f;           // Hz
        float lfoAmount = 0.0f;         // 0.0 to 1.0

        // Filtering
        float lowCut = 20.0f;           // Hz
        float highCut = 20000.0f;       // Hz
    };

    QuantumDelay();
    ~QuantumDelay() = default;

    std::array<DelayLine, numDelayLines>& getDelayLines() { return delayLines; }

    void setFeedbackMatrix(int from, int to, float amount);  // Route any delay to any delay
    void setNeuralFeedbackEnabled(bool enabled);

    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float breath);

    void prepare(double sampleRate, int maxBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

private:
    std::array<DelayLine, numDelayLines> delayLines;
    std::array<std::array<float, numDelayLines>, numDelayLines> feedbackMatrix;
    SpectralFramework spectralEngine;
    bool neuralFeedbackEnabled = false;
    bool bioReactiveEnabled = false;
    double currentSampleRate = 48000.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (QuantumDelay)
};
