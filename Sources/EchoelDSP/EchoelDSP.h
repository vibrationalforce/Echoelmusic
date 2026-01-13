// =============================================================================
// EchoelDSP - Native DSP Framework for Echoelmusic
// =============================================================================
// Copyright (c) 2024-2026 Echoelmusic. All rights reserved.
// NO JUCE. NO iPlug2. Pure native cross-platform DSP.
// =============================================================================

#pragma once

#include "../EchoelCore/EchoelCore.h"
#include <array>
#include <queue>

namespace EchoelDSP {

using namespace EchoelCore;

// =============================================================================
// Constants
// =============================================================================

constexpr int MAX_FFT_SIZE = 8192;
constexpr int DEFAULT_FFT_SIZE = 2048;

// =============================================================================
// Biquad Filter (IIR)
// =============================================================================

class BiquadFilter {
public:
    enum class Type { Lowpass, Highpass, Bandpass, Notch, Peak, LowShelf, HighShelf, Allpass };

    void setCoefficients(float b0, float b1, float b2, float a1, float a2) {
        b0_ = b0; b1_ = b1; b2_ = b2;
        a1_ = a1; a2_ = a2;
    }

    void setType(Type type, float sampleRate, float frequency, float Q, float gainDb = 0.0f) {
        float w0 = TWO_PI * frequency / sampleRate;
        float cosw0 = std::cos(w0);
        float sinw0 = std::sin(w0);
        float alpha = sinw0 / (2.0f * Q);
        float A = std::pow(10.0f, gainDb / 40.0f);

        float b0, b1, b2, a0, a1, a2;

        switch (type) {
            case Type::Lowpass:
                b0 = (1.0f - cosw0) / 2.0f;
                b1 = 1.0f - cosw0;
                b2 = b0;
                a0 = 1.0f + alpha;
                a1 = -2.0f * cosw0;
                a2 = 1.0f - alpha;
                break;

            case Type::Highpass:
                b0 = (1.0f + cosw0) / 2.0f;
                b1 = -(1.0f + cosw0);
                b2 = b0;
                a0 = 1.0f + alpha;
                a1 = -2.0f * cosw0;
                a2 = 1.0f - alpha;
                break;

            case Type::Bandpass:
                b0 = alpha;
                b1 = 0.0f;
                b2 = -alpha;
                a0 = 1.0f + alpha;
                a1 = -2.0f * cosw0;
                a2 = 1.0f - alpha;
                break;

            case Type::Notch:
                b0 = 1.0f;
                b1 = -2.0f * cosw0;
                b2 = 1.0f;
                a0 = 1.0f + alpha;
                a1 = -2.0f * cosw0;
                a2 = 1.0f - alpha;
                break;

            case Type::Peak:
                b0 = 1.0f + alpha * A;
                b1 = -2.0f * cosw0;
                b2 = 1.0f - alpha * A;
                a0 = 1.0f + alpha / A;
                a1 = -2.0f * cosw0;
                a2 = 1.0f - alpha / A;
                break;

            case Type::LowShelf: {
                float sqrtA = std::sqrt(A);
                b0 = A * ((A + 1.0f) - (A - 1.0f) * cosw0 + 2.0f * sqrtA * alpha);
                b1 = 2.0f * A * ((A - 1.0f) - (A + 1.0f) * cosw0);
                b2 = A * ((A + 1.0f) - (A - 1.0f) * cosw0 - 2.0f * sqrtA * alpha);
                a0 = (A + 1.0f) + (A - 1.0f) * cosw0 + 2.0f * sqrtA * alpha;
                a1 = -2.0f * ((A - 1.0f) + (A + 1.0f) * cosw0);
                a2 = (A + 1.0f) + (A - 1.0f) * cosw0 - 2.0f * sqrtA * alpha;
                break;
            }

            case Type::HighShelf: {
                float sqrtA = std::sqrt(A);
                b0 = A * ((A + 1.0f) + (A - 1.0f) * cosw0 + 2.0f * sqrtA * alpha);
                b1 = -2.0f * A * ((A - 1.0f) + (A + 1.0f) * cosw0);
                b2 = A * ((A + 1.0f) + (A - 1.0f) * cosw0 - 2.0f * sqrtA * alpha);
                a0 = (A + 1.0f) - (A - 1.0f) * cosw0 + 2.0f * sqrtA * alpha;
                a1 = 2.0f * ((A - 1.0f) - (A + 1.0f) * cosw0);
                a2 = (A + 1.0f) - (A - 1.0f) * cosw0 - 2.0f * sqrtA * alpha;
                break;
            }

            case Type::Allpass:
                b0 = 1.0f - alpha;
                b1 = -2.0f * cosw0;
                b2 = 1.0f + alpha;
                a0 = 1.0f + alpha;
                a1 = -2.0f * cosw0;
                a2 = 1.0f - alpha;
                break;
        }

        setCoefficients(b0/a0, b1/a0, b2/a0, a1/a0, a2/a0);
    }

