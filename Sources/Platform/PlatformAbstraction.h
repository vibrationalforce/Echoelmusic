#pragma once

#include <JuceHeader.h>
#include <memory>
#include <string>
#include <functional>
#include <vector>
#include <map>

/**
 * PlatformAbstraction - Cross-Platform Compatibility Layer
 *
 * Unified API for:
 * - macOS (Intel + Apple Silicon)
 * - iOS (iPhone + iPad)
 * - Windows (x64 + ARM64)
 * - Linux (x64 + ARM64)
 * - Android (ARM64 + x86_64)
 *
 * Abstracts:
 * - File System access
 * - Audio backends
 * - MIDI handling
 * - Biometric sensors
 * - Camera access
 * - GPU compute
 * - App lifecycle
 * - Permissions
 * - Notifications
 * - In-App Purchases
 * - Cloud storage
 */

namespace Echoelmusic {
namespace Platform {

//==============================================================================
// Platform Detection
//==============================================================================

enum class PlatformType
{
    macOS,
    iOS,
    Windows,
    Linux,
    Android,
    Unknown
};

enum class Architecture
{
    x86_64,
    ARM64,
    x86,
    ARM32,
    Unknown
};

struct PlatformInfo
{
    PlatformType type;
    Architecture arch;
    std::string osVersion;
    std::string deviceModel;
    std::string deviceName;
    bool isSimulator = false;
    bool isDebug = false;
    int screenWidth = 0;
    int screenHeight = 0;
    float screenScale = 1.0f;
    bool supportsHaptics = false;
    bool supportsBiometrics = false;
    bool supportsAR = false;
    bool supportsGPUCompute = false;
};

//==============================================================================
// Audio Backend Abstraction
//==============================================================================

enum class AudioBackend
{
    // macOS/iOS
    CoreAudio,
    AVAudioEngine,

    // Windows
    WASAPI,
    ASIO,
    DirectSound,

    // Linux
    ALSA,
    JACK,
    PulseAudio,
    PipeWire,

    // Android
    AAudio,
    OpenSLES,
    Oboe,

    // Cross-platform
    PortAudio,
    RtAudio
};

struct AudioDeviceInfo
{
    std::string id;
    std::string name;
    AudioBackend backend;
    int numInputChannels = 0;
    int numOutputChannels = 0;
    std::vector<double> supportedSampleRates;
    std::vector<int> supportedBufferSizes;
    double defaultSampleRate = 44100.0;
    int defaultBufferSize = 512;
    bool isDefault = false;
    double latencyMs = 0.0;
};

//==============================================================================
// File System Abstraction
//==============================================================================

class FileSystemAbstraction
{
public:
    // Standard locations
    virtual std::string getDocumentsPath() = 0;
    virtual std::string getCachePath() = 0;
    virtual std::string getTempPath() = 0;
    virtual std::string getAppSupportPath() = 0;
    virtual std::string getDesktopPath() = 0;
    virtual std::string getMusicPath() = 0;

    // Cloud storage
    virtual std::string getiCloudPath() { return ""; }
    virtual std::string getGoogleDrivePath() { return ""; }
    virtual std::string getDropboxPath() { return ""; }

    // Permissions
    virtual bool hasReadPermission(const std::string& path) = 0;
    virtual bool hasWritePermission(const std::string& path) = 0;
    virtual bool requestPermission(const std::string& path) = 0;

    virtual ~FileSystemAbstraction() = default;
};

//==============================================================================
// Biometrics Abstraction
//==============================================================================

class BiometricsAbstraction
{
public:
    struct HeartRateReading
    {
        double bpm;
        double confidence;
        int64_t timestamp;
    };

    struct HRVReading
    {
        double rmssd;           // Root mean square of successive differences
        double sdnn;            // Standard deviation of NN intervals
        double lf;              // Low frequency power
        double hf;              // High frequency power
        double lfHfRatio;
        int64_t timestamp;
    };

