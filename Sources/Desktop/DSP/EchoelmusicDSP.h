#pragma once

/**
 * Echoelmusic DSP Engine - JUCE-FREE Implementation
 *
 * Cross-platform DSP that works with:
 * - iPlug2 (Desktop: VST3, AU, AAX, CLAP)
 * - iOS (via Swift bridge with Accelerate)
 *
 * No JUCE dependency - MIT License compatible!
 */

#include <cmath>
#include <array>
#include <vector>
#include <algorithm>
#include <random>

// Platform-specific SIMD
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
    #include <arm_neon.h>
    #define USE_NEON 1
#elif defined(__SSE2__)
    #include <immintrin.h>
    #define USE_SSE 1
#endif

namespace echoelmusic {

// Constants
constexpr float kPi = 3.14159265358979323846f;
constexpr float kTwoPi = 6.28318530717958647692f;
constexpr float kDenormalThreshold = 1.0e-15f;

// Flush denormals to zero
inline float flushDenormals(float value)
{
    return (std::abs(value) < kDenormalThreshold) ? 0.0f : value;
}

// MIDI note to frequency
inline float noteToFrequency(int note)
{
    return 440.0f * std::pow(2.0f, (note - 69) / 12.0f);
}

//==============================================================================
// Waveform Types
//==============================================================================
enum class Waveform
{
    Sine = 0,
    Triangle,
    Sawtooth,
    Square,
    Pulse,
    Noise
};

//==============================================================================
// PolyBLEP Anti-Aliasing
//==============================================================================
inline float polyBLEP(float t, float dt)
{
    if (t < dt)
    {
        t /= dt;
        return t + t - t * t - 1.0f;
    }
    else if (t > 1.0f - dt)
    {
        t = (t - 1.0f) / dt;
        return t * t + t + t + 1.0f;
    }
    return 0.0f;
}

//==============================================================================
// Oscillator (Band-Limited)
//==============================================================================
class Oscillator
{
public:
    void SetSampleRate(float sampleRate) { mSampleRate = sampleRate; }
    void SetFrequency(float freq) { mFrequency = freq; }
    void SetWaveform(Waveform wf) { mWaveform = wf; }
    void SetPulseWidth(float pw) { mPulseWidth = std::clamp(pw, 0.1f, 0.9f); }
    void Reset() { mPhase = 0.0f; }

    float Process()
    {
        float dt = mFrequency / mSampleRate;
        float output = 0.0f;

        switch (mWaveform)
        {
            case Waveform::Sine:
                output = std::sin(mPhase * kTwoPi);
                break;

            case Waveform::Triangle:
                output = mPhase < 0.5f ? (4.0f * mPhase - 1.0f) : (3.0f - 4.0f * mPhase);
                break;

            case Waveform::Sawtooth:
            {
                output = 2.0f * mPhase - 1.0f;
                output -= polyBLEP(mPhase, dt);
                break;
            }

            case Waveform::Square:
            {
                output = mPhase < 0.5f ? 1.0f : -1.0f;
                output += polyBLEP(mPhase, dt);
                output -= polyBLEP(std::fmod(mPhase + 0.5f, 1.0f), dt);
                break;
            }

            case Waveform::Pulse:
            {
                output = mPhase < mPulseWidth ? 1.0f : -1.0f;
                output += polyBLEP(mPhase, dt);
                output -= polyBLEP(std::fmod(mPhase + (1.0f - mPulseWidth), 1.0f), dt);
                break;
            }

            case Waveform::Noise:
                output = mNoiseDistribution(mNoiseGenerator);
                break;
        }

        // Advance phase
        mPhase += dt;
        if (mPhase >= 1.0f) mPhase -= 1.0f;

        return output;
    }

private:
    float mSampleRate = 48000.0f;
    float mFrequency = 440.0f;
    float mPhase = 0.0f;
    float mPulseWidth = 0.5f;
    Waveform mWaveform = Waveform::Sawtooth;

    std::mt19937 mNoiseGenerator{std::random_device{}()};
    std::uniform_real_distribution<float> mNoiseDistribution{-1.0f, 1.0f};
};

//==============================================================================
// State Variable Filter (12dB/oct)
//==============================================================================
class StateVariableFilter
{
public:
    void SetSampleRate(float sr) { mSampleRate = sr; }
    void SetCutoff(float cutoff) { mCutoff = std::clamp(cutoff, 20.0f, 20000.0f); }
    void SetResonance(float res) { mResonance = std::clamp(res, 0.0f, 1.0f); }
    void Reset() { mLowpass = mBandpass = mHighpass = 0.0f; }

