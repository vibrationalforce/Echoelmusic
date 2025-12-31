#pragma once

/**
 * EchoelMainController.h - Central Integration Hub
 *
 * ============================================================================
 *   RALPH WIGGUM GENIUS LOOP MODE - MASTER CONTROLLER
 * ============================================================================
 *
 *   ARCHITECTURE:
 *     ┌─────────────────────────────────────────────────────────────────┐
 *     │                    EchoelMainController                         │
 *     │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
 *     │  │  Audio   │ │   Bio    │ │  Laser   │ │    UI    │           │
 *     │  │  Engine  │ │  Engine  │ │  Engine  │ │  Engine  │           │
 *     │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘           │
 *     │       │            │            │            │                  │
 *     │       └────────────┴─────┬──────┴────────────┘                  │
 *     │                          │                                      │
 *     │                   ┌──────┴──────┐                               │
 *     │                   │  State Bus  │                               │
 *     │                   │ (Lock-Free) │                               │
 *     │                   └──────┬──────┘                               │
 *     │       ┌──────────────────┼──────────────────┐                   │
 *     │  ┌────┴────┐  ┌─────┴─────┐  ┌─────┴─────┐  │                   │
 *     │  │ Presets │  │  Network  │  │  Session  │  │                   │
 *     │  │ Manager │  │   Sync    │  │  Recorder │  │                   │
 *     │  └─────────┘  └───────────┘  └───────────┘  │                   │
 *     └─────────────────────────────────────────────────────────────────┘
 *
 *   THREAD SAFETY:
 *     - Lock-free state bus for real-time communication
 *     - Atomic state snapshots for UI updates
 *     - Message queue for async operations
 *
 *   LATENCY TARGETS:
 *     - State propagation: < 1ms
 *     - Audio-to-visual sync: < 2ms
 *     - Bio-to-audio response: < 5ms
 *
 * ============================================================================
 */

#include "../DSP/BrainwaveEntrainment.h"
#include "../DSP/EntrainmentOptimizations.h"
#include "../BioData/BioGestureOptimizations.h"
#include "../Visual/SuperLaserScanOptimizations.h"
#include "../Visual/BrainwaveLaserSync.h"
#include <JuceHeader.h>
#include <atomic>
#include <memory>
#include <functional>
#include <array>
#include <string>

namespace Echoel
{

//==============================================================================
// Forward Declarations
//==============================================================================

class EchoelAudioEngine;
class EchoelPresetManager;
class EchoelSessionRecorder;
class EchoelNetworkSync;
class EchoelPerformanceDashboard;

//==============================================================================
// System State (Lock-Free Snapshot)
//==============================================================================

struct alignas(64) SystemState
{
    // Audio State
    std::atomic<float> masterVolume{0.8f};
    std::atomic<float> audioLevel{0.0f};
    std::atomic<float> bassLevel{0.0f};
    std::atomic<float> midLevel{0.0f};
    std::atomic<float> highLevel{0.0f};
    std::atomic<bool> beatDetected{false};
    std::atomic<float> bpm{120.0f};

    // Entrainment State
    std::atomic<float> entrainmentFrequency{40.0f};
    std::atomic<float> entrainmentIntensity{0.8f};
    std::atomic<int> entrainmentPreset{0};  // SessionPreset enum
    std::atomic<bool> entrainmentActive{false};

    // Bio State
    std::atomic<float> heartRate{70.0f};
    std::atomic<float> hrv{0.5f};
    std::atomic<float> coherence{0.5f};
    std::atomic<float> stress{0.3f};
    std::atomic<float> breathingRate{12.0f};
    std::atomic<bool> breathInhale{true};

    // Laser State
    std::atomic<bool> laserEnabled{false};
    std::atomic<float> laserIntensity{0.8f};
    std::atomic<int> laserPattern{0};
    std::atomic<float> laserSpeed{1.0f};

