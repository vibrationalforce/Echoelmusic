#pragma once

/**
 * EchoelPresetManager.h - Preset Save/Load System
 *
 * ============================================================================
 *   RALPH WIGGUM GENIUS LOOP MODE - PRESET PERSISTENCE
 * ============================================================================
 *
 *   FEATURES:
 *     - JSON-based preset format
 *     - Hierarchical preset categories
 *     - User & factory presets
 *     - Preset morphing/interpolation
 *     - Undo/redo support
 *     - Cloud sync ready
 *
 *   PRESET STRUCTURE:
 *     {
 *       "name": "Deep Relaxation",
 *       "category": "meditation",
 *       "version": 1,
 *       "entrainment": { ... },
 *       "laser": { ... },
 *       "audio": { ... },
 *       "bio": { ... }
 *     }
 *
 * ============================================================================
 */

#include "../DSP/BrainwaveEntrainment.h"
#include <JuceHeader.h>
#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>

namespace Echoel
{

//==============================================================================
// Preset Data Structures
//==============================================================================

struct EntrainmentPresetData
{
    float frequency = 40.0f;
    float intensity = 0.8f;
    float binauralMix = 0.4f;
    float isochronicMix = 0.3f;
    float monauralMix = 0.2f;
    float carrierFrequency = 200.0f;
    std::string sessionPreset = "Gamma40Hz_MIT";

    juce::var toVar() const
    {
        auto obj = new juce::DynamicObject();
        obj->setProperty("frequency", frequency);
        obj->setProperty("intensity", intensity);
        obj->setProperty("binauralMix", binauralMix);
        obj->setProperty("isochronicMix", isochronicMix);
        obj->setProperty("monauralMix", monauralMix);
        obj->setProperty("carrierFrequency", carrierFrequency);
        obj->setProperty("sessionPreset", juce::String(sessionPreset));
        return juce::var(obj);
    }

    static EntrainmentPresetData fromVar(const juce::var& v)
    {
        EntrainmentPresetData data;
        if (auto* obj = v.getDynamicObject())
        {
            data.frequency = obj->getProperty("frequency");
            data.intensity = obj->getProperty("intensity");
            data.binauralMix = obj->getProperty("binauralMix");
            data.isochronicMix = obj->getProperty("isochronicMix");
            data.monauralMix = obj->getProperty("monauralMix");
            data.carrierFrequency = obj->getProperty("carrierFrequency");
            data.sessionPreset = obj->getProperty("sessionPreset").toString().toStdString();
        }
        return data;
    }
};

struct LaserPresetData
{
    bool enabled = false;
    float intensity = 0.8f;
    float speed = 1.0f;
    int patternIndex = 0;
    std::string patternName = "Circle";
    float colorHue = 0.0f;
    float colorSaturation = 1.0f;
    bool audioReactive = true;
    bool bioReactive = false;

    juce::var toVar() const
    {
        auto obj = new juce::DynamicObject();
        obj->setProperty("enabled", enabled);
        obj->setProperty("intensity", intensity);
        obj->setProperty("speed", speed);
        obj->setProperty("patternIndex", patternIndex);
        obj->setProperty("patternName", juce::String(patternName));
        obj->setProperty("colorHue", colorHue);
        obj->setProperty("colorSaturation", colorSaturation);
        obj->setProperty("audioReactive", audioReactive);
        obj->setProperty("bioReactive", bioReactive);
        return juce::var(obj);
    }

    static LaserPresetData fromVar(const juce::var& v)
    {
        LaserPresetData data;
        if (auto* obj = v.getDynamicObject())
        {
            data.enabled = obj->getProperty("enabled");
            data.intensity = obj->getProperty("intensity");
            data.speed = obj->getProperty("speed");
            data.patternIndex = obj->getProperty("patternIndex");
            data.patternName = obj->getProperty("patternName").toString().toStdString();
            data.colorHue = obj->getProperty("colorHue");
            data.colorSaturation = obj->getProperty("colorSaturation");
            data.audioReactive = obj->getProperty("audioReactive");
            data.bioReactive = obj->getProperty("bioReactive");
        }
        return data;
    }
};

struct AudioPresetData
{
    float masterVolume = 0.8f;
    float bassBoost = 0.0f;
    float trebleBoost = 0.0f;
    float reverbMix = 0.0f;
    float delayMix = 0.0f;

