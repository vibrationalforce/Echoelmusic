// ReverbEffect.h
// Reverb effect controlled by HRV

#pragma once
#include <JuceHeader.h>

class ReverbEffect
{
public:
    ReverbEffect();
    ~ReverbEffect();

    void prepare(double sampleRate, int samplesPerBlock);
    void process(juce::AudioBuffer<float>& buffer);
    void reset();

    // Parameters (0-1 normalized)
    void setWetness(float wetness);      // Dry/wet mix
    void setRoomSize(float size);        // Room size
    void setDamping(float damping);      // High frequency damping
    void setWidth(float width);          // Stereo width

    // Biofeedback control
    void setFromHRV(float hrv);          // HRV (0-100ms) → Reverb wetness

private:
    juce::dsp::Reverb reverb;
    juce::dsp::Reverb::Parameters params;

    double currentSampleRate = 44100.0;

    // Smoothing
    juce::SmoothedValue<float> smoothedWetness{0.5f};
    juce::SmoothedValue<float> smoothedRoomSize{0.5f};

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ReverbEffect)
};
