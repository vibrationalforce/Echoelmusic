#pragma once

#include <JuceHeader.h>
#include "ProducerStyleProcessor.h"

/**
 * IntelligentStyleEngine - Super Intelligence Processing Mode
 *
 * ECHOELMUSIC SUPER INTELLIGENCE MODE:
 * - Genre-basiertes Processing (statt einzelner Producer)
 * - Einstellbare Parameter pro Genre
 * - Auto-Detection (Genre, BPM, Key, Instrument Type)
 * - Dolby Atmos Optimization (Standard!)
 * - Adaptive Loudness (Atmos -14 LUFS → Club -6 LUFS, stufenlos)
 * - Zip-Import mit gemischten Qualitäten
 *
 * USER-FRIENDLY GENRES statt Producer-Namen:
 * - Trap, Hip-Hop, Techno, House, Dubstep, Experimental, etc.
 * - Jedes Genre hat verstellbare Parameter
 *
 * Usage:
 * ```cpp
 * IntelligentStyleEngine engine;
 *
 * // Import .zip mit gemischten Qualitäten
 * auto samples = engine.importFromZip("samples.zip");
 *
 * // Auto-detect Genre
 * auto genre = engine.detectGenre(audio);
 *
 * // Process mit Genre + Custom Parameters
 * GenreProcessingConfig config;
 * config.genre = MusicGenre::Trap;
 * config.bassAmount = 0.8f;          // 0-1
 * config.stereoWidth = 0.7f;         // 0-1
 * config.atmosphereAmount = 0.5f;    // 0-1
 * config.targetLoudness = -10.0f;    // Atmos (-14) → Club (-6)
 *
 * auto result = engine.processIntelligent(audio, config);
 * ```
 */

//==============================================================================
// Music Genres (User-Friendly!)
//==============================================================================

enum class MusicGenre
{
    // ELECTRONIC
    Trap,                   // Modern trap, 808s, wide stereo
    HipHop,                 // Classic hip-hop, punch, warmth
    Techno,                 // Deep techno, analog, atmospheric
    House,                  // House grooves, organic, warm
    Dubstep,                // Heavy bass, wobbles, sub focus
    DrumAndBass,            // Fast breaks, tight processing
    Ambient,                // Atmospheric, reverb, space
    Experimental,           // Creative, granular, unique

    // ACOUSTIC
    Pop,                    // Clean, bright, commercial
    Rock,                   // Raw, dynamic, punchy
    Jazz,                   // Natural dynamics, space
    Classical,              // High dynamic range, natural

    // HYBRID
    Electronic,             // General electronic music
    Urban,                  // R&B, Neo-Soul, modern urban
    World,                  // Ethnic, organic instruments

    // ECHOELMUSIC SIGNATURE
    EchoelIntelligent,      // Auto-detect + best processing!

    Unknown
};

//==============================================================================
// Loudness Targets
//==============================================================================

enum class LoudnessTarget
{
    DolbyAtmos,             // -18 LUFS (spatial audio optimal)
    Streaming,              // -14 LUFS (Spotify, Apple Music)
    Broadcast,              // -23 LUFS (EBU R128)
    MusicProduction,        // -10 LUFS (modern production)
    Club,                   // -6 to -8 LUFS (maximum impact!)
    Custom                  // User-defined
};

struct LoudnessSpec
{
    float targetLUFS = -14.0f;          // Target loudness
    float truePeakMax = -1.0f;          // True peak ceiling (dBTP)
    float dynamicRangeMin = 8.0f;       // Minimum dynamic range to preserve
    bool limitTruePeak = true;          // Apply true peak limiting
    bool preserveDynamics = true;        // Preserve natural dynamics

    static LoudnessSpec fromTarget(LoudnessTarget target);
};

//==============================================================================
// Genre Processing Configuration
//==============================================================================

struct GenreProcessingConfig
{
    MusicGenre genre = MusicGenre::EchoelIntelligent;

    // ADJUSTABLE PARAMETERS (0.0 - 1.0)
    float bassAmount = 0.5f;            // Sub-bass enhancement
    float stereoWidth = 0.5f;           // Stereo widening
    float atmosphereAmount = 0.5f;      // Reverb/space
    float warmthAmount = 0.5f;          // Analog warmth/saturation
    float punchAmount = 0.5f;           // Compression/transients
    float brightnessAmount = 0.5f;      // High-frequency enhancement

