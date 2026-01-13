#pragma once
// ============================================================================
// EchoelDSP - Android Audio Backend (AAudio/Oboe)
// ============================================================================
// High-performance audio for Android 8.0+ (API 26+)
// - AAudio: Native Android low-latency API
// - Oboe: Google's C++ wrapper with fallback to OpenSL ES
// ============================================================================

#include "../AudioBuffer.h"
#include "../SIMD.h"
#include <atomic>
#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <thread>

// Android-specific includes
#if defined(__ANDROID__)
#include <android/api-level.h>
#if __ANDROID_API__ >= 26
#define ECHOEL_HAS_AAUDIO 1
#include <aaudio/AAudio.h>
#endif
#endif

namespace Echoel::DSP::Android {

// ============================================================================
// Android Audio Configuration
// ============================================================================

enum class AndroidAudioAPI : uint8_t {
    Auto,       // Automatically select best API
    AAudio,     // AAudio (Android 8.0+, API 26+)
    OpenSLES    // OpenSL ES (fallback for older devices)
};

enum class PerformanceMode : uint8_t {
    None,           // No specific requirement
    LowLatency,     // Minimize latency (may use more power)
    PowerSaving     // Minimize power (may increase latency)
};

enum class SharingMode : uint8_t {
    Exclusive,      // Exclusive access (lowest latency)
    Shared          // Shared access (allows other apps)
};

enum class Direction : uint8_t {
    Output,         // Playback
    Input           // Recording
};

struct AndroidAudioConfig {
    // Audio format
    uint32_t sampleRate{48000};
    uint32_t channelCount{2};
    uint32_t framesPerBuffer{192};  // ~4ms at 48kHz

    // API selection
    AndroidAudioAPI preferredAPI{AndroidAudioAPI::Auto};
    PerformanceMode performanceMode{PerformanceMode::LowLatency};
    SharingMode sharingMode{SharingMode::Exclusive};

    // Device selection
    int32_t deviceId{0};  // 0 = default device

    // Format
    bool useFloat{true};  // Use 32-bit float (recommended)

    // Session
    int32_t sessionId{-1};  // Audio session ID (-1 = allocate new)
};

// ============================================================================
// Audio Callback
// ============================================================================

using AndroidAudioCallback = std::function<void(
    float* outputBuffer,
    int32_t numFrames,
    int32_t numChannels
)>;

using AndroidInputCallback = std::function<void(
    const float* inputBuffer,
    int32_t numFrames,
    int32_t numChannels
)>;

// ============================================================================
// Android Audio Device Info
// ============================================================================

struct AndroidAudioDevice {
    int32_t id{0};
    std::string name;
    int32_t type{0};  // TYPE_BUILTIN_SPEAKER, TYPE_WIRED_HEADPHONES, etc.
    int32_t channelCount{2};
    std::vector<int32_t> sampleRates;
    bool isInput{false};
    bool isOutput{true};
};

// ============================================================================
// AAudio Stream Wrapper
// ============================================================================

#if defined(ECHOEL_HAS_AAUDIO)

class AAudioStream {
public:
    AAudioStream() = default;
    ~AAudioStream() { close(); }

    // Non-copyable
    AAudioStream(const AAudioStream&) = delete;
    AAudioStream& operator=(const AAudioStream&) = delete;