    virtual bool isHeartRateAvailable() = 0;
    virtual bool isHRVAvailable() = 0;
    virtual bool requestPermission() = 0;

    virtual void startHeartRateMonitoring(std::function<void(const HeartRateReading&)> callback) = 0;
    virtual void stopHeartRateMonitoring() = 0;

    virtual void startHRVMonitoring(std::function<void(const HRVReading&)> callback) = 0;
    virtual void stopHRVMonitoring() = 0;

    // Camera-based HRV (like HRV4Training)
    virtual bool isCameraHRVAvailable() { return false; }
    virtual void startCameraHRV(std::function<void(const HRVReading&)> callback) {}
    virtual void stopCameraHRV() {}

    virtual ~BiometricsAbstraction() = default;
};

//==============================================================================
// Camera Abstraction
//==============================================================================

class CameraAbstraction
{
public:
    struct CameraInfo
    {
        std::string id;
        std::string name;
        bool isFrontFacing;
        int maxWidth;
        int maxHeight;
        std::vector<int> supportedFPS;
    };

    virtual std::vector<CameraInfo> getAvailableCameras() = 0;
    virtual bool openCamera(const std::string& cameraId) = 0;
    virtual void closeCamera() = 0;

    virtual void setFrameCallback(std::function<void(const juce::Image&)> callback) = 0;

    virtual bool startRecording(const std::string& outputPath) { return false; }
    virtual void stopRecording() {}

    virtual bool requestPermission() = 0;

    virtual ~CameraAbstraction() = default;
};

//==============================================================================
// Haptics Abstraction
//==============================================================================

class HapticsAbstraction
{
public:
    enum class HapticType
    {
        Light,
        Medium,
        Heavy,
        Rigid,
        Soft,
        Success,
        Warning,
        Error,
        Selection
    };

    virtual bool isAvailable() = 0;
    virtual void playHaptic(HapticType type) = 0;
    virtual void playCustomHaptic(float intensity, float sharpness, float duration) {}

    virtual ~HapticsAbstraction() = default;
};

//==============================================================================
// Notifications Abstraction
//==============================================================================

class NotificationsAbstraction
{
public:
    struct Notification
    {
        std::string title;
        std::string body;
        std::string identifier;
        int delaySeconds = 0;
        bool repeats = false;
        std::map<std::string, std::string> userInfo;
    };

    virtual bool requestPermission() = 0;
    virtual void scheduleNotification(const Notification& notification) = 0;
    virtual void cancelNotification(const std::string& identifier) = 0;
    virtual void cancelAllNotifications() = 0;

    virtual ~NotificationsAbstraction() = default;
};

//==============================================================================
// In-App Purchase Abstraction
//==============================================================================

class IAPAbstraction
{
public:
    struct Product
    {
        std::string productId;
        std::string title;
        std::string description;
        std::string price;
        std::string currencyCode;
        bool isSubscription = false;
    };

    virtual void fetchProducts(const std::vector<std::string>& productIds,
                               std::function<void(const std::vector<Product>&)> callback) = 0;
    virtual void purchase(const std::string& productId,
                          std::function<void(bool success, const std::string& error)> callback) = 0;
    virtual void restorePurchases(std::function<void(bool success)> callback) = 0;
    virtual bool isPurchased(const std::string& productId) = 0;

    virtual ~IAPAbstraction() = default;
};

//==============================================================================
// GPU Compute Abstraction
//==============================================================================

class GPUComputeAbstraction
{
public:
    enum class ComputeBackend
    {
        Metal,      // Apple
        CUDA,       // NVIDIA
        OpenCL,     // Cross-platform
        Vulkan,     // Cross-platform
        DirectML    // Windows ML
    };

    virtual bool isAvailable() = 0;
    virtual ComputeBackend getBackend() = 0;

    // Convolution (for reverb)
    virtual void convolve(const float* input, int inputLen,
                          const float* kernel, int kernelLen,
                          float* output) = 0;

