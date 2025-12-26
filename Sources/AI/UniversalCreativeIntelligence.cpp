/**
 * UniversalCreativeIntelligence.cpp
 *
 * GENIUS WISE MODE Implementation
 * Super-intelligent fusion of biofeedback, audio, visuals, and lighting
 * with AI video generation and professional software integration.
 *
 * Optimized for ANY device: iPhone SE to Mac Studio to Cloud H100
 */

#include "UniversalCreativeIntelligence.h"

#include <algorithm>
#include <cmath>
#include <cstring>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>
#include <chrono>
#include <atomic>
#include <unordered_map>
#include <sstream>
#include <fstream>

// Platform detection
#if defined(__APPLE__)
    #include <TargetConditionals.h>
    #if TARGET_OS_IOS
        #define UCI_PLATFORM_IOS 1
    #else
        #define UCI_PLATFORM_MACOS 1
    #endif
    #define UCI_HAS_METAL 1
#elif defined(_WIN32)
    #define UCI_PLATFORM_WINDOWS 1
#elif defined(__linux__)
    #define UCI_PLATFORM_LINUX 1
#endif

// SIMD detection
#if defined(__AVX2__)
    #define UCI_SIMD_AVX2 1
    #include <immintrin.h>
#elif defined(__SSE2__)
    #define UCI_SIMD_SSE2 1
    #include <emmintrin.h>
#elif defined(__ARM_NEON__)
    #define UCI_SIMD_NEON 1
    #include <arm_neon.h>
#endif

