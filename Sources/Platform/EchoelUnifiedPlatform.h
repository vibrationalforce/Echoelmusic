#pragma once

#include <JuceHeader.h>
#include <memory>
#include <functional>
#include <vector>
#include <map>
#include <string>

// Core Audio/MIDI
#include "../Audio/AudioEngine.h"
#include "../Audio/SessionManager.h"
#include "../Audio/AudioRoutingManager.h"
#include "../MIDI/QuantizationEngine.h"

// Hardware Integration
#include "../Hardware/HardwareSyncManager.h"
#include "../Hardware/MIDIHardwareManager.h"
#include "../Hardware/BluetoothAudioManager.h"
#include "../Hardware/OSCManager.h"
#include "../Hardware/AbletonLink.h"

// Biofeedback / Wearables
#include "../Bio/BiofeedbackEngine.h"

// Video & Media
#include "../Video/VideoSyncEngine.h"
#include "../Video/VideoWeaver.h"

// Network & Collaboration
#include "../Network/LiveCollaboration.h"
#include "../Network/RealtimeStreaming.h"
#include "../Remote/EchoelCloudManager.h"

// Vocals & Processing
#include "../Vocals/VocalSuite.h"

// Content Creation
#include "../Content/ContentCreationSuite.h"

// Platform Services
#include "AgencyManager.h"
#include "CreatorManager.h"

/**
 * EchoelUnifiedPlatform - Master Integration Layer
 *
 * Connects all Echoelmusic subsystems into a cohesive ecosystem:
 *
 * HARDWARE LAYER:
 * - Oura Ring, Apple Watch, Garmin (HRV/Biometrics)
 * - Camera Sensors (HRV4Training style)
 * - MIDI Controllers, DJ Equipment
 * - Modular Synths, Hardware Synths
 * - Ableton Link, OSC
 *
 * AUDIO LAYER:
 * - Professional Audio Engine
 * - VocalSuite (Autotune → Harmonizer → VoiceCloner → Vocoder)
 * - Real-time DSP Processing
 * - Podcast/Streaming Audio
 *
 * VIDEO LAYER:
 * - Camera Access & Recording
 * - Video Editing Engine
 * - Audio-Video Sync
 * - Multi-format Export
 *
 * CONTENT LAYER:
 * - Blog/Article Creation
 * - Recipe System (Essential Oils, Food, Wellness)
 * - Album Cover / Visual Design
 * - Songwriting Tools
 *
 * NETWORK LAYER:
 * - Live Collaboration (WebRTC)
 * - Multi-platform Streaming
 * - Cloud Storage & Sync
 * - Social Media Distribution
 *
 * AI LAYER:
 * - Quantum Intelligence Processing
 * - Adaptive Learning
 * - Content Generation
 * - Smart Automation
 *
 * Design Philosophy: "Alles möglichst einfach - Super Quantum Intelligence mit voller Kontrolle"
 * (Everything as simple as possible - Super Quantum Intelligence with full control)
 */

namespace Echoelmusic {
namespace Platform {

//==============================================================================
// Wearable Device Types
//==============================================================================

enum class WearableDevice
{
    None,
    OuraRing,
    AppleWatch,
    GarminWatch,
    FitbitDevice,
    WhoopStrap,
    PolarHRM,
    CameraHRV,         // Phone camera based HRV (like HRV4Training)
    ExternalHRVSensor
};

enum class BiometricType
{
    HeartRate,
    HRV,                // Heart Rate Variability
    RespirationRate,
    SkinTemperature,
    BloodOxygen,
    StressLevel,
    SleepStage,
    ActivityLevel,
    Readiness
};

//==============================================================================
// Platform States
//==============================================================================

enum class PlatformMode
{
    Production,         // Full DAW mode
    LivePerformance,   // Low-latency live mode
    ContentCreation,   // Blog/Recipe/Design focus
    Collaboration,     // Live collab session
    Streaming,         // Multi-platform streaming
    Wellness,          // Biofeedback/meditation focus
    Practice           // Learning/practice mode
};

enum class StreamingPlatform
{
    YouTube,
    Twitch,
    Instagram,
    TikTok,
    Facebook,
    LinkedIn,
    Twitter,
    Spotify,
    SoundCloud,
    Custom
};

//==============================================================================
// Unified Event System
//==============================================================================

struct PlatformEvent
{
    enum class Type
    {
        // Hardware Events
        WearableConnected,
        WearableDisconnected,
        BiometricUpdate,
        MIDIDeviceConnected,
        ControlSurfaceUpdate,

