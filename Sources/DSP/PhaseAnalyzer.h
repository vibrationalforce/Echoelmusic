#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <deque>
#include <map>

/**
 * PhaseAnalyzer - Multi-Track Phase Correlation Analysis
 *
 * Professional phase analysis tool for:
 * - L/R stereo phase correlation (-1.0 to +1.0)
 * - Multi-track phase relationships
 * - Goniometer (L/R vector scope)
 * - Per-frequency phase analysis
 * - Mono compatibility warnings
 * - Phase issue detection and auto-fix suggestions
 *
 * Inspired by: iZotope Insight, Waves PAZ Analyzer, Plugin Alliance bx_solo
 */
class PhaseAnalyzer
{
public:
    PhaseAnalyzer();
    ~PhaseAnalyzer();

    //==============================================================================
    // Processing

    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void reset();

    void process(const juce::AudioBuffer<float>& buffer);

    //==============================================================================
    // Stereo Phase Correlation

    struct PhaseCorrelation
    {
        float instant;           // Instant correlation (-1.0 to +1.0)
        float shortTerm;         // Short-term average (100ms)
        float longTerm;          // Long-term average (3s)
        float minimum;           // Minimum detected
        float maximum;           // Maximum detected

        bool monoCompatible;     // True if correlation > 0.7
        bool hasPhaseIssues;     // True if correlation < 0.0
    };

    PhaseCorrelation getPhaseCorrelation() const;

    //==============================================================================
    // Goniometer (Vector Scope)

    struct GoniometerPoint
    {
        float mid;               // Mid (L+R) component
        float side;              // Side (L-R) component
        float magnitude;         // Distance from center
        float angle;             // Angle in radians
    };

    std::vector<GoniometerPoint> getGoniometerData(int maxPoints = 512) const;
    void clearGoniometerHistory();

    //==============================================================================
    // Per-Frequency Phase Analysis

    struct FrequencyPhase
    {
        float frequency;         // Center frequency (Hz)
        float correlation;       // Phase correlation at this frequency
        float leftMagnitude;     // Left channel magnitude
        float rightMagnitude;    // Right channel magnitude
        float phaseDifference;   // Phase difference in degrees (0-180°)

        enum class Status
        {
            Good,                // In phase (< 30°)
            Warning,             // Slightly out of phase (30-90°)
            Problem              // Severely out of phase (> 90°)
        };
        Status status;
    };

    std::vector<FrequencyPhase> getFrequencyPhaseAnalysis() const;

    //==============================================================================
    // Phase Issue Detection

    struct PhaseIssue
    {
        std::string description;     // "Low-frequency phase cancellation"
        std::string location;        // "Below 200Hz"
        float severity;              // 0.0 to 1.0
        std::string suggestion;      // "Apply mid/side EQ to correct"
        std::string technicalDetails;// "Left and right are 180° out of phase at 150Hz"
    };

    std::vector<PhaseIssue> detectPhaseIssues() const;

    //==============================================================================
    // Mono Compatibility

    struct MonoCompatibility
    {
        float overallScore;          // 0.0 to 1.0 (1.0 = perfect mono compatibility)
        float lowFreqScore;          // 0.0 to 1.0 (< 250Hz)
        float midFreqScore;          // 0.0 to 1.0 (250Hz - 2kHz)
        float highFreqScore;         // 0.0 to 1.0 (> 2kHz)

        bool passesRadioTest;        // Would sound good on mono radio/phone
        std::vector<std::string> warnings;  // List of mono compatibility warnings
    };

    MonoCompatibility getMonoCompatibility() const;

    //==============================================================================
    // Auto-Fix Suggestions

    struct FixSuggestion
    {
        std::string type;            // "Flip polarity", "Mid/Side EQ", "Phase rotation"
        std::string description;     // Human-readable explanation
        float expectedImprovement;   // 0.0 to 1.0 (how much it will help)
        bool autoApply;              // Can be automatically applied

        // Parameters for auto-apply
        std::map<std::string, float> parameters;
    };

    std::vector<FixSuggestion> getAutoFixSuggestions() const;

    //==============================================================================
    // Settings

    void setCorrelationMeterSpeed(float speed);     // 0.0 to 1.0 (slow to fast)
    void setGoniometerPersistence(float seconds);   // How long points stay visible
    void setFrequencyResolution(int bands);         // 12, 24, or 48 bands

    void setMonoCompatibilityThreshold(float threshold); // 0.0 to 1.0

    //==============================================================================
    // Visualization Data

    struct CorrelationHistory
    {
        std::deque<float> values;    // Historical correlation values (deque for O(1) pop_front)
        int maxSize;                  // Maximum history size
        double timePerSample;         // Time between samples (for X-axis)
    };

    CorrelationHistory getCorrelationHistory() const;

private:
    //==============================================================================
    // DSP State

    double currentSampleRate = 48000.0;
    int currentNumChannels = 2;

    // Phase correlation calculation
    float instantCorrelation = 1.0f;
    float shortTermCorrelation = 1.0f;
    float longTermCorrelation = 1.0f;
    float minCorrelation = 1.0f;
    float maxCorrelation = 1.0f;

    // Correlation meter smoothing
    float correlationMeterSpeed = 0.5f;
    float correlationAlpha = 0.1f;  // Smoothing coefficient

    // Goniometer (deque for O(1) pop_front)
    std::deque<GoniometerPoint> goniometerHistory;
    float goniometerPersistence = 2.0f;  // Seconds
    int maxGoniometerPoints = 2048;

    // FFT for per-frequency analysis
    static constexpr int fftOrder = 12;              // 4096 samples
    static constexpr int fftSize = 1 << fftOrder;
    juce::dsp::FFT forwardFFT;
    juce::dsp::WindowingFunction<float> window;

    std::array<float, fftSize * 2> leftFFTData;
    std::array<float, fftSize * 2> rightFFTData;
    std::array<float, fftSize> leftMagnitudes;
    std::array<float, fftSize> rightMagnitudes;

    // Frequency-domain phase analysis
    int frequencyResolution = 24;
    std::vector<FrequencyPhase> frequencyPhaseData;

    // Phase issues
    std::vector<PhaseIssue> detectedIssues;

    // Mono compatibility
    float monoCompatibilityThreshold = 0.7f;
    MonoCompatibility monoCompat;

    // History
    CorrelationHistory correlationHistory;

    //==============================================================================
    // Internal Analysis

    void calculatePhaseCorrelation(const juce::AudioBuffer<float>& buffer);
    void updateGoniometer(const juce::AudioBuffer<float>& buffer);
    void performFFTAnalysis(const juce::AudioBuffer<float>& buffer);
    void analyzeFrequencyPhase();
    void detectIssues();
    void calculateMonoCompatibility();

    float calculateCorrelationCoefficient(const float* left, const float* right, int numSamples);
    float calculatePhaseDifference(std::complex<float> leftSpectrum, std::complex<float> rightSpectrum);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PhaseAnalyzer)
};
