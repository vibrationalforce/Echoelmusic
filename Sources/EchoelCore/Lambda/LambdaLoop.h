#pragma once
/**
 * EchoelCore - Lambda Loop Orchestrator
 *
 * The central nervous system of the Echoelmusic ecosystem.
 * Coordinates all subsystems in a unified, lock-free control loop.
 *
 * Architecture:
 * ┌─────────────────────────────────────────────────────────────┐
 * │                    Lambda Loop (60 Hz)                      │
 * │                                                             │
 * │  Bio Sensors ─► BioState ─► Photonic Processing            │
 * │       │                            │                        │
 * │       ▼                            ▼                        │
 * │  MCP Server ◄─────────────► Audio Engine                   │
 * │       │                            │                        │
 * │       ▼                            ▼                        │
 * │  AI Agents ─────────────► WebXR/Visuals                    │
 * └─────────────────────────────────────────────────────────────┘
 *
 * Features:
 * - Lock-free inter-system communication
 * - Priority-based resource allocation
 * - Graceful degradation under load
 * - Future-proof for quantum/photonic hardware
 *
 * MIT License - Echoelmusic 2026
 */

#include "../Bio/BioState.h"
#include "../Bio/BioMapping.h"
#include "../Lock-Free/SPSCQueue.h"
#include "../MCP/MCPBioServer.h"
#include "../WebXR/WebXRAudioBridge.h"
#include "../Photonic/PhotonicInterconnect.h"

#include <atomic>
#include <chrono>
#include <functional>
#include <array>
#include <cmath>

namespace EchoelCore {
namespace Lambda {

//==============================================================================
// Lambda Constants
//==============================================================================

// λ - The symbol of our unified consciousness interface
constexpr float kLambda = 1.0f;

// Control loop frequency
constexpr double kControlLoopHz = 60.0;
constexpr double kControlLoopIntervalMs = 1000.0 / kControlLoopHz;

// Maximum subsystems
constexpr size_t kMaxSubsystems = 16;
constexpr size_t kMaxEventQueue = 256;

//==============================================================================
// Lambda State Machine
//==============================================================================

enum class LambdaState {
    Dormant,        // System off
    Initializing,   // Starting up
    Calibrating,    // Establishing baselines
    Active,         // Normal operation
    Flowing,        // High coherence state
    Transcendent,   // Peak experience (λ∞)
    Degrading,      // Under load, reducing features
    Shutting_Down   // Graceful shutdown
};

//==============================================================================
// Subsystem Interface
//==============================================================================

/**
 * Base interface for all Lambda Loop subsystems.
 */
class LambdaSubsystem {
public:
    virtual ~LambdaSubsystem() = default;

    // Lifecycle
    virtual bool initialize() = 0;
    virtual void shutdown() = 0;

    // Called each tick of the Lambda Loop
    virtual void tick(double deltaTimeMs) = 0;

    // Get subsystem name
    virtual const char* getName() const = 0;

    // Get subsystem priority (higher = more important)
    virtual int getPriority() const { return 0; }

    // Check if subsystem is ready
    virtual bool isReady() const = 0;

    // Get load factor (0-1)
    virtual float getLoadFactor() const { return 0.0f; }
};

//==============================================================================
// Lambda Event
//==============================================================================

enum class LambdaEventType {
    // Bio Events
    BioUpdate,
    CoherenceChanged,
    HeartbeatDetected,
    BreathCycleComplete,

    // System Events
    StateTransition,
    SubsystemConnected,
    SubsystemDisconnected,
    PerformanceWarning,

    // External Events
    MCPMessage,
    XRSessionStart,
    XRSessionEnd,
    PhotonicChannelReady,

    // User Events
    SessionStart,
    SessionEnd,
    PresetLoaded,
    ParameterChanged
};

struct LambdaEvent {
    LambdaEventType type;
    uint64_t timestamp;
    uint32_t sourceId;
    float value1;
    float value2;
    float value3;
    float value4;
};

//==============================================================================
// Lambda Loop Orchestrator
//==============================================================================

/**
 * The Lambda Loop - Central orchestrator for all Echoelmusic systems.
 *
 * Usage:
 *   LambdaLoop loop;
 *   loop.initialize();
 *
 *   // Add subsystems
 *   loop.addSubsystem(&audioEngine);
 *   loop.addSubsystem(&visualEngine);
 *
 *   // Start the loop
 *   loop.start();
 *
 *   // Tick from main thread or timer
 *   while (running) {
 *       loop.tick();
 *   }
 */
class LambdaLoop {
public:
    using EventCallback = std::function<void(const LambdaEvent&)>;

