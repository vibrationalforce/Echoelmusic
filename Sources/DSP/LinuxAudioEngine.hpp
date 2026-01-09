/**
 * LinuxAudioEngine.hpp
 * Echoelmusic - Linux ALSA Audio Integration
 *
 * Low-latency audio for Linux using ALSA
 * 300% Power Mode - Tauchfliegen Edition
 *
 * Created: 2026-01-05
 */

#pragma once

#ifdef __linux__

#include <alsa/asoundlib.h>
#include <atomic>
#include <thread>
#include <functional>
#include <vector>
#include <cmath>
#include <memory>

#include "QuantumLightEmulator.hpp"

namespace Echoelmusic {
namespace Audio {

// ============================================================================
// MARK: - Audio Configuration
// ============================================================================

struct AudioConfig {
    unsigned int sampleRate = 48000;
    unsigned int bufferSize = 256;
    unsigned int channels = 2;
    snd_pcm_format_t format = SND_PCM_FORMAT_FLOAT;
    std::string deviceName = "default";
};

// ============================================================================
// MARK: - Linux Audio Engine
// ============================================================================

class LinuxAudioEngine {
public:
    using AudioCallback = std::function<void(float* output, int numFrames, int numChannels)>;

    LinuxAudioEngine() = default;

    ~LinuxAudioEngine() {
        stop();
    }

    // MARK: - Initialization

    bool initialize(const AudioConfig& config = AudioConfig()) {
        config_ = config;

        int err;

        // Open PCM device for playback
        err = snd_pcm_open(&pcmHandle_, config_.deviceName.c_str(),
                          SND_PCM_STREAM_PLAYBACK, 0);
        if (err < 0) {
            lastError_ = "Cannot open PCM device: " + std::string(snd_strerror(err));
            return false;
        }

        // Allocate hardware parameters object
        snd_pcm_hw_params_t* hwParams;
        snd_pcm_hw_params_alloca(&hwParams);

        // Fill with default values
        snd_pcm_hw_params_any(pcmHandle_, hwParams);

        // Set parameters
        snd_pcm_hw_params_set_access(pcmHandle_, hwParams, SND_PCM_ACCESS_RW_INTERLEAVED);
        snd_pcm_hw_params_set_format(pcmHandle_, hwParams, config_.format);
        snd_pcm_hw_params_set_channels(pcmHandle_, hwParams, config_.channels);

        unsigned int actualRate = config_.sampleRate;
        snd_pcm_hw_params_set_rate_near(pcmHandle_, hwParams, &actualRate, nullptr);
        config_.sampleRate = actualRate;

        snd_pcm_uframes_t periodSize = config_.bufferSize;
        snd_pcm_hw_params_set_period_size_near(pcmHandle_, hwParams, &periodSize, nullptr);
        config_.bufferSize = periodSize;

        // Apply hardware parameters
        err = snd_pcm_hw_params(pcmHandle_, hwParams);
        if (err < 0) {
            lastError_ = "Cannot set HW params: " + std::string(snd_strerror(err));
            snd_pcm_close(pcmHandle_);
            pcmHandle_ = nullptr;
            return false;
        }

        // Allocate buffer
        buffer_.resize(config_.bufferSize * config_.channels);

        initialized_ = true;
        return true;
    }

    // MARK: - Lifecycle

    void start() {
        if (!initialized_ || running_.load()) return;

        running_.store(true);
        audioThread_ = std::thread([this]() {
            audioLoop();
        });
    }

    void stop() {
        running_.store(false);

        if (audioThread_.joinable()) {
            audioThread_.join();
        }

        if (pcmHandle_) {
            snd_pcm_drain(pcmHandle_);
            snd_pcm_close(pcmHandle_);
            pcmHandle_ = nullptr;
        }

        initialized_ = false;
    }

    bool isRunning() const { return running_.load(); }

    // MARK: - Callback