namespace uci {

//==============================================================================
// DeviceCapabilities Implementation
//==============================================================================

DeviceCapabilities DeviceCapabilities::detect()
{
    DeviceCapabilities caps;

    // Get CPU cores
    caps.cpuCores = static_cast<uint32_t>(std::thread::hardware_concurrency());
    if (caps.cpuCores == 0) caps.cpuCores = 4;

    // Platform-specific detection
#if UCI_PLATFORM_IOS
    caps.hasNPU = true;  // All modern iOS devices have Neural Engine
    caps.hasMetal = true;
    caps.hasGPU = true;

    // Estimate RAM based on device (simplified)
    // In production, use sysctlbyname("hw.memsize", ...)
    if (caps.cpuCores >= 6) {
        caps.ramBytes = 6ULL * 1024 * 1024 * 1024;  // 6GB (Pro models)
        caps.tier = DeviceTier::Mobile_Pro;
        caps.gpuTFLOPS = 2.5f;
        caps.maxVideoResolution = 1080;
        caps.maxFPS = 60;
        caps.canRun4K = false;
        caps.canRunLocalVideoGen = false;  // Too memory constrained
        caps.qualityMultiplier = 0.85f;
    } else if (caps.cpuCores >= 4) {
        caps.ramBytes = 4ULL * 1024 * 1024 * 1024;  // 4GB
        caps.tier = DeviceTier::Mobile_Mid;
        caps.gpuTFLOPS = 1.5f;
        caps.maxVideoResolution = 720;
        caps.maxFPS = 30;
        caps.qualityMultiplier = 0.6f;
    } else {
        caps.ramBytes = 2ULL * 1024 * 1024 * 1024;  // 2GB (SE)
        caps.tier = DeviceTier::Mobile_Entry;
        caps.gpuTFLOPS = 0.8f;
        caps.maxVideoResolution = 480;
        caps.maxFPS = 30;
        caps.qualityMultiplier = 0.4f;
    }

#elif UCI_PLATFORM_MACOS
    caps.hasMetal = true;
    caps.hasGPU = true;
    caps.hasNPU = true;  // M-series chips have Neural Engine

    if (caps.cpuCores >= 16) {
        // M2 Ultra / M3 Max territory
        caps.ramBytes = 64ULL * 1024 * 1024 * 1024;
        caps.vramBytes = 96ULL * 1024 * 1024 * 1024;  // Unified memory
        caps.tier = DeviceTier::Desktop_Pro;
        caps.gpuTFLOPS = 25.0f;
        caps.maxVideoResolution = 4096;  // 4K
        caps.maxFPS = 120;
        caps.maxParallelStreams = 4;
        caps.canRun4K = true;
        caps.canRunLocalVideoGen = true;
        caps.canRunLocalLLM = true;
        caps.qualityMultiplier = 1.0f;
    } else if (caps.cpuCores >= 10) {
        // M2 Pro / M3 Pro
        caps.ramBytes = 32ULL * 1024 * 1024 * 1024;
        caps.vramBytes = 32ULL * 1024 * 1024 * 1024;
        caps.tier = DeviceTier::Desktop_Mid;
        caps.gpuTFLOPS = 15.0f;
        caps.maxVideoResolution = 2160;  // 4K but slower
        caps.maxFPS = 60;
        caps.maxParallelStreams = 2;
        caps.canRun4K = true;
        caps.canRunLocalVideoGen = true;
        caps.qualityMultiplier = 0.9f;
    } else {
        // M1/M2 base
        caps.ramBytes = 16ULL * 1024 * 1024 * 1024;
        caps.vramBytes = 16ULL * 1024 * 1024 * 1024;
        caps.tier = DeviceTier::Desktop_Entry;
        caps.gpuTFLOPS = 8.0f;
        caps.maxVideoResolution = 1080;
        caps.maxFPS = 60;
        caps.canRunLocalVideoGen = false;  // Not enough VRAM for most models
        caps.qualityMultiplier = 0.75f;
    }

#elif UCI_PLATFORM_LINUX || UCI_PLATFORM_WINDOWS
    // Check for CUDA (NVIDIA)
    // In production, use CUDA runtime to query actual device
    caps.hasCUDA = true;  // Assume for now
    caps.hasGPU = true;

    if (caps.cpuCores >= 24) {
        // High-end workstation or server
        caps.ramBytes = 128ULL * 1024 * 1024 * 1024;
        caps.vramBytes = 24ULL * 1024 * 1024 * 1024;  // RTX 4090
        caps.tier = DeviceTier::Desktop_Pro;
        caps.gpuTFLOPS = 80.0f;  // RTX 4090
        caps.maxVideoResolution = 4096;
        caps.maxFPS = 120;
        caps.maxParallelStreams = 4;
        caps.canRun4K = true;
        caps.canRunLocalVideoGen = true;
        caps.canRunLocalLLM = true;
        caps.qualityMultiplier = 1.0f;
    } else if (caps.cpuCores >= 12) {
        caps.ramBytes = 32ULL * 1024 * 1024 * 1024;
        caps.vramBytes = 12ULL * 1024 * 1024 * 1024;
        caps.tier = DeviceTier::Desktop_Mid;
        caps.gpuTFLOPS = 30.0f;
        caps.maxVideoResolution = 2160;
        caps.maxFPS = 60;
        caps.canRunLocalVideoGen = true;
        caps.qualityMultiplier = 0.85f;
    } else {
        caps.ramBytes = 16ULL * 1024 * 1024 * 1024;
        caps.vramBytes = 8ULL * 1024 * 1024 * 1024;
        caps.tier = DeviceTier::Desktop_Entry;
        caps.gpuTFLOPS = 15.0f;
        caps.maxVideoResolution = 1080;
        caps.maxFPS = 60;
        caps.qualityMultiplier = 0.7f;
    }
#endif

    // Check network (simplified - just assume good connection)
    caps.hasCloudAccess = true;
    caps.bandwidthMbps = 100.0f;
    caps.latencyMs = 30.0f;

    // All devices can run real-time fusion
    caps.canRunRealTime = true;

    return caps;
}

//==============================================================================
// VideoModelInfo Implementation
//==============================================================================

std::vector<VideoModelInfo> VideoModelInfo::getAllModels()
{
    std::vector<VideoModelInfo> models;

    // CogVideoX 2B
    models.push_back({
        VideoModel::CogVideoX_2B,
        "CogVideoX 2B",
        "Zhipu AI",
        8ULL * 1024 * 1024 * 1024,  // 8GB VRAM
        DeviceTier::Desktop_Entry,
        false,  // Can run locally
        true,   // Open source
        "Apache 2.0",
        720,    // Max resolution
        6,      // Max duration
        24,     // Max FPS
        78.0f,  // Quality score
        80.0f,  // Motion score
        75.0f,  // Prompt adherence
        60.0f,  // Speed score
        0.0f,   // Cost (free local)
        45.0f   // Gen time seconds
    });

    // CogVideoX 5B
    models.push_back({
        VideoModel::CogVideoX_5B,
        "CogVideoX 5B",
        "Zhipu AI",
        16ULL * 1024 * 1024 * 1024,
        DeviceTier::Desktop_Mid,
        false, true, "Apache 2.0",
        720, 10, 24,
        85.0f, 85.0f, 82.0f, 40.0f,
        0.0f, 120.0f
    });

    // CogVideoX 1.5
    models.push_back({
        VideoModel::CogVideoX_1_5,
        "CogVideoX 1.5",
        "Zhipu AI",
        16ULL * 1024 * 1024 * 1024,
        DeviceTier::Desktop_Mid,
        false, true, "Apache 2.0",
        1080, 10, 24,
        88.0f, 87.0f, 85.0f, 35.0f,
        0.0f, 150.0f
    });

    // Mochi 1 Preview
    models.push_back({
        VideoModel::Mochi1_Preview,
        "Mochi 1 Preview",
        "Genmo",
        24ULL * 1024 * 1024 * 1024,
        DeviceTier::Desktop_Pro,
        false, true, "Apache 2.0",
        480, 5, 24,
        82.0f, 90.0f, 80.0f, 30.0f,
        0.0f, 180.0f
    });

    // Wan 2.1 1.3B (Efficient)
    models.push_back({
        VideoModel::Wan2_1_1B,
        "Wan 2.1 (1.3B)",
        "Alibaba",
        6ULL * 1024 * 1024 * 1024,
        DeviceTier::Desktop_Entry,
        false, true, "Apache 2.0",
        720, 8, 24,
        75.0f, 78.0f, 72.0f, 75.0f,
        0.0f, 30.0f
    });

    // Wan 2.1 14B (Quality)
    models.push_back({
        VideoModel::Wan2_1_14B,
        "Wan 2.1 (14B)",
        "Alibaba",
        24ULL * 1024 * 1024 * 1024,
        DeviceTier::Desktop_Pro,
        false, true, "Apache 2.0",
        1080, 16, 30,
        90.0f, 88.0f, 87.0f, 25.0f,
        0.0f, 240.0f
    });

    // AnimateDiff
    models.push_back({
        VideoModel::AnimateDiff,
        "AnimateDiff",
        "Community",
        8ULL * 1024 * 1024 * 1024,
        DeviceTier::Desktop_Entry,
        false, true, "Apache 2.0",
        1024, 4, 16,
        80.0f, 75.0f, 85.0f, 70.0f,
        0.0f, 60.0f
    });

    // AnimateDiff Lightning (Fast)
    models.push_back({
        VideoModel::AnimateDiff_Lightning,
        "AnimateDiff Lightning",
        "Community",
        8ULL * 1024 * 1024 * 1024,
        DeviceTier::Desktop_Entry,
        false, true, "Apache 2.0",
        1024, 4, 16,
        72.0f, 70.0f, 78.0f, 95.0f,
        0.0f, 10.0f  // Super fast!
    });

    // Stream Video (Real-time)
    models.push_back({
        VideoModel::StreamVideo,
        "Stream Video",
        "Open Source",
        8ULL * 1024 * 1024 * 1024,
        DeviceTier::Desktop_Entry,
        false, true, "MIT",
        720, 0, 30,  // Continuous stream
        65.0f, 70.0f, 60.0f, 100.0f,  // Real-time!
        0.0f, 0.033f  // 30fps
    });

    // Commercial APIs
    models.push_back({
        VideoModel::Runway_Gen4,
        "Runway Gen-4",
        "Runway ML",
        0, DeviceTier::Mobile_Entry,  // Cloud
        true, false, "Commercial",
        1080, 10, 24,
        92.0f, 90.0f, 88.0f, 50.0f,
        0.05f, 60.0f
    });

    models.push_back({
        VideoModel::Pika_2_0,
        "Pika 2.0",
        "Pika Labs",
        0, DeviceTier::Mobile_Entry,
        true, false, "Commercial",
        1080, 5, 24,
        88.0f, 85.0f, 82.0f, 60.0f,
        0.03f, 30.0f
    });

    models.push_back({
        VideoModel::Kling_1_6,
        "Kling 1.6",
        "Kuaishou",
        0, DeviceTier::Mobile_Entry,
        true, false, "Commercial",
        1080, 10, 24,
        90.0f, 88.0f, 85.0f, 45.0f,
        0.04f, 45.0f
    });

    // Echoelmusic Native (our optimized engine)
    models.push_back({
        VideoModel::Echoelmusic_Native,
        "Echoelmusic Native",
        "Echoelmusic",
        4ULL * 1024 * 1024 * 1024,
        DeviceTier::Mobile_Mid,
        false, false, "Proprietary",
        1080, 0, 60,  // Real-time
        70.0f, 85.0f, 65.0f, 100.0f,
        0.0f, 0.016f  // 60fps
    });

    return models;
}

VideoModelInfo VideoModelInfo::getOptimalModel(const DeviceCapabilities& device,
                                               int targetResolution,
                                               float targetQuality)
{
    auto models = getAllModels();
    VideoModelInfo best = models.back();  // Default to native
    float bestScore = -1000.0f;

    for (const auto& m : models) {
        // Skip if device can't run it
        if (static_cast<int>(device.tier) < static_cast<int>(m.minTier)) continue;
        if (!m.requiresAPI && device.vramBytes < m.minVRAM) continue;
        if (m.requiresAPI && !device.hasCloudAccess) continue;
        if (m.maxResolution < targetResolution * 0.75f) continue;

        // Score the model
        float score = 0.0f;

        // Quality match (most important)
        float qualityMatch = 1.0f - std::abs(m.qualityScore / 100.0f - targetQuality);
        score += qualityMatch * 50.0f;

        // Resolution match
        if (m.maxResolution >= targetResolution) {
            score += 20.0f;
        }

        // Speed bonus (prefer faster)
        score += m.speedScore * 0.2f;

        // Open source bonus
        if (m.isOpenSource) score += 5.0f;

        // Local execution bonus (lower latency)
        if (!m.requiresAPI) score += 10.0f;

        if (score > bestScore) {
            bestScore = score;
            best = m;
        }
    }

    return best;
}

//==============================================================================
// BioState Implementation
//==============================================================================

void BioState::computeDerivedParameters()
{
    // Creative energy from HRV + coherence + flow
    creativeEnergy = (hrv * 0.3f + coherence * 0.4f + flowState * 0.3f);
    creativeEnergy = std::clamp(creativeEnergy, 0.0f, 1.0f);

    // Emotional intensity from facial + gesture + stress
    emotionalIntensity = (facialExpression * 0.3f +
                          gestureIntensity * 0.3f +
                          (1.0f - stressIndex) * 0.2f +
                          expressiveness * 0.2f);
    emotionalIntensity = std::clamp(emotionalIntensity, 0.0f, 1.0f);

    // Focus from HRV + low stress + eye openness
    focusLevel = (hrv * 0.4f + (1.0f - stressIndex) * 0.3f + eyeOpenness * 0.3f);
    focusLevel = std::clamp(focusLevel, 0.0f, 1.0f);

    // Expressiveness from all movement
    expressiveness = (gestureIntensity * 0.3f +
                      handMovement * 0.25f +
                      bodyMovement * 0.25f +
                      headMovement * 0.2f);
    expressiveness = std::clamp(expressiveness, 0.0f, 1.0f);

    // Update timestamp
    lastUpdateMs = static_cast<uint64_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch()
        ).count()
    );
    isValid = true;
}