    bool open(const AndroidAudioConfig& config, Direction direction) {
        AAudioStreamBuilder* builder = nullptr;
        aaudio_result_t result = AAudio_createStreamBuilder(&builder);
        if (result != AAUDIO_OK) {
            lastError_ = "Failed to create stream builder";
            return false;
        }

        // Configure stream
        AAudioStreamBuilder_setDirection(builder,
            direction == Direction::Output ? AAUDIO_DIRECTION_OUTPUT : AAUDIO_DIRECTION_INPUT);
        AAudioStreamBuilder_setSampleRate(builder, config.sampleRate);
        AAudioStreamBuilder_setChannelCount(builder, config.channelCount);
        AAudioStreamBuilder_setFormat(builder,
            config.useFloat ? AAUDIO_FORMAT_PCM_FLOAT : AAUDIO_FORMAT_PCM_I16);

        // Performance mode
        switch (config.performanceMode) {
            case PerformanceMode::LowLatency:
                AAudioStreamBuilder_setPerformanceMode(builder, AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);
                break;
            case PerformanceMode::PowerSaving:
                AAudioStreamBuilder_setPerformanceMode(builder, AAUDIO_PERFORMANCE_MODE_POWER_SAVING);
                break;
            default:
                AAudioStreamBuilder_setPerformanceMode(builder, AAUDIO_PERFORMANCE_MODE_NONE);
                break;
        }

        // Sharing mode
        AAudioStreamBuilder_setSharingMode(builder,
            config.sharingMode == SharingMode::Exclusive ?
            AAUDIO_SHARING_MODE_EXCLUSIVE : AAUDIO_SHARING_MODE_SHARED);

        // Buffer size
        AAudioStreamBuilder_setFramesPerDataCallback(builder, config.framesPerBuffer);

        // Device ID
        if (config.deviceId != 0) {
            AAudioStreamBuilder_setDeviceId(builder, config.deviceId);
        }

        // Session ID
        if (config.sessionId >= 0) {
            AAudioStreamBuilder_setSessionId(builder, config.sessionId);
        }

        // Set callbacks
        AAudioStreamBuilder_setDataCallback(builder, dataCallback, this);
        AAudioStreamBuilder_setErrorCallback(builder, errorCallback, this);

        // Open stream
        result = AAudioStreamBuilder_openStream(builder, &stream_);
        AAudioStreamBuilder_delete(builder);

        if (result != AAUDIO_OK) {
            lastError_ = "Failed to open AAudio stream: " + std::to_string(result);
            return false;
        }

        // Store actual configuration
        actualSampleRate_ = AAudioStream_getSampleRate(stream_);
        actualChannelCount_ = AAudioStream_getChannelCount(stream_);
        actualFramesPerBuffer_ = AAudioStream_getFramesPerBurst(stream_);

        direction_ = direction;
        return true;
    }

    void close() {
        if (stream_) {
            AAudioStream_requestStop(stream_);
            AAudioStream_close(stream_);
            stream_ = nullptr;
        }
    }

    bool start() {
        if (!stream_) return false;
        aaudio_result_t result = AAudioStream_requestStart(stream_);
        return result == AAUDIO_OK;
    }

    bool stop() {
        if (!stream_) return false;
        aaudio_result_t result = AAudioStream_requestStop(stream_);
        return result == AAUDIO_OK;
    }

    bool pause() {
        if (!stream_) return false;
        aaudio_result_t result = AAudioStream_requestPause(stream_);
        return result == AAUDIO_OK;
    }

    bool flush() {
        if (!stream_) return false;
        aaudio_result_t result = AAudioStream_requestFlush(stream_);
        return result == AAUDIO_OK;
    }

    // Getters
    int32_t getSampleRate() const { return actualSampleRate_; }
    int32_t getChannelCount() const { return actualChannelCount_; }
    int32_t getFramesPerBuffer() const { return actualFramesPerBuffer_; }
    int32_t getBufferSizeInFrames() const {
        return stream_ ? AAudioStream_getBufferSizeInFrames(stream_) : 0;
    }
    int32_t getXRunCount() const {
        return stream_ ? AAudioStream_getXRunCount(stream_) : 0;
    }

    double getLatencyMs() const {
        if (!stream_) return 0.0;
        int32_t frames = AAudioStream_getBufferSizeInFrames(stream_);
        return (frames * 1000.0) / actualSampleRate_;
    }

    // Callbacks
    void setOutputCallback(AndroidAudioCallback callback) {
        outputCallback_ = std::move(callback);
    }

    void setInputCallback(AndroidInputCallback callback) {
        inputCallback_ = std::move(callback);
    }

    const std::string& getLastError() const { return lastError_; }

private:
    AAudioStream* stream_{nullptr};
    Direction direction_{Direction::Output};

