#pragma once

#include <JuceHeader.h>
#include <map>
#include <functional>

namespace Echoel {
namespace Platform {

//==============================================================================
/**
 * @brief Universal Console & XR Platform Layer
 *
 * ULTRATHINK QUANTUM SCIENCE DEVELOPER MODE
 *
 * Unterstützte Plattformen:
 * 🎮 KONSOLEN: PlayStation, Xbox, Nintendo Switch, Steam Deck
 * 🥽 XR/VR: Meta Quest, Apple Vision Pro, PlayStation VR, Valve Index
 * ⌚ WEARABLES: Apple Watch, Galaxy Watch, Fitbit, Oura, Whoop
 * 📱 SMART: Smart TVs, Smart Speakers, IoT Devices
 *
 * ARCHITEKTUR:
 * - Platform Abstraction Layer (PAL)
 * - Unified Input System (UIS)
 * - Adaptive Rendering Pipeline (ARP)
 * - Cross-Platform Audio Engine (CPAE)
 */

//==============================================================================
/**
 * @brief Platform Types
 */
enum class PlatformType
{
    // Desktop
    Windows,
    macOS,
    Linux,

    // Mobile
    iOS,
    Android,

    // Konsolen
    PlayStation4,
    PlayStation5,
    XboxOne,
    XboxSeriesX,
    NintendoSwitch,
    SteamDeck,

    // XR/VR
    MetaQuest2,
    MetaQuest3,
    MetaQuestPro,
    AppleVisionPro,
    PlayStationVR2,
    ValveIndex,
    HTCVive,
    PicoNeo,

    // Wearables
    AppleWatch,
    WearOS,
    Fitbit,
    OuraRing,
    Whoop,

    // Smart Devices
    SmartTV,
    SmartSpeaker,
    RaspberryPi,

    Unknown
};

//==============================================================================
/**
 * @brief Controller/Input Types
 */
enum class ControllerType
{
    None,

    // Standard Gamepads
    DualSense,           // PS5
    DualShock4,          // PS4
    XboxWireless,        // Xbox Series
    XboxOne,
    SwitchProController,
    JoyCon,
    SteamController,

    // XR Controllers
    QuestTouch,
    QuestTouchPro,
    VisionProHands,      // Hand Tracking
    IndexKnuckles,
    ViveWand,
    PSVR2Sense,

    // Alternative
    Keyboard,
    Mouse,
    TouchScreen,
    MIDIController,
    OSCDevice,

    // Accessibility
    AdaptiveController,  // Xbox Adaptive
    EyeTracker,
    VoiceControl,
    BrainInterface       // Future-ready
};

//==============================================================================
/**
 * @brief Unified Input State
 */
struct UnifiedInputState
{
    // Analog Sticks
    float leftStickX = 0.0f;
    float leftStickY = 0.0f;
    float rightStickX = 0.0f;
    float rightStickY = 0.0f;

    // Triggers
    float leftTrigger = 0.0f;
    float rightTrigger = 0.0f;

    // Buttons (platform-agnostic naming)
    bool actionSouth = false;    // A/Cross/B(Nintendo)
    bool actionEast = false;     // B/Circle/A(Nintendo)
    bool actionWest = false;     // X/Square/Y(Nintendo)
    bool actionNorth = false;    // Y/Triangle/X(Nintendo)

    bool shoulderLeft = false;   // L1/LB/L
    bool shoulderRight = false;  // R1/RB/R
    bool triggerLeft = false;    // L2/LT/ZL
    bool triggerRight = false;   // R2/RT/ZR

    bool stickLeft = false;      // L3/LS
    bool stickRight = false;     // R3/RS

    bool dpadUp = false;
    bool dpadDown = false;
    bool dpadLeft = false;
    bool dpadRight = false;

    bool start = false;          // Options/Menu/+
    bool select = false;         // Share/View/-

    bool home = false;           // PS/Xbox/Home
    bool touchpadPress = false;  // PS Touchpad

    // DualSense/Advanced Features
    float touchpadX = 0.0f;
    float touchpadY = 0.0f;
    bool touchpadActive = false;

    // Motion
    float gyroX = 0.0f;
    float gyroY = 0.0f;
    float gyroZ = 0.0f;
    float accelX = 0.0f;
    float accelY = 0.0f;
    float accelZ = 0.0f;

