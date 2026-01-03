/*
  ==============================================================================

    EchoelCore.h
    Echoelmusic Central Activation System

    "Aktiviere das gesamte Repo!"

    Master controller that activates, initializes, and orchestrates all
    Echoelmusic modules including AI, Healing, DSP, Bio-Feedback, and
    Ralph Wiggum Loop Genius systems.

    Created: 2026
    Author: Echoelmusic Team

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <memory>
#include <vector>
#include <map>
#include <set>
#include <functional>
#include <atomic>
#include <mutex>
#include <thread>
#include <future>
#include <optional>
#include <chrono>
#include <typeindex>

namespace Echoelmusic
{

//==============================================================================
// Forward Declarations
//==============================================================================

class ModuleRegistry;
class SelfHealingSystem;
class StabilityLayer;
class RalphWiggumFoundation;

//==============================================================================
/** Module categories for organization */
enum class ModuleCategory
{
    Core,           // Essential system modules
    DSP,            // Digital signal processing
    AI,             // Artificial intelligence
    Healing,        // Wellness and healing
    Bio,            // Bio-feedback systems
    MIDI,           // MIDI processing
    Audio,          // Audio engine
    Visual,         // Visualization
    Hardware,       // Hardware integration
    Cloud,          // Cloud services
    UI,             // User interface
    Plugin,         // Plugin hosting
    Effects,        // Audio effects
    Synth,          // Synthesizers
    Sequencer,      // Sequencing
    Network,        // Networking
    Development,    // Dev tools
    Platform        // Platform integration
};

//==============================================================================
/** Module state for lifecycle management */
enum class ModuleState
{
    Unregistered,
    Registered,
    Initializing,
    Active,
    Suspended,
    Error,
    Recovering,
    ShuttingDown,
    Terminated
};

//==============================================================================
/** Module priority for initialization order */
enum class ModulePriority
{
    Critical = 0,       // Must initialize first (Core, Memory)
    High = 1,           // Early initialization (Audio, MIDI)
    Normal = 2,         // Standard modules
    Low = 3,            // Optional modules
    Background = 4      // Can initialize async
};

//==============================================================================
/** Health status for modules */
struct ModuleHealth
{
    float cpuUsage = 0.0f;          // 0-100%
    float memoryUsage = 0.0f;       // Bytes
    int errorCount = 0;
    int warningCount = 0;
    juce::Time lastActiveTime;
    juce::Time lastErrorTime;
    juce::String lastErrorMessage;
    bool isResponsive = true;
    float performanceScore = 100.0f; // 0-100
};

//==============================================================================
/** Module descriptor */
struct ModuleDescriptor
{
    juce::String id;
    juce::String name;
    juce::String version;
    juce::String description;
    ModuleCategory category;
    ModulePriority priority;
    ModuleState state = ModuleState::Unregistered;

    std::vector<juce::String> dependencies;
    std::vector<juce::String> optionalDependencies;
    std::vector<juce::String> provides;

    std::function<bool()> initFunc;
    std::function<void()> shutdownFunc;
    std::function<bool()> healthCheckFunc;
    std::function<bool()> recoverFunc;

    ModuleHealth health;
    bool autoRecover = true;
    int maxRecoveryAttempts = 3;
    int currentRecoveryAttempts = 0;

    bool isActive() const { return state == ModuleState::Active; }
    bool canRecover() const { return autoRecover && currentRecoveryAttempts < maxRecoveryAttempts; }
};

//==============================================================================
/** System-wide event for inter-module communication */
struct SystemEvent
{
    enum class Type
    {
        ModuleActivated,
        ModuleDeactivated,
        ModuleError,
        ModuleRecovered,
        SystemStartup,
        SystemShutdown,
        ConfigChanged,
        PerformanceWarning,
        HealthCheckFailed,
        Custom
    };

    Type type;
    juce::String sourceModule;
    juce::String message;
    juce::var data;
    juce::Time timestamp;
};

//==============================================================================
/** System event listener interface */
class SystemEventListener
{
public:
    virtual ~SystemEventListener() = default;
    virtual void onSystemEvent(const SystemEvent& event) = 0;
};