    // FFT
    virtual void fft(const float* input, float* outputReal, float* outputImag, int size) = 0;
    virtual void ifft(const float* inputReal, const float* inputImag, float* output, int size) = 0;

    virtual ~GPUComputeAbstraction() = default;
};

//==============================================================================
// App Lifecycle Abstraction
//==============================================================================

class AppLifecycleAbstraction
{
public:
    enum class AppState
    {
        Active,
        Inactive,
        Background,
        Suspended,
        Terminated
    };

    virtual void onStateChanged(std::function<void(AppState)> callback) = 0;
    virtual void onMemoryWarning(std::function<void()> callback) = 0;
    virtual void onLowPowerMode(std::function<void(bool)> callback) = 0;

    virtual bool isBackgroundAudioEnabled() = 0;
    virtual void enableBackgroundAudio(bool enable) = 0;

    virtual ~AppLifecycleAbstraction() = default;
};

//==============================================================================
// Platform Factory
//==============================================================================

class PlatformFactory
{
public:
    static PlatformFactory& getInstance()
    {
        static PlatformFactory instance;
        return instance;
    }

    PlatformInfo getPlatformInfo() const
    {
        PlatformInfo info;

#if JUCE_MAC
        info.type = PlatformType::macOS;
    #if defined(__arm64__)
        info.arch = Architecture::ARM64;
    #else
        info.arch = Architecture::x86_64;
    #endif
        info.supportsGPUCompute = true;  // Metal

#elif JUCE_IOS
        info.type = PlatformType::iOS;
        info.arch = Architecture::ARM64;
        info.supportsHaptics = true;
        info.supportsBiometrics = true;
        info.supportsAR = true;
        info.supportsGPUCompute = true;

#elif JUCE_WINDOWS
        info.type = PlatformType::Windows;
    #if defined(_M_ARM64)
        info.arch = Architecture::ARM64;
    #elif defined(_M_X64)
        info.arch = Architecture::x86_64;
    #else
        info.arch = Architecture::x86;
    #endif
        info.supportsGPUCompute = true;  // DirectML/CUDA

#elif JUCE_LINUX
        info.type = PlatformType::Linux;
    #if defined(__aarch64__)
        info.arch = Architecture::ARM64;
    #elif defined(__x86_64__)
        info.arch = Architecture::x86_64;
    #else
        info.arch = Architecture::x86;
    #endif
        info.supportsGPUCompute = true;  // OpenCL/CUDA

#elif JUCE_ANDROID
        info.type = PlatformType::Android;
    #if defined(__aarch64__)
        info.arch = Architecture::ARM64;
    #else
        info.arch = Architecture::ARM32;
    #endif
        info.supportsHaptics = true;

#else
        info.type = PlatformType::Unknown;
        info.arch = Architecture::Unknown;
#endif

#if JUCE_DEBUG
        info.isDebug = true;
#endif

        info.osVersion = juce::SystemStats::getOperatingSystemName().toStdString();
        info.deviceName = juce::SystemStats::getComputerName().toStdString();

        auto display = juce::Desktop::getInstance().getDisplays().getPrimaryDisplay();
        if (display)
        {
            info.screenWidth = display->userArea.getWidth();
            info.screenHeight = display->userArea.getHeight();
            info.screenScale = static_cast<float>(display->scale);
        }

        return info;
    }

