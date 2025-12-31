#pragma once

/**
 * UniversalCreativeIntelligence - The Master Integration System
 *
 * GENIUS WISE MODE: Super-intelligent fusion of ALL creative systems
 *
 * INTEGRATES WITH EXISTING ECHOELMUSIC SYSTEMS:
 * - Echoel::AdvancedLightController (DMX, Art-Net, Hue, WLED, ILDA)
 * - Echoelmusic::VisualIntegrationAPI (TouchDesigner, Resolume, Unity)
 * - VideoWeaver (Professional video editing & color grading)
 * - BioReactiveDSP (Bio-modulated audio processing)
 * - SuperLaserScan (Ultra-low latency laser control)
 *
 * INTEGRATED AI VIDEO MODELS (2025/2026):
 * - CogVideoX (Zhipu AI): 85% VBench, 10s@720p, complex prompt understanding
 * - Mochi 1 (Genmo): 10B params, AsymmDiT, fluid motion, Apache 2.0
 * - Wan2.1/2.2 (Alibaba): 14B/1.3B, T2V+I2V, Apache 2.0
 * - Lumina-Video-Next: DiT architecture, artistic quality
 * - AnimateDiff: Stable Diffusion animation, style flexibility
 * - Open-Sora-Plan: Community Sora alternative
 * - Stream-Video: Real-time low-latency generation
 *
 * PROFESSIONAL SOFTWARE BRIDGES:
 * - Adobe Premiere/After Effects (CEP/UXP Extensions)
 * - DaVinci Resolve (OpenFX/DCTL)
 * - Avid Media Composer (AAF/OMF)
 * - CapCut (Template Exchange)
 * - Final Cut Pro (Motion Templates)
 * - ComfyUI (Workflow API)
 *
 * BIO-AUDIO-VISUAL-LIGHT FUSION:
 * - Biofeedback → Video Effects → Audio Processing → Lighting → Projection
 * - Real-time gesture/mimics recognition
 * - Heart rate variability → Creative parameters
 * - Breathing → Animation timing
 * - Coherence → Color grading + harmonics
 *
 * ADAPTIVE DEVICE OPTIMIZATION:
 * - iPhone SE → iPhone 16 Pro Max
 * - M1 MacBook Air → M3 Ultra Mac Studio
 * - RTX 3050 → RTX 4090 / H100
 * - Automatic quality scaling for best results on ANY device
 */

#include <array>
#include <atomic>
#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <vector>
#include <map>
#include <chrono>

// Forward declarations for existing Echoelmusic systems
namespace Echoel {
    class AdvancedLightController;
    class ArtNetController;
    class ILDAController;
}

namespace Echoelmusic {
    class VisualIntegrationAPI;
}

class VideoWeaver;
class BioReactiveDSP;

namespace laser {
    class SuperLaserScan;
}

namespace uci {  // Universal Creative Intelligence

//==============================================================================
// Device Capability Detection
//==============================================================================

enum class DeviceTier : uint8_t
{
    Mobile_Entry,       // iPhone SE, budget Android (2-4GB RAM, no NPU)
    Mobile_Mid,         // iPhone 12/13, mid Android (4-6GB RAM)
    Mobile_Pro,         // iPhone 14/15/16 Pro (8GB+ RAM, Neural Engine)
    Desktop_Entry,      // M1/Intel i5, RTX 3050 (8GB VRAM)
    Desktop_Mid,        // M2 Pro, RTX 3080/4070 (12-16GB VRAM)
    Desktop_Pro,        // M3 Max, RTX 4090 (24GB+ VRAM)
    Server_Cloud,       // H100/A100, cloud instances (48GB+ VRAM)

    NumTiers
};

struct DeviceCapabilities
{
    DeviceTier tier = DeviceTier::Mobile_Mid;

    // Hardware specs
    uint32_t cpuCores = 4;
    uint64_t ramBytes = 4ULL * 1024 * 1024 * 1024;  // 4GB default
    uint64_t vramBytes = 0;                          // GPU memory
    bool hasNPU = false;                             // Neural Processing Unit
    bool hasGPU = true;
    bool hasMetal = false;                           // Apple Metal
    bool hasCUDA = false;                            // NVIDIA CUDA
    bool hasROCm = false;                            // AMD ROCm
    float gpuTFLOPS = 1.0f;                          // Compute performance

