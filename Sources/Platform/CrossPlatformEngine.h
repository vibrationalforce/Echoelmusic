#pragma once

#include <JuceHeader.h>

/**
 * CrossPlatformEngine - Universal Platform Compatibility
 *
 * SUPPORTED PLATFORMS:
 * - Mobile: iOS (iPhone, iPad), Android (Phone, Tablet)
 * - Desktop: Windows, macOS, Linux
 * - Wearable: Apple Watch, Android Wear, Fitbit, etc.
 * - Embedded: Raspberry Pi, embedded ARM devices
 * - Web: WebAssembly, Progressive Web Apps
 * - Future: AR/VR headsets, Smart glasses, IoT devices
 *
 * ADAPTIVE FEATURES:
 * - Screen size adaptation (tiny watch to large desktop)
 * - Touch/Mouse/Gesture/Voice input
 * - Battery optimization for mobile
 * - Low-power mode for wearables
 * - Offline-first operation
 * - Cloud sync across devices
 *
 * Usage:
 * ```cpp
 * CrossPlatformEngine engine;
 *
 * // Auto-detect platform
 * auto platform = engine.getPlatformInfo();
 *
 * // Adapt UI
 * if (platform.isWearable)
 *     engine.setUIMode(UIMode::Minimal);
 * else if (platform.isMobile)
 *     engine.setUIMode(UIMode::Touch);
 * else
 *     engine.setUIMode(UIMode::Desktop);
 *
 * // Battery optimization
 * if (platform.batteryPowered)
 *     engine.enablePowerSavingMode(true);
 * ```
 */

//==============================================================================
// Platform Types
//==============================================================================

enum class PlatformType
{
    // Mobile
    iOS_Phone,
    iOS_Tablet,
    Android_Phone,
    Android_Tablet,

    // Desktop
    Windows,
    macOS,
    Linux,

    // Wearable
    AppleWatch,
    AndroidWear,
    Fitbit,
    GarminWatch,
    SamsungGalaxyWatch,

    // Embedded
    RaspberryPi,
    EmbeddedARM,
    EmbeddedLinux,

    // Web
    WebAssembly,
    ProgressiveWebApp,

    // Future
    ARHeadset,
    VRHeadset,
    SmartGlasses,
    IoTDevice,
    AutomotiveSystem,

    Unknown
};

enum class DeviceClass
{
    Mobile,
    Tablet,
    Desktop,
    Wearable,
    Embedded,
    Web,
    AR_VR,
    IoT,
    Unknown
};

enum class InputMethod
{
    Touch,              // Touchscreen
    Mouse,              // Mouse/Trackpad
    Keyboard,           // Physical keyboard
    Voice,              // Voice control
    Gesture,            // Hand gestures, motion
    DigitalCrown,       // Apple Watch crown
    Stylus,             // Apple Pencil, S Pen
    Controller,         // Game controller
    Remote,             // Remote control
    BrainInterface,     // Future: Brain-computer interface
    Unknown
};

enum class UIMode
{
    Desktop,            // Full desktop interface
    Touch,              // Touch-optimized mobile
    Minimal,            // Wearable minimal UI
    Voice,              // Voice-only interface
    AR,                 // Augmented Reality
    VR,                 // Virtual Reality
    Adaptive            // Auto-adapt
};

//==============================================================================
// Platform Information
//==============================================================================

struct PlatformInfo
{
    PlatformType type = PlatformType::Unknown;
    DeviceClass deviceClass = DeviceClass::Unknown;
    juce::String platformName;
    juce::String osVersion;
    juce::String deviceModel;

    // Screen
    int screenWidth = 0;
    int screenHeight = 0;
    float screenDPI = 96.0f;
    float screenScale = 1.0f;       // Retina, etc.
    bool touchScreen = false;

    // Capabilities
    bool hasKeyboard = false;
    bool hasMouse = false;
    bool hasStylus = false;
    bool hasVoiceInput = false;
    bool hasGPS = false;
    bool hasAccelerometer = false;
    bool hasGyroscope = false;
    bool hasCamera = false;
    bool hasMicrophone = false;

    // Power
    bool batteryPowered = false;
    int batteryPercent = 100;
    bool isCharging = false;
    float estimatedBatteryLifeHours = 0.0f;

    // Performance
    int cpuCores = 1;
    int64_t ramBytes = 0;
    int64_t storageBytes = 0;
    bool hasGPU = false;
    juce::String gpuModel;