        // Audio Events
        AudioEngineStarted,
        AudioEngineStopped,
        TransportStateChanged,
        MixdownComplete,

        // Video Events
        CameraConnected,
        RecordingStarted,
        RecordingStopped,
        VideoExportComplete,

        // Network Events
        CollaboratorJoined,
        CollaboratorLeft,
        StreamStarted,
        StreamEnded,
        CloudSyncComplete,

        // Content Events
        ContentPublished,
        ContentSaved,
        TemplateApplied,

        // AI Events
        AIAnalysisComplete,
        AISuggestionReady,
        AdaptiveLearningUpdate
    };

    Type type;
    std::string source;
    std::string message;
    std::map<std::string, std::string> data;
    juce::Time timestamp;
};

using PlatformEventCallback = std::function<void(const PlatformEvent&)>;

//==============================================================================
// Biometric Data Structure
//==============================================================================

struct BiometricReading
{
    WearableDevice device;
    BiometricType type;
    float value;
    float quality;           // 0-1 signal quality
    juce::Time timestamp;
    std::string unit;
};

struct WellnessState
{
    float heartRate = 0.0f;          // BPM
    float hrv = 0.0f;                // ms (RMSSD)
    float stressLevel = 0.0f;        // 0-1
    float readinessScore = 0.0f;     // 0-100
    float respirationRate = 0.0f;    // breaths/min
    float bloodOxygen = 0.0f;        // %
    float skinTemp = 0.0f;           // Celsius
    std::string sleepStage;          // Awake, Light, Deep, REM
    juce::Time lastUpdate;
};

//==============================================================================
// Social Media Export Settings
//==============================================================================

struct SocialMediaExport
{
    StreamingPlatform platform;
    std::string title;
    std::string description;
    std::vector<std::string> hashtags;
    std::string thumbnailPath;
    bool schedulePost = false;
    juce::Time scheduledTime;

    // Platform-specific settings
    struct PlatformSettings
    {
        int videoWidth = 1080;
        int videoHeight = 1920;
        int audioBitrate = 320;     // kbps
        int videoBitrate = 6000;    // kbps
        std::string aspectRatio = "9:16";
        int maxDurationSeconds = 60;
    } settings;
};

//==============================================================================
// Main Platform Class
//==============================================================================

class EchoelUnifiedPlatform
{
public:
    //==========================================================================
    // Singleton Access
    //==========================================================================

    static EchoelUnifiedPlatform& getInstance()
    {
        static EchoelUnifiedPlatform instance;
        return instance;
    }

    //==========================================================================
    // Initialization
    //==========================================================================

    void initialize()
    {
        if (isInitialized) return;

        // Initialize all subsystems
        initializeAudioEngine();
        initializeHardwareLayer();
        initializeBiofeedback();
        initializeVideoEngine();
        initializeNetworking();
        initializeContentSuite();
        initializeAI();

        isInitialized = true;
        currentMode = PlatformMode::Production;

        sendEvent(PlatformEvent::Type::AudioEngineStarted, "Platform", "Unified platform initialized");
    }

    void shutdown()
    {
        // Graceful shutdown of all systems
        stopAllStreams();
        disconnectAllWearables();
        stopAudioEngine();

        isInitialized = false;
    }

    //==========================================================================
    // Mode Management
    //==========================================================================

    void setMode(PlatformMode mode)
    {
        currentMode = mode;
        applyModeSettings(mode);
    }

    PlatformMode getMode() const { return currentMode; }

