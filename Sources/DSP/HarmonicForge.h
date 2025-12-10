#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>

/**
 * HarmonicForge
 *
 * Professional multiband saturation and harmonic distortion processor.
 * Inspired by Soundtoys Decapitator, FabFilter Saturn, Waves Abbey Road TG.
 * Evolved with multiband processing and advanced harmonic control.
 *
 * Features:
 * - 4-band multiband processing
 * - 5 saturation models (Tube, Tape, Transistor, Digital, Transformer)
 * - Per-band saturation type and drive
 * - Parallel processing (dry/wet mix per band)
 * - Auto-makeup gain
 * - High/Low cut filters
 * - Harmonic spectrum analyzer
 * - Zero-latency processing
 */
class HarmonicForge
{
public:
    //==========================================================================
    // Saturation Model
    //==========================================================================

    enum class SaturationType
    {
        Tube,           // Smooth, warm tube saturation (even harmonics)
        Tape,           // Vintage tape saturation (soft knee)
        Transistor,     // Solid-state transistor (harder clipping)
        Digital,        // Digital hard clipping (bit reduction)
        Transformer     // Transformer saturation (subtle harmonics)
    };

    //==========================================================================
    // Band Configuration
    //==========================================================================

    struct Band
    {
        // Processing
        bool enabled = true;
        SaturationType saturationType = SaturationType::Tube;
        float drive = 0.0f;                 // 0.0 to 1.0 (0dB to +40dB)
        float mix = 1.0f;                   // Parallel processing mix
        float output = 1.0f;                // Output gain

        // Frequency Range (for multiband)
        float lowCutFreq = 20.0f;           // Hz
        float highCutFreq = 20000.0f;       // Hz

        // Metering
        float inputLevel = 0.0f;            // Peak level
        float outputLevel = 0.0f;           // Peak level
        float gainReduction = 0.0f;         // Amount of saturation applied

        Band() = default;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    HarmonicForge();
    ~HarmonicForge() = default;

    //==========================================================================
    // Processing Mode
    //==========================================================================

    /** Set multiband mode (false = single band, true = 4 bands) */
    void setMultibandMode(bool enabled);
    bool isMultibandMode() const { return multibandEnabled; }

    //==========================================================================
    // Band Management
    //==========================================================================

    /** Get number of bands */
    int getNumBands() const { return multibandEnabled ? 4 : 1; }

    /** Get/Set band configuration */
    Band& getBand(int index);
    const Band& getBand(int index) const;
    void setBand(int index, const Band& band);

    /** Set band parameters */
    void setBandEnabled(int index, bool enabled);
    void setBandSaturationType(int index, SaturationType type);
    void setBandDrive(int index, float drive);
    void setBandMix(int index, float mix);
    void setBandOutput(int index, float output);

    //==========================================================================
    // Global Parameters
    //==========================================================================

    /** Set input gain in dB (-20 to +20) */
    void setInputGain(float gainDb);

    /** Set output gain in dB (-20 to +20) */
    void setOutputGain(float gainDb);

    /** Enable/disable auto-makeup gain */
    void setAutoMakeupGain(bool enabled);

    /** Set high quality oversampling (2x, 4x, 8x) */
    void setOversamplingFactor(int factor);

    //==========================================================================
    // Crossover (Multiband)
    //==========================================================================

    /** Set crossover frequencies (Hz) - 3 frequencies for 4 bands */
    void setCrossoverFrequencies(float low, float mid1, float mid2);

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
    // Visualization
    //==========================================================================

    /** Get harmonic spectrum data (128 bins, dB scale) */
    std::vector<float> getHarmonicSpectrum(int bandIndex = 0) const;

    /** Get input/output levels in dB */
    float getInputLevel(int bandIndex = 0) const;
    float getOutputLevel(int bandIndex = 0) const;

private:
    //==========================================================================
    // Band State
    //==========================================================================

    struct BandState
    {
        // Crossover filters (Linkwitz-Riley 4th order)
        std::array<float, 8> filterState {{0.0f}};  // Per channel

        // Peak meters
        float inputPeak = 0.0f;
        float outputPeak = 0.0f;

        // Spectrum data for visualization
        std::vector<float> spectrumData;
    };

    //==========================================================================
    // Member Variables
    //==========================================================================

    std::array<Band, 4> bands;
    std::array<BandState, 4> bandStates;

    bool multibandEnabled = false;
    double currentSampleRate = 48000.0;

    // Global parameters
    float inputGainDb = 0.0f;
    float outputGainDb = 0.0f;
    bool autoMakeupGain = true;
    int oversamplingFactor = 1;  // 1, 2, 4, or 8

    // Crossover frequencies (Hz) for 4-band mode
    float crossover1 = 200.0f;   // Low/Low-Mid
    float crossover2 = 2000.0f;  // Low-Mid/High-Mid
    float crossover3 = 8000.0f;  // High-Mid/High

    // Oversampling
    std::unique_ptr<juce::dsp::Oversampling<float>> oversampling;

    // Visualization
    mutable std::mutex spectrumMutex;

    // ✅ OPTIMIZATION: Pre-allocated buffers to avoid audio thread allocation
    std::array<juce::AudioBuffer<float>, 4> multibandBuffers;
    juce::AudioBuffer<float> dryBuffer;
    int maxBlockSize = 512;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    // Single-band processing
    void processSingleBand(juce::AudioBuffer<float>& buffer);

    // Multiband processing
    void processMultiband(juce::AudioBuffer<float>& buffer);

    // Crossover filter
    void applyCrossover(const juce::AudioBuffer<float>& input,
                       std::array<juce::AudioBuffer<float>, 4>& bands);

    // Band processing
    void processBand(juce::AudioBuffer<float>& buffer, int bandIndex);

    // Saturation algorithms
    float applySaturation(float input, SaturationType type, float drive);
    float tubeSaturation(float input, float drive);
    float tapeSaturation(float input, float drive);
    float transistorSaturation(float input, float drive);
    float digitalSaturation(float input, float drive);
    float transformerSaturation(float input, float drive);

    // Utilities
    void updateCrossoverCoefficients();
    void updateMeters(int bandIndex, const juce::AudioBuffer<float>& buffer);
    float calculateMakeupGain(float drive) const;

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (HarmonicForge)
};