//==============================================================================
/**
    EchoelCore

    The heart of Echoelmusic - activates and orchestrates all systems.

    Features:
    - Module registration and dependency resolution
    - Automatic initialization order based on dependencies
    - Self-healing with automatic recovery
    - Health monitoring and performance tracking
    - Event-driven inter-module communication
    - Graceful shutdown with resource cleanup
    - Hot-reload support for development
*/
class EchoelCore : public juce::Timer
{
public:
    //==========================================================================
    // Singleton Access

    static EchoelCore& getInstance()
    {
        static EchoelCore instance;
        return instance;
    }

    //==========================================================================
    // System Lifecycle

    /**
        Activate the entire system.
        Initializes all registered modules in dependency order.

        @return true if all critical modules initialized successfully
    */
    bool activate()
    {
        if (systemActive.load())
            return true;

        juce::Logger::writeToLog("===========================================");
        juce::Logger::writeToLog("    ECHOELMUSIC CORE ACTIVATION");
        juce::Logger::writeToLog("    Ralph Wiggum Loop Genius Edition");
        juce::Logger::writeToLog("===========================================");

        activationStartTime = juce::Time::getCurrentTime();

        // Phase 1: Resolve dependencies
        if (!resolveDependencies())
        {
            juce::Logger::writeToLog("[CRITICAL] Dependency resolution failed!");
            return false;
        }

        // Phase 2: Initialize modules in order
        if (!initializeModules())
        {
            juce::Logger::writeToLog("[CRITICAL] Module initialization failed!");
            return false;
        }

        // Phase 3: Start health monitoring
        startTimer(healthCheckIntervalMs);

        // Phase 4: Fire system startup event
        fireEvent({SystemEvent::Type::SystemStartup, "Core", "System activated",
                   juce::var(), juce::Time::getCurrentTime()});

        systemActive.store(true);
        activationEndTime = juce::Time::getCurrentTime();

        auto duration = activationEndTime - activationStartTime;
        juce::Logger::writeToLog("===========================================");
        juce::Logger::writeToLog("    ACTIVATION COMPLETE");
        juce::Logger::writeToLog("    Time: " + juce::String(duration.inMilliseconds()) + "ms");
        juce::Logger::writeToLog("    Modules: " + juce::String(getActiveModuleCount()));
        juce::Logger::writeToLog("===========================================");

        return true;
    }

    /**
        Deactivate the system gracefully.
        Shuts down all modules in reverse order.
    */
    void deactivate()
    {
        if (!systemActive.load())
            return;

        juce::Logger::writeToLog("[Core] Beginning system deactivation...");

        // Stop health monitoring
        stopTimer();

        // Fire shutdown event
        fireEvent({SystemEvent::Type::SystemShutdown, "Core", "System deactivating",
                   juce::var(), juce::Time::getCurrentTime()});

        // Shutdown in reverse order
        shutdownModules();

        systemActive.store(false);
        juce::Logger::writeToLog("[Core] System deactivated.");
    }

    bool isActive() const { return systemActive.load(); }

    //==========================================================================
    // Module Registration

    /**
        Register a module with the system.

        @param descriptor Module descriptor with init/shutdown functions
        @return true if registration successful
    */
    bool registerModule(ModuleDescriptor descriptor)
    {
        std::lock_guard<std::mutex> lock(modulesMutex);

        if (modules.count(descriptor.id) > 0)
        {
            juce::Logger::writeToLog("[Core] Module already registered: " + descriptor.id);
            return false;
        }

        descriptor.state = ModuleState::Registered;
        modules[descriptor.id] = std::move(descriptor);

        juce::Logger::writeToLog("[Core] Registered module: " + modules[descriptor.id].name);
        return true;
    }

    /**
        Unregister a module from the system.
    */
    bool unregisterModule(const juce::String& moduleId)
    {
        std::lock_guard<std::mutex> lock(modulesMutex);

        auto it = modules.find(moduleId);
        if (it == modules.end())
            return false;

        if (it->second.state == ModuleState::Active)
        {
            if (it->second.shutdownFunc)
                it->second.shutdownFunc();
        }

        modules.erase(it);
        return true;
    }

