#pragma once
// ============================================================================
// EchoelDSP/Backends/LinuxAudioBackend.h - Native Linux Audio
// ============================================================================
// Supports PipeWire (modern), ALSA (legacy), and JACK (pro audio)
// Auto-detects best available backend - PipeWire preferred
// ============================================================================

#if defined(__linux__) && !defined(__ANDROID__)

#include <functional>
#include <atomic>
#include <string>
#include <vector>
#include <thread>
#include <memory>
#include <cstring>
#include <dlfcn.h>
#include "../AudioBuffer.h"

// PipeWire headers (install: apt install libpipewire-0.3-dev)
#ifdef ECHOEL_USE_PIPEWIRE
#include <pipewire/pipewire.h>
#include <spa/param/audio/format-utils.h>
#endif

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
// MARK: - PipeWire Backend (Modern Linux)
// ============================================================================

#ifdef ECHOEL_USE_PIPEWIRE

class PipeWireBackend {
public:
    using AudioCallback = std::function<void(const float* const* inputs, float* const* outputs,
                                             int numInputChannels, int numOutputChannels,
                                             int numSamples)>;

    PipeWireBackend() {
        pw_init(nullptr, nullptr);
    }

    ~PipeWireBackend() {
        stop();
        pw_deinit();
    }

    std::vector<LinuxAudioDeviceInfo> getAvailableDevices() const {
        std::vector<LinuxAudioDeviceInfo> devices;

        // PipeWire default device
        LinuxAudioDeviceInfo defaultDev;
        defaultDev.deviceId = "pipewire:default";
        defaultDev.name = "PipeWire Default Output";
        defaultDev.isDefault = true;
        defaultDev.isInput = false;
        defaultDev.backend = LinuxAudioDeviceInfo::Backend::PipeWire;
        devices.push_back(defaultDev);

        return devices;
    }

    bool start(double sampleRate = 48000.0, int bufferSize = 256,
               int numInputChannels = 0, int numOutputChannels = 2)
    {
        if (running_.load()) return false;

        sampleRate_ = sampleRate;
        bufferSize_ = bufferSize;
        numInputChannels_ = numInputChannels;
        numOutputChannels_ = numOutputChannels;

        // Create PipeWire main loop
        loop_ = pw_main_loop_new(nullptr);
        if (!loop_) return false;

        // Create PipeWire context
        context_ = pw_context_new(pw_main_loop_get_loop(loop_), nullptr, 0);
        if (!context_) {
            pw_main_loop_destroy(loop_);
            loop_ = nullptr;
            return false;
        }

        // Create stream
        props_ = pw_properties_new(
            PW_KEY_MEDIA_TYPE, "Audio",
            PW_KEY_MEDIA_CATEGORY, "Playback",
            PW_KEY_MEDIA_ROLE, "Music",
            PW_KEY_APP_NAME, "Echoelmusic",
            nullptr);

        stream_ = pw_stream_new_simple(
            pw_main_loop_get_loop(loop_),
            "Echoelmusic Audio",
            props_,
            &streamEvents_,
            this);

        if (!stream_) {
            pw_context_destroy(context_);
            pw_main_loop_destroy(loop_);
            context_ = nullptr;
            loop_ = nullptr;
            return false;
        }

        // Set up audio format
        uint8_t buffer[1024];
        struct spa_pod_builder b = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));

        struct spa_audio_info_raw info = {};
        info.format = SPA_AUDIO_FORMAT_F32;
        info.channels = numOutputChannels;
        info.rate = static_cast<uint32_t>(sampleRate);

        const struct spa_pod* params[1];
        params[0] = spa_format_audio_raw_build(&b, SPA_PARAM_EnumFormat, &info);

        // Connect stream
        int res = pw_stream_connect(stream_,
            PW_DIRECTION_OUTPUT,
            PW_ID_ANY,
            static_cast<pw_stream_flags>(PW_STREAM_FLAG_AUTOCONNECT |
                                         PW_STREAM_FLAG_MAP_BUFFERS |
                                         PW_STREAM_FLAG_RT_PROCESS),
            params, 1);

        if (res < 0) {
            pw_stream_destroy(stream_);
            pw_context_destroy(context_);
            pw_main_loop_destroy(loop_);
            stream_ = nullptr;
            context_ = nullptr;
            loop_ = nullptr;
            return false;
        }

        // Allocate deinterleaved buffers
        deinterleavedBuffers_.resize(numOutputChannels);
        outputPtrs_.resize(numOutputChannels);
        for (int ch = 0; ch < numOutputChannels; ++ch) {
            deinterleavedBuffers_[ch].resize(bufferSize);
            outputPtrs_[ch] = deinterleavedBuffers_[ch].data();
        }

        // Start processing thread
        running_.store(true);
        audioThread_ = std::thread([this]() {
            pw_main_loop_run(loop_);
        });

        return true;
    }

    void stop() {
        if (!running_.load()) return;

        running_.store(false);

        if (loop_) {
            pw_main_loop_quit(loop_);
        }

        if (audioThread_.joinable()) {
            audioThread_.join();
        }

        if (stream_) {
            pw_stream_destroy(stream_);
            stream_ = nullptr;
        }

        if (context_) {
            pw_context_destroy(context_);
            context_ = nullptr;
        }

        if (loop_) {
            pw_main_loop_destroy(loop_);
            loop_ = nullptr;
        }
    }

    bool isRunning() const { return running_.load(); }

    void setCallback(AudioCallback callback) {
        callback_ = std::move(callback);
    }

    double getSampleRate() const { return sampleRate_; }
    int getBufferSize() const { return bufferSize_; }
    int getNumInputChannels() const { return numInputChannels_; }
    int getNumOutputChannels() const { return numOutputChannels_; }

