/*
  ==============================================================================

    PresetManager.h
    Echoelmusic - Bio-Reactive DAW

    Comprehensive Preset Management with AI-powered organization
    Tags, favorites, smart search, and bio-state presets

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "RalphWiggumAPI.h"
#include <memory>
#include <vector>
#include <map>
#include <set>
#include <mutex>
#include <functional>

namespace Echoel {
namespace Core {

//==============================================================================
/**
    Preset metadata and content
*/
struct Preset
{
    // Identity
    juce::String id;
    juce::String name;
    juce::String author;
    juce::Time created;
    juce::Time modified;
    int version = 1;

    // Organization
    juce::String category;           // "Synth", "Effect", "Project", etc.
    juce::String subcategory;        // "Lead", "Pad", "Reverb", etc.
    juce::StringArray tags;
    juce::String description;

    // User data
    bool isFavorite = false;
    float rating = 0.0f;             // 0-5 stars
    int useCount = 0;
    juce::Time lastUsed;

    // Content
    juce::String targetType;         // Plugin ID or system component
    juce::MemoryBlock data;          // Serialized state
    juce::var metadata;              // Additional JSON metadata

    // Bio-reactive
    float idealCoherence = 0.5f;     // Best coherence level for this preset
    juce::String moodTag;            // "energetic", "calm", "focused", etc.

    // Factory/User
    bool isFactory = false;
    bool isReadOnly = false;

    Preset() : id(juce::Uuid().toString()) {}
};

//==============================================================================
/**
    Preset bank for organizing presets
*/
struct PresetBank
{
    juce::String id;
    juce::String name;
    juce::String author;
    juce::String description;
    juce::StringArray presetIds;
    bool isFactory = false;

    PresetBank() : id(juce::Uuid().toString()) {}
};

//==============================================================================
/**
    Search filter for presets
*/
struct PresetFilter
{
    juce::String searchText;
    juce::StringArray categories;
    juce::StringArray tags;
    juce::String author;
    bool favoritesOnly = false;
    float minRating = 0.0f;
    juce::String moodTag;

    // Bio-reactive filtering
    bool matchBioState = false;
    float currentCoherence = 0.5f;
    float coherenceTolerance = 0.2f;

    bool isEmpty() const
    {
        return searchText.isEmpty() &&
               categories.isEmpty() &&
               tags.isEmpty() &&
               author.isEmpty() &&
               !favoritesOnly &&
               minRating == 0.0f &&
               !matchBioState;
    }
};

//==============================================================================
/**
    AI-powered preset suggestions
*/
class PresetSuggestionEngine
{
public:
    struct Suggestion
    {
        Preset preset;
        float score = 0.0f;
        juce::String reason;
    };

    std::vector<Suggestion> getSuggestions(
        const juce::String& context,
        const std::vector<Preset>& presets,
        float currentCoherence,
        const juce::StringArray& recentlyUsed)
    {
        std::vector<Suggestion> suggestions;

        for (const auto& preset : presets)
        {
            float score = 0.0f;
            juce::String reason;

            // Context matching
            if (context.isNotEmpty())
            {
                if (preset.name.containsIgnoreCase(context))
                    score += 0.4f;
                if (preset.category.containsIgnoreCase(context))
                    score += 0.2f;

                for (const auto& tag : preset.tags)
                {
                    if (tag.containsIgnoreCase(context))
                    {
                        score += 0.15f;
                        break;
                    }
                }
            }

            // Bio-state matching
            float coherenceDiff = std::abs(preset.idealCoherence - currentCoherence);
            if (coherenceDiff < 0.1f)
            {
                score += 0.3f;
                reason = "Matches your current bio-state";
            }
            else if (coherenceDiff < 0.2f)
            {
                score += 0.15f;
            }

            // Mood matching based on coherence
            if (currentCoherence > 0.7f && preset.moodTag == "calm")
                score += 0.2f;
            else if (currentCoherence < 0.3f && preset.moodTag == "energetic")
                score += 0.2f;

            // Favorite boost
            if (preset.isFavorite)
                score += 0.25f;

            // Rating boost
            score += preset.rating * 0.04f;

            // Recent usage penalty (avoid repetition)
            if (recentlyUsed.contains(preset.id))
                score -= 0.3f;

            // Popularity boost
            score += std::min(0.1f, preset.useCount * 0.002f);

            if (score > 0.3f)
            {
                Suggestion s;
                s.preset = preset;
                s.score = std::min(1.0f, score);
                s.reason = reason.isEmpty() ? "Based on your preferences" : reason;
                suggestions.push_back(s);
            }
        }

        // Sort by score
        std::sort(suggestions.begin(), suggestions.end(),
            [](const Suggestion& a, const Suggestion& b) {
                return a.score > b.score;
            });

        // Limit results
        if (suggestions.size() > 10)
            suggestions.resize(10);

        return suggestions;
    }

