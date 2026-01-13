// =============================================================================
// AAudioBackend - Android Native Audio Backend (AAudio/Oboe)
// =============================================================================
// Copyright (c) 2024-2026 Echoelmusic. All rights reserved.
// Native Android audio - NO JUCE, NO iPlug2
// =============================================================================

#pragma once

#ifdef __ANDROID__

#include <aaudio/AAudio.h>
#include <oboe/Oboe.h>
#include "../EchoelCore.h"
#include <memory>
#include <atomic>
#include <functional>

namespace EchoelCore {
namespace Android {

// =============================================================================
// AAudio Backend Configuration
// =============================================================================

struct AAudioConfig {
    int32_t sampleRate = 48000;
    int32_t framesPerBuffer = 256;
    int32_t channelCount = 2;
    aaudio_sharing_mode_t sharingMode = AAUDIO_SHARING_MODE_EXCLUSIVE;
    aaudio_performance_mode_t performanceMode = AAUDIO_PERFORMANCE_MODE_LOW_LATENCY;
    aaudio_direction_t direction = AAUDIO_DIRECTION_OUTPUT;

    // USB Audio Class support
    bool preferUSBDevice = false;
    int32_t deviceId = AAUDIO_UNSPECIFIED;
};

// =============================================================================
// AAudio Stream Wrapper
// =============================================================================

class AAudioStream {
public:
    using AudioCallback = std::function<void(float*, int32_t, int32_t)>;

    AAudioStream() = default;
    ~AAudioStream() { close(); }

    bool open(const AAudioConfig& config) {
        AAudioStreamBuilder* builder = nullptr;
        aaudio_result_t result = AAudio_createStreamBuilder(&builder);
        if (result != AAUDIO_OK) return false;

        AAudioStreamBuilder_setSampleRate(builder, config.sampleRate);
        AAudioStreamBuilder_setChannelCount(builder, config.channelCount);
        AAudioStreamBuilder_setFormat(builder, AAUDIO_FORMAT_PCM_FLOAT);
        AAudioStreamBuilder_setSharingMode(builder, config.sharingMode);
        AAudioStreamBuilder_setPerformanceMode(builder, config.performanceMode);
        AAudioStreamBuilder_setDirection(builder, config.direction);
        AAudioStreamBuilder_setFramesPerDataCallback(builder, config.framesPerBuffer);

        if (config.deviceId != AAUDIO_UNSPECIFIED) {
            AAudioStreamBuilder_setDeviceId(builder, config.deviceId);
        }

        AAudioStreamBuilder_setDataCallback(builder, dataCallback, this);
        AAudioStreamBuilder_setErrorCallback(builder, errorCallback, this);

        result = AAudioStreamBuilder_openStream(builder, &stream_);
        AAudioStreamBuilder_delete(builder);

        if (result != AAUDIO_OK) return false;

        sampleRate_ = AAudioStream_getSampleRate(stream_);
        channelCount_ = AAudioStream_getChannelCount(stream_);
        framesPerBuffer_ = AAudioStream_getFramesPerBurst(stream_);

        return true;
    }

    bool start() {
        if (!stream_) return false;
        running_ = true;
        return AAudioStream_requestStart(stream_) == AAUDIO_OK;
    }

    bool stop() {
        running_ = false;
        if (!stream_) return false;
        return AAudioStream_requestStop(stream_) == AAUDIO_OK;
    }

    void close() {
        running_ = false;
        if (stream_) {
            AAudioStream_close(stream_);
            stream_ = nullptr;
        }
    }

    void setCallback(AudioCallback callback) { callback_ = callback; }

    int32_t getSampleRate() const { return sampleRate_; }
    int32_t getChannelCount() const { return channelCount_; }
    int32_t getFramesPerBuffer() const { return framesPerBuffer_; }
    bool isRunning() const { return running_; }

