#include "CrossPlatformEngine.h"

//==============================================================================
// PlatformInfo Implementation
//==============================================================================

juce::String PlatformInfo::getDescription() const
{
    juce::String desc;
    desc << "Platform: " << platformName << "\n";
    desc << "OS Version: " << osVersion << "\n";
    desc << "Device: " << deviceModel << "\n";
    desc << "Screen: " << screenWidth << "x" << screenHeight << " @ " << screenDPI << " DPI\n";
    desc << "Class: ";

    switch (deviceClass)
    {
        case DeviceClass::Mobile:    desc << "Mobile"; break;
        case DeviceClass::Tablet:    desc << "Tablet"; break;
        case DeviceClass::Desktop:   desc << "Desktop"; break;
        case DeviceClass::Wearable:  desc << "Wearable"; break;
        case DeviceClass::Embedded:  desc << "Embedded"; break;
        case DeviceClass::Web:       desc << "Web"; break;
        case DeviceClass::AR_VR:     desc << "AR/VR"; break;
        case DeviceClass::IoT:       desc << "IoT"; break;
        default:                     desc << "Unknown"; break;
    }

    desc << "\nBattery: " << (batteryPowered ? juce::String(batteryPercent) + "%" : "AC Power");
    desc << "\nOnline: " << (isOnline ? "Yes" : "No");
    desc << "\nCPU Cores: " << cpuCores;
    desc << "\nRAM: " << juce::String(ramBytes / (1024 * 1024 * 1024)) << " GB";

    return desc;
}

//==============================================================================
// PerformanceProfile Implementation
//==============================================================================

PerformanceProfile PerformanceProfile::forPlatform(const PlatformInfo& platform)
{
    PerformanceProfile profile;

    if (platform.needsPowerOptimization())
    {
        // Battery critical - minimum settings
        profile.quality = Quality::PowerSaving;
        profile.maxAudioTracks = 8;
        profile.maxVST3Plugins = 2;
        profile.audioBufferSize = 1024;
        profile.uiRefreshRateHz = 30;
        profile.enableAnimations = false;
        profile.enableShadows = false;
        profile.enableBlur = false;
        profile.enableGPUAcceleration = false;
    }
    else if (platform.isWearable())
    {
        // Wearable - very limited
        profile.quality = Quality::Low;
        profile.maxAudioTracks = 4;
        profile.maxVST3Plugins = 1;
        profile.audioBufferSize = 1024;
        profile.audioSampleRate = 44100.0;
        profile.uiRefreshRateHz = 30;
        profile.enableAnimations = false;
        profile.enableShadows = false;
        profile.enableBlur = false;
        profile.maxThreads = 2;
    }
    else if (platform.isEmbedded())
    {
        // Embedded - limited resources
        profile.quality = Quality::Medium;
        profile.maxAudioTracks = 16;
        profile.maxVST3Plugins = 4;
        profile.audioBufferSize = 512;
        profile.audioSampleRate = 44100.0;
        profile.uiRefreshRateHz = 30;
        profile.enableAnimations = true;
        profile.enableShadows = false;
        profile.maxThreads = platform.cpuCores;
    }
    else if (platform.isMobile())
    {
        // Mobile - balanced
        profile.quality = Quality::High;
        profile.maxAudioTracks = 32;
        profile.maxVST3Plugins = 16;
        profile.audioBufferSize = 256;
        profile.audioSampleRate = 48000.0;
        profile.uiRefreshRateHz = 60;
        profile.enableAnimations = true;
        profile.enableShadows = true;
        profile.enableBlur = true;
        profile.enableGPUAcceleration = platform.hasGPU;
        profile.maxThreads = juce::jmin(platform.cpuCores, 8);
    }
    else if (platform.isDesktop())
    {
        // Desktop - high performance
        profile.quality = Quality::Ultra;
        profile.maxAudioTracks = 128;
        profile.maxVST3Plugins = 64;
        profile.audioBufferSize = 128;
        profile.audioSampleRate = 48000.0;
        profile.uiRefreshRateHz = 60;
        profile.enableAnimations = true;
        profile.enableShadows = true;
        profile.enableBlur = true;
        profile.enableGPUAcceleration = platform.hasGPU;
        profile.maxThreads = platform.cpuCores;
    }

    return profile;
}

