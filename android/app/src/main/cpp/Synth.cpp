#include "Synth.h"
#include <algorithm>

namespace echoelmusic {

// ==== Oscillator ====

float Oscillator::polyBLEP(float t, float dt) {
    if (t < dt) {
        t /= dt;
        return t + t - t * t - 1.0f;
    } else if (t > 1.0f - dt) {
        t = (t - 1.0f) / dt;
        return t * t + t + t + 1.0f;
    }
    return 0.0f;
}

float Oscillator::process() {
    float dt = mFrequency / mSampleRate;
    float output = 0.0f;

    switch (mWaveform) {
        case Waveform::Sine:
            output = std::sin(mPhase * kTwoPi);
            break;

        case Waveform::Triangle:
            output = mPhase < 0.5f ? (4.0f * mPhase - 1.0f) : (3.0f - 4.0f * mPhase);
            break;

        case Waveform::Sawtooth:
            output = 2.0f * mPhase - 1.0f;
            output -= polyBLEP(mPhase, dt);
            break;

        case Waveform::Square:
            output = mPhase < 0.5f ? 1.0f : -1.0f;
            output += polyBLEP(mPhase, dt);
            output -= polyBLEP(std::fmod(mPhase + 0.5f, 1.0f), dt);
            break;

        case Waveform::Noise:
            output = mNoiseDist(mNoiseGen);
            break;
    }

    mPhase += dt;
    if (mPhase >= 1.0f) mPhase -= 1.0f;

    return output;
}

// ==== MoogFilter ====

float MoogFilter::process(float input) {
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
    for (auto& s : mState) {
        if (std::abs(s) < 1e-15f) s = 0.0f;
    }

    return mState[3];
}

// ==== Envelope ====

void Envelope::noteOn() {
    mStage = Stage::Attack;
    mAttackInc = 1.0f / (mAttack * mSampleRate * 0.001f);
}

void Envelope::noteOff() {
    if (mStage != Stage::Idle) {
        mStage = Stage::Release;
        mReleaseInc = mLevel / (mRelease * mSampleRate * 0.001f);
    }
}

float Envelope::process() {
    switch (mStage) {
        case Stage::Idle:
            mLevel = 0.0f;
            break;

        case Stage::Attack:
            mLevel += mAttackInc;
            if (mLevel >= 1.0f) {
                mLevel = 1.0f;
                mStage = Stage::Decay;
                mDecayInc = (1.0f - mSustain) / (mDecay * mSampleRate * 0.001f);
            }
            break;

        case Stage::Decay:
            mLevel -= mDecayInc;
            if (mLevel <= mSustain) {
                mLevel = mSustain;
                mStage = Stage::Sustain;
            }
            break;

        case Stage::Sustain:
            mLevel = mSustain;
            break;

        case Stage::Release:
            mLevel -= mReleaseInc;
            if (mLevel <= 0.0f) {
                mLevel = 0.0f;
                mStage = Stage::Idle;
            }
            break;
    }

    return mLevel;
}

// ==== LFO ====

float LFO::process() {
    float output = 0.0f;
    float dt = mRate / mSampleRate;

    switch (mWaveform) {
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

// ==== Voice ====

void Voice::setSampleRate(float sr) {
    mOsc1.setSampleRate(sr);
    mOsc2.setSampleRate(sr);
    mFilter.setSampleRate(sr);
    mAmpEnv.setSampleRate(sr);
    mFilterEnv.setSampleRate(sr);
}

void Voice::noteOn(int note, int velocity) {
    mNote = note;
    mVelocity = velocity / 127.0f;
    mFrequency = 440.0f * std::pow(2.0f, (note - 69) / 12.0f);

    mOsc1.setFrequency(mFrequency);
    mOsc2.setFrequency(mFrequency);
    mOsc1.reset();
    mOsc2.reset();

    mAmpEnv.noteOn();
    mFilterEnv.noteOn();
}

void Voice::noteOff() {
    mAmpEnv.noteOff();
    mFilterEnv.noteOff();
}

void Voice::setAmpEnvelope(float a, float d, float s, float r) {
    mAmpEnv.setAttack(a);
    mAmpEnv.setDecay(d);
    mAmpEnv.setSustain(s);
    mAmpEnv.setRelease(r);
}

void Voice::setFilterEnvelope(float a, float d, float s, float r) {
    mFilterEnv.setAttack(a);
    mFilterEnv.setDecay(d);
    mFilterEnv.setSustain(s);
    mFilterEnv.setRelease(r);
}

float Voice::process() {
    if (!isActive()) return 0.0f;

    // Mix oscillators
    float osc1 = mOsc1.process();
    float osc2 = mOsc2.process();
    float mixed = osc1 * (1.0f - mOsc2Mix) + osc2 * mOsc2Mix;

    // Filter with envelope modulation
    float filterEnvLevel = mFilterEnv.process();
    float modCutoff = mFilterCutoff + mFilterEnvAmount * filterEnvLevel * 10000.0f;
    mFilter.setCutoff(std::clamp(modCutoff, 20.0f, 20000.0f));
    float filtered = mFilter.process(mixed);

    // Amp envelope
    float ampLevel = mAmpEnv.process();
    return filtered * ampLevel * mVelocity;
}

// ==== Synth ====

Synth::Synth() {
    for (auto& voice : mVoices) {
        voice.setSampleRate(mSampleRate);
    }
    mLFO.setSampleRate(mSampleRate);
}

void Synth::setSampleRate(float sr) {
    mSampleRate = sr;
    for (auto& voice : mVoices) {
        voice.setSampleRate(sr);
    }
    mLFO.setSampleRate(sr);
}

void Synth::noteOn(int note, int velocity) {
    // Find free voice or steal oldest
    int voiceIdx = -1;
    for (int i = 0; i < kMaxVoices; i++) {
        if (!mVoices[i].isActive()) {
            voiceIdx = i;
            break;
        }
    }

    if (voiceIdx < 0) {
        // Voice stealing - use voice 0
        voiceIdx = 0;
    }

    updateVoiceParameters(mVoices[voiceIdx]);
    mVoices[voiceIdx].noteOn(note, velocity);
}

void Synth::noteOff(int note) {
    for (auto& voice : mVoices) {
        if (voice.isActive() && voice.getNote() == note) {
            voice.noteOff();
        }
    }
}

void Synth::updateVoiceParameters(Voice& voice) {
    voice.setOsc1Waveform(static_cast<Waveform>(static_cast<int>(mOsc1Waveform)));
    voice.setOsc2Waveform(static_cast<Waveform>(static_cast<int>(mOsc2Waveform)));
    voice.setOsc2Mix(mOsc2Mix);
    voice.setFilterCutoff(mFilterCutoff);
    voice.setFilterResonance(mFilterResonance);
    voice.setFilterEnvAmount(mFilterEnvAmount);
    voice.setAmpEnvelope(mAmpAttack, mAmpDecay, mAmpSustain, mAmpRelease);
}

void Synth::process(float* output, int numFrames) {
    float lfoValue = 0.0f;

    for (int frame = 0; frame < numFrames; frame++) {
        lfoValue = mLFO.process();
        float sample = 0.0f;

        // Sum all voices
        for (auto& voice : mVoices) {
            if (voice.isActive()) {
                // Apply LFO to filter
                float lfoMod = lfoValue * mLFOToFilter * 2000.0f;
                voice.setFilterCutoff(mFilterCutoff + lfoMod);
                sample += voice.process();
            }
        }

        // Stereo output (mono source, could add stereo width later)
        output[frame * 2] = sample;
        output[frame * 2 + 1] = sample;
    }
}

void Synth::setParameter(int paramId, float value) {
    switch (paramId) {
        case 0: mOsc1Waveform = value; break;
        case 1: /* octave */ break;
        case 2: mOsc2Waveform = value; break;
        case 3: mOsc2Mix = value; break;
        case 10: mFilterCutoff = value; break;
        case 11: mFilterResonance = value; break;
        case 12: mFilterEnvAmount = value; break;
        case 20: mAmpAttack = value; break;
        case 21: mAmpDecay = value; break;
        case 22: mAmpSustain = value; break;
        case 23: mAmpRelease = value; break;
        case 30: mLFORate = value; mLFO.setRate(value); break;
        case 31: mLFODepth = value; break;
        case 32: mLFOToFilter = value; break;
    }
}

float Synth::getParameter(int paramId) const {
    switch (paramId) {
        case 10: return mFilterCutoff;
        case 30: return mLFORate;
        default: return 0.0f;
    }
}

void Synth::setFilterCutoffDirect(float cutoff) {
    mFilterCutoff = cutoff;
    for (auto& voice : mVoices) {
        if (voice.isActive()) {
            voice.setFilterCutoff(cutoff);
        }
    }
}

void Synth::setLFORateDirect(float rate) {
    mLFORate = rate;
    mLFO.setRate(rate);
}

} // namespace echoelmusic
