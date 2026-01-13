#pragma once
// ============================================================================
// EchoelDSP - WebAssembly Audio Backend
// ============================================================================
// Web Audio API integration for browser-based audio processing
// - AudioWorklet for low-latency processing
// - ScriptProcessorNode fallback
// - Web MIDI API integration
// - SharedArrayBuffer for lock-free audio
// ============================================================================
//
// STATUS: PLANNED - Full implementation in future release
// This file provides the API design and stub implementation
//
// ============================================================================

#include "../AudioBuffer.h"
#include "../SIMD.h"
#include <atomic>
#include <cstdint>
#include <functional>
#include <string>

// WebAssembly SIMD detection
#if defined(__wasm_simd128__)
#define ECHOEL_WASM_SIMD 1
#include <wasm_simd128.h>
#endif

namespace Echoel::DSP::WebAssembly {

// ============================================================================
// Web Audio Configuration
// ============================================================================

enum class AudioContextState : uint8_t {
    Suspended,
    Running,
    Closed
};

enum class ProcessorType : uint8_t {
    AudioWorklet,           // Preferred: Low-latency, dedicated thread
    ScriptProcessorNode     // Fallback: Main thread, higher latency
};

struct WebAudioConfig {
    uint32_t sampleRate{48000};
    uint32_t bufferSize{128};        // AudioWorklet uses 128 frames
    uint32_t inputChannels{2};
    uint32_t outputChannels{2};
    ProcessorType processorType{ProcessorType::AudioWorklet};
    bool useSharedArrayBuffer{true}; // For lock-free communication
    float latencyHint{0.01f};        // 10ms target latency
};

// ============================================================================
// Audio Callback (called from AudioWorklet)
// ============================================================================

using WebAudioCallback = std::function<void(
    const float* const* inputs,
    float* const* outputs,
    uint32_t numFrames,
    uint32_t numInputChannels,
    uint32_t numOutputChannels
)>;

// ============================================================================
// WebAssembly Audio Backend
// ============================================================================

class WebAssemblyBackend {
public:
    WebAssemblyBackend() = default;
    ~WebAssemblyBackend() { stop(); }

    // ========================================================================
    // Initialization
    // ========================================================================

    bool initialize(const WebAudioConfig& config) {
        config_ = config;

#if defined(__EMSCRIPTEN__)
        return initializeEmscripten();
#else
        // Non-WASM build - stub only
        lastError_ = "WebAssembly backend requires Emscripten compilation";
        return false;
#endif
    }

    // ========================================================================
    // Audio Context Control
    // ========================================================================

    bool resume() {
        // Resume AudioContext (required after user gesture)
#if defined(__EMSCRIPTEN__)
        return resumeAudioContext();
#else
        return false;
#endif
    }

    bool suspend() {
#if defined(__EMSCRIPTEN__)
        return suspendAudioContext();
#else
        return false;
#endif
    }

    AudioContextState getState() const noexcept {
        return state_.load(std::memory_order_acquire);
    }

    // ========================================================================
    // Audio Streaming
    // ========================================================================

    bool start(WebAudioCallback callback) {
        audioCallback_ = std::move(callback);
        running_.store(true, std::memory_order_release);

#if defined(__EMSCRIPTEN__)
        return startAudioWorklet();
#else
        return false;
#endif
    }

    void stop() {
        running_.store(false, std::memory_order_release);

#if defined(__EMSCRIPTEN__)
        stopAudioWorklet();
#endif

        audioCallback_ = nullptr;
    }

    bool isRunning() const noexcept {
        return running_.load(std::memory_order_acquire);
    }

    // ========================================================================
    // Latency
    // ========================================================================

    double getLatencyMs() const noexcept {
        // AudioWorklet typically achieves ~3-10ms latency
        return (config_.bufferSize * 1000.0) / config_.sampleRate;
    }

    double getOutputLatencyMs() const noexcept {
#if defined(__EMSCRIPTEN__)
        return getContextOutputLatency();
#else
        return getLatencyMs();
#endif
    }

    // ========================================================================
    // Browser Feature Detection
    // ========================================================================

    static bool isAudioWorkletSupported() {
#if defined(__EMSCRIPTEN__)
        return checkAudioWorkletSupport();
#else
        return false;
#endif
    }

    static bool isSharedArrayBufferSupported() {
#if defined(__EMSCRIPTEN__)
        return checkSharedArrayBufferSupport();
#else
        return false;
#endif
    }

    static bool isWasmSimdSupported() {
#if defined(ECHOEL_WASM_SIMD)
        return true;
#else
        return false;
#endif
    }

    // ========================================================================
    // Error Handling
    // ========================================================================

    const std::string& getLastError() const noexcept {
        return lastError_;
    }

private:
    WebAudioConfig config_;
    WebAudioCallback audioCallback_;

    std::atomic<bool> running_{false};
    std::atomic<AudioContextState> state_{AudioContextState::Suspended};

    std::string lastError_;

    // ========================================================================
    // Emscripten Implementation (Stubs for non-WASM builds)
    // ========================================================================

#if defined(__EMSCRIPTEN__)
    bool initializeEmscripten() {
        // Would use EM_ASM to create AudioContext
        // EM_ASM({
        //     Module.audioContext = new (window.AudioContext || window.webkitAudioContext)({
        //         sampleRate: $0,
        //         latencyHint: $1
        //     });
        // }, config_.sampleRate, config_.latencyHint);
        return true;
    }

    bool resumeAudioContext() {
        // EM_ASM({ Module.audioContext.resume(); });
        state_.store(AudioContextState::Running, std::memory_order_release);
        return true;
    }

