#pragma once

#include "HybridSampleAnalyzer.h"
#include "ProducerStyleProcessor.h"
#include <JuceHeader.h>
#include <vector>
#include <map>

//==============================================================================
// Helper Functions
//==============================================================================

inline juce::String getProducerStyleName(ProducerStyleProcessor::ProducerStyle style)
{
    using PS = ProducerStyleProcessor::ProducerStyle;

    switch (style)
    {
        case PS::Mafia808:          return "808 Mafia";
        case PS::MetroBoomin:       return "Metro Boomin";
        case PS::Pyrex:             return "Pyrex Whippa";
        case PS::Gunna:             return "Gunna";
        case PS::Turbo:             return "Turbo";
        case PS::DrDre:             return "Dr. Dre";
        case PS::ScottStorch:       return "Scott Storch";
        case PS::Timbaland:         return "Timbaland";
        case PS::Pharrell:          return "Pharrell";
        case PS::RickRubin:         return "Rick Rubin";
        case PS::Pushkarev:         return "Andrey Pushkarev";
        case PS::Lawrence:          return "Lawrence";
        case PS::PanthaDuPrince:    return "Pantha du Prince";
        case PS::NilsFrahm:         return "Nils Frahm";
        case PS::AphexTwin:         return "Aphex Twin";
        case PS::GeneralLevy:       return "General Levy";
        case PS::Skream:            return "Skream";
        case PS::EchoelSignature:   return "Echoelmusic Signature";
        default:                    return "Unknown";
    }
}

/**
 * HYBRID PRODUCER-STYLE INTEGRATION
 *
 * Kombiniert die drei innovativen Systeme:
 * 1. Sample Analysis (HybridSampleAnalyzer)
 * 2. Producer-Style Processing (ProducerStyleProcessor)
 * 3. Synthesis Model Creation
 *
 * WORKFLOW:
 * 1. Download 1.2GB Sample Library from Google Drive
 * 2. Analyze all samples (spectral, envelope, timbre)
 * 3. Apply Producer-Style Processing (808 Mafia, Metro Boomin, Dr. Dre)
 * 4. Create Synthesis Models from processed samples
 * 5. Add Analog Behavior (Tape, Tube, Vintage)
 * 6. Select BEST samples (quality-based selection)
 * 7. Export optimized library (< 100MB)
 *
 * RESULT:
 * - 1.2GB → < 100MB (99.2% reduction!)
 * - Producer-style processing baked in
 * - Analog behavior modeling
 * - Best samples only
 * - Fully parametric
 * - Infinite variations
 *
 * Usage:
 * ```cpp
 * HybridProducerStyleIntegration integration;
 * integration.initialize(44100.0);
 *
 * // Process entire library
 * auto models = integration.processGoogleDriveLibrary(
 *     "/path/to/downloads",
 *     ProducerStyle::Metro_Boomin,
 *     [](int current, int total) {
 *         std::cout << current << "/" << total << std::endl;
 *     }
 * );
 *
 * // Save optimized library
 * integration.saveOptimizedLibrary(models, "/path/to/output");
 * ```
 */

//==============================================================================
// Processing Configuration
//==============================================================================

struct HybridProcessingConfig
{
    // Sample Analysis
    bool enableSpectralAnalysis = true;
    bool enableEnvelopeDetection = true;
    bool enableTimbreAnalysis = true;
    bool enablePitchDetection = true;

    // Producer-Style Processing
    ProducerStyleProcessor::ProducerStyle producerStyle = ProducerStyleProcessor::ProducerStyle::MetroBoomin;
    float processingIntensity = 0.7f;           // 0-1
    bool applyBeforeSynthesis = true;           // Process samples BEFORE creating models

    // Analog Behavior
    AnalogBehavior analogBehavior;
    bool enableAnalogModeling = true;

    // Quality Selection
    int maxSamples = 70;                        // Maximum samples to keep
    float minQualityThreshold = 0.6f;           // Minimum quality (0-1)
    bool diversitySelection = true;             // Select diverse samples

    // Categories to process
    bool processDrums = true;
    bool processBass = true;
    bool processMelodic = true;
    bool processTextures = true;
    bool processFX = true;
    bool processVocals = true;

    // Optimization
    bool compressWavetables = true;             // Reduce wavetable size
    bool removeOriginalSamples = true;          // Don't keep originals
    int wavetableSize = 2048;                   // Wavetable resolution
};

//==============================================================================
// Processing Statistics
//==============================================================================

struct ProcessingStats
{
    int totalSamplesProcessed = 0;
    int samplesKept = 0;
    int samplesRejected = 0;

    size_t originalSizeBytes = 0;
    size_t optimizedSizeBytes = 0;
    float compressionRatio = 0.0f;

    std::map<juce::String, int> samplesByCategory;
    std::map<juce::String, float> avgQualityByCategory;

    float avgAnalysisQuality = 0.0f;
    float avgCompressionRatio = 0.0f;

    juce::String processingTime;
};

//==============================================================================
// Categorized Model Library
//==============================================================================

struct CategorizedModelLibrary
{
    juce::String name;
    juce::String description;
    ProducerStyleProcessor::ProducerStyle producerStyle;

    std::vector<SynthesisModel> drums;
    std::vector<SynthesisModel> bass;
    std::vector<SynthesisModel> melodic;
    std::vector<SynthesisModel> textures;
    std::vector<SynthesisModel> fx;
    std::vector<SynthesisModel> vocals;

