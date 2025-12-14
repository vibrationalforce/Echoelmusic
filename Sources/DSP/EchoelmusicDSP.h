/**
 * ╔══════════════════════════════════════════════════════════════════════════════╗
 * ║            ECHOELMUSIC DSP CORE - JUCE-FREE IMPLEMENTATION                   ║
 * ║                    Pure C++ / iPlug2 Compatible                               ║
 * ╚══════════════════════════════════════════════════════════════════════════════╝
 *
 * This is the framework-agnostic DSP core that works with:
 * - iPlug2 (VST3, AU, AAX, CLAP, Standalone)
 * - Pure C++ applications
 * - Any audio framework
 *
 * NO JUCE DEPENDENCY - Uses only STL and standard C++17
 *
 * MIT License - Fully open source
 */

#pragma once

#include <cmath>
#include <array>
#include <vector>
#include <algorithm>
#include <atomic>
#include <memory>
#include <cstring>

namespace echoelmusic {

//==============================================================================
// MATH CONSTANTS
//==============================================================================

namespace Math {
    constexpr double PI = 3.14159265358979323846;
    constexpr double TWO_PI = 6.28318530717958647692;
    constexpr double HALF_PI = 1.57079632679489661923;
    constexpr float PIf = 3.14159265359f;
    constexpr float TWO_PIf = 6.28318530718f;

    inline float fastTanh(float x) {
        if (x < -3.0f) return -1.0f;
        if (x > 3.0f) return 1.0f;
        float x2 = x * x;
        return x * (27.0f + x2) / (27.0f + 9.0f * x2);
    }

    inline float fastSin(float x) {
        // Normalize to [-PI, PI]
        while (x > PIf) x -= TWO_PIf;
        while (x < -PIf) x += TWO_PIf;
        // Parabolic approximation
        float y = 4.0f / PIf * x - 4.0f / (PIf * PIf) * x * std::abs(x);
        return 0.225f * (y * std::abs(y) - y) + y;
    }

    inline float lerp(float a, float b, float t) {
        return a + t * (b - a);
    }

    inline float clamp(float x, float min, float max) {
        return std::max(min, std::min(max, x));
    }

    inline float dbToLinear(float db) {
        return std::pow(10.0f, db / 20.0f);
    }

    inline float linearToDb(float linear) {
        return 20.0f * std::log10(std::max(linear, 1e-10f));
    }
}

//==============================================================================
// AUDIO BUFFER (JUCE-free replacement)
//==============================================================================

template<typename T = float>
class AudioBuffer {
public:
    AudioBuffer() = default;

    AudioBuffer(int numChannels, int numSamples)
        : mNumChannels(numChannels), mNumSamples(numSamples) {
        allocate();
    }

    void setSize(int numChannels, int numSamples) {
        if (mNumChannels != numChannels || mNumSamples != numSamples) {
            mNumChannels = numChannels;
            mNumSamples = numSamples;
            allocate();
        }
    }

    void clear() {
        for (auto& channel : mData) {
            std::fill(channel.begin(), channel.end(), T(0));
        }
    }

    void applyGain(T gain) {
        for (auto& channel : mData) {
            for (auto& sample : channel) {
                sample *= gain;
            }
        }
    }

    T* getWritePointer(int channel) {
        return mData[channel].data();
    }

    const T* getReadPointer(int channel) const {
        return mData[channel].data();
    }

    int getNumChannels() const { return mNumChannels; }
    int getNumSamples() const { return mNumSamples; }

    void copyFrom(int destChannel, int destStart,
                  const AudioBuffer& source, int sourceChannel, int sourceStart, int numSamples) {
        std::memcpy(mData[destChannel].data() + destStart,
                    source.mData[sourceChannel].data() + sourceStart,
                    numSamples * sizeof(T));
    }