//==============================================================================
// AdaptiveUIConfig Implementation
//==============================================================================

AdaptiveUIConfig AdaptiveUIConfig::forPlatform(const PlatformInfo& platform)
{
    AdaptiveUIConfig config;

    if (platform.isWearable())
    {
        // Wearable - minimal UI
        config.mode = UIMode::Minimal;
        config.minTouchTargetSize = 60;  // Larger for small screens
        config.spacing = 4;
        config.margins = 8;
        config.compactMode = true;
        config.baseFontSize = 12.0f;
        config.useNativeControls = true;
    }
    else if (platform.isMobile())
    {
        // Mobile - touch-optimized
        config.mode = UIMode::Touch;
        config.minTouchTargetSize = 44;  // iOS HIG
        config.spacing = 8;
        config.margins = 16;
        config.compactMode = (platform.screenWidth < 768);
        config.baseFontSize = 14.0f;
        config.enableSwipeGestures = true;
        config.enablePinchZoom = true;
        config.useDynamicType = true;
    }
    else if (platform.isDesktop())
    {
        // Desktop - full UI
        config.mode = UIMode::Desktop;
        config.minTouchTargetSize = 32;
        config.spacing = 12;
        config.margins = 24;
        config.compactMode = false;
        config.baseFontSize = 14.0f;
        config.enableSwipeGestures = false;
    }
    else if (platform.isAR_VR())
    {
        // AR/VR - spatial UI
        config.mode = UIMode::VR;
        config.minTouchTargetSize = 80;  // Larger for spatial pointing
        config.spacing = 16;
        config.margins = 32;
        config.baseFontSize = 18.0f;
    }

    return config;
}

//==============================================================================
// CrossPlatformEngine Implementation
//==============================================================================

CrossPlatformEngine::CrossPlatformEngine()
{
    DBG("CrossPlatformEngine initialized - Universal platform support");

    detectPlatform();
    applyPlatformOptimizations();

    if (onPlatformDetected)
        onPlatformDetected(platformInfo);
}

CrossPlatformEngine::~CrossPlatformEngine()
{
}

//==============================================================================
// Platform Detection
//==============================================================================

void CrossPlatformEngine::detectPlatform()
{
    DBG("Detecting platform...");

    detectScreen();
    detectInput();
    detectSensors();
    detectNetwork();
    detectBattery();

    // Detect OS
    #if JUCE_IOS
        platformInfo.platformName = "iOS";
        platformInfo.deviceClass = DeviceClass::Mobile;
        platformInfo.type = PlatformType::iOS_Phone;

        #if TARGET_IPHONE_SIMULATOR
            platformInfo.isSimulator = true;
        #endif

        // Check if iPad
        if (juce::SystemStats::getDeviceDescription().contains("iPad"))
        {
            platformInfo.type = PlatformType::iOS_Tablet;
            platformInfo.deviceClass = DeviceClass::Tablet;
        }

    #elif JUCE_ANDROID
        platformInfo.platformName = "Android";
        platformInfo.deviceClass = DeviceClass::Mobile;
        platformInfo.type = PlatformType::Android_Phone;

        // Check if tablet (screen size > 7 inches)
        if (platformInfo.screenWidth >= 1024)
        {
            platformInfo.type = PlatformType::Android_Tablet;
            platformInfo.deviceClass = DeviceClass::Tablet;
        }

    #elif JUCE_MAC
        platformInfo.platformName = "macOS";
        platformInfo.deviceClass = DeviceClass::Desktop;
        platformInfo.type = PlatformType::macOS;

    #elif JUCE_WINDOWS
        platformInfo.platformName = "Windows";
        platformInfo.deviceClass = DeviceClass::Desktop;
        platformInfo.type = PlatformType::Windows;

    #elif JUCE_LINUX
        platformInfo.platformName = "Linux";
        platformInfo.deviceClass = DeviceClass::Desktop;
        platformInfo.type = PlatformType::Linux;

        // Check for Raspberry Pi
        auto description = juce::SystemStats::getDeviceDescription();
        if (description.contains("Raspberry") || description.contains("BCM"))
        {
            platformInfo.type = PlatformType::RaspberryPi;
            platformInfo.deviceClass = DeviceClass::Embedded;
        }

    #elif JUCE_WASM
        platformInfo.platformName = "WebAssembly";
        platformInfo.deviceClass = DeviceClass::Web;
        platformInfo.type = PlatformType::WebAssembly;

    #else
        platformInfo.platformName = "Unknown";
        platformInfo.deviceClass = DeviceClass::Unknown;
        platformInfo.type = PlatformType::Unknown;
    #endif

    platformInfo.osVersion = juce::SystemStats::getOperatingSystemName();
    platformInfo.deviceModel = juce::SystemStats::getDeviceDescription();

    // Performance info
    platformInfo.cpuCores = juce::SystemStats::getNumCpus();
    platformInfo.ramBytes = juce::SystemStats::getMemorySizeInMegabytes() * 1024LL * 1024LL;

    // Build type
    #if JUCE_DEBUG
        platformInfo.isDevelopmentBuild = true;
    #endif

    DBG("Platform detected: " + platformInfo.platformName);
    DBG(platformInfo.getDescription());
}

