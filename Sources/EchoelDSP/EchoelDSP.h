#pragma once
// ============================================================================
// EchoelDSP - Zero-Dependency High-Performance Audio DSP Library
// ============================================================================
//
// 🚀 JUCE-FREE | iPlug2-FREE | Pure C++17 | SIMD-Optimized
//
// Copyright (c) 2026 Echoelmusic. MIT License.
//
// Features:
// - Platform-agnostic SIMD (ARM NEON, x86 AVX2/SSE4, WebAssembly)
// - Lock-free audio buffers and ring buffers
// - High-performance FFT (Split-Radix algorithm)
// - Complete filter library (Biquad, SVF, Multiband)
// - Real-time safe (no heap allocation in audio callbacks)
// - Cache-aligned memory for maximum throughput
//
// Supported Platforms:
// - Apple Silicon (macOS, iOS, visionOS, watchOS, tvOS)
// - Intel/AMD x64 (macOS, Windows, Linux)
// - ARM64 (Android, Linux)
// - WebAssembly (Browser PWA)
//
// ============================================================================

#include "SIMD.h"
#include "AudioBuffer.h"
#include "FFT.h"
#include "Filters.h"

namespace Echoel::DSP {

// ============================================================================
// MARK: - Version Info
// ============================================================================

struct Version {
    static constexpr int major = 1;
    static constexpr int minor = 0;
    static constexpr int patch = 0;
    static constexpr const char* string = "1.0.0";
    static constexpr const char* name = "EchoelDSP";
    static constexpr const char* license = "MIT";
};

// ============================================================================
// MARK: - Audio Processor Interface
// ============================================================================

/// Base class for all audio processors
class AudioProcessor {
public:
    virtual ~AudioProcessor() = default;

    /// Prepare the processor for playback
    virtual void prepare(double sampleRate, int maxBlockSize) {
        sampleRate_ = sampleRate;
        maxBlockSize_ = maxBlockSize;
    }

    /// Process a block of audio
    virtual void process(AudioBuffer<float>& buffer) = 0;

    /// Reset internal state
    virtual void reset() {}

    double getSampleRate() const { return sampleRate_; }
    int getMaxBlockSize() const { return maxBlockSize_; }

protected:
    double sampleRate_ = 44100.0;
    int maxBlockSize_ = 512;
};

// ============================================================================
// MARK: - Gain Processor
// ============================================================================

class GainProcessor : public AudioProcessor {
public:
    void setGain(float gainDb) {
        targetGain_ = std::pow(10.0f, gainDb / 20.0f);
    }

    void setGainLinear(float gain) {
        targetGain_ = gain;
    }

    void process(AudioBuffer<float>& buffer) override {
        float gain = currentGain_;
        float delta = (targetGain_ - currentGain_) / buffer.getNumSamples();

        for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
            float* samples = buffer.getWritePointer(ch);
            float g = gain;
            for (int i = 0; i < buffer.getNumSamples(); ++i) {
                samples[i] *= g;
                g += delta;
            }
        }

        currentGain_ = targetGain_;
    }

    void reset() override {
        currentGain_ = targetGain_;
    }

private:
    float targetGain_ = 1.0f;
    float currentGain_ = 1.0f;
};

// ============================================================================
// MARK: - Delay Line
// ============================================================================

class DelayLine {
public:
    void prepare(int maxDelaySamples) {
        buffer_.resize(maxDelaySamples, 0.0f);
        maxDelay_ = maxDelaySamples;
        writePos_ = 0;
    }

    void setDelay(float delaySamples) {
        delay_ = std::min(delaySamples, static_cast<float>(maxDelay_ - 1));
    }

    float processSample(float input) {
        // Write to buffer
        buffer_[writePos_] = input;

        // Read with linear interpolation
        float readPos = writePos_ - delay_;
        if (readPos < 0) readPos += maxDelay_;

        int idx0 = static_cast<int>(readPos);
        int idx1 = (idx0 + 1) % maxDelay_;
        float frac = readPos - idx0;

        float output = buffer_[idx0] * (1.0f - frac) + buffer_[idx1] * frac;

        writePos_ = (writePos_ + 1) % maxDelay_;
        return output;
    }

    float read(float delaySamples) const {
        float readPos = writePos_ - delaySamples;
        if (readPos < 0) readPos += maxDelay_;

        int idx0 = static_cast<int>(readPos);
        int idx1 = (idx0 + 1) % maxDelay_;
        float frac = readPos - idx0;

        return buffer_[idx0] * (1.0f - frac) + buffer_[idx1] * frac;
    }

    void write(float sample) {
        buffer_[writePos_] = sample;
        writePos_ = (writePos_ + 1) % maxDelay_;
    }

    void reset() {
        std::fill(buffer_.begin(), buffer_.end(), 0.0f);
        writePos_ = 0;
    }

private:
    std::vector<float> buffer_;
    int maxDelay_ = 0;
    int writePos_ = 0;
    float delay_ = 0.0f;
};

// ============================================================================
// MARK: - Envelope Follower
// ============================================================================

