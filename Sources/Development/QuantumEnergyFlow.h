#pragma once

#include <JuceHeader.h>
#include <atomic>
#include <functional>
#include <map>
#include <memory>
#include <cmath>

/**
 * ╔═══════════════════════════════════════════════════════════════════════════╗
 * ║   QUANTUM ENERGY FLOW - Universal Adaptive Optimization System            ║
 * ╠═══════════════════════════════════════════════════════════════════════════╣
 * ║                                                                           ║
 * ║   Super High Quantum Science Health Code Universal Energy Flow            ║
 * ║                                                                           ║
 * ║   Konzepte:                                                               ║
 * ║   - Adaptive Resource Allocation (Energy Flow)                            ║
 * ║   - Predictive Optimization (Quantum Superposition)                       ║
 * ║   - Bio-Reactive System Tuning                                            ║
 * ║   - Self-Organizing Performance                                           ║
 * ║   - Cross-Module Energy Balancing                                         ║
 * ║   - Dynamic Feature Prioritization                                        ║
 * ║   - Coherence-Based Optimization                                          ║
 * ║                                                                           ║
 * ║   Metapher: Die Software als lebendiger Organismus                        ║
 * ║   - "Energie" = Compute Resources (CPU, Memory, I/O)                      ║
 * ║   - "Fluss" = Dynamische Verteilung basierend auf Bedarf                 ║
 * ║   - "Quantum" = Parallele Optimierungspfade + Kollaps zur besten         ║
 * ║                                                                           ║
 * ╚═══════════════════════════════════════════════════════════════════════════╝
 */

namespace Echoel {

//==============================================================================
// Energy Types
//==============================================================================

enum class EnergyType
{
    CPU,            // Processing power
    Memory,         // RAM allocation
    GPU,            // Graphics/compute acceleration
    IO,             // Disk/Network bandwidth
    Audio,          // Audio thread priority
    UI,             // UI responsiveness
    Network,        // Network bandwidth
    Battery         // Power consumption (mobile)
};

//==============================================================================
// Module Energy Profile
//==============================================================================

struct ModuleEnergyProfile
{
    juce::String moduleName;

    // Current allocation (0-1)
    float cpuAllocation = 0.5f;
    float memoryAllocation = 0.5f;
    float ioAllocation = 0.5f;

    // Priority (1-10, higher = more important)
    int priority = 5;

    // Usage metrics
    float actualCpuUsage = 0.0f;
    float actualMemoryUsage = 0.0f;
    float efficiency = 1.0f;  // Output / Input ratio

    // Adaptivity settings
    bool canReduceQuality = true;
    bool canBeDisabled = false;
    float minimumAllocation = 0.1f;
    float maximumAllocation = 1.0f;
};

//==============================================================================
// System Energy State
//==============================================================================

struct SystemEnergyState
{
    // Total available resources (0-1 normalized)
    float totalCpuAvailable = 1.0f;
    float totalMemoryAvailable = 1.0f;
    float totalGpuAvailable = 1.0f;

    // Current utilization
    float cpuUtilization = 0.0f;
    float memoryUtilization = 0.0f;
    float gpuUtilization = 0.0f;

    // Battery state (mobile)
    float batteryLevel = 1.0f;
    bool isCharging = true;
    bool lowPowerMode = false;

    // Thermal state
    float thermalPressure = 0.0f;  // 0 = cool, 1 = throttling

    // Overall system coherence (0-1)
    float coherence = 1.0f;

    // Bio-data influence (if connected)
    float userCoherence = 0.5f;  // From HRV analysis
    float userEnergy = 0.5f;     // Estimated user energy level
};

//==============================================================================
// Optimization Strategy
//==============================================================================

enum class OptimizationStrategy
{
    Balanced,           // Equal priority to all
    Performance,        // Maximum speed
    Efficiency,         // Minimum resource usage
    BatteryLife,        // Conserve power
    LowLatency,         // Minimize audio latency
    HighQuality,        // Maximum audio/video quality
    UserAdaptive,       // Adapt to user behavior
    BioReactive         // Respond to biofeedback
};

//==============================================================================
// Quantum Energy Flow Manager
//==============================================================================

class QuantumEnergyFlow : public juce::Timer
{
public:
    //==========================================================================
    // Singleton Access
    //==========================================================================

    static QuantumEnergyFlow& getInstance()
    {
        static QuantumEnergyFlow instance;
        return instance;
    }

    //==========================================================================
    // Module Registration
    //==========================================================================

    /** Register a module for energy management */
    void registerModule(const juce::String& moduleName, const ModuleEnergyProfile& profile)
    {
        modules[moduleName] = profile;
        DBG("QuantumEnergyFlow: Registered module '" << moduleName << "'");
    }

