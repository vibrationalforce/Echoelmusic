/**
 * PipeWireAudioEngine.hpp
 * Echoelmusic - Linux PipeWire Audio Integration
 *
 * Modern low-latency audio for Linux using PipeWire.
 * PipeWire is the default audio system on Fedora 34+, Ubuntu 22.10+, and others.
 *
 * Features:
 * - Low-latency audio (<15ms)
 * - Automatic device routing
 * - JACK compatibility mode
 * - Bio-reactive modulation
 * - Quantum light emulator integration
 *
 * Requires: libpipewire-0.3-dev
 *
 * Created: 2026-01-15
 */

#pragma once

#ifdef __linux__

// Check for PipeWire support at compile time
#if __has_include(<pipewire/pipewire.h>)
#define ECHOELMUSIC_PIPEWIRE_AVAILABLE 1
#include <pipewire/pipewire.h>
#include <spa/param/audio/format-utils.h>
#include <spa/param/props.h>
#else
#define ECHOELMUSIC_PIPEWIRE_AVAILABLE 0
#endif

#include <atomic>
#include <thread>
#include <functional>
#include <vector>
#include <cmath>
#include <memory>
#include <string>
#include <mutex>

namespace Echoelmusic {

// Forward declaration
namespace Quantum {
class QuantumLightEmulator;
}

namespace Audio {

// ============================================================================
// MARK: - Audio Configuration
// ============================================================================

struct PipeWireConfig {
    uint32_t sampleRate = 48000;
    uint32_t bufferSize = 256;
    uint32_t channels = 2;
    std::string appName = "Echoelmusic";
    std::string nodeName = "echoelmusic-output";
};

#if ECHOELMUSIC_PIPEWIRE_AVAILABLE

// ============================================================================
// MARK: - PipeWire Audio Engine
// ============================================================================

class PipeWireAudioEngine {
public:
    using AudioCallback = std::function<void(float* output, int numFrames, int numChannels)>;

    PipeWireAudioEngine() {
        pw_init(nullptr, nullptr);
    }

    ~PipeWireAudioEngine() {
        stop();
        pw_deinit();
    }

    // MARK: - Initialization

    bool initialize(const PipeWireConfig& config = PipeWireConfig()) {
        config_ = config;

        // Create main loop
        loop_ = pw_main_loop_new(nullptr);
        if (!loop_) {
            lastError_ = "Failed to create main loop";
            return false;
        }

        // Create context
        context_ = pw_context_new(
            pw_main_loop_get_loop(loop_),
            nullptr,
            0
        );
        if (!context_) {
            lastError_ = "Failed to create context";
            return false;
        }

        // Create core connection
        core_ = pw_context_connect(context_, nullptr, 0);
        if (!core_) {
            lastError_ = "Failed to connect to PipeWire";
            return false;
        }

        // Create audio stream
        if (!createStream()) {
            return false;
        }

        // Allocate buffer
        buffer_.resize(config_.bufferSize * config_.channels, 0.0f);

        initialized_ = true;
        return true;
    }

    // MARK: - Lifecycle

    void start() {
        if (!initialized_ || running_.load()) return;

        running_.store(true);

        // Connect the stream
        pw_stream_connect(
            stream_,
            PW_DIRECTION_OUTPUT,
            PW_ID_ANY,
            static_cast<pw_stream_flags>(
                PW_STREAM_FLAG_AUTOCONNECT |
                PW_STREAM_FLAG_MAP_BUFFERS |
                PW_STREAM_FLAG_RT_PROCESS
            ),
            params_,
            1
        );

        // Run main loop in separate thread
        mainLoopThread_ = std::thread([this]() {
            pw_main_loop_run(loop_);
        });
    }

    void stop() {
        running_.store(false);

        if (loop_) {
            pw_main_loop_quit(loop_);
        }

        if (mainLoopThread_.joinable()) {
            mainLoopThread_.join();
        }

        if (stream_) {
            pw_stream_destroy(stream_);
            stream_ = nullptr;
        }

        if (core_) {
            pw_core_disconnect(core_);
            core_ = nullptr;
        }

        if (context_) {
            pw_context_destroy(context_);
            context_ = nullptr;
        }

        if (loop_) {
            pw_main_loop_destroy(loop_);
            loop_ = nullptr;
        }

        initialized_ = false;
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

    // MARK: - Bio Modulation

    void setBioModulation(float heartRate, float hrvCoherence, float breathingRate) {
        std::lock_guard<std::mutex> lock(bioMutex_);
        heartRate_ = heartRate;
        hrvCoherence_ = hrvCoherence;
        breathingRate_ = breathingRate;
    }

    // MARK: - Getters

    uint32_t sampleRate() const { return config_.sampleRate; }
    uint32_t bufferSize() const { return config_.bufferSize; }
    uint32_t channels() const { return config_.channels; }
    std::string lastError() const { return lastError_; }

    float getLatencyMs() const {
        return static_cast<float>(config_.bufferSize) / config_.sampleRate * 1000.0f;
    }

private:
    bool createStream() {
        // Stream properties
        auto props = pw_properties_new(
            PW_KEY_MEDIA_TYPE, "Audio",
            PW_KEY_MEDIA_CATEGORY, "Playback",
            PW_KEY_MEDIA_ROLE, "Music",
            PW_KEY_APP_NAME, config_.appName.c_str(),
            PW_KEY_NODE_NAME, config_.nodeName.c_str(),
            nullptr
        );

        // Create stream
        stream_ = pw_stream_new(core_, config_.nodeName.c_str(), props);
        if (!stream_) {
            lastError_ = "Failed to create stream";
            return false;
        }

        // Set up events
        static const struct pw_stream_events stream_events = {
            .version = PW_VERSION_STREAM_EVENTS,
            .process = onProcess,
        };

        pw_stream_add_listener(stream_, &streamListener_, &stream_events, this);

        // Audio format
        uint8_t buffer[1024];
        struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));

