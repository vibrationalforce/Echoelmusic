#pragma once

#include <JuceHeader.h>
#include <vector>
#include <complex>

/**
 * Mid/Side Tone Matching
 *
 * Professional M/S domain tone matching inspired by Rast Sound MS Studio (2025).
 * Analyzes a reference track's Mid/Side frequency content and adjusts your audio
 * to match the reference tonality while preserving stereo width and clarity.
 *
 * **Innovation**: First M/S tone matcher with bio-reactive learning integration.
 *
 * Features:
 * - Separate FFT analysis for Mid and Side channels
 * - Reference track spectral profiling
 * - Multi-band EQ matching (32 bands per channel)
 * - Automatic resonance cleanup (integrated with IntelligentResonanceSuppressor)
 * - Stereo width preservation
 * - Phase correlation monitoring
 * - Bio-reactive matching strength (HRV-controlled)
 * - Real-time or offline processing
 * - Learning mode (builds average reference over time)
 *
 * Use Cases:
 * - Match professional mixes in M/S domain
 * - Surgical stereo field adjustments
 * - Genre-specific M/S balancing
 * - Mastering reference matching
 * - Mix bus processing
 *
 * Workflow:
 * 1. Load reference track and analyze (learnReferenceProfile)
 * 2. Set matching strength (0.0 = bypass, 1.0 = full match)
 * 3. Process your audio
 * 4. Fine-tune mid/side balance independently
 */
class MidSideToneMatching
{
public:
    //==========================================================================
    // Processing Mode
    //==========================================================================

    enum class MatchingMode
    {
        FullSpectrum,       // Match entire frequency range
        LowMids,            // Match 20-500 Hz (low end & warmth)
        Midrange,           // Match 500-4000 Hz (presence & body)
        HighFrequencies,    // Match 4000-20000 Hz (air & clarity)
        Custom              // User-defined frequency range
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    MidSideToneMatching();
    ~MidSideToneMatching() = default;

    //==========================================================================
    // Reference Track Analysis
    //==========================================================================

    /** Analyze reference track and store M/S spectral profile */
    void learnReferenceProfile(const juce::AudioBuffer<float>& referenceBuffer);

    /** Clear learned reference profile */
    void clearReferenceProfile();

    /** Has a reference profile been learned? */
    bool hasReferenceProfile() const { return referenceProfileLearned; }

    /** Enable continuous learning (averages multiple references) */
    void setLearningMode(bool enable) { continuousLearning = enable; }

    /** Get number of reference analyses averaged */
    int getLearningCount() const { return learningCount; }

    //==========================================================================
    // Matching Parameters
    //==========================================================================

    /** Set matching strength (0.0 = bypass, 1.0 = full match) */
    void setMatchingStrength(float strength);

    /** Set mid channel matching amount (0.0 to 1.0) */
    void setMidMatchingAmount(float amount);

    /** Set side channel matching amount (0.0 to 1.0) */
    void setSideMatchingAmount(float amount);

    /** Set matching mode (frequency range) */
    void setMatchingMode(MatchingMode mode);

    /** Set custom frequency range for Custom mode (Hz) */
    void setCustomFrequencyRange(float lowFreq, float highFreq);

    /** Set smoothing amount (0.0 = instant, 1.0 = very smooth) */
    void setSmoothingAmount(float amount);

    /** Enable automatic resonance cleanup */
    void setResonanceCleanup(bool enable) { resonanceCleanupEnabled = enable; }

    //==========================================================================
    // Bio-Reactive Integration
    //==========================================================================

    /** Set bio-reactive modulation (HRV controls matching strength) */
    void setBioReactiveEnabled(bool enable) { bioReactiveEnabled = enable; }

    /** Update bio-data for reactive processing */
    void updateBioData(float hrvNormalized, float coherence, float stressLevel);

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
    // Analysis & Metering
    //==========================================================================

    /** Get current mid channel spectral difference (0.0 to 1.0) */
    float getMidSpectralDifference() const { return midSpectralDiff; }

    /** Get current side channel spectral difference (0.0 to 1.0) */
    float getSideSpectralDifference() const { return sideSpectralDiff; }