    // Network
    float bandwidthMbps = 50.0f;
    float latencyMs = 50.0f;
    bool hasCloudAccess = true;

    // Features
    bool canRunLocalLLM = false;
    bool canRunLocalVideoGen = false;
    bool canRun4K = false;
    bool canRunRealTime = true;

    // Detected optimal settings
    int maxVideoResolution = 720;
    int maxFPS = 30;
    int maxParallelStreams = 1;
    float qualityMultiplier = 1.0f;

    static DeviceCapabilities detect();
};

//==============================================================================
// AI Video Generation Models
//==============================================================================

enum class VideoModel : uint8_t
{
    // Open Source Models (Local + API)
    CogVideoX_2B,       // Zhipu AI - 2B params, 8GB VRAM
    CogVideoX_5B,       // Zhipu AI - 5B params, 16GB VRAM
    CogVideoX_1_5,      // Latest version with DDIM Inverse

    Mochi1_Preview,     // Genmo - 10B params, fluid motion
    Mochi1_HD,          // Genmo - 720p (coming 2025)

    Wan2_1_1B,          // Alibaba - 1.3B efficient
    Wan2_1_14B,         // Alibaba - 14B quality
    Wan2_2,             // Alibaba - Enhanced version

    AnimateDiff,        // SD animation, style flexible
    AnimateDiff_Lightning, // Fast 4-step version

    LuminaVideo,        // DiT architecture, artistic
    OpenSoraPlan,       // Community Sora alternative
    StreamVideo,        // Real-time generation

    // Commercial APIs (Cloud)
    Runway_Gen4,        // Runway ML
    Pika_2_0,           // Pika Labs
    Kling_1_6,          // Kuaishou
    Sora,               // OpenAI (when available)
    Veo3,               // Google DeepMind

    // Internal
    Echoelmusic_Native, // Our optimized engine

    NumModels
};

struct VideoModelInfo
{
    VideoModel model;
    std::string name;
    std::string provider;

    // Requirements
    uint64_t minVRAM;
    DeviceTier minTier;
    bool requiresAPI;
    bool isOpenSource;
    std::string license;

    // Capabilities
    int maxResolution;      // 480, 720, 1080, 4K
    int maxDurationSec;
    int maxFPS;
    float qualityScore;     // 0-100 (VBench-like)
    float motionScore;      // Motion quality
    float promptAdherence;  // Prompt following accuracy
    float speedScore;       // Generation speed

    // Costs
    float costPerSecond;    // $ for API models
    float localGenTimeSec;  // For local models

    static std::vector<VideoModelInfo> getAllModels();
    static VideoModelInfo getOptimalModel(const DeviceCapabilities& device,
                                          int targetResolution,
                                          float targetQuality);
};

//==============================================================================
// Biofeedback Integration
//==============================================================================

struct BioState
{
    // Heart & HRV
    float heartRate = 70.0f;           // BPM
    float hrv = 0.5f;                  // 0-1 normalized
    float coherence = 0.5f;            // HeartMath-style coherence
    float rmssd = 50.0f;               // HRV RMSSD in ms

    // Breathing
    float breathingRate = 14.0f;       // Breaths per minute
    float breathPhase = 0.0f;          // 0=exhale, 1=inhale
    float breathDepth = 0.5f;          // 0-1

    // Stress & Relaxation
    float stressIndex = 0.3f;          // 0-1
    float relaxationIndex = 0.7f;      // 0-1
    float flowState = 0.5f;            // 0-1 (optimal focus)

    // Gesture & Mimics
    float gestureIntensity = 0.0f;     // 0-1 movement intensity
    float gestureValence = 0.5f;       // 0=closed, 1=open
    float facialExpression = 0.5f;     // 0=negative, 1=positive
    float eyeOpenness = 1.0f;          // 0-1
    float mouthOpenness = 0.0f;        // 0-1
    float browPosition = 0.5f;         // 0=frown, 1=raised

    // Movement
    float bodyMovement = 0.0f;         // Overall body motion
    float handMovement = 0.0f;         // Hand gesture intensity
    float headMovement = 0.0f;         // Head motion