    /**
        Get a module by ID.
    */
    std::optional<ModuleDescriptor> getModule(const juce::String& moduleId) const
    {
        std::lock_guard<std::mutex> lock(modulesMutex);
        auto it = modules.find(moduleId);
        if (it != modules.end())
            return it->second;
        return std::nullopt;
    }

    /**
        Get all modules in a category.
    */
    std::vector<ModuleDescriptor> getModulesByCategory(ModuleCategory category) const
    {
        std::lock_guard<std::mutex> lock(modulesMutex);
        std::vector<ModuleDescriptor> result;
        for (const auto& [id, module] : modules)
        {
            if (module.category == category)
                result.push_back(module);
        }
        return result;
    }

    //==========================================================================
    // Module Control

    /**
        Activate a specific module and its dependencies.
    */
    bool activateModule(const juce::String& moduleId)
    {
        std::lock_guard<std::mutex> lock(modulesMutex);

        auto it = modules.find(moduleId);
        if (it == modules.end())
            return false;

        return initializeModule(it->second);
    }

    /**
        Deactivate a specific module.
    */
    bool deactivateModule(const juce::String& moduleId)
    {
        std::lock_guard<std::mutex> lock(modulesMutex);

        auto it = modules.find(moduleId);
        if (it == modules.end())
            return false;

        if (it->second.shutdownFunc)
        {
            it->second.shutdownFunc();
        }
        it->second.state = ModuleState::Suspended;

        fireEvent({SystemEvent::Type::ModuleDeactivated, moduleId, "Module deactivated",
                   juce::var(), juce::Time::getCurrentTime()});

        return true;
    }

    /**
        Restart a module (shutdown + init).
    */
    bool restartModule(const juce::String& moduleId)
    {
        deactivateModule(moduleId);
        return activateModule(moduleId);
    }

    //==========================================================================
    // Health & Monitoring

    /**
        Get overall system health score.
    */
    float getSystemHealth() const
    {
        std::lock_guard<std::mutex> lock(modulesMutex);

        if (modules.empty())
            return 100.0f;

        float totalScore = 0.0f;
        int activeCount = 0;

        for (const auto& [id, module] : modules)
        {
            if (module.state == ModuleState::Active)
            {
                totalScore += module.health.performanceScore;
                activeCount++;
            }
        }

        return activeCount > 0 ? totalScore / activeCount : 0.0f;
    }

    /**
        Get count of active modules.
    */
    int getActiveModuleCount() const
    {
        std::lock_guard<std::mutex> lock(modulesMutex);
        int count = 0;
        for (const auto& [id, module] : modules)
        {
            if (module.state == ModuleState::Active)
                count++;
        }
        return count;
    }

    /**
        Get count of modules in error state.
    */
    int getErrorModuleCount() const
    {
        std::lock_guard<std::mutex> lock(modulesMutex);
        int count = 0;
        for (const auto& [id, module] : modules)
        {
            if (module.state == ModuleState::Error)
                count++;
        }
        return count;
    }

    //==========================================================================
    // Event System

    /**
        Add an event listener.
    */
    void addEventListener(SystemEventListener* listener)
    {
        std::lock_guard<std::mutex> lock(listenersMutex);
        eventListeners.insert(listener);
    }

    /**
        Remove an event listener.
    */
    void removeEventListener(SystemEventListener* listener)
    {
        std::lock_guard<std::mutex> lock(listenersMutex);
        eventListeners.erase(listener);
    }

    /**
        Fire a system event.
    */
    void fireEvent(const SystemEvent& event)
    {
        std::lock_guard<std::mutex> lock(listenersMutex);

        // Store in history
        eventHistory.push_back(event);
        if (eventHistory.size() > maxEventHistorySize)
            eventHistory.erase(eventHistory.begin());

        // Notify listeners
        for (auto* listener : eventListeners)
        {
            listener->onSystemEvent(event);
        }
    }

