#pragma once

#include <JuceHeader.h>
#include "SpectralFramework.h"
#include "ParametricEQ.h"
#include "Compressor.h"
#include <vector>
#include <array>

/**
 * IntelligentMastering
 *
 * AI-assisted mastering processor inspired by iZotope Ozone.
 * Uses machine learning models and spectral analysis for automatic mastering.
 *
 * Features:
 * - AI-powered reference matching
 * - Automatic EQ curve generation
 * - Intelligent multi-band compression
 * - Stereo imaging enhancement
 * - Harmonic exciter
 * - Brickwall limiter with true peak detection
 * - Target loudness optimization (LUFS)
 * - Genre-aware processing
 * - A/B comparison with reference tracks
 */
class IntelligentMastering
{
public:
    //==========================================================================
    // Processing Mode
    //==========================================================================

    enum class ProcessingMode
    {
        Automatic,      // AI-powered analysis and processing
        Manual,         // User controls all parameters
        Reference       // Match reference track
    };

    enum class Genre
    {
        Pop,
        Rock,
        HipHop,
        Electronic,
        Jazz,
        Classical,
        Metal,
        Acoustic,
        Custom
    };

    //==========================================================================
    // Mastering Chain Modules
    //==========================================================================

    struct MasteringChain
    {
        bool eqEnabled = true;
        bool compressionEnabled = true;
        bool imagingEnabled = true;
        bool exciterEnabled = true;
        bool limiterEnabled = true;

        // EQ Settings (AI-suggested or manual)
        std::array<float, 8> eqFrequencies = {30.0f, 80.0f, 200.0f, 500.0f, 1000.0f, 3000.0f, 8000.0f, 16000.0f};
        std::array<float, 8> eqGains = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f};
        std::array<float, 8> eqQs = {1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f, 1.0f};

        // Multiband Compression (3 bands: Low, Mid, High)
        struct CompressorBand
        {
            float threshold = -20.0f;  // dB
            float ratio = 3.0f;
            float attack = 10.0f;      // ms
            float release = 100.0f;    // ms
            float makeup = 0.0f;       // dB
        };
        std::array<CompressorBand, 3> compressionBands;

        // Stereo Imaging
        float stereoWidth = 1.0f;      // 0.0 (mono) to 2.0 (wide)
        float lowFreqMono = 120.0f;    // Hz - frequencies below this are mono

        // Harmonic Exciter
        float exciterAmount = 0.0f;    // 0.0 to 1.0
        float exciterFrequency = 3000.0f;  // Hz - frequency above which to add harmonics

        // Limiter
        float limiterThreshold = -1.0f;    // dB
        float limiterRelease = 50.0f;      // ms
        bool truePeakLimiting = true;