    // Derived Creative Parameters
    float creativeEnergy = 0.5f;       // Computed from all inputs
    float emotionalIntensity = 0.5f;
    float focusLevel = 0.5f;
    float expressiveness = 0.5f;

    // Timestamps
    uint64_t lastUpdateMs = 0;
    bool isValid = false;

    void computeDerivedParameters();
};

//==============================================================================
// Audio Analysis State
//==============================================================================

struct AudioState
{
    // Levels
    float peakLevel = 0.0f;
    float rmsLevel = 0.0f;
    float lufs = -23.0f;

    // Frequency bands
    float subBass = 0.0f;      // 20-60 Hz
    float bass = 0.0f;         // 60-250 Hz
    float lowMid = 0.0f;       // 250-500 Hz
    float mid = 0.0f;          // 500-2000 Hz
    float highMid = 0.0f;      // 2000-4000 Hz
    float presence = 0.0f;     // 4000-6000 Hz
    float brilliance = 0.0f;   // 6000-20000 Hz

    // Musical analysis
    float bpm = 120.0f;
    float beatPhase = 0.0f;         // 0-1 within beat
    float barPhase = 0.0f;          // 0-1 within bar
    bool beatDetected = false;
    bool downbeatDetected = false;

    // Harmonic analysis
    int rootNote = 0;               // MIDI note of root
    int chordType = 0;              // Major, minor, etc.
    float harmonicTension = 0.5f;   // Dissonance level
    float keyStrength = 0.8f;       // Confidence in key detection

    // Spectral features
    float spectralCentroid = 2000.0f;
    float spectralFlux = 0.0f;
    float spectralRolloff = 8000.0f;
    float zeroCrossingRate = 0.0f;

    // Mood/Energy
    float energy = 0.5f;
    float valence = 0.5f;           // Happy/sad
    float danceability = 0.5f;

    // Full spectrum for visualization
    std::array<float, 512> spectrum;
    std::array<float, 2048> waveform;

    uint64_t lastUpdateMs = 0;
    bool isValid = false;
};

//==============================================================================
// Visual State (Generated/Current)
//==============================================================================

struct VisualState
{
    // Color palette
    std::array<float, 3> dominantColor = {0.5f, 0.5f, 0.5f};  // RGB
    std::array<float, 3> accentColor1 = {0.8f, 0.2f, 0.2f};
    std::array<float, 3> accentColor2 = {0.2f, 0.2f, 0.8f};
    float colorTemperature = 6500.0f;  // Kelvin
    float saturation = 0.7f;
    float brightness = 0.5f;
    float contrast = 1.0f;

    // Motion
    float motionIntensity = 0.5f;
    float motionDirection = 0.0f;    // Radians
    float motionSpeed = 0.5f;
    float zoom = 0.0f;               // -1 to 1 (out/in)
    float rotation = 0.0f;           // Rotation speed

    // Effects
    float glowIntensity = 0.0f;
    float particleDensity = 0.0f;
    float distortionAmount = 0.0f;
    float blurAmount = 0.0f;
    float noiseAmount = 0.0f;
    float glitchAmount = 0.0f;

    // Scene
    int currentPattern = 0;
    int currentPreset = 0;
    float transitionProgress = 1.0f;

    uint64_t lastUpdateMs = 0;
};

//==============================================================================
// Lighting State (DMX/ILDA/Art-Net)
//==============================================================================

struct LightingState
{
    // Master
    float masterDimmer = 1.0f;
    float masterStrobe = 0.0f;

    // Color (for all fixtures)
    std::array<float, 3> globalColor = {1.0f, 1.0f, 1.0f};
    float colorTemperature = 5600.0f;

    // Movement (for moving heads)
    float pan = 0.5f;       // 0-1 (0-540°)
    float tilt = 0.5f;      // 0-1 (0-270°)
    float panSpeed = 0.5f;
    float tiltSpeed = 0.5f;

    // Gobo/Effects
    int goboWheel = 0;
    float goboRotation = 0.0f;
    int prismIndex = 0;
    float focus = 0.5f;
    float zoom = 0.5f;

    // Chase/Sequence
    int currentChase = 0;
    float chaseSpeed = 1.0f;
    int currentStep = 0;