    /** Unregister a module */
    void unregisterModule(const juce::String& moduleName)
    {
        modules.erase(moduleName);
    }

    /** Get module profile */
    ModuleEnergyProfile* getModuleProfile(const juce::String& moduleName)
    {
        auto it = modules.find(moduleName);
        return it != modules.end() ? &it->second : nullptr;
    }

    //==========================================================================
    // Energy Allocation
    //==========================================================================

    /** Request energy allocation for a module */
    float requestEnergy(const juce::String& moduleName, EnergyType type, float amount)
    {
        auto* profile = getModuleProfile(moduleName);
        if (!profile)
            return 0.0f;

        // Calculate available energy based on system state
        float available = getAvailableEnergy(type);
        float allocated = juce::jmin(amount, available * profile->maximumAllocation);

        // Update profile
        switch (type)
        {
            case EnergyType::CPU:
                profile->cpuAllocation = allocated;
                break;
            case EnergyType::Memory:
                profile->memoryAllocation = allocated;
                break;
            case EnergyType::IO:
                profile->ioAllocation = allocated;
                break;
            default:
                break;
        }

        return allocated;
    }

    /** Release energy back to the pool */
    void releaseEnergy(const juce::String& moduleName, EnergyType type, float amount)
    {
        auto* profile = getModuleProfile(moduleName);
        if (!profile)
            return;

        switch (type)
        {
            case EnergyType::CPU:
                profile->cpuAllocation = juce::jmax(profile->minimumAllocation,
                                                     profile->cpuAllocation - amount);
                break;
            case EnergyType::Memory:
                profile->memoryAllocation = juce::jmax(profile->minimumAllocation,
                                                        profile->memoryAllocation - amount);
                break;
            default:
                break;
        }
    }

    //==========================================================================
    // Strategy & Optimization
    //==========================================================================

    /** Set optimization strategy */
    void setStrategy(OptimizationStrategy strategy)
    {
        currentStrategy = strategy;
        rebalanceEnergy();
        DBG("QuantumEnergyFlow: Strategy changed to " << static_cast<int>(strategy));
    }

    OptimizationStrategy getStrategy() const { return currentStrategy; }

    /** Get current system energy state */
    SystemEnergyState getSystemState() const { return systemState; }

    /** Update bio-data for adaptive optimization */
    void updateBioData(float hrv, float coherence, float heartRate)
    {
        systemState.userCoherence = coherence;

        // Estimate user energy from heart rate
        // Low HR = relaxed/low energy, High HR = active/high energy
        systemState.userEnergy = juce::jmap(heartRate, 50.0f, 120.0f, 0.3f, 1.0f);

        // If user coherence is high and strategy is BioReactive, optimize for flow state
        if (currentStrategy == OptimizationStrategy::BioReactive && coherence > 0.7f)
        {
            enterFlowStateOptimization();
        }
    }

    //==========================================================================
    // Quantum Optimization (Parallel Path Exploration)
    //==========================================================================