    void addFrom(int destChannel, int destStart,
                 const AudioBuffer& source, int sourceChannel, int sourceStart,
                 int numSamples, T gain = T(1)) {
        T* dest = mData[destChannel].data() + destStart;
        const T* src = source.mData[sourceChannel].data() + sourceStart;
        for (int i = 0; i < numSamples; ++i) {
            dest[i] += src[i] * gain;
        }
    }

private:
    void allocate() {
        mData.resize(mNumChannels);
        for (auto& channel : mData) {
            channel.resize(mNumSamples, T(0));
        }
    }

    int mNumChannels = 0;
    int mNumSamples = 0;
    std::vector<std::vector<T>> mData;
};

//==============================================================================
// ENVELOPE GENERATOR (ADSR)
//==============================================================================

class EnvelopeADSR {
public:
    enum class State { Idle, Attack, Decay, Sustain, Release };

    void setSampleRate(double sampleRate) { mSampleRate = sampleRate; }

    void setParameters(float attack, float decay, float sustain, float release) {
        mAttackTime = std::max(0.001f, attack);
        mDecayTime = std::max(0.001f, decay);
        mSustainLevel = Math::clamp(sustain, 0.0f, 1.0f);
        mReleaseTime = std::max(0.001f, release);
    }

    void noteOn() {
        mState = State::Attack;
        mCurrentValue = 0.0f;
    }

    void noteOff() {
        if (mState != State::Idle) {
            mState = State::Release;
            mReleaseStartValue = mCurrentValue;
        }
    }

    float process() {
        switch (mState) {
            case State::Attack: {
                float attackRate = 1.0f / (mAttackTime * mSampleRate);
                mCurrentValue += attackRate;
                if (mCurrentValue >= 1.0f) {
                    mCurrentValue = 1.0f;
                    mState = State::Decay;
                }
                break;
            }
            case State::Decay: {
                float decayRate = (1.0f - mSustainLevel) / (mDecayTime * mSampleRate);
                mCurrentValue -= decayRate;
                if (mCurrentValue <= mSustainLevel) {
                    mCurrentValue = mSustainLevel;
                    mState = State::Sustain;
                }
                break;
            }
            case State::Sustain:
                mCurrentValue = mSustainLevel;
                break;
            case State::Release: {
                float releaseRate = mReleaseStartValue / (mReleaseTime * mSampleRate);
                mCurrentValue -= releaseRate;
                if (mCurrentValue <= 0.0f) {
                    mCurrentValue = 0.0f;
                    mState = State::Idle;
                }
                break;
            }
            case State::Idle:
            default:
                mCurrentValue = 0.0f;
                break;
        }
        return mCurrentValue;
    }

    bool isActive() const { return mState != State::Idle; }
    float getValue() const { return mCurrentValue; }

private:
    double mSampleRate = 44100.0;
    State mState = State::Idle;
    float mCurrentValue = 0.0f;
    float mAttackTime = 0.01f;
    float mDecayTime = 0.1f;
    float mSustainLevel = 0.7f;
    float mReleaseTime = 0.3f;
    float mReleaseStartValue = 0.0f;
};

//==============================================================================
// OSCILLATOR
//==============================================================================

class Oscillator {
public:
    enum class Waveform { Sine, Saw, Square, Triangle, Noise };

    void setSampleRate(double sampleRate) { mSampleRate = sampleRate; }
    void setFrequency(float freq) { mFrequency = freq; }
    void setWaveform(Waveform wf) { mWaveform = wf; }

    float process() {
        float output = 0.0f;

        switch (mWaveform) {
            case Waveform::Sine:
                output = Math::fastSin(mPhase);
                break;
            case Waveform::Saw:
                output = 2.0f * (mPhase / Math::TWO_PIf) - 1.0f;
                break;
            case Waveform::Square:
                output = mPhase < Math::PIf ? 1.0f : -1.0f;
                break;
            case Waveform::Triangle:
                output = 2.0f * std::abs(2.0f * (mPhase / Math::TWO_PIf) - 1.0f) - 1.0f;
                break;
            case Waveform::Noise:
                output = 2.0f * (static_cast<float>(rand()) / RAND_MAX) - 1.0f;
                break;
        }

        // Advance phase
        mPhase += Math::TWO_PIf * mFrequency / mSampleRate;
        if (mPhase >= Math::TWO_PIf) mPhase -= Math::TWO_PIf;

        return output;
    }