    std::vector<Suggestion> getSimilarPresets(
        const Preset& reference,
        const std::vector<Preset>& presets)
    {
        std::vector<Suggestion> suggestions;

        for (const auto& preset : presets)
        {
            if (preset.id == reference.id)
                continue;

            float score = 0.0f;

            // Same category
            if (preset.category == reference.category)
                score += 0.3f;

            // Same subcategory
            if (preset.subcategory == reference.subcategory)
                score += 0.2f;

            // Tag overlap
            int commonTags = 0;
            for (const auto& tag : preset.tags)
            {
                if (reference.tags.contains(tag))
                    commonTags++;
            }
            score += commonTags * 0.1f;

            // Similar mood
            if (preset.moodTag == reference.moodTag)
                score += 0.15f;

            // Similar coherence level
            float coherenceDiff = std::abs(preset.idealCoherence - reference.idealCoherence);
            if (coherenceDiff < 0.1f)
                score += 0.1f;

            if (score > 0.3f)
            {
                Suggestion s;
                s.preset = preset;
                s.score = std::min(1.0f, score);
                s.reason = "Similar to " + reference.name;
                suggestions.push_back(s);
            }
        }

        std::sort(suggestions.begin(), suggestions.end(),
            [](const Suggestion& a, const Suggestion& b) {
                return a.score > b.score;
            });

        if (suggestions.size() > 5)
            suggestions.resize(5);

        return suggestions;
    }
};

//==============================================================================
/**
    Main Preset Manager
*/
class PresetManager
{
public:
    //--------------------------------------------------------------------------
    static PresetManager& getInstance()
    {
        static PresetManager instance;
        return instance;
    }

    //--------------------------------------------------------------------------
    void initialize(const juce::File& presetsDirectory)
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        presetsDir = presetsDirectory;

        if (!presetsDir.exists())
            presetsDir.createDirectory();

        // Create subdirectories
        presetsDir.getChildFile("Factory").createDirectory();
        presetsDir.getChildFile("User").createDirectory();
        presetsDir.getChildFile("Banks").createDirectory();

        // Load all presets
        loadAllPresets();