    // Network
    bool hasWiFi = false;
    bool hasCellular = false;
    bool hasBluetooth = false;
    bool hasNFC = false;
    bool isOnline = false;

    // Platform-specific
    bool isSimulator = false;
    bool isJailbroken = false;
    bool isDevelopmentBuild = false;

    // Helper methods
    bool isMobile() const
    {
        return deviceClass == DeviceClass::Mobile ||
               deviceClass == DeviceClass::Tablet;
    }

    bool isDesktop() const
    {
        return deviceClass == DeviceClass::Desktop;
    }

    bool isWearable() const
    {
        return deviceClass == DeviceClass::Wearable;
    }

    bool isEmbedded() const
    {
        return deviceClass == DeviceClass::Embedded;
    }

    bool isWeb() const
    {
        return deviceClass == DeviceClass::Web;
    }

    bool isAR_VR() const
    {
        return deviceClass == DeviceClass::AR_VR;
    }

    bool needsPowerOptimization() const
    {
        return batteryPowered && batteryPercent < 20;
    }

    bool hasLimitedResources() const
    {
        return isWearable() || isEmbedded() || (ramBytes < 2LL * 1024 * 1024 * 1024);
    }

    juce::String getDescription() const;
};

//==============================================================================
// Performance Profile
//==============================================================================

struct PerformanceProfile
{
    enum class Quality
    {
        Ultra,          // Desktop workstation
        High,           // Modern mobile, good desktop
        Medium,         // Older mobile, embedded
        Low,            // Wearable, very limited
        PowerSaving     // Battery critical
    };

    Quality quality = Quality::High;

    // Audio
    int maxAudioTracks = 64;
    int maxVST3Plugins = 32;
    int audioBufferSize = 512;
    double audioSampleRate = 48000.0;

    // UI
    int uiRefreshRateHz = 60;
    bool enableAnimations = true;
    bool enableShadows = true;
    bool enableBlur = true;

    // Processing
    bool enableMultithreading = true;
    int maxThreads = 8;
    bool enableGPUAcceleration = false;

    // Features
    bool enableCloudSync = true;
    bool enableOfflineMode = true;
    bool enableAutoSave = true;
    int autoSaveIntervalSeconds = 300;

    static PerformanceProfile forPlatform(const PlatformInfo& platform);
};

//==============================================================================
// Adaptive UI Configuration
//==============================================================================

struct AdaptiveUIConfig
{
    UIMode mode = UIMode::Adaptive;

    // Layout
    int minTouchTargetSize = 44;   // iOS HIG recommendation
    int spacing = 8;
    int margins = 16;
    bool compactMode = false;

    // Typography
    float baseFontSize = 14.0f;
    bool useDynamicType = true;     // Respect system font size

    // Gestures
    bool enableSwipeGestures = true;
    bool enablePinchZoom = true;
    bool enableDoubleTap = true;
    bool enableLongPress = true;

    // Accessibility
    bool highContrastMode = false;
    bool largeTextMode = false;
    bool reduceMotion = false;
    bool enableVoiceOver = false;

    // Platform-specific
    bool useNativeControls = true;
    bool respectSystemTheme = true;  // Dark/Light mode

    static AdaptiveUIConfig forPlatform(const PlatformInfo& platform);
};

//==============================================================================
// CrossPlatformEngine - Main Class
//==============================================================================

class CrossPlatformEngine
{
public:
    CrossPlatformEngine();
    ~CrossPlatformEngine();

    //==========================================================================
    // Platform Detection
    //==========================================================================

    /** Get current platform information */
    PlatformInfo getPlatformInfo() const;

    /** Detect platform capabilities */
    void detectCapabilities();

    /** Check if running on specific platform */
    bool isRunningOn(PlatformType type) const;
    bool isRunningOn(DeviceClass deviceClass) const;

    //==========================================================================
    // UI Adaptation
    //==========================================================================

    /** Set UI mode */
    void setUIMode(UIMode mode);

    /** Get current UI mode */
    UIMode getUIMode() const;

    /** Get adaptive UI configuration */
    AdaptiveUIConfig getUIConfig() const;

    /** Get recommended UI scale factor */
    float getUIScaleFactor() const;

    /** Check if should use compact UI */
    bool shouldUseCompactUI() const;

