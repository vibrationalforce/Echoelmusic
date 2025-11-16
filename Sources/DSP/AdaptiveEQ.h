#pragma once

#include <JuceHeader.h>
#include "SpectralFramework.h"
#include <vector>
#include <array>

/**
 * AdaptiveEQ
 *
 * Intelligent frequency balancer inspired by Soundtheory Gullfoss.
 * Uses real-time spectral analysis to automatically remove muddiness and enhance clarity.
 *
 * Features:
 * - Automatic masking detection and removal
 * - Real-time spectral balance optimization
 * - Adaptive clarity enhancement
 * - Intelligent tonal vs. noisy content separation
 * - Psychoacoustic-based processing
 * - Zero-latency operation
 * - Bio-reactive modulation support
 * - Transparent, surgical processing
 *
 * Unlike traditional EQs, this analyzes the audio content and dynamically
 * adjusts the frequency response to maximize clarity and balance.
 */
class AdaptiveEQ
{
public:
    //==========================================================================
    // Processing Modes
    //==========================================================================

    enum class ProcessingMode
    {
        Recover,        // Recover masked audio (clarity enhancement)
        Tame,           // Tame harsh frequencies (smoothing)
        Balanced        // Both recover and tame
    };

    enum class ListeningMode
    {
        Nearfield,      // Studio monitors/headphones
        Midfield,       // Living room
        Farfield,       // Large venue/club
        Custom
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    AdaptiveEQ();
    ~AdaptiveEQ() = default;

    //==========================================================================
    // Parameters
    //==========================================================================

    /** Set processing mode */
    void setProcessingMode(ProcessingMode mode);
    ProcessingMode getProcessingMode() const { return currentMode; }

    /** Set listening mode (affects perception model) */
    void setListeningMode(ListeningMode mode);
    ListeningMode getListeningMode() const { return listeningMode; }

    /** Set recover amount (0.0 to 1.0) - how much to bring up masked frequencies */
    void setRecoverAmount(float amount);
    float getRecoverAmount() const { return recoverAmount; }

    /** Set tame amount (0.0 to 1.0) - how much to reduce harsh frequencies */
    void setTameAmount(float amount);
    float getTameAmount() const { return tameAmount; }

    /** Set bias (0.0 to 1.0) - frequency balance bias (0.0 = dark, 0.5 = neutral, 1.0 = bright) */
    void setBias(float bias);
    float getBias() const { return frequencyBias; }

    /** Set clarity amount (0.0 to 1.0) - overall clarity enhancement */
    void setClarityAmount(float amount);
    float getClarityAmount() const { return clarityAmount; }

    /** Set dry/wet mix (0.0 to 1.0) */
    void setMix(float mix);
    float getMix() const { return wetMix; }

    /** Enable/disable bio-reactive modulation */
    void setBioReactiveEnabled(bool enabled);
    bool isBioReactiveEnabled() const { return bioReactiveEnabled; }

    /** Set bio-data for reactive processing (HRV: 0.0-1.0) */
    void setBioData(float hrv, float coherence);

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Visualization & Analysis
    //==========================================================================

    /** Get current spectral data for visualization */
    std::vector<float> getInputSpectrum() const;
    std::vector<float> getOutputSpectrum() const;

    /** Get applied EQ curve (shows what corrections were made) */
    std::vector<float> getAppliedEQCurve() const;

    /** Get masking detection data (0.0 = no masking, 1.0 = fully masked) */
    std::vector<float> getMaskingData() const;

    /** Get tonality data (0.0 = noisy, 1.0 = tonal) */
    std::vector<float> getTonalityData() const;

    //==========================================================================
    // Advanced Settings
    //==========================================================================

    /** Set frequency range to process (Hz) */
    void setFrequencyRange(float minFreq, float maxFreq);

    /** Set attack time for adaptive changes (ms) */
    void setAttackTime(float ms);

    /** Set release time for adaptive changes (ms) */
    void setReleaseTime(float ms);

    /** Set maximum boost/cut (dB) */
    void setMaxGain(float dB);

    /** Enable/disable zero-latency mode */
    void setZeroLatencyMode(bool enabled);

private:
    //==========================================================================
    // Spectral Processing
    //==========================================================================

    SpectralFramework spectralEngine;

    static constexpr int numERBBands = 40;  // Number of ERB-spaced bands

    struct ERBBand
    {
        float centerFreq = 0.0f;
        float bandwidth = 0.0f;
        int startBin = 0;
        int endBin = 0;

        // Analysis
        float magnitude = 0.0f;
        float tonality = 0.0f;
        float maskingLevel = 0.0f;

        // Processing
        float targetGain = 0.0f;
        float currentGain = 0.0f;
        float smoothedGain = 0.0f;
    };

    std::array<ERBBand, numERBBands> erbBands;

    //==========================================================================
    // Parameters
    //==========================================================================

    ProcessingMode currentMode = ProcessingMode::Balanced;
    ListeningMode listeningMode = ListeningMode::Nearfield;

    float recoverAmount = 0.5f;
    float tameAmount = 0.5f;
    float frequencyBias = 0.5f;  // 0.0 = dark, 1.0 = bright
    float clarityAmount = 0.5f;
    float wetMix = 1.0f;

    bool bioReactiveEnabled = false;
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;

    // Advanced
    float minFrequency = 20.0f;
    float maxFrequency = 20000.0f;
    float attackTimeMs = 50.0f;
    float releaseTimeMs = 200.0f;
    float maxGainDb = 12.0f;
    bool zeroLatency = false;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // State
    //==========================================================================

    // Smoothing coefficients
    float attackCoeff = 0.0f;
    float releaseCoeff = 0.0f;

    // Visualization data
    mutable std::mutex visualMutex;
    std::vector<float> inputSpectrum;
    std::vector<float> outputSpectrum;
    std::vector<float> appliedEQCurve;
    std::vector<float> maskingData;
    std::vector<float> tonalityData;

    //==========================================================================
    // Internal Buffers
    //==========================================================================

    juce::AudioBuffer<float> dryBuffer;
    SpectralFramework::SpectralData spectralDataL;
    SpectralFramework::SpectralData spectralDataR;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void initializeERBBands();
    void analyzeSpectrum(const SpectralFramework::SpectralData& data);
    void detectMasking();
    void detectTonality();
    void calculateTargetGains();
    void applyAdaptiveEQ(SpectralFramework::SpectralData& data);
    void smoothGains();
    void updateCoefficients();
    void updateVisualization();

    //==========================================================================
    // Psychoacoustic Models
    //==========================================================================

    float calculateMaskingThreshold(int bandIndex) const;
    float calculatePerceptualLoudness(float magnitude, float frequency) const;
    float calculateTonalityScore(const std::vector<float>& magnitudes,
                                  int centerBin) const;

    //==========================================================================
    // Bio-Reactive Processing
    //==========================================================================

    void applyBioReactiveModulation();

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (AdaptiveEQ)
};
