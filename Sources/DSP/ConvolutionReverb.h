#pragma once

#include <JuceHeader.h>
#include <vector>

/**
 * Convolution Reverb
 *
 * High-quality convolution reverb using impulse responses.
 * Professional spatial processing for realistic room simulation.
 *
 * Features:
 * - FFT-based convolution (fast)
 * - Impulse response loading (.wav files)
 * - Dry/wet mix
 * - Pre-delay
 * - Low/high cut filters
 * - Zero-latency (with proper buffering)
 */
class ConvolutionReverb
{
public:
    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    ConvolutionReverb();
    ~ConvolutionReverb() = default;

    //==========================================================================
    // Parameters
    //==========================================================================

    /** Set dry/wet mix (0.0 to 1.0) */
    void setMix(float mixAmount);

    /** Set pre-delay in milliseconds (0 to 100) */
    void setPreDelay(float delayMs);

    /** Set low cut frequency in Hz (20 to 500) */
    void setLowCut(float freq);

    /** Set high cut frequency in Hz (2000 to 20000) */
    void setHighCut(float freq);

    //==========================================================================
    // Impulse Response
    //==========================================================================

    /** Load impulse response from audio buffer */
    void loadImpulseResponse(const juce::AudioBuffer<float>& ir);

    /** Load impulse response from file */
    bool loadImpulseResponseFromFile(const juce::File& file);

    /** Get current impulse response length in samples */
    int getImpulseResponseLength() const;

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset convolution state */
    void reset();

    /** Process audio buffer */
    void process(juce::AudioBuffer<float>& buffer);

private:
    //==========================================================================
    // Parameters
    //==========================================================================

    float mix = 0.3f;
    float preDelay = 0.0f;          // ms
    float lowCutFreq = 20.0f;       // Hz
    float highCutFreq = 20000.0f;   // Hz

    double currentSampleRate = 48000.0;

    //==========================================================================
    // Convolution Engine (JUCE built-in)
    //==========================================================================

    juce::dsp::Convolution convolutionEngine;
    bool impulseLoaded = false;

    //==========================================================================
    // Pre-delay Buffer
    //==========================================================================

    std::vector<std::vector<float>> preDelayBuffers;  // Per channel
    std::vector<int> preDelayWritePositions;

    //==========================================================================
    // Dry Buffer (pre-allocated to avoid allocations in audio thread)
    //==========================================================================

    juce::AudioBuffer<float> dryBuffer;

    //==========================================================================
    // Filtering
    //==========================================================================

    struct FilterState
    {
        // Highpass (low cut)
        float hpX1 = 0.0f, hpY1 = 0.0f;

        // Lowpass (high cut)
        float lpY1 = 0.0f;
    };

    std::vector<FilterState> filterStates;

    // OPTIMIZATION: Pre-computed filter coefficients (avoid per-sample trig)
    float hpCoeff = 0.999f;    // Highpass coefficient
    float lpCoeff = 0.001f;    // Lowpass coefficient
    float lpOneMinusCoeff = 0.999f;  // 1 - lpCoeff (cached)
    void updateFilterCoefficients();

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void updatePreDelayBuffers();
    void applyPreDelay(juce::AudioBuffer<float>& buffer);
    void applyFiltering(juce::AudioBuffer<float>& buffer);
    float applyHighpass(float input, FilterState& state);
    float applyLowpass(float input, FilterState& state);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (ConvolutionReverb)
};