private:
    static void onProcess(void* userdata) {
        auto* self = static_cast<PipeWireBackend*>(userdata);
        self->processCallback();
    }

    void processCallback() {
        struct pw_buffer* pwBuffer = pw_stream_dequeue_buffer(stream_);
        if (!pwBuffer) return;

        struct spa_buffer* buf = pwBuffer->buffer;
        float* dst = static_cast<float*>(buf->datas[0].data);
        if (!dst) {
            pw_stream_queue_buffer(stream_, pwBuffer);
            return;
        }

        uint32_t numFrames = buf->datas[0].maxsize / (sizeof(float) * numOutputChannels_);
        numFrames = std::min(numFrames, static_cast<uint32_t>(bufferSize_));

        // Call user callback with deinterleaved buffers
        if (callback_) {
            callback_(nullptr, outputPtrs_.data(), 0, numOutputChannels_, numFrames);

            // Interleave output
            for (uint32_t i = 0; i < numFrames; ++i) {
                for (int ch = 0; ch < numOutputChannels_; ++ch) {
                    dst[i * numOutputChannels_ + ch] = outputPtrs_[ch][i];
                }
            }
        } else {
            std::memset(dst, 0, numFrames * numOutputChannels_ * sizeof(float));
        }

        buf->datas[0].chunk->offset = 0;
        buf->datas[0].chunk->stride = sizeof(float) * numOutputChannels_;
        buf->datas[0].chunk->size = numFrames * sizeof(float) * numOutputChannels_;

        pw_stream_queue_buffer(stream_, pwBuffer);
    }

    static const struct pw_stream_events streamEvents_;

    struct pw_main_loop* loop_ = nullptr;
    struct pw_context* context_ = nullptr;
    struct pw_stream* stream_ = nullptr;
    struct pw_properties* props_ = nullptr;

    AudioCallback callback_;
    std::atomic<bool> running_{false};
    std::thread audioThread_;

    double sampleRate_ = 48000.0;
    int bufferSize_ = 256;
    int numInputChannels_ = 0;
    int numOutputChannels_ = 2;

    std::vector<std::vector<float>> deinterleavedBuffers_;
    std::vector<float*> outputPtrs_;
};

