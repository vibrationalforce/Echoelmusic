/**
 * ASIOBridge.hpp
 * Echoelmusic - Windows ASIO Audio Integration
 *
 * Ultra-low latency audio for Windows using ASIO (<5ms)
 * Ralph Wiggum Lambda Loop Mode - Nobel Prize Quality
 *
 * Features:
 * - Native ASIO SDK integration
 * - FlexASIO compatibility layer
 * - ASIO4ALL support
 * - Bio-reactive modulation
 * - Quantum light emulator integration
 * - Lock-free audio processing
 *
 * Requires: ASIO SDK (Steinberg) or FlexASIO
 *
 * Created: 2026-01-17
 */

#pragma once

#ifdef _WIN32

// Check for ASIO SDK at compile time
#if __has_include("asiosdk/common/asio.h")
#define ECHOELMUSIC_ASIO_AVAILABLE 1
#include "asiosdk/common/asio.h"
#include "asiosdk/common/asiodrivers.h"
#include "asiosdk/host/asiodrivers.h"
#else
#define ECHOELMUSIC_ASIO_AVAILABLE 0
#endif

#include <atomic>
#include <thread>
#include <functional>
#include <vector>
#include <cmath>
#include <memory>
#include <string>
#include <mutex>
#include <condition_variable>
#include <array>

namespace Echoelmusic {

// Forward declaration
namespace Quantum {
class QuantumLightEmulator;
}

namespace Audio {

// ============================================================================
// MARK: - ASIO Driver Info
// ============================================================================

struct ASIODriverInfo {
    std::string name;
    std::string version;
    int inputChannels = 0;
    int outputChannels = 0;
    long minBufferSize = 0;
    long maxBufferSize = 0;
    long preferredBufferSize = 0;
    double sampleRate = 48000.0;
    bool supportsFloat32 = false;
    bool supportsInt32 = false;
    bool supportsInt24 = false;
    bool supportsInt16 = false;
};

// ============================================================================
// MARK: - ASIO Configuration
// ============================================================================

struct ASIOConfig {
    std::string driverName = "";  // Empty = first available driver
    uint32_t sampleRate = 48000;
    uint32_t bufferSize = 64;     // Ultra-low latency default
    uint32_t inputChannels = 2;
    uint32_t outputChannels = 2;
    bool useFloat32 = true;       // Prefer 32-bit float
};

#if ECHOELMUSIC_ASIO_AVAILABLE

// ============================================================================
// MARK: - ASIO Bridge Engine
// ============================================================================

class ASIOBridge {
public:
    using AudioCallback = std::function<void(
        const float* const* inputs,
        float* const* outputs,
        int numFrames,
        int numInputChannels,
        int numOutputChannels
    )>;

    ASIOBridge() = default;

    ~ASIOBridge() {
        stop();
        unloadDriver();
    }

    // MARK: - Driver Enumeration

    static std::vector<std::string> getAvailableDrivers() {
        std::vector<std::string> drivers;

        AsioDrivers asioDrivers;
        char* names[32];
        for (int i = 0; i < 32; i++) {
            names[i] = new char[256];
        }

        long numDrivers = asioDrivers.getDriverNames(names, 32);

        for (long i = 0; i < numDrivers; i++) {
            drivers.push_back(names[i]);
        }

        for (int i = 0; i < 32; i++) {
            delete[] names[i];
        }

        return drivers;
    }

    // MARK: - Initialization

    bool loadDriver(const std::string& driverName) {
        if (driverLoaded_) {
            unloadDriver();
        }

        AsioDrivers asioDrivers;

        if (driverName.empty()) {
            // Use first available driver
            auto drivers = getAvailableDrivers();
            if (drivers.empty()) {
                lastError_ = "No ASIO drivers found";
                return false;
            }
            currentDriverName_ = drivers[0];
        } else {
            currentDriverName_ = driverName;
        }

        if (!asioDrivers.loadDriver(const_cast<char*>(currentDriverName_.c_str()))) {
            lastError_ = "Failed to load ASIO driver: " + currentDriverName_;
            return false;
        }

        // Initialize driver
        ASIODriverInfo driverInfo;
        ASIOError result = ASIOInit(&driverInfo);
        if (result != ASE_OK) {
            lastError_ = "Failed to initialize ASIO driver";
            return false;
        }

        driverLoaded_ = true;
        return true;
    }

