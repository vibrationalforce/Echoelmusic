#pragma once

#include <JuceHeader.h>

/**
 * Stereo Imager
 *
 * Professional stereo width and imaging control.
 * Mid/Side processing for precise stereo manipulation.
 *
 * Features:
 * - Stereo width control (mono to super-wide)
 * - Mid/Side processing
 * - Independent mid/side gain
 * - Stereo balance
 * - Mono compatibility check
 * - Correlation meter
 */
class StereoImager
{
public:
    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    StereoImager();
    ~StereoImager() = default;

    //==========================================================================
    // Parameters
    //==========================================================================

    /** Set stereo width (0.0 = mono, 1.0 = normal, 2.0 = super wide) */
    void setWidth(float widthAmount);

    /** Set mid channel gain in dB (-12 to +12) */
    void setMidGain(float gainDb);

    /** Set side channel gain in dB (-12 to +12) */
    void setSideGain(float gainDb);

    /** Set stereo balance (-1.0 = left, 0.0 = center, 1.0 = right) */
    void setBalance(float bal);

    /** Enable mono output for compatibility check */
    void setMonoOutput(bool mono);

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset state */
    void reset();

    /** Process audio buffer (must be stereo) */
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Metering
    //==========================================================================

    /** Get stereo correlation (-1.0 to +1.0) */
    float getCorrelation() const { return correlation; }

    /** Get mid level in dB */
    float getMidLevel() const { return midLevel; }

    /** Get side level in dB */
    float getSideLevel() const { return sideLevel; }

private:
    //==========================================================================
    // Parameters
    //==========================================================================

    float width = 1.0f;            // 0-2
    float midGain = 1.0f;          // Linear gain
    float sideGain = 1.0f;         // Linear gain
    float balance = 0.0f;          // -1 to 1
    bool monoOutput = false;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // Metering
    //==========================================================================

    float correlation = 0.0f;
    float midLevel = -100.0f;
    float sideLevel = -100.0f;

    float correlationSum = 0.0f;
    int correlationSampleCount = 0;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void updateMetering(float left, float right);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (StereoImager)
};