    void applyModeSettings(PlatformMode mode)
    {
        switch (mode)
        {
            case PlatformMode::Production:
                setLatencyMode(LatencyMode::Balanced);
                enableFullDSP(true);
                break;

            case PlatformMode::LivePerformance:
                setLatencyMode(LatencyMode::UltraLow);
                enableFullDSP(false);  // Disable heavy processing
                break;

            case PlatformMode::ContentCreation:
                setLatencyMode(LatencyMode::Relaxed);
                enableContentTools(true);
                break;

            case PlatformMode::Collaboration:
                setLatencyMode(LatencyMode::Low);
                enableCollaboration(true);
                break;

            case PlatformMode::Streaming:
                setLatencyMode(LatencyMode::Balanced);
                prepareForStreaming();
                break;

            case PlatformMode::Wellness:
                setLatencyMode(LatencyMode::Relaxed);
                enableBiofeedbackIntegration(true);
                break;

            case PlatformMode::Practice:
                setLatencyMode(LatencyMode::Low);
                enableLearningMode(true);
                break;
        }
    }

    //==========================================================================
    // Wearable & Biofeedback Integration
    //==========================================================================

    bool connectWearable(WearableDevice device)
    {
        switch (device)
        {
            case WearableDevice::OuraRing:
                return connectOuraRing();
            case WearableDevice::AppleWatch:
                return connectAppleWatch();
            case WearableDevice::GarminWatch:
                return connectGarmin();
            case WearableDevice::CameraHRV:
                return startCameraHRV();
            default:
                return false;
        }
    }

    void disconnectAllWearables()
    {
        connectedWearables.clear();
        sendEvent(PlatformEvent::Type::WearableDisconnected, "Wearables", "All wearables disconnected");
    }

    WellnessState getWellnessState() const { return wellnessState; }

    void setBiofeedbackCallback(std::function<void(const BiometricReading&)> callback)
    {
        biofeedbackCallback = callback;
    }

    // Biofeedback-driven music parameters
    void enableBiofeedbackModulation(bool enable)
    {
        biofeedbackModulationEnabled = enable;
    }

    void mapBiometricToParameter(BiometricType biometric, const std::string& parameterPath)
    {
        biometricMappings[biometric] = parameterPath;
    }

    //==========================================================================
    // Audio Integration
    //==========================================================================

    void startAudioEngine() { /* Delegate to AudioEngine */ }
    void stopAudioEngine() { /* Delegate to AudioEngine */ }

    void setLatencyMode(LatencyMode mode)
    {
        latencyMode = mode;
        // Configure buffer sizes based on mode
        switch (mode)
        {
            case LatencyMode::UltraLow:  setBufferSize(64); break;
            case LatencyMode::Low:       setBufferSize(128); break;
            case LatencyMode::Balanced:  setBufferSize(256); break;
            case LatencyMode::Relaxed:   setBufferSize(512); break;
        }
    }

    // VocalSuite quick access
    Vocals::VocalSuite& getVocalSuite() { return vocalSuite; }

    void setVoiceCharacter(Vocals::VoiceCharacter character)
    {
        vocalSuite.setVoiceCharacter(character);
    }

    //==========================================================================
    // Video & Camera Integration
    //==========================================================================

    void enableCamera(int deviceIndex = 0)
    {
        cameraEnabled = true;
        currentCameraDevice = deviceIndex;
    }

    void disableCamera()
    {
        cameraEnabled = false;
    }

    void startVideoRecording(const std::string& outputPath)
    {
        if (!cameraEnabled) return;
        videoRecording = true;
        videoOutputPath = outputPath;
        sendEvent(PlatformEvent::Type::RecordingStarted, "Video", "Recording to: " + outputPath);
    }

    void stopVideoRecording()
    {
        videoRecording = false;
        sendEvent(PlatformEvent::Type::RecordingStopped, "Video", "Recording stopped");
    }

    //==========================================================================
    // Content Creation
    //==========================================================================

    Content::ContentCreationSuite& getContentSuite() { return contentSuite; }

    void createQuickContent(Content::ContentType type, const std::string& title)
    {
        switch (type)
        {
            case Content::ContentType::BlogPost:
                contentSuite.createBlogPost(title, "");
                break;
            case Content::ContentType::Recipe:
                contentSuite.createRecipe(title, Content::RecipeCategory::Wellness_Meditation);
                break;
            case Content::ContentType::Lyrics:
                contentSuite.createSong(title, "C", 120);
                break;
            default:
                break;
        }
    }