        initialized = true;
    }

    void shutdown()
    {
        std::lock_guard<std::mutex> lock(managerMutex);
        saveAllPresets();
        presets.clear();
        banks.clear();
        initialized = false;
    }

    //--------------------------------------------------------------------------
    // Preset CRUD
    juce::String savePreset(const Preset& preset)
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        Preset p = preset;
        p.modified = juce::Time::getCurrentTime();

        if (p.created.toMilliseconds() == 0)
            p.created = p.modified;

        presets[p.id] = p;
        savePresetToFile(p);

        if (onPresetSaved)
            onPresetSaved(p);

        return p.id;
    }

    Preset loadPreset(const juce::String& presetId)
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        auto it = presets.find(presetId);
        if (it != presets.end())
        {
            // Update usage stats
            it->second.useCount++;
            it->second.lastUsed = juce::Time::getCurrentTime();
            recentlyUsed.insert(recentlyUsed.begin(), presetId);

            if (recentlyUsed.size() > 20)
                recentlyUsed.resize(20);

            return it->second;
        }

        return Preset();
    }

    void deletePreset(const juce::String& presetId)
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        auto it = presets.find(presetId);
        if (it != presets.end())
        {
            if (it->second.isReadOnly)
                return;

            // Remove from any banks
            for (auto& bank : banks)
            {
                bank.second.presetIds.removeString(presetId);
            }

            // Delete file
            juce::File presetFile = getPresetFile(it->second);
            if (presetFile.exists())
                presetFile.deleteFile();

            presets.erase(it);

            if (onPresetDeleted)
                onPresetDeleted(presetId);
        }
    }

    void renamePreset(const juce::String& presetId, const juce::String& newName)
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        auto it = presets.find(presetId);
        if (it != presets.end() && !it->second.isReadOnly)
        {
            it->second.name = newName;
            it->second.modified = juce::Time::getCurrentTime();
            savePresetToFile(it->second);
        }
    }

    //--------------------------------------------------------------------------
    // Preset retrieval
    Preset getPreset(const juce::String& presetId) const
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        auto it = presets.find(presetId);
        if (it != presets.end())
            return it->second;

        return Preset();
    }

    std::vector<Preset> getAllPresets() const
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        std::vector<Preset> result;
        for (const auto& pair : presets)
            result.push_back(pair.second);

        return result;
    }

    std::vector<Preset> getPresetsForTarget(const juce::String& targetType) const
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        std::vector<Preset> result;
        for (const auto& pair : presets)
        {
            if (pair.second.targetType == targetType)
                result.push_back(pair.second);
        }

        return result;
    }

    //--------------------------------------------------------------------------
    // Filtering and search
    std::vector<Preset> searchPresets(const PresetFilter& filter) const
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        std::vector<Preset> result;

        for (const auto& pair : presets)
        {
            const Preset& p = pair.second;

            // Text search
            if (filter.searchText.isNotEmpty())
            {
                bool matches = p.name.containsIgnoreCase(filter.searchText) ||
                              p.description.containsIgnoreCase(filter.searchText) ||
                              p.author.containsIgnoreCase(filter.searchText);

                for (const auto& tag : p.tags)
                {
                    if (tag.containsIgnoreCase(filter.searchText))
                    {
                        matches = true;
                        break;
                    }
                }

                if (!matches)
                    continue;
            }

            // Category filter
            if (!filter.categories.isEmpty() && !filter.categories.contains(p.category))
                continue;

            // Tag filter
            if (!filter.tags.isEmpty())
            {
                bool hasTag = false;
                for (const auto& tag : filter.tags)
                {
                    if (p.tags.contains(tag))
                    {
                        hasTag = true;
                        break;
                    }
                }
                if (!hasTag)
                    continue;
            }

            // Author filter
            if (filter.author.isNotEmpty() && p.author != filter.author)
                continue;

            // Favorites filter
            if (filter.favoritesOnly && !p.isFavorite)
                continue;

            // Rating filter
            if (p.rating < filter.minRating)
                continue;

            // Bio-state filter
            if (filter.matchBioState)
            {
                float diff = std::abs(p.idealCoherence - filter.currentCoherence);
                if (diff > filter.coherenceTolerance)
                    continue;
            }

            // Mood filter
            if (filter.moodTag.isNotEmpty() && p.moodTag != filter.moodTag)
                continue;

            result.push_back(p);
        }

        return result;
    }

    //--------------------------------------------------------------------------
    // Categories and tags
    juce::StringArray getAllCategories() const
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        std::set<juce::String> categories;
        for (const auto& pair : presets)
        {
            if (pair.second.category.isNotEmpty())
                categories.insert(pair.second.category);
        }

        juce::StringArray result;
        for (const auto& cat : categories)
            result.add(cat);

        return result;
    }

    juce::StringArray getAllTags() const
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        std::set<juce::String> tags;
        for (const auto& pair : presets)
        {
            for (const auto& tag : pair.second.tags)
                tags.insert(tag);
        }

        juce::StringArray result;
        for (const auto& tag : tags)
            result.add(tag);

        return result;
    }

    //--------------------------------------------------------------------------
    // Favorites
    void setFavorite(const juce::String& presetId, bool isFavorite)
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        auto it = presets.find(presetId);
        if (it != presets.end())
        {
            it->second.isFavorite = isFavorite;
            savePresetToFile(it->second);
        }
    }

    std::vector<Preset> getFavorites() const
    {
        PresetFilter filter;
        filter.favoritesOnly = true;
        return searchPresets(filter);
    }

    //--------------------------------------------------------------------------
    // Rating
    void setRating(const juce::String& presetId, float rating)
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        auto it = presets.find(presetId);
        if (it != presets.end())
        {
            it->second.rating = juce::jlimit(0.0f, 5.0f, rating);
            savePresetToFile(it->second);
        }
    }

    //--------------------------------------------------------------------------
    // Banks
    juce::String createBank(const juce::String& name)
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        PresetBank bank;
        bank.name = name;

        banks[bank.id] = bank;
        saveBankToFile(bank);

        return bank.id;
    }

    void addPresetToBank(const juce::String& presetId, const juce::String& bankId)
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        auto it = banks.find(bankId);
        if (it != banks.end() && !it->second.isFactory)
        {
            if (!it->second.presetIds.contains(presetId))
            {
                it->second.presetIds.add(presetId);
                saveBankToFile(it->second);
            }
        }
    }

    void removePresetFromBank(const juce::String& presetId, const juce::String& bankId)
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        auto it = banks.find(bankId);
        if (it != banks.end() && !it->second.isFactory)
        {
            it->second.presetIds.removeString(presetId);
            saveBankToFile(it->second);
        }
    }

    std::vector<PresetBank> getAllBanks() const
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        std::vector<PresetBank> result;
        for (const auto& pair : banks)
            result.push_back(pair.second);

        return result;
    }

    std::vector<Preset> getPresetsInBank(const juce::String& bankId) const
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        std::vector<Preset> result;

        auto it = banks.find(bankId);
        if (it != banks.end())
        {
            for (const auto& presetId : it->second.presetIds)
            {
                auto presetIt = presets.find(presetId);
                if (presetIt != presets.end())
                    result.push_back(presetIt->second);
            }
        }

        return result;
    }

    //--------------------------------------------------------------------------
    // AI Suggestions
    std::vector<PresetSuggestionEngine::Suggestion> getSuggestions(
        const juce::String& context = "")
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        // Get current bio state
        float coherence = 0.5f;
        auto& api = RalphWiggum::RalphWiggumAPI::getInstance();
        auto stats = api.getBioStats();
        coherence = stats.currentCoherence;

        std::vector<Preset> allPresets;
        for (const auto& pair : presets)
            allPresets.push_back(pair.second);

        juce::StringArray recent;
        for (const auto& id : recentlyUsed)
            recent.add(id);

        return suggestionEngine.getSuggestions(context, allPresets, coherence, recent);
    }

    std::vector<PresetSuggestionEngine::Suggestion> getSimilarPresets(
        const juce::String& presetId)
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        auto it = presets.find(presetId);
        if (it == presets.end())
            return {};

        std::vector<Preset> allPresets;
        for (const auto& pair : presets)
            allPresets.push_back(pair.second);

        return suggestionEngine.getSimilarPresets(it->second, allPresets);
    }

    //--------------------------------------------------------------------------
    // Import/Export
    bool exportPreset(const juce::String& presetId, const juce::File& file)
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        auto it = presets.find(presetId);
        if (it == presets.end())
            return false;

        return serializePreset(it->second, file);
    }

    juce::String importPreset(const juce::File& file)
    {
        Preset preset = deserializePreset(file);
        if (preset.name.isEmpty())
            return "";

        // Assign new ID to avoid conflicts
        preset.id = juce::Uuid().toString();
        preset.isFactory = false;
        preset.isReadOnly = false;

        return savePreset(preset);
    }

    bool exportBank(const juce::String& bankId, const juce::File& directory)
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        auto it = banks.find(bankId);
        if (it == banks.end())
            return false;

        if (!directory.exists())
            directory.createDirectory();

        // Export bank metadata
        juce::var bankData;
        bankData["id"] = it->second.id.toStdString();
        bankData["name"] = it->second.name.toStdString();
        bankData["description"] = it->second.description.toStdString();

        juce::File metaFile = directory.getChildFile("bank.json");
        metaFile.replaceWithText(juce::JSON::toString(bankData));

        // Export each preset
        for (const auto& presetId : it->second.presetIds)
        {
            auto presetIt = presets.find(presetId);
            if (presetIt != presets.end())
            {
                juce::File presetFile = directory.getChildFile(
                    presetIt->second.name + ".echopreset");
                serializePreset(presetIt->second, presetFile);
            }
        }

        return true;
    }

    //--------------------------------------------------------------------------
    // Recently used
    std::vector<Preset> getRecentlyUsed(int maxCount = 10) const
    {
        std::lock_guard<std::mutex> lock(managerMutex);

        std::vector<Preset> result;

        for (const auto& id : recentlyUsed)
        {
            if (result.size() >= static_cast<size_t>(maxCount))
                break;

            auto it = presets.find(id);
            if (it != presets.end())
                result.push_back(it->second);
        }

        return result;
    }

    //--------------------------------------------------------------------------
    // Callbacks
    void setOnPresetSaved(std::function<void(const Preset&)> callback)
    {
        onPresetSaved = callback;
    }

    void setOnPresetDeleted(std::function<void(const juce::String&)> callback)
    {
        onPresetDeleted = callback;
    }