void CrossPlatformEngine::detectScreen()
{
    auto displays = juce::Desktop::getInstance().getDisplays();
    auto mainDisplay = displays.getPrimaryDisplay();

    if (mainDisplay)
    {
        auto area = mainDisplay->userArea;
        platformInfo.screenWidth = area.getWidth();
        platformInfo.screenHeight = area.getHeight();
        platformInfo.screenDPI = mainDisplay->dpi;
        platformInfo.screenScale = mainDisplay->scale;
    }

    platformInfo.touchScreen = juce::Desktop::getInstance().getMainMouseSource().isTouch();

    DBG("Screen: " + juce::String(platformInfo.screenWidth) + "x" +
        juce::String(platformInfo.screenHeight) + " @ " +
        juce::String(platformInfo.screenDPI) + " DPI");
}

void CrossPlatformEngine::detectInput()
{
    // Touch
    platformInfo.touchScreen = juce::Desktop::getInstance().getMainMouseSource().isTouch();

    // Mouse/Trackpad (desktop)
    #if JUCE_MAC || JUCE_WINDOWS || JUCE_LINUX
        platformInfo.hasMouse = true;
    #endif

    // Keyboard
    #if JUCE_MAC || JUCE_WINDOWS || JUCE_LINUX
        platformInfo.hasKeyboard = true;
    #elif JUCE_IOS || JUCE_ANDROID
        platformInfo.hasKeyboard = false;  // Virtual keyboard
    #endif

    // Stylus (iPad with Apple Pencil, etc.)
    #if JUCE_IOS
        platformInfo.hasStylus = true;  // Assume modern iPads
    #elif JUCE_ANDROID
        platformInfo.hasStylus = false;  // Some devices have S Pen
    #endif

    // Microphone
    platformInfo.hasMicrophone = true;  // Most devices
}

void CrossPlatformEngine::detectSensors()
{
    #if JUCE_IOS || JUCE_ANDROID
        // Mobile devices have sensors
        platformInfo.hasGPS = true;
        platformInfo.hasAccelerometer = true;
        platformInfo.hasGyroscope = true;
        platformInfo.hasCamera = true;
    #else
        // Desktop typically doesn't have these
        platformInfo.hasGPS = false;
        platformInfo.hasAccelerometer = false;
        platformInfo.hasGyroscope = false;
        platformInfo.hasCamera = false;  // Webcam exists but different
    #endif
}

void CrossPlatformEngine::detectNetwork()
{
    #if JUCE_IOS || JUCE_ANDROID
        platformInfo.hasWiFi = true;
        platformInfo.hasCellular = true;
        platformInfo.hasBluetooth = true;
        platformInfo.hasNFC = true;
    #else
        platformInfo.hasWiFi = true;
        platformInfo.hasCellular = false;
        platformInfo.hasBluetooth = false;  // Some desktops
        platformInfo.hasNFC = false;
    #endif

    // Check actual online status
    platformInfo.isOnline = true;  // Would check actual network connectivity
}

void CrossPlatformEngine::detectBattery()
{
    #if JUCE_IOS || JUCE_ANDROID
        platformInfo.batteryPowered = true;
        platformInfo.batteryPercent = 100;  // Would read actual battery level
        platformInfo.isCharging = false;
    #else
        platformInfo.batteryPowered = false;
        platformInfo.batteryPercent = 100;
        platformInfo.isCharging = false;
    #endif
}

