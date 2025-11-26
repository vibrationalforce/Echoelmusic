#pragma once

#include <JuceHeader.h>
#include <map>
#include <vector>

/**
 * UniversalSampleEngine - Centralized Sample Management for ALL Echoel Instruments
 *
 * FEATURES:
 * - Load optimized sample library (1.2GB → <100MB)
 * - Share samples across ALL instruments (Sampler, 808, Granular, etc.)
 * - Velocity layers for realistic dynamics
 * - MIDI 2.0 support (32-bit velocity, per-note pitch bend)
 * - Intelligent sample selection based on context
 * - Bio-reactive sample modulation
 * - Dolby Atmos optimization
 *
 * SAMPLE CATEGORIES:
 * - ECHOEL_DRUMS: kicks, snares, hihats, cymbals, percussion
 * - ECHOEL_BASS: sub_bass, reese, 808, acoustic, synth
 * - ECHOEL_MELODIC: keys, plucks, leads, pads, bells
 * - ECHOEL_TEXTURES: atmospheres, field_recordings, noise
 * - ECHOEL_VOCAL: chops, phrases, fx, breaths
 * - ECHOEL_FX: impacts, risers, sweeps, transitions
 * - ECHOEL_JUNGLE: amen_slices, think_slices, breaks
 *
 * Usage:
 * ```cpp
 * UniversalSampleEngine sampleEngine;
 *
 * // Load library
 * sampleEngine.loadLibrary("/path/to/processed_samples");
 *
 * // Get sample
 * auto kick = sampleEngine.getSample("ECHOEL_DRUMS", "kicks", velocity);
 *
 * // Use in any instrument
 * echoel808.assignSample(pad, kick);
 * echoelSampler.mapSample(midiNote, kick);
 * echoelGranular.setSource(kick);
 * ```
 */

//==============================================================================
// Sample Data Structures
//==============================================================================

struct SampleMetadata
{
    juce::String name;
    juce::String category;
    juce::String subcategory;
    juce::String filePath;

    float durationMs = 0.0f;
    int sampleRate = 44100;
    int channels = 2;

    // Audio features
    float pitchHz = 0.0f;
    float pitchConfidence = 0.0f;
    float tempoBpm = 0.0f;
    juce::String key;

    // Spectral features
    float spectralCentroid = 0.0f;
    float spectralRolloff = 0.0f;
    float zeroCrossingRate = 0.0f;
    float rmsEnergy = 0.0f;

    // Classification
    juce::String drumType;
    juce::String energyLevel;  // "low", "medium", "high"
    juce::String brightness;   // "dark", "neutral", "bright"

    // MIDI mapping
    int suggestedMidiNote = 60;
    int velocityMin = 0;
    int velocityMax = 127;

    // Audio data (loaded on demand)
    juce::AudioBuffer<float> audioData;
    bool isLoaded = false;
};

struct VelocityLayer
{
    int velocityMin = 0;
    int velocityMax = 127;
    float volume = 1.0f;
    juce::AudioBuffer<float> audioData;
};

//==============================================================================
// Sample Pool
//==============================================================================

class SamplePool
{
public:
    SamplePool() = default;

    void addSample(const SampleMetadata& sample)
    {
        samples.push_back(sample);
    }

    const SampleMetadata* getSample(float velocity = 0.7f) const
    {
        if (samples.empty())
            return nullptr;

        // Simple velocity selection (can be enhanced with ML)
        int velocityIndex = juce::jlimit(0, (int)samples.size() - 1,
                                        (int)(velocity * samples.size()));

        return &samples[velocityIndex];
    }

    const SampleMetadata* getSampleByEnergy(const juce::String& energyLevel) const
    {
        for (const auto& sample : samples)
        {
            if (sample.energyLevel == energyLevel)
                return &sample;
        }

        return samples.empty() ? nullptr : &samples[0];
    }

    const SampleMetadata* getSampleByBrightness(const juce::String& brightness) const
    {
        for (const auto& sample : samples)
        {
            if (sample.brightness == brightness)
                return &sample;
        }

        return samples.empty() ? nullptr : &samples[0];
    }

    int getCount() const { return (int)samples.size(); }