    bool suspendAudioContext() {
        // EM_ASM({ Module.audioContext.suspend(); });
        state_.store(AudioContextState::Suspended, std::memory_order_release);
        return true;
    }

    bool startAudioWorklet() {
        // Would register AudioWorkletProcessor and create AudioWorkletNode
        // See: https://developer.mozilla.org/en-US/docs/Web/API/AudioWorklet
        return true;
    }

    void stopAudioWorklet() {
        // Disconnect and cleanup AudioWorkletNode
    }

    static double getContextOutputLatency() {
        // Would return Module.audioContext.outputLatency * 1000
        return 10.0;
    }

    static bool checkAudioWorkletSupport() {
        // EM_ASM_INT({ return 'AudioWorklet' in window ? 1 : 0; });
        return true;
    }

    static bool checkSharedArrayBufferSupport() {
        // EM_ASM_INT({ return typeof SharedArrayBuffer !== 'undefined' ? 1 : 0; });
        return true;
    }
#else
    bool initializeEmscripten() { return false; }
    bool resumeAudioContext() { return false; }
    bool suspendAudioContext() { return false; }
    bool startAudioWorklet() { return false; }
    void stopAudioWorklet() {}
    static double getContextOutputLatency() { return 0.0; }
    static bool checkAudioWorkletSupport() { return false; }
    static bool checkSharedArrayBufferSupport() { return false; }
#endif
};

// ============================================================================
// AudioWorklet Processor (JavaScript side - for reference)
// ============================================================================

/*
 * The AudioWorklet processor would be implemented in JavaScript:
 *
 * class EchoelProcessor extends AudioWorkletProcessor {
 *     constructor() {
 *         super();
 *         this.wasmModule = null;
 *         this.port.onmessage = (e) => {
 *             if (e.data.type === 'init') {
 *                 this.wasmModule = e.data.module;
 *             }
 *         };
 *     }
 *
 *     process(inputs, outputs, parameters) {
 *         if (!this.wasmModule) return true;
 *
 *         const input = inputs[0];
 *         const output = outputs[0];
 *
 *         // Call WASM processing function
 *         this.wasmModule._processAudio(
 *             input[0], input[1],
 *             output[0], output[1],
 *             128  // AudioWorklet buffer size
 *         );
 *
 *         return true;  // Keep processor alive
 *     }
 * }
 *
 * registerProcessor('echoel-processor', EchoelProcessor);
 */

// ============================================================================
// Web MIDI API Support
// ============================================================================

class WebMIDIAccess {
public:
    struct MIDIPort {
        std::string id;
        std::string name;
        std::string manufacturer;
        bool isInput{false};
        bool isOutput{false};
        bool isConnected{false};
    };

    using MIDIMessageCallback = std::function<void(const uint8_t* data, size_t length, double timestamp)>;

    static bool isSupported() {
#if defined(__EMSCRIPTEN__)
        // EM_ASM_INT({ return navigator.requestMIDIAccess ? 1 : 0; });
        return true;
#else
        return false;
#endif
    }

    bool requestAccess(bool sysex = false) {
#if defined(__EMSCRIPTEN__)
        // Would use navigator.requestMIDIAccess({ sysex: sysex })
        return true;
#else
        return false;
#endif
    }

    std::vector<MIDIPort> getInputPorts() const {
        return inputPorts_;
    }

    std::vector<MIDIPort> getOutputPorts() const {
        return outputPorts_;
    }

    bool openInput(const std::string& portId, MIDIMessageCallback callback) {
        midiCallback_ = std::move(callback);
        return true;
    }

    bool sendMessage(const std::string& portId, const uint8_t* data, size_t length) {
        return true;
    }

private:
    std::vector<MIDIPort> inputPorts_;
    std::vector<MIDIPort> outputPorts_;
    MIDIMessageCallback midiCallback_;
};

// ============================================================================
// WASM SIMD Optimized Operations
// ============================================================================

#if defined(ECHOEL_WASM_SIMD)

inline void processBlockSIMD(const float* input, float* output, size_t numSamples, float gain) {
    v128_t gainVec = wasm_f32x4_splat(gain);

    size_t i = 0;
    for (; i + 4 <= numSamples; i += 4) {
        v128_t in = wasm_v128_load(&input[i]);
        v128_t out = wasm_f32x4_mul(in, gainVec);
        wasm_v128_store(&output[i], out);
    }

    // Handle remaining samples
    for (; i < numSamples; ++i) {
        output[i] = input[i] * gain;
    }
}

inline float computeRMSSIMD(const float* buffer, size_t numSamples) {
    v128_t sum = wasm_f32x4_splat(0.0f);

    size_t i = 0;
    for (; i + 4 <= numSamples; i += 4) {
        v128_t samples = wasm_v128_load(&buffer[i]);
        v128_t squared = wasm_f32x4_mul(samples, samples);
        sum = wasm_f32x4_add(sum, squared);
    }

    // Horizontal sum
    float result[4];
    wasm_v128_store(result, sum);
    float totalSum = result[0] + result[1] + result[2] + result[3];

    // Handle remaining samples
    for (; i < numSamples; ++i) {
        totalSum += buffer[i] * buffer[i];
    }

    return std::sqrt(totalSum / numSamples);
}

#else

// Scalar fallback
inline void processBlockSIMD(const float* input, float* output, size_t numSamples, float gain) {
    for (size_t i = 0; i < numSamples; ++i) {
        output[i] = input[i] * gain;
    }
}

inline float computeRMSSIMD(const float* buffer, size_t numSamples) {
    float sum = 0.0f;
    for (size_t i = 0; i < numSamples; ++i) {
        sum += buffer[i] * buffer[i];
    }
    return std::sqrt(sum / numSamples);
}

#endif

} // namespace Echoel::DSP::WebAssembly