void CrossPlatformEngine::detectCapabilities()
{
    detectPlatform();
}

PlatformInfo CrossPlatformEngine::getPlatformInfo() const
{
    return platformInfo;
}

bool CrossPlatformEngine::isRunningOn(PlatformType type) const
{
    return platformInfo.type == type;
}

bool CrossPlatformEngine::isRunningOn(DeviceClass deviceClass) const
{
    return platformInfo.deviceClass == deviceClass;
}

//==============================================================================
// UI Adaptation
//==============================================================================

void CrossPlatformEngine::setUIMode(UIMode mode)
{
    currentUIMode = mode;

    DBG("UI mode set to: " + juce::String((int)mode));

    if (mode == UIMode::Adaptive)
    {
        // Auto-select based on platform
        if (platformInfo.isWearable())
            currentUIMode = UIMode::Minimal;
        else if (platformInfo.isMobile())
            currentUIMode = UIMode::Touch;
        else if (platformInfo.isDesktop())
            currentUIMode = UIMode::Desktop;
        else if (platformInfo.isAR_VR())
            currentUIMode = UIMode::VR;
    }

    uiConfig = AdaptiveUIConfig::forPlatform(platformInfo);

    if (onUIModeChanged)
        onUIModeChanged(currentUIMode);
}

UIMode CrossPlatformEngine::getUIMode() const
{
    return currentUIMode;
}

AdaptiveUIConfig CrossPlatformEngine::getUIConfig() const
{
    return uiConfig;
}

float CrossPlatformEngine::getUIScaleFactor() const
{
    float scale = platformInfo.screenScale;

    // Additional scaling for small screens
    if (platformInfo.isWearable())
        scale *= 0.8f;

    return scale;
}

bool CrossPlatformEngine::shouldUseCompactUI() const
{
    return uiConfig.compactMode ||
           platformInfo.screenWidth < 768 ||
           platformInfo.isWearable();
}

//==============================================================================
// Performance Optimization
//==============================================================================

PerformanceProfile CrossPlatformEngine::getPerformanceProfile() const
{
    return performanceProfile;
}

void CrossPlatformEngine::setPerformanceQuality(PerformanceProfile::Quality quality)
{
    performanceProfile.quality = quality;

    DBG("Performance quality set to: " + juce::String((int)quality));

    applyPlatformOptimizations();
}

void CrossPlatformEngine::enablePowerSavingMode(bool enable)
{
    powerSavingMode = enable;

    DBG("Power saving mode " + juce::String(enable ? "enabled" : "disabled"));

    if (enable)
    {
        // Reduce performance
        performanceProfile.quality = PerformanceProfile::Quality::PowerSaving;
        performanceProfile.audioBufferSize = 1024;
        performanceProfile.uiRefreshRateHz = 30;
        performanceProfile.enableAnimations = false;
        performanceProfile.enableGPUAcceleration = false;
    }
    else
    {
        // Restore normal performance
        performanceProfile = PerformanceProfile::forPlatform(platformInfo);
    }

    if (onPowerSavingChanged)
        onPowerSavingChanged(enable);
}

bool CrossPlatformEngine::isPowerSavingActive() const
{
    return powerSavingMode;
}

void CrossPlatformEngine::optimizeForBattery()
{
    if (platformInfo.batteryPowered)
    {
        if (platformInfo.batteryPercent < 20)
            enablePowerSavingMode(true);
        else if (platformInfo.batteryPercent > 50 && powerSavingMode)
            enablePowerSavingMode(false);
    }
}

//==============================================================================
// Input Handling
//==============================================================================

juce::Array<InputMethod> CrossPlatformEngine::getAvailableInputMethods() const
{
    juce::Array<InputMethod> methods;

    if (platformInfo.touchScreen)
        methods.add(InputMethod::Touch);

    if (platformInfo.hasMouse)
        methods.add(InputMethod::Mouse);

    if (platformInfo.hasKeyboard)
        methods.add(InputMethod::Keyboard);

    if (platformInfo.hasMicrophone)
        methods.add(InputMethod::Voice);

    if (platformInfo.hasStylus)
        methods.add(InputMethod::Stylus);

    if (platformInfo.hasAccelerometer)
        methods.add(InputMethod::Gesture);

    return methods;
}