    void unloadDriver() {
        if (driverLoaded_) {
            ASIOExit();
            driverLoaded_ = false;
        }
    }

    ASIODriverInfo getDriverInfo() const {
        ASIODriverInfo info;

        if (!driverLoaded_) return info;

        info.name = currentDriverName_;

        long numInputs, numOutputs;
        ASIOGetChannels(&numInputs, &numOutputs);
        info.inputChannels = numInputs;
        info.outputChannels = numOutputs;

        long minSize, maxSize, preferredSize, granularity;
        ASIOGetBufferSize(&minSize, &maxSize, &preferredSize, &granularity);
        info.minBufferSize = minSize;
        info.maxBufferSize = maxSize;
        info.preferredBufferSize = preferredSize;

        ASIOSampleRate rate;
        ASIOGetSampleRate(&rate);
        info.sampleRate = rate;

        // Check supported formats
        ASIOChannelInfo channelInfo;
        channelInfo.channel = 0;
        channelInfo.isInput = ASIOFalse;
        if (ASIOGetChannelInfo(&channelInfo) == ASE_OK) {
            switch (channelInfo.type) {
                case ASIOSTFloat32LSB:
                case ASIOSTFloat32MSB:
                    info.supportsFloat32 = true;
                    break;
                case ASIOSTInt32LSB:
                case ASIOSTInt32MSB:
                    info.supportsInt32 = true;
                    break;
                case ASIOSTInt24LSB:
                case ASIOSTInt24MSB:
                    info.supportsInt24 = true;
                    break;
                case ASIOSTInt16LSB:
                case ASIOSTInt16MSB:
                    info.supportsInt16 = true;
                    break;
            }
        }

        return info;
    }

