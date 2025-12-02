#pragma once

/**
 * Polyphonic Synthesizer for Android
 * 16-voice, 2-oscillator per voice, Moog-style filter
 */

#include <array>
#include <cmath>
#include <random>

namespace echoelmusic {

constexpr int kMaxVoices = 16;
constexpr float kPi = 3.14159265358979323846f;
constexpr float kTwoPi = 6.28318530717958647692f;

// Waveform types
enum class Waveform { Sine, Triangle, Sawtooth, Square, Noise };

// Band-limited oscillator with PolyBLEP
class Oscillator {
public:
    void setSampleRate(float sr) { mSampleRate = sr; }
    void setFrequency(float freq) { mFrequency = freq; }
    void setWaveform(Waveform wf) { mWaveform = wf; }
    void reset() { mPhase = 0.0f; }

    float process();

private:
    float mSampleRate = 48000.0f;
    float mFrequency = 440.0f;
    float mPhase = 0.0f;
    Waveform mWaveform = Waveform::Sawtooth;

    std::mt19937 mNoiseGen{std::random_device{}()};
    std::uniform_real_distribution<float> mNoiseDist{-1.0f, 1.0f};

    float polyBLEP(float t, float dt);
};

// Moog-style ladder filter (24dB/oct)
class MoogFilter {
public:
    void setSampleRate(float sr) { mSampleRate = sr; }
    void setCutoff(float cutoff) { mCutoff = std::clamp(cutoff, 20.0f, 20000.0f); }
    void setResonance(float res) { mResonance = std::clamp(res, 0.0f, 1.0f); }
    void reset() { mState.fill(0.0f); }

    float process(float input);

private:
    float mSampleRate = 48000.0f;
    float mCutoff = 1000.0f;
    float mResonance = 0.5f;
    std::array<float, 4> mState = {0, 0, 0, 0};
};

// ADSR Envelope
class Envelope {
public:
    enum class Stage { Idle, Attack, Decay, Sustain, Release };

    void setSampleRate(float sr) { mSampleRate = sr; }
    void setAttack(float ms) { mAttack = ms; }
    void setDecay(float ms) { mDecay = ms; }
    void setSustain(float level) { mSustain = std::clamp(level, 0.0f, 1.0f); }
    void setRelease(float ms) { mRelease = ms; }

    void noteOn();
    void noteOff();
    float process();
    bool isActive() const { return mStage != Stage::Idle; }
    Stage getStage() const { return mStage; }

private:
    float mSampleRate = 48000.0f;
    float mAttack = 10.0f;
    float mDecay = 200.0f;
    float mSustain = 0.7f;
    float mRelease = 300.0f;

    Stage mStage = Stage::Idle;
    float mLevel = 0.0f;
    float mAttackInc = 0.0f;
    float mDecayInc = 0.0f;
    float mReleaseInc = 0.0f;
};

// LFO
class LFO {
public:
    void setSampleRate(float sr) { mSampleRate = sr; }
    void setRate(float hz) { mRate = std::clamp(hz, 0.01f, 50.0f); }
    void setWaveform(Waveform wf) { mWaveform = wf; }
    void reset() { mPhase = 0.0f; }

    float process();

private:
    float mSampleRate = 48000.0f;
    float mRate = 2.0f;
    float mPhase = 0.0f;
    Waveform mWaveform = Waveform::Sine;
};

// Single synth voice
class Voice {
public:
    void setSampleRate(float sr);
    void noteOn(int note, int velocity);
    void noteOff();
    bool isActive() const { return mAmpEnv.isActive(); }
    int getNote() const { return mNote; }

    // Parameter setters
    void setOsc1Waveform(Waveform wf) { mOsc1.setWaveform(wf); }
    void setOsc2Waveform(Waveform wf) { mOsc2.setWaveform(wf); }
    void setOsc2Mix(float mix) { mOsc2Mix = mix; }
    void setFilterCutoff(float cutoff) { mFilterCutoff = cutoff; }
    void setFilterResonance(float res) { mFilter.setResonance(res); }
    void setFilterEnvAmount(float amt) { mFilterEnvAmount = amt; }
    void setAmpEnvelope(float a, float d, float s, float r);
    void setFilterEnvelope(float a, float d, float s, float r);

    float process();

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

// Main Synth class
class Synth {
public:
    Synth();

    void setSampleRate(float sr);
    void noteOn(int note, int velocity);
    void noteOff(int note);
    void process(float* output, int numFrames);

    void setParameter(int paramId, float value);
    float getParameter(int paramId) const;

    // Direct setters (for real-time bio modulation)
    void setFilterCutoffDirect(float cutoff);
    void setLFORateDirect(float rate);

private:
    float mSampleRate = 48000.0f;
    std::array<Voice, kMaxVoices> mVoices;
    LFO mLFO;

    // Parameters
    float mOsc1Waveform = 0;
    float mOsc2Waveform = 2;
    float mOsc2Mix = 0.5f;
    float mFilterCutoff = 5000.0f;
    float mFilterResonance = 0.3f;
    float mFilterEnvAmount = 0.5f;
    float mAmpAttack = 10.0f;
    float mAmpDecay = 200.0f;
    float mAmpSustain = 0.7f;
    float mAmpRelease = 300.0f;
    float mLFORate = 2.0f;
    float mLFODepth = 0.5f;
    float mLFOToFilter = 0.3f;

    void updateVoiceParameters(Voice& voice);
};

} // namespace echoelmusic