    float process(float input) {
        float output = b0_ * input + b1_ * x1_ + b2_ * x2_ - a1_ * y1_ - a2_ * y2_;
        x2_ = x1_; x1_ = input;
        y2_ = y1_; y1_ = output;
        return output;
    }

    void reset() {
        x1_ = x2_ = y1_ = y2_ = 0.0f;
    }

private:
    float b0_ = 1.0f, b1_ = 0.0f, b2_ = 0.0f;
    float a1_ = 0.0f, a2_ = 0.0f;
    float x1_ = 0.0f, x2_ = 0.0f;
    float y1_ = 0.0f, y2_ = 0.0f;
};

// =============================================================================
// Parametric EQ (8 Bands)
// =============================================================================

class ParametricEQ : public AudioProcessor {
public:
    static constexpr int NUM_BANDS = 8;

    struct Band {
        bool enabled = true;
        BiquadFilter::Type type = BiquadFilter::Type::Peak;
        float frequency = 1000.0f;
        float gain = 0.0f;
        float Q = 1.0f;
    };

    void prepare(float sampleRate, int maxBlockSize) override {
        AudioProcessor::prepare(sampleRate, maxBlockSize);
        for (int i = 0; i < NUM_BANDS; ++i) {
            updateBand(i);
        }
    }

    void setBand(int index, const Band& band) {
        if (index >= 0 && index < NUM_BANDS) {
            bands_[index] = band;
            updateBand(index);
        }
    }

    void process(AudioBuffer<float>& buffer) override {
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
            float* data = buffer.getWritePointer(ch);
            for (int sample = 0; sample < buffer.getNumSamples(); ++sample) {
                float input = data[sample];
                for (int b = 0; b < NUM_BANDS; ++b) {
                    if (bands_[b].enabled) {
                        input = filters_[ch][b].process(input);
                    }
                }
                data[sample] = input;
            }
        }
    }

    void reset() override {
        for (auto& ch : filters_) {
            for (auto& f : ch) {
                f.reset();
            }
        }
    }

    const char* getName() const override { return "EchoelDSP ParametricEQ"; }

private:
    void updateBand(int index) {
        for (int ch = 0; ch < MAX_CHANNELS; ++ch) {
            filters_[ch][index].setType(
                bands_[index].type,
                sampleRate_,
                bands_[index].frequency,
                bands_[index].Q,
                bands_[index].gain
            );
        }
    }

    std::array<Band, NUM_BANDS> bands_;
    std::array<std::array<BiquadFilter, NUM_BANDS>, MAX_CHANNELS> filters_;
};

// =============================================================================
// Dynamics Processor (Compressor/Limiter/Gate)
// =============================================================================

class DynamicsProcessor : public AudioProcessor {
public:
    enum class Mode { Compressor, Limiter, Gate, Expander };

    void setMode(Mode mode) { mode_ = mode; }
    void setThreshold(float db) { threshold_ = db; }
    void setRatio(float ratio) { ratio_ = std::max(ratio, 1.0f); }
    void setAttack(float ms) { attackMs_ = ms; updateCoeffs(); }
    void setRelease(float ms) { releaseMs_ = ms; updateCoeffs(); }
    void setKnee(float db) { kneeDb_ = db; }
    void setMakeupGain(float db) { makeupGain_ = DSP::dbToLinear(db); }
    void setLookahead(float ms) { lookaheadMs_ = ms; }

