#pragma once

#include <JuceHeader.h>
#include <array>

/**
 * De-Esser
 *
 * Professional de-esser for vocal processing.
 * Reduces harsh sibilance (s, t, sh sounds) in the 4-10kHz range.
 *
 * Features:
 * - Frequency-selective compression
 * - Adjustable sibilance detection frequency
 * - Variable bandwidth control
 * - Transparent processing
 * - Real-time sibilance detection
 */
class DeEsser
{
public:
    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    DeEsser();
    ~DeEsser() = default;

    //==========================================================================
    // Parameters
    //==========================================================================

    /** Set threshold in dBFS (-60 to 0) */
    void setThreshold(float thresholdDb);

    /** Set center frequency for sibilance detection (2000 to 12000 Hz) */
    void setFrequency(float freq);

    /** Set bandwidth in Hz (1000 to 8000) */
    void setBandwidth(float bw);

    /** Set compression ratio (1.0 to 10.0) */
    void setRatio(float ratio);

    /** Enable/disable processing */
    void setEnabled(bool enabled);

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset state */
    void reset();

    /** Process audio buffer */
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Metering
    //==========================================================================

    /** Get gain reduction in dB */
    float getGainReduction(int channel) const;

    /** Get sibilance level in dB */
    float getSibilanceLevel(int channel) const;

private:
    //==========================================================================
    // Parameters
    //==========================================================================

    float threshold = -20.0f;      // dBFS
    float frequency = 6000.0f;     // Hz
    float bandwidth = 4000.0f;     // Hz
    float ratio = 5.0f;
    bool enabled = true;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // State
    //==========================================================================

    struct ChannelState
    {
        float envelope = 0.0f;
        float gainReduction = 0.0f;
        float sibilanceLevel = -100.0f;

        // Bandpass filter state (biquad)
        float bpX1 = 0.0f, bpX2 = 0.0f;
        float bpY1 = 0.0f, bpY2 = 0.0f;
    };

    std::array<ChannelState, 2> channelStates;

    // Attack/release coefficients
    float attackCoeff = 0.0f;
    float releaseCoeff = 0.0f;

    // Bandpass filter coefficients
    struct BiquadCoeffs
    {
        float b0, b1, b2, a1, a2;
    } bpCoeffs;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void updateCoefficients();
    void updateBandpassCoefficients();

    float applyBandpass(float input, ChannelState& state);
    float calculateGainReduction(float sibilanceDb);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (DeEsser)
};
