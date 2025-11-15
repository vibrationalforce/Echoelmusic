#pragma once

#include <JuceHeader.h>
#include <vector>
#include <unordered_map>

namespace Echoelmusic {

/**
 * PluginScanner - Scans and validates VST3, AU, and CLAP plugins
 *
 * Features:
 * - Multi-format support (VST3, AudioUnit, CLAP)
 * - Async scanning with progress callbacks
 * - Plugin validation and blacklisting
 * - Metadata caching for fast startup
 * - Crash protection during scanning
 */
class PluginScanner {
public:
    PluginScanner();
    ~PluginScanner();

    // Plugin scanning
    void scanForPlugins(std::function<void(float)> progressCallback = nullptr);
    void scanFolder(const juce::File& folder);
    void rescanFailedPlugins();

    // Plugin information
    struct PluginInfo {
        juce::String name;
        juce::String manufacturer;
        juce::String version;
        juce::String pluginFormatName;
        juce::String fileOrIdentifier;
        juce::String category;
        int numInputChannels;
        int numOutputChannels;
        bool isInstrument;
        bool hasEditor;
        juce::String uid;
        juce::Time lastModified;

        // Validation status
        bool validated = false;
        bool blacklisted = false;
        juce::String failureReason;
    };

    // Access plugin list
    const std::vector<PluginInfo>& getPluginList() const { return pluginList; }
    std::vector<PluginInfo> getPluginsByCategory(const juce::String& category) const;
    std::vector<PluginInfo> getInstruments() const;
    std::vector<PluginInfo> getEffects() const;

    // Search
    std::vector<PluginInfo> searchPlugins(const juce::String& searchText) const;
    const PluginInfo* findPluginByUID(const juce::String& uid) const;

    // Blacklist management
    void blacklistPlugin(const juce::String& uid, const juce::String& reason);
    void removeFromBlacklist(const juce::String& uid);
    bool isBlacklisted(const juce::String& uid) const;

    // Cache management
    void saveCacheToFile(const juce::File& cacheFile);
    void loadCacheFromFile(const juce::File& cacheFile);
    void clearCache();

private:
    std::vector<PluginInfo> pluginList;
    std::unordered_map<juce::String, juce::String> blacklistedPlugins;  // uid -> reason

    // Plugin format managers
    std::unique_ptr<juce::AudioPluginFormatManager> formatManager;
    std::unique_ptr<juce::VST3PluginFormat> vst3Format;
    std::unique_ptr<juce::AudioUnitPluginFormat> auFormat;

    // Scanning
    void scanFormat(juce::AudioPluginFormat* format,
                   const juce::StringArray& searchPaths,
                   std::function<void(float)> progressCallback);

    bool validatePlugin(const juce::PluginDescription& desc);
    PluginInfo convertDescription(const juce::PluginDescription& desc);

    // Categories
    juce::String inferCategory(const juce::PluginDescription& desc);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PluginScanner)
};

} // namespace Echoelmusic