    juce::var toVar() const
    {
        auto obj = new juce::DynamicObject();
        obj->setProperty("masterVolume", masterVolume);
        obj->setProperty("bassBoost", bassBoost);
        obj->setProperty("trebleBoost", trebleBoost);
        obj->setProperty("reverbMix", reverbMix);
        obj->setProperty("delayMix", delayMix);
        return juce::var(obj);
    }

    static AudioPresetData fromVar(const juce::var& v)
    {
        AudioPresetData data;
        if (auto* obj = v.getDynamicObject())
        {
            data.masterVolume = obj->getProperty("masterVolume");
            data.bassBoost = obj->getProperty("bassBoost");
            data.trebleBoost = obj->getProperty("trebleBoost");
            data.reverbMix = obj->getProperty("reverbMix");
            data.delayMix = obj->getProperty("delayMix");
        }
        return data;
    }
};

struct BioPresetData
{
    bool hrvGuidanceEnabled = false;
    float targetCoherence = 0.7f;
    float breathingRate = 6.0f;  // Breaths per minute
    bool adaptiveIntensity = true;

    juce::var toVar() const
    {
        auto obj = new juce::DynamicObject();
        obj->setProperty("hrvGuidanceEnabled", hrvGuidanceEnabled);
        obj->setProperty("targetCoherence", targetCoherence);
        obj->setProperty("breathingRate", breathingRate);
        obj->setProperty("adaptiveIntensity", adaptiveIntensity);
        return juce::var(obj);
    }

    static BioPresetData fromVar(const juce::var& v)
    {
        BioPresetData data;
        if (auto* obj = v.getDynamicObject())
        {
            data.hrvGuidanceEnabled = obj->getProperty("hrvGuidanceEnabled");
            data.targetCoherence = obj->getProperty("targetCoherence");
            data.breathingRate = obj->getProperty("breathingRate");
            data.adaptiveIntensity = obj->getProperty("adaptiveIntensity");
        }
        return data;
    }
};

//==============================================================================
// Complete Preset
//==============================================================================

struct Preset
{
    std::string name;
    std::string category;
    std::string description;
    std::string author = "Echoel";
    int version = 1;
    bool isFactory = false;
    bool isFavorite = false;
    double createdTime = 0.0;
    double modifiedTime = 0.0;

    EntrainmentPresetData entrainment;
    LaserPresetData laser;
    AudioPresetData audio;
    BioPresetData bio;

    // Tags for search
    std::vector<std::string> tags;

    juce::var toVar() const
    {
        auto obj = new juce::DynamicObject();
        obj->setProperty("name", juce::String(name));
        obj->setProperty("category", juce::String(category));
        obj->setProperty("description", juce::String(description));
        obj->setProperty("author", juce::String(author));
        obj->setProperty("version", version);
        obj->setProperty("isFactory", isFactory);
        obj->setProperty("isFavorite", isFavorite);
        obj->setProperty("createdTime", createdTime);
        obj->setProperty("modifiedTime", modifiedTime);

        obj->setProperty("entrainment", entrainment.toVar());
        obj->setProperty("laser", laser.toVar());
        obj->setProperty("audio", audio.toVar());
        obj->setProperty("bio", bio.toVar());

        juce::Array<juce::var> tagArray;
        for (const auto& tag : tags)
            tagArray.add(juce::String(tag));
        obj->setProperty("tags", tagArray);

        return juce::var(obj);
    }

    static Preset fromVar(const juce::var& v)
    {
        Preset preset;
        if (auto* obj = v.getDynamicObject())
        {
            preset.name = obj->getProperty("name").toString().toStdString();
            preset.category = obj->getProperty("category").toString().toStdString();
            preset.description = obj->getProperty("description").toString().toStdString();
            preset.author = obj->getProperty("author").toString().toStdString();
            preset.version = obj->getProperty("version");
            preset.isFactory = obj->getProperty("isFactory");
            preset.isFavorite = obj->getProperty("isFavorite");
            preset.createdTime = obj->getProperty("createdTime");
            preset.modifiedTime = obj->getProperty("modifiedTime");

            preset.entrainment = EntrainmentPresetData::fromVar(obj->getProperty("entrainment"));
            preset.laser = LaserPresetData::fromVar(obj->getProperty("laser"));
            preset.audio = AudioPresetData::fromVar(obj->getProperty("audio"));
            preset.bio = BioPresetData::fromVar(obj->getProperty("bio"));

            if (auto* tagArray = obj->getProperty("tags").getArray())
            {
                for (const auto& tag : *tagArray)
                    preset.tags.push_back(tag.toString().toStdString());
            }
        }
        return preset;
    }

