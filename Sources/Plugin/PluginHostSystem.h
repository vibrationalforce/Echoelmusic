/*
  ==============================================================================

    PluginHostSystem.h
    Echoelmusic - Bio-Reactive DAW

    VST3/AU Plugin Hosting with Ralph Wiggum AI Integration
    Intelligent plugin management, auto-routing, and bio-reactive control

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "../Core/RalphWiggumAPI.h"
#include <memory>
#include <vector>
#include <map>
#include <mutex>
#include <atomic>
#include <functional>
#include <thread>
#include <queue>
#include <condition_variable>

namespace Echoel {
namespace Plugin {

//==============================================================================
/**
    Plugin format types supported by the host
*/
enum class PluginFormat
{
    VST3,
    AudioUnit,
    AudioUnitV3,
    VST,        // Legacy VST2
    LV2,
    CLAP,
    Internal
};

//==============================================================================
/**
    Plugin category for organization and smart suggestions
*/
enum class PluginCategory
{
    Unknown,
    Effect,
    Instrument,
    Analyzer,
    // Effect subcategories
    EQ,
    Compressor,
    Limiter,
    Gate,
    Reverb,
    Delay,
    Modulation,
    Distortion,
    Filter,
    Utility,
    // Instrument subcategories
    Synthesizer,
    Sampler,
    DrumMachine,
    // AI-detected categories
    VocalProcessor,
    MasteringTool,
    CreativeEffect,
    BioReactiveCompatible
};

//==============================================================================
/**
    Plugin descriptor with metadata and AI analysis
*/
struct PluginDescriptor
{
    juce::String identifier;
    juce::String name;
    juce::String manufacturer;
    juce::String version;
    PluginFormat format;
    PluginCategory category;
    bool isInstrument = false;
    bool isMidiEffect = false;
    int numInputChannels = 0;
    int numOutputChannels = 0;
    juce::StringArray tags;

    // AI-analyzed properties
    float cpuUsageEstimate = 0.0f;      // 0-1 estimated CPU load
    float latencyMs = 0.0f;
    bool supportsDoublePrecision = false;
    bool hasCustomUI = true;

    // Bio-reactive compatibility
    bool bioReactiveCompatible = false;
    juce::StringArray autoMapParameters;

    // User data
    int useCount = 0;
    float userRating = 0.0f;
    juce::Time lastUsed;
    bool isFavorite = false;
};

//==============================================================================
/**
    Plugin instance wrapper with state management
*/
class PluginInstance
{
public:
    PluginInstance(std::unique_ptr<juce::AudioPluginInstance> instance,
                   const PluginDescriptor& desc)
        : plugin(std::move(instance))
        , descriptor(desc)
        , instanceId(juce::Uuid().toString())
    {
        if (plugin)
        {
            // Cache parameter info
            auto& params = plugin->getParameters();
            for (int i = 0; i < params.size(); ++i)
            {
                if (auto* param = params[i])
                {
                    ParameterInfo info;
                    info.index = i;
                    info.name = param->getName(64);
                    info.defaultValue = param->getDefaultValue();
                    info.currentValue = param->getValue();
                    parameterCache.push_back(info);
                }
            }
        }
    }

    ~PluginInstance() = default;

    // Non-copyable
    PluginInstance(const PluginInstance&) = delete;
    PluginInstance& operator=(const PluginInstance&) = delete;

    // Movable
    PluginInstance(PluginInstance&&) = default;
    PluginInstance& operator=(PluginInstance&&) = default;

    //--------------------------------------------------------------------------
    juce::AudioPluginInstance* getPlugin() { return plugin.get(); }
    const PluginDescriptor& getDescriptor() const { return descriptor; }
    const juce::String& getId() const { return instanceId; }

    //--------------------------------------------------------------------------
    void setParameter(int index, float value)
    {
        if (plugin && index >= 0 && index < plugin->getParameters().size())
        {
            plugin->getParameters()[index]->setValue(value);

            if (index < static_cast<int>(parameterCache.size()))
                parameterCache[index].currentValue = value;
        }
    }

    float getParameter(int index) const
    {
        if (plugin && index >= 0 && index < plugin->getParameters().size())
            return plugin->getParameters()[index]->getValue();
        return 0.0f;
    }

