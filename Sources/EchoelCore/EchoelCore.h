// =============================================================================
// EchoelCore - Native Audio Framework for Echoelmusic
// =============================================================================
// Copyright (c) 2024-2026 Echoelmusic. All rights reserved.
// NO JUCE. NO iPlug2. Pure native cross-platform audio.
// =============================================================================

#pragma once

#include <cstdint>
#include <cmath>
#include <vector>
#include <memory>
#include <functional>
#include <atomic>
#include <string>

// Platform detection
#if defined(__APPLE__)
    #include <TargetConditionals.h>
    #if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
        #define ECHOELCORE_IOS 1
    #elif TARGET_OS_MAC
        #define ECHOELCORE_MACOS 1
    #endif
    #define ECHOELCORE_APPLE 1
#elif defined(_WIN32) || defined(_WIN64)
    #define ECHOELCORE_WINDOWS 1
#elif defined(__linux__)
    #define ECHOELCORE_LINUX 1
#elif defined(__ANDROID__)
    #define ECHOELCORE_ANDROID 1
#endif

namespace EchoelCore {

// =============================================================================
// Constants
// =============================================================================

constexpr float PI = 3.14159265358979323846f;
constexpr float TWO_PI = 6.28318530717958647692f;
constexpr float HALF_PI = 1.57079632679489661923f;

constexpr int DEFAULT_SAMPLE_RATE = 48000;
constexpr int DEFAULT_BUFFER_SIZE = 256;
constexpr int MAX_CHANNELS = 64;
constexpr int MAX_VOICES = 128;

// =============================================================================
// Audio Buffer
// =============================================================================

template<typename SampleType = float>
class AudioBuffer {
public:
    AudioBuffer(int numChannels = 2, int numSamples = DEFAULT_BUFFER_SIZE)
        : channels_(numChannels), samples_(numSamples) {
        data_.resize(channels_ * samples_, SampleType(0));
    }

    void setSize(int numChannels, int numSamples) {
        channels_ = numChannels;
        samples_ = numSamples;
        data_.resize(channels_ * samples_, SampleType(0));
    }

    void clear() {
        std::fill(data_.begin(), data_.end(), SampleType(0));
    }

    SampleType* getWritePointer(int channel) {
        return data_.data() + channel * samples_;
    }

    const SampleType* getReadPointer(int channel) const {
        return data_.data() + channel * samples_;
    }

    int getNumChannels() const { return channels_; }
    int getNumSamples() const { return samples_; }

    void copyFrom(int destChannel, int destStartSample,
                  const AudioBuffer& source, int sourceChannel, int sourceStartSample,
                  int numSamples) {
        auto* dest = getWritePointer(destChannel) + destStartSample;
        auto* src = source.getReadPointer(sourceChannel) + sourceStartSample;
        std::copy(src, src + numSamples, dest);
    }

    void addFrom(int destChannel, int destStartSample,
                 const AudioBuffer& source, int sourceChannel, int sourceStartSample,
                 int numSamples, float gain = 1.0f) {
        auto* dest = getWritePointer(destChannel) + destStartSample;
        auto* src = source.getReadPointer(sourceChannel) + sourceStartSample;
        for (int i = 0; i < numSamples; ++i) {
            dest[i] += src[i] * gain;
        }
    }

