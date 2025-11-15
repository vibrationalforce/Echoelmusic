// DelayEffect.h
// Stereo delay effect

#pragma once
#include <JuceHeader.h>

class DelayEffect
{
public:
    DelayEffect();
    ~DelayEffect();

    void prepare(double sampleRate, int samplesPerBlock);
    void process(juce::AudioBuffer<float>& buffer);
    void reset();

    // Parameters
    void setDelayTime(float timeMs);     // Delay time in milliseconds
    void setFeedback(float feedback);    // Feedback amount (0-0.95)
    void setWetness(float wetness);      // Dry/wet mix

private:
    juce::dsp::DelayLine<float, juce::dsp::DelayLineInterpolationTypes::Linear> delayLineLeft;
    juce::dsp::DelayLine<float, juce::dsp::DelayLineInterpolationTypes::Linear> delayLineRight;

    double currentSampleRate = 44100.0;

    float delayTimeMs = 250.0f;
    float feedbackAmount = 0.5f;
    float wetAmount = 0.3f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(DelayEffect)
};
