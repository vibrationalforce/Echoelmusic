/**
 * JACKAudioEngine.hpp
 * Echoelmusic - Linux JACK Audio Integration
 *
 * Professional ultra-low latency audio for Linux using JACK (<10ms)
 * Ralph Wiggum Lambda Loop Mode - Nobel Prize Quality
 *
 * Features:
 * - JACK Audio Connection Kit integration
 * - Ultra-low latency (<10ms possible)
 * - Professional studio connectivity
 * - Multi-client synchronization
 * - Transport control (play/stop/locate)
 * - Bio-reactive modulation
 * - Quantum light emulator integration
 *
 * Requires: libjack-dev or libjack-jackd2-dev
 *
 * Created: 2026-01-17
 */

#pragma once

#ifdef __linux__

// Check for JACK at compile time
#if __has_include(<jack/jack.h>)
#define ECHOELMUSIC_JACK_AVAILABLE 1
#include <jack/jack.h>
#include <jack/midiport.h>
#include <jack/transport.h>
#else
#define ECHOELMUSIC_JACK_AVAILABLE 0
#endif

#include <atomic>
#include <thread>
#include <functional>
#include <vector>
#include <cmath>
#include <memory>
#include <string>
#include <mutex>
#include <cstring>

namespace Echoelmusic {

// Forward declaration
namespace Quantum {
class QuantumLightEmulator;
}

namespace Audio {

// ============================================================================
// MARK: - JACK Configuration
// ============================================================================

struct JACKConfig {
    std::string clientName = "Echoelmusic";
    uint32_t inputChannels = 2;
    uint32_t outputChannels = 2;
    bool autoConnect = true;           // Auto-connect to system ports
    bool startJackServer = false;      // Start JACK server if not running
    bool useTransport = true;          // Sync with JACK transport
    std::string serverName = "";       // Empty = default server
};

// ============================================================================
// MARK: - JACK Port Info
// ============================================================================

struct JACKPortInfo {
    std::string name;
    bool isInput;
    bool isPhysical;
    bool isTerminal;
};

// ============================================================================
// MARK: - JACK Transport State
// ============================================================================

struct JACKTransportState {
    bool isRolling = false;
    double bpm = 120.0;
    uint32_t beatsPerBar = 4;
    uint32_t beatType = 4;
    int64_t frame = 0;
    double barStartTick = 0.0;
    float bar = 0.0f;
    float beat = 0.0f;
    float tick = 0.0f;
};

#if ECHOELMUSIC_JACK_AVAILABLE

// ============================================================================
// MARK: - JACK Audio Engine
// ============================================================================

class JACKAudioEngine {
public:
    using AudioCallback = std::function<void(
        const float* const* inputs,
        float* const* outputs,
        int numFrames,
        int numInputChannels,
        int numOutputChannels
    )>;

    using TransportCallback = std::function<void(const JACKTransportState& state)>;

    JACKAudioEngine() = default;

    ~JACKAudioEngine() {
        stop();
        disconnect();
    }

    // MARK: - Server Enumeration

    static std::vector<std::string> getAvailablePorts(bool inputs = false) {
        std::vector<std::string> ports;

        jack_client_t* tempClient = jack_client_open(
            "EchoelmusicScanner",
            JackNoStartServer,
            nullptr
        );

        if (!tempClient) return ports;

        unsigned long flags = inputs ? JackPortIsOutput : JackPortIsInput;
        const char** portNames = jack_get_ports(tempClient, nullptr, JACK_DEFAULT_AUDIO_TYPE, flags);

        if (portNames) {
            for (int i = 0; portNames[i]; i++) {
                ports.push_back(portNames[i]);
            }
            jack_free(portNames);
        }

        jack_client_close(tempClient);
        return ports;
    }

    static bool isServerRunning() {
        jack_client_t* client = jack_client_open(
            "EchoelmusicTest",
            JackNoStartServer,
            nullptr
        );

        if (client) {
            jack_client_close(client);
            return true;
        }
        return false;
    }

    // MARK: - Connection