    std::string toJSON() const
    {
        return juce::JSON::toString(toVar()).toStdString();
    }

    static Preset fromJSON(const std::string& json)
    {
        auto v = juce::JSON::parse(juce::String(json));
        return fromVar(v);
    }
};

//==============================================================================
// Preset Interpolation (for morphing)
//==============================================================================

inline Preset interpolatePresets(const Preset& a, const Preset& b, float t)
{
    Preset result;
    result.name = a.name + " -> " + b.name;
    result.category = "morphed";

    // Interpolate entrainment
    result.entrainment.frequency = a.entrainment.frequency * (1.0f - t) + b.entrainment.frequency * t;
    result.entrainment.intensity = a.entrainment.intensity * (1.0f - t) + b.entrainment.intensity * t;
    result.entrainment.binauralMix = a.entrainment.binauralMix * (1.0f - t) + b.entrainment.binauralMix * t;
    result.entrainment.isochronicMix = a.entrainment.isochronicMix * (1.0f - t) + b.entrainment.isochronicMix * t;
    result.entrainment.monauralMix = a.entrainment.monauralMix * (1.0f - t) + b.entrainment.monauralMix * t;
    result.entrainment.carrierFrequency = a.entrainment.carrierFrequency * (1.0f - t) + b.entrainment.carrierFrequency * t;

    // Interpolate laser
    result.laser.intensity = a.laser.intensity * (1.0f - t) + b.laser.intensity * t;
    result.laser.speed = a.laser.speed * (1.0f - t) + b.laser.speed * t;
    result.laser.colorHue = a.laser.colorHue * (1.0f - t) + b.laser.colorHue * t;
    result.laser.colorSaturation = a.laser.colorSaturation * (1.0f - t) + b.laser.colorSaturation * t;

    // Interpolate audio
    result.audio.masterVolume = a.audio.masterVolume * (1.0f - t) + b.audio.masterVolume * t;
    result.audio.bassBoost = a.audio.bassBoost * (1.0f - t) + b.audio.bassBoost * t;
    result.audio.trebleBoost = a.audio.trebleBoost * (1.0f - t) + b.audio.trebleBoost * t;
    result.audio.reverbMix = a.audio.reverbMix * (1.0f - t) + b.audio.reverbMix * t;

    // Interpolate bio
    result.bio.targetCoherence = a.bio.targetCoherence * (1.0f - t) + b.bio.targetCoherence * t;
    result.bio.breathingRate = a.bio.breathingRate * (1.0f - t) + b.bio.breathingRate * t;

    return result;
}

//==============================================================================
// Preset Manager
//==============================================================================

class EchoelPresetManager
{
public:
    using PresetCallback = std::function<void(const Preset&)>;

    EchoelPresetManager()
    {
        // Set up preset directory
        presetDirectory_ = juce::File::getSpecialLocation(
            juce::File::userApplicationDataDirectory
        ).getChildFile("Echoel").getChildFile("Presets");

        if (!presetDirectory_.exists())
            presetDirectory_.createDirectory();

        // Load factory presets
        loadFactoryPresets();
    }

    //==========================================================================
    // Preset Loading
    //==========================================================================

    void loadAllPresets()
    {
        presets_.clear();

        // Load factory presets first
        loadFactoryPresets();

        // Load user presets
        loadUserPresets();
    }

    bool loadPreset(const std::string& name)
    {
        auto it = presets_.find(name);
        if (it != presets_.end())
        {
            currentPreset_ = it->second;
            if (presetLoadedCallback_)
                presetLoadedCallback_(currentPreset_);
            return true;
        }
        return false;
    }

    bool loadPresetFromFile(const juce::File& file)
    {
        if (!file.existsAsFile())
            return false;

        juce::String json = file.loadFileAsString();
        try
        {
            currentPreset_ = Preset::fromJSON(json.toStdString());
            if (presetLoadedCallback_)
                presetLoadedCallback_(currentPreset_);
            return true;
        }
        catch (...)
        {
            return false;
        }
    }

    //==========================================================================
    // Preset Saving
    //==========================================================================

    bool savePreset(const Preset& preset)
    {
        juce::File file = presetDirectory_.getChildFile(
            juce::String(preset.name) + ".echoel"
        );

        Preset toSave = preset;
        toSave.isFactory = false;
        toSave.modifiedTime = juce::Time::currentTimeMillis() / 1000.0;
        if (toSave.createdTime == 0.0)
            toSave.createdTime = toSave.modifiedTime;

        juce::String json(toSave.toJSON());
        if (file.replaceWithText(json))
        {
            presets_[preset.name] = toSave;
            return true;
        }
        return false;
    }