    int32_t actualSampleRate_{0};
    int32_t actualChannelCount_{0};
    int32_t actualFramesPerBuffer_{0};

    AndroidAudioCallback outputCallback_;
    AndroidInputCallback inputCallback_;

    std::string lastError_;

    // Static AAudio callbacks
    static aaudio_data_callback_result_t dataCallback(
        AAudioStream* stream,
        void* userData,
        void* audioData,
        int32_t numFrames
    ) {
        auto* self = static_cast<AAudioStream*>(userData);
        if (!self) return AAUDIO_CALLBACK_RESULT_STOP;

        if (self->direction_ == Direction::Output && self->outputCallback_) {
            self->outputCallback_(
                static_cast<float*>(audioData),
                numFrames,
                self->actualChannelCount_
            );
        } else if (self->direction_ == Direction::Input && self->inputCallback_) {
            self->inputCallback_(
                static_cast<const float*>(audioData),
                numFrames,
                self->actualChannelCount_
            );
        }

        return AAUDIO_CALLBACK_RESULT_CONTINUE;
    }

    static void errorCallback(
        AAudioStream* stream,
        void* userData,
        aaudio_result_t error
    ) {
        auto* self = static_cast<AAudioStream*>(userData);
        if (!self) return;

        self->lastError_ = "AAudio error: " + std::to_string(error);

        // Handle disconnection - restart stream
        if (error == AAUDIO_ERROR_DISCONNECTED) {
            // Stream will be recreated by the backend
        }
    }
};

#endif // ECHOEL_HAS_AAUDIO

// ============================================================================
// Android Audio Backend (Main Class)
// ============================================================================

class AndroidAudioBackend {
public:
    AndroidAudioBackend() = default;
    ~AndroidAudioBackend() { stop(); }

    // Non-copyable
    AndroidAudioBackend(const AndroidAudioBackend&) = delete;
    AndroidAudioBackend& operator=(const AndroidAudioBackend&) = delete;

    // ========================================================================
    // Device Enumeration
    // ========================================================================

    static std::vector<AndroidAudioDevice> enumerateDevices() {
        std::vector<AndroidAudioDevice> devices;

        // Default devices
        AndroidAudioDevice defaultOutput;
        defaultOutput.id = 0;
        defaultOutput.name = "Default Output";
        defaultOutput.isOutput = true;
        defaultOutput.channelCount = 2;
        defaultOutput.sampleRates = {44100, 48000};
        devices.push_back(defaultOutput);

        AndroidAudioDevice defaultInput;
        defaultInput.id = 0;
        defaultInput.name = "Default Input";
        defaultInput.isInput = true;
        defaultInput.channelCount = 1;
        defaultInput.sampleRates = {44100, 48000};
        devices.push_back(defaultInput);

        // Additional devices would be enumerated via AudioManager JNI
        return devices;
    }

    static AndroidAudioAPI getBestAvailableAPI() {
#if defined(ECHOEL_HAS_AAUDIO)
        return AndroidAudioAPI::AAudio;
#else
        return AndroidAudioAPI::OpenSLES;
#endif
    }

    static int32_t getOptimalSampleRate() {
        // Would query AudioManager via JNI for device's native sample rate
        return 48000;
    }

    static int32_t getOptimalFramesPerBuffer() {
        // Would query AudioManager via JNI for device's optimal buffer size
        return 192;  // ~4ms at 48kHz
    }

    // ========================================================================
    // Initialization
    // ========================================================================

    bool initialize(const AndroidAudioConfig& config) {
        config_ = config;

        // Select API
        if (config.preferredAPI == AndroidAudioAPI::Auto) {
            currentAPI_ = getBestAvailableAPI();
        } else {
            currentAPI_ = config.preferredAPI;
        }

#if defined(ECHOEL_HAS_AAUDIO)
        if (currentAPI_ == AndroidAudioAPI::AAudio) {
            outputStream_ = std::make_unique<AAudioStream>();
            inputStream_ = std::make_unique<AAudioStream>();
            return true;
        }
#endif

        // OpenSL ES fallback would be implemented here
        return initializeOpenSLES();
    }