    // System State
    std::atomic<bool> isPlaying{false};
    std::atomic<bool> isRecording{false};
    std::atomic<bool> networkConnected{false};
    std::atomic<double> sessionTime{0.0};

    // Performance Metrics
    std::atomic<float> audioLatencyMs{0.0f};
    std::atomic<float> renderLatencyMs{0.0f};
    std::atomic<float> cpuUsage{0.0f};
    std::atomic<int> fps{60};

    // Create snapshot for UI thread
    struct Snapshot
    {
        float masterVolume, audioLevel, bassLevel, midLevel, highLevel;
        bool beatDetected;
        float bpm;
        float entrainmentFrequency, entrainmentIntensity;
        int entrainmentPreset;
        bool entrainmentActive;
        float heartRate, hrv, coherence, stress, breathingRate;
        bool breathInhale;
        bool laserEnabled;
        float laserIntensity, laserSpeed;
        int laserPattern;
        bool isPlaying, isRecording, networkConnected;
        double sessionTime;
        float audioLatencyMs, renderLatencyMs, cpuUsage;
        int fps;
    };

    Snapshot getSnapshot() const noexcept
    {
        Snapshot s;
        s.masterVolume = masterVolume.load(std::memory_order_relaxed);
        s.audioLevel = audioLevel.load(std::memory_order_relaxed);
        s.bassLevel = bassLevel.load(std::memory_order_relaxed);
        s.midLevel = midLevel.load(std::memory_order_relaxed);
        s.highLevel = highLevel.load(std::memory_order_relaxed);
        s.beatDetected = beatDetected.load(std::memory_order_relaxed);
        s.bpm = bpm.load(std::memory_order_relaxed);
        s.entrainmentFrequency = entrainmentFrequency.load(std::memory_order_relaxed);
        s.entrainmentIntensity = entrainmentIntensity.load(std::memory_order_relaxed);
        s.entrainmentPreset = entrainmentPreset.load(std::memory_order_relaxed);
        s.entrainmentActive = entrainmentActive.load(std::memory_order_relaxed);
        s.heartRate = heartRate.load(std::memory_order_relaxed);
        s.hrv = hrv.load(std::memory_order_relaxed);
        s.coherence = coherence.load(std::memory_order_relaxed);
        s.stress = stress.load(std::memory_order_relaxed);
        s.breathingRate = breathingRate.load(std::memory_order_relaxed);
        s.breathInhale = breathInhale.load(std::memory_order_relaxed);
        s.laserEnabled = laserEnabled.load(std::memory_order_relaxed);
        s.laserIntensity = laserIntensity.load(std::memory_order_relaxed);
        s.laserSpeed = laserSpeed.load(std::memory_order_relaxed);
        s.laserPattern = laserPattern.load(std::memory_order_relaxed);
        s.isPlaying = isPlaying.load(std::memory_order_relaxed);
        s.isRecording = isRecording.load(std::memory_order_relaxed);
        s.networkConnected = networkConnected.load(std::memory_order_relaxed);
        s.sessionTime = sessionTime.load(std::memory_order_relaxed);
        s.audioLatencyMs = audioLatencyMs.load(std::memory_order_relaxed);
        s.renderLatencyMs = renderLatencyMs.load(std::memory_order_relaxed);
        s.cpuUsage = cpuUsage.load(std::memory_order_relaxed);
        s.fps = fps.load(std::memory_order_relaxed);
        return s;
    }
};

//==============================================================================
// Message Types for Async Communication
//==============================================================================

enum class MessageType : uint8_t
{
    // Transport
    Play,
    Stop,
    Pause,

    // Audio
    SetVolume,
    SetAudioFile,

    // Entrainment
    SetEntrainmentPreset,
    SetEntrainmentFrequency,
    SetEntrainmentIntensity,
    ToggleEntrainment,

    // Bio
    UpdateBioData,
    CalibrateHRV,

    // Laser
    SetLaserPattern,
    SetLaserIntensity,
    ToggleLaser,

    // Session
    StartRecording,
    StopRecording,
    LoadPreset,
    SavePreset,

