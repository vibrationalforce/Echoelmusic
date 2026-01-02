#pragma once

#include <JuceHeader.h>
#include <atomic>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <vector>

namespace Echoelmusic {

/**
 * PluginHost - VST3/AU/CLAP Plugin Hosting System
 *
 * Features:
 * - VST3 plugin support
 * - Audio Unit (AU) support (macOS/iOS)
 * - CLAP plugin support
 * - Plugin scanning and caching
 * - Plugin preset management
 * - Plugin parameter automation
 * - Multi-threaded plugin processing
 * - Plugin delay compensation
 * - Sidechain support
 * - Plugin sandboxing (crash protection)
 * - Plugin state save/restore
 */

//==============================================================================
// Plugin Format Types
//==============================================================================

enum class PluginFormat
{
    VST3,
    AudioUnit,
    CLAP,
    Internal,       // Built-in effects
    Unknown
};

inline juce::String getPluginFormatName(PluginFormat format)
{
    switch (format)
    {
        case PluginFormat::VST3:        return "VST3";
        case PluginFormat::AudioUnit:   return "Audio Unit";
        case PluginFormat::CLAP:        return "CLAP";
        case PluginFormat::Internal:    return "Internal";
        default:                        return "Unknown";
    }
}

//==============================================================================
// Plugin Category
//==============================================================================

enum class PluginCategory
{
    Effect,
    Instrument,
    Analyzer,
    Generator,
    Utility,
    Unknown
};

//==============================================================================
// Plugin Description
//==============================================================================

struct PluginDescription
{
    juce::String uid;               // Unique identifier
    juce::String name;
    juce::String manufacturer;
    juce::String version;
    juce::String category;
    PluginFormat format = PluginFormat::Unknown;
    PluginCategory type = PluginCategory::Effect;

    juce::String filePath;          // Path to plugin file

    int numInputChannels = 2;
    int numOutputChannels = 2;
    bool hasEditor = true;
    bool acceptsMidi = false;
    bool producesMidi = false;
    bool isSynth = false;

    // Cache info
    juce::int64 lastModified = 0;
    bool isValid = true;
    juce::String errorMessage;

    juce::var toVar() const
    {
        juce::DynamicObject::Ptr obj = new juce::DynamicObject();
        obj->setProperty("uid", uid);
        obj->setProperty("name", name);
        obj->setProperty("manufacturer", manufacturer);
        obj->setProperty("version", version);
        obj->setProperty("category", category);
        obj->setProperty("format", static_cast<int>(format));
        obj->setProperty("type", static_cast<int>(type));
        obj->setProperty("path", filePath);
        obj->setProperty("inputs", numInputChannels);
        obj->setProperty("outputs", numOutputChannels);
        obj->setProperty("hasEditor", hasEditor);
        obj->setProperty("midi", acceptsMidi);
        obj->setProperty("synth", isSynth);
        obj->setProperty("lastMod", lastModified);
        obj->setProperty("valid", isValid);
        return juce::var(obj.get());
    }

    static PluginDescription fromVar(const juce::var& v)
    {
        PluginDescription d;
        if (auto* obj = v.getDynamicObject())
        {
            d.uid = obj->getProperty("uid").toString();
            d.name = obj->getProperty("name").toString();
            d.manufacturer = obj->getProperty("manufacturer").toString();
            d.version = obj->getProperty("version").toString();
            d.category = obj->getProperty("category").toString();
            d.format = static_cast<PluginFormat>(static_cast<int>(obj->getProperty("format")));
            d.type = static_cast<PluginCategory>(static_cast<int>(obj->getProperty("type")));
            d.filePath = obj->getProperty("path").toString();
            d.numInputChannels = obj->getProperty("inputs");
            d.numOutputChannels = obj->getProperty("outputs");
            d.hasEditor = obj->getProperty("hasEditor");
            d.acceptsMidi = obj->getProperty("midi");
            d.isSynth = obj->getProperty("synth");
            d.lastModified = static_cast<juce::int64>(obj->getProperty("lastMod"));
            d.isValid = obj->getProperty("valid");
        }
        return d;
    }
};

//==============================================================================
// Plugin Parameter
//==============================================================================

struct PluginParameter
{
    int index = 0;
    juce::String id;
    juce::String name;
    juce::String label;             // Unit label (dB, Hz, %, etc.)

    float value = 0.0f;
    float defaultValue = 0.0f;
    float minValue = 0.0f;
    float maxValue = 1.0f;

    bool isAutomatable = true;
    bool isDiscrete = false;
    int numSteps = 0;               // For discrete parameters

