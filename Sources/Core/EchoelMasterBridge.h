/*
  ==============================================================================

    EchoelMasterBridge.h
    Echoelmusic - Bio-Reactive DAW

    UNIFIED MASTER INTEGRATION LAYER
    Connects ALL systems: Audio, Video, AI, Bio, Hardware, Visual, Cloud

    This is the central nervous system of Echoelmusic.

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>

// Core Systems
#include "RalphWiggumAPI.h"
#include "RalphWiggumFoundation.h"
#include "RalphWiggumAIBridge.h"
#include "ProgressiveDisclosureEngine.h"
#include "WiseSaveMode.h"
#include "LatentDemandDetector.h"
#include "PresetManager.h"
#include "MusicTheoryUtils.h"
#include "EchoelCore.h"

// AI Systems
#include "../AI/AICompositionEngine.h"
#include "../AI/StyleTransferEngine.h"
#include "../AI/SmartMixer.h"
#include "../AI/PatternGenerator.h"

// GUI
#include "../GUI/EchoelMainWindow.h"
#include "../GUI/BioReactiveLookAndFeel.h"

// Multimedia
#include "../Multimedia/QuantumMediaBridge.h"

// Visual
#include "../Visual/LaserForce.h"
#include "../Visual/LaserScanEngine.h"

// Video
#include "../Video/VideoSyncEngine.h"
#include "../Video/VideoEditEngine.h"

// Plugin
#include "../Plugin/PluginHostSystem.h"

// Hardware
#include "../Hardware/AbletonLink.h"
#include "../Hardware/MIDIHardwareManager.h"
#include "../Hardware/OSCManager.h"

#include <memory>
#include <vector>
#include <map>
#include <mutex>
#include <atomic>
#include <thread>
#include <functional>
#include <chrono>

namespace Echoel {

//==============================================================================
/**
    System status for each subsystem
*/
struct SubsystemStatus
{
    juce::String name;
    bool initialized = false;
    bool running = false;
    bool hasError = false;
    juce::String errorMessage;
    float cpuUsage = 0.0f;
    float memoryUsage = 0.0f;
    juce::Time lastUpdate;
};

//==============================================================================
/**
    Global session state shared across all systems
*/
struct GlobalSessionState
{
    // Transport
    bool isPlaying = false;
    bool isRecording = false;
    double transportPosition = 0.0;      // Beats
    double bpm = 120.0;
    int timeSignatureNum = 4;
    int timeSignatureDenom = 4;

    // Musical context
    juce::String key = "C";
    juce::String scale = "Major";
    int octave = 4;

    // Bio state
    float coherence = 0.5f;
    float heartRate = 70.0f;
    float hrv = 50.0f;
    juce::String flowState = "Neutral";

    // User state
    juce::String userId;
    juce::String sessionId;
    float expertiseLevel = 0.5f;         // 0=beginner, 1=expert

    // Audio state
    float masterLevel = 0.0f;            // dB
    float peakLevel = 0.0f;
    bool audioEngineRunning = false;

    // Sync state
    bool abletonLinkEnabled = false;
    int linkPeers = 0;
    bool midiClockSending = false;
    bool midiClockReceiving = false;

    // Visual state
    bool videoOutputEnabled = false;
    bool laserOutputEnabled = false;
    bool dmxOutputEnabled = false;
    bool streamingEnabled = false;

    // Collaboration
    bool collaborationEnabled = false;
    int collaboratorCount = 0;
};

//==============================================================================
/**
    Event types for the global event bus
*/
enum class GlobalEventType
{
    // Transport
    TransportPlay,
    TransportStop,
    TransportPause,
    TransportSeek,
    TempoChange,
    TimeSignatureChange,

    // Musical
    KeyChange,
    ScaleChange,
    ChordChange,

    // Bio
    CoherenceUpdate,
    HeartRateUpdate,
    FlowStateChange,

    // Audio
    AudioLevelUpdate,
    ClipTriggered,
    TrackArmed,
    TrackMuted,
    TrackSoloed,

    // MIDI
    MIDINoteOn,
    MIDINoteOff,
    MIDIControlChange,

    // AI
    AISuggestionGenerated,
    AIActionAccepted,
    AIActionDismissed,

    // Visual
    BeatPulse,
    VideoFrameReady,
    LaserPatternChange,
    LightingCueTriggered,

    // Collaboration
    CollaboratorJoined,
    CollaboratorLeft,
    RemoteAction,