        // Target Loudness
        float targetLUFS = -14.0f;     // Integrated loudness target
        bool autoGain = true;          // Automatically adjust gain to hit target
    };

    //==========================================================================
    // Reference Track Analysis
    //==========================================================================

    struct ReferenceAnalysis
    {
        float integratedLUFS = 0.0f;
        float momentaryLUFS = 0.0f;
        float truePeak = 0.0f;
        float stereoWidth = 0.0f;
        float spectralCentroid = 0.0f;
        float spectralBalance = 0.0f;
        std::vector<float> eqCurve;  // Suggested EQ curve to match reference

        bool isValid = false;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    IntelligentMastering();
    ~IntelligentMastering() = default;

    //==========================================================================
    // Processing Mode
    //==========================================================================

    void setProcessingMode(ProcessingMode mode);
    ProcessingMode getProcessingMode() const { return currentMode; }

    void setGenre(Genre genre);
    Genre getGenre() const { return currentGenre; }

    //==========================================================================
    // Mastering Chain
    //==========================================================================

    MasteringChain& getMasteringChain() { return chain; }
    const MasteringChain& getMasteringChain() const { return chain; }

    void setMasteringChain(const MasteringChain& newChain);

    // Quick presets
    void loadPreset(Genre genre);
    void resetToDefault();

    //==========================================================================
    // AI-Powered Processing
    //==========================================================================

    /** Analyze current audio and suggest optimal settings */
    void analyzeSong(const juce::AudioBuffer<float>& entireSong);

    /** Load reference track for matching */
    void loadReference(const juce::AudioBuffer<float>& referenceTrack);

    /** Get reference track analysis */
    ReferenceAnalysis getReferenceAnalysis() const { return referenceAnalysis; }

    /** Apply AI suggestions (after analysis) */
    void applyAISuggestions();

    /** Match reference track spectral balance */
    void matchReference();

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Metering & Analysis
    //==========================================================================

    struct MeteringData
    {
        float inputLUFS = 0.0f;
        float outputLUFS = 0.0f;
        float truePeak = 0.0f;
        float dynamicRange = 0.0f;
        float stereoWidth = 0.0f;
        std::array<float, 3> compressionGR = {0.0f, 0.0f, 0.0f};  // Gain reduction per band
        float limiterGR = 0.0f;
    };

    MeteringData getMeteringData() const { return meteringData; }

    /** Get spectral data for visualization */
    std::vector<float> getSpectrumData() const;

    /** Get suggested EQ curve (AI-generated) */
    std::vector<float> getSuggestedEQCurve() const { return suggestedEQCurve; }

private:
    //==========================================================================
    // Processing Modules
    //==========================================================================

    SpectralFramework spectralEngine;
    std::unique_ptr<ParametricEQ> masterEQ;
    std::array<std::unique_ptr<Compressor>, 3> multibandCompressors;  // Low, Mid, High

    //==========================================================================
    // State
    //==========================================================================

    ProcessingMode currentMode = ProcessingMode::Automatic;
    Genre currentGenre = Genre::Electronic;
    MasteringChain chain;

    double currentSampleRate = 48000.0;
    int currentBlockSize = 512;

    //==========================================================================
    // AI Analysis
    //==========================================================================

    ReferenceAnalysis referenceAnalysis;
    std::vector<float> suggestedEQCurve;
    std::vector<float> songSpectrum;  // Averaged spectrum of entire song

    bool songAnalyzed = false;
    bool referenceLoaded = false;

    //==========================================================================
    // Metering
    //==========================================================================

    MeteringData meteringData;

    // LUFS metering
    struct LUFSMeter
    {
        std::vector<float> momentaryBuffer;
        float integratedLoudness = 0.0f;
        float momentaryLoudness = 0.0f;
        int sampleCount = 0;
    };
    LUFSMeter lufsInput, lufsOutput;

    //==========================================================================
    // Internal Buffers
    //==========================================================================

    juce::AudioBuffer<float> dryBuffer;
    juce::AudioBuffer<float> multibandBuffers[3];  // Low, Mid, High
    juce::AudioBuffer<float> tempBuffer;

    //==========================================================================
    // Crossover Filters (for multiband)
    //==========================================================================

    static constexpr float lowMidCrossover = 250.0f;   // Hz
    static constexpr float midHighCrossover = 2500.0f; // Hz

    struct CrossoverFilters
    {
        juce::dsp::LinkwitzRileyFilter<float> lowpassL, lowpassR;
        juce::dsp::LinkwitzRileyFilter<float> bandpassL, bandpassR;
        juce::dsp::LinkwitzRileyFilter<float> highpassL, highpassR;
    };
    CrossoverFilters crossover;

    //==========================================================================
    // Internal Processing Methods
    //==========================================================================

    void processEQ(juce::AudioBuffer<float>& buffer);
    void processMultibandCompression(juce::AudioBuffer<float>& buffer);
    void processStereoImaging(juce::AudioBuffer<float>& buffer);
    void processHarmonicExciter(juce::AudioBuffer<float>& buffer);
    void processLimiter(juce::AudioBuffer<float>& buffer);

    void splitBands(const juce::AudioBuffer<float>& input,
                    juce::AudioBuffer<float>* outputs);
    void combineBands(const juce::AudioBuffer<float>* inputs,
                      juce::AudioBuffer<float>& output);

    //==========================================================================
    // AI & Analysis Methods
    //==========================================================================

    void analyzeSpectrum(const juce::AudioBuffer<float>& audio,
                         std::vector<float>& spectrum);
    float calculateLUFS(const juce::AudioBuffer<float>& audio);
    float calculateTruePeak(const juce::AudioBuffer<float>& audio);
    float calculateStereoWidth(const juce::AudioBuffer<float>& audio);

    void generateEQSuggestion(const std::vector<float>& targetSpectrum,
                              const std::vector<float>& currentSpectrum);
    void generateCompressionSuggestion(float dynamicRange, Genre genre);

    void updateMetering(const juce::AudioBuffer<float>& input,
                        const juce::AudioBuffer<float>& output);

    //==========================================================================
    // Utility Methods
    //==========================================================================

    void updateCrossoverFilters();
    void applyAutoGain(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (IntelligentMastering)
};