    // ========================================================================
    // Audio Streaming
    // ========================================================================

    bool startOutput(AndroidAudioCallback callback) {
#if defined(ECHOEL_HAS_AAUDIO)
        if (currentAPI_ == AndroidAudioAPI::AAudio && outputStream_) {
            if (!outputStream_->open(config_, Direction::Output)) {
                lastError_ = outputStream_->getLastError();
                return false;
            }
            outputStream_->setOutputCallback(std::move(callback));
            if (!outputStream_->start()) {
                lastError_ = "Failed to start AAudio output stream";
                return false;
            }
            outputRunning_.store(true, std::memory_order_release);
            return true;
        }
#endif
        return startOpenSLESOutput(std::move(callback));
    }

    bool startInput(AndroidInputCallback callback) {
#if defined(ECHOEL_HAS_AAUDIO)
        if (currentAPI_ == AndroidAudioAPI::AAudio && inputStream_) {
            AndroidAudioConfig inputConfig = config_;
            inputConfig.channelCount = 1;  // Mono input typically

            if (!inputStream_->open(inputConfig, Direction::Input)) {
                lastError_ = inputStream_->getLastError();
                return false;
            }
            inputStream_->setInputCallback(std::move(callback));
            if (!inputStream_->start()) {
                lastError_ = "Failed to start AAudio input stream";
                return false;
            }
            inputRunning_.store(true, std::memory_order_release);
            return true;
        }
#endif
        return startOpenSLESInput(std::move(callback));
    }

    void stopOutput() {
        outputRunning_.store(false, std::memory_order_release);
#if defined(ECHOEL_HAS_AAUDIO)
        if (outputStream_) {
            outputStream_->stop();
            outputStream_->close();
        }
#endif
    }

    void stopInput() {
        inputRunning_.store(false, std::memory_order_release);
#if defined(ECHOEL_HAS_AAUDIO)
        if (inputStream_) {
            inputStream_->stop();
            inputStream_->close();
        }
#endif
    }

    void stop() {
        stopOutput();
        stopInput();
    }

    // ========================================================================
    // Status
    // ========================================================================

    bool isOutputRunning() const noexcept {
        return outputRunning_.load(std::memory_order_acquire);
    }

    bool isInputRunning() const noexcept {
        return inputRunning_.load(std::memory_order_acquire);
    }

    AndroidAudioAPI getCurrentAPI() const noexcept {
        return currentAPI_;
    }

    // ========================================================================
    // Latency
    // ========================================================================

    double getOutputLatencyMs() const {
#if defined(ECHOEL_HAS_AAUDIO)
        if (outputStream_) {
            return outputStream_->getLatencyMs();
        }
#endif
        return (config_.framesPerBuffer * 1000.0) / config_.sampleRate;
    }

    double getInputLatencyMs() const {
#if defined(ECHOEL_HAS_AAUDIO)
        if (inputStream_) {
            return inputStream_->getLatencyMs();
        }
#endif
        return (config_.framesPerBuffer * 1000.0) / config_.sampleRate;
    }

    double getTotalLatencyMs() const {
        return getOutputLatencyMs() + getInputLatencyMs();
    }

    // ========================================================================
    // Statistics
    // ========================================================================

    int32_t getOutputXRunCount() const {
#if defined(ECHOEL_HAS_AAUDIO)
        return outputStream_ ? outputStream_->getXRunCount() : 0;
#else
        return 0;
#endif
    }

    int32_t getInputXRunCount() const {
#if defined(ECHOEL_HAS_AAUDIO)
        return inputStream_ ? inputStream_->getXRunCount() : 0;
#else
        return 0;
#endif
    }

    // ========================================================================
    // Error Handling
    // ========================================================================

    const std::string& getLastError() const noexcept {
        return lastError_;
    }

private:
    AndroidAudioConfig config_;
    AndroidAudioAPI currentAPI_{AndroidAudioAPI::Auto};

#if defined(ECHOEL_HAS_AAUDIO)
    std::unique_ptr<AAudioStream> outputStream_;
    std::unique_ptr<AAudioStream> inputStream_;
#endif