    // Get actual latency in milliseconds
    float getLatencyMs() const {
        if (!stream_) return 0.0f;
        int64_t frames = 0;
        int64_t time = 0;
        if (AAudioStream_getTimestamp(stream_, CLOCK_MONOTONIC, &frames, &time) == AAUDIO_OK) {
            int64_t bufferFrames = AAudioStream_getBufferSizeInFrames(stream_);
            return (float)bufferFrames / (float)sampleRate_ * 1000.0f;
        }
        return (float)framesPerBuffer_ / (float)sampleRate_ * 1000.0f;
    }

private:
    static aaudio_data_callback_result_t dataCallback(
        AAudioStream* stream,
        void* userData,
        void* audioData,
        int32_t numFrames
    ) {
        auto* self = static_cast<AAudioStream*>(userData);
        if (self->callback_ && self->running_) {
            self->callback_(
                static_cast<float*>(audioData),
                numFrames,
                self->channelCount_
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
        // Handle stream disconnect (USB unplug, etc.)
        if (error == AAUDIO_ERROR_DISCONNECTED) {
            self->running_ = false;
            // Could trigger reconnection here
        }
    }

    AAudioStream* stream_ = nullptr;
    AudioCallback callback_;
    int32_t sampleRate_ = 48000;
    int32_t channelCount_ = 2;
    int32_t framesPerBuffer_ = 256;
    std::atomic<bool> running_{false};
};

// =============================================================================
// Oboe High-Level Wrapper (Preferred API)
// =============================================================================

class OboeAudioEngine : public oboe::AudioStreamDataCallback,
                        public oboe::AudioStreamErrorCallback {
public:
    using ProcessCallback = std::function<void(AudioBuffer<float>&)>;

    OboeAudioEngine() = default;
    ~OboeAudioEngine() { stop(); }

    bool start(const AAudioConfig& config) {
        oboe::AudioStreamBuilder builder;

        builder.setDirection(config.direction == AAUDIO_DIRECTION_INPUT
            ? oboe::Direction::Input : oboe::Direction::Output)
            ->setPerformanceMode(oboe::PerformanceMode::LowLatency)
            ->setSharingMode(config.sharingMode == AAUDIO_SHARING_MODE_EXCLUSIVE
                ? oboe::SharingMode::Exclusive : oboe::SharingMode::Shared)
            ->setFormat(oboe::AudioFormat::Float)
            ->setChannelCount(config.channelCount)
            ->setSampleRate(config.sampleRate)
            ->setFramesPerDataCallback(config.framesPerBuffer)
            ->setDataCallback(this)
            ->setErrorCallback(this);

        if (config.deviceId != AAUDIO_UNSPECIFIED) {
            builder.setDeviceId(config.deviceId);
        }

        oboe::Result result = builder.openStream(stream_);
        if (result != oboe::Result::OK) return false;

        sampleRate_ = stream_->getSampleRate();
        channelCount_ = stream_->getChannelCount();
        buffer_.setSize(channelCount_, config.framesPerBuffer);

        result = stream_->requestStart();
        running_ = (result == oboe::Result::OK);
        return running_;
    }

    void stop() {
        running_ = false;
        if (stream_) {
            stream_->requestStop();
            stream_->close();
            stream_.reset();
        }
    }

    void setProcessCallback(ProcessCallback callback) {
        processCallback_ = callback;
    }

    // Oboe callbacks
    oboe::DataCallbackResult onAudioReady(
        oboe::AudioStream* stream,
        void* audioData,
        int32_t numFrames
    ) override {
        if (!running_) return oboe::DataCallbackResult::Stop;

        buffer_.setSize(channelCount_, numFrames);
        float* data = static_cast<float*>(audioData);

        // Deinterleave if needed and process
        if (processCallback_) {
            // Copy interleaved data to buffer
            for (int frame = 0; frame < numFrames; ++frame) {
                for (int ch = 0; ch < channelCount_; ++ch) {
                    buffer_.getWritePointer(ch)[frame] = data[frame * channelCount_ + ch];
                }
            }

            processCallback_(buffer_);

            // Copy back to interleaved
            for (int frame = 0; frame < numFrames; ++frame) {
                for (int ch = 0; ch < channelCount_; ++ch) {
                    data[frame * channelCount_ + ch] = buffer_.getReadPointer(ch)[frame];
                }
            }
        }

        return oboe::DataCallbackResult::Continue;
    }

    void onErrorBeforeClose(oboe::AudioStream* stream, oboe::Result error) override {
        // Log error
    }

    void onErrorAfterClose(oboe::AudioStream* stream, oboe::Result error) override {
        // Attempt to restart stream if disconnected
        if (error == oboe::Result::ErrorDisconnected) {
            // Could implement automatic reconnection
        }
    }

    int32_t getSampleRate() const { return sampleRate_; }
    int32_t getChannelCount() const { return channelCount_; }
    bool isRunning() const { return running_; }

    float getLatencyMs() const {
        if (!stream_) return 0.0f;
        auto result = stream_->calculateLatencyMillis();
        return result ? static_cast<float>(*result) : 0.0f;
    }

private:
    std::shared_ptr<oboe::AudioStream> stream_;
    ProcessCallback processCallback_;
    AudioBuffer<float> buffer_;
    int32_t sampleRate_ = 48000;
    int32_t channelCount_ = 2;
    std::atomic<bool> running_{false};
};

// =============================================================================
// USB Audio Class Device Discovery
// =============================================================================

class USBAudioDeviceManager {
public:
    struct USBDevice {
        int32_t deviceId;
        std::string name;
        std::string manufacturer;
        int32_t sampleRate;
        int32_t channelCount;
        bool isInput;
        bool isOutput;
    };

    static std::vector<USBDevice> getUSBDevices() {
        std::vector<USBDevice> devices;

        // Query available devices through AAudio
        // Note: Full implementation requires JNI call to AudioManager
        // This is a simplified version

        return devices;
    }

    static int32_t findPreferredUSBDevice() {
        auto devices = getUSBDevices();
        for (const auto& device : devices) {
            if (device.isOutput) {
                return device.deviceId;
            }
        }
        return AAUDIO_UNSPECIFIED;
    }
};

} // namespace Android
} // namespace EchoelCore

#endif // __ANDROID__