    const std::vector<SampleMetadata>& getAllSamples() const { return samples; }

private:
    std::vector<SampleMetadata> samples;
};

//==============================================================================
// Universal Sample Engine - Main Class
//==============================================================================

class UniversalSampleEngine
{
public:
    UniversalSampleEngine();
    ~UniversalSampleEngine();

    //==========================================================================
    // Library Management
    //==========================================================================

    /** Load complete sample library */
    bool loadLibrary(const juce::File& libraryPath);

    /** Load metadata from JSON */
    bool loadMetadata(const juce::File& metadataFile);

    /** Load MIDI mappings */
    bool loadMidiMappings(const juce::File& mappingsFile);

    /** Is library loaded? */
    bool isLibraryLoaded() const { return libraryLoaded; }

    /** Get library statistics */
    struct LibraryStats
    {
        int totalSamples = 0;
        int loadedSamples = 0;
        float totalSizeMB = 0.0f;
        juce::StringArray categories;
    };

    LibraryStats getLibraryStats() const;

    //==========================================================================
    // Sample Access
    //==========================================================================

    /** Get sample from category/subcategory */
    const SampleMetadata* getSample(
        const juce::String& category,
        const juce::String& subcategory,
        float velocity = 0.7f);

    /** Get sample by MIDI note */
    const SampleMetadata* getSampleForMidiNote(int midiNote, float velocity = 0.7f);

    /** Get sample by drum type */
    const SampleMetadata* getSampleByDrumType(const juce::String& drumType, float velocity = 0.7f);

    /** Get samples by criteria */
    std::vector<const SampleMetadata*> getSamplesByCriteria(
        const juce::String& category,
        const juce::String& subcategory,
        const juce::String& energyLevel = "",
        const juce::String& brightness = "");

    /** Get random sample from category */
    const SampleMetadata* getRandomSample(
        const juce::String& category,
        const juce::String& subcategory);

    //==========================================================================
    // Sample Loading
    //==========================================================================

    /** Load sample audio data (lazy loading) */
    bool loadSampleData(SampleMetadata* sample);

    /** Unload sample audio data (free memory) */
    void unloadSampleData(SampleMetadata* sample);

    /** Preload category */
    void preloadCategory(const juce::String& category, const juce::String& subcategory);

    /** Unload all audio data */
    void unloadAllAudioData();

    //==========================================================================
    // MIDI 2.0 Support
    //==========================================================================

    /** Get sample for MIDI 2.0 message (32-bit velocity) */
    const SampleMetadata* getSampleForMidi2(
        int note,
        uint32_t velocity,      // 32-bit MIDI 2.0 velocity
        uint32_t pressure = 0,
        uint16_t pitchBend = 0x2000);

    /** Map MIDI note to sample */
    void mapMidiNote(int midiNote, const juce::String& category, const juce::String& subcategory);

    //==========================================================================
    // Bio-Reactive Modulation
    //==========================================================================

    /** Set heart rate (affects sample selection) */
    void setHeartRate(int bpm);

    /** Set stress level (affects sample energy) */
    void setStressLevel(float stress);  // 0-1

    /** Set focus level (affects sample brightness) */
    void setFocusLevel(float focus);    // 0-1

    /** Enable bio-reactive filtering */
    void enableBioReactiveFiltering(bool enable);

    //==========================================================================
    // Intelligent Selection
    //==========================================================================

    /** Auto-select sample based on context */
    const SampleMetadata* autoSelectSample(
        const juce::String& category,
        int midiNote,
        float velocity,
        float tempo,
        const juce::String& key);

    /** Get complementary samples (for layering) */
    std::vector<const SampleMetadata*> getComplementarySamples(
        const SampleMetadata* baseSample,
        int count = 3);

    //==========================================================================
    // Jungle/Breakbeat Special
    //==========================================================================

    /** Get jungle break slices */
    std::vector<const SampleMetadata*> getJungleBreakSlices(
        const juce::String& breakName,  // "amen", "think", etc.
        int bpm = 160);