    void reset() { mPhase = 0.0f; }

private:
    double mSampleRate = 44100.0;
    float mFrequency = 440.0f;
    float mPhase = 0.0f;
    Waveform mWaveform = Waveform::Sine;
};

//==============================================================================
// LFO
//==============================================================================

class LFO {
public:
    enum class Shape { Sine, Triangle, Saw, Square, Random };

    void setSampleRate(double sampleRate) { mSampleRate = sampleRate; }
    void setRate(float rateHz) { mRate = rateHz; }
    void setShape(Shape shape) { mShape = shape; }

    float process() {
        float output = 0.0f;

        switch (mShape) {
            case Shape::Sine:
                output = Math::fastSin(mPhase);
                break;
            case Shape::Triangle:
                output = 2.0f * std::abs(2.0f * (mPhase / Math::TWO_PIf) - 1.0f) - 1.0f;
                break;
            case Shape::Saw:
                output = 2.0f * (mPhase / Math::TWO_PIf) - 1.0f;
                break;
            case Shape::Square:
                output = mPhase < Math::PIf ? 1.0f : -1.0f;
                break;
            case Shape::Random:
                if (mPhase < mLastPhase) {
                    mRandomValue = 2.0f * (static_cast<float>(rand()) / RAND_MAX) - 1.0f;
                }
                output = mRandomValue;
                break;
        }

        mLastPhase = mPhase;
        mPhase += Math::TWO_PIf * mRate / mSampleRate;
        if (mPhase >= Math::TWO_PIf) mPhase -= Math::TWO_PIf;

        return output;
    }

private:
    double mSampleRate = 44100.0;
    float mRate = 1.0f;
    float mPhase = 0.0f;
    float mLastPhase = 0.0f;
    float mRandomValue = 0.0f;
    Shape mShape = Shape::Sine;
};

//==============================================================================
// MOOG LADDER FILTER (JUCE-free)
//==============================================================================

class MoogLadder {
public:
    void setSampleRate(double sampleRate) { mSampleRate = sampleRate; }

    void setCutoff(float cutoffHz) {
        mCutoff = Math::clamp(cutoffHz, 20.0f, 20000.0f);
    }

    void setResonance(float resonance) {
        mResonance = Math::clamp(resonance, 0.0f, 1.0f);
    }

    float process(float input) {
        // Frequency coefficient
        float fc = mCutoff / mSampleRate;
        float g = 0.9892f * fc - 0.4342f * fc * fc + 0.1381f * fc * fc * fc;

        // Resonance scaling
        float res = mResonance * (1.0029f + 0.0526f * fc - 0.926f * fc * fc);

        // Feedback
        float feedback = res * mStage[3];

        // Input with saturation
        float in = Math::fastTanh(input - feedback);

        // Four cascaded one-pole filters
        for (int i = 0; i < 4; ++i) {
            float out = g * in + (1.0f - g) * mStage[i];
            mStage[i] = out;
            in = out;
        }

        return mStage[3];
    }

    void reset() { mStage.fill(0.0f); }

private:
    double mSampleRate = 44100.0;
    float mCutoff = 1000.0f;
    float mResonance = 0.0f;
    std::array<float, 4> mStage{};
};

//==============================================================================
// DELAY LINE
//==============================================================================

class DelayLine {
public:
    void prepare(double sampleRate, float maxDelayMs) {
        mSampleRate = sampleRate;
        int maxSamples = static_cast<int>(maxDelayMs * 0.001 * sampleRate) + 1;
        mBuffer.resize(maxSamples, 0.0f);
        mWritePos = 0;
    }

    void setDelay(float delayMs) {
        mDelaySamples = delayMs * 0.001f * mSampleRate;
    }

