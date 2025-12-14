/**
 * ╔══════════════════════════════════════════════════════════════════════════════╗
 * ║              ECHOELMUSIC UNIVERSAL PLATFORM SUPPORT                          ║
 * ║                    All Platforms • All Devices • All OS                      ║
 * ╚══════════════════════════════════════════════════════════════════════════════╝
 *
 * Supported Platforms:
 * ━━━━━━━━━━━━━━━━━━━━
 * DESKTOP:
 *   • Windows 10/11 (x64, ARM64)
 *   • macOS 12+ (Intel, Apple Silicon)
 *   • Linux (x64, ARM64) - Ubuntu, Fedora, Arch, etc.
 *   • ChromeOS (via Linux container)
 *
 * MOBILE:
 *   • iOS 15+ (iPhone, iPad)
 *   • iPadOS 15+ (iPad Pro, iPad Air, iPad mini)
 *   • Android 8+ (ARM64, ARMv7, x86_64)
 *
 * WEARABLES:
 *   • watchOS 8+ (Apple Watch Series 4+)
 *   • Wear OS 3+ (Samsung Galaxy Watch, Pixel Watch)
 *   • Fitbit OS (Bio-data collection)
 *   • Garmin Connect IQ
 *
 * XR/SPATIAL:
 *   • visionOS 1+ (Apple Vision Pro)
 *   • Meta Quest (via Android)
 *   • Windows Mixed Reality
 *
 * EMBEDDED:
 *   • Raspberry Pi (ARM64)
 *   • NVIDIA Jetson (ARM64, CUDA)
 *   • ESP32 (limited, bio-sensor only)
 *   • Arduino (bio-sensor bridge)
 *
 * WEB:
 *   • WebAssembly (Chrome, Firefox, Safari, Edge)
 *   • WebAudio API
 *   • WebMIDI API
 *
 * PLUGIN FORMATS:
 *   • VST3 (Windows, macOS, Linux)
 *   • Audio Unit (macOS, iOS)
 *   • AUv3 (iOS, iPadOS, macOS)
 *   • AAX (Pro Tools - macOS, Windows)
 *   • CLAP (All desktop platforms)
 *   • Standalone (All platforms)
 *   • LV2 (Linux)
 */

#pragma once

#include <cstdint>