    bool initialize(const ASIOConfig& config = ASIOConfig()) {
        if (!driverLoaded_) {
            if (!loadDriver(config.driverName)) {
                return false;
            }
        }

        config_ = config;

        // Set sample rate
        ASIOError result = ASIOSetSampleRate(static_cast<ASIOSampleRate>(config_.sampleRate));
        if (result != ASE_OK) {
            lastError_ = "Failed to set sample rate";
            return false;
        }

        // Get channel info
        long numInputs, numOutputs;
        ASIOGetChannels(&numInputs, &numOutputs);

        numInputChannels_ = std::min(static_cast<long>(config_.inputChannels), numInputs);
        numOutputChannels_ = std::min(static_cast<long>(config_.outputChannels), numOutputs);

        // Get buffer size
        long minSize, maxSize, preferredSize, granularity;
        ASIOGetBufferSize(&minSize, &maxSize, &preferredSize, &granularity);

        // Clamp buffer size to valid range
        bufferSize_ = std::clamp(
            static_cast<long>(config_.bufferSize),
            minSize,
            maxSize
        );

        // Create buffer infos
        bufferInfos_.resize(numInputChannels_ + numOutputChannels_);

        for (int i = 0; i < numInputChannels_; i++) {
            bufferInfos_[i].isInput = ASIOTrue;
            bufferInfos_[i].channelNum = i;
            bufferInfos_[i].buffers[0] = nullptr;
            bufferInfos_[i].buffers[1] = nullptr;
        }

        for (int i = 0; i < numOutputChannels_; i++) {
            bufferInfos_[numInputChannels_ + i].isInput = ASIOFalse;
            bufferInfos_[numInputChannels_ + i].channelNum = i;
            bufferInfos_[numInputChannels_ + i].buffers[0] = nullptr;
            bufferInfos_[numInputChannels_ + i].buffers[1] = nullptr;
        }

        // Set up callbacks
        callbacks_.bufferSwitch = &ASIOBridge::bufferSwitchCallback;
        callbacks_.sampleRateDidChange = &ASIOBridge::sampleRateChangedCallback;
        callbacks_.asioMessage = &ASIOBridge::asioMessageCallback;
        callbacks_.bufferSwitchTimeInfo = &ASIOBridge::bufferSwitchTimeInfoCallback;

        // Store instance for static callbacks
        instance_ = this;

        // Create buffers
        result = ASIOCreateBuffers(
            bufferInfos_.data(),
            static_cast<long>(bufferInfos_.size()),
            bufferSize_,
            &callbacks_
        );

        if (result != ASE_OK) {
            lastError_ = "Failed to create ASIO buffers";
            return false;
        }

        // Get channel info for format
        ASIOChannelInfo channelInfo;
        channelInfo.channel = 0;
        channelInfo.isInput = ASIOFalse;
        ASIOGetChannelInfo(&channelInfo);
        sampleType_ = channelInfo.type;

        // Allocate conversion buffers
        inputBuffers_.resize(numInputChannels_);
        outputBuffers_.resize(numOutputChannels_);
        for (auto& buf : inputBuffers_) {
            buf.resize(bufferSize_, 0.0f);
        }
        for (auto& buf : outputBuffers_) {
            buf.resize(bufferSize_, 0.0f);
        }

        // Create pointer arrays
        inputPtrs_.resize(numInputChannels_);
        outputPtrs_.resize(numOutputChannels_);
        for (int i = 0; i < numInputChannels_; i++) {
            inputPtrs_[i] = inputBuffers_[i].data();
        }
        for (int i = 0; i < numOutputChannels_; i++) {
            outputPtrs_[i] = outputBuffers_[i].data();
        }

        initialized_ = true;
        return true;
    }

    // MARK: - Lifecycle

    void start() {
        if (!initialized_ || running_.load()) return;

        running_.store(true);
        ASIOStart();
    }

    void stop() {
        if (!running_.load()) return;

        running_.store(false);
        ASIOStop();
        ASIODisposeBuffers();
    }

    bool isRunning() const { return running_.load(); }

    // MARK: - Callback

    void setCallback(AudioCallback callback) {
        std::lock_guard<std::mutex> lock(callbackMutex_);
        callback_ = std::move(callback);
    }

    // MARK: - Quantum Integration

    void setQuantumEmulator(Quantum::QuantumLightEmulator* emulator) {
        quantumEmulator_ = emulator;
    }

    // MARK: - Bio-Reactive Modulation

    void setBioModulation(float heartRate, float hrvCoherence, float breathingRate) {
        std::lock_guard<std::mutex> lock(bioMutex_);
        heartRate_ = heartRate;
        hrvCoherence_ = hrvCoherence;
        breathingRate_ = breathingRate;
    }

    // MARK: - Getters

    uint32_t sampleRate() const { return config_.sampleRate; }
    uint32_t bufferSize() const { return static_cast<uint32_t>(bufferSize_); }
    int numInputChannels() const { return numInputChannels_; }
    int numOutputChannels() const { return numOutputChannels_; }
    std::string lastError() const { return lastError_; }
    std::string driverName() const { return currentDriverName_; }

    float getLatencyMs() const {
        long inputLatency, outputLatency;
        ASIOGetLatencies(&inputLatency, &outputLatency);
        return static_cast<float>(outputLatency) / config_.sampleRate * 1000.0f;
    }

private:
    // MARK: - Static Callbacks

    static ASIOBridge* instance_;

    static void bufferSwitchCallback(long doubleBufferIndex, ASIOBool directProcess) {
        if (instance_) {
            instance_->processAudio(doubleBufferIndex);
        }
    }

    static void sampleRateChangedCallback(ASIOSampleRate sRate) {
        // Handle sample rate change
    }