    //--------------------------------------------------------------------------
    void setBypass(bool shouldBypass)
    {
        bypassed.store(shouldBypass);
        if (plugin)
            plugin->setBypassed(shouldBypass);
    }

    bool isBypassed() const { return bypassed.load(); }

    //--------------------------------------------------------------------------
    juce::MemoryBlock getState() const
    {
        juce::MemoryBlock state;
        if (plugin)
            plugin->getStateInformation(state);
        return state;
    }

    void setState(const juce::MemoryBlock& state)
    {
        if (plugin && state.getSize() > 0)
            plugin->setStateInformation(state.getData(), static_cast<int>(state.getSize()));
    }

    //--------------------------------------------------------------------------
    // Bio-reactive parameter mapping
    void setBioReactiveMapping(int paramIndex, const juce::String& bioSource)
    {
        std::lock_guard<std::mutex> lock(mappingMutex);
        bioMappings[paramIndex] = bioSource;
    }

    void updateBioReactiveParameters(float coherence, float heartRate, float hrv)
    {
        std::lock_guard<std::mutex> lock(mappingMutex);

        for (const auto& mapping : bioMappings)
        {
            float value = 0.5f;

            if (mapping.second == "coherence")
                value = coherence;
            else if (mapping.second == "heartRate")
                value = juce::jmap(heartRate, 40.0f, 180.0f, 0.0f, 1.0f);
            else if (mapping.second == "hrv")
                value = juce::jmap(hrv, 0.0f, 100.0f, 0.0f, 1.0f);

            setParameter(mapping.first, value);
        }
    }

private:
    struct ParameterInfo
    {
        int index;
        juce::String name;
        float defaultValue;
        float currentValue;
    };

    std::unique_ptr<juce::AudioPluginInstance> plugin;
    PluginDescriptor descriptor;
    juce::String instanceId;
    std::vector<ParameterInfo> parameterCache;
    std::atomic<bool> bypassed{false};

    std::mutex mappingMutex;
    std::map<int, juce::String> bioMappings;
};

//==============================================================================
/**
    Plugin chain for insert effects
*/
class PluginChain
{
public:
    PluginChain(const juce::String& name = "Chain")
        : chainName(name)
        , chainId(juce::Uuid().toString())
    {
    }

    //--------------------------------------------------------------------------
    void addPlugin(std::shared_ptr<PluginInstance> plugin, int index = -1)
    {
        std::lock_guard<std::mutex> lock(chainMutex);

        if (index < 0 || index >= static_cast<int>(plugins.size()))
            plugins.push_back(plugin);
        else
            plugins.insert(plugins.begin() + index, plugin);
    }

    void removePlugin(int index)
    {
        std::lock_guard<std::mutex> lock(chainMutex);

        if (index >= 0 && index < static_cast<int>(plugins.size()))
            plugins.erase(plugins.begin() + index);
    }

    void movePlugin(int fromIndex, int toIndex)
    {
        std::lock_guard<std::mutex> lock(chainMutex);

        if (fromIndex >= 0 && fromIndex < static_cast<int>(plugins.size()) &&
            toIndex >= 0 && toIndex < static_cast<int>(plugins.size()) &&
            fromIndex != toIndex)
        {
            auto plugin = plugins[fromIndex];
            plugins.erase(plugins.begin() + fromIndex);
            plugins.insert(plugins.begin() + toIndex, plugin);
        }
    }

