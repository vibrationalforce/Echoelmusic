#include "TR808Engine.h"
#include <algorithm>

namespace echoelmusic {

constexpr float kPi = 3.14159265358979323846f;
constexpr float kTwoPi = 6.28318530717958647692f;

TR808Engine::TR808Engine() {
    updateGlideCoeff();
}

void TR808Engine::setSampleRate(float sr) {
    mSampleRate = sr;
    updateGlideCoeff();
}

void TR808Engine::updateGlideCoeff() {
    // Exponential glide coefficient
    if (mGlideTime > 0.001f) {
        mGlideCoeff = std::exp(-1.0f / (mGlideTime * mSampleRate));
    } else {
        mGlideCoeff = 0.0f;
    }

    // Click decay (very fast - ~5ms)
    mClickDecayRate = std::exp(-1.0f / (0.005f * mSampleRate));
}

void TR808Engine::trigger(int note, int velocity) {
    mVelocity = velocity / 127.0f;
    mTargetFrequency = 440.0f * std::pow(2.0f, (note - 69) / 12.0f);

    // Start with glide from higher/lower pitch
    float glideRatio = std::pow(2.0f, mGlideRange / 12.0f);
    mFrequency = mTargetFrequency / glideRatio;

    // Reset envelope
    mEnvLevel = 1.0f;
    mEnvDecayRate = std::exp(-1.0f / (mDecay * mSampleRate));

    // Reset click
    mClickLevel = mClickAmount;

    // Reset phase for consistent attack
    mPhase = 0.0f;

    mActive = true;
}

float TR808Engine::processSine(float freq) {
    float dt = freq / mSampleRate;
    float sample = std::sin(mPhase * kTwoPi);

    mPhase += dt;
    if (mPhase >= 1.0f) mPhase -= 1.0f;

    return sample;
}

float TR808Engine::applyDrive(float sample) {
    if (mDrive < 0.01f) return sample;

    // Soft clipping with drive amount
    float driveGain = 1.0f + mDrive * 5.0f;
    sample *= driveGain;

    // Hyperbolic tangent saturation
    sample = std::tanh(sample);

    return sample;
}

float TR808Engine::applyFilter(float sample) {
    // Simple one-pole lowpass
    float cutoffNorm = mFilterCutoff / mSampleRate;
    cutoffNorm = std::clamp(cutoffNorm, 0.0001f, 0.45f);
    float coeff = 1.0f - std::exp(-kTwoPi * cutoffNorm);

    mFilterState += coeff * (sample - mFilterState);

    // Flush denormals
    if (std::abs(mFilterState) < 1e-15f) mFilterState = 0.0f;

    return mFilterState;
}

void TR808Engine::process(float* output, int numFrames) {
    if (!mActive) {
        // Clear buffer
        for (int i = 0; i < numFrames * 2; i++) {
            output[i] = 0.0f;
        }
        return;
    }

    for (int frame = 0; frame < numFrames; frame++) {
        // Pitch glide
        mFrequency = mGlideCoeff * mFrequency + (1.0f - mGlideCoeff) * mTargetFrequency;

        // Generate sine
        float sample = processSine(mFrequency);

        // Add harmonics based on tone
        if (mTone > 0.1f) {
            float harmonic2 = processSine(mFrequency * 2.0f) * mTone * 0.3f;
            float harmonic3 = processSine(mFrequency * 3.0f) * mTone * 0.1f;
            sample += harmonic2 + harmonic3;
        }

        // Apply envelope
        sample *= mEnvLevel;
        mEnvLevel *= mEnvDecayRate;

        // Add click transient
        if (mClickLevel > 0.001f) {
            // Click is white noise burst
            float click = (static_cast<float>(rand()) / RAND_MAX * 2.0f - 1.0f);
            click *= mClickLevel;
            sample += click;
            mClickLevel *= mClickDecayRate;
        }

        // Apply drive/saturation
        sample = applyDrive(sample);

        // Apply lowpass filter
        sample = applyFilter(sample);

        // Apply velocity
        sample *= mVelocity;

        // Check if envelope has decayed
        if (mEnvLevel < 0.0001f) {
            mActive = false;
        }

        // Stereo output
        output[frame * 2] = sample;
        output[frame * 2 + 1] = sample;
    }
}

void TR808Engine::setParameter(int paramId, float value) {
    switch (paramId) {
        case PARAM_DECAY:
            mDecay = std::clamp(value, 0.1f, 5.0f);
            break;
        case PARAM_TONE:
            mTone = std::clamp(value, 0.0f, 1.0f);
            break;
        case PARAM_DRIVE:
            mDrive = std::clamp(value, 0.0f, 1.0f);
            break;
        case PARAM_GLIDE_TIME:
            mGlideTime = std::clamp(value, 0.0f, 0.5f);
            updateGlideCoeff();
            break;
        case PARAM_GLIDE_RANGE:
            mGlideRange = std::clamp(value, -24.0f, 0.0f);
            break;
    }
}

float TR808Engine::getParameter(int paramId) const {
    switch (paramId) {
        case PARAM_DECAY: return mDecay;
        case PARAM_TONE: return mTone;
        case PARAM_DRIVE: return mDrive;
        case PARAM_GLIDE_TIME: return mGlideTime;
        case PARAM_GLIDE_RANGE: return mGlideRange;
        default: return 0.0f;
    }
}

void TR808Engine::setDecayDirect(float decay) {
    mDecay = std::clamp(decay, 0.1f, 5.0f);
    mEnvDecayRate = std::exp(-1.0f / (mDecay * mSampleRate));
}

} // namespace echoelmusic
