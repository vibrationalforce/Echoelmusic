#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>

/**
 * Parametric EQ
 *
 * Professional-grade parametric equalizer with up to 32 bands.
 * Surgical precision for mixing, mastering, and broadcast.
 *
 * Features:
 * - 8-32 adjustable bands
 * - 8 filter types: Peak, Low/High Shelf, Low/High Pass, Band Pass, Notch, All Pass
 * - Biquad filter implementation
 * - Per-band enable/disable
 * - Sample rates: 44.1kHz - 192kHz
 * - Zero-latency processing
 */
class ParametricEQ
{
public:
    //==========================================================================
    // Filter Types
    //==========================================================================

    enum class FilterType
    {
        LowShelf,
        HighShelf,
        Peak,
        LowPass,
        HighPass,
        BandPass,
        Notch,
        AllPass
    };

    //==========================================================================
    // Band Configuration
    //==========================================================================

    struct Band
    {
        float frequency = 1000.0f;    // Hz
        float gain = 0.0f;             // dB (-24 to +24)
        float q = 1.0f;                // Quality factor (0.1 to 20.0)
        FilterType type = FilterType::Peak;
        bool enabled = true;

        Band() = default;
        Band(float freq, float gainDb, float quality, FilterType filterType)
            : frequency(freq), gain(gainDb), q(quality), type(filterType) {}
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    ParametricEQ(int numBands = 8);
    ~ParametricEQ() = default;

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing with given sample rate */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset filter states */
    void reset();

    /** Process audio buffer (stereo) */
    void process(juce::AudioBuffer<float>& buffer);

    /** Process single channel */
    void processChannel(float* channelData, int numSamples, int channelIndex);

    //==========================================================================
    // Band Management
    //==========================================================================

    /** Get number of bands */
    int getNumBands() const { return static_cast<int>(bands.size()); }

    /** Set band parameters */
    void setBand(int index, float frequency, float gain, float q, FilterType type);

    /** Set individual band parameters */
    void setBandFrequency(int index, float frequency);
    void setBandGain(int index, float gain);
    void setBandQ(int index, float q);
    void setBandType(int index, FilterType type);
    void setBandEnabled(int index, bool enabled);

    /** Get band configuration */
    Band getBand(int index) const;

    /** Load preset band configuration */
    void loadPreset(const juce::String& presetName);

    //==========================================================================
    // Utility
    //==========================================================================

    /** Get frequency response at given frequency (magnitude in dB) */
    float getFrequencyResponse(float frequency) const;

    /** Get filter type name */
    static juce::String getFilterTypeName(FilterType type);

private:
    //==========================================================================
    // Biquad Filter State
    //==========================================================================

    struct BiquadCoefficients
    {
        float b0 = 1.0f, b1 = 0.0f, b2 = 0.0f;
        float a1 = 0.0f, a2 = 0.0f;
    };

    struct BiquadState
    {
        float x1 = 0.0f, x2 = 0.0f;  // Input delays
        float y1 = 0.0f, y2 = 0.0f;  // Output delays
    };

    //==========================================================================
    // Member Variables
    //==========================================================================

    std::vector<Band> bands;
    double currentSampleRate = 48000.0;

    // Filter states per channel per band
    std::vector<std::array<BiquadState, 2>> filterStates;  // [band][channel]

    // Cached coefficients per band
    std::vector<BiquadCoefficients> coefficients;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    /** Calculate biquad coefficients for band */
    BiquadCoefficients calculateCoefficients(const Band& band) const;

    /** Apply biquad filter to single sample */
    inline float processBiquad(float input, BiquadCoefficients& coeff, BiquadState& state) const
    {
        float output = coeff.b0 * input + coeff.b1 * state.x1 + coeff.b2 * state.x2
                       - coeff.a1 * state.y1 - coeff.a2 * state.y2;

        // Update state
        state.x2 = state.x1;
        state.x1 = input;
        state.y2 = state.y1;
        state.y1 = output;

        return output;
    }

    /** Update coefficients for all bands */
    void updateCoefficients();

    /** Initialize default bands */
    void initializeDefaultBands(int numBands);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (ParametricEQ)
};