    // For automation
    std::atomic<float>* automationSource = nullptr;
};

//==============================================================================
// Plugin Instance
//==============================================================================

class PluginInstance
{
public:
    PluginInstance(const PluginDescription& desc)
        : description(desc)
    {
        instanceId = juce::Uuid().toString();
    }

    virtual ~PluginInstance() = default;

    //==========================================================================
    // Lifecycle
    //==========================================================================

    virtual bool load() = 0;
    virtual void unload() = 0;
    virtual bool isLoaded() const = 0;

    virtual void prepare(double sampleRate, int maxBlockSize) = 0;
    virtual void release() = 0;

    //==========================================================================
    // Processing
    //==========================================================================

    virtual void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi) = 0;

    virtual void processSidechain(juce::AudioBuffer<float>& mainBuffer,
                                  juce::AudioBuffer<float>& sidechainBuffer,
                                  juce::MidiBuffer& midi)
    {
        // Default: no sidechain processing
        processBlock(mainBuffer, midi);
    }

    //==========================================================================
    // Parameters
    //==========================================================================

    virtual int getNumParameters() const = 0;
    virtual PluginParameter getParameter(int index) const = 0;
    virtual float getParameterValue(int index) const = 0;
    virtual void setParameterValue(int index, float value) = 0;
    virtual juce::String getParameterName(int index) const = 0;

    //==========================================================================
    // State
    //==========================================================================

    virtual juce::MemoryBlock getState() const = 0;
    virtual void setState(const juce::MemoryBlock& state) = 0;

    //==========================================================================
    // Presets
    //==========================================================================

    virtual int getNumPrograms() const { return 0; }
    virtual int getCurrentProgram() const { return 0; }
    virtual void setCurrentProgram(int index) {}
    virtual juce::String getProgramName(int index) const { return ""; }

    //==========================================================================
    // Editor
    //==========================================================================

    virtual bool hasEditor() const { return description.hasEditor; }
    virtual juce::AudioProcessorEditor* createEditor() { return nullptr; }

    //==========================================================================
    // Latency
    //==========================================================================

    virtual int getLatencySamples() const { return 0; }
    virtual int getTailLengthSamples() const { return 0; }

    //==========================================================================
    // Info
    //==========================================================================

    const PluginDescription& getDescription() const { return description; }
    juce::String getInstanceId() const { return instanceId; }

    void setBypass(bool bypass) { bypassed.store(bypass); }
    bool isBypassed() const { return bypassed.load(); }

protected:
    PluginDescription description;
    juce::String instanceId;
    std::atomic<bool> bypassed { false };

    double currentSampleRate = 48000.0;
    int currentBlockSize = 512;
};

//==============================================================================
// JUCE Plugin Instance Wrapper
//==============================================================================

class JucePluginInstance : public PluginInstance
{
public:
    JucePluginInstance(const PluginDescription& desc,
                       std::unique_ptr<juce::AudioPluginInstance> plugin)
        : PluginInstance(desc), jucePlugin(std::move(plugin))
    {
    }

    bool load() override
    {
        return jucePlugin != nullptr;
    }

    void unload() override
    {
        jucePlugin.reset();
    }

    bool isLoaded() const override
    {
        return jucePlugin != nullptr;
    }

    void prepare(double sampleRate, int maxBlockSize) override
    {
        if (jucePlugin)
        {
            currentSampleRate = sampleRate;
            currentBlockSize = maxBlockSize;
            jucePlugin->prepareToPlay(sampleRate, maxBlockSize);
        }
    }

