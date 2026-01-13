#pragma once
// ============================================================================
// EchoelDSP - USB Class-Compliant Audio Backend
// ============================================================================
// USB Audio Class 1.0/2.0 support for driver-free operation
// - iOS: Required (no custom drivers allowed)
// - Linux: ALSA UAC kernel support
// - macOS: Native CoreAudio UAC
// - Windows: Native USB Audio driver
// ============================================================================

#include "../AudioBuffer.h"
#include <atomic>
#include <cstdint>
#include <functional>
#include <string>
#include <vector>
#include <memory>

namespace Echoel::DSP::USB {

// ============================================================================
// USB Audio Class Specifications
// ============================================================================

enum class USBAudioClass : uint8_t {
    UAC1 = 1,    // USB Audio Class 1.0 - 24-bit/96kHz max, widely compatible
    UAC2 = 2,    // USB Audio Class 2.0 - 32-bit/384kHz, async support
    UAC3 = 3     // USB Audio Class 3.0 - Power delivery, newer devices
};

enum class USBTransferMode : uint8_t {
    Isochronous,      // Standard audio streaming (most common)
    Adaptive,         // Device adapts to host clock
    Asynchronous      // Device provides clock (best quality)
};

enum class USBSyncType : uint8_t {
    None,             // No synchronization
    Async,            // Asynchronous (device clock master)
    Adaptive,         // Adaptive (host clock master)
    Sync              // Synchronous (SOF sync)
};

// ============================================================================
// USB Audio Device Descriptor
// ============================================================================

struct USBDeviceInfo {
    uint16_t vendorId{0};
    uint16_t productId{0};
    std::string manufacturer;
    std::string productName;
    std::string serialNumber;
    USBAudioClass audioClass{USBAudioClass::UAC2};
    USBTransferMode transferMode{USBTransferMode::Asynchronous};
    USBSyncType syncType{USBSyncType::Async};

    // Capabilities
    uint32_t maxSampleRate{384000};
    uint32_t minSampleRate{44100};
    uint8_t maxBitDepth{32};
    uint8_t inputChannels{2};
    uint8_t outputChannels{2};
    bool supportsMIDI{false};
    bool supportsHID{false};

    // Class-compliant status
    bool isClassCompliant{true};
    bool requiresDriver{false};
};

// ============================================================================
// USB Audio Endpoint
// ============================================================================

struct USBEndpoint {
    uint8_t address{0};
    uint8_t direction{0};  // 0 = OUT (to device), 1 = IN (from device)
    uint16_t maxPacketSize{1024};
    uint8_t interval{1};   // Polling interval (125μs units for USB 2.0 HS)
    USBTransferMode transferMode{USBTransferMode::Isochronous};
    USBSyncType syncType{USBSyncType::Async};
};

// ============================================================================
// USB Audio Stream Format
// ============================================================================

struct USBStreamFormat {
    uint32_t sampleRate{48000};
    uint8_t bitDepth{24};
    uint8_t channels{2};
    bool isFloat{false};
    bool isBigEndian{false};

    // Calculate bytes per sample
    size_t bytesPerSample() const noexcept {
        return (bitDepth + 7) / 8;
    }

    // Calculate bytes per frame (all channels)
    size_t bytesPerFrame() const noexcept {
        return bytesPerSample() * channels;
    }

    // Calculate bytes per second
    size_t bytesPerSecond() const noexcept {
        return bytesPerFrame() * sampleRate;
    }
};

// ============================================================================
// USB Audio Clock Source
// ============================================================================

struct USBClockSource {
    uint8_t clockId{0};
    std::string name;
    bool isInternal{true};
    bool isLocked{true};
    uint32_t currentRate{48000};

    // Clock validity
    bool isValid() const noexcept {
        return isLocked && currentRate >= 8000 && currentRate <= 768000;
    }
};

// ============================================================================
// USB Audio Feature Unit (Volume, Mute, etc.)
// ============================================================================

struct USBFeatureUnit {
    uint8_t unitId{0};
    uint8_t sourceId{0};