    //--------------------------------------------------------------------------
    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi)
    {
        std::lock_guard<std::mutex> lock(chainMutex);

        for (auto& plugin : plugins)
        {
            if (plugin && !plugin->isBypassed())
            {
                if (auto* p = plugin->getPlugin())
                    p->processBlock(buffer, midi);
            }
        }
    }

    //--------------------------------------------------------------------------
    void prepareToPlay(double sampleRate, int samplesPerBlock)
    {
        std::lock_guard<std::mutex> lock(chainMutex);

        for (auto& plugin : plugins)
        {
            if (plugin)
            {
                if (auto* p = plugin->getPlugin())
                {
                    p->setPlayConfigDetails(2, 2, sampleRate, samplesPerBlock);
                    p->prepareToPlay(sampleRate, samplesPerBlock);
                }
            }
        }
    }

    void releaseResources()
    {
        std::lock_guard<std::mutex> lock(chainMutex);

        for (auto& plugin : plugins)
        {
            if (plugin)
            {
                if (auto* p = plugin->getPlugin())
                    p->releaseResources();
            }
        }
    }

    //--------------------------------------------------------------------------
    size_t getNumPlugins() const
    {
        std::lock_guard<std::mutex> lock(chainMutex);
        return plugins.size();
    }

    std::shared_ptr<PluginInstance> getPlugin(int index)
    {
        std::lock_guard<std::mutex> lock(chainMutex);
        if (index >= 0 && index < static_cast<int>(plugins.size()))
            return plugins[index];
        return nullptr;
    }

    const juce::String& getName() const { return chainName; }
    const juce::String& getId() const { return chainId; }

private:
    juce::String chainName;
    juce::String chainId;
    std::vector<std::shared_ptr<PluginInstance>> plugins;
    mutable std::mutex chainMutex;
};

//==============================================================================
/**
    AI-powered plugin suggestion engine
*/
class PluginSuggestionEngine
{
public:
    struct Suggestion
    {
        PluginDescriptor plugin;
        float confidence = 0.0f;
        juce::String reason;
        int suggestedPosition = -1;
    };

    //--------------------------------------------------------------------------
    std::vector<Suggestion> suggestPlugins(
        const juce::String& context,
        const std::vector<PluginDescriptor>& availablePlugins,
        const PluginChain* currentChain = nullptr)
    {
        std::vector<Suggestion> suggestions;

        // Analyze context
        bool needsEQ = context.containsIgnoreCase("muddy") ||
                       context.containsIgnoreCase("eq") ||
                       context.containsIgnoreCase("clarity");
        bool needsCompression = context.containsIgnoreCase("dynamic") ||
                                context.containsIgnoreCase("punch") ||
                                context.containsIgnoreCase("compress");
        bool needsReverb = context.containsIgnoreCase("space") ||
                           context.containsIgnoreCase("reverb") ||
                           context.containsIgnoreCase("room");
        bool needsDelay = context.containsIgnoreCase("delay") ||
                          context.containsIgnoreCase("echo");
        bool needsSaturation = context.containsIgnoreCase("warm") ||
                               context.containsIgnoreCase("analog") ||
                               context.containsIgnoreCase("saturation");

        for (const auto& plugin : availablePlugins)
        {
            float score = 0.0f;
            juce::String reason;

            if (needsEQ && plugin.category == PluginCategory::EQ)
            {
                score = 0.9f;
                reason = "EQ for clarity and tonal balance";
            }
            else if (needsCompression && plugin.category == PluginCategory::Compressor)
            {
                score = 0.85f;
                reason = "Compression for dynamics control";
            }
            else if (needsReverb && plugin.category == PluginCategory::Reverb)
            {
                score = 0.88f;
                reason = "Reverb for spatial depth";
            }
            else if (needsDelay && plugin.category == PluginCategory::Delay)
            {
                score = 0.85f;
                reason = "Delay for rhythmic interest";
            }
            else if (needsSaturation && plugin.category == PluginCategory::Distortion)
            {
                score = 0.82f;
                reason = "Saturation for analog warmth";
            }

            // Boost for bio-reactive compatible
            if (plugin.bioReactiveCompatible)
                score += 0.1f;

            // Boost for user favorites
            if (plugin.isFavorite)
                score += 0.15f;

            // Boost for frequently used
            score += std::min(0.1f, plugin.useCount * 0.01f);

            if (score > 0.5f)
            {
                Suggestion suggestion;
                suggestion.plugin = plugin;
                suggestion.confidence = std::min(1.0f, score);
                suggestion.reason = reason;
                suggestions.push_back(suggestion);
            }
        }

        // Sort by confidence
        std::sort(suggestions.begin(), suggestions.end(),
            [](const Suggestion& a, const Suggestion& b) {
                return a.confidence > b.confidence;
            });

        // Limit to top suggestions
        if (suggestions.size() > 5)
            suggestions.resize(5);

        return suggestions;
    }