    // LOUDNESS (stufenlos einstellbar!)
    LoudnessSpec loudness;

    // DOLBY ATMOS OPTIMIZATION
    bool optimizeForAtmos = true;       // Standard: true!
    bool spatialEnhancement = false;    // Extra spatial processing
    float atmosHeadroom = 4.0f;         // Headroom für Atmos (dB)

    // QUALITY
    ProducerStyleProcessor::AudioQuality outputQuality =
        ProducerStyleProcessor::AudioQuality::Professional;

    // AUTO-DETECTION
    bool autoDetectGenre = false;
    bool autoDetectKey = false;
    bool autoDetectBPM = false;
    bool autoDetectInstrument = false;
};

//==============================================================================
// Processing Result with Metadata
//==============================================================================

struct IntelligentProcessingResult
{
    juce::AudioBuffer<float> audio;

    // Detected metadata
    MusicGenre detectedGenre = MusicGenre::Unknown;
    juce::String detectedKey;           // "A minor", "C# major", etc.
    float detectedBPM = 0.0f;
    juce::String detectedInstrument;    // "Kick", "Bass", "Synth", etc.

    // Audio analysis
    float peakDB = 0.0f;
    float rmsDB = 0.0f;
    float lufs = 0.0f;
    float truePeakDB = 0.0f;
    float dynamicRange = 0.0f;
    float stereoWidth = 0.0f;

    // Dolby Atmos metrics
    bool atmosCompliant = false;
    float atmosHeadroom = 0.0f;
    juce::String atmosRating;           // "Excellent", "Good", "Needs adjustment"

    // Processing info
    juce::String processingChain;
    double processingTime = 0.0;
    bool success = false;
    juce::String errorMessage;
};

//==============================================================================
// Zip Import Support
//==============================================================================

struct ZipImportResult
{
    juce::Array<juce::File> importedFiles;

    // Quality detection
    struct FileQuality
    {
        juce::File file;
        int bitDepth = 16;
        double sampleRate = 44100.0;
        int numChannels = 2;
        juce::String qualityRating;     // "Standard", "Professional", "Studio"
    };

    juce::Array<FileQuality> fileQualities;

    int totalFiles = 0;
    int imported = 0;
    int failed = 0;
    juce::StringArray failedFiles;

    // Statistics
    int files16bit = 0;
    int files24bit = 0;
    int files32bit = 0;
    int files44khz = 0;
    int files48khz = 0;
    int files96khz = 0;
    int files192khz = 0;
};

//==============================================================================
// IntelligentStyleEngine - Main Class
//==============================================================================

class IntelligentStyleEngine
{
public:
    IntelligentStyleEngine();
    ~IntelligentStyleEngine();

    //==========================================================================
    // ZIP IMPORT (Mixed Qualities & Folder Structures)
    //==========================================================================

    /** Import samples from .zip archive (any structure, any quality) */
    ZipImportResult importFromZip(const juce::File& zipFile,
                                   const juce::File& extractToFolder);

    /** Import and auto-organize by detected quality */
    ZipImportResult importFromZipWithOrganization(const juce::File& zipFile,
                                                   const juce::File& baseFolder);

    /** Scan .zip without extracting (preview contents) */
    ZipImportResult scanZipContents(const juce::File& zipFile);

    //==========================================================================
    // AUTO-DETECTION
    //==========================================================================

    /** Auto-detect genre from audio */
    MusicGenre detectGenre(const juce::AudioBuffer<float>& audio,
                          double sampleRate);

    /** Auto-detect key (musical key) */
    juce::String detectKey(const juce::AudioBuffer<float>& audio,
                          double sampleRate);

    /** Auto-detect BPM (tempo) */
    float detectBPM(const juce::AudioBuffer<float>& audio,
                   double sampleRate);

    /** Auto-detect instrument type */
    juce::String detectInstrument(const juce::AudioBuffer<float>& audio,
                                  double sampleRate);

    /** Full auto-detection (all metadata) */
    struct AutoDetectionResult
    {
        MusicGenre genre;
        juce::String key;
        float bpm;
        juce::String instrument;
        float confidence;           // 0-1 (how confident is the detection)
    };

    AutoDetectionResult autoDetectAll(const juce::AudioBuffer<float>& audio,
                                     double sampleRate);

    //==========================================================================
    // INTELLIGENT PROCESSING
    //==========================================================================