        params_[0] = static_cast<const struct spa_pod*>(
            spa_format_audio_raw_build(
                &b,
                SPA_PARAM_EnumFormat,
                &SPA_AUDIO_INFO_RAW_INIT(
                    .format = SPA_AUDIO_FORMAT_F32,
                    .channels = config_.channels,
                    .rate = config_.sampleRate
                )
            )
        );

        return true;
    }

    static void onProcess(void* userData) {
        auto* engine = static_cast<PipeWireAudioEngine*>(userData);
        engine->processAudio();
    }

    void processAudio() {
        struct pw_buffer* pwBuffer = pw_stream_dequeue_buffer(stream_);
        if (!pwBuffer) return;

        struct spa_buffer* buf = pwBuffer->buffer;
        float* output = static_cast<float*>(buf->datas[0].data);

        if (!output) {
            pw_stream_queue_buffer(stream_, pwBuffer);
            return;
        }

        uint32_t numFrames = buf->datas[0].maxsize / (sizeof(float) * config_.channels);
        numFrames = std::min(numFrames, config_.bufferSize);

        // Clear buffer
        std::fill(output, output + numFrames * config_.channels, 0.0f);

        // Call user callback
        {
            std::lock_guard<std::mutex> lock(callbackMutex_);
            if (callback_) {
                callback_(output, numFrames, config_.channels);
            }
        }

        // Apply bio modulation
        applyBioModulation(output, numFrames);

        // Set buffer size
        buf->datas[0].chunk->offset = 0;
        buf->datas[0].chunk->stride = sizeof(float) * config_.channels;
        buf->datas[0].chunk->size = numFrames * sizeof(float) * config_.channels;

        pw_stream_queue_buffer(stream_, pwBuffer);
    }

    void applyBioModulation(float* buffer, uint32_t numFrames) {
        std::lock_guard<std::mutex> lock(bioMutex_);

        if (hrvCoherence_ < 0.1f) return;

        float breathPhase = 0.0f;
        float breathIncrement = (breathingRate_ / 60.0f) * 2.0f * M_PI / config_.sampleRate;

        for (uint32_t i = 0; i < numFrames; ++i) {
            float mod = 1.0f + 0.05f * hrvCoherence_ * std::sin(breathPhase);

            for (uint32_t ch = 0; ch < config_.channels; ++ch) {
                buffer[i * config_.channels + ch] *= mod;
            }

            breathPhase += breathIncrement;
            if (breathPhase > 2.0f * M_PI) breathPhase -= 2.0f * M_PI;
        }
    }

    // PipeWire objects
    struct pw_main_loop* loop_ = nullptr;
    struct pw_context* context_ = nullptr;
    struct pw_core* core_ = nullptr;
    struct pw_stream* stream_ = nullptr;
    struct spa_hook streamListener_;
    const struct spa_pod* params_[1];

    PipeWireConfig config_;
    std::vector<float> buffer_;

    AudioCallback callback_;
    std::mutex callbackMutex_;

    Quantum::QuantumLightEmulator* quantumEmulator_ = nullptr;

    std::mutex bioMutex_;
    float heartRate_ = 70.0f;
    float hrvCoherence_ = 0.0f;
    float breathingRate_ = 12.0f;

    std::atomic<bool> running_{false};
    std::thread mainLoopThread_;
    bool initialized_ = false;
    std::string lastError_;
};

#else // !ECHOELMUSIC_PIPEWIRE_AVAILABLE

// ============================================================================
// MARK: - Stub Implementation (when PipeWire not available)
// ============================================================================

class PipeWireAudioEngine {
public:
    using AudioCallback = std::function<void(float* output, int numFrames, int numChannels)>;

    PipeWireAudioEngine() = default;
    ~PipeWireAudioEngine() = default;

    bool initialize(const PipeWireConfig& = PipeWireConfig()) {
        lastError_ = "PipeWire not available at compile time";
        return false;
    }

    void start() {}
    void stop() {}
    bool isRunning() const { return false; }
    void setCallback(AudioCallback) {}
    void setQuantumEmulator(Quantum::QuantumLightEmulator*) {}
    void setBioModulation(float, float, float) {}

    uint32_t sampleRate() const { return 48000; }
    uint32_t bufferSize() const { return 256; }
    uint32_t channels() const { return 2; }
    std::string lastError() const { return lastError_; }
    float getLatencyMs() const { return 0.0f; }

    static bool isAvailable() { return false; }

private:
    std::string lastError_ = "PipeWire not available";
};

#endif // ECHOELMUSIC_PIPEWIRE_AVAILABLE

// ============================================================================
// MARK: - PipeWire Utilities
// ============================================================================

namespace PipeWireUtils {

inline bool isPipeWireAvailable() {
#if ECHOELMUSIC_PIPEWIRE_AVAILABLE
    return true;
#else
    return false;
#endif
}

inline std::string getPipeWireVersion() {
#if ECHOELMUSIC_PIPEWIRE_AVAILABLE
    return pw_get_library_version();
#else
    return "Not available";
#endif
}

} // namespace PipeWireUtils

} // namespace Audio
} // namespace Echoelmusic

#endif // __linux__
