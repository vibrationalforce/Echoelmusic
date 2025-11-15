#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <string>
#include <map>

/**
 * StyleAwareMastering - Genre-Specific Mastering Chains
 *
 * Intelligent mastering system that adapts to musical genre:
 * - Pre-configured mastering chains for 20+ genres
 * - Genre-aware EQ, compression, limiting
 * - Target loudness standards (LUFS) per genre
 * - Reference track matching
 * - One-click mastering presets
 * - Custom chain building
 *
 * Integrates with WorldMusicDatabase for authentic genre processing.
 *
 * Inspired by: iZotope Ozone, Lurssen Mastering Console, LANDR
 */
class StyleAwareMastering
{
public:
    StyleAwareMastering();
    ~StyleAwareMastering();

    //==============================================================================
    // Processing

    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void reset();

    void process(juce::AudioBuffer<float>& buffer);

    //==============================================================================
    // Genre Selection

    enum class Genre
    {
        Pop,
        Rock,
        Electronic,
        HipHop,
        RnB,
        Jazz,
        Classical,
        Country,
        Metal,
        Indie,
        Ambient,
        Dubstep,
        House,
        Techno,
        DrumAndBass,
        Reggae,
        Latin,
        World,
        Soundtrack,
        Podcast,
        Custom
    };

    void setGenre(Genre genre);
    Genre getGenre() const;

    //==============================================================================
    // Mastering Chain

    struct ChainModule
    {
        enum class Type
        {
            EQ,
            Compression,
            Limiting,
            StereoWidening,
            Saturation,
            DeEssing
        };

        Type type;
        std::string name;
        bool enabled;
        std::map<std::string, float> parameters;
    };

    std::vector<ChainModule> getMasteringChain() const;
    void setMasteringChain(const std::vector<ChainModule>& chain);

    //==============================================================================
    // Genre-Specific Targets

    struct GenreTargets
    {
        float targetLUFS;            // Integrated loudness (-23 to -6 LUFS)
        float targetLRA;             // Loudness range (3 to 15 LU)
        float targetPeak;            // True peak ceiling (-0.1 to -1.0 dB)

        std::string tonalBalance;    // "Bright", "Warm", "Balanced", etc.
        std::string dynamicRange;    // "Compressed", "Natural", "Dynamic"
        std::string stereoWidth;     // "Narrow", "Natural", "Wide"
    };

    GenreTargets getGenreTargets() const;
    void setCustomTargets(const GenreTargets& targets);

    //==============================================================================
    // Analysis & Matching

    struct CurrentMetrics
    {
        float integratedLUFS;
        float shortTermLUFS;
        float loudnessRange;
        float truePeakL;
        float truePeakR;
        float stereoWidth;           // 0.0 to 1.0

        float distanceFromTarget;    // How far from genre targets (0.0 = perfect)
    };

    CurrentMetrics analyzeCurrentState() const;

    //==============================================================================
    // Reference Matching

    void setReferenceTrack(const juce::AudioBuffer<float>& reference);
    void clearReferenceTrack();

    struct ReferenceAnalysis
    {
        float referenceLUFS;
        float referenceLRA;
        float referencePeak;
        std::string estimatedGenre;
        std::vector<std::string> matchSuggestions;  // What to adjust
    };

    ReferenceAnalysis getReferenceAnalysis() const;

    //==============================================================================
    // Auto-Mastering

    enum class MasteringIntensity
    {
        Subtle,      // Light touch, preserve dynamics
        Moderate,    // Standard mastering
        Aggressive,  // Loud, competitive loudness
        Extreme      // Maximum loudness (brick-walled)
    };

    void setMasteringIntensity(MasteringIntensity intensity);
    void enableAutoMastering(bool enable);
    bool isAutoMasteringEnabled() const;

    //==============================================================================
    // Processing Modules

    // EQ
    struct EQSettings
    {
        float lowShelfGain;          // -6 to +6 dB
        float lowShelfFreq;          // 60-200 Hz
        float midBoostGain;          // -3 to +3 dB
        float midBoostFreq;          // 1-4 kHz
        float highShelfGain;         // -6 to +6 dB
        float highShelfFreq;         // 8-16 kHz
    };