    void prepare(float sampleRate, int maxBlockSize) override {
        AudioProcessor::prepare(sampleRate, maxBlockSize);
        updateCoeffs();

        int lookaheadSamples = static_cast<int>(lookaheadMs_ * 0.001f * sampleRate);
        for (auto& delay : lookaheadDelays_) {
            delay.resize(lookaheadSamples > 0 ? lookaheadSamples : 1, 0.0f);
        }
    }

    void process(AudioBuffer<float>& buffer) override {
        for (int sample = 0; sample < buffer.getNumSamples(); ++sample) {
            // Detect peak across all channels
            float peak = 0.0f;
            for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
                peak = std::max(peak, std::abs(buffer.getReadPointer(ch)[sample]));
            }

            float inputDb = DSP::linearToDb(peak);
            float gainReduction = calculateGainReduction(inputDb);

            // Smooth gain
            float targetGain = DSP::dbToLinear(gainReduction);
            float coeff = (targetGain < envelope_) ? attackCoeff_ : releaseCoeff_;
            envelope_ = envelope_ * coeff + targetGain * (1.0f - coeff);

            // Apply gain
            for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
                buffer.getWritePointer(ch)[sample] *= envelope_ * makeupGain_;
            }
        }
    }

    float getGainReduction() const { return DSP::linearToDb(envelope_); }

    const char* getName() const override { return "EchoelDSP Dynamics"; }

private:
    float calculateGainReduction(float inputDb) {
        float overThreshold = inputDb - threshold_;

        switch (mode_) {
            case Mode::Compressor:
            case Mode::Limiter: {
                if (overThreshold <= -kneeDb_ / 2.0f) return 0.0f;
                if (overThreshold >= kneeDb_ / 2.0f) {
                    return -overThreshold * (1.0f - 1.0f / ratio_);
                }
                // Soft knee
                float knee = overThreshold + kneeDb_ / 2.0f;
                return -knee * knee / (2.0f * kneeDb_) * (1.0f - 1.0f / ratio_);
            }

            case Mode::Gate:
                return (inputDb < threshold_) ? -80.0f : 0.0f;

            case Mode::Expander:
                if (inputDb < threshold_) {
                    return (threshold_ - inputDb) * (ratio_ - 1.0f);
                }
                return 0.0f;
        }
        return 0.0f;
    }

    void updateCoeffs() {
        attackCoeff_ = std::exp(-1.0f / (attackMs_ * 0.001f * sampleRate_));
        releaseCoeff_ = std::exp(-1.0f / (releaseMs_ * 0.001f * sampleRate_));
    }

    Mode mode_ = Mode::Compressor;
    float threshold_ = -20.0f;
    float ratio_ = 4.0f;
    float attackMs_ = 10.0f;
    float releaseMs_ = 100.0f;
    float kneeDb_ = 6.0f;
    float makeupGain_ = 1.0f;
    float lookaheadMs_ = 0.0f;

    float attackCoeff_ = 0.0f;
    float releaseCoeff_ = 0.0f;
    float envelope_ = 1.0f;

    std::array<std::vector<float>, MAX_CHANNELS> lookaheadDelays_;
};

// =============================================================================
// Saturation / Distortion
// =============================================================================

class Saturation : public AudioProcessor {
public:
    enum class Type { Soft, Hard, Tube, Tape, Bitcrush };

    void setType(Type type) { type_ = type; }
    void setDrive(float db) { drive_ = DSP::dbToLinear(db); }
    void setMix(float mix) { mix_ = DSP::clamp(mix, 0.0f, 1.0f); }
    void setBitDepth(int bits) { bitDepth_ = DSP::clamp(bits, 1, 24); }

    void process(AudioBuffer<float>& buffer) override {
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
            float* data = buffer.getWritePointer(ch);
            for (int sample = 0; sample < buffer.getNumSamples(); ++sample) {
                float dry = data[sample];
                float wet = saturate(dry * drive_);
                data[sample] = dry * (1.0f - mix_) + wet * mix_;
            }
        }
    }

    const char* getName() const override { return "EchoelDSP Saturation"; }