    // System
    SubsystemStarted,
    SubsystemStopped,
    SubsystemError,
    PresetLoaded,
    ProjectLoaded,
    ProjectSaved
};

struct GlobalEvent
{
    GlobalEventType type;
    juce::var data;
    juce::Time timestamp;
    juce::String source;

    GlobalEvent(GlobalEventType t = GlobalEventType::TransportStop)
        : type(t), timestamp(juce::Time::getCurrentTime()) {}
};

//==============================================================================
/**
    MASTER INTEGRATION BRIDGE
    The central hub connecting all Echoelmusic systems
*/
class EchoelMasterBridge
{
public:
    //--------------------------------------------------------------------------
    static EchoelMasterBridge& getInstance()
    {
        static EchoelMasterBridge instance;
        return instance;
    }

    //==========================================================================
    // INITIALIZATION
    //==========================================================================

    void initialize()
    {
        std::lock_guard<std::mutex> lock(bridgeMutex);

        if (initialized)
            return;

        // Generate session ID
        sessionState.sessionId = juce::Uuid().toString();
        sessionState.userId = juce::SystemStats::getComputerName();

        // Initialize subsystems in order
        initializeCoreSubsystems();
        initializeAudioSubsystems();
        initializeAISubsystems();
        initializeVisualSubsystems();
        initializeHardwareSubsystems();
        initializeNetworkSubsystems();

        // Start master update thread
        updateRunning = true;
        updateThread = std::thread(&EchoelMasterBridge::masterUpdateLoop, this);

        initialized = true;
        postEvent(GlobalEventType::SubsystemStarted, juce::var("EchoelMasterBridge"));
    }

    void shutdown()
    {
        updateRunning = false;

        if (updateThread.joinable())
            updateThread.join();

        // Shutdown in reverse order
        shutdownNetworkSubsystems();
        shutdownHardwareSubsystems();
        shutdownVisualSubsystems();
        shutdownAISubsystems();
        shutdownAudioSubsystems();
        shutdownCoreSubsystems();

        initialized = false;
    }

    bool isInitialized() const { return initialized; }

    //==========================================================================
    // GLOBAL STATE
    //==========================================================================

    GlobalSessionState getSessionState() const
    {
        std::lock_guard<std::mutex> lock(bridgeMutex);
        return sessionState;
    }

    void updateTransport(bool playing, bool recording, double position)
    {
        std::lock_guard<std::mutex> lock(bridgeMutex);

        bool wasPlaying = sessionState.isPlaying;
        sessionState.isPlaying = playing;
        sessionState.isRecording = recording;
        sessionState.transportPosition = position;

        // Propagate to all systems
        propagateTransportState();

        if (playing && !wasPlaying)
            postEvent(GlobalEventType::TransportPlay, juce::var(position));
        else if (!playing && wasPlaying)
            postEvent(GlobalEventType::TransportStop, juce::var(position));
    }

    void updateTempo(double bpm)
    {
        std::lock_guard<std::mutex> lock(bridgeMutex);
        sessionState.bpm = bpm;
        propagateTempoState();
        postEvent(GlobalEventType::TempoChange, juce::var(bpm));
    }

    void updateMusicalContext(const juce::String& key, const juce::String& scale)
    {
        std::lock_guard<std::mutex> lock(bridgeMutex);
        sessionState.key = key;
        sessionState.scale = scale;
        propagateMusicalContext();
        postEvent(GlobalEventType::KeyChange, juce::var(key + " " + scale));
    }

    void updateBioState(float coherence, float heartRate, float hrv)
    {
        std::lock_guard<std::mutex> lock(bridgeMutex);
        sessionState.coherence = coherence;
        sessionState.heartRate = heartRate;
        sessionState.hrv = hrv;
        sessionState.flowState = determineFlowState(coherence, hrv);
        propagateBioState();
        postEvent(GlobalEventType::CoherenceUpdate, juce::var(coherence));
    }

    void updateAudioLevel(float level, float peak)
    {
        std::lock_guard<std::mutex> lock(bridgeMutex);
        sessionState.masterLevel = level;
        sessionState.peakLevel = peak;
    }

    //==========================================================================
    // EVENT BUS
    //==========================================================================

    using EventCallback = std::function<void(const GlobalEvent&)>;