    float process(float input) {
        // Write
        mBuffer[mWritePos] = input;

        // Read with linear interpolation
        float readPos = mWritePos - mDelaySamples;
        if (readPos < 0) readPos += mBuffer.size();

        int readIdx = static_cast<int>(readPos);
        float frac = readPos - readIdx;
        int nextIdx = (readIdx + 1) % mBuffer.size();

        float output = mBuffer[readIdx] * (1.0f - frac) + mBuffer[nextIdx] * frac;

        // Advance write position
        mWritePos = (mWritePos + 1) % mBuffer.size();

        return output;
    }

    void clear() { std::fill(mBuffer.begin(), mBuffer.end(), 0.0f); }

private:
    double mSampleRate = 44100.0;
    std::vector<float> mBuffer;
    int mWritePos = 0;
    float mDelaySamples = 0.0f;
};

//==============================================================================
// REVERB (Freeverb-style)
//==============================================================================

class Reverb {
public:
    void prepare(double sampleRate) {
        mSampleRate = sampleRate;

        // Comb filter delay times (in samples at 44100)
        const int combTimes[] = {1557, 1617, 1491, 1422, 1277, 1356, 1188, 1116};
        for (int i = 0; i < 8; ++i) {
            int size = static_cast<int>(combTimes[i] * sampleRate / 44100.0);
            mCombBuffers[i].resize(size, 0.0f);
            mCombPos[i] = 0;
        }

        // Allpass delay times
        const int allpassTimes[] = {225, 556, 441, 341};
        for (int i = 0; i < 4; ++i) {
            int size = static_cast<int>(allpassTimes[i] * sampleRate / 44100.0);
            mAllpassBuffers[i].resize(size, 0.0f);
            mAllpassPos[i] = 0;
        }
    }

    void setParameters(float roomSize, float damping, float mix) {
        mRoomSize = Math::clamp(roomSize, 0.0f, 1.0f);
        mDamping = Math::clamp(damping, 0.0f, 1.0f);
        mMix = Math::clamp(mix, 0.0f, 1.0f);
    }

    float process(float input) {
        float wet = 0.0f;

        // Parallel comb filters
        for (int i = 0; i < 8; ++i) {
            int pos = mCombPos[i];
            float delayed = mCombBuffers[i][pos];
            wet += delayed;

            // Lowpass filter for damping
            mCombLowpass[i] = delayed * (1.0f - mDamping) + mCombLowpass[i] * mDamping;

            // Write back with feedback
            mCombBuffers[i][pos] = input + mCombLowpass[i] * mRoomSize;

            mCombPos[i] = (pos + 1) % mCombBuffers[i].size();
        }

        wet /= 8.0f;

        // Series allpass filters
        for (int i = 0; i < 4; ++i) {
            int pos = mAllpassPos[i];
            float delayed = mAllpassBuffers[i][pos];

            float output = -wet + delayed;
            mAllpassBuffers[i][pos] = wet + delayed * 0.5f;

            wet = output;
            mAllpassPos[i] = (pos + 1) % mAllpassBuffers[i].size();
        }

        return input * (1.0f - mMix) + wet * mMix;
    }

    void clear() {
        for (auto& buf : mCombBuffers) std::fill(buf.begin(), buf.end(), 0.0f);
        for (auto& buf : mAllpassBuffers) std::fill(buf.begin(), buf.end(), 0.0f);
        mCombLowpass.fill(0.0f);
    }

private:
    double mSampleRate = 44100.0;
    float mRoomSize = 0.5f;
    float mDamping = 0.5f;
    float mMix = 0.3f;

    std::array<std::vector<float>, 8> mCombBuffers;
    std::array<int, 8> mCombPos{};
    std::array<float, 8> mCombLowpass{};

    std::array<std::vector<float>, 4> mAllpassBuffers;
    std::array<int, 4> mAllpassPos{};
};

//==============================================================================
// SYNTH VOICE
//==============================================================================

class SynthVoice {
public:
    void prepare(double sampleRate) {
        mSampleRate = sampleRate;
        mOsc1.setSampleRate(sampleRate);
        mOsc2.setSampleRate(sampleRate);
        mFilter.setSampleRate(sampleRate);
        mAmpEnv.setSampleRate(sampleRate);
        mFilterEnv.setSampleRate(sampleRate);
        mLFO.setSampleRate(sampleRate);
    }