private:
    float saturate(float input) {
        switch (type_) {
            case Type::Soft:
                return DSP::fastTanh(input);

            case Type::Hard:
                return DSP::clamp(input, -1.0f, 1.0f);

            case Type::Tube: {
                // Asymmetric tube-style saturation
                if (input >= 0.0f) {
                    return 1.0f - std::exp(-input);
                } else {
                    return -1.0f + std::exp(input);
                }
            }

            case Type::Tape: {
                // Tape-style soft saturation with hysteresis
                float x = input * 0.9f;
                return x / (1.0f + std::abs(x)) * 1.1f;
            }

            case Type::Bitcrush: {
                float levels = std::pow(2.0f, static_cast<float>(bitDepth_));
                return std::round(input * levels) / levels;
            }
        }
        return input;
    }

    Type type_ = Type::Soft;
    float drive_ = 1.0f;
    float mix_ = 1.0f;
    int bitDepth_ = 8;
};

// =============================================================================
// Chorus
// =============================================================================

class Chorus : public AudioProcessor {
public:
    void setRate(float hz) { rate_ = hz; }
    void setDepth(float ms) { depth_ = ms; }
    void setMix(float mix) { mix_ = DSP::clamp(mix, 0.0f, 1.0f); }
    void setFeedback(float fb) { feedback_ = DSP::clamp(fb, -0.95f, 0.95f); }

    void prepare(float sampleRate, int maxBlockSize) override {
        AudioProcessor::prepare(sampleRate, maxBlockSize);
        int maxDelaySamples = static_cast<int>(0.05f * sampleRate); // 50ms max
        for (auto& delay : delayLines_) {
            delay = std::make_unique<DelayLine>(maxDelaySamples);
        }
        phase_ = 0.0f;
    }

    void process(AudioBuffer<float>& buffer) override {
        float phaseInc = rate_ / sampleRate_;

        for (int sample = 0; sample < buffer.getNumSamples(); ++sample) {
            float lfo = (std::sin(phase_ * TWO_PI) + 1.0f) * 0.5f;
            float delaySamples = (5.0f + depth_ * lfo) * sampleRate_ * 0.001f;

            for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
                float* data = buffer.getWritePointer(ch);
                float dry = data[ch];

                delayLines_[ch]->setDelay(delaySamples);
                float wet = delayLines_[ch]->process(dry + lastOutput_[ch] * feedback_);
                lastOutput_[ch] = wet;

                data[sample] = dry * (1.0f - mix_) + wet * mix_;
            }

            phase_ += phaseInc;
            if (phase_ >= 1.0f) phase_ -= 1.0f;
        }
    }

    const char* getName() const override { return "EchoelDSP Chorus"; }

private:
    float rate_ = 0.5f;
    float depth_ = 3.0f;
    float mix_ = 0.5f;
    float feedback_ = 0.0f;
    float phase_ = 0.0f;

    std::array<std::unique_ptr<DelayLine>, MAX_CHANNELS> delayLines_;
    std::array<float, MAX_CHANNELS> lastOutput_ = {};
};

// =============================================================================
// Phaser
// =============================================================================

class Phaser : public AudioProcessor {
public:
    static constexpr int NUM_STAGES = 6;

    void setRate(float hz) { rate_ = hz; }
    void setDepth(float d) { depth_ = DSP::clamp(d, 0.0f, 1.0f); }
    void setFeedback(float fb) { feedback_ = DSP::clamp(fb, -0.95f, 0.95f); }
    void setMix(float mix) { mix_ = DSP::clamp(mix, 0.0f, 1.0f); }

    void prepare(float sampleRate, int maxBlockSize) override {
        AudioProcessor::prepare(sampleRate, maxBlockSize);
        for (auto& ch : allpassStates_) {
            ch.fill(0.0f);
        }
    }

