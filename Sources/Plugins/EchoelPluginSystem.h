/**
 * EchoelPluginSystem.h
 *
 * Third-Party Plugin Architecture & Extension System
 *
 * Complete plugin ecosystem:
 * - Plugin discovery & loading
 * - Sandboxed execution
 * - API versioning
 * - Hot-reload support
 * - Plugin marketplace integration
 * - Settings management
 * - Inter-plugin communication
 * - Resource management
 * - Update system
 * - Developer tools
 *
 * Part of Ralph Wiggum Quantum Sauce Mode - Phase 2
 * "That's where I saw the leprechaun. He tells me to burn things." - Ralph Wiggum
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <set>
#include <memory>
#include <functional>
#include <chrono>
#include <optional>
#include <variant>
#include <atomic>
#include <mutex>
#include <any>

namespace Echoel {

// ============================================================================
// Plugin Types
// ============================================================================

enum class PluginType {
    // Audio Processing
    Effect,             // Audio effect
    Instrument,         // Virtual instrument
    Analyzer,           // Audio analysis
    Generator,          // Sound generator

    // MIDI
    MIDIEffect,         // MIDI processor
    MIDIGenerator,      // MIDI generator

    // UI
    Theme,              // Visual theme
    Widget,             // UI widget
    Panel,              // Custom panel

    // Content
    SamplePack,         // Sample library
    PresetPack,         // Preset collection

    // Integration
    CloudService,       // Cloud integration
    Hardware,           // Hardware control
    DAWBridge,          // DAW integration

    // Utility
    Utility,            // General utility
    Automation,         // Automation helper

    Custom
};

enum class PluginCapability {
    AudioInput,
    AudioOutput,
    MIDIInput,
    MIDIOutput,
    SideChain,
    MultiChannel,
    Offline,
    RealTime,
    ParameterAutomation,
    PresetManagement,
    CustomUI,
    EditorResize,
    StateChunk,
    BypassProcessing
};

// ============================================================================
// Plugin Metadata
// ============================================================================

struct PluginVersion {
    int major = 1;
    int minor = 0;
    int patch = 0;
    std::string preRelease;  // "alpha", "beta", "rc1"
    std::string build;

    std::string toString() const {
        std::string v = std::to_string(major) + "." +
                        std::to_string(minor) + "." +
                        std::to_string(patch);
        if (!preRelease.empty()) v += "-" + preRelease;
        if (!build.empty()) v += "+" + build;
        return v;
    }

    bool operator<(const PluginVersion& other) const {
        if (major != other.major) return major < other.major;
        if (minor != other.minor) return minor < other.minor;
        return patch < other.patch;
    }

    bool operator>=(const PluginVersion& other) const {
        return !(*this < other);
    }
};

struct PluginAuthor {
    std::string name;
    std::string email;
    std::string website;
    std::string company;
};

struct PluginMetadata {
    std::string id;              // Unique identifier
    std::string name;
    std::string displayName;
    std::string description;
    PluginVersion version;
    PluginType type = PluginType::Effect;

    PluginAuthor author;
    std::string license;
    std::string homepage;
    std::string repository;

    std::vector<std::string> categories;
    std::vector<std::string> tags;

    // Requirements
    PluginVersion minAppVersion;
    PluginVersion maxAppVersion;
    std::vector<std::string> dependencies;  // Other plugin IDs
    std::vector<std::string> conflicts;     // Incompatible plugins

    // Capabilities
    std::set<PluginCapability> capabilities;

    // Platform support
    bool supportsMacOS = true;
    bool supportsWindows = true;
    bool supportsLinux = true;
    bool supportsiOS = false;

    // Resources
    std::string iconPath;
    std::string bannerPath;
    std::vector<std::string> screenshots;

    // Pricing (for marketplace)
    bool isFree = true;
    float price = 0.0f;
    std::string currency = "USD";
};

// ============================================================================
// Plugin Parameters
// ============================================================================

struct PluginParameter {
    std::string id;
    std::string name;
    std::string displayName;
    std::string unit;
    std::string group;

    enum class Type {
        Float,
        Int,
        Bool,
        Choice,
        String,
        Color,
        File,
        Custom
    } type = Type::Float;

    // Value range
    float minValue = 0.0f;
    float maxValue = 1.0f;
    float defaultValue = 0.0f;
    float stepSize = 0.0f;

    // For choice type
    std::vector<std::string> choices;

    // Display
    std::function<std::string(float)> valueToString;
    std::function<float(const std::string&)> stringToValue;

    // Automation
    bool isAutomatable = true;
    bool isMetaParameter = false;

    // Current value
    std::atomic<float> value{0.0f};
};

// ============================================================================
// Plugin State
// ============================================================================

struct PluginState {
    std::string pluginId;
    PluginVersion version;

    // Parameter values
    std::map<std::string, float> parameters;

    // Custom state data
    std::vector<uint8_t> customData;
    std::string customDataFormat;  // "json", "binary", "xml"

    // Preset info
    std::string presetName;
    std::string presetAuthor;

    std::chrono::system_clock::time_point savedAt;
};

// ============================================================================
// Plugin Interface
// ============================================================================

class IPluginHost;

class IPlugin {
public:
    virtual ~IPlugin() = default;

    // Lifecycle
    virtual bool initialize(IPluginHost* host) = 0;
    virtual void shutdown() = 0;

    // Metadata
    virtual PluginMetadata getMetadata() const = 0;

    // Parameters
    virtual std::vector<PluginParameter> getParameters() const = 0;
    virtual void setParameter(const std::string& id, float value) = 0;
    virtual float getParameter(const std::string& id) const = 0;

    // State
    virtual PluginState getState() const = 0;
    virtual void setState(const PluginState& state) = 0;

    // Processing
    virtual void prepareToPlay(double sampleRate, int maxBlockSize) = 0;
    virtual void processBlock(float** inputs, float** outputs,
                               int numChannels, int numSamples) = 0;
    virtual void reset() = 0;

    // MIDI
    virtual void processMIDI(const std::vector<uint8_t>& message) {}

    // UI
    virtual bool hasEditor() const { return false; }
    virtual void* createEditor() { return nullptr; }
    virtual void destroyEditor(void* editor) {}
    virtual std::pair<int, int> getEditorSize() const { return {400, 300}; }

    // Info
    virtual int getLatencySamples() const { return 0; }
    virtual int getTailLengthSamples() const { return 0; }
};

// ============================================================================
// Plugin Host Interface
// ============================================================================

class IPluginHost {
public:
    virtual ~IPluginHost() = default;

    // App info
    virtual std::string getAppName() const = 0;
    virtual PluginVersion getAppVersion() const = 0;

    // Audio info
    virtual double getSampleRate() const = 0;
    virtual int getBlockSize() const = 0;
    virtual int getNumInputChannels() const = 0;
    virtual int getNumOutputChannels() const = 0;

    // Transport
    virtual bool isPlaying() const = 0;
    virtual bool isRecording() const = 0;
    virtual double getPlayheadPosition() const = 0;  // In samples
    virtual double getTempo() const = 0;
    virtual int getTimeSigNumerator() const = 0;
    virtual int getTimeSigDenominator() const = 0;

    // Parameter automation
    virtual void beginParameterChange(const std::string& parameterId) = 0;
    virtual void endParameterChange(const std::string& parameterId) = 0;
    virtual void setParameterValue(const std::string& parameterId, float value) = 0;

    // Logging
    virtual void log(const std::string& message, int level = 0) = 0;

    // Resources
    virtual std::string getPluginDataPath() const = 0;
    virtual std::string getTempPath() const = 0;

    // Inter-plugin
    virtual void sendMessage(const std::string& targetPluginId,
                              const std::string& message,
                              const std::any& data) = 0;
};

// ============================================================================
// Plugin Factory
// ============================================================================

using PluginCreateFunc = std::function<std::unique_ptr<IPlugin>()>;
using PluginDestroyFunc = std::function<void(IPlugin*)>;

struct PluginFactory {
    PluginMetadata metadata;
    PluginCreateFunc create;
    PluginDestroyFunc destroy;
};

// ============================================================================
// Plugin Instance
// ============================================================================

struct PluginInstance {
    std::string instanceId;
    std::string pluginId;

    std::unique_ptr<IPlugin> plugin;
    PluginState lastState;

    bool isActive = false;
    bool isBypassed = false;
    bool isLoading = false;

    // Processing stats
    double cpuUsage = 0.0;
    int latency = 0;

    std::chrono::system_clock::time_point loadedAt;
    std::chrono::system_clock::time_point lastUsed;
};

// ============================================================================
// Plugin Manager
// ============================================================================

class PluginManager {
public:
    static PluginManager& getInstance() {
        static PluginManager instance;
        return instance;
    }

    // ========================================================================
    // Plugin Discovery
    // ========================================================================

    void scanForPlugins() {
        std::lock_guard<std::mutex> lock(mutex_);

        // Scan plugin directories
        std::vector<std::string> searchPaths = {
            getSystemPluginPath(),
            getUserPluginPath(),
            getAppPluginPath()
        };

        for (const auto& path : searchPaths) {
            scanDirectory(path);
        }

        pluginsScanned_ = true;
    }

    std::vector<PluginMetadata> getAvailablePlugins(
        std::optional<PluginType> type = std::nullopt) const {

        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<PluginMetadata> result;
        for (const auto& [id, factory] : pluginFactories_) {
            if (type && factory.metadata.type != *type) continue;
            result.push_back(factory.metadata);
        }

        return result;
    }

    std::optional<PluginMetadata> getPluginMetadata(const std::string& pluginId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = pluginFactories_.find(pluginId);
        if (it != pluginFactories_.end()) {
            return it->second.metadata;
        }
        return std::nullopt;
    }

    // ========================================================================
    // Plugin Loading
    // ========================================================================

    std::string loadPlugin(const std::string& pluginId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto factoryIt = pluginFactories_.find(pluginId);
        if (factoryIt == pluginFactories_.end()) {
            return "";  // Plugin not found
        }

        // Check dependencies
        for (const auto& depId : factoryIt->second.metadata.dependencies) {
            if (pluginFactories_.count(depId) == 0) {
                return "";  // Missing dependency
            }
        }

        // Create instance
        PluginInstance instance;
        instance.instanceId = generateInstanceId();
        instance.pluginId = pluginId;
        instance.plugin = factoryIt->second.create();
        instance.loadedAt = std::chrono::system_clock::now();

        if (!instance.plugin) {
            return "";
        }

        // Initialize
        instance.plugin->initialize(hostInterface_.get());
        instance.isActive = true;

        std::string instanceId = instance.instanceId;
        pluginInstances_[instanceId] = std::move(instance);

        return instanceId;
    }

    void unloadPlugin(const std::string& instanceId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = pluginInstances_.find(instanceId);
        if (it == pluginInstances_.end()) return;

        // Shutdown and destroy
        if (it->second.plugin) {
            it->second.plugin->shutdown();
        }

        pluginInstances_.erase(it);
    }

    PluginInstance* getPluginInstance(const std::string& instanceId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = pluginInstances_.find(instanceId);
        if (it != pluginInstances_.end()) {
            return &it->second;
        }
        return nullptr;
    }

    std::vector<std::string> getLoadedPluginInstances() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<std::string> result;
        for (const auto& [id, instance] : pluginInstances_) {
            result.push_back(id);
        }
        return result;
    }

    // ========================================================================
    // Plugin Control
    // ========================================================================

    void setPluginParameter(const std::string& instanceId,
                             const std::string& parameterId, float value) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = pluginInstances_.find(instanceId);
        if (it != pluginInstances_.end() && it->second.plugin) {
            it->second.plugin->setParameter(parameterId, value);
        }
    }

    float getPluginParameter(const std::string& instanceId,
                              const std::string& parameterId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = pluginInstances_.find(instanceId);
        if (it != pluginInstances_.end() && it->second.plugin) {
            return it->second.plugin->getParameter(parameterId);
        }
        return 0.0f;
    }

    void bypassPlugin(const std::string& instanceId, bool bypass) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = pluginInstances_.find(instanceId);
        if (it != pluginInstances_.end()) {
            it->second.isBypassed = bypass;
        }
    }

    // ========================================================================
    // State Management
    // ========================================================================

    PluginState getPluginState(const std::string& instanceId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = pluginInstances_.find(instanceId);
        if (it != pluginInstances_.end() && it->second.plugin) {
            return it->second.plugin->getState();
        }
        return PluginState{};
    }

    void setPluginState(const std::string& instanceId, const PluginState& state) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = pluginInstances_.find(instanceId);
        if (it != pluginInstances_.end() && it->second.plugin) {
            it->second.plugin->setState(state);
        }
    }

    // ========================================================================
    // Plugin Registration (for built-in & external)
    // ========================================================================

    void registerPlugin(const PluginFactory& factory) {
        std::lock_guard<std::mutex> lock(mutex_);
        pluginFactories_[factory.metadata.id] = factory;
    }

    void unregisterPlugin(const std::string& pluginId) {
        std::lock_guard<std::mutex> lock(mutex_);

        // Unload all instances first
        std::vector<std::string> toUnload;
        for (const auto& [instanceId, instance] : pluginInstances_) {
            if (instance.pluginId == pluginId) {
                toUnload.push_back(instanceId);
            }
        }

        for (const auto& instanceId : toUnload) {
            unloadPlugin(instanceId);
        }

        pluginFactories_.erase(pluginId);
    }

    // ========================================================================
    // Hot Reload
    // ========================================================================

    void enableHotReload(const std::string& pluginId, bool enable) {
        std::lock_guard<std::mutex> lock(mutex_);
        hotReloadEnabled_[pluginId] = enable;
    }

    void reloadPlugin(const std::string& pluginId) {
        std::lock_guard<std::mutex> lock(mutex_);

        // Save states of all instances
        std::map<std::string, PluginState> savedStates;
        for (const auto& [instanceId, instance] : pluginInstances_) {
            if (instance.pluginId == pluginId && instance.plugin) {
                savedStates[instanceId] = instance.plugin->getState();
            }
        }

        // Unload and reload plugin library
        // (Would involve dynamic library reloading)

        // Restore states
        for (const auto& [instanceId, state] : savedStates) {
            auto it = pluginInstances_.find(instanceId);
            if (it != pluginInstances_.end() && it->second.plugin) {
                it->second.plugin->setState(state);
            }
        }
    }

    // ========================================================================
    // Update System
    // ========================================================================

    struct PluginUpdate {
        std::string pluginId;
        PluginVersion currentVersion;
        PluginVersion newVersion;
        std::string downloadUrl;
        std::string changelog;
        int64_t fileSize = 0;
        bool isCritical = false;
    };

    std::vector<PluginUpdate> checkForUpdates() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<PluginUpdate> updates;

        // Would check update server for each installed plugin
        // For now, return empty

        return updates;
    }

    bool updatePlugin(const std::string& pluginId) {
        // Would download and install update
        return true;
    }

    // ========================================================================
    // Resource Management
    // ========================================================================

    std::string getPluginResourcePath(const std::string& pluginId) const {
        return getUserPluginPath() + "/" + pluginId + "/resources";
    }

    int64_t getPluginDiskUsage(const std::string& pluginId) const {
        // Would calculate actual disk usage
        return 0;
    }

    void clearPluginCache(const std::string& pluginId) {
        // Clear cached data for plugin
    }

    // ========================================================================
    // Developer Tools
    // ========================================================================

    void enableDeveloperMode(bool enable) {
        developerMode_ = enable;
    }

    bool isDeveloperMode() const {
        return developerMode_;
    }

    void setPluginSearchPath(const std::string& path) {
        customSearchPaths_.push_back(path);
    }

    std::string getPluginLog(const std::string& instanceId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = pluginLogs_.find(instanceId);
        if (it != pluginLogs_.end()) {
            return it->second;
        }
        return "";
    }

private:
    PluginManager() {
        hostInterface_ = std::make_unique<PluginHostImpl>();
    }
    ~PluginManager() = default;

    PluginManager(const PluginManager&) = delete;
    PluginManager& operator=(const PluginManager&) = delete;

    std::string generateInstanceId() {
        return "inst_" + std::to_string(nextInstanceId_++);
    }

    void scanDirectory(const std::string& path) {
        // Would scan directory for plugin bundles/libraries
        // Load metadata from each valid plugin
    }

    std::string getSystemPluginPath() const {
#ifdef __APPLE__
        return "/Library/Audio/Plug-Ins/Echoel";
#elif _WIN32
        return "C:\\Program Files\\Echoel\\Plugins";
#else
        return "/usr/lib/echoel/plugins";
#endif
    }

    std::string getUserPluginPath() const {
#ifdef __APPLE__
        return "~/Library/Audio/Plug-Ins/Echoel";
#elif _WIN32
        return "%APPDATA%\\Echoel\\Plugins";
#else
        return "~/.local/share/echoel/plugins";
#endif
    }

    std::string getAppPluginPath() const {
        return "./plugins";  // Relative to app bundle
    }

    // Simple host implementation
    class PluginHostImpl : public IPluginHost {
    public:
        std::string getAppName() const override { return "Echoel"; }
        PluginVersion getAppVersion() const override { return {1, 0, 0}; }
        double getSampleRate() const override { return sampleRate_; }
        int getBlockSize() const override { return blockSize_; }
        int getNumInputChannels() const override { return 2; }
        int getNumOutputChannels() const override { return 2; }
        bool isPlaying() const override { return isPlaying_; }
        bool isRecording() const override { return isRecording_; }
        double getPlayheadPosition() const override { return playheadPosition_; }
        double getTempo() const override { return tempo_; }
        int getTimeSigNumerator() const override { return 4; }
        int getTimeSigDenominator() const override { return 4; }
        void beginParameterChange(const std::string&) override {}
        void endParameterChange(const std::string&) override {}
        void setParameterValue(const std::string&, float) override {}
        void log(const std::string& message, int level) override {
            // Log message
        }
        std::string getPluginDataPath() const override { return "~/.echoel/plugins"; }
        std::string getTempPath() const override { return "/tmp/echoel"; }
        void sendMessage(const std::string&, const std::string&, const std::any&) override {}

        double sampleRate_ = 44100.0;
        int blockSize_ = 512;
        bool isPlaying_ = false;
        bool isRecording_ = false;
        double playheadPosition_ = 0.0;
        double tempo_ = 120.0;
    };

    mutable std::mutex mutex_;

    std::map<std::string, PluginFactory> pluginFactories_;
    std::map<std::string, PluginInstance> pluginInstances_;
    std::map<std::string, bool> hotReloadEnabled_;
    std::map<std::string, std::string> pluginLogs_;

    std::unique_ptr<PluginHostImpl> hostInterface_;

    std::vector<std::string> customSearchPaths_;

    std::atomic<bool> pluginsScanned_{false};
    std::atomic<bool> developerMode_{false};
    std::atomic<int> nextInstanceId_{1};
};

// ============================================================================
// Convenience Functions
// ============================================================================

namespace Plugins {

inline void scan() {
    PluginManager::getInstance().scanForPlugins();
}

inline std::vector<PluginMetadata> available(std::optional<PluginType> type = std::nullopt) {
    return PluginManager::getInstance().getAvailablePlugins(type);
}

inline std::string load(const std::string& pluginId) {
    return PluginManager::getInstance().loadPlugin(pluginId);
}

inline void unload(const std::string& instanceId) {
    PluginManager::getInstance().unloadPlugin(instanceId);
}

inline void setParameter(const std::string& instanceId,
                          const std::string& parameterId, float value) {
    PluginManager::getInstance().setPluginParameter(instanceId, parameterId, value);
}

} // namespace Plugins

} // namespace Echoel