    LambdaLoop() noexcept
        : mBioState()
        , mBioMapper()
        , mMcpServer(nullptr)
        , mWebXRBridge(nullptr)
        , mPhotonicInterconnect(nullptr)
        , mState(LambdaState::Dormant)
        , mNumSubsystems(0)
        , mRunning(false)
        , mTickCount(0)
        , mLastTickTime(0)
        , mLambdaScore(0.0f)
        , mCoherenceHistory{}
        , mCoherenceHistoryIndex(0)
    {}

    ~LambdaLoop() {
        if (mRunning.load()) {
            stop();
        }
    }

    //==========================================================================
    // Initialization
    //==========================================================================

    /**
     * Initialize the Lambda Loop and all core subsystems.
     */
    bool initialize() {
        if (mState != LambdaState::Dormant) return false;

        transitionTo(LambdaState::Initializing);

        // Initialize core components
        mMcpServer = std::make_unique<MCP::MCPBioServer>(mBioState);
        mWebXRBridge = std::make_unique<WebXR::WebXRAudioBridge>(mBioState);
        mPhotonicInterconnect = std::make_unique<Photonic::PhotonicInterconnect>(mBioState);

        if (!mMcpServer->initialize()) return false;
        if (!mPhotonicInterconnect->initialize()) return false;

        transitionTo(LambdaState::Calibrating);

        // Initialize all registered subsystems
        for (size_t i = 0; i < mNumSubsystems; ++i) {
            if (!mSubsystems[i]->initialize()) {
                return false;
            }
        }

        transitionTo(LambdaState::Active);
        return true;
    }

    /**
     * Shutdown the Lambda Loop.
     */
    void shutdown() {
        transitionTo(LambdaState::Shutting_Down);

        // Shutdown subsystems in reverse priority order
        for (int i = static_cast<int>(mNumSubsystems) - 1; i >= 0; --i) {
            mSubsystems[i]->shutdown();
        }

        if (mMcpServer) mMcpServer->shutdown();

        mRunning.store(false);
        transitionTo(LambdaState::Dormant);
    }

    //==========================================================================
    // Subsystem Management
    //==========================================================================

    /**
     * Add a subsystem to the Lambda Loop.
     * Subsystems are sorted by priority (higher priority ticks first).
     */
    bool addSubsystem(LambdaSubsystem* subsystem) {
        if (!subsystem || mNumSubsystems >= kMaxSubsystems) return false;

        // Insert sorted by priority
        size_t insertIndex = mNumSubsystems;
        for (size_t i = 0; i < mNumSubsystems; ++i) {
            if (subsystem->getPriority() > mSubsystems[i]->getPriority()) {
                insertIndex = i;
                break;
            }
        }

        // Shift elements
        for (size_t i = mNumSubsystems; i > insertIndex; --i) {
            mSubsystems[i] = mSubsystems[i - 1];
        }

        mSubsystems[insertIndex] = subsystem;
        mNumSubsystems++;

        pushEvent({
            LambdaEventType::SubsystemConnected,
            getCurrentTimestamp(),
            static_cast<uint32_t>(insertIndex),
            0.0f, 0.0f, 0.0f, 0.0f
        });

        return true;
    }

    /**
     * Remove a subsystem.
     */
    bool removeSubsystem(LambdaSubsystem* subsystem) {
        for (size_t i = 0; i < mNumSubsystems; ++i) {
            if (mSubsystems[i] == subsystem) {
                // Shift remaining
                for (size_t j = i; j < mNumSubsystems - 1; ++j) {
                    mSubsystems[j] = mSubsystems[j + 1];
                }
                mNumSubsystems--;

                pushEvent({
                    LambdaEventType::SubsystemDisconnected,
                    getCurrentTimestamp(),
                    static_cast<uint32_t>(i),
                    0.0f, 0.0f, 0.0f, 0.0f
                });

                return true;
            }
        }
        return false;
    }

    //==========================================================================
    // Control Loop
    //==========================================================================

    /**
     * Start the Lambda Loop.
     */
    void start() {
        mRunning.store(true);
        mLastTickTime = getCurrentTimestamp();
    }

    /**
     * Stop the Lambda Loop.
     */
    void stop() {
        mRunning.store(false);
    }