    /**
        Get event history.
    */
    const std::vector<SystemEvent>& getEventHistory() const
    {
        return eventHistory;
    }

    //==========================================================================
    // Configuration

    void setHealthCheckInterval(int intervalMs)
    {
        healthCheckIntervalMs = intervalMs;
        if (isTimerRunning())
        {
            stopTimer();
            startTimer(healthCheckIntervalMs);
        }
    }

    void setAutoRecoveryEnabled(bool enabled)
    {
        autoRecoveryEnabled = enabled;
    }

    //==========================================================================
    // Statistics

    juce::Time getActivationTime() const { return activationStartTime; }
    juce::Time getUptime() const { return juce::Time::getCurrentTime() - activationStartTime; }
    int getTotalModuleCount() const { return (int)modules.size(); }
    int getRecoveryCount() const { return totalRecoveryCount; }

    //==========================================================================
    // Serialization

    std::unique_ptr<juce::XmlElement> createStateXML() const
    {
        auto xml = std::make_unique<juce::XmlElement>("EchoelCore");

        xml->setAttribute("version", "1.0");
        xml->setAttribute("active", systemActive.load());
        xml->setAttribute("uptime", getUptime().inSeconds());

        auto* modulesXml = xml->createNewChildElement("Modules");
        for (const auto& [id, module] : modules)
        {
            auto* moduleXml = modulesXml->createNewChildElement("Module");
            moduleXml->setAttribute("id", module.id);
            moduleXml->setAttribute("name", module.name);
            moduleXml->setAttribute("state", static_cast<int>(module.state));
            moduleXml->setAttribute("category", static_cast<int>(module.category));
            moduleXml->setAttribute("health", module.health.performanceScore);
        }

        return xml;
    }

private:
    EchoelCore() = default;
    ~EchoelCore() { deactivate(); }

    EchoelCore(const EchoelCore&) = delete;
    EchoelCore& operator=(const EchoelCore&) = delete;

    //==========================================================================
    // Timer Callback (Health Checks)

    void timerCallback() override
    {
        performHealthChecks();
    }

    //==========================================================================
    // Internal Methods

    bool resolveDependencies()
    {
        juce::Logger::writeToLog("[Core] Resolving module dependencies...");

        // Build dependency graph
        std::map<juce::String, std::set<juce::String>> graph;
        std::map<juce::String, int> inDegree;

        for (const auto& [id, module] : modules)
        {
            inDegree[id] = 0;
        }

        for (const auto& [id, module] : modules)
        {
            for (const auto& dep : module.dependencies)
            {
                if (modules.count(dep) == 0)
                {
                    juce::Logger::writeToLog("[Core] Missing dependency: " + dep + " for " + id);
                    return false;
                }
                graph[dep].insert(id);
                inDegree[id]++;
            }
        }

        // Topological sort (Kahn's algorithm)
        std::queue<juce::String> queue;
        for (const auto& [id, degree] : inDegree)
        {
            if (degree == 0)
                queue.push(id);
        }

        initializationOrder.clear();
        while (!queue.empty())
        {
            auto current = queue.front();
            queue.pop();
            initializationOrder.push_back(current);

            for (const auto& dependent : graph[current])
            {
                inDegree[dependent]--;
                if (inDegree[dependent] == 0)
                    queue.push(dependent);
            }
        }

        // Check for cycles
        if (initializationOrder.size() != modules.size())
        {
            juce::Logger::writeToLog("[Core] Circular dependency detected!");
            return false;
        }

        // Sort by priority within dependency order
        std::stable_sort(initializationOrder.begin(), initializationOrder.end(),
            [this](const juce::String& a, const juce::String& b) {
                return modules[a].priority < modules[b].priority;
            });

        juce::Logger::writeToLog("[Core] Dependency resolution complete. Order:");
        for (const auto& id : initializationOrder)
        {
            juce::Logger::writeToLog("  - " + modules[id].name);
        }

        return true;
    }

