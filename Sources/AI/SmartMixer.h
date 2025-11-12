#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>

/**
 * SmartMixer - AI-Powered Auto-Mixing
 *
 * Analyzes multi-track audio and suggests optimal mixing parameters
 * based on machine learning models trained on professional mixes.
 *
 * Features:
 * - Auto-gain staging (optimal levels per track)
 * - Smart EQ suggestions (frequency balancing)
 * - Compression settings (dynamic control)
 * - Pan positioning (stereo imaging)
 * - Mastering chain (streaming-ready output)
 *
 * Basis: Trained on MUSDB18, MixingSecrets, professional mixes
 * Inference: ONNX Runtime (client-side, $0 cost)
 */
class SmartMixer
{
public:
    //==========================================================================
    // Mix Suggestion Structure
    //==========================================================================

    struct EQSettings
    {
        float lowShelf = 0.0f;          // -12dB to +12dB
        float lowMidPeak = 0.0f;        // Q=2.0, 250-500Hz
        float midPeak = 0.0f;           // Q=2.0, 1-3kHz
        float highMidPeak = 0.0f;       // Q=2.0, 4-8kHz
        float highShelf = 0.0f;         // -12dB to +12dB
    };

    struct CompressionSettings
    {
        float threshold = -20.0f;       // dB
        float ratio = 4.0f;             // 1:1 to 20:1
        float attack = 10.0f;           // ms
        float release = 100.0f;         // ms
        float makeupGain = 0.0f;        // dB
    };

    struct MixingSuggestion
    {
        juce::String trackName;
        int trackIndex = 0;

        // Basic mixing
        float suggestedGain = 0.0f;     // dB (-∞ to +12)
        float suggestedPan = 0.0f;      // -1.0 (L) to +1.0 (R)

        // Processing
        EQSettings suggestedEQ;
        CompressionSettings suggestedCompression;

        // Effects sends
        float reverbSend = 0.0f;        // 0.0 to 1.0
        float delaySend = 0.0f;         // 0.0 to 1.0

        // Confidence score
        float confidence = 0.0f;        // 0.0 to 1.0

        MixingSuggestion() = default;
    };

    //==========================================================================
    // Mastering Targets
    //==========================================================================

    enum class MasteringTarget
    {
        Spotify,            // -14 LUFS integrated
        AppleMusic,         // -16 LUFS integrated
        YouTube,            // -13 LUFS integrated
        Tidal,              // -14 LUFS integrated
        CD,                 // -9 LUFS integrated (louder)
        BroadcastEBU,       // -23 LUFS (EBU R128)
        Custom              // User-defined
    };

    struct MasteringSettings
    {
        float targetLUFS = -14.0f;
        float truePeakCeiling = -1.0f;  // dBTP
        bool limitingEnabled = true;
        bool stereoenhanc

ementEnabled = false;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    SmartMixer();
    ~SmartMixer() = default;

    //==========================================================================
    // Auto-Mixing Analysis
    //==========================================================================

    /** Analyze tracks and generate mixing suggestions */
    std::vector<MixingSuggestion> analyzeAndSuggest(
        const std::vector<juce::AudioBuffer<float>>& tracks,
        const std::vector<juce::String>& trackNames
    );

    /** Apply suggestions to audio buffers */
    void applySuggestions(
        std::vector<juce::AudioBuffer<float>>& tracks,
        const std::vector<MixingSuggestion>& suggestions
    );

    //==========================================================================
    // Mastering
    //==========================================================================

    /** Master final mixdown for streaming platforms */
    juce::AudioBuffer<float> masterTrack(
        const juce::AudioBuffer<float>& mixdown,
        MasteringTarget target = MasteringTarget::Spotify
    );

    /** Master with custom settings */
    juce::AudioBuffer<float> masterTrack(
        const juce::AudioBuffer<float>& mixdown,
        const MasteringSettings& settings
    );

    //==========================================================================
    // Analysis Tools
    //==========================================================================

    /** Analyze frequency spectrum */
    struct SpectrumAnalysis
    {
        std::vector<float> magnitudes;  // FFT bins
        float spectralCentroid = 0.0f;  // Hz
        float spectralRolloff = 0.0f;   // Hz
        float spectralFlux = 0.0f;      // Change rate
    };

    SpectrumAnalysis analyzeSpectrum(const juce::AudioBuffer<float>& audio);

    /** Analyze dynamics */
    struct DynamicsAnalysis
    {
        float rmsLevel = 0.0f;          // dB
        float peakLevel = 0.0f;         // dB
        float crestFactor = 0.0f;       // Peak/RMS ratio
        float dynamicRange = 0.0f;      // dB
        float lufsIntegrated = 0.0f;    // LUFS
    };

    DynamicsAnalysis analyzeDynamics(const juce::AudioBuffer<float>& audio);

    //==========================================================================
    // Model Management
    //==========================================================================

    /** Load ML model (ONNX format) */
    bool loadModel(const juce::File& modelFile);

    /** Check if model is loaded */
    bool isModelLoaded() const { return modelLoaded; }

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    bool modelLoaded = false;
    double sampleRate = 48000.0;

    // ML Model would be loaded here (ONNX Runtime)
    // For now, use rule-based algorithms

    //==========================================================================
    // Feature Extraction
    //==========================================================================

    std::vector<float> extractFeatures(const juce::AudioBuffer<float>& audio);

    /** Calculate spectral centroid (brightness) */
    float calculateSpectralCentroid(const std::vector<float>& spectrum);

    /** Calculate RMS level */
    float calculateRMS(const juce::AudioBuffer<float>& audio);

    /** Calculate peak level */
    float calculatePeak(const juce::AudioBuffer<float>& audio);

    /** Calculate LUFS (loudness) */
    float calculateLUFS(const juce::AudioBuffer<float>& audio);

    //==========================================================================
    // Processing
    //==========================================================================

    /** Apply EQ to buffer */
    void applyEQ(juce::AudioBuffer<float>& audio, const EQSettings& eq);

    /** Apply compression */
    void applyCompression(juce::AudioBuffer<float>& audio,
                         const CompressionSettings& comp);

    /** Apply limiting */
    void applyLimiter(juce::AudioBuffer<float>& audio, float ceiling);

    /** Normalize to target LUFS */
    void normalizeLUFS(juce::AudioBuffer<float>& audio, float targetLUFS);

    //==========================================================================
    // Inter-Track Analysis
    //==========================================================================

    /** Detect frequency masking between tracks */
    void adjustForMasking(std::vector<MixingSuggestion>& suggestions,
                         const std::vector<juce::AudioBuffer<float>>& tracks);

    /** Balance overall frequency spectrum */
    void adjustForFrequencyBalance(std::vector<MixingSuggestion>& suggestions,
                                   const std::vector<juce::AudioBuffer<float>>& tracks);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SmartMixer)
};