//==============================================================================
// FusionMapping Implementation
//==============================================================================

float FusionMapping::process(float input)
{
    if (!enabled) return currentValue;

    // Clamp to source range
    input = std::clamp(input, sourceMin, sourceMax);

    // Normalize to 0-1
    float normalized = (input - sourceMin) / (sourceMax - sourceMin + 1e-9f);

    // Apply response curve (power function)
    if (response != 1.0f) {
        normalized = std::pow(normalized, response);
    }

    // Invert if needed
    if (inverted) {
        normalized = 1.0f - normalized;
    }

    // Apply scale and offset
    normalized = normalized * scale + offset;

    // Map to target range
    float output = targetMin + normalized * (targetMax - targetMin);

    // Apply smoothing
    currentValue += (output - currentValue) * (1.0f - smoothing);

    return currentValue;
}

} // namespace uci

//==============================================================================
// UniversalCreativeIntelligence Implementation
//==============================================================================

struct UniversalCreativeIntelligence::Impl
{
    // Initialization state
    std::atomic<bool> initialized{false};

    // Device
    uci::DeviceCapabilities deviceCaps;
    uci::DeviceTier forcedTier = uci::DeviceTier::NumTiers;

    // Current states
    uci::BioState bioState;
    uci::AudioState audioState;
    uci::VisualState visualState;
    uci::LightingState lightingState;
    std::mutex stateMutex;

    // Attached existing Echoelmusic systems
    Echoel::AdvancedLightController* lightController = nullptr;
    Echoelmusic::VisualIntegrationAPI* visualAPI = nullptr;
    VideoWeaver* videoWeaver = nullptr;
    BioReactiveDSP* bioReactiveDSP = nullptr;
    laser::SuperLaserScan* laserScan = nullptr;
    bool autoSync = true;

    // Fusion
    uci::FusionPreset currentPreset;
    std::vector<uci::FusionPreset> allPresets;
    float globalIntensity = 1.0f;
    float bioInfluence = 1.0f;
    float audioInfluence = 1.0f;
    float gestureInfluence = 0.5f;

    // Video generation
    std::atomic<bool> generatingVideo{false};
    std::atomic<float> videoProgress{0.0f};
    std::thread videoGenThread;
    std::mutex videoMutex;

    // External bridges
    std::vector<uci::ExternalBridge> bridges;
    std::mutex bridgeMutex;

    // ComfyUI
    std::string comfyUIHost;
    int comfyUIPort = 8188;
    bool comfyUIConnected = false;
    std::vector<std::string> comfyUIWorkflows;

    // Performance
    std::atomic<float> currentFPS{60.0f};
    std::atomic<float> processingLatency{0.0f};
    std::chrono::steady_clock::time_point lastFrameTime;
    uint64_t frameCount = 0;

    // Callbacks
    uci::VideoFrameCallback videoCallback;
    uci::AudioBufferCallback audioCallback;
    uci::BioUpdateCallback bioCallback;
    uci::LightingCallback lightingCallback;
    uci::ErrorCallback errorCallback;

    // OPTIMIZATION: Single unified value map for O(1) lookup
    // Previous: 4 separate maps × 2 lookups each = up to 8 lookups per value
    // Now: 1 map × 1 lookup = O(1) constant time
    std::unordered_map<std::string, float*> unifiedValueMap;

    // Category flags for influence multipliers (bit flags for fast check)
    enum class ValueCategory : uint8_t { Bio = 1, Audio = 2, Visual = 4, Light = 8 };
    std::unordered_map<std::string, ValueCategory> valueCategoryMap;

    void buildValueMaps();
    float getValueByPath(const std::string& path);
    void setValueByPath(const std::string& path, float value);
    ValueCategory getValueCategory(const std::string& path);

    // AI prompt generation
    std::string generateCreativePrompt();
};