    /**
     * Main tick function - call this at 60Hz.
     * Orchestrates all subsystems and processes events.
     */
    void tick() {
        if (!mRunning.load()) return;

        uint64_t now = getCurrentTimestamp();
        double deltaMs = static_cast<double>(now - mLastTickTime) / 1000000.0;
        mLastTickTime = now;
        mTickCount++;

        // Phase 1: Update bio state and compute lambda score
        updateLambdaScore();

        // Phase 2: Check for state transitions
        checkStateTransitions();

        // Phase 3: Tick all subsystems (priority order)
        tickSubsystems(deltaMs);

        // Phase 4: Process event queue
        processEvents();

        // Phase 5: Apply bio-reactive modulation
        applyBioModulation();

        // Phase 6: Performance monitoring
        monitorPerformance(deltaMs);
    }

    /**
     * Check if the loop is running.
     */
    bool isRunning() const noexcept {
        return mRunning.load();
    }

    //==========================================================================
    // Bio Interface
    //==========================================================================

    /**
     * Get the bio state (for subsystems).
     */
    BioState& getBioState() noexcept { return mBioState; }
    const BioState& getBioState() const noexcept { return mBioState; }

    /**
     * Get the bio mapper.
     */
    BioMapper& getBioMapper() noexcept { return mBioMapper; }

    /**
     * Update bio data from sensors.
     * Thread-safe, can be called from sensor thread.
     */
    void updateBioData(float hrv, float coherence, float heartRate, float breathPhase) {
        mBioState.update(hrv, coherence, heartRate, breathPhase);

        pushEvent({
            LambdaEventType::BioUpdate,
            getCurrentTimestamp(),
            0,
            hrv, coherence, heartRate, breathPhase
        });

        // Track coherence changes
        float prevCoherence = mCoherenceHistory[mCoherenceHistoryIndex];
        mCoherenceHistoryIndex = (mCoherenceHistoryIndex + 1) % kCoherenceHistorySize;
        mCoherenceHistory[mCoherenceHistoryIndex] = coherence;

        if (std::abs(coherence - prevCoherence) > 0.1f) {
            pushEvent({
                LambdaEventType::CoherenceChanged,
                getCurrentTimestamp(),
                0,
                prevCoherence, coherence, 0.0f, 0.0f
            });
        }
    }

    //==========================================================================
    // Core Component Access
    //==========================================================================

    MCP::MCPBioServer* getMcpServer() noexcept {
        return mMcpServer.get();
    }

    WebXR::WebXRAudioBridge* getWebXRBridge() noexcept {
        return mWebXRBridge.get();
    }

    Photonic::PhotonicInterconnect* getPhotonicInterconnect() noexcept {
        return mPhotonicInterconnect.get();
    }

    //==========================================================================
    // Lambda Score & State
    //==========================================================================

    /**
     * Get the Lambda Score (0-1).
     * Represents the unified coherence of the entire system.
     *
     * λ = weighted(bio_coherence, system_load, subsystem_health)
     */
    float getLambdaScore() const noexcept {
        return mLambdaScore.load();
    }

    /**
     * Get current state.
     */
    LambdaState getState() const noexcept {
        return mState.load();
    }

    /**
     * Get state name.
     */
    static const char* getStateName(LambdaState state) {
        switch (state) {
            case LambdaState::Dormant:       return "Dormant";
            case LambdaState::Initializing:  return "Initializing";
            case LambdaState::Calibrating:   return "Calibrating";
            case LambdaState::Active:        return "Active";
            case LambdaState::Flowing:       return "Flowing";
            case LambdaState::Transcendent:  return "Transcendent (λ∞)";
            case LambdaState::Degrading:     return "Degrading";
            case LambdaState::Shutting_Down: return "Shutting Down";
            default:                         return "Unknown";
        }
    }

    //==========================================================================
    // Event System
    //==========================================================================

    /**
     * Register an event callback.
     */
    void setEventCallback(EventCallback callback) {
        mEventCallback = std::move(callback);
    }

    /**
     * Push an event to the queue.
     * Thread-safe.
     */
    void pushEvent(const LambdaEvent& event) {
        mEventQueue.push(event);
    }

    //==========================================================================
    // Statistics
    //==========================================================================

    struct Stats {
        LambdaState state;
        float lambdaScore;
        uint64_t tickCount;
        double avgTickTimeMs;
        size_t numSubsystems;
        size_t readySubsystems;
        float systemLoad;
        float coherenceTrend;  // -1 to +1 (decreasing to increasing)
    };