    bool connect(const JACKConfig& config = JACKConfig()) {
        if (connected_) {
            disconnect();
        }

        config_ = config;

        // Set up options
        jack_options_t options = JackNullOption;
        if (!config_.startJackServer) {
            options = JackNoStartServer;
        }

        jack_status_t status;

        // Open client
        if (config_.serverName.empty()) {
            client_ = jack_client_open(
                config_.clientName.c_str(),
                options,
                &status
            );
        } else {
            client_ = jack_client_open(
                config_.clientName.c_str(),
                static_cast<jack_options_t>(options | JackServerName),
                &status,
                config_.serverName.c_str()
            );
        }

        if (!client_) {
            if (status & JackServerFailed) {
                lastError_ = "JACK server not running";
            } else if (status & JackNameNotUnique) {
                lastError_ = "Client name not unique";
            } else {
                lastError_ = "Failed to connect to JACK server";
            }
            return false;
        }

        // Get server info
        sampleRate_ = jack_get_sample_rate(client_);
        bufferSize_ = jack_get_buffer_size(client_);

        // Set callbacks
        jack_set_process_callback(client_, processCallback, this);
        jack_set_sample_rate_callback(client_, sampleRateCallback, this);
        jack_set_buffer_size_callback(client_, bufferSizeCallback, this);
        jack_on_shutdown(client_, shutdownCallback, this);

        if (config_.useTransport) {
            jack_set_sync_callback(client_, syncCallback, this);
        }

        // Create input ports
        inputPorts_.resize(config_.inputChannels);
        for (uint32_t i = 0; i < config_.inputChannels; i++) {
            std::string portName = "input_" + std::to_string(i + 1);
            inputPorts_[i] = jack_port_register(
                client_,
                portName.c_str(),
                JACK_DEFAULT_AUDIO_TYPE,
                JackPortIsInput,
                0
            );

            if (!inputPorts_[i]) {
                lastError_ = "Failed to create input port " + std::to_string(i + 1);
                disconnect();
                return false;
            }
        }

        // Create output ports
        outputPorts_.resize(config_.outputChannels);
        for (uint32_t i = 0; i < config_.outputChannels; i++) {
            std::string portName = "output_" + std::to_string(i + 1);
            outputPorts_[i] = jack_port_register(
                client_,
                portName.c_str(),
                JACK_DEFAULT_AUDIO_TYPE,
                JackPortIsOutput,
                0
            );

            if (!outputPorts_[i]) {
                lastError_ = "Failed to create output port " + std::to_string(i + 1);
                disconnect();
                return false;
            }
        }

        // Allocate buffer pointer arrays
        inputPtrs_.resize(config_.inputChannels);
        outputPtrs_.resize(config_.outputChannels);

        connected_ = true;
        return true;
    }

    void disconnect() {
        if (!connected_) return;

        stop();

        if (client_) {
            // Unregister ports
            for (auto* port : inputPorts_) {
                if (port) jack_port_unregister(client_, port);
            }
            for (auto* port : outputPorts_) {
                if (port) jack_port_unregister(client_, port);
            }

            jack_client_close(client_);
            client_ = nullptr;
        }

        inputPorts_.clear();
        outputPorts_.clear();
        inputPtrs_.clear();
        outputPtrs_.clear();

        connected_ = false;
    }

    // MARK: - Lifecycle

    void start() {
        if (!connected_ || running_.load()) return;

        // Activate client
        if (jack_activate(client_) != 0) {
            lastError_ = "Failed to activate JACK client";
            return;
        }

        running_.store(true);

        // Auto-connect to system ports
        if (config_.autoConnect) {
            autoConnectPorts();
        }
    }

    void stop() {
        if (!running_.load()) return;

        running_.store(false);

        if (client_) {
            jack_deactivate(client_);
        }
    }

    bool isRunning() const { return running_.load(); }
    bool isConnected() const { return connected_; }

    // MARK: - Port Connection

    bool connectPort(const std::string& sourcePort, const std::string& destPort) {
        if (!client_) return false;
        return jack_connect(client_, sourcePort.c_str(), destPort.c_str()) == 0;
    }

    bool disconnectPort(const std::string& sourcePort, const std::string& destPort) {
        if (!client_) return false;
        return jack_disconnect(client_, sourcePort.c_str(), destPort.c_str()) == 0;
    }

    std::string getPortName(int channel, bool isInput) const {
        if (!client_) return "";

        if (isInput) {
            if (channel >= 0 && channel < static_cast<int>(inputPorts_.size())) {
                return jack_port_name(inputPorts_[channel]);
            }
        } else {
            if (channel >= 0 && channel < static_cast<int>(outputPorts_.size())) {
                return jack_port_name(outputPorts_[channel]);
            }
        }
        return "";
    }

    // MARK: - Transport Control

    void transportStart() {
        if (client_) {
            jack_transport_start(client_);
        }
    }

    void transportStop() {
        if (client_) {
            jack_transport_stop(client_);
        }
    }