    float Process(float input)
    {
        float f = 2.0f * std::sin(kPi * mCutoff / mSampleRate);
        float q = 1.0f - mResonance;

        mLowpass += f * mBandpass;
        mHighpass = input - mLowpass - q * mBandpass;
        mBandpass += f * mHighpass;

        // Flush denormals
        mLowpass = flushDenormals(mLowpass);
        mBandpass = flushDenormals(mBandpass);
        mHighpass = flushDenormals(mHighpass);

        return mLowpass;
    }

private:
    float mSampleRate = 48000.0f;
    float mCutoff = 1000.0f;
    float mResonance = 0.5f;
    float mLowpass = 0.0f;
    float mBandpass = 0.0f;
    float mHighpass = 0.0f;
};

//==============================================================================
// Moog Ladder Filter (24dB/oct)
//==============================================================================
class MoogFilter
{
public:
    void SetSampleRate(float sr) { mSampleRate = sr; }
    void SetCutoff(float cutoff) { mCutoff = std::clamp(cutoff, 20.0f, 20000.0f); }
    void SetResonance(float res) { mResonance = std::clamp(res, 0.0f, 1.0f); }
    void Reset() { mState.fill(0.0f); }

    float Process(float input)
    {
        float fc = mCutoff / mSampleRate;
        fc = std::clamp(fc, 0.0001f, 0.45f);
        float f = fc * 1.16f;
        float fb = mResonance * (1.0f - 0.15f * f * f) * 4.1f;

        input -= mState[3] * fb;
        input *= 0.35013f * (f * f) * (f * f);

        mState[0] = input + 0.3f * mState[0];
        mState[1] = mState[0] + 0.3f * mState[1];
        mState[2] = mState[1] + 0.3f * mState[2];
        mState[3] = mState[2] + 0.3f * mState[3];

        // Flush denormals
        for (auto& s : mState) s = flushDenormals(s);

        return mState[3];
    }

private:
    float mSampleRate = 48000.0f;
    float mCutoff = 1000.0f;
    float mResonance = 0.5f;
    std::array<float, 4> mState = {0.0f, 0.0f, 0.0f, 0.0f};
};

//==============================================================================
// ADSR Envelope
//==============================================================================
class Envelope
{
public:
    enum class Stage { Idle, Attack, Decay, Sustain, Release };

    void SetSampleRate(float sr) { mSampleRate = sr; }
    void SetAttack(float ms) { mAttackTime = ms; }
    void SetDecay(float ms) { mDecayTime = ms; }
    void SetSustain(float level) { mSustainLevel = std::clamp(level, 0.0f, 1.0f); }
    void SetRelease(float ms) { mReleaseTime = ms; }

    void NoteOn()
    {
        mStage = Stage::Attack;
        mAttackIncrement = 1.0f / (mAttackTime * mSampleRate * 0.001f);
    }

    void NoteOff()
    {
        if (mStage != Stage::Idle)
        {
            mStage = Stage::Release;
            mReleaseIncrement = mLevel / (mReleaseTime * mSampleRate * 0.001f);
        }
    }

    float Process()
    {
        switch (mStage)
        {
            case Stage::Idle:
                mLevel = 0.0f;
                break;

            case Stage::Attack:
                mLevel += mAttackIncrement;
                if (mLevel >= 1.0f)
                {
                    mLevel = 1.0f;
                    mStage = Stage::Decay;
                    mDecayIncrement = (1.0f - mSustainLevel) / (mDecayTime * mSampleRate * 0.001f);
                }
                break;

            case Stage::Decay:
                mLevel -= mDecayIncrement;
                if (mLevel <= mSustainLevel)
                {
                    mLevel = mSustainLevel;
                    mStage = Stage::Sustain;
                }
                break;

            case Stage::Sustain:
                mLevel = mSustainLevel;
                break;

            case Stage::Release:
                mLevel -= mReleaseIncrement;
                if (mLevel <= 0.0f)
                {
                    mLevel = 0.0f;
                    mStage = Stage::Idle;
                }
                break;
        }

        return mLevel;
    }

    bool IsActive() const { return mStage != Stage::Idle; }
    Stage GetStage() const { return mStage; }

private:
    float mSampleRate = 48000.0f;
    float mAttackTime = 10.0f;
    float mDecayTime = 200.0f;
    float mSustainLevel = 0.7f;
    float mReleaseTime = 300.0f;

    Stage mStage = Stage::Idle;
    float mLevel = 0.0f;
    float mAttackIncrement = 0.0f;
    float mDecayIncrement = 0.0f;
    float mReleaseIncrement = 0.0f;
};

//==============================================================================
// LFO (Low Frequency Oscillator)
//==============================================================================
class LFO
{
public:
    void SetSampleRate(float sr) { mSampleRate = sr; }
    void SetRate(float hz) { mRate = std::clamp(hz, 0.01f, 50.0f); }
    void SetWaveform(Waveform wf) { mWaveform = wf; }
    void Reset() { mPhase = 0.0f; }