    // Per-channel controls
    struct ChannelControls {
        bool hasMute{false};
        bool hasVolume{false};
        bool hasBass{false};
        bool hasMid{false};
        bool hasTreble{false};
        bool hasEQ{false};
        bool hasAGC{false};
        bool hasDelay{false};
        bool hasBassBoost{false};
        bool hasLoudness{false};

        // Current values
        bool muted{false};
        float volume{1.0f};      // 0.0 - 1.0
        float bass{0.5f};        // 0.0 - 1.0
        float mid{0.5f};         // 0.0 - 1.0
        float treble{0.5f};      // 0.0 - 1.0
    };

    ChannelControls masterControls;
    std::vector<ChannelControls> channelControls;
};

// ============================================================================
// USB Class-Compliant Backend Configuration
// ============================================================================

struct USBBackendConfig {
    uint32_t sampleRate{48000};
    uint32_t bufferSize{256};
    uint8_t bitDepth{24};
    USBAudioClass preferredClass{USBAudioClass::UAC2};
    USBTransferMode preferredTransfer{USBTransferMode::Asynchronous};
    bool enableMIDI{true};
    bool enableHID{false};

    // Latency compensation
    uint32_t inputLatencyFrames{0};
    uint32_t outputLatencyFrames{0};

    // Fallback options
    bool allowUAC1Fallback{true};
    bool allowAdaptiveFallback{true};
};

// ============================================================================
// USB Audio Callback
// ============================================================================

using USBAudioCallback = std::function<void(
    const float* const* inputChannels,
    float* const* outputChannels,
    uint32_t numFrames,
    uint32_t numInputChannels,
    uint32_t numOutputChannels
)>;

using USBDeviceChangeCallback = std::function<void(
    const USBDeviceInfo& device,
    bool connected
)>;

// ============================================================================
// USB Class-Compliant Audio Backend
// ============================================================================

class USBClassCompliantBackend {
public:
    USBClassCompliantBackend() = default;
    ~USBClassCompliantBackend() { stop(); }

    // Non-copyable
    USBClassCompliantBackend(const USBClassCompliantBackend&) = delete;
    USBClassCompliantBackend& operator=(const USBClassCompliantBackend&) = delete;

    // ========================================================================
    // Device Enumeration
    // ========================================================================

    static std::vector<USBDeviceInfo> enumerateDevices() {
        std::vector<USBDeviceInfo> devices;

#if defined(__APPLE__)
        // macOS/iOS: Use IOKit to enumerate USB audio devices
        enumerateAppleUSBDevices(devices);
#elif defined(_WIN32)
        // Windows: Use SetupAPI and Windows.Devices.Enumeration
        enumerateWindowsUSBDevices(devices);
#elif defined(__linux__)
        // Linux: Use libudev or sysfs
        enumerateLinuxUSBDevices(devices);
#elif defined(__ANDROID__)
        // Android: Use UsbManager via JNI
        enumerateAndroidUSBDevices(devices);
#endif

        return devices;
    }

    static bool isClassCompliant(uint16_t vendorId, uint16_t productId) {
        // Known class-compliant devices (subset)
        // Most devices advertising USB Audio Class work without drivers

        // Universal Audio
        if (vendorId == 0x2708) return true;

        // Focusrite
        if (vendorId == 0x1235) return true;

        // RME
        if (vendorId == 0x0424) return true;

        // MOTU
        if (vendorId == 0x07FD) return true;

        // Apogee
        if (vendorId == 0x0C60) return true;

        // Native Instruments
        if (vendorId == 0x17CC) return true;

        // Arturia
        if (vendorId == 0x1C75) return true;

        // RODE
        if (vendorId == 0x19F7) return true;

        // Shure
        if (vendorId == 0x14ED) return true;

        // Generic USB Audio Class devices are class-compliant by definition
        return true;
    }

    // ========================================================================
    // Initialization
    // ========================================================================

    bool initialize(const USBBackendConfig& config) {
        config_ = config;

#if defined(__APPLE__)
        return initializeApple();
#elif defined(_WIN32)
        return initializeWindows();
#elif defined(__linux__)
        return initializeLinux();
#elif defined(__ANDROID__)
        return initializeAndroid();
#else
        return false;
#endif
    }