namespace echoelmusic {
namespace platform {

//==============================================================================
// PLATFORM DETECTION
//==============================================================================

// Operating System
#if defined(_WIN32) || defined(_WIN64) || defined(__MINGW32__)
    #define ECHOEL_WINDOWS 1
    #define ECHOEL_PLATFORM_NAME "Windows"
#elif defined(__APPLE__)
    #include <TargetConditionals.h>
    #if TARGET_OS_IPHONE
        #define ECHOEL_IOS 1
        #define ECHOEL_PLATFORM_NAME "iOS"
    #elif TARGET_OS_WATCH
        #define ECHOEL_WATCHOS 1
        #define ECHOEL_PLATFORM_NAME "watchOS"
    #elif TARGET_OS_TV
        #define ECHOEL_TVOS 1
        #define ECHOEL_PLATFORM_NAME "tvOS"
    #elif TARGET_OS_VISION
        #define ECHOEL_VISIONOS 1
        #define ECHOEL_PLATFORM_NAME "visionOS"
    #else
        #define ECHOEL_MACOS 1
        #define ECHOEL_PLATFORM_NAME "macOS"
    #endif
    #define ECHOEL_APPLE 1
#elif defined(__ANDROID__)
    #define ECHOEL_ANDROID 1
    #define ECHOEL_PLATFORM_NAME "Android"
#elif defined(__linux__)
    #define ECHOEL_LINUX 1
    #define ECHOEL_PLATFORM_NAME "Linux"
#elif defined(__EMSCRIPTEN__)
    #define ECHOEL_WEB 1
    #define ECHOEL_PLATFORM_NAME "Web"
#elif defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__)
    #define ECHOEL_BSD 1
    #define ECHOEL_PLATFORM_NAME "BSD"
#else
    #define ECHOEL_UNKNOWN_OS 1
    #define ECHOEL_PLATFORM_NAME "Unknown"
#endif

// Architecture
#if defined(__x86_64__) || defined(_M_X64) || defined(__amd64__)
    #define ECHOEL_X64 1
    #define ECHOEL_ARCH_NAME "x64"
#elif defined(__i386__) || defined(_M_IX86)
    #define ECHOEL_X86 1
    #define ECHOEL_ARCH_NAME "x86"
#elif defined(__aarch64__) || defined(_M_ARM64)
    #define ECHOEL_ARM64 1
    #define ECHOEL_ARCH_NAME "ARM64"
#elif defined(__arm__) || defined(_M_ARM)
    #define ECHOEL_ARM32 1
    #define ECHOEL_ARCH_NAME "ARM32"
#elif defined(__wasm__)
    #define ECHOEL_WASM 1
    #define ECHOEL_ARCH_NAME "WebAssembly"
#elif defined(__riscv)
    #define ECHOEL_RISCV 1
    #define ECHOEL_ARCH_NAME "RISC-V"
#else
    #define ECHOEL_UNKNOWN_ARCH 1
    #define ECHOEL_ARCH_NAME "Unknown"
#endif

// Device Type
#if ECHOEL_WATCHOS || defined(WEAR_OS)
    #define ECHOEL_WEARABLE 1
    #define ECHOEL_DEVICE_TYPE "Wearable"
#elif ECHOEL_VISIONOS || defined(QUEST_OS)
    #define ECHOEL_XR 1
    #define ECHOEL_DEVICE_TYPE "XR Headset"
#elif ECHOEL_IOS || ECHOEL_ANDROID
    #define ECHOEL_MOBILE 1
    #define ECHOEL_DEVICE_TYPE "Mobile"
#elif ECHOEL_TVOS
    #define ECHOEL_TV 1
    #define ECHOEL_DEVICE_TYPE "TV"
#elif ECHOEL_WEB
    #define ECHOEL_BROWSER 1
    #define ECHOEL_DEVICE_TYPE "Browser"
#else
    #define ECHOEL_DESKTOP 1
    #define ECHOEL_DEVICE_TYPE "Desktop"
#endif

//==============================================================================
// FEATURE AVAILABILITY
//==============================================================================

struct PlatformCapabilities {
    // Audio
    bool hasAudioOutput = true;
    bool hasAudioInput = true;
    bool hasMIDI = true;
    bool hasLowLatencyAudio = true;
    int maxSampleRate = 192000;
    int minBufferSize = 32;

    // Bio-sensors
    bool hasHeartRateSensor = false;
    bool hasHRVSensor = false;
    bool hasECGSensor = false;
    bool hasAccelerometer = false;
    bool hasGyroscope = false;
    bool hasBarometer = false;
    bool hasGPS = false;

    // Connectivity
    bool hasBluetooth = true;
    bool hasBluetoothLE = true;
    bool hasWiFi = true;
    bool hasUSB = true;
    bool hasThunderbolt = false;

    // Display
    bool hasDisplay = true;
    bool hasTouchScreen = false;
    bool hasHaptics = false;
    bool supportsHDR = false;
    bool supportsSpatialAudio = false;

    // Compute
    bool hasGPU = true;
    bool hasSIMD = true;
    bool hasMultiCore = true;
    int maxThreads = 8;
    size_t maxRAM = 8ULL * 1024 * 1024 * 1024;  // 8GB default