    void applyGain(float gain) {
        for (auto& sample : data_) {
            sample *= gain;
        }
    }

private:
    int channels_;
    int samples_;
    std::vector<SampleType> data_;
};

// =============================================================================
// DSP Math Utilities
// =============================================================================

namespace DSP {

inline float fastSin(float x) {
    // Bhaskara I's sine approximation (fast, accurate enough for audio)
    x = fmodf(x, TWO_PI);
    if (x < 0) x += TWO_PI;
    if (x > PI) {
        x -= PI;
        return -16.0f * x * (PI - x) / (5.0f * PI * PI - 4.0f * x * (PI - x));
    }
    return 16.0f * x * (PI - x) / (5.0f * PI * PI - 4.0f * x * (PI - x));
}

inline float fastCos(float x) {
    return fastSin(x + HALF_PI);
}

inline float fastTanh(float x) {
    // Pade approximation
    if (x < -3.0f) return -1.0f;
    if (x > 3.0f) return 1.0f;
    float x2 = x * x;
    return x * (27.0f + x2) / (27.0f + 9.0f * x2);
}

inline float dbToLinear(float db) {
    return std::pow(10.0f, db / 20.0f);
}

inline float linearToDb(float linear) {
    return 20.0f * std::log10(std::max(linear, 1e-10f));
}

inline float midiToFrequency(int midiNote) {
    return 440.0f * std::pow(2.0f, (midiNote - 69) / 12.0f);
}

inline int frequencyToMidi(float frequency) {
    return static_cast<int>(std::round(69.0f + 12.0f * std::log2(frequency / 440.0f)));
}

inline float lerp(float a, float b, float t) {
    return a + t * (b - a);
}

inline float clamp(float value, float min, float max) {
    return std::min(std::max(value, min), max);
}

} // namespace DSP

// =============================================================================
// Envelope Generator (ADSR)
// =============================================================================

class EnvelopeGenerator {
public:
    enum class State { Idle, Attack, Decay, Sustain, Release };

    EnvelopeGenerator() = default;

    void setParameters(float attackMs, float decayMs, float sustain, float releaseMs, float sampleRate) {
        sampleRate_ = sampleRate;
        attackRate_ = 1.0f / (attackMs * 0.001f * sampleRate);
        decayRate_ = 1.0f / (decayMs * 0.001f * sampleRate);
        sustainLevel_ = sustain;
        releaseRate_ = 1.0f / (releaseMs * 0.001f * sampleRate);
    }

    void noteOn() {
        state_ = State::Attack;
        currentLevel_ = 0.0f;
    }

    void noteOff() {
        state_ = State::Release;
    }

    float process() {
        switch (state_) {
            case State::Idle:
                return 0.0f;

            case State::Attack:
                currentLevel_ += attackRate_;
                if (currentLevel_ >= 1.0f) {
                    currentLevel_ = 1.0f;
                    state_ = State::Decay;
                }
                break;

            case State::Decay:
                currentLevel_ -= decayRate_;
                if (currentLevel_ <= sustainLevel_) {
                    currentLevel_ = sustainLevel_;
                    state_ = State::Sustain;
                }
                break;

            case State::Sustain:
                break;

            case State::Release:
                currentLevel_ -= releaseRate_;
                if (currentLevel_ <= 0.0f) {
                    currentLevel_ = 0.0f;
                    state_ = State::Idle;
                }
                break;
        }
        return currentLevel_;
    }

    bool isActive() const { return state_ != State::Idle; }
    State getState() const { return state_; }

private:
    State state_ = State::Idle;
    float sampleRate_ = DEFAULT_SAMPLE_RATE;
    float currentLevel_ = 0.0f;
    float attackRate_ = 0.01f;
    float decayRate_ = 0.001f;
    float sustainLevel_ = 0.7f;
    float releaseRate_ = 0.001f;
};

// =============================================================================
// Oscillator
// =============================================================================

class Oscillator {
public:
    enum class Waveform { Sine, Saw, Square, Triangle, Noise };

    Oscillator(float sampleRate = DEFAULT_SAMPLE_RATE)
        : sampleRate_(sampleRate) {}

    void setFrequency(float freq) {
        frequency_ = freq;
        phaseIncrement_ = frequency_ / sampleRate_;
    }

    void setWaveform(Waveform wf) { waveform_ = wf; }
    void setSampleRate(float sr) { sampleRate_ = sr; }

    float process() {
        float sample = 0.0f;

        switch (waveform_) {
            case Waveform::Sine:
                sample = DSP::fastSin(phase_ * TWO_PI);
                break;

            case Waveform::Saw:
                sample = 2.0f * phase_ - 1.0f;
                break;

            case Waveform::Square:
                sample = phase_ < 0.5f ? 1.0f : -1.0f;
                break;

            case Waveform::Triangle:
                sample = 4.0f * std::abs(phase_ - 0.5f) - 1.0f;
                break;

            case Waveform::Noise:
                sample = (static_cast<float>(rand()) / RAND_MAX) * 2.0f - 1.0f;
                break;
        }

        phase_ += phaseIncrement_;
        if (phase_ >= 1.0f) phase_ -= 1.0f;

        return sample;
    }