void CrossPlatformEngine::setPrimaryInputMethod(InputMethod method)
{
    currentInputMethod = method;

    DBG("Primary input method: " + juce::String((int)method));
}

InputMethod CrossPlatformEngine::getCurrentInputMethod() const
{
    return currentInputMethod;
}

void CrossPlatformEngine::enableGestures(bool enable)
{
    gesturesEnabled = enable;
    uiConfig.enableSwipeGestures = enable;
    uiConfig.enablePinchZoom = enable;
    uiConfig.enableDoubleTap = enable;
    uiConfig.enableLongPress = enable;
}

void CrossPlatformEngine::enableVoiceControl(bool enable)
{
    voiceControlEnabled = enable;

    DBG("Voice control " + juce::String(enable ? "enabled" : "disabled"));
}

//==============================================================================
// Platform-Specific Features
//==============================================================================

void CrossPlatformEngine::enableMobileFeatures(bool enable)
{
    if (enable && platformInfo.isMobile())
    {
        setUIMode(UIMode::Touch);
        enableGestures(true);
        uiConfig.useDynamicType = true;
        uiConfig.respectSystemTheme = true;
    }
}

void CrossPlatformEngine::enableWearableFeatures(bool enable)
{
    if (enable && platformInfo.isWearable())
    {
        setUIMode(UIMode::Minimal);
        enablePowerSavingMode(true);
        uiConfig.compactMode = true;
    }
}

void CrossPlatformEngine::enableDesktopFeatures(bool enable)
{
    if (enable && platformInfo.isDesktop())
    {
        setUIMode(UIMode::Desktop);
        enableGestures(false);
        performanceProfile.quality = PerformanceProfile::Quality::Ultra;
    }
}

void CrossPlatformEngine::enableAR_VRFeatures(bool enable)
{
    if (enable && platformInfo.isAR_VR())
    {
        setUIMode(UIMode::VR);
        enableSpatialAudio(true);
    }
}

//==============================================================================
// Responsive Layout
//==============================================================================

juce::String CrossPlatformEngine::getRecommendedLayout() const
{
    if (platformInfo.isWearable())
        return "minimal";
    else if (platformInfo.screenWidth < 768)
        return "mobile";
    else if (platformInfo.screenWidth < 1024)
        return "tablet";
    else if (platformInfo.screenWidth < 1440)
        return "desktop";
    else
        return "large-desktop";
}

bool CrossPlatformEngine::shouldShowSidebar() const
{
    return platformInfo.screenWidth >= 1024 && !shouldUseCompactUI();
}

bool CrossPlatformEngine::shouldShowToolbar() const
{
    return !platformInfo.isWearable();
}

int CrossPlatformEngine::getMaxVisibleTracks() const
{
    if (platformInfo.isWearable())
        return 1;
    else if (platformInfo.screenWidth < 768)
        return 4;
    else if (platformInfo.screenWidth < 1024)
        return 8;
    else if (platformInfo.screenWidth < 1440)
        return 16;
    else
        return 32;
}

int CrossPlatformEngine::getCompactModeThreshold() const
{
    return 768;  // iPad width
}

//==============================================================================
// Cross-Platform Sync
//==============================================================================

void CrossPlatformEngine::enableCloudSync(bool enable)
{
    cloudSyncEnabled = enable;

    DBG("Cloud sync " + juce::String(enable ? "enabled" : "disabled"));
}

bool CrossPlatformEngine::syncProject(const juce::String& projectID)
{
    if (!cloudSyncEnabled)
        return false;

    DBG("Syncing project: " + projectID);

    // Would implement actual cloud sync here

    return true;
}

juce::String CrossPlatformEngine::getSyncStatus() const
{
    if (!cloudSyncEnabled)
        return "Sync disabled";

    if (!platformInfo.isOnline)
        return "Offline";

    return "Synced";
}

//==============================================================================
// Offline Support
//==============================================================================

void CrossPlatformEngine::enableOfflineMode(bool enable)
{
    offlineMode = enable;

    DBG("Offline mode " + juce::String(enable ? "enabled" : "disabled"));
}