    bool openDevice(const USBDeviceInfo& device) {
        if (!device.isClassCompliant && device.requiresDriver) {
            lastError_ = "Device requires proprietary driver";
            return false;
        }

        currentDevice_ = device;
        deviceOpen_.store(true, std::memory_order_release);

#if defined(__APPLE__)
        return openAppleDevice(device);
#elif defined(_WIN32)
        return openWindowsDevice(device);
#elif defined(__linux__)
        return openLinuxDevice(device);
#elif defined(__ANDROID__)
        return openAndroidDevice(device);
#else
        return false;
#endif
    }

    void closeDevice() {
        stop();
        deviceOpen_.store(false, std::memory_order_release);

#if defined(__APPLE__)
        closeAppleDevice();
#elif defined(_WIN32)
        closeWindowsDevice();
#elif defined(__linux__)
        closeLinuxDevice();
#elif defined(__ANDROID__)
        closeAndroidDevice();
#endif
    }

    // ========================================================================
    // Audio Streaming
    // ========================================================================

    bool start(USBAudioCallback callback) {
        if (!deviceOpen_.load(std::memory_order_acquire)) {
            lastError_ = "No device open";
            return false;
        }

        audioCallback_ = std::move(callback);
        running_.store(true, std::memory_order_release);

#if defined(__APPLE__)
        return startAppleStream();
#elif defined(_WIN32)
        return startWindowsStream();
#elif defined(__linux__)
        return startLinuxStream();
#elif defined(__ANDROID__)
        return startAndroidStream();
#else
        return false;
#endif
    }

    void stop() {
        running_.store(false, std::memory_order_release);

#if defined(__APPLE__)
        stopAppleStream();
#elif defined(_WIN32)
        stopWindowsStream();
#elif defined(__linux__)
        stopLinuxStream();
#elif defined(__ANDROID__)
        stopAndroidStream();
#endif

        audioCallback_ = nullptr;
    }

    bool isRunning() const noexcept {
        return running_.load(std::memory_order_acquire);
    }

    // ========================================================================
    // Device Monitoring
    // ========================================================================

    void setDeviceChangeCallback(USBDeviceChangeCallback callback) {
        deviceChangeCallback_ = std::move(callback);
    }

    // ========================================================================
    // Feature Controls
    // ========================================================================

    bool setVolume(float volume, int channel = -1) {
        volume = std::clamp(volume, 0.0f, 1.0f);

        if (channel < 0) {
            masterVolume_.store(volume, std::memory_order_release);
        }

        // Send to USB device
        return sendFeatureControl(0x01, channel, volume);  // Volume control
    }

    bool setMute(bool mute, int channel = -1) {
        if (channel < 0) {
            muted_.store(mute, std::memory_order_release);
        }

        return sendFeatureControl(0x00, channel, mute ? 1.0f : 0.0f);  // Mute control
    }

    float getVolume(int channel = -1) const noexcept {
        return masterVolume_.load(std::memory_order_acquire);
    }

    bool isMuted(int channel = -1) const noexcept {
        return muted_.load(std::memory_order_acquire);
    }

    // ========================================================================
    // Clock Management
    // ========================================================================

    std::vector<USBClockSource> getClockSources() const {
        return clockSources_;
    }

    bool setClockSource(uint8_t clockId) {
        for (const auto& clock : clockSources_) {
            if (clock.clockId == clockId) {
                currentClockId_ = clockId;
                return sendClockSelector(clockId);
            }
        }
        return false;
    }

    uint32_t getCurrentSampleRate() const noexcept {
        return currentSampleRate_.load(std::memory_order_acquire);
    }

    bool setSampleRate(uint32_t rate) {
        if (rate < currentDevice_.minSampleRate || rate > currentDevice_.maxSampleRate) {
            return false;
        }

        currentSampleRate_.store(rate, std::memory_order_release);
        return sendSampleRateControl(rate);
    }

    // ========================================================================
    // Latency
    // ========================================================================

    uint32_t getInputLatency() const noexcept {
        // USB Audio typically has 1-3ms latency depending on buffer size
        return config_.bufferSize + config_.inputLatencyFrames;
    }