    //==========================================================================
    // Performance Optimization
    //==========================================================================

    /** Get performance profile */
    PerformanceProfile getPerformanceProfile() const;

    /** Set performance quality */
    void setPerformanceQuality(PerformanceProfile::Quality quality);

    /** Enable power saving mode */
    void enablePowerSavingMode(bool enable);

    /** Is power saving active? */
    bool isPowerSavingActive() const;

    /** Optimize for current battery level */
    void optimizeForBattery();

    //==========================================================================
    // Input Handling
    //==========================================================================

    /** Get available input methods */
    juce::Array<InputMethod> getAvailableInputMethods() const;

    /** Set primary input method */
    void setPrimaryInputMethod(InputMethod method);

    /** Get current input method */
    InputMethod getCurrentInputMethod() const;

    /** Enable gesture recognition */
    void enableGestures(bool enable);

    /** Enable voice control */
    void enableVoiceControl(bool enable);

    //==========================================================================
    // Platform-Specific Features
    //==========================================================================

    /** Enable mobile-specific features */
    void enableMobileFeatures(bool enable);

    /** Enable wearable-specific features */
    void enableWearableFeatures(bool enable);

    /** Enable desktop-specific features */
    void enableDesktopFeatures(bool enable);

    /** Enable AR/VR features */
    void enableAR_VRFeatures(bool enable);

    //==========================================================================
    // Responsive Layout
    //==========================================================================

    /** Get recommended layout for current screen */
    juce::String getRecommendedLayout() const;

    /** Should show sidebar? */
    bool shouldShowSidebar() const;

    /** Should show toolbar? */
    bool shouldShowToolbar() const;

    /** Get maximum visible tracks */
    int getMaxVisibleTracks() const;

    /** Get compact mode threshold */
    int getCompactModeThreshold() const;

    //==========================================================================
    // Cross-Platform Sync
    //==========================================================================

    /** Enable cloud sync */
    void enableCloudSync(bool enable);

    /** Sync project across devices */
    bool syncProject(const juce::String& projectID);

    /** Get sync status */
    juce::String getSyncStatus() const;

    //==========================================================================
    // Offline Support
    //==========================================================================

    /** Enable offline mode */
    void enableOfflineMode(bool enable);

    /** Is offline mode active? */
    bool isOfflineMode() const;

    /** Cache data for offline use */
    void cacheDataForOffline();

    /** Clear offline cache */
    void clearOfflineCache();

    //==========================================================================
    // Platform Lifecycle
    //==========================================================================

    /** Handle app entering background */
    void onAppEnterBackground();

    /** Handle app entering foreground */
    void onAppEnterForeground();

    /** Handle low memory warning */
    void onLowMemoryWarning();

    /** Handle battery level change */
    void onBatteryLevelChange(int percent);

    /** Handle network status change */
    void onNetworkStatusChange(bool online);

    //==========================================================================
    // Future Platform Support
    //==========================================================================

    /** Prepare for AR mode */
    void prepareARMode();

    /** Prepare for VR mode */
    void prepareVRMode();

    /** Enable spatial audio for AR/VR */
    void enableSpatialAudio(bool enable);

    /** Handle AR/VR controller input */
    void handleVRControllerInput();

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(const PlatformInfo& info)> onPlatformDetected;
    std::function<void(UIMode mode)> onUIModeChanged;
    std::function<void(bool powerSaving)> onPowerSavingChanged;
    std::function<void(int batteryPercent)> onBatteryChanged;
    std::function<void(bool online)> onNetworkChanged;
    std::function<void()> onLowMemory;

private:
    PlatformInfo platformInfo;
    PerformanceProfile performanceProfile;
    AdaptiveUIConfig uiConfig;

    UIMode currentUIMode = UIMode::Adaptive;
    InputMethod currentInputMethod = InputMethod::Unknown;

    bool powerSavingMode = false;
    bool cloudSyncEnabled = false;
    bool offlineMode = false;
    bool gesturesEnabled = true;
    bool voiceControlEnabled = false;

    void detectPlatform();
    void detectScreen();
    void detectInput();
    void detectSensors();
    void detectNetwork();
    void detectBattery();

    void applyPlatformOptimizations();
    void configureForMobile();
    void configureForDesktop();
    void configureForWearable();
    void configureForWeb();
    void configureForAR_VR();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CrossPlatformEngine)
};