    // XR Specific
    struct XRController
    {
        float positionX = 0.0f;
        float positionY = 0.0f;
        float positionZ = 0.0f;
        float rotationX = 0.0f;
        float rotationY = 0.0f;
        float rotationZ = 0.0f;
        float rotationW = 1.0f;
        float grip = 0.0f;
        float trigger = 0.0f;
        bool primaryButton = false;
        bool secondaryButton = false;
        bool thumbstickPress = false;
    };

    XRController leftHand;
    XRController rightHand;

    // Hand Tracking (Vision Pro, Quest)
    struct HandTracking
    {
        bool isTracked = false;
        float pinchStrength = 0.0f;     // Thumb + Index
        float grabStrength = 0.0f;      // Full fist
        float pointStrength = 0.0f;     // Index pointing
        bool isPinching = false;
        bool isGrabbing = false;
        bool isPointing = false;
    };

    HandTracking leftHandTracking;
    HandTracking rightHandTracking;

    // Eye Tracking (Vision Pro, Quest Pro, PSVR2)
    struct EyeTracking
    {
        bool isTracked = false;
        float gazeX = 0.0f;
        float gazeY = 0.0f;
        float gazeZ = 0.0f;
        float leftPupilDilation = 0.0f;
        float rightPupilDilation = 0.0f;
        bool isBlinking = false;
    };

    EyeTracking eyes;
};

//==============================================================================
/**
 * @brief Haptic Feedback System
 */
class HapticFeedbackSystem
{
public:
    enum class HapticType
    {
        None,
        Light,
        Medium,
        Heavy,
        Success,
        Warning,
        Error,
        Selection,
        ImpactLight,
        ImpactMedium,
        ImpactHeavy,
        RigidityLow,
        RigidityMedium,
        RigidityHigh
    };

    struct HapticWaveform
    {
        std::vector<float> amplitudes;  // 0-1
        std::vector<float> frequencies; // Hz
        std::vector<float> durations;   // ms
    };

    static HapticFeedbackSystem& getInstance()
    {
        static HapticFeedbackSystem instance;
        return instance;
    }

    void triggerHaptic(HapticType type, ControllerType controller = ControllerType::None)
    {
        // Platform-specific haptic implementation
        switch (controller)
        {
            case ControllerType::DualSense:
                triggerDualSenseHaptic(type);
                break;
            case ControllerType::QuestTouch:
            case ControllerType::QuestTouchPro:
                triggerQuestHaptic(type);
                break;
            case ControllerType::IndexKnuckles:
                triggerIndexHaptic(type);
                break;
            default:
                triggerGenericHaptic(type);
                break;
        }
    }

    // DualSense Adaptive Triggers
    void setAdaptiveTrigger(bool isLeft, float resistance, float startPosition = 0.0f)
    {
        // PS5 DualSense specific
        adaptiveTriggerResistance[isLeft ? 0 : 1] = resistance;
        adaptiveTriggerStart[isLeft ? 0 : 1] = startPosition;
    }

    // Custom waveform for advanced controllers
    void playCustomWaveform(const HapticWaveform& waveform)
    {
        customWaveform = waveform;
        // Implementation would send to hardware
    }

private:
    void triggerDualSenseHaptic(HapticType type)
    {
        // DualSense HD Haptics
    }

    void triggerQuestHaptic(HapticType type)
    {
        // Quest Touch Controllers
    }

    void triggerIndexHaptic(HapticType type)
    {
        // Valve Index Knuckles
    }

    void triggerGenericHaptic(HapticType type)
    {
        // Generic rumble
    }

    float adaptiveTriggerResistance[2] = { 0.0f, 0.0f };
    float adaptiveTriggerStart[2] = { 0.0f, 0.0f };
    HapticWaveform customWaveform;
};

//==============================================================================
/**
 * @brief XR/VR Integration Layer
 */
class XRIntegrationLayer
{
public:
    struct XRCapabilities
    {
        bool hasPositionalTracking = false;
        bool hasHandTracking = false;
        bool hasEyeTracking = false;
        bool hasFaceTracking = false;
        bool hasPassthrough = false;
        bool hasSpatialAudio = false;
        bool hasHaptics = false;
        bool hasAdaptiveResolution = false;
        int maxRefreshRate = 72;
        float fieldOfView = 100.0f;
        float ipd = 63.0f;  // Interpupillary distance
    };