    /** Get slice by position (0-15 for 16th notes) */
    const SampleMetadata* getBreakSlice(
        const juce::String& breakName,
        int position);

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(const juce::String& message)> onStatusChange;
    std::function<void(const juce::String& error)> onError;
    std::function<void(int samplesLoaded, int totalSamples)> onLoadProgress;

private:
    //==========================================================================
    // Data Storage
    //==========================================================================

    std::map<juce::String, std::map<juce::String, SamplePool>> library;
    std::map<int, std::pair<juce::String, juce::String>> midiMappings;

    juce::File libraryPath;
    bool libraryLoaded = false;

    // Bio-reactive state
    int currentHeartRate = 70;
    float currentStress = 0.0f;
    float currentFocus = 0.5f;
    bool bioReactiveEnabled = false;

    //==========================================================================
    // Helper Methods
    //==========================================================================

    bool parseSampleMetadata(const juce::var& json, SampleMetadata& sample);

    float velocityToFloat(uint32_t velocity32bit);

    juce::String selectEnergyLevel(float velocity, float stress);
    juce::String selectBrightness(float focus);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(UniversalSampleEngine)
};

//==============================================================================
// Integration Helpers for Echoel Instruments
//==============================================================================

/**
 * Integrate samples into Echoel808
 */
class Echoel808SampleIntegration
{
public:
    static void setupWithSamples(UniversalSampleEngine& sampleEngine)
    {
        // Map pads to samples
        for (int pad = 0; pad < 16; pad++)
        {
            juce::String category, subcategory;

            switch (pad)
            {
                case 0: category = "ECHOEL_DRUMS"; subcategory = "kicks"; break;
                case 1: category = "ECHOEL_DRUMS"; subcategory = "snares"; break;
                case 2: case 3: category = "ECHOEL_DRUMS"; subcategory = "hihats"; break;
                case 4: category = "ECHOEL_DRUMS"; subcategory = "claps"; break;
                case 5: case 6: category = "ECHOEL_DRUMS"; subcategory = "percussion"; break;
                case 7: category = "ECHOEL_DRUMS"; subcategory = "cymbals"; break;
                case 8: case 9: case 10: case 11:
                    category = "ECHOEL_BASS"; subcategory = "808"; break;
                default:
                    category = "ECHOEL_FX"; subcategory = "impacts"; break;
            }

            // Would assign sample to pad
            auto sample = sampleEngine.getSample(category, subcategory, 0.7f);
            // pad[pad].assignSample(sample);
        }
    }

    static void enableJungleMode(UniversalSampleEngine& sampleEngine)
    {
        // Load Amen break slices
        auto amenSlices = sampleEngine.getJungleBreakSlices("amen", 170);

        // Map to pads
        for (int i = 0; i < juce::jmin(16, (int)amenSlices.size()); i++)
        {
            // pad[i].assignSample(amenSlices[i]);
        }
    }
};

/**
 * Integrate samples into EchoelSampler
 */
class EchoelSamplerIntegration
{
public:
    static void autoMapSamples(UniversalSampleEngine& sampleEngine)
    {
        // Map MIDI notes to samples
        for (int note = 0; note < 128; note++)
        {
            juce::String category, subcategory;

            if (note < 36)
            {
                // Bass range
                category = "ECHOEL_BASS";
                subcategory = (note < 24) ? "sub_bass" : "synth";
            }
            else if (note < 60)
            {
                // Drum range
                category = "ECHOEL_DRUMS";
                subcategory = "percussion";
            }
            else
            {
                // Melodic range
                category = "ECHOEL_MELODIC";

                if (note < 72)
                    subcategory = "keys";
                else if (note < 84)
                    subcategory = "plucks";
                else
                    subcategory = "bells";
            }

            sampleEngine.mapMidiNote(note, category, subcategory);
        }
    }
};

/**
 * Integrate samples into EchoelGranular
 */
class EchoelGranularIntegration
{
public:
    static void loadTexturesForGranulation(UniversalSampleEngine& sampleEngine)
    {
        // Get atmospheric textures perfect for granulation
        auto textures = sampleEngine.getSamplesByCriteria(
            "ECHOEL_TEXTURES",
            "atmospheres",
            "",  // any energy
            ""   // any brightness
        );

        // Would set as granular source
        // for (auto texture : textures) {
        //     granular.addSource(texture);
        // }
    }
};
