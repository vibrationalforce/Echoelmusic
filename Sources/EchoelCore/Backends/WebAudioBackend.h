// =============================================================================
// WebAudioBackend - WebAssembly Audio Backend Stub
// =============================================================================
// Copyright (c) 2024-2026 Echoelmusic. All rights reserved.
// WASM/Emscripten audio backend - NO JUCE, NO iPlug2
// =============================================================================

#pragma once

#ifdef __EMSCRIPTEN__

#include <emscripten.h>
#include <emscripten/bind.h>
#include <emscripten/val.h>
#include "../EchoelCore.h"
#include <functional>
#include <atomic>

namespace EchoelCore {
namespace Web {

// =============================================================================
// Web Audio Configuration
// =============================================================================

struct WebAudioConfig {
    int sampleRate = 48000;
    int bufferSize = 256;  // 128, 256, 512, 1024, 2048, 4096
    int channelCount = 2;
    bool enableSIMD = true;  // Use WASM SIMD if available
};

// =============================================================================
// Web Audio Context Wrapper
// =============================================================================

class WebAudioContext {
public:
    using ProcessCallback = std::function<void(AudioBuffer<float>&)>;

    WebAudioContext() = default;
    ~WebAudioContext() { close(); }

    bool initialize(const WebAudioConfig& config) {
        config_ = config;
        buffer_.setSize(config.channelCount, config.bufferSize);

        // Create AudioContext via JavaScript
        EM_ASM({
            if (!window.EchoelAudioContext) {
                window.EchoelAudioContext = new (window.AudioContext || window.webkitAudioContext)({
                    sampleRate: $0,
                    latencyHint: 'interactive'
                });
            }
        }, config.sampleRate);

        sampleRate_ = config.sampleRate;
        return true;
    }

    bool start() {
        if (running_) return true;

        // Create ScriptProcessorNode or AudioWorkletNode
        EM_ASM({
            var ctx = window.EchoelAudioContext;
            if (ctx.state === 'suspended') {
                ctx.resume();
            }

            // Create processor node
            var bufferSize = $0;
            var channels = $1;

            window.EchoelProcessor = ctx.createScriptProcessor(bufferSize, channels, channels);

            window.EchoelProcessor.onaudioprocess = function(event) {
                var inputBuffer = event.inputBuffer;
                var outputBuffer = event.outputBuffer;

                // Get pointers from WASM module
                var inputPtr = Module._getInputBufferPtr();
                var outputPtr = Module._getOutputBufferPtr();

                // Copy input to WASM heap
                for (var ch = 0; ch < channels; ch++) {
                    var inputData = inputBuffer.getChannelData(ch);
                    for (var i = 0; i < bufferSize; i++) {
                        Module.HEAPF32[(inputPtr >> 2) + ch * bufferSize + i] = inputData[i];
                    }
                }

                // Process in WASM
                Module._processAudio(bufferSize, channels);

                // Copy output from WASM heap
                for (var ch = 0; ch < channels; ch++) {
                    var outputData = outputBuffer.getChannelData(ch);
                    for (var i = 0; i < bufferSize; i++) {
                        outputData[i] = Module.HEAPF32[(outputPtr >> 2) + ch * bufferSize + i];
                    }
                }
            };

            window.EchoelProcessor.connect(ctx.destination);
        }, config_.bufferSize, config_.channelCount);

        running_ = true;
        return true;
    }

    void stop() {
        if (!running_) return;

        EM_ASM({
            if (window.EchoelProcessor) {
                window.EchoelProcessor.disconnect();
                window.EchoelProcessor = null;
            }
        });

        running_ = false;
    }

    void close() {
        stop();

        EM_ASM({
            if (window.EchoelAudioContext) {
                window.EchoelAudioContext.close();
                window.EchoelAudioContext = null;
            }
        });
    }

    void setProcessCallback(ProcessCallback callback) {
        processCallback_ = callback;
    }