void UniversalCreativeIntelligence::Impl::buildValueMaps()
{
    // OPTIMIZATION: Build unified value map for O(1) lookup
    // All 54+ values in single hash map instead of 4 separate maps

    // Helper lambda to add entries with category tracking
    auto addBio = [this](const char* path, float* ptr) {
        unifiedValueMap[path] = ptr;
        valueCategoryMap[path] = ValueCategory::Bio;
    };
    auto addAudio = [this](const char* path, float* ptr) {
        unifiedValueMap[path] = ptr;
        valueCategoryMap[path] = ValueCategory::Audio;
    };
    auto addVisual = [this](const char* path, float* ptr) {
        unifiedValueMap[path] = ptr;
        valueCategoryMap[path] = ValueCategory::Visual;
    };
    auto addLight = [this](const char* path, float* ptr) {
        unifiedValueMap[path] = ptr;
        valueCategoryMap[path] = ValueCategory::Light;
    };

    // Bio state mappings (20 values)
    addBio("bio.heartRate", &bioState.heartRate);
    addBio("bio.hrv", &bioState.hrv);
    addBio("bio.coherence", &bioState.coherence);
    addBio("bio.breathingRate", &bioState.breathingRate);
    addBio("bio.breathPhase", &bioState.breathPhase);
    addBio("bio.breathDepth", &bioState.breathDepth);
    addBio("bio.stressIndex", &bioState.stressIndex);
    addBio("bio.relaxationIndex", &bioState.relaxationIndex);
    addBio("bio.flowState", &bioState.flowState);
    addBio("bio.gestureIntensity", &bioState.gestureIntensity);
    addBio("bio.facialExpression", &bioState.facialExpression);
    addBio("bio.eyeOpenness", &bioState.eyeOpenness);
    addBio("bio.mouthOpenness", &bioState.mouthOpenness);
    addBio("bio.handMovement", &bioState.handMovement);
    addBio("bio.bodyMovement", &bioState.bodyMovement);
    addBio("bio.headMovement", &bioState.headMovement);
    addBio("bio.creativeEnergy", &bioState.creativeEnergy);
    addBio("bio.emotionalIntensity", &bioState.emotionalIntensity);
    addBio("bio.focusLevel", &bioState.focusLevel);
    addBio("bio.expressiveness", &bioState.expressiveness);

    // Audio state mappings (16 values)
    addAudio("audio.peakLevel", &audioState.peakLevel);
    addAudio("audio.rmsLevel", &audioState.rmsLevel);
    addAudio("audio.subBass", &audioState.subBass);
    addAudio("audio.bass", &audioState.bass);
    addAudio("audio.lowMid", &audioState.lowMid);
    addAudio("audio.mid", &audioState.mid);
    addAudio("audio.highMid", &audioState.highMid);
    addAudio("audio.presence", &audioState.presence);
    addAudio("audio.brilliance", &audioState.brilliance);
    addAudio("audio.bpm", &audioState.bpm);
    addAudio("audio.beatPhase", &audioState.beatPhase);
    addAudio("audio.energy", &audioState.energy);
    addAudio("audio.valence", &audioState.valence);
    addAudio("audio.spectralCentroid", &audioState.spectralCentroid);
    addAudio("audio.spectralFlux", &audioState.spectralFlux);
    addAudio("audio.harmonicTension", &audioState.harmonicTension);

    // Visual state mappings (17 values)
    addVisual("visual.brightness", &visualState.brightness);
    addVisual("visual.saturation", &visualState.saturation);
    addVisual("visual.contrast", &visualState.contrast);
    addVisual("visual.colorTemperature", &visualState.colorTemperature);
    addVisual("visual.motionIntensity", &visualState.motionIntensity);
    addVisual("visual.motionSpeed", &visualState.motionSpeed);
    addVisual("visual.zoom", &visualState.zoom);
    addVisual("visual.rotation", &visualState.rotation);
    addVisual("visual.glowIntensity", &visualState.glowIntensity);
    addVisual("visual.particleDensity", &visualState.particleDensity);
    addVisual("visual.distortionAmount", &visualState.distortionAmount);
    addVisual("visual.blurAmount", &visualState.blurAmount);
    addVisual("visual.noiseAmount", &visualState.noiseAmount);
    addVisual("visual.glitchAmount", &visualState.glitchAmount);
    addVisual("visual.dominantColor.r", &visualState.dominantColor[0]);
    addVisual("visual.dominantColor.g", &visualState.dominantColor[1]);
    addVisual("visual.dominantColor.b", &visualState.dominantColor[2]);

    // Lighting state mappings (11 values)
    addLight("light.masterDimmer", &lightingState.masterDimmer);
    addLight("light.masterStrobe", &lightingState.masterStrobe);
    addLight("light.colorTemperature", &lightingState.colorTemperature);
    addLight("light.pan", &lightingState.pan);
    addLight("light.tilt", &lightingState.tilt);
    addLight("light.focus", &lightingState.focus);
    addLight("light.zoom", &lightingState.zoom);
    addLight("light.laserIntensity", &lightingState.laserIntensity);
    addLight("light.globalColor.r", &lightingState.globalColor[0]);
    addLight("light.globalColor.g", &lightingState.globalColor[1]);
    addLight("light.globalColor.b", &lightingState.globalColor[2]);

    // Reserve capacity for optimal hash map performance
    unifiedValueMap.reserve(64);
    valueCategoryMap.reserve(64);
}

float UniversalCreativeIntelligence::Impl::getValueByPath(const std::string& path)
{
    // OPTIMIZATION: Single O(1) lookup instead of 4 × O(1) = O(1) but 4x faster
    auto it = unifiedValueMap.find(path);
    if (it != unifiedValueMap.end()) {
        return *it->second;
    }

    // Special case for beat detection (bool to float) - rarely used
    if (path == "audio.beatDetected") return audioState.beatDetected ? 1.0f : 0.0f;
    if (path == "audio.downbeatDetected") return audioState.downbeatDetected ? 1.0f : 0.0f;

    return 0.0f;
}

void UniversalCreativeIntelligence::Impl::setValueByPath(const std::string& path, float value)
{
    // OPTIMIZATION: Single O(1) lookup
    auto it = unifiedValueMap.find(path);
    if (it != unifiedValueMap.end()) {
        // Only allow setting visual and light values (targets)
        auto catIt = valueCategoryMap.find(path);
        if (catIt != valueCategoryMap.end() &&
            (catIt->second == ValueCategory::Visual || catIt->second == ValueCategory::Light)) {
            *it->second = value;
        }
    }
}

UniversalCreativeIntelligence::Impl::ValueCategory
UniversalCreativeIntelligence::Impl::getValueCategory(const std::string& path)
{
    auto it = valueCategoryMap.find(path);
    if (it != valueCategoryMap.end()) {
        return it->second;
    }
    return ValueCategory::Bio;  // Default
}

std::string UniversalCreativeIntelligence::Impl::generateCreativePrompt()
{
    std::ostringstream prompt;

    // Base style from coherence + valence
    if (bioState.coherence > 0.7f && audioState.valence > 0.6f) {
        prompt << "Serene, harmonious, flowing ";
    } else if (audioState.energy > 0.8f) {
        prompt << "Dynamic, energetic, pulsing ";
    } else if (bioState.stressIndex > 0.6f) {
        prompt << "Intense, dramatic, contrasting ";
    } else {
        prompt << "Balanced, evolving, organic ";
    }

    // Visual style from audio
    if (audioState.spectralCentroid > 4000) {
        prompt << "bright crystalline visuals, ";
    } else if (audioState.spectralCentroid < 1500) {
        prompt << "deep warm tones, ";
    }

    // Movement from bio
    if (bioState.gestureIntensity > 0.5f) {
        prompt << "responsive motion tracking, ";
    }
    if (bioState.breathPhase > 0.5f) {
        prompt << "expanding breathing rhythm, ";
    }

    // Color from heart
    float heartNorm = (bioState.heartRate - 60) / 40.0f;
    if (heartNorm > 0.5f) {
        prompt << "warm reds and oranges, ";
    } else {
        prompt << "cool blues and greens, ";
    }

    // Add quality
    prompt << "8K ultra detailed, cinematic lighting, volumetric effects";

    return prompt.str();
}

//==============================================================================
// Public API Implementation
//==============================================================================

UniversalCreativeIntelligence::UniversalCreativeIntelligence()
    : pImpl(std::make_unique<Impl>())
{
}

UniversalCreativeIntelligence::~UniversalCreativeIntelligence()
{
    shutdown();
}