    Stats getStats() const noexcept {
        Stats stats{};
        stats.state = mState.load();
        stats.lambdaScore = mLambdaScore.load();
        stats.tickCount = mTickCount;
        stats.avgTickTimeMs = mAvgTickTimeMs;
        stats.numSubsystems = mNumSubsystems;

        size_t ready = 0;
        float totalLoad = 0.0f;
        for (size_t i = 0; i < mNumSubsystems; ++i) {
            if (mSubsystems[i]->isReady()) ready++;
            totalLoad += mSubsystems[i]->getLoadFactor();
        }
        stats.readySubsystems = ready;
        stats.systemLoad = mNumSubsystems > 0 ? totalLoad / mNumSubsystems : 0.0f;
        stats.coherenceTrend = computeCoherenceTrend();

        return stats;
    }

private:
    // Core components
    BioState mBioState;
    BioMapper mBioMapper;
    std::unique_ptr<MCP::MCPBioServer> mMcpServer;
    std::unique_ptr<WebXR::WebXRAudioBridge> mWebXRBridge;
    std::unique_ptr<Photonic::PhotonicInterconnect> mPhotonicInterconnect;

    // State
    std::atomic<LambdaState> mState;

    // Subsystems
    std::array<LambdaSubsystem*, kMaxSubsystems> mSubsystems{};
    size_t mNumSubsystems;

    // Control loop
    std::atomic<bool> mRunning;
    uint64_t mTickCount;
    uint64_t mLastTickTime;
    double mAvgTickTimeMs = 0.0;

    // Lambda score
    std::atomic<float> mLambdaScore;

    // Coherence history for trend detection
    static constexpr size_t kCoherenceHistorySize = 60;  // 1 second at 60Hz
    std::array<float, kCoherenceHistorySize> mCoherenceHistory{};
    size_t mCoherenceHistoryIndex = 0;

    // Event queue
    SPSCQueue<LambdaEvent, kMaxEventQueue> mEventQueue;
    EventCallback mEventCallback;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void transitionTo(LambdaState newState) {
        LambdaState oldState = mState.exchange(newState);
        if (oldState != newState) {
            pushEvent({
                LambdaEventType::StateTransition,
                getCurrentTimestamp(),
                0,
                static_cast<float>(oldState),
                static_cast<float>(newState),
                0.0f, 0.0f
            });
        }
    }

    void updateLambdaScore() {
        // Bio component (50% weight)
        float bioScore = mBioState.getCoherence() * 0.5f +
                         mBioState.getHRV() * 0.3f +
                         mBioState.getRelaxation() * 0.2f;

        // System health component (30% weight)
        float systemScore = 0.0f;
        if (mNumSubsystems > 0) {
            size_t ready = 0;
            for (size_t i = 0; i < mNumSubsystems; ++i) {
                if (mSubsystems[i]->isReady()) ready++;
            }
            systemScore = static_cast<float>(ready) / static_cast<float>(mNumSubsystems);
        } else {
            systemScore = 1.0f;  // No subsystems = full score
        }

        // Performance component (20% weight)
        float perfScore = 1.0f;
        if (mNumSubsystems > 0) {
            float totalLoad = 0.0f;
            for (size_t i = 0; i < mNumSubsystems; ++i) {
                totalLoad += mSubsystems[i]->getLoadFactor();
            }
            perfScore = 1.0f - (totalLoad / mNumSubsystems);
        }

        // Compute weighted lambda score
        float lambda = bioScore * 0.5f + systemScore * 0.3f + perfScore * 0.2f;

        // Smooth the score
        float prev = mLambdaScore.load();
        float smoothed = prev * 0.9f + lambda * 0.1f;
        mLambdaScore.store(smoothed);
    }

    void checkStateTransitions() {
        LambdaState current = mState.load();
        float lambda = mLambdaScore.load();
        float coherence = mBioState.getCoherence();

        switch (current) {
            case LambdaState::Active:
                if (lambda > 0.8f && coherence > 0.7f) {
                    transitionTo(LambdaState::Flowing);
                }
                if (getTotalLoad() > 0.9f) {
                    transitionTo(LambdaState::Degrading);
                }
                break;

            case LambdaState::Flowing:
                if (lambda > 0.95f && coherence > 0.9f) {
                    transitionTo(LambdaState::Transcendent);
                }
                if (lambda < 0.7f) {
                    transitionTo(LambdaState::Active);
                }
                break;

            case LambdaState::Transcendent:
                if (lambda < 0.9f) {
                    transitionTo(LambdaState::Flowing);
                }
                break;

            case LambdaState::Degrading:
                if (getTotalLoad() < 0.7f) {
                    transitionTo(LambdaState::Active);
                }
                break;

            default:
                break;
        }
    }

    void tickSubsystems(double deltaMs) {
        for (size_t i = 0; i < mNumSubsystems; ++i) {
            // Skip low-priority systems if degrading
            if (mState.load() == LambdaState::Degrading &&
                mSubsystems[i]->getPriority() < 5) {
                continue;
            }
            mSubsystems[i]->tick(deltaMs);
        }
    }