    // Laser specific
    float laserIntensity = 0.0f;
    bool laserBlanking = true;

    // Fixture groups
    std::array<float, 16> groupDimmers;
    std::array<std::array<float, 3>, 16> groupColors;

    uint64_t lastUpdateMs = 0;
};

//==============================================================================
// Fusion Parameters (Mappings between all systems)
//==============================================================================

struct FusionMapping
{
    std::string sourcePath;      // e.g., "bio.hrv", "audio.bass"
    std::string targetPath;      // e.g., "visual.glowIntensity", "light.masterDimmer"

    float sourceMin = 0.0f;
    float sourceMax = 1.0f;
    float targetMin = 0.0f;
    float targetMax = 1.0f;

    float smoothing = 0.1f;      // 0=instant, 1=very smooth
    float response = 1.0f;       // Response curve (1=linear)
    float offset = 0.0f;
    float scale = 1.0f;

    bool enabled = true;
    bool inverted = false;

    float currentValue = 0.0f;

    float process(float input);
};

struct FusionPreset
{
    std::string name;
    std::string description;
    std::string category;        // "Meditation", "Performance", "Party", etc.

    std::vector<FusionMapping> mappings;

    // Preset-specific settings
    float globalIntensity = 1.0f;
    float bioInfluence = 1.0f;
    float audioInfluence = 1.0f;
    float gestureInfluence = 0.5f;

    static std::vector<FusionPreset> getBuiltInPresets();
};

//==============================================================================
// Video Generation Request
//==============================================================================

struct VideoGenerationRequest
{
    // Content
    std::string prompt;
    std::string negativePrompt;
    std::string stylePreset;         // "Cinematic", "Anime", "Realistic", etc.

    // Reference inputs
    std::vector<uint8_t> referenceImage;  // Optional start frame
    std::vector<uint8_t> referenceVideo;  // Optional style reference
    std::vector<uint8_t> audioTrack;      // Optional audio to sync

    // Technical specs
    int width = 1280;
    int height = 720;
    int fps = 24;
    float durationSec = 4.0f;

    // Model selection
    VideoModel preferredModel = VideoModel::Echoelmusic_Native;
    bool allowCloudFallback = true;
    float maxCostUSD = 1.0f;

    // Bio-reactive
    bool useBioState = true;
    bool useAudioState = true;
    BioState bioSnapshot;
    AudioState audioSnapshot;

    // Quality
    float qualityLevel = 0.8f;          // 0-1
    int guidanceScale = 7;
    int inferenceSteps = 30;
    int64_t seed = -1;                  // -1 = random

    // Callbacks
    std::function<void(float)> progressCallback;
    std::function<void(const std::vector<uint8_t>&)> frameCallback;
    std::function<void(const std::vector<uint8_t>&, bool success)> completionCallback;
};

//==============================================================================
// External Software Integration
//==============================================================================

enum class ExternalSoftware : uint8_t
{
    // Video Editors
    AdobePremiere,
    AdobeAfterEffects,
    DaVinciResolve,
    AvidMediaComposer,
    FinalCutPro,
    CapCut,

    // VJ Software
    Resolume,
    TouchDesigner,
    MadMapper,
    VDMX,
    Millumin,

    // DAWs
    AbletonLive,
    LogicPro,
    ProTools,
    FLStudio,
    Cubase,
    Bitwig,

    // Game Engines
    Unity,
    UnrealEngine,
    Godot,

    // AI Platforms
    ComfyUI,
    Automatic1111,

    // Lighting
    GrandMA,
    QLC_Plus,
    DMXIS,

    NumSoftware
};

struct ExternalBridge
{
    ExternalSoftware software;
    std::string name;

    // Connection
    std::string protocol;            // "OSC", "MIDI", "REST", "WebSocket", "NDI"
    std::string host;
    int port;
    bool connected = false;

    // Capabilities
    bool canSendVideo = false;
    bool canReceiveVideo = false;
    bool canSendAudio = false;
    bool canReceiveAudio = false;
    bool canSendControl = true;
    bool canReceiveControl = true;
    bool canSendTimecode = false;