    std::vector<AudioBackend> getAvailableAudioBackends() const
    {
        std::vector<AudioBackend> backends;

#if JUCE_MAC || JUCE_IOS
        backends.push_back(AudioBackend::CoreAudio);
        backends.push_back(AudioBackend::AVAudioEngine);
#endif

#if JUCE_WINDOWS
        backends.push_back(AudioBackend::WASAPI);
    #if JUCE_ASIO
        backends.push_back(AudioBackend::ASIO);
    #endif
        backends.push_back(AudioBackend::DirectSound);
#endif

#if JUCE_LINUX
    #if JUCE_ALSA
        backends.push_back(AudioBackend::ALSA);
    #endif
    #if JUCE_JACK
        backends.push_back(AudioBackend::JACK);
    #endif
        backends.push_back(AudioBackend::PulseAudio);
#endif

#if JUCE_ANDROID
        backends.push_back(AudioBackend::AAudio);
        backends.push_back(AudioBackend::Oboe);
        backends.push_back(AudioBackend::OpenSLES);
#endif

        return backends;
    }

    std::vector<AudioDeviceInfo> getAudioDevices() const
    {
        std::vector<AudioDeviceInfo> devices;

        auto& deviceManager = getAudioDeviceManager();
        auto deviceTypes = deviceManager.getAvailableDeviceTypes();

        for (auto* deviceType : deviceTypes)
        {
            deviceType->scanForDevices();
            auto deviceNames = deviceType->getDeviceNames();

            for (const auto& name : deviceNames)
            {
                AudioDeviceInfo info;
                info.name = name.toStdString();
                info.id = name.toStdString();

                // Determine backend
#if JUCE_MAC
                info.backend = AudioBackend::CoreAudio;
#elif JUCE_WINDOWS
                if (deviceType->getTypeName() == "ASIO")
                    info.backend = AudioBackend::ASIO;
                else if (deviceType->getTypeName() == "Windows Audio")
                    info.backend = AudioBackend::WASAPI;
                else
                    info.backend = AudioBackend::DirectSound;
#elif JUCE_LINUX
                info.backend = AudioBackend::ALSA;
#elif JUCE_ANDROID
                info.backend = AudioBackend::AAudio;
#endif

                devices.push_back(info);
            }
        }

        return devices;
    }

    std::string getPlatformString() const
    {
        auto info = getPlatformInfo();

        std::string platform;
        switch (info.type)
        {
            case PlatformType::macOS:   platform = "macOS"; break;
            case PlatformType::iOS:     platform = "iOS"; break;
            case PlatformType::Windows: platform = "Windows"; break;
            case PlatformType::Linux:   platform = "Linux"; break;
            case PlatformType::Android: platform = "Android"; break;
            default:                    platform = "Unknown"; break;
        }

        std::string arch;
        switch (info.arch)
        {
            case Architecture::ARM64:  arch = "ARM64"; break;
            case Architecture::x86_64: arch = "x64"; break;
            case Architecture::x86:    arch = "x86"; break;
            case Architecture::ARM32:  arch = "ARM"; break;
            default:                   arch = "Unknown"; break;
        }

        return platform + " (" + arch + ")";
    }

private:
    juce::AudioDeviceManager& getAudioDeviceManager() const
    {
        static juce::AudioDeviceManager deviceManager;
        return deviceManager;
    }
};

//==============================================================================
// Convenience Macros
//==============================================================================

#define EchoelPlatform PlatformFactory::getInstance()

// Platform-specific code blocks
#define ECHOEL_MACOS_ONLY    if constexpr (JUCE_MAC && !JUCE_IOS)
#define ECHOEL_IOS_ONLY      if constexpr (JUCE_IOS)
#define ECHOEL_WINDOWS_ONLY  if constexpr (JUCE_WINDOWS)
#define ECHOEL_LINUX_ONLY    if constexpr (JUCE_LINUX)
#define ECHOEL_ANDROID_ONLY  if constexpr (JUCE_ANDROID)
#define ECHOEL_DESKTOP_ONLY  if constexpr (JUCE_MAC || JUCE_WINDOWS || JUCE_LINUX)
#define ECHOEL_MOBILE_ONLY   if constexpr (JUCE_IOS || JUCE_ANDROID)
#define ECHOEL_APPLE_ONLY    if constexpr (JUCE_MAC || JUCE_IOS)

} // namespace Platform
} // namespace Echoelmusic