    bool initializeModules()
    {
        juce::Logger::writeToLog("[Core] Initializing modules...");

        for (const auto& moduleId : initializationOrder)
        {
            auto& module = modules[moduleId];
            if (!initializeModule(module))
            {
                if (module.priority == ModulePriority::Critical)
                {
                    juce::Logger::writeToLog("[CRITICAL] Critical module failed: " + module.name);
                    return false;
                }
                juce::Logger::writeToLog("[WARNING] Non-critical module failed: " + module.name);
            }
        }

        return true;
    }

    bool initializeModule(ModuleDescriptor& module)
    {
        if (module.state == ModuleState::Active)
            return true;

        juce::Logger::writeToLog("[Core] Initializing: " + module.name);
        module.state = ModuleState::Initializing;

        // Check dependencies are active
        for (const auto& dep : module.dependencies)
        {
            if (modules[dep].state != ModuleState::Active)
            {
                juce::Logger::writeToLog("[Core] Dependency not active: " + dep);
                module.state = ModuleState::Error;
                return false;
            }
        }

        // Run initialization
        bool success = false;
        try
        {
            if (module.initFunc)
            {
                success = module.initFunc();
            }
            else
            {
                success = true;  // No init function = always succeeds
            }
        }
        catch (const std::exception& e)
        {
            module.health.lastErrorMessage = e.what();
            success = false;
        }

        if (success)
        {
            module.state = ModuleState::Active;
            module.health.lastActiveTime = juce::Time::getCurrentTime();
            juce::Logger::writeToLog("[Core] ✓ " + module.name + " activated");

            fireEvent({SystemEvent::Type::ModuleActivated, module.id, "Module activated",
                       juce::var(), juce::Time::getCurrentTime()});
        }
        else
        {
            module.state = ModuleState::Error;
            module.health.errorCount++;
            module.health.lastErrorTime = juce::Time::getCurrentTime();
            juce::Logger::writeToLog("[Core] ✗ " + module.name + " failed");

            fireEvent({SystemEvent::Type::ModuleError, module.id, module.health.lastErrorMessage,
                       juce::var(), juce::Time::getCurrentTime()});
        }

        return success;
    }

    void shutdownModules()
    {
        // Shutdown in reverse order
        for (auto it = initializationOrder.rbegin(); it != initializationOrder.rend(); ++it)
        {
            auto& module = modules[*it];
            if (module.state == ModuleState::Active)
            {
                juce::Logger::writeToLog("[Core] Shutting down: " + module.name);
                module.state = ModuleState::ShuttingDown;

                try
                {
                    if (module.shutdownFunc)
                        module.shutdownFunc();
                }
                catch (...)
                {
                    // Ignore shutdown errors
                }

                module.state = ModuleState::Terminated;
            }
        }
    }

    void performHealthChecks()
    {
        std::lock_guard<std::mutex> lock(modulesMutex);

        for (auto& [id, module] : modules)
        {
            if (module.state != ModuleState::Active)
                continue;

            // Run health check
            bool healthy = true;
            if (module.healthCheckFunc)
            {
                try
                {
                    healthy = module.healthCheckFunc();
                }
                catch (...)
                {
                    healthy = false;
                }
            }

            if (!healthy)
            {
                module.health.isResponsive = false;
                module.health.performanceScore = std::max(0.0f, module.health.performanceScore - 10.0f);

                fireEvent({SystemEvent::Type::HealthCheckFailed, id, "Health check failed",
                           juce::var(), juce::Time::getCurrentTime()});

                // Attempt recovery if enabled
                if (autoRecoveryEnabled && module.canRecover())
                {
                    attemptRecovery(module);
                }
            }
            else
            {
                module.health.isResponsive = true;
                module.health.lastActiveTime = juce::Time::getCurrentTime();
                module.health.performanceScore = std::min(100.0f, module.health.performanceScore + 1.0f);
            }
        }
    }