    void setCallback(AudioCallback callback) {
        callback_ = std::move(callback);
    }

    // MARK: - Quantum Integration

    void setQuantumEmulator(Quantum::QuantumLightEmulator* emulator) {
        quantumEmulator_ = emulator;
    }

    // MARK: - Getters

    unsigned int sampleRate() const { return config_.sampleRate; }
    unsigned int bufferSize() const { return config_.bufferSize; }
    unsigned int channels() const { return config_.channels; }
    std::string lastError() const { return lastError_; }

private:
    void audioLoop() {
        while (running_.load()) {
            // Clear buffer
            std::fill(buffer_.begin(), buffer_.end(), 0.0f);

            // Call user callback
            if (callback_) {
                callback_(buffer_.data(), config_.bufferSize, config_.channels);
            }

            // Apply quantum processing if available
            if (quantumEmulator_ && quantumEmulator_->isRunning()) {
                quantumEmulator_->processAudio(buffer_.data(),
                                              buffer_.size());
            }

            // Write to ALSA
            int err = snd_pcm_writei(pcmHandle_, buffer_.data(), config_.bufferSize);

            if (err == -EPIPE) {
                // Buffer underrun
                snd_pcm_prepare(pcmHandle_);
            } else if (err < 0) {
                // Other error - try to recover
                snd_pcm_recover(pcmHandle_, err, 0);
            }
        }
    }

    snd_pcm_t* pcmHandle_ = nullptr;
    AudioConfig config_;
    std::vector<float> buffer_;

    AudioCallback callback_;
    Quantum::QuantumLightEmulator* quantumEmulator_ = nullptr;

    std::atomic<bool> running_{false};
    std::thread audioThread_;
    bool initialized_ = false;
    std::string lastError_;
};

// ============================================================================
// MARK: - ALSA Mixer Control
// ============================================================================

class ALSAMixer {
public:
    ALSAMixer(const std::string& cardName = "default", const std::string& elementName = "Master")
        : cardName_(cardName), elementName_(elementName) {}

    ~ALSAMixer() {
        close();
    }

    bool open() {
        int err = snd_mixer_open(&mixerHandle_, 0);
        if (err < 0) return false;

        err = snd_mixer_attach(mixerHandle_, cardName_.c_str());
        if (err < 0) {
            snd_mixer_close(mixerHandle_);
            mixerHandle_ = nullptr;
            return false;
        }

        err = snd_mixer_selem_register(mixerHandle_, nullptr, nullptr);
        if (err < 0) {
            snd_mixer_close(mixerHandle_);
            mixerHandle_ = nullptr;
            return false;
        }

        err = snd_mixer_load(mixerHandle_);
        if (err < 0) {
            snd_mixer_close(mixerHandle_);
            mixerHandle_ = nullptr;
            return false;
        }

        // Find the element
        snd_mixer_selem_id_t* sid;
        snd_mixer_selem_id_alloca(&sid);
        snd_mixer_selem_id_set_index(sid, 0);
        snd_mixer_selem_id_set_name(sid, elementName_.c_str());

        mixerElement_ = snd_mixer_find_selem(mixerHandle_, sid);

        return mixerElement_ != nullptr;
    }

    void close() {
        if (mixerHandle_) {
            snd_mixer_close(mixerHandle_);
            mixerHandle_ = nullptr;
            mixerElement_ = nullptr;
        }
    }

    float getVolume() {
        if (!mixerElement_) return 0.0f;

        long minVol, maxVol, currentVol;
        snd_mixer_selem_get_playback_volume_range(mixerElement_, &minVol, &maxVol);
        snd_mixer_selem_get_playback_volume(mixerElement_, SND_MIXER_SCHN_MONO, &currentVol);

        return static_cast<float>(currentVol - minVol) / (maxVol - minVol);
    }