    // State
    float latencyMs = 0.0f;
    uint64_t lastMessageMs = 0;
    int messagesSent = 0;
    int messagesReceived = 0;
};

//==============================================================================
// Callbacks
//==============================================================================

using VideoFrameCallback = std::function<void(const uint8_t* rgba, int width, int height, uint64_t frameId)>;
using AudioBufferCallback = std::function<void(const float* samples, int numSamples, int numChannels)>;
using BioUpdateCallback = std::function<void(const BioState& state)>;
using LightingCallback = std::function<void(const LightingState& state)>;
using ErrorCallback = std::function<void(int code, const std::string& message)>;

} // namespace uci

//==============================================================================
// UniversalCreativeIntelligence - Main Class
//==============================================================================

class UniversalCreativeIntelligence
{
public:
    //==========================================================================
    // Lifecycle
    //==========================================================================

    UniversalCreativeIntelligence();
    ~UniversalCreativeIntelligence();

    /** Initialize the system, detect device capabilities */
    void initialize();

    /** Shutdown and release all resources */
    void shutdown();

    /** Check if initialized */
    bool isInitialized() const noexcept;

    //==========================================================================
    // Device & Performance
    //==========================================================================

    /** Get detected device capabilities */
    uci::DeviceCapabilities getDeviceCapabilities() const;

    /** Get current device tier */
    uci::DeviceTier getDeviceTier() const noexcept;

    /** Force a specific performance tier (for testing) */
    void setPerformanceTier(uci::DeviceTier tier);

    /** Get optimal video model for current device */
    uci::VideoModelInfo getOptimalVideoModel(int targetResolution = 720,
                                              float targetQuality = 0.8f) const;

    /** Get all available video models */
    std::vector<uci::VideoModelInfo> getAvailableVideoModels() const;

    //==========================================================================
    // State Updates (Real-time inputs)
    //==========================================================================

    /** Update biofeedback state */
    void updateBioState(const uci::BioState& state);

    /** Update audio analysis state */
    void updateAudioState(const uci::AudioState& state);

    /** Get current combined creative state */
    uci::VisualState computeVisualState() const;

    /** Get current lighting state from fusion */
    uci::LightingState computeLightingState() const;

    //==========================================================================
    // Fusion Engine
    //==========================================================================

    /** Load a fusion preset */
    void loadFusionPreset(const std::string& name);

    /** Load a custom fusion preset */
    void loadFusionPreset(const uci::FusionPreset& preset);

    /** Get current fusion preset */
    uci::FusionPreset getCurrentFusionPreset() const;

    /** Get all available fusion presets */
    std::vector<std::string> getFusionPresetNames() const;

    /** Add a custom mapping */
    void addFusionMapping(const uci::FusionMapping& mapping);

    /** Remove a mapping by index */
    void removeFusionMapping(int index);

    /** Set global fusion intensity */
    void setFusionIntensity(float intensity);

    /** Set bio influence strength */
    void setBioInfluence(float influence);

    /** Set audio influence strength */
    void setAudioInfluence(float influence);

    /** Set gesture influence strength */
    void setGestureInfluence(float influence);

    //==========================================================================
    // AI Video Generation
    //==========================================================================

    /** Generate video with AI (async) */
    void generateVideo(const uci::VideoGenerationRequest& request);

    /** Cancel current video generation */
    void cancelVideoGeneration();

    /** Check if video generation is in progress */
    bool isGeneratingVideo() const noexcept;

    /** Get video generation progress (0-1) */
    float getVideoGenerationProgress() const noexcept;

    /** Generate video prompt from current bio+audio state */
    std::string generatePromptFromState() const;

    /** Apply style transfer to video */
    void applyStyleTransfer(const std::vector<uint8_t>& inputVideo,
                            const std::string& style,
                            std::function<void(const std::vector<uint8_t>&)> callback);

    //==========================================================================
    // External Software Bridges
    //==========================================================================

    /** Connect to external software */
    bool connectToSoftware(uci::ExternalSoftware software,
                           const std::string& host = "127.0.0.1",
                           int port = 0);

    /** Disconnect from external software */
    void disconnectFromSoftware(uci::ExternalSoftware software);

    /** Check if connected to software */
    bool isConnectedTo(uci::ExternalSoftware software) const;

    /** Get all bridge states */
    std::vector<uci::ExternalBridge> getExternalBridges() const;