    //==========================================================================
    // Live Collaboration
    //==========================================================================

    void startCollaborationSession(const std::string& sessionName)
    {
        collaborationActive = true;
        currentSessionName = sessionName;
        sendEvent(PlatformEvent::Type::CollaboratorJoined, "Collab", "Session started: " + sessionName);
    }

    void joinCollaborationSession(const std::string& sessionCode)
    {
        collaborationActive = true;
        // Connect via WebRTC
    }

    void leaveCollaborationSession()
    {
        collaborationActive = false;
        sendEvent(PlatformEvent::Type::CollaboratorLeft, "Collab", "Left session");
    }

    void inviteCollaborator(const std::string& email)
    {
        pendingInvites.push_back(email);
    }

    //==========================================================================
    // Multi-Platform Streaming
    //==========================================================================

    void addStreamingDestination(StreamingPlatform platform, const std::string& streamKey)
    {
        streamingDestinations[platform] = streamKey;
    }

    void removeStreamingDestination(StreamingPlatform platform)
    {
        streamingDestinations.erase(platform);
    }

    void startStreaming()
    {
        if (streamingDestinations.empty()) return;

        isStreaming = true;
        sendEvent(PlatformEvent::Type::StreamStarted, "Streaming",
                  "Streaming to " + std::to_string(streamingDestinations.size()) + " platforms");
    }

    void stopAllStreams()
    {
        isStreaming = false;
        sendEvent(PlatformEvent::Type::StreamEnded, "Streaming", "All streams stopped");
    }

    bool isCurrentlyStreaming() const { return isStreaming; }

    //==========================================================================
    // Social Media Export
    //==========================================================================

    void exportForSocialMedia(const SocialMediaExport& settings, const std::string& mediaPath)
    {
        auto dims = Content::VisualDesigner::getDimensions(
            getPlatformFormat(settings.platform));

        // Configure export based on platform
        Content::ContentCreationSuite::ExportSettings exportSettings;
        exportSettings.visualFormat = getPlatformFormat(settings.platform);
        exportSettings.videoQuality = settings.settings.videoBitrate;
        exportSettings.audioQuality = settings.settings.audioBitrate;

        contentSuite.exportContent(Content::ContentType::Video, mediaPath, exportSettings);

        sendEvent(PlatformEvent::Type::ContentPublished, "Social",
                  "Exported for " + getPlatformName(settings.platform));
    }

    void schedulePost(const SocialMediaExport& settings)
    {
        scheduledPosts.push_back(settings);
    }

    //==========================================================================
    // Cloud & Sync
    //==========================================================================

    void syncToCloud()
    {
        // Sync current session to cloud
        sendEvent(PlatformEvent::Type::CloudSyncComplete, "Cloud", "Session synced");
    }

    void enableAutoSync(bool enable)
    {
        autoSyncEnabled = enable;
    }

    //==========================================================================
    // Event System
    //==========================================================================

    void addEventListener(PlatformEventCallback callback)
    {
        eventListeners.push_back(callback);
    }

    void sendEvent(PlatformEvent::Type type, const std::string& source, const std::string& message)
    {
        PlatformEvent event;
        event.type = type;
        event.source = source;
        event.message = message;
        event.timestamp = juce::Time::getCurrentTime();

        for (auto& listener : eventListeners)
            listener(event);
    }

    //==========================================================================
    // Quick Actions (One-Touch Operations)
    //==========================================================================

    void quickStartPodcast()
    {
        setMode(PlatformMode::ContentCreation);
        enableCamera(0);
        startVideoRecording("podcast_" + getTimestamp() + ".mp4");
    }

    void quickStartLiveStream(StreamingPlatform platform)
    {
        setMode(PlatformMode::Streaming);
        enableCamera(0);
        startStreaming();
    }

    void quickStartMeditation(int durationMinutes)
    {
        setMode(PlatformMode::Wellness);
        enableBiofeedbackModulation(true);
        // Load meditation soundscape
        setVoiceCharacter(Vocals::VoiceCharacter::Sound_Bath);
    }