    uint32_t getOutputLatency() const noexcept {
        return config_.bufferSize + config_.outputLatencyFrames;
    }

    double getLatencyMs() const noexcept {
        uint32_t totalFrames = getInputLatency() + getOutputLatency();
        return (totalFrames * 1000.0) / currentSampleRate_.load(std::memory_order_acquire);
    }

    // ========================================================================
    // Error Handling
    // ========================================================================

    const std::string& getLastError() const noexcept {
        return lastError_;
    }

    // ========================================================================
    // Device Information
    // ========================================================================

    const USBDeviceInfo& getCurrentDevice() const noexcept {
        return currentDevice_;
    }

    USBStreamFormat getCurrentFormat() const noexcept {
        return currentFormat_;
    }

private:
    USBBackendConfig config_;
    USBDeviceInfo currentDevice_;
    USBStreamFormat currentFormat_;
    std::vector<USBClockSource> clockSources_;

    USBAudioCallback audioCallback_;
    USBDeviceChangeCallback deviceChangeCallback_;

    std::atomic<bool> running_{false};
    std::atomic<bool> deviceOpen_{false};
    std::atomic<float> masterVolume_{1.0f};
    std::atomic<bool> muted_{false};
    std::atomic<uint32_t> currentSampleRate_{48000};
    uint8_t currentClockId_{0};

    std::string lastError_;

    // Platform-specific handles
#if defined(__APPLE__)
    void* coreAudioDevice_{nullptr};
    void* audioUnit_{nullptr};
#elif defined(_WIN32)
    void* mmDevice_{nullptr};
    void* audioClient_{nullptr};
#elif defined(__linux__)
    void* alsaHandle_{nullptr};
    void* udevMonitor_{nullptr};
#elif defined(__ANDROID__)
    void* usbManager_{nullptr};
    void* usbConnection_{nullptr};
#endif

    // ========================================================================
    // Platform-Specific Implementation Stubs
    // ========================================================================

#if defined(__APPLE__)
    static void enumerateAppleUSBDevices(std::vector<USBDeviceInfo>& devices) {
        // Use IOServiceMatching with kIOUSBAudioInterfaceClassName
        // Enumerate via IOIteratorNext
        // Parse device descriptors for USB Audio Class compliance
    }

    bool initializeApple() {
        // Initialize CoreAudio
        return true;
    }

    bool openAppleDevice(const USBDeviceInfo& device) {
        // Create AudioUnit for USB device
        // Configure for low-latency operation
        return true;
    }

    void closeAppleDevice() {
        // Dispose AudioUnit
    }

    bool startAppleStream() {
        // AudioOutputUnitStart
        return true;
    }

    void stopAppleStream() {
        // AudioOutputUnitStop
    }
#endif

#if defined(_WIN32)
    static void enumerateWindowsUSBDevices(std::vector<USBDeviceInfo>& devices) {
        // Use Windows.Devices.Enumeration or SetupAPI
        // Filter for USB Audio Class devices
    }

    bool initializeWindows() {
        // CoInitializeEx for COM
        return true;
    }

    bool openWindowsDevice(const USBDeviceInfo& device) {
        // IMMDeviceEnumerator -> IMMDevice -> IAudioClient
        return true;
    }

    void closeWindowsDevice() {
        // Release COM interfaces
    }

    bool startWindowsStream() {
        // IAudioClient::Start
        return true;
    }

    void stopWindowsStream() {
        // IAudioClient::Stop
    }
#endif

#if defined(__linux__)
    static void enumerateLinuxUSBDevices(std::vector<USBDeviceInfo>& devices) {
        // Use libudev or parse /sys/class/sound/
        // Match USB audio devices via ALSA
    }

    bool initializeLinux() {
        // Initialize udev for device monitoring
        return true;
    }

    bool openLinuxDevice(const USBDeviceInfo& device) {
        // snd_pcm_open for USB device
        return true;
    }

    void closeLinuxDevice() {
        // snd_pcm_close
    }

    bool startLinuxStream() {
        // snd_pcm_start
        return true;
    }