    /** Send OSC message to software */
    void sendOSC(uci::ExternalSoftware target,
                 const std::string& address,
                 const std::vector<float>& values);

    /** Send MIDI to software */
    void sendMIDI(uci::ExternalSoftware target,
                  uint8_t channel, uint8_t note, uint8_t velocity);

    /** Send video frame via NDI/Syphon/Spout */
    void sendVideoFrame(uci::ExternalSoftware target,
                        const uint8_t* rgba, int width, int height);

    //==========================================================================
    // ComfyUI Integration
    //==========================================================================

    /** Connect to ComfyUI server */
    bool connectToComfyUI(const std::string& host = "127.0.0.1", int port = 8188);

    /** Get available ComfyUI workflows */
    std::vector<std::string> getComfyUIWorkflows() const;

    /** Run a ComfyUI workflow */
    void runComfyUIWorkflow(const std::string& workflowName,
                            const std::map<std::string, std::string>& inputs,
                            std::function<void(const std::vector<uint8_t>&)> callback);

    /** Check ComfyUI queue status */
    int getComfyUIQueueLength() const;

    //==========================================================================
    // Lighting Output
    //==========================================================================

    /** Send DMX universe */
    void sendDMX(int universe, const uint8_t* data, int numChannels);

    /** Send Art-Net */
    void sendArtNet(int universe, const uint8_t* data, int numChannels,
                    const std::string& host = "255.255.255.255", int port = 6454);

    /** Send ILDA laser data */
    void sendILDA(const void* points, int numPoints);

    /** Set lighting fixture mapping */
    void setFixtureMapping(int fixtureId, int dmxAddress, int numChannels,
                           const std::string& profileName);

    //==========================================================================
    // Real-time Processing Loop
    //==========================================================================

    /** Process one frame of the fusion engine (call at 60fps) */
    void processFrame(double deltaTime);

    /** Get current frame rate */
    float getCurrentFPS() const noexcept;

    /** Get processing latency in ms */
    float getProcessingLatency() const noexcept;

    //==========================================================================
    // Callbacks
    //==========================================================================

    void setVideoFrameCallback(uci::VideoFrameCallback callback);
    void setAudioBufferCallback(uci::AudioBufferCallback callback);
    void setBioUpdateCallback(uci::BioUpdateCallback callback);
    void setLightingCallback(uci::LightingCallback callback);
    void setErrorCallback(uci::ErrorCallback callback);

    //==========================================================================
    // Presets & Saving
    //==========================================================================

    /** Save current state as preset */
    void savePreset(const std::string& name, const std::string& path);

    /** Load preset from file */
    void loadPresetFromFile(const std::string& path);

    /** Export fusion mappings */
    std::string exportMappingsJSON() const;

    /** Import fusion mappings from JSON */
    void importMappingsJSON(const std::string& json);

    //==========================================================================
    // Integration with Existing Echoelmusic Systems
    //==========================================================================

    /** Attach existing AdvancedLightController (uses Echoel::AdvancedLightController) */
    void attachLightController(Echoel::AdvancedLightController* controller);

    /** Attach existing VisualIntegrationAPI (uses Echoelmusic::VisualIntegrationAPI) */
    void attachVisualAPI(Echoelmusic::VisualIntegrationAPI* api);

    /** Attach VideoWeaver for video editing integration */
    void attachVideoWeaver(VideoWeaver* weaver);

    /** Attach BioReactiveDSP for audio processing */
    void attachBioReactiveDSP(BioReactiveDSP* dsp);

    /** Attach SuperLaserScan for optimized laser output */
    void attachSuperLaserScan(laser::SuperLaserScan* scan);

    /** Sync bio state to all attached systems */
    void syncBioStateToSystems();

    /** Sync audio state to all attached systems */
    void syncAudioStateToSystems();

    /** Get integration status report */
    std::string getIntegrationStatus() const;

    //==========================================================================
    // Unified Real-Time Processing
    //==========================================================================

    /** Process one unified frame - updates ALL attached systems at once */
    void processUnifiedFrame(double deltaTime);

    /** Enable/disable automatic system sync on state updates */
    void setAutoSync(bool enabled);