    void noteOn(int note, float velocity) {
        mNote = note;
        mVelocity = velocity;
        mOsc1.setFrequency(midiToFreq(note));
        mOsc2.setFrequency(midiToFreq(note + mOsc2Semitones));
        mOsc1.reset();
        mOsc2.reset();
        mAmpEnv.noteOn();
        mFilterEnv.noteOn();
        mActive = true;
    }

    void noteOff() {
        mAmpEnv.noteOff();
        mFilterEnv.noteOff();
    }

    float process() {
        if (!mActive) return 0.0f;

        // LFO
        float lfoValue = mLFO.process();

        // Oscillators
        float osc1 = mOsc1.process();
        float osc2 = mOsc2.process();
        float oscMix = osc1 * (1.0f - mOscMix) + osc2 * mOscMix;

        // Filter with envelope and LFO modulation
        float filterEnv = mFilterEnv.process();
        float cutoff = mFilterCutoff + filterEnv * mFilterEnvAmount + lfoValue * mLFOToFilter;
        mFilter.setCutoff(cutoff);
        float filtered = mFilter.process(oscMix);

        // Amplitude envelope
        float ampEnv = mAmpEnv.process();
        float output = filtered * ampEnv * mVelocity;

        if (!mAmpEnv.isActive()) {
            mActive = false;
        }

        return output;
    }

    bool isActive() const { return mActive; }
    int getNote() const { return mNote; }

    // Parameters
    void setOscillatorMix(float mix) { mOscMix = mix; }
    void setOsc1Waveform(Oscillator::Waveform wf) { mOsc1.setWaveform(wf); }
    void setOsc2Waveform(Oscillator::Waveform wf) { mOsc2.setWaveform(wf); }
    void setOsc2Semitones(int semitones) { mOsc2Semitones = semitones; }
    void setFilterCutoff(float cutoff) { mFilterCutoff = cutoff; mFilter.setCutoff(cutoff); }
    void setFilterResonance(float res) { mFilter.setResonance(res); }
    void setFilterEnvAmount(float amount) { mFilterEnvAmount = amount; }
    void setAmpEnvelope(float a, float d, float s, float r) { mAmpEnv.setParameters(a, d, s, r); }
    void setFilterEnvelope(float a, float d, float s, float r) { mFilterEnv.setParameters(a, d, s, r); }
    void setLFORate(float rate) { mLFO.setRate(rate); }
    void setLFOToFilter(float amount) { mLFOToFilter = amount; }

private:
    float midiToFreq(int note) {
        return 440.0f * std::pow(2.0f, (note - 69) / 12.0f);
    }

    double mSampleRate = 44100.0;
    bool mActive = false;
    int mNote = 0;
    float mVelocity = 0.0f;

    Oscillator mOsc1, mOsc2;
    MoogLadder mFilter;
    EnvelopeADSR mAmpEnv, mFilterEnv;
    LFO mLFO;

    float mOscMix = 0.5f;
    int mOsc2Semitones = 0;
    float mFilterCutoff = 1000.0f;
    float mFilterEnvAmount = 2000.0f;
    float mLFOToFilter = 0.0f;
};

//==============================================================================
// BIO-REACTIVE STATE
//==============================================================================

struct BioState {
    float hrv = 50.0f;           // Heart Rate Variability (ms)
    float coherence = 0.5f;      // HeartMath coherence (0-1)
    float heartRate = 72.0f;     // BPM
    float breathingPhase = 0.0f; // 0-1 breathing cycle
    float stressLevel = 0.3f;    // 0-1

    // Calculate bio modulation value for filter/LFO
    float getFilterModulation() const {
        return (hrv - 50.0f) / 100.0f * coherence;
    }

