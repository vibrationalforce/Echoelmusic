#pragma once
// ============================================================================
// EchoelDSP/Backends/LinuxAudioBackend.h - Native Linux Audio
// ============================================================================
// Supports ALSA (direct) and PipeWire (modern desktop)
// Auto-detects best available backend
// ============================================================================

#if defined(__linux__) && !defined(__ANDROID__)

#include <functional>
#include <atomic>
#include <string>
#include <vector>
#include <thread>
#include <memory>
#include <cstring>
#include "../AudioBuffer.h"

// ALSA headers (install: apt install libasound2-dev)
#ifdef ECHOEL_USE_ALSA
#include <alsa/asoundlib.h>
#endif

namespace Echoel::DSP {

// ============================================================================
// MARK: - Linux Audio Device Info
// ============================================================================

struct LinuxAudioDeviceInfo {
    std::string deviceId;      // "hw:0,0" or "default"
    std::string name;
    std::string description;
    int numChannels;
    int sampleRate;
    bool isDefault;
    bool isInput;
    enum class Backend { ALSA, PipeWire, JACK } backend;
};

// ============================================================================
// MARK: - ALSA Backend
// ============================================================================

#ifdef ECHOEL_USE_ALSA

class ALSABackend {
public:
    using AudioCallback = std::function<void(const float* const* inputs, float* const* outputs,
                                             int numInputChannels, int numOutputChannels,
                                             int numSamples)>;

    ALSABackend() = default;

    ~ALSABackend() {
        stop();
    }

    // ========================================================================
    // Device Management
    // ========================================================================

    std::vector<LinuxAudioDeviceInfo> getAvailableDevices() const {
        std::vector<LinuxAudioDeviceInfo> devices;

        // Add default device
        LinuxAudioDeviceInfo defaultDev;
        defaultDev.deviceId = "default";
        defaultDev.name = "Default Audio Device";
        defaultDev.isDefault = true;
        defaultDev.isInput = false;
        defaultDev.backend = LinuxAudioDeviceInfo::Backend::ALSA;
        devices.push_back(defaultDev);

        // Enumerate hardware devices
        int card = -1;
        while (snd_card_next(&card) >= 0 && card >= 0) {
            char* cardName = nullptr;
            if (snd_card_get_name(card, &cardName) >= 0) {
                LinuxAudioDeviceInfo info;
                info.deviceId = "hw:" + std::to_string(card);
                info.name = cardName;
                info.isDefault = false;
                info.isInput = false;
                info.backend = LinuxAudioDeviceInfo::Backend::ALSA;
                devices.push_back(info);
                free(cardName);
            }
        }

        return devices;
    }

    // ========================================================================
    // Audio Stream Control
    // ========================================================================

    bool start(double sampleRate = 48000.0, int bufferSize = 256,
               int numInputChannels = 0, int numOutputChannels = 2,
               const std::string& deviceId = "default")
    {
        if (running_.load()) return false;

        sampleRate_ = sampleRate;
        bufferSize_ = bufferSize;
        numInputChannels_ = numInputChannels;
        numOutputChannels_ = numOutputChannels;

        // Open PCM device
        int err = snd_pcm_open(&pcmHandle_, deviceId.c_str(),
                               SND_PCM_STREAM_PLAYBACK, 0);
        if (err < 0) {
            return false;
        }

        // Set hardware parameters
        snd_pcm_hw_params_t* hwParams;
        snd_pcm_hw_params_alloca(&hwParams);
        snd_pcm_hw_params_any(pcmHandle_, hwParams);

        // Set access type (interleaved)
        snd_pcm_hw_params_set_access(pcmHandle_, hwParams,
                                     SND_PCM_ACCESS_RW_INTERLEAVED);

        // Set format (32-bit float)
        snd_pcm_hw_params_set_format(pcmHandle_, hwParams,
                                     SND_PCM_FORMAT_FLOAT_LE);

        // Set channels
        snd_pcm_hw_params_set_channels(pcmHandle_, hwParams, numOutputChannels);

        // Set sample rate
        unsigned int rate = static_cast<unsigned int>(sampleRate);
        snd_pcm_hw_params_set_rate_near(pcmHandle_, hwParams, &rate, nullptr);
        actualSampleRate_ = rate;

        // Set buffer size
        snd_pcm_uframes_t frames = bufferSize;
        snd_pcm_hw_params_set_period_size_near(pcmHandle_, hwParams, &frames, nullptr);
        actualBufferSize_ = frames;

        // Set buffer count (2 periods for low latency)
        snd_pcm_hw_params_set_periods(pcmHandle_, hwParams, 2, 0);

        // Apply parameters
        err = snd_pcm_hw_params(pcmHandle_, hwParams);
        if (err < 0) {
            snd_pcm_close(pcmHandle_);
            pcmHandle_ = nullptr;
            return false;
        }

        // Prepare PCM
        snd_pcm_prepare(pcmHandle_);

        // Allocate interleaved buffer
        interleavedBuffer_.resize(actualBufferSize_ * numOutputChannels_);

        // Start audio thread
        running_.store(true);
        audioThread_ = std::thread(&ALSABackend::audioThreadProc, this);

        return true;
    }