bool CrossPlatformEngine::isOfflineMode() const
{
    return offlineMode || !platformInfo.isOnline;
}

void CrossPlatformEngine::cacheDataForOffline()
{
    DBG("Caching data for offline use...");

    // Would cache projects, samples, etc.
}

void CrossPlatformEngine::clearOfflineCache()
{
    DBG("Clearing offline cache...");
}

//==============================================================================
// Platform Lifecycle
//==============================================================================

void CrossPlatformEngine::onAppEnterBackground()
{
    DBG("App entering background");

    // Save state
    // Pause audio processing
    // Release resources
}

void CrossPlatformEngine::onAppEnterForeground()
{
    DBG("App entering foreground");

    // Restore state
    // Resume audio processing
}

void CrossPlatformEngine::onLowMemoryWarning()
{
    DBG("Low memory warning!");

    // Clear caches
    // Reduce quality
    // Release unused resources

    if (onLowMemory)
        onLowMemory();
}

void CrossPlatformEngine::onBatteryLevelChange(int percent)
{
    platformInfo.batteryPercent = percent;

    DBG("Battery level: " + juce::String(percent) + "%");

    optimizeForBattery();

    if (onBatteryChanged)
        onBatteryChanged(percent);
}

void CrossPlatformEngine::onNetworkStatusChange(bool online)
{
    platformInfo.isOnline = online;

    DBG("Network: " + juce::String(online ? "Online" : "Offline"));

    if (!online)
        enableOfflineMode(true);

    if (onNetworkChanged)
        onNetworkChanged(online);
}

//==============================================================================
// Future Platform Support
//==============================================================================

void CrossPlatformEngine::prepareARMode()
{
    DBG("Preparing AR mode...");

    setUIMode(UIMode::AR);
    enableSpatialAudio(true);
}

void CrossPlatformEngine::prepareVRMode()
{
    DBG("Preparing VR mode...");

    setUIMode(UIMode::VR);
    enableSpatialAudio(true);
    performanceProfile.uiRefreshRateHz = 90;  // High refresh for VR
}

void CrossPlatformEngine::enableSpatialAudio(bool enable)
{
    DBG("Spatial audio " + juce::String(enable ? "enabled" : "disabled"));

    // Would enable binaural/spatial processing
}

void CrossPlatformEngine::handleVRControllerInput()
{
    DBG("Handling VR controller input");

    // Would process VR controller events
}

//==============================================================================
// Private Methods
//==============================================================================

void CrossPlatformEngine::applyPlatformOptimizations()
{
    performanceProfile = PerformanceProfile::forPlatform(platformInfo);
    uiConfig = AdaptiveUIConfig::forPlatform(platformInfo);

    if (platformInfo.isMobile())
        configureForMobile();
    else if (platformInfo.isDesktop())
        configureForDesktop();
    else if (platformInfo.isWearable())
        configureForWearable();
    else if (platformInfo.isWeb())
        configureForWeb();
    else if (platformInfo.isAR_VR())
        configureForAR_VR();
}

void CrossPlatformEngine::configureForMobile()
{
    DBG("Configuring for mobile platform");

    setUIMode(UIMode::Touch);
    enableGestures(true);
    uiConfig.useDynamicType = true;
    uiConfig.respectSystemTheme = true;
}

void CrossPlatformEngine::configureForDesktop()
{
    DBG("Configuring for desktop platform");

    setUIMode(UIMode::Desktop);
    enableGestures(false);
    performanceProfile.quality = PerformanceProfile::Quality::Ultra;
}

void CrossPlatformEngine::configureForWearable()
{
    DBG("Configuring for wearable platform");

    setUIMode(UIMode::Minimal);
    enablePowerSavingMode(true);
    uiConfig.compactMode = true;
    performanceProfile.quality = PerformanceProfile::Quality::Low;
}

void CrossPlatformEngine::configureForWeb()
{
    DBG("Configuring for web platform");

    setUIMode(UIMode::Adaptive);
    performanceProfile.quality = PerformanceProfile::Quality::Medium;
}

void CrossPlatformEngine::configureForAR_VR()
{
    DBG("Configuring for AR/VR platform");

    setUIMode(UIMode::VR);
    enableSpatialAudio(true);
    performanceProfile.uiRefreshRateHz = 90;
}