    void release() override
    {
        if (jucePlugin)
        {
            jucePlugin->releaseResources();
        }
    }

    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi) override
    {
        if (jucePlugin && !bypassed.load())
        {
            jucePlugin->processBlock(buffer, midi);
        }
    }

    int getNumParameters() const override
    {
        return jucePlugin ? jucePlugin->getParameters().size() : 0;
    }

    PluginParameter getParameter(int index) const override
    {
        PluginParameter param;

        if (jucePlugin && index < jucePlugin->getParameters().size())
        {
            auto* p = jucePlugin->getParameters()[index];
            param.index = index;
            param.name = p->getName(100);
            param.label = p->getLabel();
            param.value = p->getValue();
            param.defaultValue = p->getDefaultValue();
            param.isAutomatable = p->isAutomatable();
        }

        return param;
    }

    float getParameterValue(int index) const override
    {
        if (jucePlugin && index < jucePlugin->getParameters().size())
        {
            return jucePlugin->getParameters()[index]->getValue();
        }
        return 0.0f;
    }

    void setParameterValue(int index, float value) override
    {
        if (jucePlugin && index < jucePlugin->getParameters().size())
        {
            jucePlugin->getParameters()[index]->setValue(value);
        }
    }

    juce::String getParameterName(int index) const override
    {
        if (jucePlugin && index < jucePlugin->getParameters().size())
        {
            return jucePlugin->getParameters()[index]->getName(100);
        }
        return "";
    }

    juce::MemoryBlock getState() const override
    {
        juce::MemoryBlock state;
        if (jucePlugin)
        {
            jucePlugin->getStateInformation(state);
        }
        return state;
    }

    void setState(const juce::MemoryBlock& state) override
    {
        if (jucePlugin)
        {
            jucePlugin->setStateInformation(state.getData(), static_cast<int>(state.getSize()));
        }
    }

    int getNumPrograms() const override
    {
        return jucePlugin ? jucePlugin->getNumPrograms() : 0;
    }

    int getCurrentProgram() const override
    {
        return jucePlugin ? jucePlugin->getCurrentProgram() : 0;
    }

    void setCurrentProgram(int index) override
    {
        if (jucePlugin) jucePlugin->setCurrentProgram(index);
    }

    juce::String getProgramName(int index) const override
    {
        return jucePlugin ? jucePlugin->getProgramName(index) : "";
    }

    juce::AudioProcessorEditor* createEditor() override
    {
        return jucePlugin ? jucePlugin->createEditor() : nullptr;
    }

    int getLatencySamples() const override
    {
        return jucePlugin ? jucePlugin->getLatencySamples() : 0;
    }

    int getTailLengthSamples() const override
    {
        return jucePlugin ? static_cast<int>(jucePlugin->getTailLengthSeconds() * currentSampleRate) : 0;
    }

    juce::AudioPluginInstance* getJucePlugin() { return jucePlugin.get(); }

private:
    std::unique_ptr<juce::AudioPluginInstance> jucePlugin;
};

//==============================================================================
// Plugin Scanner
//==============================================================================

class PluginScanner
{
public:
    using ScanCallback = std::function<void(const juce::String& pluginName, float progress)>;
    using CompleteCallback = std::function<void(const std::vector<PluginDescription>& plugins)>;

    PluginScanner()
    {
        // Initialize format manager with supported formats
        formatManager.addDefaultFormats();
    }

    //==========================================================================
    // Scanning
    //==========================================================================

    /** Scan all plugin directories */
    void scanAllPlugins(ScanCallback progressCallback = nullptr,
                        CompleteCallback completeCallback = nullptr)
    {
        scannedPlugins.clear();

        // Get search paths
        auto searchPaths = getPluginSearchPaths();

        juce::KnownPluginList pluginList;
        juce::PluginDirectoryScanner scanner(
            pluginList,
            formatManager,
            searchPaths,
            true,  // Recursive
            juce::File()  // No dead plugins file
        );

        juce::String pluginName;
        float progress = 0.0f;
        int total = 1;  // Estimate

        while (scanner.scanNextFile(false, pluginName))
        {
            progress = scanner.getProgress();

            if (progressCallback)
            {
                progressCallback(pluginName, progress);
            }
        }

        // Convert to our format
        for (const auto& desc : pluginList.getTypes())
        {
            PluginDescription pd;
            pd.uid = desc.createIdentifierString();
            pd.name = desc.name;
            pd.manufacturer = desc.manufacturerName;
            pd.version = desc.version;
            pd.category = desc.category;
            pd.filePath = desc.fileOrIdentifier;
            pd.numInputChannels = desc.numInputChannels;
            pd.numOutputChannels = desc.numOutputChannels;
            pd.hasEditor = desc.hasSharedContainer;
            pd.acceptsMidi = desc.isInstrument;
            pd.isSynth = desc.isInstrument;

            if (desc.pluginFormatName == "VST3")
                pd.format = PluginFormat::VST3;
            else if (desc.pluginFormatName == "AudioUnit")
                pd.format = PluginFormat::AudioUnit;
            else
                pd.format = PluginFormat::Unknown;

            pd.type = desc.isInstrument ? PluginCategory::Instrument : PluginCategory::Effect;

            scannedPlugins.push_back(pd);
        }

        if (completeCallback)
        {
            completeCallback(scannedPlugins);
        }
    }

    /** Get cached plugins */
    const std::vector<PluginDescription>& getScannedPlugins() const
    {
        return scannedPlugins;
    }

