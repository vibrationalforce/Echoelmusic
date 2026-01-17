/**
 * UnifiedAudioConfig.hpp
 * Echoelmusic - Unified Cross-Platform Audio Configuration
 *
 * Single configuration interface for all audio backends
 * Ralph Wiggum Lambda Loop Mode - Nobel Prize Quality
 *
 * Supports:
 * - Windows: WASAPI, ASIO, DirectSound
 * - Linux: PipeWire, JACK, ALSA
 * - macOS/iOS: Core Audio
 * - Android: AAudio, Oboe
 *
 * Created: 2026-01-17
 */

#pragma once

#include <string>
#include <vector>
#include <memory>
#include <functional>
#include <cstdint>

namespace Echoelmusic {
namespace Audio {

// ============================================================================
// MARK: - Audio Backend Enumeration
// ============================================================================

enum class AudioBackend {
    // Auto-detect best available
    Auto,

    // Windows
    WASAPI,
    WASAPI_Exclusive,
    ASIO,
    DirectSound,

    // Linux
    PipeWire,
    JACK,
    ALSA,
    PulseAudio,

    // Apple
    CoreAudio,
    AVFoundation,

    // Android
    AAudio,
    Oboe,
    OpenSLES,

    // Cross-platform
    PortAudio,
    RtAudio
};

// ============================================================================
// MARK: - Device Info
// ============================================================================

struct AudioDeviceInfo {
    std::string id;
    std::string name;
    AudioBackend backend;
    int maxInputChannels = 0;
    int maxOutputChannels = 0;
    std::vector<uint32_t> supportedSampleRates;
    std::vector<uint32_t> supportedBufferSizes;
    bool isDefault = false;
    bool supportsExclusive = false;
    float minLatencyMs = 0.0f;
};

// ============================================================================
// MARK: - Unified Audio Configuration
// ============================================================================

struct UnifiedAudioConfig {
    // Backend selection
    AudioBackend backend = AudioBackend::Auto;
    std::string deviceId = "";  // Empty = default device

    // Audio format
    uint32_t sampleRate = 48000;
    uint32_t bufferSize = 256;
    uint32_t inputChannels = 2;
    uint32_t outputChannels = 2;
    uint32_t bitsPerSample = 32;  // 16, 24, or 32

    // Quality settings
    bool useFloat = true;         // Use 32-bit float
    bool useExclusive = true;     // Exclusive mode if available
    bool allowResampling = false; // Allow sample rate conversion

    // Latency targets
    float targetLatencyMs = 10.0f;
    float maxLatencyMs = 50.0f;

    // Platform-specific
#ifdef _WIN32
    std::string mmcssTaskName = "Pro Audio";
    bool useMMCSS = true;
#endif

#ifdef __linux__
    std::string jackClientName = "Echoelmusic";
    bool autoConnectJack = true;
    std::string pipewireAppName = "Echoelmusic";
#endif

#ifdef __APPLE__
    bool enableAirPlay = false;
    bool enableBluetooth = true;
#endif

#ifdef __ANDROID__
    int performanceMode = 1;  // 0=None, 1=LowLatency, 2=PowerSaving
    int sharingMode = 1;      // 0=Shared, 1=Exclusive
#endif

    // Bio-reactive
    bool enableBioModulation = true;
    bool enableQuantumEmulator = true;

    // ========================================================================
    // Factory methods for common configurations
    // ========================================================================

    static UnifiedAudioConfig ultraLowLatency() {
        UnifiedAudioConfig config;
        config.bufferSize = 64;
        config.targetLatencyMs = 3.0f;
        config.useExclusive = true;
#ifdef _WIN32
        config.backend = AudioBackend::ASIO;
#elif defined(__linux__)
        config.backend = AudioBackend::JACK;
#endif
        return config;
    }

    static UnifiedAudioConfig lowLatency() {
        UnifiedAudioConfig config;
        config.bufferSize = 128;
        config.targetLatencyMs = 6.0f;
        config.useExclusive = true;
        return config;
    }

    static UnifiedAudioConfig balanced() {
        UnifiedAudioConfig config;
        config.bufferSize = 256;
        config.targetLatencyMs = 10.0f;
        config.useExclusive = false;
        return config;
    }