    void reset() { phase_ = 0.0f; }

private:
    Waveform waveform_ = Waveform::Sine;
    float sampleRate_;
    float frequency_ = 440.0f;
    float phase_ = 0.0f;
    float phaseIncrement_ = 0.0f;
};

// =============================================================================
// Filter (State Variable Filter)
// =============================================================================

class StateVariableFilter {
public:
    enum class Mode { Lowpass, Highpass, Bandpass, Notch };

    StateVariableFilter(float sampleRate = DEFAULT_SAMPLE_RATE)
        : sampleRate_(sampleRate) {}

    void setParameters(float cutoff, float resonance) {
        cutoff_ = DSP::clamp(cutoff, 20.0f, sampleRate_ * 0.49f);
        resonance_ = DSP::clamp(resonance, 0.0f, 1.0f);

        // Calculate coefficients
        g_ = std::tan(PI * cutoff_ / sampleRate_);
        k_ = 2.0f - 2.0f * resonance_;
        a1_ = 1.0f / (1.0f + g_ * (g_ + k_));
        a2_ = g_ * a1_;
        a3_ = g_ * a2_;
    }

    void setMode(Mode mode) { mode_ = mode; }
    void setSampleRate(float sr) { sampleRate_ = sr; }

    float process(float input) {
        float v3 = input - ic2eq_;
        float v1 = a1_ * ic1eq_ + a2_ * v3;
        float v2 = ic2eq_ + a2_ * ic1eq_ + a3_ * v3;

        ic1eq_ = 2.0f * v1 - ic1eq_;
        ic2eq_ = 2.0f * v2 - ic2eq_;

        switch (mode_) {
            case Mode::Lowpass:  return v2;
            case Mode::Highpass: return input - k_ * v1 - v2;
            case Mode::Bandpass: return v1;
            case Mode::Notch:    return input - k_ * v1;
        }
        return v2;
    }

    void reset() {
        ic1eq_ = 0.0f;
        ic2eq_ = 0.0f;
    }

private:
    Mode mode_ = Mode::Lowpass;
    float sampleRate_;
    float cutoff_ = 1000.0f;
    float resonance_ = 0.5f;
    float g_ = 0.0f, k_ = 0.0f;
    float a1_ = 0.0f, a2_ = 0.0f, a3_ = 0.0f;
    float ic1eq_ = 0.0f, ic2eq_ = 0.0f;
};

// =============================================================================
// Delay Line
// =============================================================================

class DelayLine {
public:
    DelayLine(int maxDelayInSamples = 48000)
        : buffer_(maxDelayInSamples, 0.0f), maxDelay_(maxDelayInSamples) {}

    void setDelay(float delaySamples) {
        delayTime_ = DSP::clamp(delaySamples, 0.0f, static_cast<float>(maxDelay_ - 1));
    }

    float process(float input) {
        // Write to buffer
        buffer_[writeIndex_] = input;

        // Calculate read position with linear interpolation
        float readPos = static_cast<float>(writeIndex_) - delayTime_;
        if (readPos < 0.0f) readPos += maxDelay_;

        int readIndex = static_cast<int>(readPos);
        float frac = readPos - readIndex;

        int nextIndex = (readIndex + 1) % maxDelay_;
        float output = DSP::lerp(buffer_[readIndex], buffer_[nextIndex], frac);

        // Advance write position
        writeIndex_ = (writeIndex_ + 1) % maxDelay_;

        return output;
    }