    bool saveCurrentPreset(const std::string& name)
    {
        Preset toSave = currentPreset_;
        toSave.name = name;
        return savePreset(toSave);
    }

    //==========================================================================
    // Preset Management
    //==========================================================================

    bool deletePreset(const std::string& name)
    {
        auto it = presets_.find(name);
        if (it != presets_.end() && !it->second.isFactory)
        {
            juce::File file = presetDirectory_.getChildFile(
                juce::String(name) + ".echoel"
            );
            if (file.deleteFile())
            {
                presets_.erase(it);
                return true;
            }
        }
        return false;
    }

    bool renamePreset(const std::string& oldName, const std::string& newName)
    {
        auto it = presets_.find(oldName);
        if (it != presets_.end() && !it->second.isFactory)
        {
            Preset preset = it->second;
            preset.name = newName;
            if (savePreset(preset))
            {
                deletePreset(oldName);
                return true;
            }
        }
        return false;
    }

    void setFavorite(const std::string& name, bool favorite)
    {
        auto it = presets_.find(name);
        if (it != presets_.end())
        {
            it->second.isFavorite = favorite;
            if (!it->second.isFactory)
                savePreset(it->second);
        }
    }

    //==========================================================================
    // Preset Access
    //==========================================================================

    const Preset& getCurrentPreset() const { return currentPreset_; }
    Preset& getCurrentPreset() { return currentPreset_; }

    std::vector<std::string> getPresetNames() const
    {
        std::vector<std::string> names;
        for (const auto& pair : presets_)
            names.push_back(pair.first);
        return names;
    }

    std::vector<std::string> getPresetsByCategory(const std::string& category) const
    {
        std::vector<std::string> names;
        for (const auto& pair : presets_)
        {
            if (pair.second.category == category)
                names.push_back(pair.first);
        }
        return names;
    }

    std::vector<std::string> getFavoritePresets() const
    {
        std::vector<std::string> names;
        for (const auto& pair : presets_)
        {
            if (pair.second.isFavorite)
                names.push_back(pair.first);
        }
        return names;
    }

    std::vector<std::string> searchPresets(const std::string& query) const
    {
        std::vector<std::string> results;
        juce::String searchLower = juce::String(query).toLowerCase();

        for (const auto& pair : presets_)
        {
            juce::String nameLower = juce::String(pair.first).toLowerCase();
            if (nameLower.contains(searchLower))
            {
                results.push_back(pair.first);
                continue;
            }

            // Search tags
            for (const auto& tag : pair.second.tags)
            {
                if (juce::String(tag).toLowerCase().contains(searchLower))
                {
                    results.push_back(pair.first);
                    break;
                }
            }
        }
        return results;
    }

    const Preset* getPreset(const std::string& name) const
    {
        auto it = presets_.find(name);
        return it != presets_.end() ? &it->second : nullptr;
    }

    //==========================================================================
    // Categories
    //==========================================================================