    void transportLocate(int64_t frame) {
        if (client_) {
            jack_transport_locate(client_, static_cast<jack_nframes_t>(frame));
        }
    }

    JACKTransportState getTransportState() const {
        JACKTransportState state;
        if (!client_) return state;

        jack_position_t pos;
        jack_transport_state_t jackState = jack_transport_query(client_, &pos);

        state.isRolling = (jackState == JackTransportRolling);
        state.frame = pos.frame;

        if (pos.valid & JackPositionBBT) {
            state.bpm = pos.beats_per_minute;
            state.beatsPerBar = pos.beats_per_bar;
            state.beatType = pos.beat_type;
            state.bar = static_cast<float>(pos.bar);
            state.beat = static_cast<float>(pos.beat);
            state.tick = static_cast<float>(pos.tick);
            state.barStartTick = pos.bar_start_tick;
        }

        return state;
    }

    // MARK: - Callbacks

    void setCallback(AudioCallback callback) {
        std::lock_guard<std::mutex> lock(callbackMutex_);
        callback_ = std::move(callback);
    }

    void setTransportCallback(TransportCallback callback) {
        std::lock_guard<std::mutex> lock(transportMutex_);
        transportCallback_ = std::move(callback);
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

    uint32_t sampleRate() const { return sampleRate_; }
    uint32_t bufferSize() const { return bufferSize_; }
    uint32_t inputChannels() const { return static_cast<uint32_t>(inputPorts_.size()); }
    uint32_t outputChannels() const { return static_cast<uint32_t>(outputPorts_.size()); }
    std::string lastError() const { return lastError_; }

    float getLatencyMs() const {
        if (!client_) return 0.0f;
        jack_nframes_t latency = jack_get_buffer_size(client_);
        return static_cast<float>(latency) / sampleRate_ * 1000.0f;
    }

    float getCpuLoad() const {
        if (!client_) return 0.0f;
        return jack_cpu_load(client_);
    }

private:
    // MARK: - Static Callbacks

    static int processCallback(jack_nframes_t nframes, void* arg) {
        auto* engine = static_cast<JACKAudioEngine*>(arg);
        return engine->processAudio(nframes);
    }

    static int sampleRateCallback(jack_nframes_t nframes, void* arg) {
        auto* engine = static_cast<JACKAudioEngine*>(arg);
        engine->sampleRate_ = nframes;
        return 0;
    }

    static int bufferSizeCallback(jack_nframes_t nframes, void* arg) {
        auto* engine = static_cast<JACKAudioEngine*>(arg);
        engine->bufferSize_ = nframes;
        return 0;
    }

    static void shutdownCallback(void* arg) {
        auto* engine = static_cast<JACKAudioEngine*>(arg);
        engine->running_.store(false);
        engine->connected_ = false;
    }

    static int syncCallback(jack_transport_state_t state, jack_position_t* pos, void* arg) {
        // Always ready to roll
        return 1;
    }

    // MARK: - Audio Processing

    int processAudio(jack_nframes_t nframes) {
        if (!running_.load()) return 0;

        // Get port buffers
        for (size_t i = 0; i < inputPorts_.size(); i++) {
            inputPtrs_[i] = static_cast<float*>(
                jack_port_get_buffer(inputPorts_[i], nframes)
            );
        }

        for (size_t i = 0; i < outputPorts_.size(); i++) {
            outputPtrs_[i] = static_cast<float*>(
                jack_port_get_buffer(outputPorts_[i], nframes)
            );
            // Clear output buffer
            std::memset(outputPtrs_[i], 0, nframes * sizeof(float));
        }

        // Call user callback
        {
            std::lock_guard<std::mutex> lock(callbackMutex_);
            if (callback_) {
                callback_(
                    const_cast<const float* const*>(inputPtrs_.data()),
                    outputPtrs_.data(),
                    static_cast<int>(nframes),
                    static_cast<int>(inputPorts_.size()),
                    static_cast<int>(outputPorts_.size())
                );
            }
        }

        // Apply bio modulation
        applyBioModulation(nframes);

        // Transport callback
        if (config_.useTransport) {
            std::lock_guard<std::mutex> lock(transportMutex_);
            if (transportCallback_) {
                transportCallback_(getTransportState());
            }
        }

        return 0;
    }

    void autoConnectPorts() {
        // Get system capture ports (for our inputs)
        const char** capturePorts = jack_get_ports(
            client_,
            nullptr,
            JACK_DEFAULT_AUDIO_TYPE,
            JackPortIsPhysical | JackPortIsOutput
        );

        if (capturePorts) {
            for (size_t i = 0; i < inputPorts_.size() && capturePorts[i]; i++) {
                jack_connect(client_, capturePorts[i], jack_port_name(inputPorts_[i]));
            }
            jack_free(capturePorts);
        }

        // Get system playback ports (for our outputs)
        const char** playbackPorts = jack_get_ports(
            client_,
            nullptr,
            JACK_DEFAULT_AUDIO_TYPE,
            JackPortIsPhysical | JackPortIsInput
        );

        if (playbackPorts) {
            for (size_t i = 0; i < outputPorts_.size() && playbackPorts[i]; i++) {
                jack_connect(client_, jack_port_name(outputPorts_[i]), playbackPorts[i]);
            }
            jack_free(playbackPorts);
        }
    }

    void applyBioModulation(jack_nframes_t nframes) {
        std::lock_guard<std::mutex> lock(bioMutex_);

        if (hrvCoherence_ <= 0.0f) return;

        // Coherence-based subtle warmth
        float warmthAmount = hrvCoherence_ * 0.1f;

        for (size_t ch = 0; ch < outputPorts_.size(); ch++) {
            float* output = outputPtrs_[ch];
            for (jack_nframes_t i = 0; i < nframes; i++) {
                // Soft saturation for warmth
                float sample = output[i];
                float saturated = std::tanh(sample * (1.0f + warmthAmount * 0.5f));
                output[i] = sample + (saturated - sample) * warmthAmount;
            }
        }
    }

    // MARK: - Member Variables

    JACKConfig config_;
    jack_client_t* client_ = nullptr;
    bool connected_ = false;
    std::atomic<bool> running_{false};
    std::string lastError_;

    uint32_t sampleRate_ = 48000;
    uint32_t bufferSize_ = 256;

    std::vector<jack_port_t*> inputPorts_;
    std::vector<jack_port_t*> outputPorts_;
    std::vector<float*> inputPtrs_;
    std::vector<float*> outputPtrs_;

    AudioCallback callback_;
    std::mutex callbackMutex_;

    TransportCallback transportCallback_;
    std::mutex transportMutex_;

    // Quantum integration
    Quantum::QuantumLightEmulator* quantumEmulator_ = nullptr;

    // Bio modulation
    std::mutex bioMutex_;
    float heartRate_ = 60.0f;
    float hrvCoherence_ = 0.0f;
    float breathingRate_ = 6.0f;
};

#else // ECHOELMUSIC_JACK_AVAILABLE == 0

// ============================================================================
// MARK: - JACK Stub (not available)
// ============================================================================

class JACKAudioEngine {
public:
    using AudioCallback = std::function<void(
        const float* const* inputs,
        float* const* outputs,
        int numFrames,
        int numInputChannels,
        int numOutputChannels
    )>;