    void clear() {
        std::fill(buffer_.begin(), buffer_.end(), 0.0f);
    }

private:
    std::vector<float> buffer_;
    int maxDelay_;
    int writeIndex_ = 0;
    float delayTime_ = 0.0f;
};

// =============================================================================
// Reverb (Simple Schroeder)
// =============================================================================

class SchroederReverb {
public:
    SchroederReverb(float sampleRate = DEFAULT_SAMPLE_RATE) : sampleRate_(sampleRate) {
        // Initialize comb filters with prime-length delays
        for (int i = 0; i < 4; ++i) {
            combDelays_[i] = std::make_unique<DelayLine>(static_cast<int>(sampleRate * 0.1f));
            combFilters_[i] = 0.0f;
        }
        // Initialize allpass filters
        for (int i = 0; i < 2; ++i) {
            allpassDelays_[i] = std::make_unique<DelayLine>(static_cast<int>(sampleRate * 0.05f));
        }
        setRoomSize(0.5f);
        setDamping(0.5f);
    }

    void setRoomSize(float size) {
        roomSize_ = DSP::clamp(size, 0.0f, 1.0f);
        updateParameters();
    }

    void setDamping(float damp) {
        damping_ = DSP::clamp(damp, 0.0f, 1.0f);
    }

    void setWetDry(float wet) {
        wetLevel_ = DSP::clamp(wet, 0.0f, 1.0f);
    }

    float process(float input) {
        // Parallel comb filters
        float combSum = 0.0f;
        for (int i = 0; i < 4; ++i) {
            float delayed = combDelays_[i]->process(input + combFilters_[i] * combFeedback_);
            combFilters_[i] = delayed * (1.0f - damping_) + combFilters_[i] * damping_;
            combSum += combFilters_[i];
        }
        combSum *= 0.25f;

        // Series allpass filters
        float allpassOut = combSum;
        for (int i = 0; i < 2; ++i) {
            float delayed = allpassDelays_[i]->process(allpassOut);
            allpassOut = delayed - allpassCoeff_ * allpassOut + allpassCoeff_ * delayed;
        }

        // Mix wet/dry
        return input * (1.0f - wetLevel_) + allpassOut * wetLevel_;
    }

private:
    void updateParameters() {
        static const float combTimes[4] = { 0.0297f, 0.0371f, 0.0411f, 0.0437f };
        static const float allpassTimes[2] = { 0.09683f, 0.032954f };

        float sizeScale = 0.5f + roomSize_ * 1.5f;

        for (int i = 0; i < 4; ++i) {
            combDelays_[i]->setDelay(combTimes[i] * sizeScale * sampleRate_);
        }
        for (int i = 0; i < 2; ++i) {
            allpassDelays_[i]->setDelay(allpassTimes[i] * sizeScale * sampleRate_);
        }
        combFeedback_ = 0.8f + roomSize_ * 0.15f;
    }

    float sampleRate_;
    float roomSize_ = 0.5f;
    float damping_ = 0.5f;
    float wetLevel_ = 0.3f;
    float combFeedback_ = 0.84f;
    float allpassCoeff_ = 0.5f;

    std::unique_ptr<DelayLine> combDelays_[4];
    std::unique_ptr<DelayLine> allpassDelays_[2];
    float combFilters_[4] = {0.0f};
};

// =============================================================================
// Compressor
// =============================================================================

class Compressor {
public:
    Compressor(float sampleRate = DEFAULT_SAMPLE_RATE) : sampleRate_(sampleRate) {
        updateCoefficients();
    }

    void setThreshold(float thresholdDb) { threshold_ = thresholdDb; }
    void setRatio(float ratio) { ratio_ = std::max(ratio, 1.0f); }
    void setAttack(float attackMs) { attackMs_ = attackMs; updateCoefficients(); }
    void setRelease(float releaseMs) { releaseMs_ = releaseMs; updateCoefficients(); }
    void setMakeupGain(float gainDb) { makeupGain_ = DSP::dbToLinear(gainDb); }