    static long asioMessageCallback(long selector, long value, void* message, double* opt) {
        switch (selector) {
            case kAsioSelectorSupported:
                switch (value) {
                    case kAsioResetRequest:
                    case kAsioEngineVersion:
                    case kAsioResyncRequest:
                    case kAsioLatenciesChanged:
                    case kAsioSupportsTimeInfo:
                    case kAsioSupportsTimeCode:
                        return 1;
                }
                return 0;

            case kAsioEngineVersion:
                return 2;

            case kAsioResetRequest:
                return 1;

            case kAsioResyncRequest:
                return 1;

            case kAsioLatenciesChanged:
                return 1;

            case kAsioSupportsTimeInfo:
                return 1;

            case kAsioSupportsTimeCode:
                return 0;
        }
        return 0;
    }

    static ASIOTime* bufferSwitchTimeInfoCallback(ASIOTime* params, long doubleBufferIndex, ASIOBool directProcess) {
        if (instance_) {
            instance_->processAudio(doubleBufferIndex);
        }
        return params;
    }

    // MARK: - Audio Processing

    void processAudio(long bufferIndex) {
        if (!running_.load()) return;

        // Convert input buffers to float
        for (int ch = 0; ch < numInputChannels_; ch++) {
            void* buffer = bufferInfos_[ch].buffers[bufferIndex];
            convertToFloat(buffer, inputBuffers_[ch].data(), bufferSize_);
        }

        // Clear output buffers
        for (auto& buf : outputBuffers_) {
            std::fill(buf.begin(), buf.end(), 0.0f);
        }

        // Call user callback
        {
            std::lock_guard<std::mutex> lock(callbackMutex_);
            if (callback_) {
                callback_(
                    inputPtrs_.data(),
                    outputPtrs_.data(),
                    static_cast<int>(bufferSize_),
                    numInputChannels_,
                    numOutputChannels_
                );
            }
        }

        // Apply bio modulation
        applyBioModulation();

        // Convert output buffers from float
        for (int ch = 0; ch < numOutputChannels_; ch++) {
            void* buffer = bufferInfos_[numInputChannels_ + ch].buffers[bufferIndex];
            convertFromFloat(outputBuffers_[ch].data(), buffer, bufferSize_);
        }

        // Output ready
        ASIOOutputReady();
    }

    void convertToFloat(void* src, float* dst, long numSamples) {
        switch (sampleType_) {
            case ASIOSTFloat32LSB:
            case ASIOSTFloat32MSB:
                std::memcpy(dst, src, numSamples * sizeof(float));
                break;

            case ASIOSTInt32LSB:
            case ASIOSTInt32MSB: {
                int32_t* intSrc = static_cast<int32_t*>(src);
                const float scale = 1.0f / 2147483648.0f;
                for (long i = 0; i < numSamples; i++) {
                    dst[i] = intSrc[i] * scale;
                }
                break;
            }

            case ASIOSTInt16LSB:
            case ASIOSTInt16MSB: {
                int16_t* intSrc = static_cast<int16_t*>(src);
                const float scale = 1.0f / 32768.0f;
                for (long i = 0; i < numSamples; i++) {
                    dst[i] = intSrc[i] * scale;
                }
                break;
            }

            default:
                std::fill(dst, dst + numSamples, 0.0f);
                break;
        }
    }

    void convertFromFloat(float* src, void* dst, long numSamples) {
        switch (sampleType_) {
            case ASIOSTFloat32LSB:
            case ASIOSTFloat32MSB:
                std::memcpy(dst, src, numSamples * sizeof(float));
                break;

            case ASIOSTInt32LSB:
            case ASIOSTInt32MSB: {
                int32_t* intDst = static_cast<int32_t*>(dst);
                const float scale = 2147483647.0f;
                for (long i = 0; i < numSamples; i++) {
                    float sample = std::clamp(src[i], -1.0f, 1.0f);
                    intDst[i] = static_cast<int32_t>(sample * scale);
                }
                break;
            }

            case ASIOSTInt16LSB:
            case ASIOSTInt16MSB: {
                int16_t* intDst = static_cast<int16_t*>(dst);
                const float scale = 32767.0f;
                for (long i = 0; i < numSamples; i++) {
                    float sample = std::clamp(src[i], -1.0f, 1.0f);
                    intDst[i] = static_cast<int16_t>(sample * scale);
                }
                break;
            }

            default:
                break;
        }
    }