    // Network
    ConnectNetwork,
    DisconnectNetwork,
    SyncState,

    // System
    Shutdown,
    ResetMetrics
};

struct Message
{
    MessageType type;
    float floatValue = 0.0f;
    int intValue = 0;
    std::string stringValue;
    double timestamp = 0.0;
};

//==============================================================================
// Lock-Free Message Queue
//==============================================================================

template<typename T, size_t Capacity = 256>
class LockFreeQueue
{
public:
    bool push(const T& item) noexcept
    {
        size_t currentTail = tail_.load(std::memory_order_relaxed);
        size_t nextTail = (currentTail + 1) % Capacity;

        if (nextTail == head_.load(std::memory_order_acquire))
            return false;  // Queue full

        buffer_[currentTail] = item;
        tail_.store(nextTail, std::memory_order_release);
        return true;
    }

    bool pop(T& item) noexcept
    {
        size_t currentHead = head_.load(std::memory_order_relaxed);

        if (currentHead == tail_.load(std::memory_order_acquire))
            return false;  // Queue empty

        item = buffer_[currentHead];
        head_.store((currentHead + 1) % Capacity, std::memory_order_release);
        return true;
    }

    bool isEmpty() const noexcept
    {
        return head_.load(std::memory_order_acquire) == tail_.load(std::memory_order_acquire);
    }

    size_t size() const noexcept
    {
        size_t head = head_.load(std::memory_order_acquire);
        size_t tail = tail_.load(std::memory_order_acquire);
        return (tail >= head) ? (tail - head) : (Capacity - head + tail);
    }

private:
    std::array<T, Capacity> buffer_;
    std::atomic<size_t> head_{0};
    std::atomic<size_t> tail_{0};
};

//==============================================================================
// Callback Types
//==============================================================================

using StateChangeCallback = std::function<void(const SystemState::Snapshot&)>;
using ErrorCallback = std::function<void(int code, const std::string& message)>;
using BeatCallback = std::function<void(double timestamp, float bpm)>;
using BreathCallback = std::function<void(bool inhale, float rate)>;

//==============================================================================
// Main Controller
//==============================================================================

class EchoelMainController : private juce::Timer
{
public:
    //==========================================================================
    // Singleton Access
    //==========================================================================

    static EchoelMainController& getInstance()
    {
        static EchoelMainController instance;
        return instance;
    }

    //==========================================================================
    // Initialization
    //==========================================================================

    void initialize(double sampleRate = 48000.0, int blockSize = 512)
    {
        if (initialized_.load(std::memory_order_acquire))
            return;

        sampleRate_ = sampleRate;
        blockSize_ = blockSize;

        // Initialize subsystems
        initializeAudio();
        initializeBio();
        initializeLaser();
        initializeNetwork();

        // Start update timer (60 Hz for UI updates)
        startTimerHz(60);

        initialized_.store(true, std::memory_order_release);
    }

    void shutdown()
    {
        if (!initialized_.load(std::memory_order_acquire))
            return;

        stopTimer();

        // Send shutdown message
        postMessage({MessageType::Shutdown});

        // Shutdown subsystems
        shutdownNetwork();
        shutdownLaser();
        shutdownBio();
        shutdownAudio();

        initialized_.store(false, std::memory_order_release);
    }

    bool isInitialized() const noexcept
    {
        return initialized_.load(std::memory_order_acquire);
    }

    //==========================================================================
    // State Access
    //==========================================================================

    SystemState& getState() noexcept { return state_; }
    const SystemState& getState() const noexcept { return state_; }

    SystemState::Snapshot getStateSnapshot() const noexcept
    {
        return state_.getSnapshot();
    }

    //==========================================================================
    // Transport Controls
    //==========================================================================

    void play()
    {
        state_.isPlaying.store(true, std::memory_order_release);
        postMessage({MessageType::Play});
        notifyStateChange();
    }