    float Process()
    {
        float output = 0.0f;
        float dt = mRate / mSampleRate;

        switch (mWaveform)
        {
            case Waveform::Sine:
                output = std::sin(mPhase * kTwoPi);
                break;
            case Waveform::Triangle:
                output = mPhase < 0.5f ? (4.0f * mPhase - 1.0f) : (3.0f - 4.0f * mPhase);
                break;
            case Waveform::Sawtooth:
                output = 2.0f * mPhase - 1.0f;
                break;
            case Waveform::Square:
                output = mPhase < 0.5f ? 1.0f : -1.0f;
                break;
            default:
                break;
        }

        mPhase += dt;
        if (mPhase >= 1.0f) mPhase -= 1.0f;

        return output;
    }

private:
    float mSampleRate = 48000.0f;
    float mRate = 2.0f;
    float mPhase = 0.0f;
    Waveform mWaveform = Waveform::Sine;
};

//==============================================================================
// Simple Reverb (Schroeder)
//==============================================================================
class SimpleReverb
{
public:
    void SetSampleRate(float sr)
    {
        mSampleRate = sr;
        // Pre-allocate delay lines once (avoid allocation in audio path)
        int maxDelay = static_cast<int>(sr * 0.1f);  // 100ms max
        for (auto& comb : mCombs) {
            comb.assign(maxDelay, 0.0f);
            comb.shrink_to_fit();
        }
        for (auto& ap : mAllpass) {
            ap.assign(maxDelay / 4, 0.0f);
            ap.shrink_to_fit();
        }
        // Reset read positions
        mCombIdx.fill(0);
        mApIdx.fill(0);
    }

    void SetMix(float mix) { mMix = std::clamp(mix, 0.0f, 1.0f); }
    void SetDecay(float decay) { mDecay = std::clamp(decay, 0.1f, 0.99f); }

    float Process(float input)
    {
        // 4 parallel comb filters
        float combOut = 0.0f;
        const int combDelays[] = {1557, 1617, 1491, 1422};  // Prime delays

        for (int i = 0; i < 4; i++)
        {
            int delay = static_cast<int>(combDelays[i] * mSampleRate / 44100.0f);
            delay = std::min(delay, static_cast<int>(mCombs[i].size()) - 1);

            float delayed = mCombs[i][mCombIdx[i]];
            mCombs[i][mCombIdx[i]] = input + delayed * mDecay;
            mCombIdx[i] = (mCombIdx[i] + 1) % delay;

            combOut += delayed;
        }
        combOut *= 0.25f;

        // 2 series allpass filters
        const int apDelays[] = {225, 556};
        float apOut = combOut;

        for (int i = 0; i < 2; i++)
        {
            int delay = static_cast<int>(apDelays[i] * mSampleRate / 44100.0f);
            delay = std::min(delay, static_cast<int>(mAllpass[i].size()) - 1);

            float delayed = mAllpass[i][mApIdx[i]];
            float temp = apOut + delayed * 0.5f;
            mAllpass[i][mApIdx[i]] = temp;
            mApIdx[i] = (mApIdx[i] + 1) % delay;
            apOut = delayed - apOut * 0.5f;
        }

        return input * (1.0f - mMix) + apOut * mMix;
    }

private:
    float mSampleRate = 48000.0f;
    float mMix = 0.3f;
    float mDecay = 0.8f;

    std::array<std::vector<float>, 4> mCombs;
    std::array<std::vector<float>, 2> mAllpass;
    std::array<int, 4> mCombIdx = {0, 0, 0, 0};
    std::array<int, 2> mApIdx = {0, 0};
};

//==============================================================================
// Synth Voice
//==============================================================================
class Voice
{
public:
    void SetSampleRate(float sr)
    {
        mOsc1.SetSampleRate(sr);
        mOsc2.SetSampleRate(sr);
        mFilter.SetSampleRate(sr);
        mAmpEnv.SetSampleRate(sr);
        mFilterEnv.SetSampleRate(sr);
    }

    void NoteOn(int note, int velocity)
    {
        mNote = note;
        mVelocity = velocity / 127.0f;
        mFrequency = noteToFrequency(note);

        mOsc1.SetFrequency(mFrequency);
        mOsc2.SetFrequency(mFrequency);
        mOsc1.Reset();
        mOsc2.Reset();

        mAmpEnv.NoteOn();
        mFilterEnv.NoteOn();
    }

    void NoteOff()
    {
        mAmpEnv.NoteOff();
        mFilterEnv.NoteOff();
    }

    bool IsActive() const { return mAmpEnv.IsActive(); }
    int GetNote() const { return mNote; }