    /** Process with genre + custom parameters */
    IntelligentProcessingResult processIntelligent(
        const juce::AudioBuffer<float>& audio,
        const GenreProcessingConfig& config);

    /** Process with full auto-detection */
    IntelligentProcessingResult processFullAuto(
        const juce::AudioBuffer<float>& audio,
        double sampleRate);

    /** Batch process multiple files */
    juce::Array<IntelligentProcessingResult> processBatch(
        const juce::Array<juce::File>& files,
        const GenreProcessingConfig& config);

    //==========================================================================
    // DOLBY ATMOS OPTIMIZATION
    //==========================================================================

    /** Optimize for Dolby Atmos (standard!) */
    juce::AudioBuffer<float> optimizeForAtmos(
        const juce::AudioBuffer<float>& audio);

    /** Check Atmos compliance */
    struct AtmosComplianceCheck
    {
        bool compliant = false;
        float headroom = 0.0f;          // Available headroom
        float dynamicRange = 0.0f;
        float lufs = 0.0f;
        float truePeak = 0.0f;
        juce::String rating;            // "Excellent", "Good", "Poor"
        juce::StringArray issues;       // List of issues
        juce::StringArray recommendations;
    };

    AtmosComplianceCheck checkAtmosCompliance(
        const juce::AudioBuffer<float>& audio,
        double sampleRate);

    /** Fix Atmos issues automatically */
    juce::AudioBuffer<float> fixAtmosIssues(
        const juce::AudioBuffer<float>& audio,
        const AtmosComplianceCheck& check);

    //==========================================================================
    // ADAPTIVE LOUDNESS (Stufenlos: Atmos → Club)
    //==========================================================================

    /** Adjust loudness to target LUFS (stufenlos!) */
    juce::AudioBuffer<float> adjustLoudness(
        const juce::AudioBuffer<float>& audio,
        double sampleRate,
        float targetLUFS,
        bool preserveDynamics = true);

    /** Loudness with visual feedback data */
    struct LoudnessAdjustmentResult
    {
        juce::AudioBuffer<float> audio;
        float inputLUFS = 0.0f;
        float outputLUFS = 0.0f;
        float gainApplied = 0.0f;       // dB
        float truePeak = 0.0f;
        float dynamicRange = 0.0f;
        bool limitingApplied = false;
        juce::String quality;           // "Excellent", "Good", "Over-processed"
    };

    LoudnessAdjustmentResult adjustLoudnessWithFeedback(
        const juce::AudioBuffer<float>& audio,
        double sampleRate,
        const LoudnessSpec& spec);

    /** Get loudness meter data (for UI display) */
    struct LoudnessMeterData
    {
        float currentLUFS = 0.0f;
        float targetLUFS = 0.0f;
        float truePeak = 0.0f;
        float dynamicRange = 0.0f;
        float headroom = 0.0f;
        juce::String targetName;        // "Dolby Atmos", "Club Mix", etc.
    };

    LoudnessMeterData getLoudnessMeterData(
        const juce::AudioBuffer<float>& audio,
        double sampleRate,
        LoudnessTarget target);

    //==========================================================================
    // GENRE-SPECIFIC PROCESSING
    //==========================================================================

    // Each genre has optimized processing chain
    juce::AudioBuffer<float> processTrap(const juce::AudioBuffer<float>& audio,
                                        const GenreProcessingConfig& config);

    juce::AudioBuffer<float> processHipHop(const juce::AudioBuffer<float>& audio,
                                          const GenreProcessingConfig& config);

    juce::AudioBuffer<float> processTechno(const juce::AudioBuffer<float>& audio,
                                          const GenreProcessingConfig& config);

    juce::AudioBuffer<float> processHouse(const juce::AudioBuffer<float>& audio,
                                         const GenreProcessingConfig& config);

    juce::AudioBuffer<float> processDubstep(const juce::AudioBuffer<float>& audio,
                                           const GenreProcessingConfig& config);

    juce::AudioBuffer<float> processAmbient(const juce::AudioBuffer<float>& audio,
                                           const GenreProcessingConfig& config);

    juce::AudioBuffer<float> processExperimental(const juce::AudioBuffer<float>& audio,
                                                 const GenreProcessingConfig& config);

    //==========================================================================
    // RECOMMENDED SETTINGS
    //==========================================================================