    void process(AudioBuffer<float>& buffer) override {
        float phaseInc = rate_ / sampleRate_;

        for (int sample = 0; sample < buffer.getNumSamples(); ++sample) {
            float lfo = std::sin(phase_ * TWO_PI);
            float minFreq = 200.0f;
            float maxFreq = 4000.0f;
            float freq = minFreq + (maxFreq - minFreq) * (lfo * depth_ + 1.0f) * 0.5f;

            float coeff = (std::tan(PI * freq / sampleRate_) - 1.0f) /
                         (std::tan(PI * freq / sampleRate_) + 1.0f);

            for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
                float* data = buffer.getWritePointer(ch);
                float input = data[sample] + lastOutput_[ch] * feedback_;
                float output = input;

                for (int stage = 0; stage < NUM_STAGES; ++stage) {
                    float temp = allpassStates_[ch][stage];
                    allpassStates_[ch][stage] = output;
                    output = temp + coeff * (output - temp);
                }

                lastOutput_[ch] = output;
                data[sample] = data[sample] * (1.0f - mix_) + output * mix_;
            }

            phase_ += phaseInc;
            if (phase_ >= 1.0f) phase_ -= 1.0f;
        }
    }

    const char* getName() const override { return "EchoelDSP Phaser"; }

private:
    float rate_ = 0.3f;
    float depth_ = 0.7f;
    float feedback_ = 0.5f;
    float mix_ = 0.5f;
    float phase_ = 0.0f;

    std::array<std::array<float, NUM_STAGES>, MAX_CHANNELS> allpassStates_;
    std::array<float, MAX_CHANNELS> lastOutput_ = {};
};

// =============================================================================
// Stereo Widener
// =============================================================================

class StereoWidener : public AudioProcessor {
public:
    void setWidth(float width) { width_ = DSP::clamp(width, 0.0f, 2.0f); }
    void setMidGain(float db) { midGain_ = DSP::dbToLinear(db); }
    void setSideGain(float db) { sideGain_ = DSP::dbToLinear(db); }

    void process(AudioBuffer<float>& buffer) override {
        if (buffer.getNumChannels() < 2) return;

        float* left = buffer.getWritePointer(0);
        float* right = buffer.getWritePointer(1);

        for (int sample = 0; sample < buffer.getNumSamples(); ++sample) {
            float mid = (left[sample] + right[sample]) * 0.5f * midGain_;
            float side = (left[sample] - right[sample]) * 0.5f * sideGain_ * width_;

            left[sample] = mid + side;
            right[sample] = mid - side;
        }
    }

    const char* getName() const override { return "EchoelDSP StereoWidener"; }

private:
    float width_ = 1.0f;
    float midGain_ = 1.0f;
    float sideGain_ = 1.0f;
};

// =============================================================================
// Convolution Reverb (Simple FFT-based)
// =============================================================================

class ConvolutionReverb : public AudioProcessor {
public:
    void loadImpulse(const std::vector<float>& impulse) {
        impulseResponse_ = impulse;
        // In production, this would use FFT partitioning
    }

    void setWetDry(float wet) { wetLevel_ = DSP::clamp(wet, 0.0f, 1.0f); }

    void process(AudioBuffer<float>& buffer) override {
        if (impulseResponse_.empty()) return;

        // Simple time-domain convolution (for short IRs only)
        // Production would use FFT overlap-add
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
            float* data = buffer.getWritePointer(ch);

            for (int sample = 0; sample < buffer.getNumSamples(); ++sample) {
                // Push sample into history
                inputHistory_[ch].push_back(data[sample]);
                if (inputHistory_[ch].size() > impulseResponse_.size()) {
                    inputHistory_[ch].erase(inputHistory_[ch].begin());
                }

                // Convolve
                float wet = 0.0f;
                for (size_t i = 0; i < inputHistory_[ch].size() && i < impulseResponse_.size(); ++i) {
                    wet += inputHistory_[ch][inputHistory_[ch].size() - 1 - i] * impulseResponse_[i];
                }

                data[sample] = data[sample] * (1.0f - wetLevel_) + wet * wetLevel_;
            }
        }
    }

    const char* getName() const override { return "EchoelDSP ConvolutionReverb"; }

private:
    std::vector<float> impulseResponse_;
    std::array<std::vector<float>, MAX_CHANNELS> inputHistory_;
    float wetLevel_ = 0.3f;
};

// =============================================================================
// Limiter (Lookahead Brickwall)
// =============================================================================