    // Setters
    void SetOsc1Waveform(Waveform wf) { mOsc1.SetWaveform(wf); }
    void SetOsc2Waveform(Waveform wf) { mOsc2.SetWaveform(wf); }
    void SetOsc2Mix(float mix) { mOsc2Mix = mix; }
    void SetFilterCutoff(float cutoff) { mFilterCutoff = cutoff; }
    void SetFilterResonance(float res) { mFilter.SetResonance(res); }
    void SetFilterEnvAmount(float amt) { mFilterEnvAmount = amt; }
    void SetAmpEnvelope(float a, float d, float s, float r)
    {
        mAmpEnv.SetAttack(a);
        mAmpEnv.SetDecay(d);
        mAmpEnv.SetSustain(s);
        mAmpEnv.SetRelease(r);
    }
    void SetFilterEnvelope(float a, float d, float s, float r)
    {
        mFilterEnv.SetAttack(a);
        mFilterEnv.SetDecay(d);
        mFilterEnv.SetSustain(s);
        mFilterEnv.SetRelease(r);
    }

    float Process()
    {
        if (!IsActive()) return 0.0f;

        // Mix oscillators
        float osc1 = mOsc1.Process();
        float osc2 = mOsc2.Process();
        float mixed = osc1 * (1.0f - mOsc2Mix) + osc2 * mOsc2Mix;

        // Filter with envelope modulation
        float filterEnvLevel = mFilterEnv.Process();
        float modCutoff = mFilterCutoff + mFilterEnvAmount * filterEnvLevel * 10000.0f;
        mFilter.SetCutoff(std::clamp(modCutoff, 20.0f, 20000.0f));
        float filtered = mFilter.Process(mixed);

        // Amp envelope
        float ampLevel = mAmpEnv.Process();
        return filtered * ampLevel * mVelocity;
    }

private:
    int mNote = 60;
    float mVelocity = 1.0f;
    float mFrequency = 440.0f;

    Oscillator mOsc1, mOsc2;
    MoogFilter mFilter;
    Envelope mAmpEnv, mFilterEnv;

    float mOsc2Mix = 0.5f;
    float mFilterCutoff = 5000.0f;
    float mFilterEnvAmount = 0.5f;
};

} // namespace echoelmusic

//==============================================================================
// Main DSP Engine Class
//==============================================================================
class EchoelmusicDSP
{
public:
    static const int kMaxVoices = 16;

    void Reset(float sampleRate)
    {
        mSampleRate = sampleRate;
        for (auto& voice : mVoices)
        {
            voice.SetSampleRate(sampleRate);
        }
        mLFO.SetSampleRate(sampleRate);
        mReverb.SetSampleRate(sampleRate);
    }

    void NoteOn(int note, int velocity)
    {
        // Find free voice or steal oldest
        int voiceIdx = -1;
        for (int i = 0; i < kMaxVoices; i++)
        {
            if (!mVoices[i].IsActive())
            {
                voiceIdx = i;
                break;
            }
        }

        if (voiceIdx < 0)
        {
            // Voice stealing - use voice 0
            voiceIdx = 0;
        }

        mVoices[voiceIdx].NoteOn(note, velocity);
    }

    void NoteOff(int note)
    {
        for (auto& voice : mVoices)
        {
            if (voice.IsActive() && voice.GetNote() == note)
            {
                voice.NoteOff();
            }
        }
    }

    void ProcessBlock(float* outputL, float* outputR, int numFrames)
    {
        for (int s = 0; s < numFrames; s++)
        {
            float lfoValue = mLFO.Process();
            float sample = 0.0f;

            // Sum all voices
            for (auto& voice : mVoices)
            {
                sample += voice.Process();
            }

            // Apply reverb
            sample = mReverb.Process(sample);

            // Stereo output
            outputL[s] = sample;
            outputR[s] = sample;
        }
    }

    // Parameter setters
    void SetOsc1Waveform(int wf)
    {
        for (auto& v : mVoices) v.SetOsc1Waveform(static_cast<echoelmusic::Waveform>(wf));
    }
    void SetOsc2Waveform(int wf)
    {
        for (auto& v : mVoices) v.SetOsc2Waveform(static_cast<echoelmusic::Waveform>(wf));
    }
    void SetFilterCutoff(float cutoff)
    {
        for (auto& v : mVoices) v.SetFilterCutoff(cutoff);
    }
    void SetFilterResonance(float res)
    {
        for (auto& v : mVoices) v.SetFilterResonance(res);
    }
    void SetReverbMix(float mix) { mReverb.SetMix(mix); }
    void SetLFORate(float rate) { mLFO.SetRate(rate); }
    void SetPitchBend(float bend) { mPitchBend = bend; }

private:
    float mSampleRate = 48000.0f;
    std::array<echoelmusic::Voice, kMaxVoices> mVoices;
    echoelmusic::LFO mLFO;
    echoelmusic::SimpleReverb mReverb;
    float mPitchBend = 0.0f;
};