    void setEQSettings(const EQSettings& settings);
    EQSettings getEQSettings() const;

    // Compression
    struct CompressionSettings
    {
        float threshold;             // -30 to 0 dB
        float ratio;                 // 1.0 to 10.0
        float attack;                // 1 to 100 ms
        float release;               // 50 to 500 ms
        float knee;                  // 0 to 12 dB
        float makeupGain;            // 0 to 12 dB
    };

    void setCompressionSettings(const CompressionSettings& settings);
    CompressionSettings getCompressionSettings() const;

    // Limiting
    struct LimiterSettings
    {
        float ceiling;               // -0.1 to -1.0 dB (true peak)
        float release;               // 10 to 500 ms
        bool ispDetection;           // Inter-sample peak detection
    };

    void setLimiterSettings(const LimiterSettings& settings);
    LimiterSettings getLimiterSettings() const;

    //==============================================================================
    // Presets

    struct Preset
    {
        std::string name;
        Genre genre;
        GenreTargets targets;
        std::vector<ChainModule> chain;
        EQSettings eq;
        CompressionSettings compression;
        LimiterSettings limiter;
    };

    void loadPreset(const std::string& presetName);
    std::vector<std::string> getAvailablePresets() const;

    //==============================================================================
    // Export

    struct MasteringReport
    {
        std::string genre;
        CurrentMetrics before;
        CurrentMetrics after;
        std::vector<std::string> appliedProcessing;
        std::string recommendations;
    };

    MasteringReport generateReport() const;

private:
    //==============================================================================
    // DSP State

    double currentSampleRate = 48000.0;
    int currentNumChannels = 2;

    // Current settings
    Genre currentGenre = Genre::Pop;
    MasteringIntensity intensity = MasteringIntensity::Moderate;
    bool autoMasteringEnabled = false;

    // Mastering chain
    std::vector<ChainModule> masteringChain;

    // Genre targets
    GenreTargets genreTargets;
    GenreTargets customTargets;

    // Module settings
    EQSettings eqSettings;
    CompressionSettings compressionSettings;
    LimiterSettings limiterSettings;

    // Reference track
    juce::AudioBuffer<float> referenceTrack;
    bool hasReferenceTrack = false;
    ReferenceAnalysis referenceAnalysis;

    // Metrics
    CurrentMetrics currentMetrics;
    CurrentMetrics beforeMetrics;

    // Presets database
    std::map<std::string, Preset> presetDatabase;

    //==============================================================================
    // Internal Processing

    void loadGenreDefaults(Genre genre);
    void initializePresets();

    void processEQ(juce::AudioBuffer<float>& buffer);
    void processCompression(juce::AudioBuffer<float>& buffer);
    void processLimiter(juce::AudioBuffer<float>& buffer);

    void analyzeMetrics(const juce::AudioBuffer<float>& buffer);
    void autoAdjustParameters();

    //==============================================================================
    // Filters (simplified)

    struct BiquadFilter
    {
        float b0, b1, b2, a1, a2;
        float z1L = 0.0f, z2L = 0.0f;
        float z1R = 0.0f, z2R = 0.0f;

        void setLowShelf(float frequency, float gain, float sampleRate);
        void setHighShelf(float frequency, float gain, float sampleRate);
        void setPeak(float frequency, float gain, float Q, float sampleRate);

        float processSample(float input, bool isLeftChannel);
    };

    BiquadFilter lowShelfFilter;
    BiquadFilter highShelfFilter;
    BiquadFilter midPeakFilter;

    //==============================================================================
    // Compression/Limiting

    struct CompressorState
    {
        float envelope = 0.0f;
        float gain = 1.0f;
    };

    CompressorState compressorL, compressorR;

    float processCompressorSample(float input, CompressorState& state, const CompressionSettings& settings);
    float processLimiterSample(float input, float& envelope, const LimiterSettings& settings);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(StyleAwareMastering)
};