    //--------------------------------------------------------------------------
    std::vector<Suggestion> suggestChainForGenre(
        const juce::String& genre,
        const std::vector<PluginDescriptor>& availablePlugins)
    {
        std::vector<Suggestion> suggestions;

        // Genre-specific chain templates
        std::vector<PluginCategory> chainTemplate;

        if (genre.containsIgnoreCase("rock") || genre.containsIgnoreCase("metal"))
        {
            chainTemplate = { PluginCategory::EQ, PluginCategory::Compressor,
                             PluginCategory::Distortion, PluginCategory::EQ };
        }
        else if (genre.containsIgnoreCase("pop") || genre.containsIgnoreCase("electronic"))
        {
            chainTemplate = { PluginCategory::EQ, PluginCategory::Compressor,
                             PluginCategory::Modulation, PluginCategory::Reverb };
        }
        else if (genre.containsIgnoreCase("jazz") || genre.containsIgnoreCase("acoustic"))
        {
            chainTemplate = { PluginCategory::EQ, PluginCategory::Compressor,
                             PluginCategory::Reverb };
        }
        else if (genre.containsIgnoreCase("hip") || genre.containsIgnoreCase("trap"))
        {
            chainTemplate = { PluginCategory::EQ, PluginCategory::Compressor,
                             PluginCategory::Limiter, PluginCategory::Delay };
        }

        int position = 0;
        for (auto category : chainTemplate)
        {
            for (const auto& plugin : availablePlugins)
            {
                if (plugin.category == category)
                {
                    Suggestion s;
                    s.plugin = plugin;
                    s.confidence = 0.8f + (plugin.isFavorite ? 0.1f : 0.0f);
                    s.reason = "Suggested for " + genre + " production";
                    s.suggestedPosition = position;
                    suggestions.push_back(s);
                    break;
                }
            }
            position++;
        }

        return suggestions;
    }
};

//==============================================================================
/**
    Main Plugin Host System with AI integration
*/
class PluginHostSystem
{
public:
    //--------------------------------------------------------------------------
    static PluginHostSystem& getInstance()
    {
        static PluginHostSystem instance;
        return instance;
    }

    //--------------------------------------------------------------------------
    void initialize()
    {
        std::lock_guard<std::mutex> lock(hostMutex);

        if (initialized)
            return;

        // Initialize format manager
        formatManager = std::make_unique<juce::AudioPluginFormatManager>();
        formatManager->addDefaultFormats();

        // Start scanner thread
        scannerRunning = true;
        scannerThread = std::thread(&PluginHostSystem::scannerLoop, this);

        initialized = true;
    }

    void shutdown()
    {
        {
            std::lock_guard<std::mutex> lock(hostMutex);
            scannerRunning = false;
        }
        scannerCondition.notify_all();

        if (scannerThread.joinable())
            scannerThread.join();

        // Release all plugin instances
        std::lock_guard<std::mutex> lock(hostMutex);
        activeInstances.clear();
        pluginChains.clear();
        initialized = false;
    }

    //--------------------------------------------------------------------------
    // Plugin scanning
    void scanPlugins(const juce::StringArray& paths)
    {
        {
            std::lock_guard<std::mutex> lock(scanMutex);
            for (const auto& path : paths)
                scanQueue.push(path);
        }
        scannerCondition.notify_one();
    }

    void scanDefaultLocations()
    {
        juce::StringArray paths;

#if JUCE_MAC
        paths.add("/Library/Audio/Plug-Ins/VST3");
        paths.add("/Library/Audio/Plug-Ins/Components");
        paths.add("~/Library/Audio/Plug-Ins/VST3");
        paths.add("~/Library/Audio/Plug-Ins/Components");
#elif JUCE_WINDOWS
        paths.add("C:\\Program Files\\Common Files\\VST3");
        paths.add("C:\\Program Files\\Steinberg\\VstPlugins");
#elif JUCE_LINUX
        paths.add("/usr/lib/vst3");
        paths.add("/usr/local/lib/vst3");
        paths.add("~/.vst3");
#endif

        scanPlugins(paths);
    }

    float getScanProgress() const { return scanProgress.load(); }
    bool isScanning() const { return isCurrentlyScanning.load(); }