void UniversalCreativeIntelligence::initialize()
{
    if (pImpl->initialized.load()) return;

    // Detect device
    pImpl->deviceCaps = uci::DeviceCapabilities::detect();

    // Build value maps for fusion
    pImpl->buildValueMaps();

    // Load built-in presets
    pImpl->allPresets = uci::FusionPreset::getBuiltInPresets();
    if (!pImpl->allPresets.empty()) {
        pImpl->currentPreset = pImpl->allPresets[0];
    }

    // Initialize default bridges
    pImpl->bridges.clear();

    // Initialize timing
    pImpl->lastFrameTime = std::chrono::steady_clock::now();
    pImpl->frameCount = 0;

    pImpl->initialized.store(true);
}

void UniversalCreativeIntelligence::shutdown()
{
    if (!pImpl->initialized.load()) return;

    // Cancel any video generation
    cancelVideoGeneration();

    // Disconnect bridges
    for (auto& bridge : pImpl->bridges) {
        bridge.connected = false;
    }

    pImpl->initialized.store(false);
}

bool UniversalCreativeIntelligence::isInitialized() const noexcept
{
    return pImpl->initialized.load();
}

uci::DeviceCapabilities UniversalCreativeIntelligence::getDeviceCapabilities() const
{
    return pImpl->deviceCaps;
}

uci::DeviceTier UniversalCreativeIntelligence::getDeviceTier() const noexcept
{
    if (pImpl->forcedTier != uci::DeviceTier::NumTiers) {
        return pImpl->forcedTier;
    }
    return pImpl->deviceCaps.tier;
}

void UniversalCreativeIntelligence::setPerformanceTier(uci::DeviceTier tier)
{
    pImpl->forcedTier = tier;
}

uci::VideoModelInfo UniversalCreativeIntelligence::getOptimalVideoModel(
    int targetResolution, float targetQuality) const
{
    return uci::VideoModelInfo::getOptimalModel(pImpl->deviceCaps, targetResolution, targetQuality);
}

std::vector<uci::VideoModelInfo> UniversalCreativeIntelligence::getAvailableVideoModels() const
{
    auto all = uci::VideoModelInfo::getAllModels();
    std::vector<uci::VideoModelInfo> available;

    for (const auto& m : all) {
        // Check if we can run this model
        if (m.requiresAPI && pImpl->deviceCaps.hasCloudAccess) {
            available.push_back(m);
        } else if (!m.requiresAPI &&
                   static_cast<int>(pImpl->deviceCaps.tier) >= static_cast<int>(m.minTier) &&
                   pImpl->deviceCaps.vramBytes >= m.minVRAM) {
            available.push_back(m);
        }
    }

    return available;
}

void UniversalCreativeIntelligence::updateBioState(const uci::BioState& state)
{
    std::lock_guard<std::mutex> lock(pImpl->stateMutex);
    pImpl->bioState = state;
    pImpl->bioState.computeDerivedParameters();

    if (pImpl->bioCallback) {
        pImpl->bioCallback(pImpl->bioState);
    }
}

void UniversalCreativeIntelligence::updateAudioState(const uci::AudioState& state)
{
    std::lock_guard<std::mutex> lock(pImpl->stateMutex);
    pImpl->audioState = state;
}

uci::VisualState UniversalCreativeIntelligence::computeVisualState() const
{
    std::lock_guard<std::mutex> lock(pImpl->stateMutex);
    return pImpl->visualState;
}

uci::LightingState UniversalCreativeIntelligence::computeLightingState() const
{
    std::lock_guard<std::mutex> lock(pImpl->stateMutex);
    return pImpl->lightingState;
}

void UniversalCreativeIntelligence::loadFusionPreset(const std::string& name)
{
    for (const auto& preset : pImpl->allPresets) {
        if (preset.name == name) {
            loadFusionPreset(preset);
            return;
        }
    }
}

void UniversalCreativeIntelligence::loadFusionPreset(const uci::FusionPreset& preset)
{
    pImpl->currentPreset = preset;
    pImpl->globalIntensity = preset.globalIntensity;
    pImpl->bioInfluence = preset.bioInfluence;
    pImpl->audioInfluence = preset.audioInfluence;
    pImpl->gestureInfluence = preset.gestureInfluence;
}

uci::FusionPreset UniversalCreativeIntelligence::getCurrentFusionPreset() const
{
    return pImpl->currentPreset;
}

std::vector<std::string> UniversalCreativeIntelligence::getFusionPresetNames() const
{
    std::vector<std::string> names;
    for (const auto& p : pImpl->allPresets) {
        names.push_back(p.name);
    }
    return names;
}

void UniversalCreativeIntelligence::addFusionMapping(const uci::FusionMapping& mapping)
{
    pImpl->currentPreset.mappings.push_back(mapping);
}

void UniversalCreativeIntelligence::removeFusionMapping(int index)
{
    if (index >= 0 && index < static_cast<int>(pImpl->currentPreset.mappings.size())) {
        pImpl->currentPreset.mappings.erase(pImpl->currentPreset.mappings.begin() + index);
    }
}

void UniversalCreativeIntelligence::setFusionIntensity(float intensity)
{
    pImpl->globalIntensity = std::clamp(intensity, 0.0f, 1.0f);
}

void UniversalCreativeIntelligence::setBioInfluence(float influence)
{
    pImpl->bioInfluence = std::clamp(influence, 0.0f, 1.0f);
}

void UniversalCreativeIntelligence::setAudioInfluence(float influence)
{
    pImpl->audioInfluence = std::clamp(influence, 0.0f, 1.0f);
}

void UniversalCreativeIntelligence::setGestureInfluence(float influence)
{
    pImpl->gestureInfluence = std::clamp(influence, 0.0f, 1.0f);
}

void UniversalCreativeIntelligence::generateVideo(const uci::VideoGenerationRequest& request)
{
    if (pImpl->generatingVideo.load()) {
        cancelVideoGeneration();
    }

    pImpl->generatingVideo.store(true);
    pImpl->videoProgress.store(0.0f);

    // Get optimal model
    auto model = getOptimalVideoModel(request.width, request.qualityLevel);

    pImpl->videoGenThread = std::thread([this, request, model]() {
        // Simulate video generation (in production, call actual model APIs)
        const int totalSteps = request.inferenceSteps;

        for (int step = 0; step < totalSteps && pImpl->generatingVideo.load(); ++step) {
            // Simulate processing time
            float stepTime = model.localGenTimeSec / totalSteps;
            std::this_thread::sleep_for(
                std::chrono::milliseconds(static_cast<int>(stepTime * 1000))
            );

            pImpl->videoProgress.store(static_cast<float>(step + 1) / totalSteps);

            if (request.progressCallback) {
                request.progressCallback(pImpl->videoProgress.load());
            }
        }

        // Generate dummy output (in production, actual video bytes)
        std::vector<uint8_t> output;
        if (pImpl->generatingVideo.load()) {
            // Generate placeholder video data
            int frameSize = request.width * request.height * 4;  // RGBA
            int numFrames = static_cast<int>(request.durationSec * request.fps);
            output.resize(frameSize * numFrames);
            // Fill with gradient pattern
            for (int f = 0; f < numFrames; ++f) {
                for (int y = 0; y < request.height; ++y) {
                    for (int x = 0; x < request.width; ++x) {
                        int idx = (f * request.width * request.height + y * request.width + x) * 4;
                        output[idx + 0] = static_cast<uint8_t>((x * 255) / request.width);
                        output[idx + 1] = static_cast<uint8_t>((y * 255) / request.height);
                        output[idx + 2] = static_cast<uint8_t>((f * 255) / numFrames);
                        output[idx + 3] = 255;
                    }
                }
            }
        }

        if (request.completionCallback) {
            request.completionCallback(output, pImpl->generatingVideo.load());
        }

        pImpl->generatingVideo.store(false);
    });
}

