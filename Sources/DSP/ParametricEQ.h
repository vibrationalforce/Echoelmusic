#pragma once

#include <JuceHeader.h>

/**
 * ParametricEQ - 8-band parametric equalizer
 *
 * Professional-grade EQ with:
 * - 8 fully parametric bands
 * - Low/High-pass filters
 * - Low/High shelf
 * - Bell filters
 * - Surgical precision or musical warmth
 */
class ParametricEQ
{
public:
    //==========================================================================
    struct Band
    {
        enum class Type
        {
            LowPass,
            HighPass,
            LowShelf,
            HighShelf,
            Bell,
            Notch,
            BandPass
        };

        Type type = Type::Bell;
        float frequency = 1000.0f;  // Hz
        float gain = 0.0f;          // dB (-24 to +24)
        float Q = 1.0f;             // Quality factor (0.1 to 10.0)
        bool enabled = false;

        Band() = default;
    };

    //==========================================================================
    ParametricEQ();
    ~ParametricEQ();

    void prepare(double sampleRate, int maximumBlockSize);
    void reset();

    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Band Control
    //==========================================================================

    static constexpr int numBands = 8;

    void setBand(int bandIndex, const Band& settings);
    Band getBand(int bandIndex) const;

    void setBandEnabled(int bandIndex, bool enabled);
    void setBandType(int bandIndex, Band::Type type);
    void setBandFrequency(int bandIndex, float frequency);
    void setBandGain(int bandIndex, float gain);
    void setBandQ(int bandIndex, float Q);

    //==========================================================================
    // Presets
    //==========================================================================

    void loadPreset(const juce::String& presetName);

    void presetFlat();
    void presetVocalWarmth();
    void presetKickPunch();
    void presetAirySynth();
    void presetMasterBrightness();

private:
    double currentSampleRate = 48000.0;

    std::array<Band, numBands> bands;
    std::array<juce::dsp::IIR::Filter<float>, numBands * 2> filters; // Stereo

    void updateFilters();
    void updateFilterCoefficients(int bandIndex);

    juce::dsp::IIR::Coefficients<float>::Ptr createCoefficients(const Band& band);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ParametricEQ)
};