    //--------------------------------------------------------------------------
    // Plugin list access
    std::vector<PluginDescriptor> getAvailablePlugins() const
    {
        std::lock_guard<std::mutex> lock(hostMutex);
        return availablePlugins;
    }

    std::vector<PluginDescriptor> getPluginsByCategory(PluginCategory category) const
    {
        std::lock_guard<std::mutex> lock(hostMutex);
        std::vector<PluginDescriptor> result;

        for (const auto& plugin : availablePlugins)
        {
            if (plugin.category == category)
                result.push_back(plugin);
        }

        return result;
    }

    std::vector<PluginDescriptor> searchPlugins(const juce::String& query) const
    {
        std::lock_guard<std::mutex> lock(hostMutex);
        std::vector<PluginDescriptor> result;

        juce::String lowerQuery = query.toLowerCase();

        for (const auto& plugin : availablePlugins)
        {
            if (plugin.name.toLowerCase().contains(lowerQuery) ||
                plugin.manufacturer.toLowerCase().contains(lowerQuery))
            {
                result.push_back(plugin);
            }
        }

        return result;
    }

    //--------------------------------------------------------------------------
    // Plugin instantiation
    std::shared_ptr<PluginInstance> createInstance(const PluginDescriptor& descriptor)
    {
        std::lock_guard<std::mutex> lock(hostMutex);

        if (!formatManager)
            return nullptr;

        juce::String errorMessage;
        juce::PluginDescription juceDesc;
        juceDesc.name = descriptor.name;
        juceDesc.manufacturerName = descriptor.manufacturer;
        juceDesc.pluginFormatName = formatToString(descriptor.format);
        juceDesc.fileOrIdentifier = descriptor.identifier;
        juceDesc.isInstrument = descriptor.isInstrument;
        juceDesc.numInputChannels = descriptor.numInputChannels;
        juceDesc.numOutputChannels = descriptor.numOutputChannels;

        auto plugin = formatManager->createPluginInstance(
            juceDesc, currentSampleRate, currentBlockSize, errorMessage);

        if (plugin)
        {
            auto instance = std::make_shared<PluginInstance>(std::move(plugin), descriptor);
            activeInstances.push_back(instance);

            // Update usage stats
            for (auto& p : availablePlugins)
            {
                if (p.identifier == descriptor.identifier)
                {
                    p.useCount++;
                    p.lastUsed = juce::Time::getCurrentTime();
                    break;
                }
            }

            return instance;
        }

        return nullptr;
    }

    void releaseInstance(const juce::String& instanceId)
    {
        std::lock_guard<std::mutex> lock(hostMutex);

        activeInstances.erase(
            std::remove_if(activeInstances.begin(), activeInstances.end(),
                [&instanceId](const std::shared_ptr<PluginInstance>& inst) {
                    return inst->getId() == instanceId;
                }),
            activeInstances.end());
    }

    //--------------------------------------------------------------------------
    // Plugin chains
    std::shared_ptr<PluginChain> createChain(const juce::String& name)
    {
        std::lock_guard<std::mutex> lock(hostMutex);
        auto chain = std::make_shared<PluginChain>(name);
        pluginChains.push_back(chain);
        return chain;
    }

    void removeChain(const juce::String& chainId)
    {
        std::lock_guard<std::mutex> lock(hostMutex);

        pluginChains.erase(
            std::remove_if(pluginChains.begin(), pluginChains.end(),
                [&chainId](const std::shared_ptr<PluginChain>& chain) {
                    return chain->getId() == chainId;
                }),
            pluginChains.end());
    }

    //--------------------------------------------------------------------------
    // AI suggestions
    std::vector<PluginSuggestionEngine::Suggestion> getSuggestions(
        const juce::String& context,
        const PluginChain* currentChain = nullptr)
    {
        return suggestionEngine.suggestPlugins(context, availablePlugins, currentChain);
    }

    std::vector<PluginSuggestionEngine::Suggestion> getGenreChainSuggestions(
        const juce::String& genre)
    {
        return suggestionEngine.suggestChainForGenre(genre, availablePlugins);
    }

    //--------------------------------------------------------------------------
    // Audio configuration
    void setAudioConfig(double sampleRate, int blockSize)
    {
        std::lock_guard<std::mutex> lock(hostMutex);
        currentSampleRate = sampleRate;
        currentBlockSize = blockSize;

        // Update all chains
        for (auto& chain : pluginChains)
            chain->prepareToPlay(sampleRate, blockSize);
    }