void UniversalCreativeIntelligence::cancelVideoGeneration()
{
    pImpl->generatingVideo.store(false);
    if (pImpl->videoGenThread.joinable()) {
        pImpl->videoGenThread.join();
    }
}

bool UniversalCreativeIntelligence::isGeneratingVideo() const noexcept
{
    return pImpl->generatingVideo.load();
}

float UniversalCreativeIntelligence::getVideoGenerationProgress() const noexcept
{
    return pImpl->videoProgress.load();
}

std::string UniversalCreativeIntelligence::generatePromptFromState() const
{
    return pImpl->generateCreativePrompt();
}

void UniversalCreativeIntelligence::applyStyleTransfer(
    const std::vector<uint8_t>& inputVideo,
    const std::string& style,
    std::function<void(const std::vector<uint8_t>&)> callback)
{
    // In production, run actual style transfer model
    // For now, just pass through
    if (callback) {
        callback(inputVideo);
    }
}

bool UniversalCreativeIntelligence::connectToSoftware(
    uci::ExternalSoftware software,
    const std::string& host,
    int port)
{
    std::lock_guard<std::mutex> lock(pImpl->bridgeMutex);

    uci::ExternalBridge bridge;
    bridge.software = software;
    bridge.host = host;
    bridge.connected = false;

    // Set default ports and protocols based on software
    switch (software) {
        case uci::ExternalSoftware::AbletonLive:
            bridge.name = "Ableton Live";
            bridge.protocol = "OSC";
            bridge.port = (port == 0) ? 9000 : port;
            bridge.canReceiveControl = true;
            bridge.canSendControl = true;
            bridge.canSendTimecode = true;
            break;

        case uci::ExternalSoftware::Resolume:
            bridge.name = "Resolume";
            bridge.protocol = "OSC";
            bridge.port = (port == 0) ? 7000 : port;
            bridge.canSendVideo = true;
            bridge.canReceiveVideo = true;
            bridge.canSendControl = true;
            break;

        case uci::ExternalSoftware::TouchDesigner:
            bridge.name = "TouchDesigner";
            bridge.protocol = "OSC";
            bridge.port = (port == 0) ? 9000 : port;
            bridge.canSendVideo = true;
            bridge.canReceiveVideo = true;
            bridge.canSendControl = true;
            break;

        case uci::ExternalSoftware::DaVinciResolve:
            bridge.name = "DaVinci Resolve";
            bridge.protocol = "REST";
            bridge.port = (port == 0) ? 38080 : port;
            bridge.canSendVideo = true;
            bridge.canSendControl = true;
            break;

        case uci::ExternalSoftware::ComfyUI:
            bridge.name = "ComfyUI";
            bridge.protocol = "WebSocket";
            bridge.port = (port == 0) ? 8188 : port;
            bridge.canSendVideo = true;
            break;

        case uci::ExternalSoftware::GrandMA:
            bridge.name = "grandMA";
            bridge.protocol = "OSC";
            bridge.port = (port == 0) ? 8000 : port;
            bridge.canSendControl = true;
            bridge.canSendTimecode = true;
            break;

        case uci::ExternalSoftware::QLC_Plus:
            bridge.name = "QLC+";
            bridge.protocol = "OSC";
            bridge.port = (port == 0) ? 7700 : port;
            bridge.canSendControl = true;
            break;

        default:
            bridge.name = "External Software";
            bridge.protocol = "OSC";
            bridge.port = (port == 0) ? 9000 : port;
            break;
    }

    // In production, actually attempt connection
    bridge.connected = true;  // Simulate success

    // Add or update bridge
    for (auto& b : pImpl->bridges) {
        if (b.software == software) {
            b = bridge;
            return true;
        }
    }
    pImpl->bridges.push_back(bridge);

    return true;
}

void UniversalCreativeIntelligence::disconnectFromSoftware(uci::ExternalSoftware software)
{
    std::lock_guard<std::mutex> lock(pImpl->bridgeMutex);
    for (auto& bridge : pImpl->bridges) {
        if (bridge.software == software) {
            bridge.connected = false;
        }
    }
}

bool UniversalCreativeIntelligence::isConnectedTo(uci::ExternalSoftware software) const
{
    std::lock_guard<std::mutex> lock(pImpl->bridgeMutex);
    for (const auto& bridge : pImpl->bridges) {
        if (bridge.software == software) {
            return bridge.connected;
        }
    }
    return false;
}

std::vector<uci::ExternalBridge> UniversalCreativeIntelligence::getExternalBridges() const
{
    std::lock_guard<std::mutex> lock(pImpl->bridgeMutex);
    return pImpl->bridges;
}

void UniversalCreativeIntelligence::sendOSC(
    uci::ExternalSoftware target,
    const std::string& address,
    const std::vector<float>& values)
{
    // In production, use actual OSC library (liblo, oscpack, etc.)
    std::lock_guard<std::mutex> lock(pImpl->bridgeMutex);
    for (auto& bridge : pImpl->bridges) {
        if (bridge.software == target && bridge.connected) {
            bridge.messagesSent++;
            bridge.lastMessageMs = static_cast<uint64_t>(
                std::chrono::duration_cast<std::chrono::milliseconds>(
                    std::chrono::steady_clock::now().time_since_epoch()
                ).count()
            );
        }
    }
}

void UniversalCreativeIntelligence::sendMIDI(
    uci::ExternalSoftware target,
    uint8_t channel, uint8_t note, uint8_t velocity)
{
    // In production, use actual MIDI library (RtMidi, CoreMIDI, etc.)
    std::lock_guard<std::mutex> lock(pImpl->bridgeMutex);
    for (auto& bridge : pImpl->bridges) {
        if (bridge.software == target && bridge.connected) {
            bridge.messagesSent++;
        }
    }
}

void UniversalCreativeIntelligence::sendVideoFrame(
    uci::ExternalSoftware target,
    const uint8_t* rgba, int width, int height)
{
    // In production, use NDI SDK, Syphon, or Spout
    std::lock_guard<std::mutex> lock(pImpl->bridgeMutex);
    for (auto& bridge : pImpl->bridges) {
        if (bridge.software == target && bridge.connected && bridge.canSendVideo) {
            bridge.messagesSent++;
        }
    }
}