    ProcessingStats stats;

    int getTotalCount() const
    {
        return drums.size() + bass.size() + melodic.size() +
               textures.size() + fx.size() + vocals.size();
    }
};

//==============================================================================
// Hybrid Producer-Style Integration
//==============================================================================

class HybridProducerStyleIntegration
{
public:
    HybridProducerStyleIntegration();
    ~HybridProducerStyleIntegration();

    //==============================================================================
    // Initialization
    //==============================================================================

    void initialize(double sampleRate);
    void setConfiguration(const HybridProcessingConfig& config);

    //==============================================================================
    // Google Drive Library Processing
    //==============================================================================

    /** Process entire sample library from Google Drive */
    CategorizedModelLibrary processGoogleDriveLibrary(
        const juce::File& libraryRoot,
        ProducerStyleProcessor::ProducerStyle style = ProducerStyleProcessor::ProducerStyle::MetroBoomin,
        std::function<void(int, int)> progressCallback = nullptr
    );

    /** Process specific category from library */
    std::vector<SynthesisModel> processCategoryFolder(
        const juce::File& categoryFolder,
        const juce::String& categoryName,
        ProducerStyleProcessor::ProducerStyle style,
        std::function<void(int, int)> progressCallback = nullptr
    );

    //==============================================================================
    // Single Sample Processing
    //==============================================================================

    /** Process single sample with producer-style + analysis */
    SynthesisModel processSample(
        const juce::AudioBuffer<float>& sample,
        const juce::String& name,
        ProducerStyleProcessor::ProducerStyle style,
        const juce::String& category = "unknown"
    );

    /** Process audio file */
    SynthesisModel processAudioFile(
        const juce::File& audioFile,
        ProducerStyleProcessor::ProducerStyle style,
        const juce::String& category = ""
    );

    //==============================================================================
    // Producer-Style Application
    //==============================================================================

    /** Apply producer-style processing to audio buffer */
    juce::AudioBuffer<float> applyProducerStyle(
        const juce::AudioBuffer<float>& input,
        ProducerStyleProcessor::ProducerStyle style,
        float intensity = 0.7f
    );

    /** Apply multiple producer styles and blend */
    juce::AudioBuffer<float> applyBlendedStyles(
        const juce::AudioBuffer<float>& input,
        const std::vector<std::pair<ProducerStyleProcessor::ProducerStyle, float>>& stylesWithWeights
    );

    //==============================================================================
    // Quality Selection
    //==============================================================================

    /** Select best samples from library based on quality metrics */
    CategorizedModelLibrary selectBestSamples(
        const CategorizedModelLibrary& library,
        int maxSamplesPerCategory = 15
    );

    /** Select diverse samples (avoid duplicates) */
    std::vector<SynthesisModel> selectDiverseSamples(
        const std::vector<SynthesisModel>& models,
        int targetCount,
        float diversityWeight = 0.5f
    );

    //==============================================================================
    // Library I/O
    //==============================================================================

    /** Save optimized library to directory */
    bool saveOptimizedLibrary(
        const CategorizedModelLibrary& library,
        const juce::File& outputDirectory
    );

    /** Load optimized library from directory */
    CategorizedModelLibrary loadOptimizedLibrary(
        const juce::File& libraryDirectory
    );

    /** Export library statistics report */
    bool exportStatisticsReport(
        const CategorizedModelLibrary& library,
        const juce::File& reportFile
    );

    //==============================================================================
    // Google Drive Integration
    //==============================================================================

    /** Download sample library from Google Drive */
    bool downloadFromGoogleDrive(
        const juce::String& driveURL,
        const juce::File& downloadPath,
        std::function<void(float)> progressCallback = nullptr
    );

    /** Auto-detect sample library structure */
    std::map<juce::String, juce::Array<juce::File>> detectLibraryStructure(
        const juce::File& libraryRoot
    );

    //==============================================================================
    // Utilities
    //==============================================================================

    /** Get processing statistics */
    ProcessingStats getLastProcessingStats() const { return lastStats; }

    /** Get configuration */
    HybridProcessingConfig getConfiguration() const { return config; }

    /** Estimate processing time */
    juce::String estimateProcessingTime(int numSamples) const;

    /** Get supported audio formats */
    juce::StringArray getSupportedFormats() const;

private:
    //==============================================================================
    // Components
    //==============================================================================

    HybridSampleAnalyzer analyzer;
    ProducerStyleProcessor styleProcessor;

    //==============================================================================
    // Configuration
    //==============================================================================

    HybridProcessingConfig config;
    double currentSampleRate = 44100.0;

    //==============================================================================
    // Statistics
    //==============================================================================

    ProcessingStats lastStats;

    //==============================================================================
    // Helpers
    //==============================================================================

    /** Categorize sample based on filename/analysis */
    juce::String categorizeSample(
        const juce::String& filename,
        const SynthesisModel& model
    );

    /** Calculate similarity between two models */
    float calculateSimilarity(
        const SynthesisModel& a,
        const SynthesisModel& b
    );

    /** Compute diversity score for sample set */
    float computeDiversityScore(
        const std::vector<SynthesisModel>& models
    );

    /** Update statistics */
    void updateStatistics(
        ProcessingStats& stats,
        const std::vector<SynthesisModel>& models
    );

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(HybridProducerStyleIntegration)
};
