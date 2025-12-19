#pragma once

#include <JuceHeader.h>

/**
 * @brief Audio Humanizer - 6-Dimension Humanization
 *
 * Professional audio humanization with 6 independent control dimensions.
 * Adds natural imperfections and character to make audio sound more organic.
 */
class AudioHumanizer
{
public:
    enum class TimeDivision
    {
        Sixteenth,
        Eighth,
        Quarter,
        Half,
        Whole,
        TwoBar,
        FourBar
    };

    AudioHumanizer();
    ~AudioHumanizer() = default;

    //==========================================================================
    // Lifecycle

    void prepare(double sampleRate, int maxBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // 6-Dimension Parameters

    void setHumanizationAmount(float amount);     // 0.0 to 1.0
    void setSpectralAmount(float amount);         // 0.0 to 1.0
    void setTransientAmount(float amount);        // 0.0 to 1.0
    void setColourAmount(float amount);           // 0.0 to 1.0
    void setNoiseAmount(float amount);            // 0.0 to 1.0
    void setSmoothAmount(float amount);           // 0.0 to 1.0

    void setTimeDivision(TimeDivision division);

    //==========================================================================
    // Bio-Reactive

    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float stress);

private:
    double currentSampleRate = 44100.0;

    // 6 Dimensions
    float humanizationAmount = 0.5f;
    float spectralAmount = 0.3f;
    float transientAmount = 0.4f;
    float colourAmount = 0.3f;
    float noiseAmount = 0.1f;
    float smoothAmount = 0.5f;

    float timeDivision = 0.25f;  // 16th notes

    // Bio-reactive
    bool bioReactiveEnabled = false;
    float currentHRV = 0.5f;
    float currentCoherence = 0.5f;
    float currentStress = 0.5f;

    // Processing state
    juce::Random random;
    float phase = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AudioHumanizer)
};
