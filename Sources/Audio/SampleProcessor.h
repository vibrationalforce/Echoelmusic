#pragma once

#include <JuceHeader.h>
#include <functional>
#include <memory>

/**
 * SampleProcessor - Intelligent Sample Transformation Engine
 *
 * Transforms raw samples into unique "Echoelmusic Signature" sounds.
 *
 * Features:
 * - Automatic transformation (pitch, time, FX)
 * - Signature sound presets (Dark, Bright, Vintage, Glitchy)
 * - Batch processing (entire folders)
 * - Legal safety (transformative processing)
 * - Phone import integration
 * - Multi-layer generation (velocity layers from single sample)
 * - Randomization (unique variations)
 *
 * Use Cases:
 * - Import phone samples → Transform → Categorize → Ready!
 * - Make samples unrecognizable (copyright safety)
 * - Create consistent "Echoelmusic Sound"
 * - Generate velocity layers automatically
 * - Batch process 1000s of samples
 *
 * Inspiration:
 * - Output Arcade (transformed loops)
 * - Splice (sample library)
 * - iZotope RX (audio repair)
 * - Echoelmusic Intelligence = All combined!
 */
class SampleProcessor
{
public:
    //==========================================================================
    // Transformation Preset
    //==========================================================================

    enum class TransformPreset
    {
        // Echoelmusic Signature Sounds
        DarkDeep,           // Pitch down, reverb, saturation (dark techno)
        BrightCrispy,       // Pitch up, EQ boost, compression (modern house)
        VintageWarm,        // Tape saturation, bit crush, vinyl (lo-fi)
        GlitchyModern,      // Stutter, grain, modulation (experimental)
        SubBass,            // Extreme low-pass, sub boost (bass heavy)
        AiryEthereal,       // High-pass, reverb, chorus (ambient)
        AggressivePunchy,   // Transient boost, distortion (hard techno)
        RetroVaporwave,     // Pitch shift, chorus, delay (vaporwave)

        // Random variations
        RandomLight,        // Subtle changes (10-30% variation)
        RandomMedium,       // Moderate changes (30-60% variation)
        RandomHeavy,        // Extreme changes (60-100% variation)

        // Custom
        Custom              // User-defined settings
    };

    //==========================================================================
    // Processing Settings
    //==========================================================================

    struct ProcessingSettings
    {
        TransformPreset preset = TransformPreset::RandomMedium;

        // Pitch & Time
        float pitchShiftSemitones = 0.0f;    // -24 to +24
        float timeStretchRatio = 1.0f;       // 0.5 to 2.0
        bool maintainFormants = true;        // Keep vocal character

        // Filtering
        float lowPassCutoff = 20000.0f;      // Hz
        float highPassCutoff = 20.0f;        // Hz
        float resonance = 0.0f;              // 0.0 to 1.0

        // Dynamics
        float compression = 0.0f;            // 0.0 to 1.0
        float saturation = 0.0f;             // 0.0 to 1.0
        float normalize = true;              // Peak normalize

        // Spatial
        float reverb = 0.0f;                 // 0.0 to 1.0 (wet mix)
        float delay = 0.0f;                  // 0.0 to 1.0 (wet mix)
        float stereoWidth = 1.0f;            // 0.0 to 2.0

        // Character
        float bitCrush = 0.0f;               // 0.0 to 1.0 (bit reduction)
        float vinylNoise = 0.0f;             // 0.0 to 1.0
        float tapeSaturation = 0.0f;         // 0.0 to 1.0

        // Modulation
        float chorus = 0.0f;                 // 0.0 to 1.0
        float phaser = 0.0f;                 // 0.0 to 1.0
        float tremolo = 0.0f;                // 0.0 to 1.0

        // Glitch
        float stutter = 0.0f;                // 0.0 to 1.0
        float granular = 0.0f;               // 0.0 to 1.0
        float reverse = 0.0f;                // 0.0 to 1.0 (mix with forward)

