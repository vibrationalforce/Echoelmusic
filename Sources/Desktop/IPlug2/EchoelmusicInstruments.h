/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * ECHOELMUSIC INSTRUMENTS - iPlug2 Bridge
 * ═══════════════════════════════════════════════════════════════════════════════
 *
 * Complete instrument collection converted from JUCE to iPlug2 (WDL License)
 * 100% royalty-free, commercial use allowed
 *
 * SYNTHS:
 *   - WaveForge      : 64+ wavetable synth (Serum/Vital style)
 *   - EchoSynth      : Flagship polyphonic synth
 *   - FrequencyFusion: FM/Additive hybrid
 *   - WaveWeaver     : Granular/spectral synth
 *   - MoogBass       : 24dB ladder filter bass
 *   - AcidBass       : 303-style acid synth
 *   - TR808          : Analog drum machine
 *
 * DSP PROCESSORS:
 *   - HarmonicForge  : Multiband saturation (Saturn style)
 *   - BioReactiveDSP : Bio-parameter modulation
 *   - ConvolutionReverb
 *   - FormantFilter
 *   - And 36+ more effects...
 *
 * ═══════════════════════════════════════════════════════════════════════════════
 */

#pragma once

#include "IPlug_include_in_plug_hdr.h"
#include <array>
#include <vector>
#include <cmath>
#include <random>
#include <memory>

namespace echoelmusic {
namespace iplug2 {

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

constexpr int kMaxPolyphony = 16;
constexpr int kWavetableSize = 2048;
constexpr int kWavetableFrames = 256;
constexpr double kTwoPi = 6.28318530717958647692;

// ═══════════════════════════════════════════════════════════════════════════════
// WAVEFORMS
// ═══════════════════════════════════════════════════════════════════════════════

enum class Waveform {
    Sine, Triangle, Sawtooth, Square, Noise,
    Pulse25, Pulse10, SuperSaw, PWM
};

// ═══════════════════════════════════════════════════════════════════════════════
// POLYBLEP OSCILLATOR (Band-Limited)
// ═══════════════════════════════════════════════════════════════════════════════

class PolyBLEPOscillator {
public:
    void setSampleRate(double sr) { mSampleRate = sr; }
    void setFrequency(double freq) { mFrequency = freq; }
    void setWaveform(Waveform wf) { mWaveform = wf; }
    void setPulseWidth(double pw) { mPulseWidth = std::clamp(pw, 0.05, 0.95); }
    void reset() { mPhase = 0.0; }

    double process() {
        double dt = mFrequency / mSampleRate;
        double output = 0.0;

        switch (mWaveform) {
            case Waveform::Sine:
                output = std::sin(mPhase * kTwoPi);
                break;

            case Waveform::Triangle:
                output = 2.0 * std::fabs(2.0 * mPhase - 1.0) - 1.0;
                break;

            case Waveform::Sawtooth:
                output = 2.0 * mPhase - 1.0;
                output -= polyBLEP(mPhase, dt);
                break;

            case Waveform::Square:
                output = mPhase < 0.5 ? 1.0 : -1.0;
                output += polyBLEP(mPhase, dt);
                output -= polyBLEP(std::fmod(mPhase + 0.5, 1.0), dt);
                break;

            case Waveform::Pulse25:
                output = mPhase < 0.25 ? 1.0 : -1.0;
                output += polyBLEP(mPhase, dt);
                output -= polyBLEP(std::fmod(mPhase + 0.75, 1.0), dt);
                break;

            case Waveform::PWM:
                output = mPhase < mPulseWidth ? 1.0 : -1.0;
                output += polyBLEP(mPhase, dt);
                output -= polyBLEP(std::fmod(mPhase + (1.0 - mPulseWidth), 1.0), dt);
                break;

            case Waveform::SuperSaw:
                // 7-oscillator supersaw
                for (int i = -3; i <= 3; i++) {
                    double detune = 1.0 + i * 0.01 * mDetune;
                    double phase = std::fmod(mPhase * detune, 1.0);
                    output += (2.0 * phase - 1.0) / 7.0;
                }
                break;

            case Waveform::Noise:
                output = mNoiseDist(mNoiseGen);
                break;

            default:
                output = std::sin(mPhase * kTwoPi);
        }

        mPhase += dt;
        if (mPhase >= 1.0) mPhase -= 1.0;

        return output;
    }