    struct XRFrame
    {
        // Head pose
        float headPosX = 0.0f;
        float headPosY = 0.0f;
        float headPosZ = 0.0f;
        float headRotX = 0.0f;
        float headRotY = 0.0f;
        float headRotZ = 0.0f;
        float headRotW = 1.0f;

        // View matrices (per eye)
        float leftViewMatrix[16];
        float rightViewMatrix[16];
        float leftProjectionMatrix[16];
        float rightProjectionMatrix[16];

        // Timing
        double predictedDisplayTime = 0.0;
        int frameIndex = 0;
    };

    static XRIntegrationLayer& getInstance()
    {
        static XRIntegrationLayer instance;
        return instance;
    }

    bool initialize(PlatformType platform)
    {
        xrPlatform = platform;

        switch (platform)
        {
            case PlatformType::MetaQuest2:
            case PlatformType::MetaQuest3:
            case PlatformType::MetaQuestPro:
                return initializeOpenXR();

            case PlatformType::AppleVisionPro:
                return initializeVisionOS();

            case PlatformType::PlayStationVR2:
                return initializePSVR2();

            case PlatformType::ValveIndex:
            case PlatformType::HTCVive:
                return initializeOpenVR();

            default:
                return false;
        }
    }

    XRCapabilities getCapabilities() const { return capabilities; }

    void beginFrame(XRFrame& frame)
    {
        // Wait for optimal rendering time
        // Get predicted head pose
    }

    void endFrame()
    {
        // Submit rendered frames to HMD
    }

    // Passthrough AR
    void setPassthroughEnabled(bool enabled)
    {
        passthroughEnabled = enabled;
    }

    void setPassthroughOpacity(float opacity)
    {
        passthroughOpacity = juce::jlimit(0.0f, 1.0f, opacity);
    }

    // Spatial Anchors
    struct SpatialAnchor
    {
        juce::String id;
        float posX, posY, posZ;
        float rotX, rotY, rotZ, rotW;
        bool isPersistent;
    };

    bool createSpatialAnchor(const juce::String& id, float x, float y, float z)
    {
        SpatialAnchor anchor;
        anchor.id = id;
        anchor.posX = x;
        anchor.posY = y;
        anchor.posZ = z;
        anchor.isPersistent = false;
        spatialAnchors[id] = anchor;
        return true;
    }

private:
    bool initializeOpenXR()
    {
        capabilities.hasPositionalTracking = true;
        capabilities.hasHandTracking = true;
        capabilities.hasPassthrough = true;
        capabilities.hasSpatialAudio = true;
        capabilities.hasHaptics = true;
        capabilities.maxRefreshRate = 120;
        return true;
    }

    bool initializeVisionOS()
    {
        capabilities.hasPositionalTracking = true;
        capabilities.hasHandTracking = true;
        capabilities.hasEyeTracking = true;
        capabilities.hasFaceTracking = true;
        capabilities.hasPassthrough = true;
        capabilities.hasSpatialAudio = true;
        capabilities.fieldOfView = 120.0f;
        return true;
    }

    bool initializePSVR2()
    {
        capabilities.hasPositionalTracking = true;
        capabilities.hasEyeTracking = true;
        capabilities.hasHaptics = true;
        capabilities.maxRefreshRate = 120;
        capabilities.hasAdaptiveResolution = true;
        return true;
    }

    bool initializeOpenVR()
    {
        capabilities.hasPositionalTracking = true;
        capabilities.hasHaptics = true;
        capabilities.maxRefreshRate = 144;
        return true;
    }

    PlatformType xrPlatform = PlatformType::Unknown;
    XRCapabilities capabilities;
    bool passthroughEnabled = false;
    float passthroughOpacity = 1.0f;
    std::map<juce::String, SpatialAnchor> spatialAnchors;
};

//==============================================================================
/**
 * @brief Wearable Device Integration
 */
class WearableIntegration
{
public:
    struct BiometricData
    {
        // Heart
        float heartRate = 0.0f;
        float heartRateVariability = 0.0f;
        float restingHeartRate = 0.0f;

        // Activity
        int steps = 0;
        float caloriesBurned = 0.0f;
        float distanceKm = 0.0f;
        int floorsClimbed = 0;

        // Sleep
        float sleepHours = 0.0f;
        float deepSleepHours = 0.0f;
        float remSleepHours = 0.0f;
        int sleepScore = 0;