    // Plugin formats
    bool supportsVST3 = false;
    bool supportsAU = false;
    bool supportsAAX = false;
    bool supportsCLAP = false;
    bool supportsLV2 = false;
    bool supportsAUv3 = false;
};

inline PlatformCapabilities getCapabilities() {
    PlatformCapabilities caps;

    #if ECHOEL_WINDOWS
        caps.supportsVST3 = true;
        caps.supportsAAX = true;
        caps.supportsCLAP = true;
        caps.hasThunderbolt = true;
        caps.maxThreads = 64;
    #elif ECHOEL_MACOS
        caps.supportsVST3 = true;
        caps.supportsAU = true;
        caps.supportsAAX = true;
        caps.supportsCLAP = true;
        caps.hasThunderbolt = true;
        caps.supportsSpatialAudio = true;
        caps.maxThreads = 24;
    #elif ECHOEL_IOS
        caps.supportsAUv3 = true;
        caps.hasTouchScreen = true;
        caps.hasHaptics = true;
        caps.hasAccelerometer = true;
        caps.hasGyroscope = true;
        caps.hasGPS = true;
        caps.maxThreads = 6;
        caps.maxRAM = 6ULL * 1024 * 1024 * 1024;
    #elif ECHOEL_WATCHOS
        caps.hasHeartRateSensor = true;
        caps.hasHRVSensor = true;
        caps.hasECGSensor = true;  // Apple Watch 4+
        caps.hasAccelerometer = true;
        caps.hasGyroscope = true;
        caps.hasBarometer = true;
        caps.hasGPS = true;
        caps.hasTouchScreen = true;
        caps.hasHaptics = true;
        caps.hasAudioInput = false;  // Limited on Watch
        caps.hasLowLatencyAudio = false;
        caps.maxSampleRate = 48000;
        caps.minBufferSize = 512;
        caps.maxThreads = 2;
        caps.maxRAM = 1ULL * 1024 * 1024 * 1024;
        caps.hasGPU = false;
    #elif ECHOEL_VISIONOS
        caps.supportsAUv3 = true;
        caps.supportsSpatialAudio = true;
        caps.supportsHDR = true;
        caps.hasAccelerometer = true;
        caps.hasGyroscope = true;
        caps.hasGPS = true;
        caps.maxThreads = 10;
    #elif ECHOEL_TVOS
        caps.supportsAUv3 = true;
        caps.supportsSpatialAudio = true;
        caps.supportsHDR = true;
        caps.hasAudioInput = false;
        caps.hasTouchScreen = false;
        caps.maxThreads = 6;
    #elif ECHOEL_ANDROID
        caps.hasTouchScreen = true;
        caps.hasHaptics = true;
        caps.hasAccelerometer = true;
        caps.hasGyroscope = true;
        caps.hasGPS = true;
        caps.hasHeartRateSensor = true;  // Many Android wearables
        caps.maxThreads = 8;
    #elif ECHOEL_LINUX
        caps.supportsVST3 = true;
        caps.supportsCLAP = true;
        caps.supportsLV2 = true;
        caps.maxThreads = 128;  // Server-grade
    #elif ECHOEL_WEB
        caps.hasAudioInput = true;  // WebRTC
        caps.hasMIDI = true;  // WebMIDI
        caps.hasLowLatencyAudio = false;  // Web Audio has latency
        caps.minBufferSize = 128;
        caps.hasGPU = true;  // WebGL/WebGPU
        caps.hasSIMD = true;  // WASM SIMD
        caps.hasUSB = false;
        caps.hasThunderbolt = false;
    #endif

    return caps;
}

//==============================================================================
// WEARABLE BIO-SENSOR INTERFACE
//==============================================================================

struct BioSensorReading {
    float heartRate = 0.0f;          // BPM
    float hrv = 0.0f;                // ms (RMSSD)
    float respirationRate = 0.0f;   // breaths/min
    float bloodOxygen = 0.0f;       // SpO2 %
    float skinTemperature = 0.0f;   // °C
    float galvanicSkinResponse = 0.0f;  // μS
    float stressLevel = 0.0f;       // 0-1
    float energyLevel = 0.0f;       // 0-1
    float sleepQuality = 0.0f;      // 0-1
    int64_t timestamp = 0;          // Unix timestamp ms
    bool isValid = false;
};

// Abstract interface for platform-specific bio-sensor implementations
class IBioSensorProvider {
public:
    virtual ~IBioSensorProvider() = default;

    virtual bool initialize() = 0;
    virtual void shutdown() = 0;
    virtual bool isAvailable() const = 0;