    void quickStartCollab()
    {
        setMode(PlatformMode::Collaboration);
        startCollaborationSession("QuickCollab_" + getTimestamp());
    }

    //==========================================================================
    // System Status
    //==========================================================================

    struct SystemStatus
    {
        bool audioEngineRunning = false;
        bool videoEnabled = false;
        bool isStreaming = false;
        bool isCollaborating = false;
        int connectedWearables = 0;
        int connectedMIDI = 0;
        float cpuLoad = 0.0f;
        float memoryUsage = 0.0f;
        PlatformMode currentMode;
    };

    SystemStatus getSystemStatus() const
    {
        SystemStatus status;
        status.audioEngineRunning = true;  // Get from AudioEngine
        status.videoEnabled = cameraEnabled;
        status.isStreaming = isStreaming;
        status.isCollaborating = collaborationActive;
        status.connectedWearables = static_cast<int>(connectedWearables.size());
        status.currentMode = currentMode;
        return status;
    }

    //==========================================================================
    // AI/Quantum Intelligence Interface
    //==========================================================================

    void enableQuantumIntelligence(bool enable)
    {
        quantumIntelligenceEnabled = enable;
    }

    // AI-driven suggestions
    std::string suggestNextAction()
    {
        // Based on current context, biometrics, time of day, etc.
        if (wellnessState.stressLevel > 0.7f)
            return "Consider a brief meditation break";
        if (wellnessState.readinessScore > 80.0f)
            return "Great energy levels - ideal for creative work";
        return "Ready for your next task";
    }

    void enableAdaptiveLearning(bool enable)
    {
        adaptiveLearningEnabled = enable;
    }

private:
    //==========================================================================
    // Constructor (Private for Singleton)
    //==========================================================================

    EchoelUnifiedPlatform() = default;
    ~EchoelUnifiedPlatform() = default;

    // Prevent copying
    EchoelUnifiedPlatform(const EchoelUnifiedPlatform&) = delete;
    EchoelUnifiedPlatform& operator=(const EchoelUnifiedPlatform&) = delete;

    //==========================================================================
    // Initialization Helpers
    //==========================================================================

    void initializeAudioEngine() { /* Initialize audio subsystem */ }
    void initializeHardwareLayer() { /* Initialize hardware connections */ }
    void initializeBiofeedback() { /* Initialize biofeedback engine */ }
    void initializeVideoEngine() { /* Initialize video subsystem */ }
    void initializeNetworking() { /* Initialize network layer */ }
    void initializeContentSuite() { /* Initialize content creation tools */ }
    void initializeAI() { /* Initialize AI subsystems */ }

    //==========================================================================
    // Wearable Connection Helpers
    //==========================================================================

    bool connectOuraRing()
    {
        // Connect via Oura API/Bluetooth
        connectedWearables.insert(WearableDevice::OuraRing);
        sendEvent(PlatformEvent::Type::WearableConnected, "Oura", "Oura Ring connected");
        return true;
    }

    bool connectAppleWatch()
    {
        // Connect via HealthKit
        connectedWearables.insert(WearableDevice::AppleWatch);
        sendEvent(PlatformEvent::Type::WearableConnected, "Apple", "Apple Watch connected");
        return true;
    }

    bool connectGarmin()
    {
        // Connect via Garmin Connect API
        connectedWearables.insert(WearableDevice::GarminWatch);
        sendEvent(PlatformEvent::Type::WearableConnected, "Garmin", "Garmin connected");
        return true;
    }

    bool startCameraHRV()
    {
        // Use phone camera for PPG-based HRV measurement
        connectedWearables.insert(WearableDevice::CameraHRV);
        sendEvent(PlatformEvent::Type::WearableConnected, "Camera", "Camera HRV started");
        return true;
    }

    //==========================================================================
    // Mode Helpers
    //==========================================================================

