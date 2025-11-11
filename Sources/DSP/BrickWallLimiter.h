#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>

/**
 * Brick-Wall Limiter
 *
 * True-peak limiting for broadcast/mastering with look-ahead.
 * Prevents clipping and ensures compliance with broadcasting standards.
 *
 * Features:
 * - Look-ahead peak detection (0-10ms)
 * - True peak limiting (ITU-R BS.1770 compliant)
 * - Automatic release adaptation
 * - Soft-knee limiting option
 * - Zero overshoot guarantee
 * - Transparent limiting up to ceiling
 * - ISP (Inter-Sample Peak) detection
 */
class BrickWallLimiter
{
public:
    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    BrickWallLimiter();
    ~BrickWallLimiter() = default;

    //==========================================================================
    // Parameters
    //==========================================================================

    /** Set threshold in dBFS (-60 to 0) */
    void setThreshold(float thresholdDb);

    /** Set ceiling/max output in dBFS (-0.3 to 0.0) */
    void setCeiling(float ceilingDb);

    /** Set release time in milliseconds (10 to 1000) */
    void setRelease(float releaseMs);

    /** Set look-ahead time in milliseconds (0 to 10) */
    void setLookahead(float lookaheadMs);

    /** Enable/disable true peak detection (ITU-R BS.1770) */
    void setTruePeakEnabled(bool enabled);

    /** Set soft knee width in dB (0 to 6) */
    void setSoftKnee(float kneeDb);

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset limiter state */
    void reset();

    /** Process audio buffer (stereo) */
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Metering
    //==========================================================================

    /** Get current gain reduction in dB (negative value) */
    float getGainReduction(int channel) const;

    /** Get input level in dBFS */
    float getInputLevel(int channel) const;

    /** Get output level in dBFS */
    float getOutputLevel(int channel) const;

    /** Check if limiting is currently active */
    bool isLimiting() const;

    /** Get maximum peak since last reset */
    float getPeakSinceReset() const;

    /** Reset peak meter */
    void resetPeakMeter();

private:
    //==========================================================================
    // Parameters
    //==========================================================================

    float threshold = -0.3f;        // dBFS
    float ceiling = -0.1f;          // dBFS
    float release = 100.0f;         // ms
    float lookaheadMs = 5.0f;       // ms
    float softKnee = 0.0f;          // dB
    bool truePeakEnabled = true;

    //==========================================================================
    // State
    //==========================================================================

    double currentSampleRate = 48000.0;
    int lookaheadSamples = 0;

    // Look-ahead delay buffers per channel
    std::array<std::vector<float>, 2> lookaheadBuffers;
    std::array<int, 2> lookaheadWritePos {{0, 0}};

    // Gain envelope per channel
    std::array<float, 2> gainEnvelope {{1.0f, 1.0f}};

    // Release coefficient
    float releaseCoeff = 0.999f;

    // Metering
    std::array<float, 2> gainReduction {{0.0f, 0.0f}};
    std::array<float, 2> inputLevel {{-100.0f, -100.0f}};
    std::array<float, 2> outputLevel {{-100.0f, -100.0f}};
    float maxPeak = 0.0f;
    bool currentlyLimiting = false;

    // True peak detection (4x oversampling approximation)
    std::array<std::array<float, 3>, 2> truePeakHistory;  // [channel][tap]

    //==========================================================================
    // Internal Methods
    //==========================================================================

    /** Calculate required gain reduction for given level */
    float calculateGainReduction(float levelDb) const;

    /** Detect true peak using oversampling approximation */
    float detectTruePeak(float sample, int channel);

    /** Update release coefficient based on release time */
    void updateReleaseCoeff();

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (BrickWallLimiter)
};