    void stop()
    {
        state_.isPlaying.store(false, std::memory_order_release);
        postMessage({MessageType::Stop});
        notifyStateChange();
    }

    void pause()
    {
        state_.isPlaying.store(false, std::memory_order_release);
        postMessage({MessageType::Pause});
        notifyStateChange();
    }

    bool isPlaying() const noexcept
    {
        return state_.isPlaying.load(std::memory_order_acquire);
    }

    //==========================================================================
    // Audio Controls
    //==========================================================================

    void setMasterVolume(float volume)
    {
        volume = juce::jlimit(0.0f, 1.0f, volume);
        state_.masterVolume.store(volume, std::memory_order_release);
        Message msg{MessageType::SetVolume};
        msg.floatValue = volume;
        postMessage(msg);
    }

    float getMasterVolume() const noexcept
    {
        return state_.masterVolume.load(std::memory_order_acquire);
    }

    //==========================================================================
    // Entrainment Controls
    //==========================================================================

    void setEntrainmentPreset(DSP::SessionPreset preset)
    {
        state_.entrainmentPreset.store(static_cast<int>(preset), std::memory_order_release);
        Message msg{MessageType::SetEntrainmentPreset};
        msg.intValue = static_cast<int>(preset);
        postMessage(msg);
        notifyStateChange();
    }

    void setEntrainmentFrequency(float hz)
    {
        hz = juce::jlimit(0.5f, 100.0f, hz);
        state_.entrainmentFrequency.store(hz, std::memory_order_release);
        Message msg{MessageType::SetEntrainmentFrequency};
        msg.floatValue = hz;
        postMessage(msg);
    }

    void setEntrainmentIntensity(float intensity)
    {
        intensity = juce::jlimit(0.0f, 1.0f, intensity);
        state_.entrainmentIntensity.store(intensity, std::memory_order_release);
        Message msg{MessageType::SetEntrainmentIntensity};
        msg.floatValue = intensity;
        postMessage(msg);
    }

    void toggleEntrainment(bool enabled)
    {
        state_.entrainmentActive.store(enabled, std::memory_order_release);
        postMessage({MessageType::ToggleEntrainment});
        notifyStateChange();
    }

    //==========================================================================
    // Bio Data Integration
    //==========================================================================

    void updateBioData(float heartRate, float hrv, float coherence, float stress)
    {
        state_.heartRate.store(heartRate, std::memory_order_release);
        state_.hrv.store(hrv, std::memory_order_release);
        state_.coherence.store(coherence, std::memory_order_release);
        state_.stress.store(stress, std::memory_order_release);

        // Propagate to laser system for bio-reactive visuals
        if (laserRenderer_)
        {
            // Bio-modulated intensity
            float bioIntensity = 0.5f + coherence * 0.5f;
            // laserRenderer_->setBioModulation(bioIntensity, hrv, stress);
        }
    }

    void updateBreathingState(bool inhale, float rate)
    {
        state_.breathInhale.store(inhale, std::memory_order_release);
        state_.breathingRate.store(rate, std::memory_order_release);

        if (breathCallback_)
        {
            breathCallback_(inhale, rate);
        }
    }

    //==========================================================================
    // Laser Controls
    //==========================================================================

    void setLaserEnabled(bool enabled)
    {
        state_.laserEnabled.store(enabled, std::memory_order_release);
        postMessage({MessageType::ToggleLaser});
        notifyStateChange();
    }

    void setLaserPattern(int patternIndex)
    {
        state_.laserPattern.store(patternIndex, std::memory_order_release);
        Message msg{MessageType::SetLaserPattern};
        msg.intValue = patternIndex;
        postMessage(msg);
    }

    void setLaserIntensity(float intensity)
    {
        intensity = juce::jlimit(0.0f, 1.0f, intensity);
        state_.laserIntensity.store(intensity, std::memory_order_release);
        Message msg{MessageType::SetLaserIntensity};
        msg.floatValue = intensity;
        postMessage(msg);
    }