    /** Get overall matching accuracy (0.0 to 1.0, higher = better match) */
    float getMatchingAccuracy() const { return matchingAccuracy; }

    /** Get number of frequency bands */
    int getNumBands() const { return NUM_BANDS; }

    /** Get mid channel EQ curve (for visualization) */
    const std::vector<float>& getMidEQCurve() const { return midEQCurve; }

    /** Get side channel EQ curve (for visualization) */
    const std::vector<float>& getSideEQCurve() const { return sideEQCurve; }

private:
    //==========================================================================
    // Constants
    //==========================================================================

    static constexpr int FFT_ORDER = 11;            // 2048 samples
    static constexpr int FFT_SIZE = 1 << FFT_ORDER;  // 2048
    static constexpr int NUM_BANDS = 32;             // EQ bands per channel
    static constexpr int HOP_SIZE = FFT_SIZE / 4;    // 75% overlap

    //==========================================================================
    // Parameters
    //==========================================================================

    float matchingStrength = 0.7f;        // Overall matching strength
    float midMatchingAmount = 1.0f;       // Mid channel amount
    float sideMatchingAmount = 1.0f;      // Side channel amount
    float smoothingAmount = 0.5f;         // EQ curve smoothing

    MatchingMode currentMode = MatchingMode::FullSpectrum;
    float customLowFreq = 20.0f;
    float customHighFreq = 20000.0f;

    bool resonanceCleanupEnabled = true;
    bool continuousLearning = false;

    // Bio-reactive
    bool bioReactiveEnabled = false;
    float currentHRV = 0.5f;
    float currentCoherence = 0.5f;
    float currentStress = 0.0f;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // Reference Profile Storage
    //==========================================================================

    bool referenceProfileLearned = false;
    int learningCount = 0;

    std::vector<float> referenceMidSpectrum;      // 32 bands
    std::vector<float> referenceSideSpectrum;     // 32 bands

    //==========================================================================
    // FFT Analysis
    //==========================================================================

    juce::dsp::FFT fftProcessor { FFT_ORDER };
    juce::dsp::WindowingFunction<float> window { FFT_SIZE, juce::dsp::WindowingFunction<float>::hann };

    std::vector<float> fftDataMid;
    std::vector<float> fftDataSide;
    std::vector<float> fftBufferMid;
    std::vector<float> fftBufferSide;

    int fftInputPos = 0;
    bool fftReady = false;

    //==========================================================================
    // EQ Matching
    //==========================================================================

    std::vector<float> midEQCurve;         // Current mid EQ (32 bands)
    std::vector<float> sideEQCurve;        // Current side EQ (32 bands)
    std::vector<float> targetMidEQ;        // Target mid EQ (32 bands)
    std::vector<float> targetSideEQ;       // Target side EQ (32 bands)

    // Smoothing filters for EQ curves
    std::vector<float> midEQSmoothState;
    std::vector<float> sideEQSmoothState;

    //==========================================================================
    // Metering
    //==========================================================================

    float midSpectralDiff = 0.0f;
    float sideSpectralDiff = 0.0f;
    float matchingAccuracy = 0.0f;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    /** Analyze audio and extract M/S spectral profile */
    void analyzeSpectrum(const juce::AudioBuffer<float>& buffer,
                        std::vector<float>& midSpectrum,
                        std::vector<float>& sideSpectrum);

    /** Convert FFT bins to frequency bands (mel-scale inspired) */
    void binsToBands(const std::vector<float>& fftData, std::vector<float>& bands);

    /** Calculate target EQ curves from reference and current spectra */
    void calculateTargetEQ(const std::vector<float>& currentSpectrum,
                          const std::vector<float>& referenceSpectrum,
                          std::vector<float>& targetEQ);

    /** Apply EQ curve to audio using multiband processing */
    void applyEQCurve(juce::AudioBuffer<float>& buffer,
                     const std::vector<float>& eqCurve,
                     bool isMidChannel);

    /** Get frequency for band index */
    float getBandFrequency(int bandIndex) const;

    /** Get band index for frequency */
    int getFrequencyBand(float frequency) const;

    /** Apply bio-reactive modulation to parameters */
    void applyBioReactiveModulation();

    /** Update metering values */
    void updateMetering();

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (MidSideToneMatching)
};