class BrickwallLimiter : public AudioProcessor {
public:
    void setCeiling(float db) { ceiling_ = DSP::dbToLinear(db); }
    void setRelease(float ms) { releaseMs_ = ms; updateCoeffs(); }
    void setLookahead(float ms) { lookaheadMs_ = ms; }

    void prepare(float sampleRate, int maxBlockSize) override {
        AudioProcessor::prepare(sampleRate, maxBlockSize);
        updateCoeffs();

        int lookaheadSamples = static_cast<int>(lookaheadMs_ * 0.001f * sampleRate);
        for (auto& delay : lookaheadDelays_) {
            delay = std::make_unique<DelayLine>(lookaheadSamples + 1);
            delay->setDelay(static_cast<float>(lookaheadSamples));
        }
    }

    void process(AudioBuffer<float>& buffer) override {
        for (int sample = 0; sample < buffer.getNumSamples(); ++sample) {
            // Find peak across all channels
            float peak = 0.0f;
            for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
                peak = std::max(peak, std::abs(buffer.getReadPointer(ch)[sample]));
            }

            // Calculate gain reduction
            float targetGain = (peak > ceiling_) ? ceiling_ / peak : 1.0f;

            // Smooth release (instant attack)
            if (targetGain < envelope_) {
                envelope_ = targetGain;
            } else {
                envelope_ = envelope_ * releaseCoeff_ + targetGain * (1.0f - releaseCoeff_);
            }

            // Apply to delayed signal
            for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
                float* data = buffer.getWritePointer(ch);
                float delayed = lookaheadDelays_[ch]->process(data[sample]);
                data[sample] = delayed * envelope_;
            }
        }
    }

    const char* getName() const override { return "EchoelDSP BrickwallLimiter"; }

private:
    void updateCoeffs() {
        releaseCoeff_ = std::exp(-1.0f / (releaseMs_ * 0.001f * sampleRate_));
    }

    float ceiling_ = 1.0f;
    float releaseMs_ = 100.0f;
    float lookaheadMs_ = 5.0f;
    float releaseCoeff_ = 0.0f;
    float envelope_ = 1.0f;

    std::array<std::unique_ptr<DelayLine>, MAX_CHANNELS> lookaheadDelays_;
};

// =============================================================================
// De-Esser
// =============================================================================

class DeEsser : public AudioProcessor {
public:
    void setThreshold(float db) { threshold_ = db; }
    void setFrequency(float hz) { frequency_ = hz; }
    void setRange(float db) { range_ = db; }

    void prepare(float sampleRate, int maxBlockSize) override {
        AudioProcessor::prepare(sampleRate, maxBlockSize);
        for (auto& f : sideFilters_) {
            f.setType(BiquadFilter::Type::Bandpass, sampleRate, frequency_, 2.0f);
        }
        for (auto& f : cutFilters_) {
            f.setType(BiquadFilter::Type::Peak, sampleRate, frequency_, 2.0f, -range_);
        }
    }

    void process(AudioBuffer<float>& buffer) override {
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
            float* data = buffer.getWritePointer(ch);
            for (int sample = 0; sample < buffer.getNumSamples(); ++sample) {
                // Detect sibilance
                float sidechain = sideFilters_[ch].process(data[sample]);
                float sibilanceDb = DSP::linearToDb(std::abs(sidechain));

                if (sibilanceDb > threshold_) {
                    // Apply reduction
                    data[sample] = cutFilters_[ch].process(data[sample]);
                }
            }
        }
    }

    const char* getName() const override { return "EchoelDSP DeEsser"; }

private:
    float threshold_ = -20.0f;
    float frequency_ = 6000.0f;
    float range_ = 10.0f;

    std::array<BiquadFilter, MAX_CHANNELS> sideFilters_;
    std::array<BiquadFilter, MAX_CHANNELS> cutFilters_;
};

// =============================================================================
// Version Info
// =============================================================================

struct Version {
    static constexpr int major = 1;
    static constexpr int minor = 0;
    static constexpr int patch = 0;

    static const char* getString() { return "1.0.0"; }
    static const char* getFrameworkName() { return "EchoelDSP"; }
};

} // namespace EchoelDSP