    // Called from JavaScript
    void processAudioBlock(float* input, float* output, int numFrames, int numChannels) {
        // Copy input to buffer
        for (int ch = 0; ch < numChannels && ch < buffer_.getNumChannels(); ++ch) {
            float* dest = buffer_.getWritePointer(ch);
            const float* src = input + ch * numFrames;
            std::copy(src, src + numFrames, dest);
        }

        // Process
        if (processCallback_) {
            processCallback_(buffer_);
        }

        // Copy to output
        for (int ch = 0; ch < numChannels && ch < buffer_.getNumChannels(); ++ch) {
            const float* src = buffer_.getReadPointer(ch);
            float* dest = output + ch * numFrames;
            std::copy(src, src + numFrames, dest);
        }
    }

    int getSampleRate() const { return sampleRate_; }
    int getChannelCount() const { return config_.channelCount; }
    bool isRunning() const { return running_; }

    float getLatencyMs() const {
        // Approximate latency based on buffer size
        return static_cast<float>(config_.bufferSize) / static_cast<float>(sampleRate_) * 1000.0f;
    }

private:
    WebAudioConfig config_;
    AudioBuffer<float> buffer_;
    ProcessCallback processCallback_;
    int sampleRate_ = 48000;
    std::atomic<bool> running_{false};
};

// =============================================================================
// WASM SIMD Utilities
// =============================================================================

namespace SIMD {

#ifdef __wasm_simd128__

inline void processVectorAdd(float* a, const float* b, int count) {
    int simdCount = count / 4;
    for (int i = 0; i < simdCount; ++i) {
        v128_t va = wasm_v128_load(a + i * 4);
        v128_t vb = wasm_v128_load(b + i * 4);
        v128_t result = wasm_f32x4_add(va, vb);
        wasm_v128_store(a + i * 4, result);
    }
    // Handle remainder
    for (int i = simdCount * 4; i < count; ++i) {
        a[i] += b[i];
    }
}

inline void processVectorMul(float* a, float scalar, int count) {
    v128_t vs = wasm_f32x4_splat(scalar);
    int simdCount = count / 4;
    for (int i = 0; i < simdCount; ++i) {
        v128_t va = wasm_v128_load(a + i * 4);
        v128_t result = wasm_f32x4_mul(va, vs);
        wasm_v128_store(a + i * 4, result);
    }
    for (int i = simdCount * 4; i < count; ++i) {
        a[i] *= scalar;
    }
}

#else

inline void processVectorAdd(float* a, const float* b, int count) {
    for (int i = 0; i < count; ++i) a[i] += b[i];
}

inline void processVectorMul(float* a, float scalar, int count) {
    for (int i = 0; i < count; ++i) a[i] *= scalar;
}

#endif

} // namespace SIMD

// =============================================================================
// Emscripten Bindings
// =============================================================================

// Global instance for JavaScript access
inline WebAudioContext* g_webAudioContext = nullptr;

extern "C" {

EMSCRIPTEN_KEEPALIVE
int initializeAudio(int sampleRate, int bufferSize, int channels) {
    if (!g_webAudioContext) {
        g_webAudioContext = new WebAudioContext();
    }

    WebAudioConfig config;
    config.sampleRate = sampleRate;
    config.bufferSize = bufferSize;
    config.channelCount = channels;

    return g_webAudioContext->initialize(config) ? 1 : 0;
}

EMSCRIPTEN_KEEPALIVE
int startAudio() {
    return g_webAudioContext ? (g_webAudioContext->start() ? 1 : 0) : 0;
}

EMSCRIPTEN_KEEPALIVE
void stopAudio() {
    if (g_webAudioContext) g_webAudioContext->stop();
}

EMSCRIPTEN_KEEPALIVE
void processAudio(int numFrames, int numChannels) {
    // Called from JavaScript audio callback
    // Implementation would use shared memory buffers
}

// Buffer pointers for JavaScript access
static std::vector<float> g_inputBuffer;
static std::vector<float> g_outputBuffer;

EMSCRIPTEN_KEEPALIVE
float* getInputBufferPtr() {
    return g_inputBuffer.data();
}

EMSCRIPTEN_KEEPALIVE
float* getOutputBufferPtr() {
    return g_outputBuffer.data();
}

EMSCRIPTEN_KEEPALIVE
void resizeBuffers(int numFrames, int numChannels) {
    int size = numFrames * numChannels;
    g_inputBuffer.resize(size, 0.0f);
    g_outputBuffer.resize(size, 0.0f);
}

} // extern "C"

} // namespace Web
} // namespace EchoelCore

#endif // __EMSCRIPTEN__