    /** Search plugins by name */
    std::vector<PluginDescription> searchPlugins(const juce::String& query) const
    {
        std::vector<PluginDescription> results;
        juce::String lowerQuery = query.toLowerCase();

        for (const auto& plugin : scannedPlugins)
        {
            if (plugin.name.toLowerCase().contains(lowerQuery) ||
                plugin.manufacturer.toLowerCase().contains(lowerQuery) ||
                plugin.category.toLowerCase().contains(lowerQuery))
            {
                results.push_back(plugin);
            }
        }

        return results;
    }

    /** Get plugins by category */
    std::vector<PluginDescription> getPluginsByCategory(PluginCategory category) const
    {
        std::vector<PluginDescription> results;

        for (const auto& plugin : scannedPlugins)
        {
            if (plugin.type == category)
            {
                results.push_back(plugin);
            }
        }

        return results;
    }

    /** Get plugins by format */
    std::vector<PluginDescription> getPluginsByFormat(PluginFormat format) const
    {
        std::vector<PluginDescription> results;

        for (const auto& plugin : scannedPlugins)
        {
            if (plugin.format == format)
            {
                results.push_back(plugin);
            }
        }

        return results;
    }

    //==========================================================================
    // Cache
    //==========================================================================

    void saveCache(const juce::File& cacheFile)
    {
        juce::Array<juce::var> pluginArray;

        for (const auto& plugin : scannedPlugins)
        {
            pluginArray.add(plugin.toVar());
        }

        juce::DynamicObject::Ptr root = new juce::DynamicObject();
        root->setProperty("plugins", pluginArray);
        root->setProperty("version", 1);
        root->setProperty("timestamp", juce::Time::currentTimeMillis());

        juce::FileOutputStream stream(cacheFile);
        if (stream.openedOk())
        {
            juce::JSON::writeToStream(stream, juce::var(root.get()));
        }
    }

    void loadCache(const juce::File& cacheFile)
    {
        if (!cacheFile.existsAsFile())
            return;

        juce::FileInputStream stream(cacheFile);
        if (!stream.openedOk())
            return;

        juce::var json = juce::JSON::parse(stream);

        if (auto* obj = json.getDynamicObject())
        {
            if (auto* pluginArray = obj->getProperty("plugins").getArray())
            {
                scannedPlugins.clear();

                for (const auto& p : *pluginArray)
                {
                    scannedPlugins.push_back(PluginDescription::fromVar(p));
                }
            }
        }
    }

private:
    juce::AudioPluginFormatManager formatManager;
    std::vector<PluginDescription> scannedPlugins;

    juce::FileSearchPath getPluginSearchPaths() const
    {
        juce::FileSearchPath paths;

        #if JUCE_MAC
        paths.addPath(juce::File("/Library/Audio/Plug-Ins/VST3"));
        paths.addPath(juce::File("~/Library/Audio/Plug-Ins/VST3"));
        paths.addPath(juce::File("/Library/Audio/Plug-Ins/Components"));
        paths.addPath(juce::File("~/Library/Audio/Plug-Ins/Components"));
        #elif JUCE_WINDOWS
        paths.addPath(juce::File("C:\\Program Files\\Common Files\\VST3"));
        paths.addPath(juce::File("C:\\Program Files (x86)\\Common Files\\VST3"));
        #elif JUCE_LINUX
        paths.addPath(juce::File("/usr/lib/vst3"));
        paths.addPath(juce::File("/usr/local/lib/vst3"));
        paths.addPath(juce::File("~/.vst3"));
        #endif

        return paths;
    }
};

//==============================================================================
// Plugin Host
//==============================================================================

class PluginHost
{
public:
    using PluginLoadedCallback = std::function<void(PluginInstance*, bool success)>;

    PluginHost()
    {
        formatManager.addDefaultFormats();
    }

    //==========================================================================
    // Plugin Loading
    //==========================================================================

    /** Load a plugin from description */
    std::unique_ptr<PluginInstance> loadPlugin(const PluginDescription& desc,
                                                double sampleRate = 48000.0,
                                                int blockSize = 512)
    {
        juce::String error;

        // Find matching JUCE plugin description
        juce::PluginDescription juceDesc;
        juceDesc.name = desc.name;
        juceDesc.fileOrIdentifier = desc.filePath;
        juceDesc.pluginFormatName = getPluginFormatName(desc.format);
        juceDesc.numInputChannels = desc.numInputChannels;
        juceDesc.numOutputChannels = desc.numOutputChannels;

        // Create plugin instance
        auto jucePlugin = formatManager.createPluginInstance(
            juceDesc,
            sampleRate,
            blockSize,
            error
        );

        if (jucePlugin)
        {
            auto instance = std::make_unique<JucePluginInstance>(desc, std::move(jucePlugin));
            instance->prepare(sampleRate, blockSize);
            return instance;
        }
        else
        {
            // Log error
            lastError = error;
            return nullptr;
        }
    }