// Static stream events
const struct pw_stream_events PipeWireBackend::streamEvents_ = {
    .version = PW_VERSION_STREAM_EVENTS,
    .process = PipeWireBackend::onProcess,
};

#endif // ECHOEL_USE_PIPEWIRE

// ============================================================================
// MARK: - Linux Audio Backend (Auto-Select: PipeWire > ALSA)
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
        #ifdef ECHOEL_USE_PIPEWIRE
        if (pipeWireBackend_) {
            return pipeWireBackend_->getAvailableDevices();
        }
        #endif
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
        #ifdef ECHOEL_USE_PIPEWIRE
        if (pipeWireBackend_) {
            pipeWireBackend_->setCallback(callback_);
            return pipeWireBackend_->start(sampleRate, bufferSize,
                                           numInputChannels, numOutputChannels);
        }
        #endif
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
        #ifdef ECHOEL_USE_PIPEWIRE
        if (pipeWireBackend_) {
            pipeWireBackend_->stop();
        }
        #endif
        #ifdef ECHOEL_USE_ALSA
        if (alsaBackend_) {
            alsaBackend_->stop();
        }
        #endif
    }

    bool isRunning() const {
        #ifdef ECHOEL_USE_PIPEWIRE
        if (pipeWireBackend_) {
            return pipeWireBackend_->isRunning();
        }
        #endif
        #ifdef ECHOEL_USE_ALSA
        if (alsaBackend_) {
            return alsaBackend_->isRunning();
        }
        #endif
        return false;
    }

    void setCallback(AudioCallback callback) {
        callback_ = std::move(callback);
        #ifdef ECHOEL_USE_PIPEWIRE
        if (pipeWireBackend_) {
            pipeWireBackend_->setCallback(callback_);
        }
        #endif
        #ifdef ECHOEL_USE_ALSA
        if (alsaBackend_) {
            alsaBackend_->setCallback(callback_);
        }
        #endif
    }

    enum class ActiveBackend { None, ALSA, PipeWire, JACK };
    ActiveBackend getActiveBackend() const { return activeBackend_; }

    static bool isPipeWireAvailable() {
        // Check if PipeWire is running by trying to load the library
        void* handle = dlopen("libpipewire-0.3.so", RTLD_LAZY);
        if (handle) {
            dlclose(handle);
            return true;
        }
        return false;
    }

    static bool isALSAAvailable() {
        void* handle = dlopen("libasound.so.2", RTLD_LAZY);
        if (handle) {
            dlclose(handle);
            return true;
        }
        return false;
    }

private:
    void detectBestBackend() {
        // Priority: PipeWire (modern) > ALSA (legacy)
        // PipeWire is default on Fedora 34+, Ubuntu 22.10+, Arch, etc.

        #ifdef ECHOEL_USE_PIPEWIRE
        if (isPipeWireAvailable()) {
            pipeWireBackend_ = std::make_unique<PipeWireBackend>();
            activeBackend_ = ActiveBackend::PipeWire;
            return;
        }
        #endif

        #ifdef ECHOEL_USE_ALSA
        if (isALSAAvailable()) {
            alsaBackend_ = std::make_unique<ALSABackend>();
            activeBackend_ = ActiveBackend::ALSA;
            return;
        }
        #endif

        activeBackend_ = ActiveBackend::None;
    }

    AudioCallback callback_;
    ActiveBackend activeBackend_ = ActiveBackend::None;

    #ifdef ECHOEL_USE_PIPEWIRE
    std::unique_ptr<PipeWireBackend> pipeWireBackend_;
    #endif

    #ifdef ECHOEL_USE_ALSA
    std::unique_ptr<ALSABackend> alsaBackend_;
    #endif
};

} // namespace Echoel::DSP

#endif // __linux__ && !__ANDROID__