    virtual BioSensorReading getLatestReading() const = 0;
    virtual void requestReading() = 0;

    // Specific sensor access
    virtual float getHeartRate() const { return getLatestReading().heartRate; }
    virtual float getHRV() const { return getLatestReading().hrv; }
    virtual float getStressLevel() const { return getLatestReading().stressLevel; }
};

//==============================================================================
// PLATFORM-SPECIFIC AUDIO BACKENDS
//==============================================================================

enum class AudioBackend {
    // Windows
    WASAPI,
    ASIO,
    DirectSound,

    // macOS/iOS
    CoreAudio,
    AVAudioEngine,

    // Linux
    ALSA,
    PulseAudio,
    JACK,
    PipeWire,

    // Android
    AAudio,
    OpenSLES,
    Oboe,

    // Web
    WebAudio,

    // Cross-platform
    PortAudio,
    RtAudio,

    Unknown
};

inline AudioBackend getPreferredBackend() {
    #if ECHOEL_WINDOWS
        return AudioBackend::WASAPI;  // Prefer WASAPI, fallback to ASIO
    #elif ECHOEL_MACOS || ECHOEL_IOS || ECHOEL_TVOS || ECHOEL_VISIONOS
        return AudioBackend::CoreAudio;
    #elif ECHOEL_WATCHOS
        return AudioBackend::AVAudioEngine;
    #elif ECHOEL_LINUX
        return AudioBackend::PipeWire;  // Modern Linux default
    #elif ECHOEL_ANDROID
        return AudioBackend::Oboe;  // Best Android audio
    #elif ECHOEL_WEB
        return AudioBackend::WebAudio;
    #else
        return AudioBackend::PortAudio;
    #endif
}

inline const char* getBackendName(AudioBackend backend) {
    switch (backend) {
        case AudioBackend::WASAPI: return "WASAPI";
        case AudioBackend::ASIO: return "ASIO";
        case AudioBackend::DirectSound: return "DirectSound";
        case AudioBackend::CoreAudio: return "Core Audio";
        case AudioBackend::AVAudioEngine: return "AVAudioEngine";
        case AudioBackend::ALSA: return "ALSA";
        case AudioBackend::PulseAudio: return "PulseAudio";
        case AudioBackend::JACK: return "JACK";
        case AudioBackend::PipeWire: return "PipeWire";
        case AudioBackend::AAudio: return "AAudio";
        case AudioBackend::OpenSLES: return "OpenSL ES";
        case AudioBackend::Oboe: return "Oboe";
        case AudioBackend::WebAudio: return "Web Audio";
        case AudioBackend::PortAudio: return "PortAudio";
        case AudioBackend::RtAudio: return "RtAudio";
        default: return "Unknown";
    }
}

//==============================================================================
// PLATFORM INFO
//==============================================================================

struct PlatformInfo {
    const char* osName = ECHOEL_PLATFORM_NAME;
    const char* archName = ECHOEL_ARCH_NAME;
    const char* deviceType = ECHOEL_DEVICE_TYPE;
    PlatformCapabilities capabilities;
    AudioBackend preferredBackend;

    PlatformInfo() {
        capabilities = getCapabilities();
        preferredBackend = getPreferredBackend();
    }
};

inline PlatformInfo getPlatformInfo() {
    static PlatformInfo info;
    return info;
}

//==============================================================================
// COMPILE-TIME PLATFORM CHECKS
//==============================================================================

#if ECHOEL_WEARABLE
    static_assert(true, "Building for wearable platform");
#endif

#if ECHOEL_XR
    static_assert(true, "Building for XR/Spatial platform");
#endif

#if ECHOEL_WEB
    static_assert(true, "Building for Web/WASM platform");
#endif

} // namespace platform
} // namespace echoelmusic

// Convenience macros
#define ECHOEL_PLATFORM_INFO() echoelmusic::platform::getPlatformInfo()
#define ECHOEL_HAS_BIO_SENSORS() ECHOEL_PLATFORM_INFO().capabilities.hasHeartRateSensor