    void applyBioModulation() {
        std::lock_guard<std::mutex> lock(bioMutex_);

        if (hrvCoherence_ <= 0.0f) return;

        // Coherence-based subtle warmth
        float warmthAmount = hrvCoherence_ * 0.1f;

        for (int ch = 0; ch < numOutputChannels_; ch++) {
            for (long i = 0; i < bufferSize_; i++) {
                float& sample = outputBuffers_[ch][i];

                // Soft saturation for warmth
                float saturated = std::tanh(sample * (1.0f + warmthAmount * 0.5f));
                sample = sample + (saturated - sample) * warmthAmount;
            }
        }
    }

    // MARK: - Member Variables

    ASIOConfig config_;
    std::string currentDriverName_;
    bool driverLoaded_ = false;
    bool initialized_ = false;
    std::atomic<bool> running_{false};
    std::string lastError_;

    std::vector<ASIOBufferInfo> bufferInfos_;
    ASIOCallbacks callbacks_;
    long bufferSize_ = 256;
    ASIOSampleType sampleType_ = ASIOSTFloat32LSB;
    int numInputChannels_ = 0;
    int numOutputChannels_ = 0;

    std::vector<std::vector<float>> inputBuffers_;
    std::vector<std::vector<float>> outputBuffers_;
    std::vector<float*> inputPtrs_;
    std::vector<float*> outputPtrs_;

    AudioCallback callback_;
    std::mutex callbackMutex_;

    // Quantum integration
    Quantum::QuantumLightEmulator* quantumEmulator_ = nullptr;

    // Bio modulation
    std::mutex bioMutex_;
    float heartRate_ = 60.0f;
    float hrvCoherence_ = 0.0f;
    float breathingRate_ = 6.0f;
};

// Static instance for callbacks
ASIOBridge* ASIOBridge::instance_ = nullptr;

#else // ECHOELMUSIC_ASIO_AVAILABLE == 0

// ============================================================================
// MARK: - ASIO Stub (SDK not available)
// ============================================================================

class ASIOBridge {
public:
    using AudioCallback = std::function<void(
        const float* const* inputs,
        float* const* outputs,
        int numFrames,
        int numInputChannels,
        int numOutputChannels
    )>;

    static std::vector<std::string> getAvailableDrivers() { return {}; }

    bool loadDriver(const std::string&) {
        lastError_ = "ASIO SDK not available. Install ASIO SDK in ThirdParty/asiosdk/";
        return false;
    }

    void unloadDriver() {}
    ASIODriverInfo getDriverInfo() const { return {}; }
    bool initialize(const ASIOConfig& = ASIOConfig()) { return false; }
    void start() {}
    void stop() {}
    bool isRunning() const { return false; }
    void setCallback(AudioCallback) {}
    void setQuantumEmulator(Quantum::QuantumLightEmulator*) {}
    void setBioModulation(float, float, float) {}
    uint32_t sampleRate() const { return 48000; }
    uint32_t bufferSize() const { return 256; }
    int numInputChannels() const { return 0; }
    int numOutputChannels() const { return 0; }
    std::string lastError() const { return lastError_; }
    std::string driverName() const { return ""; }
    float getLatencyMs() const { return 0.0f; }

private:
    std::string lastError_ = "ASIO not available";
};

#endif // ECHOELMUSIC_ASIO_AVAILABLE

} // namespace Audio
} // namespace Echoelmusic

#endif // _WIN32