    static UnifiedAudioConfig stable() {
        UnifiedAudioConfig config;
        config.bufferSize = 512;
        config.targetLatencyMs = 20.0f;
        config.useExclusive = false;
        return config;
    }

    static UnifiedAudioConfig highQuality() {
        UnifiedAudioConfig config;
        config.sampleRate = 96000;
        config.bufferSize = 512;
        config.bitsPerSample = 32;
        config.targetLatencyMs = 20.0f;
        return config;
    }
};

// ============================================================================
// MARK: - Audio Callback Types
// ============================================================================

using AudioProcessCallback = std::function<void(
    const float* const* inputs,
    float* const* outputs,
    int numFrames,
    int numInputChannels,
    int numOutputChannels
)>;

using AudioErrorCallback = std::function<void(const std::string& error)>;
using DeviceChangeCallback = std::function<void()>;

// ============================================================================
// MARK: - Backend Availability
// ============================================================================

struct BackendAvailability {
    static bool isAvailable(AudioBackend backend) {
        switch (backend) {
#ifdef _WIN32
            case AudioBackend::WASAPI:
            case AudioBackend::WASAPI_Exclusive:
                return true;
            case AudioBackend::ASIO:
#ifdef ECHOELMUSIC_ASIO_AVAILABLE
                return true;
#else
                return false;
#endif
            case AudioBackend::DirectSound:
                return true;
#endif

#ifdef __linux__
            case AudioBackend::PipeWire:
#ifdef ECHOELMUSIC_PIPEWIRE_AVAILABLE
                return true;
#else
                return false;
#endif
            case AudioBackend::JACK:
#ifdef ECHOELMUSIC_JACK_AVAILABLE
                return true;
#else
                return false;
#endif
            case AudioBackend::ALSA:
                return true;
            case AudioBackend::PulseAudio:
                return false;  // Deprecated, use PipeWire
#endif

#ifdef __APPLE__
            case AudioBackend::CoreAudio:
            case AudioBackend::AVFoundation:
                return true;
#endif

#ifdef __ANDROID__
            case AudioBackend::AAudio:
            case AudioBackend::Oboe:
                return true;
            case AudioBackend::OpenSLES:
                return true;  // Legacy fallback
#endif

            case AudioBackend::Auto:
                return true;

            default:
                return false;
        }
    }

    static AudioBackend getBestAvailable() {
#ifdef _WIN32
#ifdef ECHOELMUSIC_ASIO_AVAILABLE
        return AudioBackend::ASIO;
#else
        return AudioBackend::WASAPI_Exclusive;
#endif
#elif defined(__APPLE__)
        return AudioBackend::CoreAudio;
#elif defined(__linux__)
#ifdef ECHOELMUSIC_JACK_AVAILABLE
        return AudioBackend::JACK;
#elif defined(ECHOELMUSIC_PIPEWIRE_AVAILABLE)
        return AudioBackend::PipeWire;
#else
        return AudioBackend::ALSA;
#endif
#elif defined(__ANDROID__)
        return AudioBackend::AAudio;
#else
        return AudioBackend::Auto;
#endif
    }

    static std::vector<AudioBackend> getAvailableBackends() {
        std::vector<AudioBackend> backends;

#ifdef _WIN32
        backends.push_back(AudioBackend::WASAPI);
        backends.push_back(AudioBackend::WASAPI_Exclusive);
#ifdef ECHOELMUSIC_ASIO_AVAILABLE
        backends.push_back(AudioBackend::ASIO);
#endif
        backends.push_back(AudioBackend::DirectSound);
#endif

#ifdef __linux__
#ifdef ECHOELMUSIC_PIPEWIRE_AVAILABLE
        backends.push_back(AudioBackend::PipeWire);
#endif
#ifdef ECHOELMUSIC_JACK_AVAILABLE
        backends.push_back(AudioBackend::JACK);
#endif
        backends.push_back(AudioBackend::ALSA);
#endif

#ifdef __APPLE__
        backends.push_back(AudioBackend::CoreAudio);
        backends.push_back(AudioBackend::AVFoundation);
#endif

#ifdef __ANDROID__
        backends.push_back(AudioBackend::AAudio);
        backends.push_back(AudioBackend::Oboe);
#endif

        return backends;
    }