    /** Get recommended config for genre */
    GenreProcessingConfig getRecommendedConfig(MusicGenre genre);

    /** Get recommended loudness for use-case */
    LoudnessSpec getRecommendedLoudness(LoudnessTarget target);

    /** Get genre name (user-friendly) */
    juce::String getGenreName(MusicGenre genre) const;

    /** Get genre description */
    juce::String getGenreDescription(MusicGenre genre) const;

    //==========================================================================
    // PRESETS & SETTINGS
    //==========================================================================

    /** Save custom preset */
    bool savePreset(const GenreProcessingConfig& config,
                   const juce::String& name);

    /** Load custom preset */
    GenreProcessingConfig loadPreset(const juce::String& name);

    /** Get all saved presets */
    juce::StringArray getSavedPresets();

    //==========================================================================
    // CALLBACKS (für UI Updates)
    //==========================================================================

    std::function<void(float progress)> onProgress;
    std::function<void(const juce::String& message)> onStatusChange;
    std::function<void(const LoudnessMeterData& data)> onLoudnessUpdate;
    std::function<void(const AtmosComplianceCheck& check)> onAtmosCheck;
    std::function<void(const AutoDetectionResult& result)> onAutoDetection;
    std::function<void(const juce::String& error)> onError;

private:
    //==========================================================================
    // Internal Processing
    //==========================================================================

    ProducerStyleProcessor styleProcessor;

    // Genre processing helpers
    juce::AudioBuffer<float> applyGenreChain(
        const juce::AudioBuffer<float>& audio,
        MusicGenre genre,
        const GenreProcessingConfig& config);

    // Auto-detection algorithms
    MusicGenre detectGenreFromSpectrum(const juce::AudioBuffer<float>& audio,
                                       double sampleRate);
    MusicGenre detectGenreFromRhythm(const juce::AudioBuffer<float>& audio,
                                     double sampleRate);

    // Loudness processing
    float calculateLUFS(const juce::AudioBuffer<float>& audio, double sampleRate);
    float calculateTruePeak(const juce::AudioBuffer<float>& audio);
    juce::AudioBuffer<float> applyGainToLUFS(
        const juce::AudioBuffer<float>& audio,
        double sampleRate,
        float targetLUFS);

    // Dolby Atmos helpers
    bool meetsAtmosStandards(float lufs, float truePeak, float dynamicRange);
    juce::AudioBuffer<float> applyAtmosOptimization(
        const juce::AudioBuffer<float>& audio);

    // Zip extraction
    bool extractZipFile(const juce::File& zipFile, const juce::File& targetFolder);
    juce::Array<juce::File> findAudioFilesRecursive(const juce::File& folder);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(IntelligentStyleEngine)
};

//==============================================================================
// Inline Helper Functions
//==============================================================================

inline LoudnessSpec LoudnessSpec::fromTarget(LoudnessTarget target)
{
    LoudnessSpec spec;

    switch (target)
    {
        case LoudnessTarget::DolbyAtmos:
            spec.targetLUFS = -18.0f;       // Atmos standard
            spec.truePeakMax = -2.0f;       // Conservative headroom
            spec.dynamicRangeMin = 12.0f;   // High dynamic range
            spec.preserveDynamics = true;
            break;

        case LoudnessTarget::Streaming:
            spec.targetLUFS = -14.0f;       // Spotify, Apple Music
            spec.truePeakMax = -1.0f;
            spec.dynamicRangeMin = 8.0f;
            spec.preserveDynamics = true;
            break;

        case LoudnessTarget::Broadcast:
            spec.targetLUFS = -23.0f;       // EBU R128
            spec.truePeakMax = -1.0f;
            spec.dynamicRangeMin = 10.0f;
            spec.preserveDynamics = true;
            break;

        case LoudnessTarget::MusicProduction:
            spec.targetLUFS = -10.0f;       // Modern production
            spec.truePeakMax = -1.0f;
            spec.dynamicRangeMin = 6.0f;
            spec.preserveDynamics = true;
            break;

        case LoudnessTarget::Club:
            spec.targetLUFS = -6.0f;        // Maximum impact!
            spec.truePeakMax = -0.5f;
            spec.dynamicRangeMin = 4.0f;
            spec.preserveDynamics = false;  // More compression
            break;

        default:
            break;
    }

    spec.limitTruePeak = true;
    return spec;
}