    using TransportCallback = std::function<void(const JACKTransportState& state)>;

    static std::vector<std::string> getAvailablePorts(bool = false) { return {}; }
    static bool isServerRunning() { return false; }

    bool connect(const JACKConfig& = JACKConfig()) {
        lastError_ = "JACK not available. Install libjack-dev or libjack-jackd2-dev";
        return false;
    }

    void disconnect() {}
    void start() {}
    void stop() {}
    bool isRunning() const { return false; }
    bool isConnected() const { return false; }
    bool connectPort(const std::string&, const std::string&) { return false; }
    bool disconnectPort(const std::string&, const std::string&) { return false; }
    std::string getPortName(int, bool) const { return ""; }
    void transportStart() {}
    void transportStop() {}
    void transportLocate(int64_t) {}
    JACKTransportState getTransportState() const { return {}; }
    void setCallback(AudioCallback) {}
    void setTransportCallback(TransportCallback) {}
    void setQuantumEmulator(Quantum::QuantumLightEmulator*) {}
    void setBioModulation(float, float, float) {}
    uint32_t sampleRate() const { return 48000; }
    uint32_t bufferSize() const { return 256; }
    uint32_t inputChannels() const { return 0; }
    uint32_t outputChannels() const { return 0; }
    std::string lastError() const { return lastError_; }
    float getLatencyMs() const { return 0.0f; }
    float getCpuLoad() const { return 0.0f; }

private:
    std::string lastError_ = "JACK not available";
};

#endif // ECHOELMUSIC_JACK_AVAILABLE

} // namespace Audio
} // namespace Echoelmusic

#endif // __linux__