    float getLFOModulation() const {
        return std::sin(breathingPhase * Math::TWO_PIf);
    }
};

//==============================================================================
// MAIN DSP ENGINE
//==============================================================================

class EchoelmusicDSP {
public:
    static constexpr int kMaxVoices = 16;

    void prepare(double sampleRate, int blockSize) {
        mSampleRate = sampleRate;
        mBlockSize = blockSize;

        for (auto& voice : mVoices) {
            voice.prepare(sampleRate);
        }

        mReverb.prepare(sampleRate);
        mDelay.prepare(sampleRate, 2000.0f);  // 2 second max delay
    }

    void processBlock(float** outputs, int numChannels, int numSamples) {
        // Clear output
        for (int ch = 0; ch < numChannels; ++ch) {
            std::memset(outputs[ch], 0, numSamples * sizeof(float));
        }

        // Apply bio-reactive modulation
        applyBioModulation();

        // Process voices
        for (int i = 0; i < numSamples; ++i) {
            float sample = 0.0f;

            for (auto& voice : mVoices) {
                if (voice.isActive()) {
                    sample += voice.process();
                }
            }

            // Apply effects
            sample = mReverb.process(sample);

            // Soft clip
            sample = Math::fastTanh(sample * mMasterGain);

            // Output to all channels
            for (int ch = 0; ch < numChannels; ++ch) {
                outputs[ch][i] = sample;
            }
        }
    }

    // MIDI handling
    void noteOn(int note, float velocity) {
        // Find free voice or steal oldest
        SynthVoice* voice = nullptr;

        for (auto& v : mVoices) {
            if (!v.isActive()) {
                voice = &v;
                break;
            }
        }

        if (!voice) {
            voice = &mVoices[0];  // Simple voice stealing
        }

        voice->noteOn(note, velocity);
    }

    void noteOff(int note) {
        for (auto& voice : mVoices) {
            if (voice.isActive() && voice.getNote() == note) {
                voice.noteOff();
            }
        }
    }

    // Bio-reactive
    void updateBioState(const BioState& state) {
        mBioState = state;
    }

    // Parameters
    void setMasterGain(float gain) { mMasterGain = gain; }
    void setReverbMix(float mix) { mReverb.setParameters(0.5f, 0.5f, mix); }
    void setDelayTime(float ms) { mDelay.setDelay(ms); }

    void setFilterCutoff(float cutoff) {
        for (auto& v : mVoices) v.setFilterCutoff(cutoff);
    }

    void setFilterResonance(float res) {
        for (auto& v : mVoices) v.setFilterResonance(res);
    }

    void setOsc1Waveform(int wf) {
        for (auto& v : mVoices) v.setOsc1Waveform(static_cast<Oscillator::Waveform>(wf));
    }

    void setOsc2Waveform(int wf) {
        for (auto& v : mVoices) v.setOsc2Waveform(static_cast<Oscillator::Waveform>(wf));
    }

    void setAmpEnvelope(float a, float d, float s, float r) {
        for (auto& v : mVoices) v.setAmpEnvelope(a, d, s, r);
    }

    void setFilterEnvelope(float a, float d, float s, float r) {
        for (auto& v : mVoices) v.setFilterEnvelope(a, d, s, r);
    }

private:
    void applyBioModulation() {
        // Modulate filter cutoff based on HRV and coherence
        float bioFilterMod = mBioState.getFilterModulation();
        // This would be applied in the voice processing

        // Modulate LFO based on breathing
        float bioLFOMod = mBioState.getLFOModulation();
        // Applied to LFO depth
    }

    double mSampleRate = 44100.0;
    int mBlockSize = 512;

    std::array<SynthVoice, kMaxVoices> mVoices;
    Reverb mReverb;
    DelayLine mDelay;

    BioState mBioState;
    float mMasterGain = 1.0f;
};

} // namespace echoelmusic

// Convenience typedef for iPlug2
using EchoelmusicDSP = echoelmusic::EchoelmusicDSP;