private:
    PresetManager() = default;
    ~PresetManager() { shutdown(); }

    PresetManager(const PresetManager&) = delete;
    PresetManager& operator=(const PresetManager&) = delete;

    //--------------------------------------------------------------------------
    void loadAllPresets()
    {
        // Load factory presets
        loadPresetsFromDirectory(presetsDir.getChildFile("Factory"), true);

        // Load user presets
        loadPresetsFromDirectory(presetsDir.getChildFile("User"), false);

        // Load banks
        loadBanksFromDirectory(presetsDir.getChildFile("Banks"));
    }

    void loadPresetsFromDirectory(const juce::File& dir, bool isFactory)
    {
        if (!dir.exists())
            return;

        juce::Array<juce::File> files;
        dir.findChildFiles(files, juce::File::findFiles, true, "*.echopreset");

        for (const auto& file : files)
        {
            Preset preset = deserializePreset(file);
            if (preset.name.isNotEmpty())
            {
                preset.isFactory = isFactory;
                preset.isReadOnly = isFactory;
                presets[preset.id] = preset;
            }
        }
    }

    void loadBanksFromDirectory(const juce::File& dir)
    {
        if (!dir.exists())
            return;

        juce::Array<juce::File> files;
        dir.findChildFiles(files, juce::File::findFiles, true, "*.echobank");

        for (const auto& file : files)
        {
            PresetBank bank = deserializeBank(file);
            if (bank.name.isNotEmpty())
            {
                banks[bank.id] = bank;
            }
        }
    }

    void saveAllPresets()
    {
        for (const auto& pair : presets)
        {
            if (!pair.second.isFactory)
                savePresetToFile(pair.second);
        }

        for (const auto& pair : banks)
        {
            if (!pair.second.isFactory)
                saveBankToFile(pair.second);
        }
    }

    juce::File getPresetFile(const Preset& preset)
    {
        juce::String subdir = preset.isFactory ? "Factory" : "User";
        juce::String category = preset.category.isEmpty() ? "Uncategorized" : preset.category;

        juce::File categoryDir = presetsDir.getChildFile(subdir).getChildFile(category);
        if (!categoryDir.exists())
            categoryDir.createDirectory();

        return categoryDir.getChildFile(preset.id + ".echopreset");
    }

    void savePresetToFile(const Preset& preset)
    {
        juce::File file = getPresetFile(preset);
        serializePreset(preset, file);
    }

    void saveBankToFile(const PresetBank& bank)
    {
        juce::File file = presetsDir.getChildFile("Banks").getChildFile(bank.id + ".echobank");
        serializeBank(bank, file);
    }

    //--------------------------------------------------------------------------
    bool serializePreset(const Preset& preset, const juce::File& file)
    {
        juce::var data;

        data["id"] = preset.id.toStdString();
        data["name"] = preset.name.toStdString();
        data["author"] = preset.author.toStdString();
        data["created"] = preset.created.toMilliseconds();
        data["modified"] = preset.modified.toMilliseconds();
        data["version"] = preset.version;
        data["category"] = preset.category.toStdString();
        data["subcategory"] = preset.subcategory.toStdString();
        data["description"] = preset.description.toStdString();
        data["isFavorite"] = preset.isFavorite;
        data["rating"] = preset.rating;
        data["useCount"] = preset.useCount;
        data["lastUsed"] = preset.lastUsed.toMilliseconds();
        data["targetType"] = preset.targetType.toStdString();
        data["idealCoherence"] = preset.idealCoherence;
        data["moodTag"] = preset.moodTag.toStdString();

        // Tags
        juce::var tagsArray;
        for (const auto& tag : preset.tags)
            tagsArray.append(tag.toStdString());
        data["tags"] = tagsArray;

        // Data (base64 encoded)
        data["data"] = preset.data.toBase64Encoding().toStdString();

        // Metadata
        data["metadata"] = preset.metadata;

        return file.replaceWithText(juce::JSON::toString(data, true));
    }

    Preset deserializePreset(const juce::File& file)
    {
        Preset preset;

        juce::var data = juce::JSON::parse(file);
        if (!data.isObject())
            return preset;

        preset.id = data.getProperty("id", "").toString();
        preset.name = data.getProperty("name", "").toString();
        preset.author = data.getProperty("author", "").toString();
        preset.created = juce::Time(static_cast<int64>(data.getProperty("created", 0)));
        preset.modified = juce::Time(static_cast<int64>(data.getProperty("modified", 0)));
        preset.version = data.getProperty("version", 1);
        preset.category = data.getProperty("category", "").toString();
        preset.subcategory = data.getProperty("subcategory", "").toString();
        preset.description = data.getProperty("description", "").toString();
        preset.isFavorite = data.getProperty("isFavorite", false);
        preset.rating = data.getProperty("rating", 0.0f);
        preset.useCount = data.getProperty("useCount", 0);
        preset.lastUsed = juce::Time(static_cast<int64>(data.getProperty("lastUsed", 0)));
        preset.targetType = data.getProperty("targetType", "").toString();
        preset.idealCoherence = data.getProperty("idealCoherence", 0.5f);
        preset.moodTag = data.getProperty("moodTag", "").toString();

        // Tags
        auto tagsArray = data.getProperty("tags", juce::var());
        if (tagsArray.isArray())
        {
            for (int i = 0; i < tagsArray.size(); ++i)
                preset.tags.add(tagsArray[i].toString());
        }

        // Data
        juce::String dataBase64 = data.getProperty("data", "").toString();
        if (dataBase64.isNotEmpty())
            preset.data.fromBase64Encoding(dataBase64);

        // Metadata
        preset.metadata = data.getProperty("metadata", juce::var());

        return preset;
    }

    void serializeBank(const PresetBank& bank, const juce::File& file)
    {
        juce::var data;

        data["id"] = bank.id.toStdString();
        data["name"] = bank.name.toStdString();
        data["author"] = bank.author.toStdString();
        data["description"] = bank.description.toStdString();

        juce::var presetIds;
        for (const auto& id : bank.presetIds)
            presetIds.append(id.toStdString());
        data["presetIds"] = presetIds;

        file.replaceWithText(juce::JSON::toString(data, true));
    }

    PresetBank deserializeBank(const juce::File& file)
    {
        PresetBank bank;

        juce::var data = juce::JSON::parse(file);
        if (!data.isObject())
            return bank;

        bank.id = data.getProperty("id", "").toString();
        bank.name = data.getProperty("name", "").toString();
        bank.author = data.getProperty("author", "").toString();
        bank.description = data.getProperty("description", "").toString();

        auto presetIds = data.getProperty("presetIds", juce::var());
        if (presetIds.isArray())
        {
            for (int i = 0; i < presetIds.size(); ++i)
                bank.presetIds.add(presetIds[i].toString());
        }

        return bank;
    }

    //--------------------------------------------------------------------------
    mutable std::mutex managerMutex;
    bool initialized = false;

    juce::File presetsDir;
    std::map<juce::String, Preset> presets;
    std::map<juce::String, PresetBank> banks;
    std::vector<juce::String> recentlyUsed;

    PresetSuggestionEngine suggestionEngine;

    std::function<void(const Preset&)> onPresetSaved;
    std::function<void(const juce::String&)> onPresetDeleted;
};

} // namespace Core
} // namespace Echoel