    //--------------------------------------------------------------------------
    // Bio-reactive integration
    void updateBioState(float coherence, float heartRate, float hrv)
    {
        std::lock_guard<std::mutex> lock(hostMutex);

        for (auto& instance : activeInstances)
        {
            if (instance && instance->getDescriptor().bioReactiveCompatible)
            {
                instance->updateBioReactiveParameters(coherence, heartRate, hrv);
            }
        }
    }

    //--------------------------------------------------------------------------
    // Callbacks
    void setOnScanComplete(std::function<void(int)> callback)
    {
        onScanComplete = callback;
    }

    void setOnPluginLoaded(std::function<void(const PluginDescriptor&)> callback)
    {
        onPluginLoaded = callback;
    }

private:
    PluginHostSystem() = default;
    ~PluginHostSystem() { shutdown(); }

    PluginHostSystem(const PluginHostSystem&) = delete;
    PluginHostSystem& operator=(const PluginHostSystem&) = delete;

    //--------------------------------------------------------------------------
    void scannerLoop()
    {
        while (scannerRunning)
        {
            juce::String pathToScan;

            {
                std::unique_lock<std::mutex> lock(scanMutex);
                scannerCondition.wait(lock, [this] {
                    return !scanQueue.empty() || !scannerRunning;
                });

                if (!scannerRunning)
                    break;

                if (!scanQueue.empty())
                {
                    pathToScan = scanQueue.front();
                    scanQueue.pop();
                }
            }

            if (pathToScan.isNotEmpty())
            {
                scanDirectory(pathToScan);
            }
        }
    }

    void scanDirectory(const juce::String& path)
    {
        isCurrentlyScanning.store(true);

        juce::File directory(path);
        if (!directory.isDirectory())
        {
            isCurrentlyScanning.store(false);
            return;
        }

        juce::Array<juce::File> files;
        directory.findChildFiles(files, juce::File::findFiles, true,
            "*.vst3;*.component;*.vst;*.clap");

        int total = files.size();
        int scanned = 0;

        for (const auto& file : files)
        {
            if (!scannerRunning)
                break;

            scanPluginFile(file);

            scanned++;
            scanProgress.store(static_cast<float>(scanned) / static_cast<float>(total));
        }

        isCurrentlyScanning.store(false);
        scanProgress.store(1.0f);

        if (onScanComplete)
            onScanComplete(static_cast<int>(availablePlugins.size()));
    }

    void scanPluginFile(const juce::File& file)
    {
        if (!formatManager)
            return;

        juce::OwnedArray<juce::PluginDescription> descriptions;

        for (auto* format : formatManager->getFormats())
        {
            format->findAllTypesForFile(descriptions, file.getFullPathName());
        }

        for (auto* desc : descriptions)
        {
            PluginDescriptor pluginDesc;
            pluginDesc.identifier = desc->fileOrIdentifier;
            pluginDesc.name = desc->name;
            pluginDesc.manufacturer = desc->manufacturerName;
            pluginDesc.version = desc->version;
            pluginDesc.format = stringToFormat(desc->pluginFormatName);
            pluginDesc.isInstrument = desc->isInstrument;
            pluginDesc.numInputChannels = desc->numInputChannels;
            pluginDesc.numOutputChannels = desc->numOutputChannels;
            pluginDesc.hasCustomUI = desc->hasSharedContainer;

            // Analyze and categorize
            pluginDesc.category = categorizePlugin(desc->name, desc->isInstrument);

            // Check for bio-reactive keywords
            pluginDesc.bioReactiveCompatible =
                desc->name.containsIgnoreCase("bio") ||
                desc->name.containsIgnoreCase("breath") ||
                desc->name.containsIgnoreCase("pulse");

            std::lock_guard<std::mutex> lock(hostMutex);

            // Check for duplicates
            bool exists = false;
            for (const auto& p : availablePlugins)
            {
                if (p.identifier == pluginDesc.identifier)
                {
                    exists = true;
                    break;
                }
            }

            if (!exists)
            {
                availablePlugins.push_back(pluginDesc);

                if (onPluginLoaded)
                    onPluginLoaded(pluginDesc);
            }
        }
    }