        // Stress & Recovery
        float stressLevel = 0.0f;
        float recoveryScore = 0.0f;
        float bodyBattery = 0.0f;

        // Blood Oxygen
        float spo2 = 0.0f;

        // Temperature
        float skinTemperature = 0.0f;
        float bodyTemperatureDeviation = 0.0f;

        // Advanced (Oura, Whoop)
        float readinessScore = 0.0f;
        float strainScore = 0.0f;
        float respiratoryRate = 0.0f;
    };

    static WearableIntegration& getInstance()
    {
        static WearableIntegration instance;
        return instance;
    }

    bool connectDevice(PlatformType device)
    {
        connectedDevice = device;

        switch (device)
        {
            case PlatformType::AppleWatch:
                return connectAppleWatch();
            case PlatformType::WearOS:
                return connectWearOS();
            case PlatformType::Fitbit:
                return connectFitbit();
            case PlatformType::OuraRing:
                return connectOura();
            case PlatformType::Whoop:
                return connectWhoop();
            default:
                return false;
        }
    }

    BiometricData getLatestBiometrics() const { return biometrics; }

    // Real-time heart rate streaming
    void setHeartRateCallback(std::function<void(float)> callback)
    {
        heartRateCallback = std::move(callback);
    }

    // Use biometrics for app features
    void applyBiometricsToApp()
    {
        // Adjust UI based on stress level
        // Modify audio based on heart rate
        // Suggest breaks based on recovery
    }

private:
    bool connectAppleWatch()
    {
        // HealthKit integration
        return true;
    }

    bool connectWearOS()
    {
        // Health Connect API
        return true;
    }

    bool connectFitbit()
    {
        // Fitbit Web API
        return true;
    }

    bool connectOura()
    {
        // Oura Cloud API
        return true;
    }

    bool connectWhoop()
    {
        // Whoop API
        return true;
    }

    PlatformType connectedDevice = PlatformType::Unknown;
    BiometricData biometrics;
    std::function<void(float)> heartRateCallback;
};

//==============================================================================
/**
 * @brief Console-Specific Optimizations
 */
class ConsoleOptimizer
{
public:
    struct ConsoleCapabilities
    {
        // CPU
        int cpuCores = 8;
        float cpuFrequencyGHz = 3.5f;
        bool hasSMT = true;

        // GPU
        float gpuTeraflops = 10.0f;
        bool hasRayTracing = false;
        bool hasVRS = false;  // Variable Rate Shading
        bool hasMeshShaders = false;

        // Memory
        int ramGB = 16;
        int vramGB = 16;
        bool hasUnifiedMemory = true;
        float memoryBandwidthGBs = 448.0f;

        // Storage
        bool hasSSD = true;
        float ssdSpeedGBs = 5.5f;

        // Audio
        bool has3DAudio = true;
        int audioChannels = 512;

        // Features
        bool hasHaptics = false;
        bool hasAdaptiveTriggers = false;
        bool hasTouchpad = false;
        bool hasGyro = true;
    };

    static ConsoleOptimizer& getInstance()
    {
        static ConsoleOptimizer instance;
        return instance;
    }

    ConsoleCapabilities getCapabilities(PlatformType console)
    {
        ConsoleCapabilities caps;

        switch (console)
        {
            case PlatformType::PlayStation5:
                caps.cpuCores = 8;
                caps.cpuFrequencyGHz = 3.5f;
                caps.gpuTeraflops = 10.28f;
                caps.hasRayTracing = true;
                caps.ramGB = 16;
                caps.memoryBandwidthGBs = 448.0f;
                caps.hasSSD = true;
                caps.ssdSpeedGBs = 5.5f;
                caps.has3DAudio = true;  // Tempest 3D AudioTech
                caps.hasHaptics = true;
                caps.hasAdaptiveTriggers = true;
                caps.hasTouchpad = true;
                break;

            case PlatformType::XboxSeriesX:
                caps.cpuCores = 8;
                caps.cpuFrequencyGHz = 3.8f;
                caps.gpuTeraflops = 12.0f;
                caps.hasRayTracing = true;
                caps.hasVRS = true;
                caps.hasMeshShaders = true;
                caps.ramGB = 16;
                caps.memoryBandwidthGBs = 560.0f;
                caps.hasSSD = true;
                caps.ssdSpeedGBs = 2.4f;
                caps.has3DAudio = true;  // Spatial Sound
                break;

            case PlatformType::NintendoSwitch:
                caps.cpuCores = 4;
                caps.cpuFrequencyGHz = 1.02f;
                caps.gpuTeraflops = 0.4f;
                caps.hasRayTracing = false;
                caps.ramGB = 4;
                caps.hasSSD = false;
                caps.has3DAudio = false;
                caps.hasGyro = true;
                break;

            case PlatformType::SteamDeck:
                caps.cpuCores = 4;
                caps.cpuFrequencyGHz = 3.5f;
                caps.gpuTeraflops = 1.6f;
                caps.hasRayTracing = false;
                caps.ramGB = 16;
                caps.hasSSD = true;
                caps.has3DAudio = false;
                caps.hasGyro = true;
                caps.hasTouchpad = true;
                break;

            default:
                break;
        }

        return caps;
    }