    void processEvents() {
        LambdaEvent event;
        size_t processed = 0;
        constexpr size_t kMaxEventsPerTick = 16;

        while (mEventQueue.pop(event) && processed < kMaxEventsPerTick) {
            if (mEventCallback) {
                mEventCallback(event);
            }
            processed++;
        }
    }

    void applyBioModulation() {
        // Apply bio-reactive layout to WebXR sources
        if (mWebXRBridge) {
            mWebXRBridge->applyBioReactiveLayout();
        }
    }

    void monitorPerformance(double deltaMs) {
        // Update average tick time
        mAvgTickTimeMs = mAvgTickTimeMs * 0.99 + deltaMs * 0.01;

        // Warn if falling behind
        if (deltaMs > kControlLoopIntervalMs * 2.0) {
            pushEvent({
                LambdaEventType::PerformanceWarning,
                getCurrentTimestamp(),
                0,
                static_cast<float>(deltaMs),
                static_cast<float>(kControlLoopIntervalMs),
                0.0f, 0.0f
            });
        }
    }

    float getTotalLoad() const noexcept {
        if (mNumSubsystems == 0) return 0.0f;
        float total = 0.0f;
        for (size_t i = 0; i < mNumSubsystems; ++i) {
            total += mSubsystems[i]->getLoadFactor();
        }
        return total / mNumSubsystems;
    }

    float computeCoherenceTrend() const noexcept {
        // Compare recent coherence to older values
        float recent = 0.0f, older = 0.0f;
        size_t halfSize = kCoherenceHistorySize / 2;

        for (size_t i = 0; i < halfSize; ++i) {
            size_t recentIdx = (mCoherenceHistoryIndex - i + kCoherenceHistorySize) % kCoherenceHistorySize;
            size_t olderIdx = (mCoherenceHistoryIndex - i - halfSize + kCoherenceHistorySize) % kCoherenceHistorySize;
            recent += mCoherenceHistory[recentIdx];
            older += mCoherenceHistory[olderIdx];
        }

        recent /= halfSize;
        older /= halfSize;

        return std::clamp(recent - older, -1.0f, 1.0f);
    }

    static uint64_t getCurrentTimestamp() noexcept {
        auto now = std::chrono::steady_clock::now();
        return static_cast<uint64_t>(
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                now.time_since_epoch()
            ).count()
        );
    }
};

//==============================================================================
// Lambda Subsystem Adapters
//==============================================================================

/**
 * Adapter to wrap an audio processing callback as a Lambda Subsystem.
 */
class AudioSubsystemAdapter : public LambdaSubsystem {
public:
    using ProcessCallback = std::function<void(double)>;

    AudioSubsystemAdapter(ProcessCallback callback)
        : mCallback(std::move(callback))
        , mReady(false)
        , mLoad(0.0f)
    {}

    bool initialize() override {
        mReady = true;
        return true;
    }

    void shutdown() override {
        mReady = false;
    }

    void tick(double deltaTimeMs) override {
        if (mCallback) {
            auto start = std::chrono::steady_clock::now();
            mCallback(deltaTimeMs);
            auto end = std::chrono::steady_clock::now();

            double elapsed = std::chrono::duration<double, std::milli>(end - start).count();
            mLoad = static_cast<float>(elapsed / deltaTimeMs);
        }
    }

    const char* getName() const override { return "AudioSubsystem"; }
    int getPriority() const override { return 100; }  // Highest priority
    bool isReady() const override { return mReady; }
    float getLoadFactor() const override { return mLoad; }

private:
    ProcessCallback mCallback;
    bool mReady;
    float mLoad;
};

/**
 * Adapter for visual processing subsystem.
 */
class VisualSubsystemAdapter : public LambdaSubsystem {
public:
    using RenderCallback = std::function<void(double)>;

    VisualSubsystemAdapter(RenderCallback callback)
        : mCallback(std::move(callback))
        , mReady(false)
        , mLoad(0.0f)
    {}

    bool initialize() override {
        mReady = true;
        return true;
    }

    void shutdown() override {
        mReady = false;
    }

    void tick(double deltaTimeMs) override {
        if (mCallback) {
            mCallback(deltaTimeMs);
        }
    }

    const char* getName() const override { return "VisualSubsystem"; }
    int getPriority() const override { return 50; }
    bool isReady() const override { return mReady; }
    float getLoadFactor() const override { return mLoad; }

    void setLoadFactor(float load) { mLoad = load; }

private:
    RenderCallback mCallback;
    bool mReady;
    float mLoad;
};

} // namespace Lambda
} // namespace EchoelCore