    void subscribeToEvent(GlobalEventType type, const juce::String& subscriberId,
                          EventCallback callback)
    {
        std::lock_guard<std::mutex> lock(eventMutex);
        eventSubscribers[type][subscriberId] = callback;
    }

    void unsubscribeFromEvent(GlobalEventType type, const juce::String& subscriberId)
    {
        std::lock_guard<std::mutex> lock(eventMutex);
        auto it = eventSubscribers.find(type);
        if (it != eventSubscribers.end())
            it->second.erase(subscriberId);
    }

    void postEvent(GlobalEventType type, const juce::var& data = juce::var(),
                   const juce::String& source = "")
    {
        GlobalEvent event;
        event.type = type;
        event.data = data;
        event.source = source.isEmpty() ? "EchoelMasterBridge" : source;
        event.timestamp = juce::Time::getCurrentTime();

        {
            std::lock_guard<std::mutex> lock(eventMutex);
            eventQueue.push(event);
        }
    }

    //==========================================================================
    // SUBSYSTEM ACCESS
    //==========================================================================

    // Core
    RalphWiggum::RalphWiggumAPI& getRalphWiggumAPI()
    {
        return RalphWiggum::RalphWiggumAPI::getInstance();
    }

    Core::PresetManager& getPresetManager()
    {
        return Core::PresetManager::getInstance();
    }

    // AI
    AI::AICompositionEngine& getAIComposition()
    {
        return AI::AICompositionEngine::getInstance();
    }

    // Plugin
    Plugin::PluginHostSystem& getPluginHost()
    {
        return Plugin::PluginHostSystem::getInstance();
    }

    // Multimedia
    Multimedia::QuantumMediaBridge& getMediaBridge()
    {
        return Multimedia::QuantumMediaBridge::getInstance();
    }

    // Visual
    Visual::LaserScanEngine& getLaserScan()
    {
        return Visual::LaserScanEngine::getInstance();
    }

    // Video
    Video::VideoEditEngine& getVideoEdit()
    {
        return Video::VideoEditEngine::getInstance();
    }

    //==========================================================================
    // QUICK ACTIONS
    //==========================================================================

    // Transport
    void play() { updateTransport(true, sessionState.isRecording, sessionState.transportPosition); }
    void stop() { updateTransport(false, false, 0.0); }
    void pause() { updateTransport(false, sessionState.isRecording, sessionState.transportPosition); }
    void record() { updateTransport(true, true, sessionState.transportPosition); }

    // Generate AI content
    void generateMelody(const juce::String& style = "")
    {
        auto& ai = getAIComposition();
        auto request = AI::CompositionRequest();
        request.type = AI::CompositionRequest::Type::Melody;
        request.contextKey = sessionState.key;
        request.contextScale = sessionState.scale;
        request.contextTempo = static_cast<float>(sessionState.bpm);
        request.coherenceLevel = sessionState.coherence;
        ai.submitRequest(request);
    }

    void generateChords(const juce::String& style = "")
    {
        auto& ai = getAIComposition();
        auto request = AI::CompositionRequest();
        request.type = AI::CompositionRequest::Type::ChordProgression;
        request.contextKey = sessionState.key;
        request.contextScale = sessionState.scale;
        request.contextTempo = static_cast<float>(sessionState.bpm);
        request.coherenceLevel = sessionState.coherence;
        ai.submitRequest(request);
    }

    // Trigger visual effects
    void triggerBeatPulse()
    {
        auto& media = getMediaBridge();
        // Trigger synchronized visual pulse across all outputs
        postEvent(GlobalEventType::BeatPulse, juce::var(sessionState.bpm));
    }

    // Save/Load
    void saveSession(const juce::File& file)
    {
        // Collect state from all subsystems
        juce::var sessionData;

        // Core state
        sessionData["transport"]["bpm"] = sessionState.bpm;
        sessionData["transport"]["key"] = sessionState.key.toStdString();
        sessionData["transport"]["scale"] = sessionState.scale.toStdString();

        // AI state
        // Video state
        // Plugin state
        // etc.

        // Write to file
        file.replaceWithText(juce::JSON::toString(sessionData, true));
        postEvent(GlobalEventType::ProjectSaved, juce::var(file.getFullPathName().toStdString()));
    }