    std::atomic<bool> outputRunning_{false};
    std::atomic<bool> inputRunning_{false};

    std::string lastError_;

    // OpenSL ES fallback (for Android < 8.0)
    bool initializeOpenSLES() {
        // Would initialize SLEngineItf, etc.
        return true;
    }

    bool startOpenSLESOutput(AndroidAudioCallback callback) {
        // Would create and start OpenSL ES player
        return false;
    }

    bool startOpenSLESInput(AndroidInputCallback callback) {
        // Would create and start OpenSL ES recorder
        return false;
    }
};

// ============================================================================
// Android Audio Session Manager
// ============================================================================

class AndroidAudioSession {
public:
    enum class ContentType : int32_t {
        Unknown = 0,
        Speech = 1,
        Music = 2,
        Movie = 3,
        Sonification = 4
    };

    enum class Usage : int32_t {
        Unknown = 0,
        Media = 1,
        VoiceCommunication = 2,
        VoiceCommunicationSignalling = 3,
        Alarm = 4,
        Notification = 5,
        NotificationRingtone = 6,
        NotificationCommunicationRequest = 7,
        NotificationCommunicationInstant = 8,
        NotificationCommunicationDelayed = 9,
        NotificationEvent = 10,
        AssistanceAccessibility = 11,
        AssistanceNavigationGuidance = 12,
        AssistanceSonification = 13,
        Game = 14
    };

    struct AudioAttributes {
        ContentType contentType{ContentType::Music};
        Usage usage{Usage::Media};
        bool allowedCaptureByAll{false};
        bool allowedCaptureBySystem{true};
    };

    static int32_t allocateSessionId() {
        // Would call AudioManager.generateAudioSessionId() via JNI
        return nextSessionId_++;
    }

    static void setAudioAttributes(int32_t sessionId, const AudioAttributes& attributes) {
        // Would set attributes via AudioAttributes.Builder and AudioManager
    }

private:
    static inline std::atomic<int32_t> nextSessionId_{1};
};

// ============================================================================
// Android Audio Focus Manager
// ============================================================================

class AndroidAudioFocus {
public:
    enum class FocusGain : int32_t {
        Gain = 1,                    // Permanent focus
        GainTransient = 2,           // Temporary focus
        GainTransientMayDuck = 3,    // Temporary, others can duck
        GainTransientExclusive = 4   // Temporary, others must pause
    };

    enum class FocusResult : int32_t {
        Granted = 1,
        Denied = 0,
        Delayed = 2
    };

    using FocusChangeCallback = std::function<void(FocusResult focus)>;

    static FocusResult requestFocus(FocusGain gain, FocusChangeCallback callback) {
        // Would request audio focus via AudioManager.requestAudioFocus()
        focusCallback_ = std::move(callback);
        return FocusResult::Granted;
    }

    static void abandonFocus() {
        // Would abandon audio focus via AudioManager.abandonAudioFocus()
        focusCallback_ = nullptr;
    }

private:
    static inline FocusChangeCallback focusCallback_;
};

// ============================================================================
// Android Bluetooth Audio Support
// ============================================================================

class AndroidBluetoothAudio {
public:
    enum class BluetoothProfile : int32_t {
        A2DP = 2,      // Advanced Audio Distribution Profile
        Headset = 1,   // Headset Profile (HSP)
        HearingAid = 21
    };

    static bool isBluetoothA2dpOn() {
        // Would check via AudioManager.isBluetoothA2dpOn()
        return false;
    }

    static bool isBluetoothScoOn() {
        // Would check via AudioManager.isBluetoothScoOn()
        return false;
    }

    static void startBluetoothSco() {
        // Would call AudioManager.startBluetoothSco()
    }

    static void stopBluetoothSco() {
        // Would call AudioManager.stopBluetoothSco()
    }
};

} // namespace Echoel::DSP::Android