    //--------------------------------------------------------------------------
    static juce::String formatToString(PluginFormat format)
    {
        switch (format)
        {
            case PluginFormat::VST3: return "VST3";
            case PluginFormat::AudioUnit: return "AudioUnit";
            case PluginFormat::AudioUnitV3: return "AudioUnit";
            case PluginFormat::VST: return "VST";
            case PluginFormat::LV2: return "LV2";
            case PluginFormat::CLAP: return "CLAP";
            default: return "Unknown";
        }
    }

    static PluginFormat stringToFormat(const juce::String& str)
    {
        if (str == "VST3") return PluginFormat::VST3;
        if (str == "AudioUnit") return PluginFormat::AudioUnit;
        if (str == "VST") return PluginFormat::VST;
        if (str == "LV2") return PluginFormat::LV2;
        if (str == "CLAP") return PluginFormat::CLAP;
        return PluginFormat::Internal;
    }

    static PluginCategory categorizePlugin(const juce::String& name, bool isInstrument)
    {
        if (isInstrument)
        {
            if (name.containsIgnoreCase("drum") || name.containsIgnoreCase("beat"))
                return PluginCategory::DrumMachine;
            if (name.containsIgnoreCase("sampl"))
                return PluginCategory::Sampler;
            return PluginCategory::Synthesizer;
        }

        // Effect categorization by name keywords
        if (name.containsIgnoreCase("eq") || name.containsIgnoreCase("equaliz"))
            return PluginCategory::EQ;
        if (name.containsIgnoreCase("compres") || name.containsIgnoreCase("comp"))
            return PluginCategory::Compressor;
        if (name.containsIgnoreCase("limit"))
            return PluginCategory::Limiter;
        if (name.containsIgnoreCase("gate") || name.containsIgnoreCase("expand"))
            return PluginCategory::Gate;
        if (name.containsIgnoreCase("reverb") || name.containsIgnoreCase("verb") ||
            name.containsIgnoreCase("room") || name.containsIgnoreCase("hall"))
            return PluginCategory::Reverb;
        if (name.containsIgnoreCase("delay") || name.containsIgnoreCase("echo"))
            return PluginCategory::Delay;
        if (name.containsIgnoreCase("chorus") || name.containsIgnoreCase("flang") ||
            name.containsIgnoreCase("phase") || name.containsIgnoreCase("trem"))
            return PluginCategory::Modulation;
        if (name.containsIgnoreCase("distort") || name.containsIgnoreCase("overdrive") ||
            name.containsIgnoreCase("satur") || name.containsIgnoreCase("fuzz"))
            return PluginCategory::Distortion;
        if (name.containsIgnoreCase("filter"))
            return PluginCategory::Filter;
        if (name.containsIgnoreCase("vocal"))
            return PluginCategory::VocalProcessor;
        if (name.containsIgnoreCase("master"))
            return PluginCategory::MasteringTool;
        if (name.containsIgnoreCase("analyz") || name.containsIgnoreCase("meter"))
            return PluginCategory::Analyzer;

        return PluginCategory::Effect;
    }

    //--------------------------------------------------------------------------
    mutable std::mutex hostMutex;
    std::mutex scanMutex;
    std::condition_variable scannerCondition;

    bool initialized = false;
    std::atomic<bool> scannerRunning{false};
    std::atomic<bool> isCurrentlyScanning{false};
    std::atomic<float> scanProgress{0.0f};
    std::thread scannerThread;
    std::queue<juce::String> scanQueue;

    std::unique_ptr<juce::AudioPluginFormatManager> formatManager;
    std::vector<PluginDescriptor> availablePlugins;
    std::vector<std::shared_ptr<PluginInstance>> activeInstances;
    std::vector<std::shared_ptr<PluginChain>> pluginChains;

    PluginSuggestionEngine suggestionEngine;

    double currentSampleRate = 44100.0;
    int currentBlockSize = 512;

    std::function<void(int)> onScanComplete;
    std::function<void(const PluginDescriptor&)> onPluginLoaded;
};

} // namespace Plugin
} // namespace Echoel