        // Randomization
        float randomizationAmount = 0.5f;    // How much to randomize
        int randomSeed = 0;                  // For reproducibility

        // Silence Trimming (SAVE DISK SPACE!)
        bool trimSilence = true;             // Remove silence from start/end
        float silenceThreshold = -60.0f;     // dB threshold for silence detection
        int microFadeSamples = 64;           // Micro-fade length to prevent clicks (64 samples = ~1.5ms @ 44.1kHz)

        static ProcessingSettings fromPreset(TransformPreset preset);
    };

    //==========================================================================
    // Batch Processing Job
    //==========================================================================

    struct BatchJob
    {
        juce::Array<juce::File> inputFiles;
        juce::File outputDirectory;
        ProcessingSettings settings;

        bool generateVelocityLayers = false; // Create 3-4 variations
        bool autoCategory = true;            // Auto-categorize output
        bool preserveOriginal = true;        // Keep original file

        juce::String outputPrefix = "Echo_"; // Filename prefix
        juce::String outputSuffix = "";      // Filename suffix
    };

    //==========================================================================
    // Processing Result
    //==========================================================================

    struct ProcessingResult
    {
        bool success = false;
        juce::File outputFile;
        juce::String category;               // Auto-detected category
        juce::String subcategory;
        juce::Array<juce::String> tags;

        // Analysis
        double originalBPM = 0.0;
        double processedBPM = 0.0;
        juce::String originalKey;
        juce::String processedKey;

        juce::String errorMessage;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    SampleProcessor();
    ~SampleProcessor();

    //==========================================================================
    // Single Sample Processing
    //==========================================================================

    /** Process single sample */
    ProcessingResult processSample(const juce::File& inputFile,
                                   const juce::File& outputFile,
                                   const ProcessingSettings& settings);

    /** Process sample with preset */
    ProcessingResult processSample(const juce::File& inputFile,
                                   const juce::File& outputFile,
                                   TransformPreset preset);

    /** Process in-place (returns processed audio) */
    juce::AudioBuffer<float> processSample(const juce::AudioBuffer<float>& input,
                                          double sampleRate,
                                          const ProcessingSettings& settings);

    //==========================================================================
    // Batch Processing
    //==========================================================================

    /** Process entire folder */
    bool processBatch(const BatchJob& job);

    /** Process phone import folder */
    bool processPhoneImport(const juce::File& phoneFolder,
                           const juce::File& outputFolder,
                           TransformPreset defaultPreset = TransformPreset::RandomMedium);

    /** Cancel batch processing */
    void cancelBatch();

    /** Check if batch is running */
    bool isBatchRunning() const { return batchRunning; }

    /** Get batch progress */
    float getBatchProgress() const { return batchProgress; }

    //==========================================================================
    // Velocity Layer Generation
    //==========================================================================

    /** Generate velocity layers from single sample */
    juce::Array<ProcessingResult> generateVelocityLayers(
        const juce::File& inputFile,
        const juce::File& outputFolder,
        int numLayers = 4);

    //==========================================================================
    // Phone Import
    //==========================================================================

    /** Detect phone connection (USB/Network) */
    juce::Array<juce::File> detectPhoneFolders();

    /** Scan phone folder for audio files */
    juce::Array<juce::File> scanPhoneFolder(const juce::File& folder);

    /** Import from phone with auto-processing */
    bool importFromPhone(const juce::File& phoneFolder,
                        bool autoProcess = true,
                        bool autoOrganize = true);

    //==========================================================================
    // Signature Sound Presets
    //==========================================================================

    /** Get all available presets */
    juce::Array<TransformPreset> getAllPresets() const;

    /** Get preset name */
    static juce::String getPresetName(TransformPreset preset);

    /** Get preset description */
    static juce::String getPresetDescription(TransformPreset preset);

    //==========================================================================
    // Auto-Categorization
    //==========================================================================