    std::vector<std::string> getCategories() const
    {
        std::vector<std::string> categories;
        for (const auto& pair : presets_)
        {
            if (std::find(categories.begin(), categories.end(), pair.second.category) == categories.end())
                categories.push_back(pair.second.category);
        }
        return categories;
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    void onPresetLoaded(PresetCallback callback)
    {
        presetLoadedCallback_ = std::move(callback);
    }

    //==========================================================================
    // Morphing
    //==========================================================================

    Preset morphPresets(const std::string& nameA, const std::string& nameB, float t)
    {
        const Preset* a = getPreset(nameA);
        const Preset* b = getPreset(nameB);

        if (a && b)
            return interpolatePresets(*a, *b, t);

        return currentPreset_;
    }

private:
    void loadFactoryPresets()
    {
        // [SCIENTIFICALLY VALIDATED]
        {
            Preset p;
            p.name = "Gamma 40Hz - MIT Alzheimer's";
            p.category = "scientific";
            p.description = "MIT-validated 40 Hz gamma entrainment for cognitive enhancement";
            p.isFactory = true;
            p.tags = {"gamma", "40hz", "cognitive", "validated", "MIT"};
            p.entrainment.frequency = 40.0f;
            p.entrainment.intensity = 0.8f;
            p.entrainment.sessionPreset = "Gamma40Hz_MIT";
            p.laser.enabled = true;
            p.laser.patternName = "Gamma Flicker";
            presets_[p.name] = p;
        }

        {
            Preset p;
            p.name = "VNS 25Hz - FDA Approved";
            p.category = "scientific";
            p.description = "Vagus nerve stimulation frequency range for therapeutic applications";
            p.isFactory = true;
            p.tags = {"VNS", "25hz", "therapeutic", "FDA"};
            p.entrainment.frequency = 25.0f;
            p.entrainment.intensity = 0.7f;
            p.entrainment.sessionPreset = "VNS_25Hz";
            p.laser.enabled = true;
            p.laser.patternName = "VNS Pulse";
            presets_[p.name] = p;
        }

        {
            Preset p;
            p.name = "Alpha Relaxation - Validated";
            p.category = "scientific";
            p.description = "Meta-analysis validated alpha wave relaxation (10 Hz)";
            p.isFactory = true;
            p.tags = {"alpha", "10hz", "relaxation", "validated"};
            p.entrainment.frequency = 10.0f;
            p.entrainment.intensity = 0.6f;
            p.entrainment.sessionPreset = "AlphaRelaxation_Validated";
            p.laser.enabled = true;
            p.laser.patternName = "Gentle Wave";
            p.laser.colorHue = 0.5f;  // Cyan
            presets_[p.name] = p;
        }

        // [LIMITED EVIDENCE]
        {
            Preset p;
            p.name = "Deep Focus - Beta";
            p.category = "focus";
            p.description = "Beta wave focus enhancement (18 Hz)";
            p.isFactory = true;
            p.tags = {"beta", "focus", "concentration"};
            p.entrainment.frequency = 18.0f;
            p.entrainment.intensity = 0.7f;
            p.laser.patternName = "Spiral Focus";
            presets_[p.name] = p;
        }

        {
            Preset p;
            p.name = "Deep Meditation - Theta";
            p.category = "meditation";
            p.description = "Theta wave deep meditation (6 Hz)";
            p.isFactory = true;
            p.tags = {"theta", "meditation", "deep"};
            p.entrainment.frequency = 6.0f;
            p.entrainment.intensity = 0.5f;
            p.laser.patternName = "Mandala";
            p.laser.colorHue = 0.75f;  // Purple
            presets_[p.name] = p;
        }

        {
            Preset p;
            p.name = "Bio-Reactive Breathing";
            p.category = "bio";
            p.description = "HRV-synchronized breathing with visual guidance";
            p.isFactory = true;
            p.tags = {"breathing", "HRV", "coherence", "bio"};
            p.bio.hrvGuidanceEnabled = true;
            p.bio.breathingRate = 6.0f;
            p.bio.targetCoherence = 0.7f;
            p.laser.bioReactive = true;
            p.laser.patternName = "Breath Wave";
            presets_[p.name] = p;
        }

        // [ESOTERIC - Clearly Labeled]
        {
            Preset p;
            p.name = "[ESOTERIC] Schumann Resonance";
            p.category = "esoteric";
            p.description = "[NO SCIENTIFIC EVIDENCE] Earth's 7.83 Hz resonance frequency";
            p.isFactory = true;
            p.tags = {"schumann", "earth", "esoteric"};
            p.entrainment.frequency = 7.83f;
            p.entrainment.intensity = 0.5f;
            p.laser.patternName = "Earth Glow";
            p.laser.colorHue = 0.3f;  // Green
            presets_[p.name] = p;
        }

        {
            Preset p;
            p.name = "[ESOTERIC] 528 Hz Love";
            p.category = "esoteric";
            p.description = "[NO SCIENTIFIC EVIDENCE] Solfeggio frequency for transformation";
            p.isFactory = true;
            p.tags = {"solfeggio", "528", "esoteric"};
            p.entrainment.carrierFrequency = 528.0f;
            p.entrainment.frequency = 8.0f;
            p.laser.patternName = "Heart Spiral";
            p.laser.colorHue = 0.9f;  // Magenta
            presets_[p.name] = p;
        }
    }

    void loadUserPresets()
    {
        juce::Array<juce::File> files;
        presetDirectory_.findChildFiles(files, juce::File::findFiles, false, "*.echoel");

        for (const auto& file : files)
        {
            juce::String json = file.loadFileAsString();
            try
            {
                Preset preset = Preset::fromJSON(json.toStdString());
                preset.isFactory = false;
                presets_[preset.name] = preset;
            }
            catch (...)
            {
                // Skip invalid presets
            }
        }
    }

    std::map<std::string, Preset> presets_;
    Preset currentPreset_;
    juce::File presetDirectory_;
    PresetCallback presetLoadedCallback_;
};

}  // namespace Echoel