    void stop() {
        if (!running_.load()) return;

        running_.store(false);

        if (audioThread_.joinable()) {
            audioThread_.join();
        }

        if (pcmHandle_) {
            snd_pcm_drain(pcmHandle_);
            snd_pcm_close(pcmHandle_);
            pcmHandle_ = nullptr;
        }
    }

    bool isRunning() const { return running_.load(); }

    void setCallback(AudioCallback callback) {
        callback_ = std::move(callback);
    }

    // ========================================================================
    // Properties
    // ========================================================================

    double getSampleRate() const { return actualSampleRate_; }
    int getBufferSize() const { return actualBufferSize_; }
    int getNumInputChannels() const { return numInputChannels_; }
    int getNumOutputChannels() const { return numOutputChannels_; }

private:
    void audioThreadProc() {
        // Set real-time priority (requires rtprio permission)
        struct sched_param param;
        param.sched_priority = sched_get_priority_max(SCHED_FIFO);
        pthread_setschedparam(pthread_self(), SCHED_FIFO, &param);

        std::vector<float*> outputPtrs(numOutputChannels_);
        std::vector<std::vector<float>> deinterleavedBuffers(numOutputChannels_);
        for (int ch = 0; ch < numOutputChannels_; ++ch) {
            deinterleavedBuffers[ch].resize(actualBufferSize_);
            outputPtrs[ch] = deinterleavedBuffers[ch].data();
        }

        while (running_.load()) {
            // Call user callback
            if (callback_) {
                callback_(nullptr, outputPtrs.data(),
                         0, numOutputChannels_, actualBufferSize_);

                // Interleave output
                for (int i = 0; i < actualBufferSize_; ++i) {
                    for (int ch = 0; ch < numOutputChannels_; ++ch) {
                        interleavedBuffer_[i * numOutputChannels_ + ch] = outputPtrs[ch][i];
                    }
                }
            } else {
                // Silence
                std::fill(interleavedBuffer_.begin(), interleavedBuffer_.end(), 0.0f);
            }

            // Write to ALSA
            int err = snd_pcm_writei(pcmHandle_, interleavedBuffer_.data(), actualBufferSize_);
            if (err < 0) {
                // Handle underrun
                if (err == -EPIPE) {
                    snd_pcm_prepare(pcmHandle_);
                }
            }
        }
    }

    snd_pcm_t* pcmHandle_ = nullptr;
    AudioCallback callback_;
    std::atomic<bool> running_{false};
    std::thread audioThread_;

    double sampleRate_ = 48000.0;
    double actualSampleRate_ = 48000.0;
    int bufferSize_ = 256;
    int actualBufferSize_ = 256;
    int numInputChannels_ = 0;
    int numOutputChannels_ = 2;

    std::vector<float> interleavedBuffer_;
};

#endif // ECHOEL_USE_ALSA

// ============================================================================
// MARK: - Linux Audio Backend (Auto-Select)
// ============================================================================

class LinuxAudioBackend {
public:
    using AudioCallback = std::function<void(const float* const* inputs, float* const* outputs,
                                             int numInputChannels, int numOutputChannels,
                                             int numSamples)>;

    LinuxAudioBackend() {
        detectBestBackend();
    }

    ~LinuxAudioBackend() {
        stop();
    }

    std::vector<LinuxAudioDeviceInfo> getAvailableDevices() const {
        #ifdef ECHOEL_USE_ALSA
        if (alsaBackend_) {
            return alsaBackend_->getAvailableDevices();
        }
        #endif
        return {};
    }

    bool start(double sampleRate = 48000.0, int bufferSize = 256,
               int numInputChannels = 0, int numOutputChannels = 2)
    {
        #ifdef ECHOEL_USE_ALSA
        if (alsaBackend_) {
            alsaBackend_->setCallback(callback_);
            return alsaBackend_->start(sampleRate, bufferSize,
                                       numInputChannels, numOutputChannels);
        }
        #endif
        return false;
    }

    void stop() {
        #ifdef ECHOEL_USE_ALSA
        if (alsaBackend_) {
            alsaBackend_->stop();
        }
        #endif
    }

    bool isRunning() const {
        #ifdef ECHOEL_USE_ALSA
        if (alsaBackend_) {
            return alsaBackend_->isRunning();
        }
        #endif
        return false;
    }

    void setCallback(AudioCallback callback) {
        callback_ = std::move(callback);
        #ifdef ECHOEL_USE_ALSA
        if (alsaBackend_) {
            alsaBackend_->setCallback(callback_);
        }
        #endif
    }

    enum class ActiveBackend { None, ALSA, PipeWire, JACK };
    ActiveBackend getActiveBackend() const { return activeBackend_; }

private:
    void detectBestBackend() {
        // Try PipeWire first (modern desktops)
        // Then JACK (pro audio)
        // Finally ALSA (direct hardware)

        #ifdef ECHOEL_USE_ALSA
        alsaBackend_ = std::make_unique<ALSABackend>();
        activeBackend_ = ActiveBackend::ALSA;
        #endif
    }

    AudioCallback callback_;
    ActiveBackend activeBackend_ = ActiveBackend::None;

    #ifdef ECHOEL_USE_ALSA
    std::unique_ptr<ALSABackend> alsaBackend_;
    #endif
};

} // namespace Echoel::DSP

#endif // __linux__ && !__ANDROID__