    void setVolume(float volume) {
        if (!mixerElement_) return;

        volume = std::clamp(volume, 0.0f, 1.0f);

        long minVol, maxVol;
        snd_mixer_selem_get_playback_volume_range(mixerElement_, &minVol, &maxVol);

        long newVol = minVol + static_cast<long>(volume * (maxVol - minVol));
        snd_mixer_selem_set_playback_volume_all(mixerElement_, newVol);
    }

    bool getMute() {
        if (!mixerElement_) return false;

        int muted;
        snd_mixer_selem_get_playback_switch(mixerElement_, SND_MIXER_SCHN_MONO, &muted);
        return muted == 0;
    }

    void setMute(bool mute) {
        if (!mixerElement_) return;
        snd_mixer_selem_set_playback_switch_all(mixerElement_, mute ? 0 : 1);
    }

private:
    std::string cardName_;
    std::string elementName_;
    snd_mixer_t* mixerHandle_ = nullptr;
    snd_mixer_elem_t* mixerElement_ = nullptr;
};

// ============================================================================
// MARK: - Binaural Beat Generator
// ============================================================================

class BinauralBeatGenerator {
public:
    BinauralBeatGenerator(float baseFrequency = 200.0f, float beatFrequency = 10.0f)
        : baseFrequency_(baseFrequency)
        , beatFrequency_(beatFrequency)
    {}

    void setSampleRate(unsigned int sampleRate) {
        sampleRate_ = sampleRate;
    }

    void setBaseFrequency(float freq) {
        baseFrequency_ = freq;
    }

    void setBeatFrequency(float freq) {
        beatFrequency_ = freq;
    }

    void setAmplitude(float amp) {
        amplitude_ = std::clamp(amp, 0.0f, 1.0f);
    }

    // Generate stereo binaural beat
    void generate(float* leftChannel, float* rightChannel, int numSamples) {
        float leftFreq = baseFrequency_;
        float rightFreq = baseFrequency_ + beatFrequency_;

        float leftPhaseInc = 2.0f * M_PI * leftFreq / sampleRate_;
        float rightPhaseInc = 2.0f * M_PI * rightFreq / sampleRate_;

        for (int i = 0; i < numSamples; ++i) {
            leftChannel[i] = amplitude_ * std::sin(leftPhase_);
            rightChannel[i] = amplitude_ * std::sin(rightPhase_);

            leftPhase_ += leftPhaseInc;
            rightPhase_ += rightPhaseInc;

            // Wrap phases
            if (leftPhase_ > 2.0f * M_PI) leftPhase_ -= 2.0f * M_PI;
            if (rightPhase_ > 2.0f * M_PI) rightPhase_ -= 2.0f * M_PI;
        }
    }

    // Generate interleaved stereo
    void generateInterleaved(float* output, int numFrames) {
        for (int i = 0; i < numFrames; ++i) {
            float leftFreq = baseFrequency_;
            float rightFreq = baseFrequency_ + beatFrequency_;

            float leftPhaseInc = 2.0f * M_PI * leftFreq / sampleRate_;
            float rightPhaseInc = 2.0f * M_PI * rightFreq / sampleRate_;

            output[i * 2] = amplitude_ * std::sin(leftPhase_);
            output[i * 2 + 1] = amplitude_ * std::sin(rightPhase_);

            leftPhase_ += leftPhaseInc;
            rightPhase_ += rightPhaseInc;

            if (leftPhase_ > 2.0f * M_PI) leftPhase_ -= 2.0f * M_PI;
            if (rightPhase_ > 2.0f * M_PI) rightPhase_ -= 2.0f * M_PI;
        }
    }

private:
    float baseFrequency_ = 200.0f;
    float beatFrequency_ = 10.0f;
    float amplitude_ = 0.5f;
    unsigned int sampleRate_ = 48000;
    float leftPhase_ = 0.0f;
    float rightPhase_ = 0.0f;
};

} // namespace Audio
} // namespace Echoelmusic

#endif // __linux__
