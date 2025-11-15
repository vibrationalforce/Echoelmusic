// FilterEffect.h
// Multi-mode filter (LP, HP, BP) controlled by biofeedback

#pragma once
#include <JuceHeader.h>

class FilterEffect
{
public:
    enum FilterType
    {
        LowPass,
        HighPass,
        BandPass
    };

    FilterEffect();
    ~FilterEffect();

    void prepare(double sampleRate, int samplesPerBlock);
    void process(juce::AudioBuffer<float>& buffer);
    void reset();

    // Parameters
    void setCutoff(float frequency);     // Cutoff frequency (20-20000 Hz)
    void setResonance(float q);          // Filter resonance (0.1-10.0)
    void setType(FilterType type);       // Filter type

    // Biofeedback control
    void setFromBreathRate(float breathRate);  // Breath (5-30/min) → Cutoff modulation

private:
    using Filter = juce::dsp::StateVariableTPTFilter<float>;

    Filter filterLeft;
    Filter filterRight;

    double currentSampleRate = 44100.0;
    FilterType currentType = LowPass;

    float cutoffFrequency = 1000.0f;
    float resonanceQ = 0.707f;

    // Smoothing
    juce::SmoothedValue<float> smoothedCutoff{1000.0f};

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(FilterEffect)
};