    float process(float input) {
        float inputDb = DSP::linearToDb(std::abs(input));

        // Calculate gain reduction
        float overThreshold = inputDb - threshold_;
        float gainReductionDb = 0.0f;
        if (overThreshold > 0.0f) {
            gainReductionDb = overThreshold * (1.0f - 1.0f / ratio_);
        }

        // Smooth gain with attack/release
        float targetGain = DSP::dbToLinear(-gainReductionDb);
        float coeff = (targetGain < envelope_) ? attackCoeff_ : releaseCoeff_;
        envelope_ = envelope_ * coeff + targetGain * (1.0f - coeff);

        return input * envelope_ * makeupGain_;
    }

private:
    void updateCoefficients() {
        attackCoeff_ = std::exp(-1.0f / (attackMs_ * 0.001f * sampleRate_));
        releaseCoeff_ = std::exp(-1.0f / (releaseMs_ * 0.001f * sampleRate_));
    }

    float sampleRate_;
    float threshold_ = -20.0f;
    float ratio_ = 4.0f;
    float attackMs_ = 10.0f;
    float releaseMs_ = 100.0f;
    float makeupGain_ = 1.0f;
    float attackCoeff_ = 0.0f;
    float releaseCoeff_ = 0.0f;
    float envelope_ = 1.0f;
};

// =============================================================================
// Bio-Reactive Modulator (HRV/Coherence -> Audio Parameters)
// =============================================================================

class BioReactiveModulator {
public:
    struct BioData {
        float heartRate = 70.0f;        // BPM
        float hrv = 50.0f;              // SDNN in ms
        float coherence = 0.5f;         // 0-1
        float breathingRate = 6.0f;     // breaths per minute
        float breathPhase = 0.0f;       // 0-1 (inhale to exhale)
    };

    struct ModulationTarget {
        float filterCutoff = 0.0f;      // -1 to 1 modulation
        float reverbWet = 0.0f;
        float tempo = 0.0f;
        float volume = 0.0f;
        float spatialWidth = 0.0f;
        float grainDensity = 0.0f;
    };

    void updateBioData(const BioData& data) {
        bioData_ = data;
        calculateModulation();
    }

    ModulationTarget getModulation() const { return modulation_; }

    // Modulation mapping configuration
    void setCoherenceToFilter(float amount) { coherenceToFilter_ = amount; }
    void setHrvToReverb(float amount) { hrvToReverb_ = amount; }
    void setHeartRateToTempo(float amount) { heartRateToTempo_ = amount; }
    void setBreathToVolume(float amount) { breathToVolume_ = amount; }

private:
    void calculateModulation() {
        // Coherence -> Filter (high coherence = brighter sound)
        modulation_.filterCutoff = (bioData_.coherence - 0.5f) * 2.0f * coherenceToFilter_;

        // HRV -> Reverb (high HRV = more space)
        float hrvNormalized = DSP::clamp((bioData_.hrv - 20.0f) / 80.0f, 0.0f, 1.0f);
        modulation_.reverbWet = hrvNormalized * hrvToReverb_;

        // Heart rate -> Tempo
        float hrNormalized = (bioData_.heartRate - 60.0f) / 60.0f;
        modulation_.tempo = hrNormalized * heartRateToTempo_;

        // Breathing phase -> Volume swell
        float breathSwell = std::sin(bioData_.breathPhase * TWO_PI);
        modulation_.volume = breathSwell * 0.1f * breathToVolume_;

        // Coherence -> Spatial width
        modulation_.spatialWidth = bioData_.coherence;

        // HRV variability -> Grain density
        modulation_.grainDensity = hrvNormalized;
    }

    BioData bioData_;
    ModulationTarget modulation_;

    float coherenceToFilter_ = 1.0f;
    float hrvToReverb_ = 1.0f;
    float heartRateToTempo_ = 0.5f;
    float breathToVolume_ = 1.0f;
};

// =============================================================================
// Audio Processor Base Class
// =============================================================================

class AudioProcessor {
public:
    virtual ~AudioProcessor() = default;

    virtual void prepare(float sampleRate, int maxBlockSize) {
        sampleRate_ = sampleRate;
        maxBlockSize_ = maxBlockSize;
    }

    virtual void process(AudioBuffer<float>& buffer) = 0;
    virtual void reset() {}

    virtual const char* getName() const = 0;

protected:
    float sampleRate_ = DEFAULT_SAMPLE_RATE;
    int maxBlockSize_ = DEFAULT_BUFFER_SIZE;
};

// =============================================================================
// Synth Voice
// =============================================================================

class SynthVoice {
public:
    SynthVoice() = default;