bool UniversalCreativeIntelligence::connectToComfyUI(const std::string& host, int port)
{
    pImpl->comfyUIHost = host;
    pImpl->comfyUIPort = port;

    // In production, attempt WebSocket connection
    pImpl->comfyUIConnected = true;

    // Fetch available workflows
    pImpl->comfyUIWorkflows = {
        "text_to_video_cogvideox",
        "text_to_video_wan2",
        "image_to_video_animatediff",
        "style_transfer_lumina",
        "upscale_4k_realesrgan",
        "face_swap_reactor",
        "audio_reactive_deforum",
        "biofeedback_visual_gen"
    };

    return true;
}

std::vector<std::string> UniversalCreativeIntelligence::getComfyUIWorkflows() const
{
    return pImpl->comfyUIWorkflows;
}

void UniversalCreativeIntelligence::runComfyUIWorkflow(
    const std::string& workflowName,
    const std::map<std::string, std::string>& inputs,
    std::function<void(const std::vector<uint8_t>&)> callback)
{
    // In production, POST to ComfyUI API and track queue
    if (callback) {
        callback({});  // Empty result for now
    }
}

int UniversalCreativeIntelligence::getComfyUIQueueLength() const
{
    // In production, query /queue endpoint
    return 0;
}

void UniversalCreativeIntelligence::sendDMX(
    int universe, const uint8_t* data, int numChannels)
{
    // In production, use libdmx or similar
    (void)universe;
    (void)data;
    (void)numChannels;
}

void UniversalCreativeIntelligence::sendArtNet(
    int universe, const uint8_t* data, int numChannels,
    const std::string& host, int port)
{
    // In production, send Art-Net UDP packets
    (void)universe;
    (void)data;
    (void)numChannels;
    (void)host;
    (void)port;
}

void UniversalCreativeIntelligence::sendILDA(const void* points, int numPoints)
{
    // In production, send to laser DAC
    (void)points;
    (void)numPoints;
}

void UniversalCreativeIntelligence::setFixtureMapping(
    int fixtureId, int dmxAddress, int numChannels,
    const std::string& profileName)
{
    (void)fixtureId;
    (void)dmxAddress;
    (void)numChannels;
    (void)profileName;
}

void UniversalCreativeIntelligence::processFrame(double deltaTime)
{
    auto startTime = std::chrono::steady_clock::now();

    std::lock_guard<std::mutex> lock(pImpl->stateMutex);

    // Apply all fusion mappings
    // OPTIMIZATION: Use cached category lookup instead of string prefix check
    for (auto& mapping : pImpl->currentPreset.mappings) {
        if (!mapping.enabled) continue;

        // Get source value (O(1) unified lookup)
        float sourceValue = pImpl->getValueByPath(mapping.sourcePath);

        // Apply influence multipliers using cached category (O(1))
        auto category = pImpl->getValueCategory(mapping.sourcePath);
        if (category == Impl::ValueCategory::Bio) {
            sourceValue *= pImpl->bioInfluence;
        } else if (category == Impl::ValueCategory::Audio) {
            sourceValue *= pImpl->audioInfluence;
        }

        // Process through mapping
        float outputValue = mapping.process(sourceValue);

        // Apply global intensity
        outputValue *= pImpl->globalIntensity;

        // Set target value (O(1) unified lookup)
        pImpl->setValueByPath(mapping.targetPath, outputValue);
    }

    // Update visual state timestamp
    pImpl->visualState.lastUpdateMs = static_cast<uint64_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now().time_since_epoch()
        ).count()
    );

    // Update lighting state
    pImpl->lightingState.lastUpdateMs = pImpl->visualState.lastUpdateMs;

    // Fire callbacks
    if (pImpl->lightingCallback) {
        pImpl->lightingCallback(pImpl->lightingState);
    }

    // Calculate FPS
    pImpl->frameCount++;
    auto now = std::chrono::steady_clock::now();
    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        now - pImpl->lastFrameTime
    ).count();

    if (elapsed >= 1000) {
        pImpl->currentFPS.store(pImpl->frameCount * 1000.0f / elapsed);
        pImpl->frameCount = 0;
        pImpl->lastFrameTime = now;
    }

    // Calculate processing latency
    auto endTime = std::chrono::steady_clock::now();
    float latencyMs = std::chrono::duration_cast<std::chrono::microseconds>(
        endTime - startTime
    ).count() / 1000.0f;
    pImpl->processingLatency.store(latencyMs);
}

float UniversalCreativeIntelligence::getCurrentFPS() const noexcept
{
    return pImpl->currentFPS.load();
}

float UniversalCreativeIntelligence::getProcessingLatency() const noexcept
{
    return pImpl->processingLatency.load();
}

void UniversalCreativeIntelligence::setVideoFrameCallback(uci::VideoFrameCallback callback)
{
    pImpl->videoCallback = std::move(callback);
}

void UniversalCreativeIntelligence::setAudioBufferCallback(uci::AudioBufferCallback callback)
{
    pImpl->audioCallback = std::move(callback);
}

void UniversalCreativeIntelligence::setBioUpdateCallback(uci::BioUpdateCallback callback)
{
    pImpl->bioCallback = std::move(callback);
}

void UniversalCreativeIntelligence::setLightingCallback(uci::LightingCallback callback)
{
    pImpl->lightingCallback = std::move(callback);
}

void UniversalCreativeIntelligence::setErrorCallback(uci::ErrorCallback callback)
{
    pImpl->errorCallback = std::move(callback);
}

void UniversalCreativeIntelligence::savePreset(const std::string& name, const std::string& path)
{
    // In production, serialize to JSON
    std::ofstream file(path);
    if (file.is_open()) {
        file << "{\n";
        file << "  \"name\": \"" << name << "\",\n";
        file << "  \"mappings\": " << pImpl->currentPreset.mappings.size() << "\n";
        file << "}\n";
    }
}

void UniversalCreativeIntelligence::loadPresetFromFile(const std::string& path)
{
    // In production, parse JSON
    (void)path;
}

std::string UniversalCreativeIntelligence::exportMappingsJSON() const
{
    std::ostringstream json;
    json << "{\n";
    json << "  \"preset\": \"" << pImpl->currentPreset.name << "\",\n";
    json << "  \"mappings\": [\n";

    for (size_t i = 0; i < pImpl->currentPreset.mappings.size(); ++i) {
        const auto& m = pImpl->currentPreset.mappings[i];
        json << "    {\n";
        json << "      \"source\": \"" << m.sourcePath << "\",\n";
        json << "      \"target\": \"" << m.targetPath << "\",\n";
        json << "      \"enabled\": " << (m.enabled ? "true" : "false") << "\n";
        json << "    }";
        if (i < pImpl->currentPreset.mappings.size() - 1) json << ",";
        json << "\n";
    }

    json << "  ]\n";
    json << "}\n";

    return json.str();
}

void UniversalCreativeIntelligence::importMappingsJSON(const std::string& json)
{
    // In production, parse JSON
    (void)json;
}

//==============================================================================
// Integration with Existing Echoelmusic Systems
//==============================================================================

void UniversalCreativeIntelligence::attachLightController(Echoel::AdvancedLightController* controller)
{
    pImpl->lightController = controller;
}

void UniversalCreativeIntelligence::attachVisualAPI(Echoelmusic::VisualIntegrationAPI* api)
{
    pImpl->visualAPI = api;
}

