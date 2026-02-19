#pragma once

/**
 * EchoelBeat Bass Engine for Android
 * Authentic 808-style bass with pitch glide
 */

#include <cmath>
#include <array>

namespace echoelmusic {

class TR808Engine {
public:
    TR808Engine();

    void setSampleRate(float sr);
    void trigger(int note, int velocity);
    void process(float* output, int numFrames);

    void setParameter(int paramId, float value);
    float getParameter(int paramId) const;
    void setDecayDirect(float decay);

    // Parameter IDs
    static constexpr int PARAM_DECAY = 0;
    static constexpr int PARAM_TONE = 1;
    static constexpr int PARAM_DRIVE = 2;
    static constexpr int PARAM_GLIDE_TIME = 3;
    static constexpr int PARAM_GLIDE_RANGE = 4;

private:
    float mSampleRate = 48000.0f;

    // Voice state
    bool mActive = false;
    float mPhase = 0.0f;
    float mFrequency = 60.0f;
    float mTargetFrequency = 60.0f;
    float mVelocity = 1.0f;

    // Envelope
    float mEnvLevel = 0.0f;
    float mEnvDecayRate = 0.0f;

    // Click envelope (attack transient)
    float mClickLevel = 0.0f;
    float mClickDecayRate = 0.0f;

    // Parameters
    float mDecay = 1.5f;        // seconds
    float mTone = 0.5f;         // 0-1, affects harmonic content
    float mDrive = 0.2f;        // 0-1, saturation
    float mGlideTime = 0.08f;   // seconds
    float mGlideRange = -12.0f; // semitones (negative = pitch drops)

    // Filter state
    float mFilterState = 0.0f;
    float mFilterCutoff = 200.0f;

    // Internal
    float mGlideCoeff = 0.0f;
    float mClickAmount = 0.3f;

    // Thread-safe noise generator (replaces unsafe rand())
    uint32_t mNoiseState = 12345;  // Fast LCG seed

    void updateGlideCoeff();

    // Fast thread-safe noise (-1 to +1)
    inline float generateNoise() {
        mNoiseState = mNoiseState * 1664525u + 1013904223u;  // LCG
        return static_cast<float>(static_cast<int32_t>(mNoiseState)) / 2147483648.0f;
    }
    float processSine(float freq);
    float applyDrive(float sample);
    float applyFilter(float sample);
};

} // namespace echoelmusic
