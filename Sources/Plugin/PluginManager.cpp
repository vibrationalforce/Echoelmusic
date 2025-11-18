#include "PluginManager.h"

namespace echoelmusic {
namespace plugin {

// ============================================================================
// SINGLETON
// ============================================================================

PluginManager& PluginManager::getInstance()
{
    static PluginManager instance;
    return instance;
}

// ============================================================================
// CONSTRUCTOR / DESTRUCTOR
// ============================================================================

PluginManager::PluginManager()
{
}

PluginManager::~PluginManager()
{
}

// ============================================================================
// INITIALIZATION
// ============================================================================

bool PluginManager::initialize(bool scanOnStartup)
{
    if (m_initialized)
        return true;

    DBG("Plugin Manager initializing...");

    // Setup plugin formats (VST3, AU, etc.)
    setupPluginFormats();

    // Try to load cached plugin list
    juce::File pluginListFile = getPluginListFile();
    if (pluginListFile.existsAsFile())
    {
        if (loadPluginList(pluginListFile))
        {
            DBG("Loaded cached plugin list: " + juce::String(m_knownPluginList.getNumTypes()) + " plugins");
        }
    }

    // Scan for plugins if requested (or if cache is empty)
    if (scanOnStartup || m_knownPluginList.getNumTypes() == 0)
    {
        DBG("Scanning for plugins...");
        scanForPlugins();
    }

    m_initialized = true;
    return true;
}

void PluginManager::setupPluginFormats()
{
    // Add VST3 format
    #if (JUCE_PLUGINHOST_VST3 && (JUCE_MAC || JUCE_WINDOWS || JUCE_LINUX))
        m_formatManager.addDefaultFormats();
        DBG("VST3 support enabled");
    #endif

    // Add AU format (macOS only)
    #if (JUCE_PLUGINHOST_AU && JUCE_MAC)
        DBG("Audio Units support enabled");
    #endif

    // Add AAX format (if SDK available)
    #if JUCE_PLUGINHOST_AAX
        DBG("AAX support enabled");
    #endif

    // Add LADSPA format (Linux)
    #if (JUCE_PLUGINHOST_LADSPA && JUCE_LINUX)
        DBG("LADSPA support enabled");
    #endif
}

juce::FileSearchPath PluginManager::getPluginSearchPaths() const
{
    juce::FileSearchPath paths;

    #if JUCE_MAC
        // macOS plugin paths
        paths.add(juce::File("/Library/Audio/Plug-Ins/VST3"));
        paths.add(juce::File("/Library/Audio/Plug-Ins/Components"));  // AU
        paths.add(juce::File("~/Library/Audio/Plug-Ins/VST3"));
        paths.add(juce::File("~/Library/Audio/Plug-Ins/Components"));
    #elif JUCE_WINDOWS
        // Windows plugin paths
        paths.add(juce::File("C:\\Program Files\\Common Files\\VST3"));
        paths.add(juce::File("C:\\Program Files (x86)\\Common Files\\VST3"));
        paths.add(juce::File("C:\\Program Files\\VSTPlugins"));
    #elif JUCE_LINUX
        // Linux plugin paths
        paths.add(juce::File("/usr/lib/vst3"));
        paths.add(juce::File("/usr/local/lib/vst3"));
        paths.add(juce::File("~/.vst3"));
        paths.add(juce::File("/usr/lib/ladspa"));
        paths.add(juce::File("/usr/local/lib/ladspa"));
    #endif

    return paths;
}

// ============================================================================
// PLUGIN SCANNING
// ============================================================================

void PluginManager::scanForPlugins(
    std::function<void(float, const juce::String&)> progressCallback)
{
    if (m_isScanning)
    {
        DBG("Error: Plugin scan already in progress!");
        return;
    }

    m_isScanning = true;

    auto searchPaths = getPluginSearchPaths();

    DBG("Scanning for plugins in:");
    for (int i = 0; i < searchPaths.getNumPaths(); ++i)
    {
        DBG("  - " + searchPaths[i].getFullPathName());
    }

    // Scan each format
    for (int i = 0; i < m_formatManager.getNumFormats(); ++i)
    {
        auto* format = m_formatManager.getFormat(i);
        if (format == nullptr)
            continue;

        DBG("Scanning " + format->getName() + " plugins...");

        if (progressCallback)
        {
            float progress = (float)i / m_formatManager.getNumFormats();
            progressCallback(progress, "Scanning " + format->getName() + "...");
        }

        juce::PluginDirectoryScanner scanner(
            m_knownPluginList,
            *format,
            searchPaths,
            true,  // Search recursively
            juce::File(),  // Temp file for dead plugins
            true   // Allow async scanning
        );

        juce::String pluginBeingScanned;

        while (scanner.scanNextFile(true, pluginBeingScanned))
        {
            DBG("Found: " + pluginBeingScanned);

            if (progressCallback)
            {
                float progress = (float)i / m_formatManager.getNumFormats() +
                                 scanner.getProgress() / m_formatManager.getNumFormats();
                progressCallback(progress, "Scanning: " + pluginBeingScanned);
            }
        }
    }

    // Save plugin list to cache
    savePluginList(getPluginListFile());

    m_isScanning = false;

    DBG("Plugin scan complete: " + juce::String(m_knownPluginList.getNumTypes()) + " plugins found");

    if (progressCallback)
    {
        progressCallback(1.0f, "Scan complete!");
    }
}

void PluginManager::cancelScan()
{
    // TODO: Implement scan cancellation
    m_isScanning = false;
}

// ============================================================================
// PLUGIN QUERYING
// ============================================================================

std::vector<PluginManager::PluginInfo> PluginManager::getAvailablePlugins() const
{
    std::vector<PluginInfo> result;

    for (const auto& type : m_knownPluginList.getTypes())
    {
        PluginInfo info;
        info.name = type.name;
        info.manufacturer = type.manufacturerName;
        info.category = type.category;
        info.filePath = type.fileOrIdentifier;
        info.pluginFormatName = type.pluginFormatName;
        info.description = type;

        result.push_back(info);
    }

    return result;
}

std::vector<PluginManager::PluginInfo> PluginManager::getPluginsByCategory(
    const juce::String& category) const
{
    std::vector<PluginInfo> result;

    auto allPlugins = getAvailablePlugins();

    for (const auto& plugin : allPlugins)
    {
        if (plugin.category.containsIgnoreCase(category))
        {
            result.push_back(plugin);
        }
    }

    return result;
}

// ============================================================================
// PLUGIN LOADING
// ============================================================================

std::unique_ptr<juce::AudioPluginInstance> PluginManager::loadPlugin(
    const PluginInfo& pluginInfo)
{
    juce::String errorMessage;

    auto instance = m_formatManager.createPluginInstance(
        pluginInfo.description,
        48000.0,  // Sample rate (will be updated later)
        512,       // Block size (will be updated later)
        errorMessage
    );

    if (instance == nullptr)
    {
        DBG("Error loading plugin '" + pluginInfo.name + "': " + errorMessage);
        return nullptr;
    }

    DBG("Loaded plugin: " + pluginInfo.name);
    return instance;
}

std::unique_ptr<juce::AudioPluginInstance> PluginManager::loadPluginByName(
    const juce::String& pluginName)
{
    // Find plugin in known plugins list
    for (const auto& type : m_knownPluginList.getTypes())
    {
        if (type.name.containsIgnoreCase(pluginName))
        {
            PluginInfo info;
            info.description = type;
            info.name = type.name;
            info.manufacturer = type.manufacturerName;
            info.category = type.category;
            info.filePath = type.fileOrIdentifier;
            info.pluginFormatName = type.pluginFormatName;

            return loadPlugin(info);
        }
    }

    DBG("Error: Plugin not found: " + pluginName);
    return nullptr;
}

// ============================================================================
// PLUGIN STATE MANAGEMENT
// ============================================================================

juce::MemoryBlock PluginManager::savePluginState(juce::AudioPluginInstance* plugin) const
{
    if (plugin == nullptr)
        return juce::MemoryBlock();

    juce::MemoryBlock state;
    plugin->getStateInformation(state);

    DBG("Saved plugin state for '" + plugin->getName() + "': " +
        juce::String(state.getSize()) + " bytes");

    return state;
}

bool PluginManager::loadPluginState(
    juce::AudioPluginInstance* plugin,
    const juce::MemoryBlock& state)
{
    if (plugin == nullptr || state.isEmpty())
        return false;

    plugin->setStateInformation(state.getData(), (int)state.getSize());

    DBG("Restored plugin state for '" + plugin->getName() + "'");
    return true;
}

// ============================================================================
// ACCESSORS
// ============================================================================

juce::AudioPluginFormatManager& PluginManager::getFormatManager()
{
    return m_formatManager;
}

juce::KnownPluginList& PluginManager::getKnownPluginsList()
{
    return m_knownPluginList;
}

// ============================================================================
// PERSISTENCE
// ============================================================================

juce::File PluginManager::getPluginListFile() const
{
    return juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory)
        .getChildFile("Echoelmusic")
        .getChildFile("PluginList.xml");
}

void PluginManager::savePluginList(const juce::File& file)
{
    file.getParentDirectory().createDirectory();

    auto xml = m_knownPluginList.createXml();
    if (xml != nullptr)
    {
        if (xml->writeTo(file, juce::XmlElement::TextFormat()))
        {
            DBG("Saved plugin list to: " + file.getFullPathName());
        }
        else
        {
            DBG("Error: Failed to save plugin list!");
        }
    }
}

bool PluginManager::loadPluginList(const juce::File& file)
{
    if (!file.existsAsFile())
        return false;

    auto xml = juce::parseXML(file);
    if (xml == nullptr)
    {
        DBG("Error: Failed to parse plugin list XML!");
        return false;
    }

    m_knownPluginList.recreateFromXml(*xml);

    DBG("Loaded plugin list from: " + file.getFullPathName());
    return true;
}

} // namespace plugin
} // namespace echoelmusic