class EnvelopeFollower {
public:
    void prepare(double sampleRate) {
        sampleRate_ = sampleRate;
        updateCoefficients();
    }

    void setAttack(float attackMs) {
        attackMs_ = attackMs;
        updateCoefficients();
    }

    void setRelease(float releaseMs) {
        releaseMs_ = releaseMs;
        updateCoefficients();
    }

    float processSample(float input) {
        float inputAbs = std::abs(input);
        float coeff = (inputAbs > envelope_) ? attackCoeff_ : releaseCoeff_;
        envelope_ = coeff * (envelope_ - inputAbs) + inputAbs;
        return envelope_;
    }

    float getEnvelope() const { return envelope_; }

    void reset() { envelope_ = 0.0f; }

private:
    void updateCoefficients() {
        attackCoeff_ = std::exp(-1.0f / (attackMs_ * 0.001f * sampleRate_));
        releaseCoeff_ = std::exp(-1.0f / (releaseMs_ * 0.001f * sampleRate_));
    }

    double sampleRate_ = 44100.0;
    float attackMs_ = 10.0f;
    float releaseMs_ = 100.0f;
    float attackCoeff_ = 0.0f;
    float releaseCoeff_ = 0.0f;
    float envelope_ = 0.0f;
};

// ============================================================================
// MARK: - Oscillator (Band-Limited)
// ============================================================================

class Oscillator {
public:
    enum class Waveform { Sine, Saw, Square, Triangle };

    void prepare(double sampleRate) {
        sampleRate_ = sampleRate;
    }

    void setFrequency(float frequency) {
        phaseIncrement_ = frequency / sampleRate_;
    }

    void setWaveform(Waveform waveform) {
        waveform_ = waveform;
    }

    float processSample() {
        float output = 0.0f;

        switch (waveform_) {
            case Waveform::Sine:
                output = std::sin(phase_ * 2.0f * M_PI);
                break;

            case Waveform::Saw:
                // Band-limited using PolyBLEP
                output = 2.0f * phase_ - 1.0f;
                output -= polyBlep(phase_);
                break;

            case Waveform::Square:
                output = (phase_ < 0.5f) ? 1.0f : -1.0f;
                output += polyBlep(phase_);
                output -= polyBlep(std::fmod(phase_ + 0.5f, 1.0f));
                break;

            case Waveform::Triangle:
                output = 4.0f * std::abs(phase_ - 0.5f) - 1.0f;
                break;
        }

        phase_ += phaseIncrement_;
        if (phase_ >= 1.0f) phase_ -= 1.0f;

        return output;
    }

    void reset() { phase_ = 0.0f; }

private:
    float polyBlep(float t) const {
        float dt = phaseIncrement_;
        if (t < dt) {
            t /= dt;
            return t + t - t * t - 1.0f;
        } else if (t > 1.0f - dt) {
            t = (t - 1.0f) / dt;
            return t * t + t + t + 1.0f;
        }
        return 0.0f;
    }

    double sampleRate_ = 44100.0;
    Waveform waveform_ = Waveform::Sine;
    float phase_ = 0.0f;
    float phaseIncrement_ = 0.0f;
};

// ============================================================================
// MARK: - Parameter Smoother
// ============================================================================

class ParameterSmoother {
public:
    void prepare(double sampleRate, float smoothingTimeMs = 20.0f) {
        float samples = smoothingTimeMs * 0.001f * sampleRate;
        coeff_ = std::exp(-1.0f / samples);
    }

    void setTarget(float target) {
        target_ = target;
    }

    float getNext() {
        current_ = target_ + coeff_ * (current_ - target_);
        return current_;
    }

    float getCurrentValue() const { return current_; }

    void reset(float value) {
        current_ = target_ = value;
    }

    bool isSmoothing() const {
        return std::abs(target_ - current_) > 1e-6f;
    }

private:
    float target_ = 0.0f;
    float current_ = 0.0f;
    float coeff_ = 0.99f;
};

// ============================================================================
// MARK: - Utility Functions
// ============================================================================

/// Convert dB to linear gain
inline float dbToLinear(float db) {
    return std::pow(10.0f, db / 20.0f);
}

/// Convert linear gain to dB
inline float linearToDb(float linear) {
    return 20.0f * std::log10(std::max(linear, 1e-10f));
}

/// Convert frequency to MIDI note
inline float frequencyToMidi(float frequency) {
    return 69.0f + 12.0f * std::log2(frequency / 440.0f);
}

/// Convert MIDI note to frequency
inline float midiToFrequency(float midi) {
    return 440.0f * std::pow(2.0f, (midi - 69.0f) / 12.0f);
}

/// Soft clip with adjustable knee
inline float softClip(float x, float threshold = 0.9f) {
    if (x > threshold) {
        return threshold + (1.0f - threshold) * std::tanh((x - threshold) / (1.0f - threshold));
    } else if (x < -threshold) {
        return -threshold + (1.0f - threshold) * std::tanh((x + threshold) / (1.0f - threshold));
    }
    return x;
}

} // namespace Echoel::DSP