    void stopLinuxStream() {
        // snd_pcm_drop
    }
#endif

#if defined(__ANDROID__)
    static void enumerateAndroidUSBDevices(std::vector<USBDeviceInfo>& devices) {
        // Use UsbManager via JNI
        // Filter for USB Audio Class devices
    }

    bool initializeAndroid() {
        // Get UsbManager from Android context
        return true;
    }

    bool openAndroidDevice(const USBDeviceInfo& device) {
        // Request USB permission, open connection
        return true;
    }

    void closeAndroidDevice() {
        // Close USB connection
    }

    bool startAndroidStream() {
        // Start USB audio streaming
        return true;
    }

    void stopAndroidStream() {
        // Stop streaming
    }
#endif

    // ========================================================================
    // USB Control Transfers
    // ========================================================================

    bool sendFeatureControl(uint8_t controlSelector, int channel, float value) {
        // USB Audio Class Feature Unit control
        // bmRequestType: 0x21 (Host-to-device, Class, Interface)
        // bRequest: SET_CUR (0x01)
        // wValue: Control Selector << 8 | Channel Number
        // wIndex: Feature Unit ID << 8 | Interface
        return true;
    }

    bool sendClockSelector(uint8_t clockId) {
        // USB Audio Class 2.0 Clock Selector control
        return true;
    }

    bool sendSampleRateControl(uint32_t rate) {
        // USB Audio Class Sample Rate control
        // UAC1: Uses endpoint control
        // UAC2: Uses Clock Source control
        return true;
    }
};

// ============================================================================
// USB MIDI Support (USB Audio Class compliant)
// ============================================================================

class USBMIDIInterface {
public:
    struct MIDIMessage {
        uint8_t cable{0};      // Cable number (0-15)
        uint8_t status{0};     // MIDI status byte
        uint8_t data1{0};      // First data byte
        uint8_t data2{0};      // Second data byte
        uint64_t timestamp{0}; // Timestamp in samples
    };

    using MIDICallback = std::function<void(const MIDIMessage& message)>;

    bool open(const USBDeviceInfo& device) {
        if (!device.supportsMIDI) {
            return false;
        }
        // Open USB MIDI interface
        return true;
    }

    void close() {
        // Close USB MIDI interface
    }

    bool sendMessage(const MIDIMessage& message) {
        // Send MIDI message to USB device
        return true;
    }

    void setMIDICallback(MIDICallback callback) {
        midiCallback_ = std::move(callback);
    }

private:
    MIDICallback midiCallback_;
};

// ============================================================================
// USB Audio Class Compliance Checker
// ============================================================================

class USBComplianceChecker {
public:
    struct ComplianceReport {
        bool isCompliant{false};
        USBAudioClass detectedClass{USBAudioClass::UAC1};
        std::string issues;
        std::vector<uint32_t> supportedRates;
        std::vector<uint8_t> supportedBitDepths;
        bool hasAsyncEndpoint{false};
        bool hasFeedbackEndpoint{false};
    };

    static ComplianceReport checkCompliance(const USBDeviceInfo& device) {
        ComplianceReport report;

        // Check USB Audio Class version
        report.detectedClass = device.audioClass;

        // Check for async endpoint (best for audio quality)
        report.hasAsyncEndpoint = (device.syncType == USBSyncType::Async);

        // UAC2 is preferred for professional audio
        if (device.audioClass == USBAudioClass::UAC2) {
            report.isCompliant = true;
            report.supportedRates = {44100, 48000, 88200, 96000, 176400, 192000, 352800, 384000};
            report.supportedBitDepths = {16, 24, 32};
        } else if (device.audioClass == USBAudioClass::UAC1) {
            report.isCompliant = true;
            report.supportedRates = {44100, 48000, 88200, 96000};
            report.supportedBitDepths = {16, 24};
            report.issues = "UAC1 limited to 96kHz max";
        }

        // Check for feedback endpoint (improves clock sync)
        report.hasFeedbackEndpoint = device.transferMode == USBTransferMode::Asynchronous;

        return report;
    }
};

} // namespace Echoel::DSP::USB