    //==========================================================================
    // Session Recording
    //==========================================================================

    void startRecording()
    {
        state_.isRecording.store(true, std::memory_order_release);
        postMessage({MessageType::StartRecording});
        notifyStateChange();
    }

    void stopRecording()
    {
        state_.isRecording.store(false, std::memory_order_release);
        postMessage({MessageType::StopRecording});
        notifyStateChange();
    }

    bool isRecording() const noexcept
    {
        return state_.isRecording.load(std::memory_order_acquire);
    }

    //==========================================================================
    // Presets
    //==========================================================================

    void loadPreset(const std::string& name)
    {
        Message msg{MessageType::LoadPreset};
        msg.stringValue = name;
        postMessage(msg);
    }

    void savePreset(const std::string& name)
    {
        Message msg{MessageType::SavePreset};
        msg.stringValue = name;
        postMessage(msg);
    }

    //==========================================================================
    // Network Sync
    //==========================================================================

    void connectNetwork(const std::string& address, int port)
    {
        Message msg{MessageType::ConnectNetwork};
        msg.stringValue = address;
        msg.intValue = port;
        postMessage(msg);
    }

    void disconnectNetwork()
    {
        state_.networkConnected.store(false, std::memory_order_release);
        postMessage({MessageType::DisconnectNetwork});
        notifyStateChange();
    }