    static const char* getBackendName(AudioBackend backend) {
        switch (backend) {
            case AudioBackend::Auto: return "Auto";
            case AudioBackend::WASAPI: return "WASAPI";
            case AudioBackend::WASAPI_Exclusive: return "WASAPI Exclusive";
            case AudioBackend::ASIO: return "ASIO";
            case AudioBackend::DirectSound: return "DirectSound";
            case AudioBackend::PipeWire: return "PipeWire";
            case AudioBackend::JACK: return "JACK";
            case AudioBackend::ALSA: return "ALSA";
            case AudioBackend::PulseAudio: return "PulseAudio";
            case AudioBackend::CoreAudio: return "Core Audio";
            case AudioBackend::AVFoundation: return "AVFoundation";
            case AudioBackend::AAudio: return "AAudio";
            case AudioBackend::Oboe: return "Oboe";
            case AudioBackend::OpenSLES: return "OpenSL ES";
            case AudioBackend::PortAudio: return "PortAudio";
            case AudioBackend::RtAudio: return "RtAudio";
            default: return "Unknown";
        }
    }

    static float getTypicalLatencyMs(AudioBackend backend) {
        switch (backend) {
            case AudioBackend::ASIO: return 3.0f;
            case AudioBackend::JACK: return 5.0f;
            case AudioBackend::WASAPI_Exclusive: return 8.0f;
            case AudioBackend::CoreAudio: return 8.0f;
            case AudioBackend::AAudio: return 10.0f;
            case AudioBackend::PipeWire: return 12.0f;
            case AudioBackend::WASAPI: return 20.0f;
            case AudioBackend::Oboe: return 15.0f;
            case AudioBackend::ALSA: return 20.0f;
            case AudioBackend::DirectSound: return 30.0f;
            case AudioBackend::PulseAudio: return 40.0f;
            case AudioBackend::OpenSLES: return 50.0f;
            default: return 20.0f;
        }
    }
};

// ============================================================================
// MARK: - Latency Calculator
// ============================================================================

struct LatencyCalculator {
    static float bufferToMs(uint32_t bufferSize, uint32_t sampleRate) {
        return static_cast<float>(bufferSize) / sampleRate * 1000.0f;
    }

    static uint32_t msToBuffer(float latencyMs, uint32_t sampleRate) {
        return static_cast<uint32_t>(latencyMs / 1000.0f * sampleRate);
    }

    static uint32_t roundToPowerOf2(uint32_t value) {
        uint32_t result = 1;
        while (result < value) {
            result *= 2;
        }
        return result;
    }

    static uint32_t getOptimalBufferSize(float targetLatencyMs, uint32_t sampleRate) {
        uint32_t samples = msToBuffer(targetLatencyMs, sampleRate);
        uint32_t powerOf2 = roundToPowerOf2(samples);

        // Don't go below 32 or above 4096
        if (powerOf2 < 32) powerOf2 = 32;
        if (powerOf2 > 4096) powerOf2 = 4096;

        return powerOf2;
    }
};

// ============================================================================
// MARK: - Performance Profiles
// ============================================================================

struct PerformanceProfile {
    std::string name;
    UnifiedAudioConfig config;
    std::string description;

    static std::vector<PerformanceProfile> getProfiles() {
        return {
            {
                "Ultra Low Latency",
                UnifiedAudioConfig::ultraLowLatency(),
                "For professional ASIO/JACK setups. ~3ms latency. Requires fast CPU."
            },
            {
                "Low Latency",
                UnifiedAudioConfig::lowLatency(),
                "Good balance for music production. ~6ms latency."
            },
            {
                "Balanced",
                UnifiedAudioConfig::balanced(),
                "Default setting. ~10ms latency. Good for most use cases."
            },
            {
                "Stable",
                UnifiedAudioConfig::stable(),
                "Maximum stability. ~20ms latency. For older hardware."
            },
            {
                "High Quality",
                UnifiedAudioConfig::highQuality(),
                "96kHz sample rate. Best audio quality for mastering."
            }
        };
    }
};

} // namespace Audio
} // namespace Echoelmusic
