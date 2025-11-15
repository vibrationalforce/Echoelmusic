#pragma once

#include <JuceHeader.h>
#include "ParametricEQ.h"
#include <array>
#include <vector>

/**
 * Dynamic EQ
 *
 * Professional dynamic equalizer combining EQ and compression.
 * Each band can compress/expand dynamically based on signal level.
 * Inspired by FabFilter Pro-Q 3, Waves F6, iZotope Neutron.
 *
 * Features:
 * - 8 dynamic EQ bands
 * - Per-band: frequency, gain, Q, threshold, ratio, attack, release
 * - Dynamic boost or cut modes
 * - Mid/Side processing per band
 * - Real-time spectrum analyzer with band overlays
 * - Solo/mute per band
 * - Sidechain input per band
 * - Look-ahead processing
 */
class DynamicEQ
{
public:
    //==========================================================================
    // Dynamic Mode
    //==========================================================================

    enum class DynamicMode
    {
        Static,         // Normal EQ (no dynamics)
        DynamicCut,     // Reduce gain when signal exceeds threshold
        DynamicBoost,   // Increase gain when signal exceeds threshold
        Expander        // Reduce gain when signal is below threshold
    };

    //==========================================================================
    // Band Configuration
    //==========================================================================

    struct Band
    {
        // EQ Parameters
        float frequency = 1000.0f;                      // Hz
        float gain = 0.0f;                              // dB
        float q = 1.0f;                                 // Quality factor
        ParametricEQ::FilterType filterType = ParametricEQ::FilterType::Peak;

        // Dynamics Parameters
        DynamicMode dynamicMode = DynamicMode::Static;
        float threshold = -20.0f;                       // dBFS
        float ratio = 3.0f;                             // X:1
        float attack = 10.0f;                           // ms
        float release = 100.0f;                         // ms
        float knee = 3.0f;                              // dB

        // Processing Options
        bool enabled = true;
        bool solo = false;
        bool midSideMode = false;  // false = stereo, true = mid/side
        bool processMid = true;    // For M/S mode
        bool processSide = true;   // For M/S mode

        // Metering
        float currentGainReduction = 0.0f;

        Band() = default;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    DynamicEQ();
    ~DynamicEQ() = default;

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset all states */
    void reset();

    /** Process audio buffer */
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Band Management
    //==========================================================================

    /** Get number of bands */
    constexpr int getNumBands() const { return 8; }

    /** Get/Set band configuration */
    Band& getBand(int index);
    const Band& getBand(int index) const;
    void setBand(int index, const Band& band);

    /** Set individual parameters */
    void setBandFrequency(int index, float freq);
    void setBandGain(int index, float gain);
    void setBandQ(int index, float q);
    void setBandDynamicMode(int index, DynamicMode mode);
    void setBandThreshold(int index, float threshold);
    void setBandRatio(int index, float ratio);

    //==========================================================================
    // Spectrum Analysis
    //==========================================================================

    /** Get FFT spectrum data for visualization (64 bins, 0.0-1.0) */
    std::vector<float> getSpectrumData() const;

    /** Enable/disable spectrum analyzer */
    void setSpectrumAnalyzerEnabled(bool enabled);

private:
    //==========================================================================
    // Band State
    //==========================================================================

    struct BandState
    {
        // Parametric EQ filter
        ParametricEQ::BiquadCoefficients eqCoeffs;

        // Biquad filter state per channel
        std::array<ParametricEQ::Band, 2> filterStates;  // [L/R]

        // Dynamics state per channel
        std::array<float, 2> envelope {{0.0f, 0.0f}};
        std::array<float, 2> gainReduction {{0.0f, 0.0f}};

        // Attack/release coefficients
        float attackCoeff = 0.0f;
        float releaseCoeff = 0.0f;
    };

    //==========================================================================
    // Member Variables
    //==========================================================================

    std::array<Band, 8> bands;
    std::array<BandState, 8> bandStates;

    double currentSampleRate = 48000.0;

    // Spectrum Analyzer (FFT)
    bool spectrumEnabled = true;
    static constexpr int fftOrder = 11;  // 2048 samples
    static constexpr int fftSize = 1 << fftOrder;
    static constexpr int spectrumBins = 64;

    juce::dsp::FFT fft {fftOrder};
    juce::dsp::WindowingFunction<float> window {fftSize, juce::dsp::WindowingFunction<float>::hann};

    std::array<float, fftSize * 2> fftData;
    int fftDataIndex = 0;

    std::array<float, spectrumBins> spectrumData;
    mutable std::mutex spectrumMutex;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void processBand(int bandIndex,
                     float* leftChannel,
                     float* rightChannel,
                     int numSamples);

    float calculateDynamicGain(float inputLevel,
                                const Band& band,
                                float envelope);

    void updateBandCoefficients(int bandIndex);
    void updateSpectrumData(const juce::AudioBuffer<float>& buffer);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (DynamicEQ)
};