    /** Auto-detect sample category */
    juce::String detectCategory(const juce::AudioBuffer<float>& audio,
                               double sampleRate);

    /** Auto-detect subcategory */
    juce::String detectSubcategory(const juce::AudioBuffer<float>& audio,
                                   const juce::String& category);

    /** Generate smart tags */
    juce::StringArray generateTags(const juce::AudioBuffer<float>& audio,
                                   const ProcessingSettings& settings);

    //==========================================================================
    // Creative Naming System
    //==========================================================================

    /** Generate creative, authentic Echoelmusic sample name */
    juce::String generateCreativeName(const juce::File& sourceFile,
                                      const ProcessingSettings& settings,
                                      const juce::String& category,
                                      int uniqueID = 0);

    /** Generate name for velocity layer */
    juce::String generateVelocityLayerName(const juce::String& baseName,
                                          int layerIndex,
                                          int totalLayers);

    /** Extract musical info from filename */
    struct MusicalInfo
    {
        juce::String key;           // C, Am, Dm, etc.
        int bpm = 0;                // Detected from filename
        juce::String genre;         // Techno, House, etc.
        juce::String character;     // Dark, Bright, Warm, etc.
    };

    MusicalInfo extractMusicalInfo(const juce::String& filename);

    //==========================================================================
    // Legal Safety
    //==========================================================================

    /** Check if transformation is legally safe */
    bool isTransformationLegal(const ProcessingSettings& settings) const;

    /** Get recommended transformation amount */
    float getRecommendedTransformation() const { return 0.5f; } // 50% minimum

    /** Verify transformation uniqueness */
    bool verifyUniqueness(const juce::AudioBuffer<float>& original,
                         const juce::AudioBuffer<float>& processed) const;

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(int filesProcessed, int totalFiles)> onBatchProgress;
    std::function<void(const ProcessingResult& result)> onFileProcessed;
    std::function<void(bool success, int filesProcessed)> onBatchComplete;
    std::function<void(const juce::String& error)> onError;

private:
    //==========================================================================
    // Processing Implementation
    //==========================================================================

    void applyPitchShift(juce::AudioBuffer<float>& audio, float semitones, double sampleRate);
    void applyTimeStretch(juce::AudioBuffer<float>& audio, float ratio, double sampleRate);
    void applyFilter(juce::AudioBuffer<float>& audio, float lowPass, float highPass, double sampleRate);
    void applyCompression(juce::AudioBuffer<float>& audio, float amount);
    void applySaturation(juce::AudioBuffer<float>& audio, float amount);
    void applyReverb(juce::AudioBuffer<float>& audio, float wetMix, double sampleRate);
    void applyDelay(juce::AudioBuffer<float>& audio, float wetMix, double sampleRate);
    void applyBitCrush(juce::AudioBuffer<float>& audio, float amount);
    void applyVinylNoise(juce::AudioBuffer<float>& audio, float amount);
    void applyChorus(juce::AudioBuffer<float>& audio, float amount, double sampleRate);
    void applyStutter(juce::AudioBuffer<float>& audio, float amount, double sampleRate);
    void applyGranular(juce::AudioBuffer<float>& audio, float amount, double sampleRate);
    void applyReverse(juce::AudioBuffer<float>& audio, float mixAmount);

    /** Trim silence from start/end with micro-fades to prevent clicks */
    juce::AudioBuffer<float> trimSilenceWithFades(const juce::AudioBuffer<float>& audio,
                                                   float thresholdDB,
                                                   int fadeSamples,
                                                   double sampleRate);

    //==========================================================================
    // Randomization
    //==========================================================================

    void randomizeSettings(ProcessingSettings& settings, float amount, int seed);
    float getRandomValue(float min, float max);

    //==========================================================================
    // Batch State
    //==========================================================================

    std::atomic<bool> batchRunning { false };
    std::atomic<float> batchProgress { 0.0f };
    std::atomic<bool> shouldCancelBatch { false };

    juce::Random random;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SampleProcessor)
};