    void prepare(float sampleRate) {
        sampleRate_ = sampleRate;
        oscillator_.setSampleRate(sampleRate);
        filter_.setSampleRate(sampleRate);
        envelope_.setParameters(10.0f, 100.0f, 0.7f, 200.0f, sampleRate);
    }

    void noteOn(int midiNote, float velocity) {
        midiNote_ = midiNote;
        velocity_ = velocity;
        oscillator_.setFrequency(DSP::midiToFrequency(midiNote));
        envelope_.noteOn();
        active_ = true;
    }

    void noteOff() {
        envelope_.noteOff();
    }

    float process() {
        if (!active_) return 0.0f;

        float env = envelope_.process();
        if (!envelope_.isActive()) {
            active_ = false;
            return 0.0f;
        }

        float osc = oscillator_.process();
        float filtered = filter_.process(osc);
        return filtered * env * velocity_;
    }

    bool isActive() const { return active_; }
    int getMidiNote() const { return midiNote_; }

    void setWaveform(Oscillator::Waveform wf) { oscillator_.setWaveform(wf); }
    void setFilterCutoff(float cutoff) { filter_.setParameters(cutoff, filterResonance_); }
    void setFilterResonance(float res) { filterResonance_ = res; filter_.setParameters(filterCutoff_, res); }

private:
    float sampleRate_ = DEFAULT_SAMPLE_RATE;
    Oscillator oscillator_;
    StateVariableFilter filter_;
    EnvelopeGenerator envelope_;
    int midiNote_ = 60;
    float velocity_ = 1.0f;
    float filterCutoff_ = 5000.0f;
    float filterResonance_ = 0.3f;
    bool active_ = false;
};

// =============================================================================
// Polyphonic Synthesizer
// =============================================================================

class PolySynth : public AudioProcessor {
public:
    PolySynth(int numVoices = 16) : numVoices_(numVoices) {
        voices_.resize(numVoices);
    }

    void prepare(float sampleRate, int maxBlockSize) override {
        AudioProcessor::prepare(sampleRate, maxBlockSize);
        for (auto& voice : voices_) {
            voice.prepare(sampleRate);
        }
    }

    void process(AudioBuffer<float>& buffer) override {
        buffer.clear();

        for (int sample = 0; sample < buffer.getNumSamples(); ++sample) {
            float mixedSample = 0.0f;
            for (auto& voice : voices_) {
                if (voice.isActive()) {
                    mixedSample += voice.process();
                }
            }
            mixedSample *= 0.5f; // Master volume

            for (int channel = 0; channel < buffer.getNumChannels(); ++channel) {
                buffer.getWritePointer(channel)[sample] = mixedSample;
            }
        }
    }

    void noteOn(int midiNote, float velocity) {
        // Find free voice or steal oldest
        for (auto& voice : voices_) {
            if (!voice.isActive()) {
                voice.noteOn(midiNote, velocity);
                return;
            }
        }
        // Voice stealing: use first voice
        voices_[0].noteOn(midiNote, velocity);
    }

    void noteOff(int midiNote) {
        for (auto& voice : voices_) {
            if (voice.isActive() && voice.getMidiNote() == midiNote) {
                voice.noteOff();
            }
        }
    }

    void setWaveform(Oscillator::Waveform wf) {
        for (auto& voice : voices_) {
            voice.setWaveform(wf);
        }
    }

    void reset() override {
        for (auto& voice : voices_) {
            voice.noteOff();
        }
    }

    const char* getName() const override { return "EchoelCore PolySynth"; }

private:
    int numVoices_;
    std::vector<SynthVoice> voices_;
};

// =============================================================================
// Version Info
// =============================================================================

struct Version {
    static constexpr int major = 1;
    static constexpr int minor = 0;
    static constexpr int patch = 0;

    static const char* getString() { return "1.0.0"; }
    static const char* getBuildDate() { return __DATE__; }
    static const char* getFrameworkName() { return "EchoelCore"; }
};

} // namespace EchoelCore