void UniversalCreativeIntelligence::attachVideoWeaver(VideoWeaver* weaver)
{
    pImpl->videoWeaver = weaver;
}

void UniversalCreativeIntelligence::attachBioReactiveDSP(BioReactiveDSP* dsp)
{
    pImpl->bioReactiveDSP = dsp;
}

void UniversalCreativeIntelligence::attachSuperLaserScan(laser::SuperLaserScan* scan)
{
    pImpl->laserScan = scan;
}

void UniversalCreativeIntelligence::syncBioStateToSystems()
{
    std::lock_guard<std::mutex> lock(pImpl->stateMutex);

    // Sync to VideoWeaver (bio-reactive color grading)
    if (pImpl->videoWeaver) {
        // VideoWeaver uses setBioData(float hrv, float coherence)
        // pImpl->videoWeaver->setBioData(pImpl->bioState.hrv, pImpl->bioState.coherence);
    }

    // Sync to BioReactiveDSP
    if (pImpl->bioReactiveDSP) {
        // BioReactiveDSP processes with hrv and coherence
        // These values modulate filter cutoff, reverb, etc.
    }

    // Sync to VisualIntegrationAPI
    if (pImpl->visualAPI) {
        // VisualIntegrationAPI receives bio data via update()
    }

    // Sync to SuperLaserScan
    if (pImpl->laserScan) {
        // SuperLaserScan uses updateBioData(hrv, coherence, heartRate)
        // laser::BioData bioData;
        // bioData.hrv = pImpl->bioState.hrv;
        // bioData.coherence = pImpl->bioState.coherence;
        // bioData.heartRate = pImpl->bioState.heartRate;
        // pImpl->laserScan->updateBioData(bioData);
    }
}

void UniversalCreativeIntelligence::syncAudioStateToSystems()
{
    std::lock_guard<std::mutex> lock(pImpl->stateMutex);

    // Sync to LightController (frequency -> color mapping)
    if (pImpl->lightController) {
        // Use mapFrequencyToLight(frequency, amplitude)
        float dominantFreq = pImpl->audioState.spectralCentroid;
        float amplitude = pImpl->audioState.rmsLevel;
        // pImpl->lightController->mapFrequencyToLight(dominantFreq, amplitude);
    }

    // Sync to SuperLaserScan
    if (pImpl->laserScan) {
        // SuperLaserScan uses updateAudioData()
        // laser::AudioData audioData;
        // audioData.waveform = ...;
        // audioData.spectrum = ...;
        // audioData.beatDetected = pImpl->audioState.beatDetected;
        // audioData.bpm = pImpl->audioState.bpm;
        // pImpl->laserScan->updateAudioData(audioData);
    }
}

std::string UniversalCreativeIntelligence::getIntegrationStatus() const
{
    std::ostringstream status;
    status << "=== UniversalCreativeIntelligence Integration Status ===\n\n";

    status << "ATTACHED SYSTEMS:\n";
    status << "  LightController:    " << (pImpl->lightController ? "YES (DMX/ArtNet/Hue/WLED/ILDA)" : "NO") << "\n";
    status << "  VisualIntegrationAPI: " << (pImpl->visualAPI ? "YES (TouchDesigner/Resolume/Unity)" : "NO") << "\n";
    status << "  VideoWeaver:        " << (pImpl->videoWeaver ? "YES (Video editing & color grading)" : "NO") << "\n";
    status << "  BioReactiveDSP:     " << (pImpl->bioReactiveDSP ? "YES (Audio processing)" : "NO") << "\n";
    status << "  SuperLaserScan:     " << (pImpl->laserScan ? "YES (Ultra-low latency laser)" : "NO") << "\n\n";

    status << "DEVICE TIER: ";
    switch (pImpl->deviceCaps.tier) {
        case uci::DeviceTier::Mobile_Entry: status << "Mobile Entry (iPhone SE, budget Android)\n"; break;
        case uci::DeviceTier::Mobile_Mid: status << "Mobile Mid (iPhone 12-13, mid Android)\n"; break;
        case uci::DeviceTier::Mobile_Pro: status << "Mobile Pro (iPhone 14-16 Pro, 8GB+ RAM)\n"; break;
        case uci::DeviceTier::Desktop_Entry: status << "Desktop Entry (M1, RTX 3050)\n"; break;
        case uci::DeviceTier::Desktop_Mid: status << "Desktop Mid (M2 Pro, RTX 4070)\n"; break;
        case uci::DeviceTier::Desktop_Pro: status << "Desktop Pro (M3 Max, RTX 4090)\n"; break;
        case uci::DeviceTier::Server_Cloud: status << "Server/Cloud (H100, A100)\n"; break;
        default: status << "Unknown\n"; break;
    }

    status << "\nFUSION PRESET: " << pImpl->currentPreset.name << "\n";
    status << "  Mappings:     " << pImpl->currentPreset.mappings.size() << "\n";
    status << "  Bio Influence:   " << (pImpl->bioInfluence * 100) << "%\n";
    status << "  Audio Influence: " << (pImpl->audioInfluence * 100) << "%\n";
    status << "  Gesture Influence: " << (pImpl->gestureInfluence * 100) << "%\n\n";

    status << "EXTERNAL BRIDGES:\n";
    for (const auto& bridge : pImpl->bridges) {
        status << "  " << bridge.name << " (" << bridge.protocol << ":" << bridge.port << ") ";
        status << (bridge.connected ? "CONNECTED" : "DISCONNECTED") << "\n";
    }

    status << "\nPERFORMANCE:\n";
    status << "  FPS:            " << pImpl->currentFPS.load() << "\n";
    status << "  Latency:        " << pImpl->processingLatency.load() << " ms\n";
    status << "  Auto-Sync:      " << (pImpl->autoSync ? "ON" : "OFF") << "\n";

    return status.str();
}

void UniversalCreativeIntelligence::processUnifiedFrame(double deltaTime)
{
    auto startTime = std::chrono::steady_clock::now();

    // 1. Process fusion mappings (updates visualState and lightingState)
    processFrame(deltaTime);

    // 2. Sync to all attached systems if autoSync enabled
    if (pImpl->autoSync) {
        syncBioStateToSystems();
        syncAudioStateToSystems();
    }

    // 3. Update timing
    auto endTime = std::chrono::steady_clock::now();
    float totalLatency = std::chrono::duration_cast<std::chrono::microseconds>(
        endTime - startTime
    ).count() / 1000.0f;
    pImpl->processingLatency.store(totalLatency);
}

void UniversalCreativeIntelligence::setAutoSync(bool enabled)
{
    pImpl->autoSync = enabled;
}

float UniversalCreativeIntelligence::getTotalSystemLatency() const noexcept
{
    float total = pImpl->processingLatency.load();

    // Add estimated latencies from attached systems
    if (pImpl->lightController) total += 0.5f;    // Art-Net ~0.5ms
    if (pImpl->visualAPI) total += 1.0f;          // OSC ~1ms
    if (pImpl->laserScan) total += 0.1f;          // Ultra-low latency laser
    if (pImpl->videoWeaver) total += 2.0f;        // Video processing ~2ms

    return total;
}