    void enableFullDSP(bool enable) { fullDSPEnabled = enable; }
    void enableContentTools(bool enable) { contentToolsEnabled = enable; }
    void enableCollaboration(bool enable) { collaborationEnabled = enable; }
    void enableLearningMode(bool enable) { learningModeEnabled = enable; }
    void enableBiofeedbackIntegration(bool enable) { biofeedbackIntegrationEnabled = enable; }
    void prepareForStreaming() { /* Optimize settings for streaming */ }
    void setBufferSize(int size) { bufferSize = size; }

    //==========================================================================
    // Format Helpers
    //==========================================================================

    Content::VisualFormat getPlatformFormat(StreamingPlatform platform)
    {
        switch (platform)
        {
            case StreamingPlatform::Instagram:  return Content::VisualFormat::Instagram_Story;
            case StreamingPlatform::TikTok:     return Content::VisualFormat::TikTok_Video;
            case StreamingPlatform::YouTube:    return Content::VisualFormat::YouTube_Thumbnail;
            case StreamingPlatform::Twitter:    return Content::VisualFormat::Twitter_Post;
            case StreamingPlatform::LinkedIn:   return Content::VisualFormat::LinkedIn_Post;
            case StreamingPlatform::Facebook:   return Content::VisualFormat::Facebook_Post;
            default:                            return Content::VisualFormat::Instagram_Square;
        }
    }

    std::string getPlatformName(StreamingPlatform platform)
    {
        switch (platform)
        {
            case StreamingPlatform::YouTube:    return "YouTube";
            case StreamingPlatform::Twitch:     return "Twitch";
            case StreamingPlatform::Instagram:  return "Instagram";
            case StreamingPlatform::TikTok:     return "TikTok";
            case StreamingPlatform::Facebook:   return "Facebook";
            case StreamingPlatform::LinkedIn:   return "LinkedIn";
            case StreamingPlatform::Twitter:    return "Twitter/X";
            case StreamingPlatform::Spotify:    return "Spotify";
            case StreamingPlatform::SoundCloud: return "SoundCloud";
            default:                            return "Custom";
        }
    }

    std::string getTimestamp()
    {
        return juce::Time::getCurrentTime().formatted("%Y%m%d_%H%M%S").toStdString();
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    enum class LatencyMode { UltraLow, Low, Balanced, Relaxed };

    bool isInitialized = false;
    PlatformMode currentMode = PlatformMode::Production;
    LatencyMode latencyMode = LatencyMode::Balanced;

    // Subsystems
    Vocals::VocalSuite vocalSuite;
    Content::ContentCreationSuite contentSuite;

    // Hardware
    std::set<WearableDevice> connectedWearables;
    std::map<BiometricType, std::string> biometricMappings;
    bool biofeedbackModulationEnabled = false;
    std::function<void(const BiometricReading&)> biofeedbackCallback;
    WellnessState wellnessState;

    // Video
    bool cameraEnabled = false;
    bool videoRecording = false;
    int currentCameraDevice = 0;
    std::string videoOutputPath;

    // Collaboration
    bool collaborationActive = false;
    std::string currentSessionName;
    std::vector<std::string> pendingInvites;

    // Streaming
    bool isStreaming = false;
    std::map<StreamingPlatform, std::string> streamingDestinations;
    std::vector<SocialMediaExport> scheduledPosts;

    // Cloud
    bool autoSyncEnabled = true;

    // Settings
    bool fullDSPEnabled = true;
    bool contentToolsEnabled = true;
    bool collaborationEnabled = false;
    bool learningModeEnabled = false;
    bool biofeedbackIntegrationEnabled = false;
    int bufferSize = 256;

    // AI
    bool quantumIntelligenceEnabled = true;
    bool adaptiveLearningEnabled = true;

    // Events
    std::vector<PlatformEventCallback> eventListeners;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelUnifiedPlatform)
};

//==============================================================================
// Convenience Macros for Quick Access
//==============================================================================

#define EchoelPlatform EchoelUnifiedPlatform::getInstance()
#define EchoelVocals   EchoelUnifiedPlatform::getInstance().getVocalSuite()
#define EchoelContent  EchoelUnifiedPlatform::getInstance().getContentSuite()

} // namespace Platform
} // namespace Echoelmusic
