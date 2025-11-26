#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>

namespace echoelmusic {
namespace plugin {

/**
 * @brief VST3/AU Plugin Manager - Host user's plugins!
 *
 * CRITICAL MVP FEATURE - Makes Echoelmusic competitive!
 *
 * Users can:
 * - Load their existing VST3/AU plugins
 * - Use 3rd party effects (Fabfilter, Waves, etc.)
 * - Use 3rd party instruments
 * - Save plugin states in projects
 *
 * This is what makes us INTEGRATION not REPLACEMENT!
 *
 * @author Claude Code (ULTRATHINK SUPER LASER MODE)
 * @date 2025-11-18
 */
class PluginManager
{
public:
    /**
     * @brief Plugin info structure
     */
    struct PluginInfo
    {
        juce::String name;
        juce::String manufacturer;
        juce::String category;  // Instrument, Effect, etc.
        juce::String filePath;
        juce::String pluginFormatName;  // VST3, AU, etc.
        juce::PluginDescription description;
    };

    /**
     * @brief Get singleton instance
     */
    static PluginManager& getInstance();

    /**
     * @brief Initialize plugin manager
     *
     * @param scanOnStartup If true, scan for plugins on initialization
     */
    bool initialize(bool scanOnStartup = true);

    /**
     * @brief Scan for plugins
     *
     * This scans standard plugin directories for VST3, AU, etc.
     * Can take a while (30 seconds to 5 minutes depending on plugins installed)
     *
     * @param progressCallback Optional callback for progress updates (0.0 to 1.0)
     */
    void scanForPlugins(std::function<void(float progress, const juce::String& status)> progressCallback = nullptr);

    /**
     * @brief Get list of available plugins
     *
     * @return Vector of plugin info
     */
    std::vector<PluginInfo> getAvailablePlugins() const;

    /**
     * @brief Get plugins by category
     *
     * @param category "Instrument", "Effect", "Synth", etc.
     * @return Filtered plugin list
     */
    std::vector<PluginInfo> getPluginsByCategory(const juce::String& category) const;

    /**
     * @brief Load plugin instance
     *
     * @param pluginInfo Plugin to load
     * @return Plugin instance (nullptr if failed)
     */
    std::unique_ptr<juce::AudioPluginInstance> loadPlugin(const PluginInfo& pluginInfo);

    /**
     * @brief Load plugin by name
     *
     * @param pluginName Name of plugin to load
     * @return Plugin instance (nullptr if not found)
     */
    std::unique_ptr<juce::AudioPluginInstance> loadPluginByName(const juce::String& pluginName);

    /**
     * @brief Save plugin state
     *
     * @param plugin Plugin instance
     * @return State as MemoryBlock
     */
    juce::MemoryBlock savePluginState(juce::AudioPluginInstance* plugin) const;

    /**
     * @brief Load plugin state
     *
     * @param plugin Plugin instance
     * @param state State to restore
     * @return true if successful
     */
    bool loadPluginState(juce::AudioPluginInstance* plugin, const juce::MemoryBlock& state);

    /**
     * @brief Get plugin formats manager
     *
     * @return JUCE plugin format manager
     */
    juce::AudioPluginFormatManager& getFormatManager();

    /**
     * @brief Get known plugins list (cached scan results)
     *
     * @return Known plugins list
     */
    juce::KnownPluginList& getKnownPluginsList();

    /**
     * @brief Save plugin list to file (cache scan results)
     *
     * @param file File to save to
     */
    void savePluginList(const juce::File& file);

    /**
     * @brief Load plugin list from file (load cached scan)
     *
     * @param file File to load from
     * @return true if loaded successfully
     */
    bool loadPluginList(const juce::File& file);

    /**
     * @brief Check if plugin scan is in progress
     */
    bool isScanningPlugins() const { return m_isScanning; }

    /**
     * @brief Cancel ongoing plugin scan
     */
    void cancelScan();

private:
    PluginManager();
    ~PluginManager();

    // Prevent copying
    PluginManager(const PluginManager&) = delete;
    PluginManager& operator=(const PluginManager&) = delete;

    /**
     * @brief Get default plugin list file path
     */
    juce::File getPluginListFile() const;

    /**
     * @brief Add plugin formats (VST3, AU, etc.)
     */
    void setupPluginFormats();

    /**
     * @brief Get plugin search paths for current platform
     */
    juce::FileSearchPath getPluginSearchPaths() const;

private:
    bool m_initialized = false;
    bool m_isScanning = false;

    // JUCE plugin management
    juce::AudioPluginFormatManager m_formatManager;
    juce::KnownPluginList m_knownPluginList;

    // Plugin directory watcher (for detecting new plugins)
    std::unique_ptr<juce::FileSystemWatcher> m_pluginWatcher;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PluginManager)
};

} // namespace plugin
} // namespace echoelmusic
