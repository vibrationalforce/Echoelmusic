#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>

/**
 * Tape Delay
 *
 * Vintage tape echo emulation with wow/flutter and saturation.
 * Inspired by classic units like Roland Space Echo, Echoplex.
 *
 * Features:
 * - Variable delay time (10ms to 2000ms)
 * - Wow and flutter modulation (tape speed variations)
 * - Tape saturation/distortion
 * - Feedback control
 * - Stereo width
 * - Highpass/lowpass filtering (tape aging)
 */
class TapeDelay
{
public:
    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    TapeDelay();
    ~TapeDelay() = default;

    //==========================================================================
    // Parameters
    //==========================================================================

    /** Set delay time in milliseconds (10 to 2000) */
    void setDelayTime(float timeMs);

    /** Set feedback amount (0.0 to 0.95) */
    void setFeedback(float fb);

    /** Set dry/wet mix (0.0 to 1.0) */
    void setMix(float mixAmount);

    /** Set wow/flutter amount (0.0 to 1.0) */
    void setWowFlutter(float amount);

    /** Set tape saturation amount (0.0 to 1.0) */
    void setSaturation(float sat);

    /** Set stereo width (0.0 = mono, 1.0 = wide stereo) */
    void setStereoWidth(float width);

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset delay buffers */
    void reset();

    /** Process audio buffer */
    void process(juce::AudioBuffer<float>& buffer);

private:
    //==========================================================================
    // Parameters
    //==========================================================================

    float delayTime = 500.0f;      // ms
    float feedback = 0.5f;         // 0-1
    float mix = 0.3f;              // 0-1
    float wowFlutter = 0.02f;      // 0-1
    float saturation = 0.1f;       // 0-1
    float stereoWidth = 0.5f;      // 0-1

    double currentSampleRate = 48000.0;

    //==========================================================================
    // Delay Buffers
    //==========================================================================

    std::array<std::vector<float>, 2> delayBuffers;
    std::array<int, 2> writePositions {{0, 0}};

    //==========================================================================
    // Modulation (Wow/Flutter)
    //==========================================================================

    float lfoPhase = 0.0f;
    float lfoIncrement = 0.0f;

    //==========================================================================
    // Filtering
    //==========================================================================

    struct FilterState
    {
        float lpY1 = 0.0f;  // Lowpass
        float hpX1 = 0.0f, hpY1 = 0.0f;  // Highpass
    };

    std::array<FilterState, 2> filterStates;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    float readDelayInterpolated(int channel, float delayInSamples);
    float applySaturation(float input);
    float applyFiltering(float input, int channel);
    void updateLFO();

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (TapeDelay)
};
