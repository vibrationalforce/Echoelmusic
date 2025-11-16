#pragma once

#include <JuceHeader.h>
#include "SpectralFramework.h"
#include <vector>
#include <array>

/**
 * ResonanceSuppressor
 *
 * Dynamic resonance removal processor inspired by oeksound Soothe2.
 * Automatically detects and suppresses harsh resonances and sibilance.
 *
 * Features:
 * - Automatic harsh frequency detection
 * - Dynamic multi-band suppression
 * - Surgical resonance removal without affecting overall tone
 * - Intelligent sibilance control
 * - Adaptive attack/release
 * - Mid/Side processing
 * - Delta (diff) monitoring
 * - Zero-latency operation
 * - Soft/hard knee control
 *
 * Unlike static EQ or de-essers, this dynamically targets only problematic
 * resonances when they occur, leaving the rest of the signal untouched.
 */
class ResonanceSuppressor
{
public:
    //==========================================================================
    // Processing Modes
    //==========================================================================

    enum class ProcessingMode
    {
        Broadband,      // Process entire frequency range
        HighShelf,      // Focus on high frequencies (de-essing)
        MidRange,       // Focus on mid frequencies (harshness)
        LowRange,       // Focus on low frequencies (boominess)
        Custom          // User-defined frequency range
    };

    enum class DetectionMode
    {
        Spectral,       // FFT-based detection (most accurate)
        RMS,            // RMS-based detection (faster)
        Peak,           // Peak-based detection (aggressive)
        Hybrid          // Combination of spectral + RMS
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    ResonanceSuppressor();
    ~ResonanceSuppressor() = default;

    //==========================================================================
    // Parameters
    //==========================================================================

    /** Set processing mode */
    void setProcessingMode(ProcessingMode mode);
    ProcessingMode getProcessingMode() const { return processingMode; }

    /** Set detection mode */
    void setDetectionMode(DetectionMode mode);
    DetectionMode getDetectionMode() const { return detectionMode; }

    /** Set depth (0.0 to 1.0) - amount of suppression */
    void setDepth(float depth);
    float getDepth() const { return suppressionDepth; }

    /** Set sharpness (0.0 to 1.0) - how selective the suppression is */
    void setSharpness(float sharpness);
    float getSharpness() const { return sharpness; }

    /** Set attack (0.1 to 100 ms) */
    void setAttack(float ms);
    float getAttack() const { return attackMs; }

    /** Set release (10 to 1000 ms) */
    void setRelease(float ms);
    float getRelease() const { return releaseMs; }

    /** Set selectivity (0.0 to 1.0) - how aggressively to target resonances */
    void setSelectivity(float selectivity);
    float getSelectivity() const { return selectivity; }

    /** Set frequency range (Hz) */
    void setFrequencyRange(float minFreq, float maxFreq);
    float getMinFrequency() const { return minFrequency; }
    float getMaxFrequency() const { return maxFrequency; }

    /** Set bandwidth (0.1 to 10.0 octaves) */
    void setBandwidth(float octaves);
    float getBandwidth() const { return bandwidth; }

    /** Enable/disable Mid/Side processing */
    void setMidSideMode(bool enabled);
    bool isMidSideMode() const { return midSideMode; }

    /** Set Mid/Side balance (-1.0 = Mid only, 0.0 = both, 1.0 = Side only) */
    void setMidSideBalance(float balance);

    /** Set dry/wet mix (0.0 to 1.0) */
    void setMix(float mix);
    float getMix() const { return wetMix; }

    /** Enable/disable delta (difference) mode for monitoring */
    void setDeltaMode(bool enabled);
    bool isDeltaMode() const { return deltaMode; }

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Visualization & Monitoring
    //==========================================================================

    /** Get detected resonances for visualization */
    struct ResonanceData
    {
        float frequency;
        float magnitude;
        float suppression;  // Amount of suppression applied (dB)
    };

    std::vector<ResonanceData> getDetectedResonances() const;

    /** Get real-time spectrum (input) */
    std::vector<float> getInputSpectrum() const;

    /** Get suppression curve being applied */
    std::vector<float> getSuppressionCurve() const;

    /** Get total gain reduction (dB) */
    float getTotalGainReduction() const { return totalGainReduction; }

    //==========================================================================
    // Advanced Settings
    //==========================================================================

    /** Set threshold offset (dB) - adjusts detection sensitivity */
    void setThresholdOffset(float dB);

    /** Set knee (dB) - softness of suppression transition */
    void setKnee(float dB);

    /** Set lookahead (0 to 20 ms) - improves transient handling */
    void setLookahead(float ms);

    /** Enable/disable auto-gain compensation */
    void setAutoGain(bool enabled);

private:
    //==========================================================================
    // Spectral Processing
    //==========================================================================

    SpectralFramework spectralEngine;

    static constexpr int numProcessingBands = 64;  // High-resolution processing

    struct ProcessingBand
    {
        float centerFreq = 0.0f;
        int binStart = 0;
        int binEnd = 0;

        // Detection
        float magnitude = 0.0f;
        float smoothedMagnitude = 0.0f;
        float threshold = 0.0f;
        bool isResonant = false;

        // Suppression
        float targetGain = 1.0f;
        float currentGain = 1.0f;
        float gainReduction = 0.0f;

        // Envelope follower
        float envelope = 0.0f;
    };

    std::array<ProcessingBand, numProcessingBands> bands;

    //==========================================================================
    // Parameters
    //==========================================================================

    ProcessingMode processingMode = ProcessingMode::Broadband;
    DetectionMode detectionMode = DetectionMode::Spectral;

    float suppressionDepth = 0.5f;
    float sharpness = 0.5f;
    float attackMs = 10.0f;
    float releaseMs = 100.0f;
    float selectivity = 0.5f;

    float minFrequency = 200.0f;
    float maxFrequency = 16000.0f;
    float bandwidth = 1.0f;  // octaves

    bool midSideMode = false;
    float midSideBalance = 0.0f;
    float wetMix = 1.0f;
    bool deltaMode = false;

    // Advanced
    float thresholdOffset = 0.0f;
    float knee = 6.0f;  // dB
    float lookaheadMs = 0.0f;
    bool autoGain = true;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // State
    //==========================================================================

    float attackCoeff = 0.0f;
    float releaseCoeff = 0.0f;
    float totalGainReduction = 0.0f;

    // Visualization
    mutable std::mutex visualMutex;
    std::vector<ResonanceData> detectedResonances;
    std::vector<float> inputSpectrum;
    std::vector<float> suppressionCurve;

    //==========================================================================
    // Internal Buffers
    //==========================================================================

    juce::AudioBuffer<float> dryBuffer;
    juce::AudioBuffer<float> midSideBuffer;
    SpectralFramework::SpectralData spectralDataL;
    SpectralFramework::SpectralData spectralDataR;
    SpectralFramework::SpectralData spectralDataMid;
    SpectralFramework::SpectralData spectralDataSide;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void initializeBands();
    void updateCoefficients();

    // Processing pipeline
    void analyzeBands(const SpectralFramework::SpectralData& data);
    void detectResonances();
    void calculateSuppressionGains();
    void applySuppression(SpectralFramework::SpectralData& data);

    // Detection algorithms
    float calculateAdaptiveThreshold(int bandIndex) const;
    bool isResonance(const ProcessingBand& band) const;
    float calculateResonanceScore(const ProcessingBand& band) const;

    // Utilities
    void convertToMidSide(juce::AudioBuffer<float>& buffer);
    void convertToStereo(juce::AudioBuffer<float>& buffer);
    void updateVisualization();

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (ResonanceSuppressor)
};