    bool isNetworkConnected() const noexcept
    {
        return state_.networkConnected.load(std::memory_order_acquire);
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    void onStateChange(StateChangeCallback callback)
    {
        stateChangeCallback_ = std::move(callback);
    }

    void onError(ErrorCallback callback)
    {
        errorCallback_ = std::move(callback);
    }

    void onBeat(BeatCallback callback)
    {
        beatCallback_ = std::move(callback);
    }

    void onBreath(BreathCallback callback)
    {
        breathCallback_ = std::move(callback);
    }

    //==========================================================================
    // Audio Processing (Called from Audio Thread)
    //==========================================================================

    void processAudioBlock(float* leftChannel, float* rightChannel, int numSamples)
    {
        if (!initialized_.load(std::memory_order_acquire))
            return;

        // Process messages from UI thread
        processMessages();

        // Update session time
        double blockDuration = static_cast<double>(numSamples) / sampleRate_;
        state_.sessionTime.store(
            state_.sessionTime.load(std::memory_order_relaxed) + blockDuration,
            std::memory_order_release
        );

        // Audio analysis for levels
        updateAudioLevels(leftChannel, rightChannel, numSamples);

        // Apply entrainment if active
        if (state_.entrainmentActive.load(std::memory_order_acquire))
        {
            // Entrainment processing would go here
        }

        // Apply master volume
        float volume = state_.masterVolume.load(std::memory_order_acquire);
        for (int i = 0; i < numSamples; ++i)
        {
            leftChannel[i] *= volume;
            rightChannel[i] *= volume;
        }
    }

    //==========================================================================
    // Render Update (Called from Render Thread)
    //==========================================================================

    void renderUpdate(double deltaTime)
    {
        if (!initialized_.load(std::memory_order_acquire))
            return;

        // Update laser renderer
        if (laserRenderer_)
        {
            laserRenderer_->renderFrame(deltaTime);

            // Get render metrics
            auto metrics = laserRenderer_->getMetrics();
            state_.renderLatencyMs.store(metrics.frameTimeUs / 1000.0f, std::memory_order_release);
            state_.fps.store(metrics.framesPerSecond, std::memory_order_release);
        }
    }

    //==========================================================================
    // Direct Access to Subsystems
    //==========================================================================

    LaserOptimization::UltraFastLaserRenderer* getLaserRenderer() noexcept
    {
        return laserRenderer_.get();
    }

    Visual::BrainwaveLaserSync* getBrainwaveSync() noexcept
    {
        return brainwaveSync_.get();
    }

private:
    //==========================================================================
    // Constructor (Private for Singleton)
    //==========================================================================

    EchoelMainController() = default;
    ~EchoelMainController() { shutdown(); }

    // Non-copyable
    EchoelMainController(const EchoelMainController&) = delete;
    EchoelMainController& operator=(const EchoelMainController&) = delete;

    //==========================================================================
    // Timer Callback (UI Thread Updates)
    //==========================================================================

    void timerCallback() override
    {
        // Notify UI of state changes
        if (stateChangeCallback_)
        {
            stateChangeCallback_(state_.getSnapshot());
        }

        // Check for beat detection
        if (state_.beatDetected.exchange(false, std::memory_order_acq_rel))
        {
            if (beatCallback_)
            {
                beatCallback_(
                    state_.sessionTime.load(std::memory_order_acquire),
                    state_.bpm.load(std::memory_order_acquire)
                );
            }
        }
    }

    //==========================================================================
    // Message Processing
    //==========================================================================

    void postMessage(const Message& msg)
    {
        messageQueue_.push(msg);
    }

    void processMessages()
    {
        Message msg;
        while (messageQueue_.pop(msg))
        {
            handleMessage(msg);
        }
    }

    void handleMessage(const Message& msg)
    {
        switch (msg.type)
        {
            case MessageType::SetEntrainmentPreset:
                // Apply preset to entrainment system
                break;

            case MessageType::SetLaserPattern:
                // Apply pattern to laser system
                break;

            case MessageType::StartRecording:
                // Start session recorder
                break;

            case MessageType::StopRecording:
                // Stop session recorder
                break;

            default:
                break;
        }
    }

    //==========================================================================
    // Subsystem Initialization
    //==========================================================================

    void initializeAudio()
    {
        // Audio engine initialization
    }

    void initializeBio()
    {
        // Bio data processing initialization
    }

    void initializeLaser()
    {
        laserRenderer_ = std::make_unique<LaserOptimization::UltraFastLaserRenderer>();
        brainwaveSync_ = std::make_unique<Visual::BrainwaveLaserSync>();
        brainwaveSync_->prepare(sampleRate_, blockSize_);
    }

    void initializeNetwork()
    {
        // Network sync initialization
    }

    void shutdownAudio() {}
    void shutdownBio() {}
    void shutdownLaser() { laserRenderer_.reset(); brainwaveSync_.reset(); }
    void shutdownNetwork() {}

    //==========================================================================
    // Audio Analysis
    //==========================================================================

    void updateAudioLevels(const float* left, const float* right, int numSamples)
    {
        float peak = 0.0f;
        float sum = 0.0f;

        for (int i = 0; i < numSamples; ++i)
        {
            float mono = (left[i] + right[i]) * 0.5f;
            float absVal = std::abs(mono);
            peak = std::max(peak, absVal);
            sum += mono * mono;
        }

        float rms = std::sqrt(sum / numSamples);

        // Smoothed update
        float currentLevel = state_.audioLevel.load(std::memory_order_relaxed);
        float newLevel = currentLevel * 0.9f + peak * 0.1f;
        state_.audioLevel.store(newLevel, std::memory_order_release);
    }

    void notifyStateChange()
    {
        // Will be picked up by timer callback
    }

    //==========================================================================
    // State
    //==========================================================================

    std::atomic<bool> initialized_{false};
    double sampleRate_ = 48000.0;
    int blockSize_ = 512;

    SystemState state_;
    LockFreeQueue<Message> messageQueue_;

    // Subsystems
    std::unique_ptr<LaserOptimization::UltraFastLaserRenderer> laserRenderer_;
    std::unique_ptr<Visual::BrainwaveLaserSync> brainwaveSync_;

    // Callbacks
    StateChangeCallback stateChangeCallback_;
    ErrorCallback errorCallback_;
    BeatCallback beatCallback_;
    BreathCallback breathCallback_;
};

//==============================================================================
// Convenience Macros
//==============================================================================

#define ECHOEL_CONTROLLER Echoel::EchoelMainController::getInstance()

}  // namespace Echoel