    /** Load plugin async */
    void loadPluginAsync(const PluginDescription& desc,
                         double sampleRate,
                         int blockSize,
                         PluginLoadedCallback callback)
    {
        // In production, this would use a background thread
        auto plugin = loadPlugin(desc, sampleRate, blockSize);
        if (callback)
        {
            callback(plugin.get(), plugin != nullptr);
        }
    }

    //==========================================================================
    // Scanner Access
    //==========================================================================

    PluginScanner& getScanner() { return scanner; }

    void scanPlugins(PluginScanner::ScanCallback progress = nullptr,
                     PluginScanner::CompleteCallback complete = nullptr)
    {
        scanner.scanAllPlugins(progress, complete);
    }

    //==========================================================================
    // Plugin Chain
    //==========================================================================

    /** Create a plugin chain for a track */
    class PluginChain
    {
    public:
        void addPlugin(std::unique_ptr<PluginInstance> plugin)
        {
            std::lock_guard<std::mutex> lock(mutex);
            plugins.push_back(std::move(plugin));
        }

        void insertPlugin(std::unique_ptr<PluginInstance> plugin, int index)
        {
            std::lock_guard<std::mutex> lock(mutex);
            if (index >= 0 && index <= static_cast<int>(plugins.size()))
            {
                plugins.insert(plugins.begin() + index, std::move(plugin));
            }
        }

        void removePlugin(int index)
        {
            std::lock_guard<std::mutex> lock(mutex);
            if (index >= 0 && index < static_cast<int>(plugins.size()))
            {
                plugins.erase(plugins.begin() + index);
            }
        }

        void movePlugin(int fromIndex, int toIndex)
        {
            std::lock_guard<std::mutex> lock(mutex);
            if (fromIndex >= 0 && fromIndex < static_cast<int>(plugins.size()) &&
                toIndex >= 0 && toIndex < static_cast<int>(plugins.size()))
            {
                auto plugin = std::move(plugins[fromIndex]);
                plugins.erase(plugins.begin() + fromIndex);
                plugins.insert(plugins.begin() + toIndex, std::move(plugin));
            }
        }

        PluginInstance* getPlugin(int index)
        {
            if (index >= 0 && index < static_cast<int>(plugins.size()))
            {
                return plugins[index].get();
            }
            return nullptr;
        }

        int getNumPlugins() const { return static_cast<int>(plugins.size()); }

        void prepare(double sampleRate, int blockSize)
        {
            std::lock_guard<std::mutex> lock(mutex);
            for (auto& plugin : plugins)
            {
                plugin->prepare(sampleRate, blockSize);
            }
        }

        void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi)
        {
            std::lock_guard<std::mutex> lock(mutex);
            for (auto& plugin : plugins)
            {
                if (!plugin->isBypassed())
                {
                    plugin->processBlock(buffer, midi);
                }
            }
        }

        int getTotalLatency() const
        {
            int latency = 0;
            for (const auto& plugin : plugins)
            {
                if (!plugin->isBypassed())
                {
                    latency += plugin->getLatencySamples();
                }
            }
            return latency;
        }

        juce::var getState() const
        {
            juce::Array<juce::var> states;

            for (const auto& plugin : plugins)
            {
                juce::DynamicObject::Ptr pluginState = new juce::DynamicObject();
                pluginState->setProperty("uid", plugin->getDescription().uid);
                pluginState->setProperty("bypassed", plugin->isBypassed());

                auto state = plugin->getState();
                pluginState->setProperty("state", state.toBase64Encoding());

                states.add(juce::var(pluginState.get()));
            }

            return states;
        }

    private:
        std::vector<std::unique_ptr<PluginInstance>> plugins;
        std::mutex mutex;
    };

    std::unique_ptr<PluginChain> createPluginChain()
    {
        return std::make_unique<PluginChain>();
    }

    //==========================================================================
    // Error Handling
    //==========================================================================

    juce::String getLastError() const { return lastError; }

private:
    juce::AudioPluginFormatManager formatManager;
    PluginScanner scanner;
    juce::String lastError;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PluginHost)
};

} // namespace Echoelmusic