    /** Run quantum-style optimization - explore multiple paths simultaneously */
    void runQuantumOptimization()
    {
        // "Superposition" - evaluate multiple configurations in parallel
        std::vector<std::pair<float, std::map<juce::String, ModuleEnergyProfile>>> candidates;

        // Generate candidate configurations
        for (int i = 0; i < numQuantumPaths; ++i)
        {
            auto candidate = generateCandidateConfiguration(i);
            float score = evaluateConfiguration(candidate);
            candidates.push_back({score, candidate});
        }

        // "Collapse" - select best configuration
        auto best = std::max_element(candidates.begin(), candidates.end(),
            [](const auto& a, const auto& b) { return a.first < b.first; });

        if (best != candidates.end() && best->first > currentConfigurationScore)
        {
            // Apply winning configuration
            modules = best->second;
            currentConfigurationScore = best->first;
            DBG("QuantumEnergyFlow: Quantum collapse to better configuration (score: "
                << best->first << ")");
        }
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(const SystemEnergyState&)> onStateChanged;
    std::function<void(const juce::String& module, float newAllocation)> onAllocationChanged;

    //==========================================================================
    // Configuration
    //==========================================================================

    void setOptimizationInterval(int intervalMs)
    {
        stopTimer();
        startTimer(intervalMs);
    }

    void setQuantumPaths(int paths) { numQuantumPaths = paths; }

private:
    //==========================================================================
    // Constructor (Private for Singleton)
    //==========================================================================

    QuantumEnergyFlow()
    {
        currentStrategy = OptimizationStrategy::Balanced;

        // Initialize system state
        updateSystemState();

        // Start optimization timer (every 2 seconds)
        startTimer(2000);
    }

    ~QuantumEnergyFlow()
    {
        stopTimer();
    }

    //==========================================================================
    // Timer Callback
    //==========================================================================

    void timerCallback() override
    {
        // Update system state
        updateSystemState();

        // Rebalance energy based on current strategy
        rebalanceEnergy();

        // Periodic quantum optimization
        quantumTimer++;
        if (quantumTimer >= quantumInterval)
        {
            quantumTimer = 0;
            runQuantumOptimization();
        }

        // Notify listeners
        if (onStateChanged)
            onStateChanged(systemState);
    }

    //==========================================================================
    // System State Update
    //==========================================================================

    void updateSystemState()
    {
        // CPU utilization (would need platform-specific implementation)
        float totalCpu = 0.0f;
        for (const auto& [name, profile] : modules)
        {
            totalCpu += profile.actualCpuUsage;
        }
        systemState.cpuUtilization = juce::jmin(1.0f, totalCpu);

        // Memory utilization
        int64_t usedMemory = juce::Process::getCurrentlyUsedMemory();
        // Assume 8GB total for now
        systemState.memoryUtilization = usedMemory / (8.0 * 1024 * 1024 * 1024);

        // Battery (mobile platforms)
#if JUCE_IOS || JUCE_ANDROID
        // Would need platform-specific battery API
        systemState.batteryLevel = 1.0f;
        systemState.isCharging = true;
#endif

        // Calculate overall coherence
        systemState.coherence = calculateSystemCoherence();
    }

    float calculateSystemCoherence()
    {
        // Coherence = how well-balanced is the system?
        float totalVariance = 0.0f;
        float avgUtilization = 0.0f;
        int count = 0;

        for (const auto& [name, profile] : modules)
        {
            avgUtilization += profile.efficiency;
            count++;
        }

        if (count > 0)
        {
            avgUtilization /= count;

            for (const auto& [name, profile] : modules)
            {
                float diff = profile.efficiency - avgUtilization;
                totalVariance += diff * diff;
            }

            totalVariance /= count;
        }

        // Low variance = high coherence
        return 1.0f / (1.0f + totalVariance * 10.0f);
    }

    //==========================================================================
    // Energy Balancing
    //==========================================================================

    void rebalanceEnergy()
    {
        switch (currentStrategy)
        {
            case OptimizationStrategy::Balanced:
                rebalanceBalanced();
                break;
            case OptimizationStrategy::Performance:
                rebalancePerformance();
                break;
            case OptimizationStrategy::Efficiency:
                rebalanceEfficiency();
                break;
            case OptimizationStrategy::BatteryLife:
                rebalanceBattery();
                break;
            case OptimizationStrategy::LowLatency:
                rebalanceLowLatency();
                break;
            case OptimizationStrategy::BioReactive:
                rebalanceBioReactive();
                break;
            default:
                rebalanceBalanced();
                break;
        }
    }

    void rebalanceBalanced()
    {
        // Distribute resources based on priority
        float totalPriority = 0.0f;
        for (const auto& [name, profile] : modules)
            totalPriority += profile.priority;

        for (auto& [name, profile] : modules)
        {
            float share = profile.priority / totalPriority;
            profile.cpuAllocation = share;
            profile.memoryAllocation = share;
        }
    }

    void rebalancePerformance()
    {
        // Give more to high-priority modules
        for (auto& [name, profile] : modules)
        {
            if (profile.priority >= 7)
            {
                profile.cpuAllocation = profile.maximumAllocation;
            }
            else
            {
                profile.cpuAllocation = profile.minimumAllocation;
            }
        }
    }

    void rebalanceEfficiency()
    {
        // Minimize resource usage based on actual needs
        for (auto& [name, profile] : modules)
        {
            // Only allocate what's actually being used + small buffer
            profile.cpuAllocation = juce::jmin(
                profile.actualCpuUsage * 1.2f + 0.1f,
                profile.maximumAllocation
            );
        }
    }

    void rebalanceBattery()
    {
        // Aggressively reduce non-essential modules
        for (auto& [name, profile] : modules)
        {
            if (profile.canBeDisabled)
            {
                profile.cpuAllocation = 0.0f;
            }
            else if (profile.canReduceQuality)
            {
                profile.cpuAllocation = profile.minimumAllocation;
            }
        }
    }

    void rebalanceLowLatency()
    {
        // Prioritize audio module
        for (auto& [name, profile] : modules)
        {
            if (name.containsIgnoreCase("audio") || name.containsIgnoreCase("engine"))
            {
                profile.cpuAllocation = profile.maximumAllocation;
            }
            else
            {
                profile.cpuAllocation = profile.minimumAllocation;
            }
        }
    }

    void rebalanceBioReactive()
    {
        // Adapt to user's current state
        float userEnergy = systemState.userEnergy;
        float userCoherence = systemState.userCoherence;

        for (auto& [name, profile] : modules)
        {
            // Match energy output to user energy level
            float targetAllocation = userEnergy * profile.maximumAllocation;

            // Smooth transition
            profile.cpuAllocation = profile.cpuAllocation * 0.9f + targetAllocation * 0.1f;
        }
    }

    void enterFlowStateOptimization()
    {
        // User is in flow state - optimize for minimal interruption
        DBG("QuantumEnergyFlow: User in flow state - optimizing for focus");

        // Disable notifications, auto-save at longer intervals, etc.
        for (auto& [name, profile] : modules)
        {
            if (name.containsIgnoreCase("notification") ||
                name.containsIgnoreCase("update") ||
                name.containsIgnoreCase("sync"))
            {
                profile.cpuAllocation = profile.minimumAllocation;
            }
        }
    }

    //==========================================================================
    // Quantum Optimization Helpers
    //==========================================================================

    std::map<juce::String, ModuleEnergyProfile> generateCandidateConfiguration(int seed)
    {
        auto candidate = modules;
        juce::Random rng(seed);

        // Mutate allocations randomly
        for (auto& [name, profile] : candidate)
        {
            float mutation = (rng.nextFloat() - 0.5f) * 0.3f;  // +/- 15%
            profile.cpuAllocation = juce::jlimit(
                profile.minimumAllocation,
                profile.maximumAllocation,
                profile.cpuAllocation + mutation
            );
        }

        return candidate;
    }

    float evaluateConfiguration(const std::map<juce::String, ModuleEnergyProfile>& config)
    {
        float score = 0.0f;
        float totalAllocation = 0.0f;

        for (const auto& [name, profile] : config)
        {
            // Score based on efficiency * priority
            score += profile.efficiency * profile.priority;
            totalAllocation += profile.cpuAllocation;
        }

        // Penalize over-allocation
        if (totalAllocation > 1.0f)
            score *= (1.0f / totalAllocation);

        // Bonus for matching current strategy
        score *= getStrategyMultiplier(config);

        return score;
    }

    float getStrategyMultiplier(const std::map<juce::String, ModuleEnergyProfile>& config)
    {
        // Evaluate how well this configuration matches our strategy
        switch (currentStrategy)
        {
            case OptimizationStrategy::LowLatency:
            {
                // Bonus if audio modules have high allocation
                for (const auto& [name, profile] : config)
                {
                    if (name.containsIgnoreCase("audio"))
                        return 1.0f + profile.cpuAllocation;
                }
                break;
            }
            case OptimizationStrategy::Efficiency:
            {
                // Bonus for low total allocation
                float total = 0.0f;
                for (const auto& [name, profile] : config)
                    total += profile.cpuAllocation;
                return 2.0f - total;
            }
            default:
                break;
        }
        return 1.0f;
    }

    float getAvailableEnergy(EnergyType type)
    {
        switch (type)
        {
            case EnergyType::CPU:
                return 1.0f - systemState.cpuUtilization;
            case EnergyType::Memory:
                return 1.0f - systemState.memoryUtilization;
            case EnergyType::GPU:
                return 1.0f - systemState.gpuUtilization;
            case EnergyType::Battery:
                return systemState.batteryLevel;
            default:
                return 1.0f;
        }
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    std::map<juce::String, ModuleEnergyProfile> modules;
    SystemEnergyState systemState;
    OptimizationStrategy currentStrategy;

    int numQuantumPaths = 5;
    int quantumInterval = 10;  // Run quantum optimization every 10 timer cycles
    int quantumTimer = 0;
    float currentConfigurationScore = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(QuantumEnergyFlow)
};

//==============================================================================
// Convenience Macros for Energy Management
//==============================================================================

#define ECHOEL_REGISTER_MODULE(name, priority) \
    QuantumEnergyFlow::getInstance().registerModule(name, {name, 0.5f, 0.5f, 0.5f, priority})

#define ECHOEL_REQUEST_CPU(name, amount) \
    QuantumEnergyFlow::getInstance().requestEnergy(name, EnergyType::CPU, amount)

#define ECHOEL_RELEASE_CPU(name, amount) \
    QuantumEnergyFlow::getInstance().releaseEnergy(name, EnergyType::CPU, amount)

} // namespace Echoel