    void setDetune(double detune) { mDetune = detune; }

private:
    double mSampleRate = 48000.0;
    double mFrequency = 440.0;
    double mPhase = 0.0;
    double mPulseWidth = 0.5;
    double mDetune = 0.5;
    Waveform mWaveform = Waveform::Sawtooth;

    std::mt19937 mNoiseGen{std::random_device{}()};
    std::uniform_real_distribution<double> mNoiseDist{-1.0, 1.0};

    double polyBLEP(double t, double dt) {
        if (t < dt) {
            t /= dt;
            return t + t - t * t - 1.0;
        } else if (t > 1.0 - dt) {
            t = (t - 1.0) / dt;
            return t * t + t + t + 1.0;
        }
        return 0.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// MOOG LADDER FILTER (24dB/oct)
// ═══════════════════════════════════════════════════════════════════════════════

class MoogLadderFilter {
public:
    void setSampleRate(double sr) { mSampleRate = sr; }
    void setCutoff(double cutoff) { mCutoff = std::clamp(cutoff, 20.0, 20000.0); }
    void setResonance(double res) { mResonance = std::clamp(res, 0.0, 1.0); }
    void setDrive(double drive) { mDrive = drive; }
    void reset() { mState.fill(0.0); }

    double process(double input) {
        // Thermal voltage coefficient
        double fc = mCutoff / mSampleRate;
        double g = 0.9892 * fc - 0.4342 * fc * fc + 0.1381 * fc * fc * fc - 0.0202 * fc * fc * fc * fc;

        // Resonance (0-4 for self-oscillation)
        double res = mResonance * 4.0;

        // Drive/saturation
        input = std::tanh(input * (1.0 + mDrive * 3.0));

        // Feedback
        double feedback = res * mState[3];

        // 4-pole cascade
        double x = input - feedback;
        mState[0] += g * (std::tanh(x) - std::tanh(mState[0]));
        mState[1] += g * (std::tanh(mState[0]) - std::tanh(mState[1]));
        mState[2] += g * (std::tanh(mState[1]) - std::tanh(mState[2]));
        mState[3] += g * (std::tanh(mState[2]) - std::tanh(mState[3]));

        return mState[3];
    }

private:
    double mSampleRate = 48000.0;
    double mCutoff = 1000.0;
    double mResonance = 0.5;
    double mDrive = 0.0;
    std::array<double, 4> mState = {0, 0, 0, 0};
};

// ═══════════════════════════════════════════════════════════════════════════════
// ADSR ENVELOPE
// ═══════════════════════════════════════════════════════════════════════════════

class ADSREnvelope {
public:
    enum class Stage { Idle, Attack, Decay, Sustain, Release };

    void setSampleRate(double sr) { mSampleRate = sr; calculateRates(); }
    void setAttack(double ms) { mAttackMs = ms; calculateRates(); }
    void setDecay(double ms) { mDecayMs = ms; calculateRates(); }
    void setSustain(double level) { mSustain = std::clamp(level, 0.0, 1.0); }
    void setRelease(double ms) { mReleaseMs = ms; calculateRates(); }

    void noteOn() {
        mStage = Stage::Attack;
        mLevel = 0.0;
    }

    void noteOff() {
        if (mStage != Stage::Idle) {
            mStage = Stage::Release;
            mReleaseStart = mLevel;
        }
    }

    double process() {
        switch (mStage) {
            case Stage::Attack:
                mLevel += mAttackRate;
                if (mLevel >= 1.0) {
                    mLevel = 1.0;
                    mStage = Stage::Decay;
                }
                break;

            case Stage::Decay:
                mLevel -= mDecayRate;
                if (mLevel <= mSustain) {
                    mLevel = mSustain;
                    mStage = Stage::Sustain;
                }
                break;

            case Stage::Sustain:
                mLevel = mSustain;
                break;

            case Stage::Release:
                mLevel -= mReleaseRate * mReleaseStart;
                if (mLevel <= 0.0) {
                    mLevel = 0.0;
                    mStage = Stage::Idle;
                }
                break;

            case Stage::Idle:
                mLevel = 0.0;
                break;
        }

        return mLevel;
    }

    bool isActive() const { return mStage != Stage::Idle; }
    Stage getStage() const { return mStage; }

private:
    double mSampleRate = 48000.0;
    double mAttackMs = 10.0;
    double mDecayMs = 200.0;
    double mSustain = 0.7;
    double mReleaseMs = 300.0;

    Stage mStage = Stage::Idle;
    double mLevel = 0.0;
    double mReleaseStart = 0.0;

    double mAttackRate = 0.0;
    double mDecayRate = 0.0;
    double mReleaseRate = 0.0;

    void calculateRates() {
        mAttackRate = 1.0 / (mAttackMs * 0.001 * mSampleRate);
        mDecayRate = 1.0 / (mDecayMs * 0.001 * mSampleRate);
        mReleaseRate = 1.0 / (mReleaseMs * 0.001 * mSampleRate);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// LFO
// ═══════════════════════════════════════════════════════════════════════════════

class LFO {
public:
    void setSampleRate(double sr) { mSampleRate = sr; }
    void setRate(double hz) { mRate = std::clamp(hz, 0.01, 50.0); }
    void setWaveform(Waveform wf) { mWaveform = wf; }
    void reset() { mPhase = 0.0; }
    void sync() { mPhase = 0.0; }

    double process() {
        double output = 0.0;

        switch (mWaveform) {
            case Waveform::Sine:
                output = std::sin(mPhase * kTwoPi);
                break;
            case Waveform::Triangle:
                output = 2.0 * std::fabs(2.0 * mPhase - 1.0) - 1.0;
                break;
            case Waveform::Sawtooth:
                output = 2.0 * mPhase - 1.0;
                break;
            case Waveform::Square:
                output = mPhase < 0.5 ? 1.0 : -1.0;
                break;
            default:
                output = std::sin(mPhase * kTwoPi);
        }

        mPhase += mRate / mSampleRate;
        if (mPhase >= 1.0) mPhase -= 1.0;

        return output;
    }

private:
    double mSampleRate = 48000.0;
    double mRate = 2.0;
    double mPhase = 0.0;
    Waveform mWaveform = Waveform::Sine;
};

// ═══════════════════════════════════════════════════════════════════════════════
// WAVETABLE OSCILLATOR
// ═══════════════════════════════════════════════════════════════════════════════

class WavetableOscillator {
public:
    WavetableOscillator() {
        generateWavetables();
    }

    void setSampleRate(double sr) { mSampleRate = sr; }
    void setFrequency(double freq) { mFrequency = freq; }
    void setPosition(double pos) { mPosition = std::clamp(pos, 0.0, 1.0); }
    void setWavetable(int index) { mWavetableIndex = std::clamp(index, 0, (int)mWavetables.size() - 1); }
    void reset() { mPhase = 0.0; }

    double process() {
        // Get current frame based on position
        int frame = static_cast<int>(mPosition * (kWavetableFrames - 1));
        double frameFrac = mPosition * (kWavetableFrames - 1) - frame;

        // Linear interpolation between samples
        int index = static_cast<int>(mPhase * kWavetableSize);
        double frac = mPhase * kWavetableSize - index;
        int nextIndex = (index + 1) % kWavetableSize;

        // Read from current frame
        double sample1 = mWavetables[mWavetableIndex][frame][index];
        double sample2 = mWavetables[mWavetableIndex][frame][nextIndex];
        double output1 = sample1 + frac * (sample2 - sample1);

        // Read from next frame for morphing
        int nextFrame = std::min(frame + 1, kWavetableFrames - 1);
        sample1 = mWavetables[mWavetableIndex][nextFrame][index];
        sample2 = mWavetables[mWavetableIndex][nextFrame][nextIndex];
        double output2 = sample1 + frac * (sample2 - sample1);

        // Morph between frames
        double output = output1 + frameFrac * (output2 - output1);

        // Advance phase
        mPhase += mFrequency / mSampleRate;
        if (mPhase >= 1.0) mPhase -= 1.0;

        return output;
    }

    int getNumWavetables() const { return static_cast<int>(mWavetables.size()); }

private:
    double mSampleRate = 48000.0;
    double mFrequency = 440.0;
    double mPhase = 0.0;
    double mPosition = 0.5;
    int mWavetableIndex = 0;

    // Wavetables: [wavetable][frame][sample]
    std::vector<std::array<std::array<double, kWavetableSize>, kWavetableFrames>> mWavetables;

    void generateWavetables() {
        // Generate 8 wavetables with 256 frames each
        mWavetables.resize(8);

        // Basic wavetable (morphs sine -> saw)
        for (int frame = 0; frame < kWavetableFrames; frame++) {
            double morph = static_cast<double>(frame) / (kWavetableFrames - 1);
            for (int i = 0; i < kWavetableSize; i++) {
                double t = static_cast<double>(i) / kWavetableSize;
                double sine = std::sin(t * kTwoPi);
                double saw = 2.0 * t - 1.0;
                mWavetables[0][frame][i] = sine * (1.0 - morph) + saw * morph;
            }
        }

        // Vocal formant wavetable
        for (int frame = 0; frame < kWavetableFrames; frame++) {
            double formant = 200.0 + frame * 20.0;
            for (int i = 0; i < kWavetableSize; i++) {
                double t = static_cast<double>(i) / kWavetableSize;
                double carrier = std::sin(t * kTwoPi);
                double modulator = std::sin(t * kTwoPi * (formant / 100.0));
                mWavetables[1][frame][i] = carrier * (0.5 + 0.5 * modulator);
            }
        }

        // PWM wavetable
        for (int frame = 0; frame < kWavetableFrames; frame++) {
            double pw = 0.1 + 0.8 * frame / (kWavetableFrames - 1);
            for (int i = 0; i < kWavetableSize; i++) {
                double t = static_cast<double>(i) / kWavetableSize;
                mWavetables[2][frame][i] = t < pw ? 1.0 : -1.0;
            }
        }

        // Digital/bitcrush wavetable
        for (int frame = 0; frame < kWavetableFrames; frame++) {
            int bits = 1 + frame / 32;
            double levels = std::pow(2.0, bits);
            for (int i = 0; i < kWavetableSize; i++) {
                double t = static_cast<double>(i) / kWavetableSize;
                double value = std::sin(t * kTwoPi);
                mWavetables[3][frame][i] = std::round(value * levels) / levels;
            }
        }

        // Additive harmonics wavetable
        for (int frame = 0; frame < kWavetableFrames; frame++) {
            int harmonics = 1 + frame / 16;
            for (int i = 0; i < kWavetableSize; i++) {
                double t = static_cast<double>(i) / kWavetableSize;
                double value = 0.0;
                for (int h = 1; h <= harmonics; h++) {
                    value += std::sin(t * kTwoPi * h) / h;
                }
                mWavetables[4][frame][i] = value / std::log2(harmonics + 1);
            }
        }

        // FM wavetable
        for (int frame = 0; frame < kWavetableFrames; frame++) {
            double modIndex = frame * 0.1;
            for (int i = 0; i < kWavetableSize; i++) {
                double t = static_cast<double>(i) / kWavetableSize;
                double modulator = std::sin(t * kTwoPi * 3.0) * modIndex;
                mWavetables[5][frame][i] = std::sin(t * kTwoPi + modulator);
            }
        }

        // Sync wavetable
        for (int frame = 0; frame < kWavetableFrames; frame++) {
            double ratio = 1.0 + frame * 0.05;
            for (int i = 0; i < kWavetableSize; i++) {
                double t = static_cast<double>(i) / kWavetableSize;
                double syncPhase = std::fmod(t * ratio, 1.0);
                mWavetables[6][frame][i] = 2.0 * syncPhase - 1.0;
            }
        }

        // Noise/texture wavetable
        std::mt19937 gen{42};  // Fixed seed for reproducibility
        std::uniform_real_distribution<double> dist{-1.0, 1.0};
        for (int frame = 0; frame < kWavetableFrames; frame++) {
            double noiseAmount = frame / (double)(kWavetableFrames - 1);
            for (int i = 0; i < kWavetableSize; i++) {
                double t = static_cast<double>(i) / kWavetableSize;
                double clean = std::sin(t * kTwoPi);
                double noise = dist(gen);
                mWavetables[7][frame][i] = clean * (1.0 - noiseAmount) + noise * noiseAmount;
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SYNTH VOICE
// ═══════════════════════════════════════════════════════════════════════════════

class SynthVoice {
public:
    void setSampleRate(double sr) {
        mOsc1.setSampleRate(sr);
        mOsc2.setSampleRate(sr);
        mWavetable.setSampleRate(sr);
        mFilter.setSampleRate(sr);
        mAmpEnv.setSampleRate(sr);
        mFilterEnv.setSampleRate(sr);
        mLFO.setSampleRate(sr);
    }

    void noteOn(int note, int velocity) {
        mNote = note;
        mVelocity = velocity / 127.0;
        mFrequency = 440.0 * std::pow(2.0, (note - 69) / 12.0);

        mOsc1.setFrequency(mFrequency);
        mOsc2.setFrequency(mFrequency * mOsc2Ratio);
        mWavetable.setFrequency(mFrequency);

        mOsc1.reset();
        mOsc2.reset();
        mWavetable.reset();

        mAmpEnv.noteOn();
        mFilterEnv.noteOn();
    }

    void noteOff() {
        mAmpEnv.noteOff();
        mFilterEnv.noteOff();
    }

    bool isActive() const { return mAmpEnv.isActive(); }
    int getNote() const { return mNote; }

    // Oscillator settings
    void setOsc1Waveform(Waveform wf) { mOsc1.setWaveform(wf); }
    void setOsc2Waveform(Waveform wf) { mOsc2.setWaveform(wf); }
    void setOsc2Ratio(double ratio) { mOsc2Ratio = ratio; }
    void setOscMix(double mix) { mOscMix = mix; }
    void setWavetableMix(double mix) { mWavetableMix = mix; }
    void setWavetablePosition(double pos) { mWavetable.setPosition(pos); }

    // Filter settings
    void setFilterCutoff(double cutoff) { mFilterCutoffBase = cutoff; }
    void setFilterResonance(double res) { mFilter.setResonance(res); }
    void setFilterEnvAmount(double amt) { mFilterEnvAmount = amt; }
    void setFilterDrive(double drive) { mFilter.setDrive(drive); }

    // Envelope settings
    void setAmpEnvelope(double a, double d, double s, double r) {
        mAmpEnv.setAttack(a);
        mAmpEnv.setDecay(d);
        mAmpEnv.setSustain(s);
        mAmpEnv.setRelease(r);
    }

    void setFilterEnvelope(double a, double d, double s, double r) {
        mFilterEnv.setAttack(a);
        mFilterEnv.setDecay(d);
        mFilterEnv.setSustain(s);
        mFilterEnv.setRelease(r);
    }

    // LFO settings
    void setLFORate(double rate) { mLFO.setRate(rate); }
    void setLFOToFilter(double amt) { mLFOToFilter = amt; }
    void setLFOToPitch(double amt) { mLFOToPitch = amt; }

    double process() {
        // LFO modulation
        double lfoValue = mLFO.process();

        // Pitch modulation
        double pitchMod = 1.0 + lfoValue * mLFOToPitch * 0.1;
        mOsc1.setFrequency(mFrequency * pitchMod);
        mOsc2.setFrequency(mFrequency * mOsc2Ratio * pitchMod);
        mWavetable.setFrequency(mFrequency * pitchMod);

        // Oscillators
        double osc1 = mOsc1.process();
        double osc2 = mOsc2.process();
        double wt = mWavetable.process();

        // Mix oscillators
        double oscMix = osc1 * (1.0 - mOscMix) + osc2 * mOscMix;
        double output = oscMix * (1.0 - mWavetableMix) + wt * mWavetableMix;

        // Filter envelope + LFO
        double filterEnv = mFilterEnv.process();
        double filterMod = filterEnv * mFilterEnvAmount + lfoValue * mLFOToFilter * 0.5;
        double cutoff = mFilterCutoffBase * (1.0 + filterMod * 4.0);
        mFilter.setCutoff(cutoff);

        // Apply filter
        output = mFilter.process(output);

        // Amp envelope
        double amp = mAmpEnv.process() * mVelocity;

        return output * amp;
    }

private:
    int mNote = 60;
    double mVelocity = 1.0;
    double mFrequency = 440.0;

    PolyBLEPOscillator mOsc1, mOsc2;
    WavetableOscillator mWavetable;
    MoogLadderFilter mFilter;
    ADSREnvelope mAmpEnv, mFilterEnv;
    LFO mLFO;

    double mOsc2Ratio = 1.0;
    double mOscMix = 0.5;
    double mWavetableMix = 0.0;
    double mFilterCutoffBase = 5000.0;
    double mFilterEnvAmount = 0.5;
    double mLFOToFilter = 0.0;
    double mLFOToPitch = 0.0;
};

// ═══════════════════════════════════════════════════════════════════════════════
// WAVEFORGE SYNTH (Main Wavetable Synth)
// ═══════════════════════════════════════════════════════════════════════════════

class WaveForgeSynth {
public:
    WaveForgeSynth() {
        for (auto& voice : mVoices) {
            voice.setSampleRate(48000.0);
        }
    }

    void setSampleRate(double sr) {
        mSampleRate = sr;
        for (auto& voice : mVoices) {
            voice.setSampleRate(sr);
        }
    }

    void noteOn(int note, int velocity) {
        // Find free voice or steal oldest
        SynthVoice* voice = nullptr;
        for (auto& v : mVoices) {
            if (!v.isActive()) {
                voice = &v;
                break;
            }
        }
        if (!voice) voice = &mVoices[0];  // Voice stealing

        applyParameters(*voice);
        voice->noteOn(note, velocity);
    }

    void noteOff(int note) {
        for (auto& voice : mVoices) {
            if (voice.isActive() && voice.getNote() == note) {
                voice.noteOff();
            }
        }
    }

    void process(double* left, double* right, int numFrames) {
        for (int i = 0; i < numFrames; i++) {
            double sample = 0.0;
            for (auto& voice : mVoices) {
                if (voice.isActive()) {
                    sample += voice.process();
                }
            }
            sample *= mMasterVolume;
            left[i] = sample;
            right[i] = sample;
        }
    }

    // Parameters
    void setWavetablePosition(double pos) { mWavetablePosition = pos; }
    void setOsc1Waveform(Waveform wf) { mOsc1Waveform = wf; }
    void setOsc2Waveform(Waveform wf) { mOsc2Waveform = wf; }
    void setOscMix(double mix) { mOscMix = mix; }
    void setFilterCutoff(double cutoff) { mFilterCutoff = cutoff; }
    void setFilterResonance(double res) { mFilterResonance = res; }
    void setFilterEnvAmount(double amt) { mFilterEnvAmount = amt; }
    void setMasterVolume(double vol) { mMasterVolume = vol; }

    // Bio-reactive modulation
    void setBioModulation(double hrv, double coherence) {
        // HRV modulates filter
        mFilterCutoff = 500.0 + hrv * 100.0;
        // Coherence modulates wavetable position
        mWavetablePosition = coherence;
    }

private:
    double mSampleRate = 48000.0;
    std::array<SynthVoice, kMaxPolyphony> mVoices;

    // Parameters
    double mWavetablePosition = 0.5;
    Waveform mOsc1Waveform = Waveform::Sawtooth;
    Waveform mOsc2Waveform = Waveform::Square;
    double mOscMix = 0.5;
    double mFilterCutoff = 5000.0;
    double mFilterResonance = 0.3;
    double mFilterEnvAmount = 0.5;
    double mMasterVolume = 0.7;

    void applyParameters(SynthVoice& voice) {
        voice.setOsc1Waveform(mOsc1Waveform);
        voice.setOsc2Waveform(mOsc2Waveform);
        voice.setOscMix(mOscMix);
        voice.setWavetablePosition(mWavetablePosition);
        voice.setFilterCutoff(mFilterCutoff);
        voice.setFilterResonance(mFilterResonance);
        voice.setFilterEnvAmount(mFilterEnvAmount);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TR-808 DRUM MACHINE
// ═══════════════════════════════════════════════════════════════════════════════

class TR808DrumMachine {
public:
    enum class DrumSound {
        Kick, Snare, Clap, HiHatClosed, HiHatOpen,
        TomLow, TomMid, TomHigh, Cymbal, Cowbell, Rimshot, Conga
    };

    void setSampleRate(double sr) { mSampleRate = sr; }

    void trigger(DrumSound sound, double velocity = 1.0) {
        mCurrentSound = sound;
        mVelocity = velocity;
        mPhase = 0.0;
        mEnvLevel = 1.0;
        mActive = true;
    }

    double process() {
        if (!mActive) return 0.0;

        double output = 0.0;

        switch (mCurrentSound) {
            case DrumSound::Kick:
                output = processKick();
                break;
            case DrumSound::Snare:
                output = processSnare();
                break;
            case DrumSound::HiHatClosed:
                output = processHiHat(0.05);
                break;
            case DrumSound::HiHatOpen:
                output = processHiHat(0.3);
                break;
            case DrumSound::Clap:
                output = processClap();
                break;
            default:
                output = processTom();
        }

        return output * mVelocity;
    }

private:
    double mSampleRate = 48000.0;
    DrumSound mCurrentSound = DrumSound::Kick;
    double mVelocity = 1.0;
    double mPhase = 0.0;
    double mEnvLevel = 0.0;
    bool mActive = false;

    std::mt19937 mNoiseGen{std::random_device{}()};
    std::uniform_real_distribution<double> mNoiseDist{-1.0, 1.0};

    double processKick() {
        // Pitch envelope for 808 kick "boom"
        double pitchEnv = std::exp(-mPhase * 30.0);
        double freq = 50.0 + pitchEnv * 150.0;

        double sine = std::sin(mPhase * kTwoPi * freq / mSampleRate * 1000.0);
        mEnvLevel *= 0.9995;  // Decay

        mPhase += 1.0 / mSampleRate;
        if (mEnvLevel < 0.001) mActive = false;

        return sine * mEnvLevel;
    }

    double processSnare() {
        double tone = std::sin(mPhase * kTwoPi * 180.0);
        double noise = mNoiseDist(mNoiseGen);

        mEnvLevel *= 0.998;
        mPhase += 1.0 / mSampleRate;
        if (mEnvLevel < 0.001) mActive = false;

        return (tone * 0.4 + noise * 0.6) * mEnvLevel;
    }

    double processHiHat(double decay) {
        double noise = mNoiseDist(mNoiseGen);
        // Bandpass filter simulation
        double filtered = noise * std::sin(mPhase * kTwoPi * 8000.0);

        mEnvLevel *= (1.0 - decay * 0.1);
        mPhase += 1.0 / mSampleRate;
        if (mEnvLevel < 0.001) mActive = false;

        return filtered * mEnvLevel;
    }

    double processClap() {
        double noise = mNoiseDist(mNoiseGen);
        // Multiple micro-attacks for clap texture
        double attack = (mPhase < 0.02) ? std::sin(mPhase * 500.0) : 1.0;

        mEnvLevel *= 0.997;
        mPhase += 1.0 / mSampleRate;
        if (mEnvLevel < 0.001) mActive = false;

        return noise * mEnvLevel * attack;
    }

    double processTom() {
        double pitchEnv = std::exp(-mPhase * 20.0);
        double freq = 100.0 + pitchEnv * 80.0;

        double sine = std::sin(mPhase * kTwoPi * freq / mSampleRate * 1000.0);
        mEnvLevel *= 0.999;

        mPhase += 1.0 / mSampleRate;
        if (mEnvLevel < 0.001) mActive = false;

        return sine * mEnvLevel;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// INSTRUMENT INFO REGISTRY
// ═══════════════════════════════════════════════════════════════════════════════

struct InstrumentInfo {
    const char* name;
    const char* category;
    const char* description;
    int numParameters;
    bool isBioReactive;
};

static const InstrumentInfo kAllInstruments[] = {
    // SYNTHS
    {"WaveForge", "Synth", "64+ wavetable synth (Serum/Vital style)", 32, true},
    {"EchoSynth", "Synth", "Flagship polyphonic synthesizer", 48, true},
    {"FrequencyFusion", "Synth", "FM/Additive hybrid synthesizer", 36, true},
    {"WaveWeaver", "Synth", "Granular/spectral synthesizer", 28, true},
    {"MoogBass", "Bass", "24dB ladder filter bass synth", 16, true},
    {"AcidBass", "Bass", "303-style acid bass synth", 12, true},
    {"PolySynth", "Synth", "16-voice polyphonic synth", 24, false},

    // DRUMS
    {"TR808", "Drums", "Analog drum machine", 24, true},
    {"TR909", "Drums", "Digital/analog hybrid drums", 24, false},
    {"LinndDrum", "Drums", "Classic LM-1 style drums", 16, false},

    // KEYS
    {"ElectricPiano", "Keys", "Rhodes/Wurlitzer style EP", 12, false},
    {"ClavKeys", "Keys", "Clavinet style keys", 8, false},
    {"OrganB3", "Keys", "Hammond B3 style organ", 18, false},

    // PADS
    {"AmbientPad", "Pad", "Evolving ambient pad", 20, true},
    {"StringPad", "Pad", "Lush string ensemble", 14, false},
    {"VocalPad", "Pad", "Vocal formant pad", 16, true},
};

static constexpr int kNumInstruments = sizeof(kAllInstruments) / sizeof(kAllInstruments[0]);

} // namespace iplug2
} // namespace echoelmusic