    // Audio buffer size optimization per platform
    int getOptimalBufferSize(PlatformType console)
    {
        switch (console)
        {
            case PlatformType::PlayStation5:
                return 256;  // Low latency with Tempest
            case PlatformType::XboxSeriesX:
                return 256;
            case PlatformType::NintendoSwitch:
                return 512;  // More headroom needed
            case PlatformType::SteamDeck:
                return 256;
            default:
                return 512;
        }
    }

    // Thread allocation per platform
    int getAudioThreadCount(PlatformType console)
    {
        auto caps = getCapabilities(console);
        return juce::jmax(1, caps.cpuCores / 4);
    }
};

//==============================================================================
/**
 * @brief Universal Platform Manager
 */
class UniversalPlatformManager
{
public:
    static UniversalPlatformManager& getInstance()
    {
        static UniversalPlatformManager instance;
        return instance;
    }

    PlatformType detectPlatform()
    {
        #if defined(__PROSPERO__)  // PS5
            return PlatformType::PlayStation5;
        #elif defined(__ORBIS__)   // PS4
            return PlatformType::PlayStation4;
        #elif defined(_GAMING_XBOX_SCARLETT)
            return PlatformType::XboxSeriesX;
        #elif defined(_GAMING_XBOX)
            return PlatformType::XboxOne;
        #elif defined(__SWITCH__)
            return PlatformType::NintendoSwitch;
        #elif JUCE_IOS
            return PlatformType::iOS;
        #elif JUCE_ANDROID
            return PlatformType::Android;
        #elif JUCE_MAC
            return PlatformType::macOS;
        #elif JUCE_WINDOWS
            return PlatformType::Windows;
        #elif JUCE_LINUX
            return PlatformType::Linux;
        #else
            return PlatformType::Unknown;
        #endif
    }

    void initialize()
    {
        currentPlatform = detectPlatform();

        // Initialize subsystems
        auto& haptics = HapticFeedbackSystem::getInstance();
        auto& console = ConsoleOptimizer::getInstance();

        // Auto-configure based on platform
        autoConfigureForPlatform();
    }

    PlatformType getCurrentPlatform() const { return currentPlatform; }

    // Input polling
    UnifiedInputState pollInput()
    {
        UnifiedInputState state;

        // Platform-specific input polling would go here
        // This is the unified interface all game code uses

        return state;
    }

    // Controller mapping
    void setControllerMapping(const std::map<juce::String, juce::String>& mapping)
    {
        controllerMapping = mapping;
    }

private:
    void autoConfigureForPlatform()
    {
        auto& console = ConsoleOptimizer::getInstance();
        auto caps = console.getCapabilities(currentPlatform);

        // Adjust audio settings
        optimalBufferSize = console.getOptimalBufferSize(currentPlatform);
        audioThreads = console.getAudioThreadCount(currentPlatform);

        // Adjust visual settings based on GPU power
        if (caps.gpuTeraflops < 1.0f)
        {
            visualQuality = 0;  // Low
        }
        else if (caps.gpuTeraflops < 5.0f)
        {
            visualQuality = 1;  // Medium
        }
        else
        {
            visualQuality = 2;  // High
        }
    }

    PlatformType currentPlatform = PlatformType::Unknown;
    std::map<juce::String, juce::String> controllerMapping;
    int optimalBufferSize = 512;
    int audioThreads = 2;
    int visualQuality = 1;
};

} // namespace Platform
} // namespace Echoel