    /** Get total system latency (all systems combined) */
    float getTotalSystemLatency() const noexcept;

private:
    struct Impl;
    std::unique_ptr<Impl> pImpl;
};

//==============================================================================
// Fusion Presets (Built-in)
//==============================================================================

namespace uci {

inline std::vector<FusionPreset> FusionPreset::getBuiltInPresets()
{
    std::vector<FusionPreset> presets;

    // ============================================
    // MEDITATION & WELLNESS
    // ============================================
    {
        FusionPreset p;
        p.name = "Zen Breath";
        p.description = "Calming visuals synced to breathing, coherence drives color warmth";
        p.category = "Meditation";
        p.bioInfluence = 1.0f;
        p.audioInfluence = 0.3f;
        p.globalIntensity = 0.6f;

        p.mappings = {
            {"bio.breathPhase", "visual.brightness", 0, 1, 0.3f, 0.8f, 0.3f, 1, 0, 1, true, false},
            {"bio.coherence", "visual.colorTemperature", 0, 1, 4000, 7000, 0.5f, 1, 0, 1, true, false},
            {"bio.hrv", "visual.saturation", 0, 1, 0.3f, 0.9f, 0.4f, 1, 0, 1, true, false},
            {"bio.relaxationIndex", "light.masterDimmer", 0, 1, 0.2f, 0.7f, 0.5f, 1, 0, 1, true, false},
            {"bio.heartRate", "visual.motionSpeed", 40, 100, 0.1f, 0.5f, 0.3f, 1, 0, 1, true, false},
        };
        presets.push_back(p);
    }

    {
        FusionPreset p;
        p.name = "Heart Glow";
        p.description = "Pulses with heartbeat, HRV controls glow intensity";
        p.category = "Meditation";
        p.bioInfluence = 1.0f;
        p.audioInfluence = 0.2f;
        p.globalIntensity = 0.7f;

        p.mappings = {
            {"bio.heartRate", "visual.glowIntensity", 50, 90, 0.2f, 1.0f, 0.1f, 1, 0, 1, true, false},
            {"bio.hrv", "visual.particleDensity", 0, 1, 0, 0.8f, 0.3f, 1, 0, 1, true, false},
            {"bio.coherence", "light.globalColor.g", 0, 1, 0.3f, 1.0f, 0.2f, 1, 0, 1, true, false},
        };
        presets.push_back(p);
    }

    // ============================================
    // PERFORMANCE & LIVE
    // ============================================
    {
        FusionPreset p;
        p.name = "Beat Fusion";
        p.description = "Full audio-reactive with bass-driven visuals and beat-synced lights";
        p.category = "Performance";
        p.bioInfluence = 0.3f;
        p.audioInfluence = 1.0f;
        p.globalIntensity = 1.0f;

        p.mappings = {
            {"audio.bass", "visual.glowIntensity", 0, 1, 0, 1, 0.05f, 1.5f, 0, 1, true, false},
            {"audio.mid", "visual.saturation", 0, 1, 0.5f, 1.0f, 0.1f, 1, 0, 1, true, false},
            {"audio.brilliance", "visual.particleDensity", 0, 1, 0, 0.8f, 0.08f, 1, 0, 1, true, false},
            {"audio.beatPhase", "light.masterStrobe", 0, 1, 0, 1, 0.02f, 2, 0, 1, true, false},
            {"audio.bpm", "visual.motionSpeed", 60, 180, 0.3f, 1.5f, 0.5f, 1, 0, 1, true, false},
            {"audio.energy", "light.masterDimmer", 0, 1, 0.3f, 1.0f, 0.1f, 1, 0, 1, true, false},
        };
        presets.push_back(p);
    }

    {
        FusionPreset p;
        p.name = "Gesture Control";
        p.description = "Hand movements control visuals, facial expressions affect colors";
        p.category = "Performance";
        p.bioInfluence = 0.5f;
        p.audioInfluence = 0.5f;
        p.gestureInfluence = 1.0f;
        p.globalIntensity = 0.9f;

        p.mappings = {
            {"bio.handMovement", "visual.distortionAmount", 0, 1, 0, 0.5f, 0.1f, 1, 0, 1, true, false},
            {"bio.gestureIntensity", "visual.motionIntensity", 0, 1, 0.2f, 1.0f, 0.1f, 1, 0, 1, true, false},
            {"bio.facialExpression", "visual.colorTemperature", 0, 1, 3000, 8000, 0.2f, 1, 0, 1, true, false},
            {"bio.eyeOpenness", "visual.brightness", 0, 1, 0.3f, 1.0f, 0.15f, 1, 0, 1, true, false},
            {"bio.mouthOpenness", "light.zoom", 0, 1, 0.3f, 1.0f, 0.1f, 1, 0, 1, true, false},
        };
        presets.push_back(p);
    }

    // ============================================
    // PARTY & CLUB
    // ============================================
    {
        FusionPreset p;
        p.name = "Rave Mode";
        p.description = "Maximum energy, strobes on beats, bass-reactive everything";
        p.category = "Party";
        p.bioInfluence = 0.1f;
        p.audioInfluence = 1.0f;
        p.globalIntensity = 1.0f;

        p.mappings = {
            {"audio.subBass", "visual.zoom", 0, 1, -0.3f, 0.3f, 0.03f, 2, 0, 1, true, false},
            {"audio.bass", "light.masterDimmer", 0, 1, 0.5f, 1.0f, 0.02f, 1.5f, 0, 1, true, false},
            {"audio.beatDetected", "light.masterStrobe", 0, 1, 0, 1, 0.01f, 1, 0, 1, true, false},
            {"audio.energy", "visual.glitchAmount", 0, 1, 0, 0.3f, 0.05f, 1, 0, 1, true, false},
            {"audio.spectralFlux", "visual.distortionAmount", 0, 1, 0, 0.4f, 0.08f, 1, 0, 1, true, false},
        };
        presets.push_back(p);
    }

    // ============================================
    // CREATIVE & STUDIO
    // ============================================
    {
        FusionPreset p;
        p.name = "Producer Flow";
        p.description = "Subtle visuals that enhance focus, responds to music creation";
        p.category = "Studio";
        p.bioInfluence = 0.5f;
        p.audioInfluence = 0.6f;
        p.globalIntensity = 0.4f;

        p.mappings = {
            {"bio.flowState", "visual.brightness", 0, 1, 0.4f, 0.7f, 0.5f, 1, 0, 1, true, false},
            {"bio.focusLevel", "light.colorTemperature", 0, 1, 4000, 6500, 0.5f, 1, 0, 1, true, false},
            {"audio.rmsLevel", "visual.particleDensity", 0, 1, 0, 0.3f, 0.2f, 1, 0, 1, true, false},
            {"bio.stressIndex", "visual.saturation", 0, 1, 0.7f, 0.3f, 0.3f, 1, 0, 1, true, true},
        };
        presets.push_back(p);
    }

    // ============================================
    // EXPERIMENTAL
    // ============================================
    {
        FusionPreset p;
        p.name = "Synaesthesia";
        p.description = "Full cross-modal mapping - see sound, hear colors, feel rhythm";
        p.category = "Experimental";
        p.bioInfluence = 0.7f;
        p.audioInfluence = 0.9f;
        p.gestureInfluence = 0.6f;
        p.globalIntensity = 0.8f;

        p.mappings = {
            // Audio → Visual
            {"audio.spectralCentroid", "visual.dominantColor.r", 500, 8000, 0, 1, 0.1f, 1, 0, 1, true, false},
            {"audio.harmonicTension", "visual.distortionAmount", 0, 1, 0, 0.5f, 0.15f, 1, 0, 1, true, false},
            // Bio → Audio-like effects
            {"bio.heartRate", "visual.motionSpeed", 50, 100, 0.3f, 1.2f, 0.2f, 1, 0, 1, true, false},
            {"bio.breathPhase", "visual.zoom", 0, 1, -0.2f, 0.2f, 0.4f, 1, 0, 1, true, false},
            // Gesture → Everything
            {"bio.handMovement", "light.pan", 0, 1, 0, 1, 0.1f, 1, 0, 1, true, false},
            {"bio.bodyMovement", "visual.rotation", 0, 1, -1, 1, 0.2f, 1, 0, 1, true, false},
        };
        presets.push_back(p);
    }

    return presets;
}

} // namespace uci