    void attemptRecovery(ModuleDescriptor& module)
    {
        juce::Logger::writeToLog("[Core] Attempting recovery for: " + module.name);
        module.state = ModuleState::Recovering;
        module.currentRecoveryAttempts++;
        totalRecoveryCount++;

        bool recovered = false;
        if (module.recoverFunc)
        {
            try
            {
                recovered = module.recoverFunc();
            }
            catch (...)
            {
                recovered = false;
            }
        }
        else
        {
            // Default recovery: restart
            if (module.shutdownFunc)
                module.shutdownFunc();

            if (module.initFunc)
                recovered = module.initFunc();
        }

        if (recovered)
        {
            module.state = ModuleState::Active;
            module.health.performanceScore = 80.0f;  // Start at 80% after recovery
            juce::Logger::writeToLog("[Core] Recovery successful: " + module.name);

            fireEvent({SystemEvent::Type::ModuleRecovered, module.id, "Module recovered",
                       juce::var(), juce::Time::getCurrentTime()});
        }
        else
        {
            module.state = ModuleState::Error;
            juce::Logger::writeToLog("[Core] Recovery failed: " + module.name);
        }
    }

    //==========================================================================
    // State

    std::atomic<bool> systemActive{false};

    std::map<juce::String, ModuleDescriptor> modules;
    mutable std::mutex modulesMutex;

    std::vector<juce::String> initializationOrder;

    std::set<SystemEventListener*> eventListeners;
    std::mutex listenersMutex;

    std::vector<SystemEvent> eventHistory;
    size_t maxEventHistorySize = 1000;

    juce::Time activationStartTime;
    juce::Time activationEndTime;

    int healthCheckIntervalMs = 5000;
    bool autoRecoveryEnabled = true;
    int totalRecoveryCount = 0;
};

//==============================================================================
/**
    ModuleBuilder

    Fluent builder for creating module descriptors.
*/
class ModuleBuilder
{
public:
    ModuleBuilder(const juce::String& id)
    {
        descriptor.id = id;
        descriptor.name = id;
        descriptor.version = "1.0.0";
        descriptor.priority = ModulePriority::Normal;
        descriptor.category = ModuleCategory::Core;
    }

    ModuleBuilder& name(const juce::String& n) { descriptor.name = n; return *this; }
    ModuleBuilder& version(const juce::String& v) { descriptor.version = v; return *this; }
    ModuleBuilder& description(const juce::String& d) { descriptor.description = d; return *this; }
    ModuleBuilder& category(ModuleCategory c) { descriptor.category = c; return *this; }
    ModuleBuilder& priority(ModulePriority p) { descriptor.priority = p; return *this; }

    ModuleBuilder& dependsOn(const juce::String& dep)
    {
        descriptor.dependencies.push_back(dep);
        return *this;
    }

    ModuleBuilder& optionallyDependsOn(const juce::String& dep)
    {
        descriptor.optionalDependencies.push_back(dep);
        return *this;
    }

    ModuleBuilder& provides(const juce::String& capability)
    {
        descriptor.provides.push_back(capability);
        return *this;
    }

    ModuleBuilder& onInit(std::function<bool()> func)
    {
        descriptor.initFunc = std::move(func);
        return *this;
    }

    ModuleBuilder& onShutdown(std::function<void()> func)
    {
        descriptor.shutdownFunc = std::move(func);
        return *this;
    }

    ModuleBuilder& onHealthCheck(std::function<bool()> func)
    {
        descriptor.healthCheckFunc = std::move(func);
        return *this;
    }

    ModuleBuilder& onRecover(std::function<bool()> func)
    {
        descriptor.recoverFunc = std::move(func);
        return *this;
    }

    ModuleBuilder& autoRecover(bool enabled)
    {
        descriptor.autoRecover = enabled;
        return *this;
    }

    ModuleBuilder& maxRecoveryAttempts(int max)
    {
        descriptor.maxRecoveryAttempts = max;
        return *this;
    }

    ModuleDescriptor build() { return std::move(descriptor); }

    bool registerWith(EchoelCore& core)
    {
        return core.registerModule(build());
    }

private:
    ModuleDescriptor descriptor;
};

} // namespace Echoelmusic