    void loadSession(const juce::File& file)
    {
        juce::var sessionData = juce::JSON::parse(file);
        if (!sessionData.isObject())
            return;

        // Restore state to all subsystems
        auto transport = sessionData["transport"];
        if (transport.isObject())
        {
            updateTempo(transport.getProperty("bpm", 120.0));
            updateMusicalContext(
                transport.getProperty("key", "C").toString(),
                transport.getProperty("scale", "Major").toString()
            );
        }

        postEvent(GlobalEventType::ProjectLoaded, juce::var(file.getFullPathName().toStdString()));
    }

    //==========================================================================
    // SUBSYSTEM STATUS
    //==========================================================================

    std::vector<SubsystemStatus> getSubsystemStatuses() const
    {
        std::lock_guard<std::mutex> lock(bridgeMutex);
        std::vector<SubsystemStatus> result;

        for (const auto& pair : subsystemStatuses)
            result.push_back(pair.second);

        return result;
    }

    SubsystemStatus getSubsystemStatus(const juce::String& name) const
    {
        std::lock_guard<std::mutex> lock(bridgeMutex);

        auto it = subsystemStatuses.find(name);
        if (it != subsystemStatuses.end())
            return it->second;

        return SubsystemStatus();
    }

    //==========================================================================
    // SYNC CONTROL
    //==========================================================================

    void enableAbletonLink(bool enable)
    {
        std::lock_guard<std::mutex> lock(bridgeMutex);
        sessionState.abletonLinkEnabled = enable;
        // Configure Link...
    }

    void enableMIDIClock(bool send, bool receive)
    {
        std::lock_guard<std::mutex> lock(bridgeMutex);
        sessionState.midiClockSending = send;
        sessionState.midiClockReceiving = receive;
        // Configure MIDI clock...
    }

    //==========================================================================
    // OUTPUT CONTROL
    //==========================================================================

    void enableVideoOutput(bool enable)
    {
        std::lock_guard<std::mutex> lock(bridgeMutex);
        sessionState.videoOutputEnabled = enable;
    }

    void enableLaserOutput(bool enable)
    {
        std::lock_guard<std::mutex> lock(bridgeMutex);
        sessionState.laserOutputEnabled = enable;
        // Safety check before enabling lasers
    }

    void enableDMXOutput(bool enable)
    {
        std::lock_guard<std::mutex> lock(bridgeMutex);
        sessionState.dmxOutputEnabled = enable;
    }

    void enableStreaming(bool enable)
    {
        std::lock_guard<std::mutex> lock(bridgeMutex);
        sessionState.streamingEnabled = enable;
    }

    //==========================================================================
    // COLLABORATION
    //==========================================================================

    void enableCollaboration(bool enable)
    {
        std::lock_guard<std::mutex> lock(bridgeMutex);
        sessionState.collaborationEnabled = enable;

        if (enable)
        {
            auto& media = getMediaBridge();
            // Start collaboration server...
        }
    }

private:
    EchoelMasterBridge() = default;
    ~EchoelMasterBridge() { shutdown(); }

    EchoelMasterBridge(const EchoelMasterBridge&) = delete;
    EchoelMasterBridge& operator=(const EchoelMasterBridge&) = delete;

    //--------------------------------------------------------------------------
    void initializeCoreSubsystems()
    {
        updateSubsystemStatus("RalphWiggumAPI", true, true);
        updateSubsystemStatus("PresetManager", true, true);
        updateSubsystemStatus("ProgressiveDisclosure", true, true);
    }

    void initializeAudioSubsystems()
    {
        Plugin::PluginHostSystem::getInstance().initialize();
        updateSubsystemStatus("PluginHost", true, true);
    }

    void initializeAISubsystems()
    {
        AI::AICompositionEngine::getInstance().initialize();
        updateSubsystemStatus("AIComposition", true, true);
    }

    void initializeVisualSubsystems()
    {
        Visual::LaserScanEngine::getInstance().initialize();
        Video::VideoEditEngine::getInstance().initialize();
        updateSubsystemStatus("LaserScan", true, true);
        updateSubsystemStatus("VideoEdit", true, true);
    }

    void initializeHardwareSubsystems()
    {
        updateSubsystemStatus("Hardware", true, true);
    }

    void initializeNetworkSubsystems()
    {
        Multimedia::QuantumMediaBridge::getInstance().initialize();
        updateSubsystemStatus("MediaBridge", true, true);
    }

    void shutdownCoreSubsystems()
    {
        Core::PresetManager::getInstance().shutdown();
    }

    void shutdownAudioSubsystems()
    {
        Plugin::PluginHostSystem::getInstance().shutdown();
    }

    void shutdownAISubsystems()
    {
        AI::AICompositionEngine::getInstance().shutdown();
    }

    void shutdownVisualSubsystems()
    {
        Visual::LaserScanEngine::getInstance().shutdown();
        Video::VideoEditEngine::getInstance().shutdown();
    }

    void shutdownHardwareSubsystems() {}

    void shutdownNetworkSubsystems()
    {
        Multimedia::QuantumMediaBridge::getInstance().shutdown();
    }

    //--------------------------------------------------------------------------
    void propagateTransportState()
    {
        // Update all systems with new transport state
        auto& videoEdit = getVideoEdit();
        if (sessionState.isPlaying)
            videoEdit.play();
        else
            videoEdit.pause();
    }

    void propagateTempoState()
    {
        // Update tempo across all systems
        auto& ai = getAIComposition();
        // ai.setTempo(sessionState.bpm);
    }

    void propagateMusicalContext()
    {
        // Update musical context across all systems
        auto& ai = getAIComposition();
        // ai.setKey(sessionState.key, sessionState.scale);
    }

    void propagateBioState()
    {
        // Update bio state across all visual/audio systems
        auto& pluginHost = getPluginHost();
        pluginHost.updateBioState(sessionState.coherence,
                                   sessionState.heartRate,
                                   sessionState.hrv);

        auto& laserScan = getLaserScan();
        laserScan.updateBioState(sessionState.coherence, sessionState.hrv);

        auto& videoEdit = getVideoEdit();
        videoEdit.updateBioState(sessionState.coherence, sessionState.hrv);
    }

    juce::String determineFlowState(float coherence, float hrv)
    {
        if (coherence > 0.8f && hrv > 60.0f)
            return "Deep Flow";
        else if (coherence > 0.6f)
            return "Flow";
        else if (coherence > 0.4f)
            return "Engaged";
        else if (coherence > 0.2f)
            return "Neutral";
        else
            return "Distracted";
    }

    //--------------------------------------------------------------------------
    void updateSubsystemStatus(const juce::String& name, bool initialized, bool running,
                               bool hasError = false, const juce::String& error = "")
    {
        SubsystemStatus status;
        status.name = name;
        status.initialized = initialized;
        status.running = running;
        status.hasError = hasError;
        status.errorMessage = error;
        status.lastUpdate = juce::Time::getCurrentTime();

        subsystemStatuses[name] = status;
    }

    //--------------------------------------------------------------------------
    void masterUpdateLoop()
    {
        while (updateRunning)
        {
            // Process event queue
            processEventQueue();

            // Update subsystem statuses
            updateAllSubsystemStatuses();

            // Sync with external systems (Link, MIDI clock)
            syncExternalSystems();

            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
    }

    void processEventQueue()
    {
        std::vector<GlobalEvent> eventsToProcess;

        {
            std::lock_guard<std::mutex> lock(eventMutex);
            while (!eventQueue.empty())
            {
                eventsToProcess.push_back(eventQueue.front());
                eventQueue.pop();
            }
        }

        for (const auto& event : eventsToProcess)
        {
            std::lock_guard<std::mutex> lock(eventMutex);
            auto it = eventSubscribers.find(event.type);
            if (it != eventSubscribers.end())
            {
                for (const auto& sub : it->second)
                {
                    try
                    {
                        sub.second(event);
                    }
                    catch (...) {}
                }
            }
        }
    }

    void updateAllSubsystemStatuses()
    {
        // Update CPU/memory usage for each subsystem
        // This would integrate with system monitoring
    }

    void syncExternalSystems()
    {
        // Sync with Ableton Link
        if (sessionState.abletonLinkEnabled)
        {
            // Get Link tempo and phase
        }

        // Send/receive MIDI clock
        if (sessionState.midiClockSending || sessionState.midiClockReceiving)
        {
            // Handle MIDI clock
        }
    }

    //--------------------------------------------------------------------------
    mutable std::mutex bridgeMutex;
    mutable std::mutex eventMutex;

    bool initialized = false;
    std::atomic<bool> updateRunning{false};
    std::thread updateThread;

    GlobalSessionState sessionState;
    std::map<juce::String, SubsystemStatus> subsystemStatuses;

    std::queue<GlobalEvent> eventQueue;
    std::map<GlobalEventType, std::map<juce::String, EventCallback>> eventSubscribers;
};

} // namespace Echoel
