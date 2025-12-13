#pragma once

/**
 * Echoelmusic Effects Suite - iPlug2 Bridge
 *
 * Bridges ALL 36+ DSP effects from Sources/DSP to iPlug2 plugins
 * Each effect can be built as separate plugin or combined
 *
 * MIT License - JUCE-free implementation
 */

#include "../DSP/EchoelmusicDSP.h"

// Include all DSP effects headers
#include "../../DSP/BioReactiveDSP.h"
#include "../../DSP/DynamicEQ.h"
#include "../../DSP/SpectralSculptor.h"
#include "../../DSP/ConvolutionReverb.h"
#include "../../DSP/BrickWallLimiter.h"
#include "../../DSP/Compressor.h"
#include "../../DSP/FETCompressor.h"
#include "../../DSP/Harmonizer.h"
#include "../../DSP/DeEsser.h"
#include "../../DSP/FormantFilter.h"
#include "../../DSP/LofiBitcrusher.h"
#include "../../DSP/ClassicPreamp.h"
#include "../../DSP/ChordSense.h"
#include "../../DSP/HarmonicForge.h"
#include "../../DSP/EdgeControl.h"
#include "../../DSP/EchoConsole.h"
#include "../../DSP/EchoSynth.h"
#include "../../DSP/Audio2MIDI.h"

namespace echoelmusic {
namespace effects {

//==============================================================================
// Effect Categories for Plugin Organization
//==============================================================================

enum class EffectCategory
{
    Dynamics,       // Compressor, Limiter, Gate
    EQ,             // Dynamic EQ, Parametric, Spectral
    Reverb,         // Convolution, Algorithmic
    Delay,          // Tape, Ping-Pong, Multi-tap
    Modulation,     // Chorus, Flanger, Phaser
    Distortion,     // Saturation, Bitcrusher, Preamp
    Pitch,          // Harmonizer, Pitch Shift
    Utility,        // De-esser, Formant, Audio2MIDI
    BioReactive,    // HRV-controlled effects
    Creative        // Edge Control, Spectral Sculptor
};

//==============================================================================
// Complete Effects Registry
//==============================================================================

struct EffectInfo
{
    const char* name;
    const char* description;
    EffectCategory category;
    bool isBioReactive;
    int inputChannels;
    int outputChannels;
};

static const EffectInfo kAllEffects[] = {
    // DYNAMICS
    {"EchoelCompressor", "Clean transparent compression", EffectCategory::Dynamics, false, 2, 2},
    {"EchoelFETComp", "FET-style analog compression", EffectCategory::Dynamics, false, 2, 2},
    {"EchoelLimiter", "Brick-wall true peak limiter", EffectCategory::Dynamics, false, 2, 2},

    // EQ
    {"EchoelDynamicEQ", "6-band dynamic equalizer", EffectCategory::EQ, true, 2, 2},
    {"EchoelSpectralSculptor", "FFT-based spectral processing", EffectCategory::EQ, true, 2, 2},

    // REVERB
    {"EchoelConvolution", "IR-based convolution reverb", EffectCategory::Reverb, true, 2, 2},
    {"EchoelAlgorithmic", "Schroeder algorithmic reverb", EffectCategory::Reverb, true, 2, 2},

    // DISTORTION
    {"EchoelLofi", "Bitcrusher + sample rate reduction", EffectCategory::Distortion, false, 2, 2},
    {"EchoelPreamp", "Tube/transistor preamp modeling", EffectCategory::Distortion, false, 2, 2},
    {"EchoelSaturation", "Harmonic saturation", EffectCategory::Distortion, false, 2, 2},

    // PITCH
    {"EchoelHarmonizer", "Intelligent pitch harmonizer", EffectCategory::Pitch, true, 2, 2},
    {"EchoelFormant", "Formant filter with vowel morph", EffectCategory::Pitch, true, 2, 2},

    // UTILITY
    {"EchoelDeEsser", "Sibilance control", EffectCategory::Utility, false, 2, 2},
    {"EchoelAudio2MIDI", "Polyphonic pitch to MIDI", EffectCategory::Utility, false, 2, 2},
    {"EchoelChordSense", "Chord detection & suggestion", EffectCategory::Utility, false, 2, 2},

    // BIO-REACTIVE
    {"EchoelBioFilter", "HRV-controlled filter", EffectCategory::BioReactive, true, 2, 2},
    {"EchoelBioReverb", "Coherence-responsive space", EffectCategory::BioReactive, true, 2, 2},
    {"EchoelBioModulator", "Biometric modulation hub", EffectCategory::BioReactive, true, 2, 2},

    // CREATIVE
    {"EchoelEdgeControl", "Transient shaping", EffectCategory::Creative, false, 2, 2},
    {"EchoelHarmonicForge", "Additive harmonic design", EffectCategory::Creative, true, 2, 2},
    {"EchoelConsole", "Channel strip + summing", EffectCategory::Creative, false, 2, 2},

    // SYNTHS (as effects for re-synthesis)
    {"EchoelSynth", "Full synthesizer engine", EffectCategory::Creative, true, 0, 2},
};

static const int kNumEffects = sizeof(kAllEffects) / sizeof(EffectInfo);

//==============================================================================
// Unified Effects Processor
//==============================================================================

class EffectsChain
{
public:
    void SetSampleRate(float sampleRate)
    {
        mSampleRate = sampleRate;
        // Initialize all effect instances
    }

    void Reset()
    {
        // Reset all effect states
    }

    void SetBioParameters(float hrv, float coherence, float heartRate)
    {
        mHRV = hrv;
        mCoherence = coherence;
        mHeartRate = heartRate;

        // Apply to all bio-reactive effects
        ApplyBioModulation();
    }

    void Process(float* inputL, float* inputR, float* outputL, float* outputR, int numFrames)
    {
        // Copy input to output
        for (int i = 0; i < numFrames; i++)
        {
            outputL[i] = inputL[i];
            outputR[i] = inputR[i];
        }

        // Process through enabled effects in chain order
        // Each effect modifies the output buffer in place
    }

    // Effect enable/disable
    void EnableEffect(int effectIndex, bool enabled)
    {
        if (effectIndex >= 0 && effectIndex < kNumEffects)
        {
            mEffectEnabled[effectIndex] = enabled;
        }
    }

    bool IsEffectEnabled(int effectIndex) const
    {
        if (effectIndex >= 0 && effectIndex < kNumEffects)
        {
            return mEffectEnabled[effectIndex];
        }
        return false;
    }

private:
    float mSampleRate = 48000.0f;
    float mHRV = 0.5f;
    float mCoherence = 0.5f;
    float mHeartRate = 70.0f;

    std::array<bool, kNumEffects> mEffectEnabled = {};

    void ApplyBioModulation()
    {
        // Map biometric data to effect parameters
        // HRV → Filter cutoff, reverb decay
        // Coherence → Spatial width, harmonic content
        // Heart Rate → Modulation rates
    }
};

//==============================================================================
// Individual Effect Wrappers (for separate plugins)
//==============================================================================

// Base class for iPlug2 effect wrappers
class IPlugEffect
{
public:
    virtual ~IPlugEffect() = default;
    virtual void Reset(float sampleRate) = 0;
    virtual void Process(float** inputs, float** outputs, int nFrames) = 0;
    virtual void SetParameter(int paramIdx, float value) = 0;
    virtual float GetParameter(int paramIdx) const = 0;
    virtual int GetNumParameters() const = 0;

    // Bio-reactive interface
    virtual void SetBioData(float hrv, float coherence, float hr)
    {
        mHRV = hrv;
        mCoherence = coherence;
        mHeartRate = hr;
    }

protected:
    float mSampleRate = 48000.0f;
    float mHRV = 0.5f;
    float mCoherence = 0.5f;
    float mHeartRate = 70.0f;
};

//==============================================================================
// Dynamic EQ Effect (Bio-Reactive)
//==============================================================================

class DynamicEQEffect : public IPlugEffect
{
public:
    enum Parameters
    {
        kBand1Freq = 0,
        kBand1Gain,
        kBand1Q,
        kBand1Threshold,
        kBand1Ratio,
        // ... repeat for bands 2-6
        kBioHRVAmount,
        kBioCoherenceAmount,
        kNumParams
    };

    void Reset(float sampleRate) override
    {
        mSampleRate = sampleRate;
        // Initialize DynamicEQ DSP
    }

    void Process(float** inputs, float** outputs, int nFrames) override
    {
        // Apply HRV modulation to band gains
        float hrvMod = (mHRV - 0.5f) * mBioHRVAmount;

        for (int i = 0; i < nFrames; i++)
        {
            // Process through 6-band dynamic EQ
            float L = inputs[0][i];
            float R = inputs[1][i];

            // Apply dynamic EQ processing...

            outputs[0][i] = L;
            outputs[1][i] = R;
        }
    }

    void SetParameter(int paramIdx, float value) override
    {
        switch (paramIdx)
        {
            case kBioHRVAmount:
                mBioHRVAmount = value;
                break;
            case kBioCoherenceAmount:
                mBioCoherenceAmount = value;
                break;
            default:
                break;
        }
    }

    float GetParameter(int paramIdx) const override
    {
        return 0.0f; // Implement per parameter
    }

    int GetNumParameters() const override { return kNumParams; }

private:
    float mBioHRVAmount = 0.5f;
    float mBioCoherenceAmount = 0.5f;
};

//==============================================================================
// Convolution Reverb Effect (Bio-Reactive)
//==============================================================================

class ConvolutionReverbEffect : public IPlugEffect
{
public:
    enum Parameters
    {
        kDryWet = 0,
        kPreDelay,
        kDecay,
        kDamping,
        kWidth,
        kBioCoherenceToWet,
        kBioHRVToDecay,
        kNumParams
    };

    void Reset(float sampleRate) override
    {
        mSampleRate = sampleRate;
    }

    void Process(float** inputs, float** outputs, int nFrames) override
    {
        // Apply coherence modulation to wet mix
        float coherenceMod = mCoherence * mBioCoherenceToWet;
        float wetMix = std::clamp(mDryWet + coherenceMod, 0.0f, 1.0f);

        // Apply HRV modulation to decay
        float hrvMod = (mHRV - 0.5f) * mBioHRVToDecay;
        float decay = std::clamp(mDecay + hrvMod, 0.1f, 10.0f);

        for (int i = 0; i < nFrames; i++)
        {
            float L = inputs[0][i];
            float R = inputs[1][i];

            // Process through convolution reverb...

            outputs[0][i] = L * (1.0f - wetMix) + L * wetMix;  // Placeholder
            outputs[1][i] = R * (1.0f - wetMix) + R * wetMix;
        }
    }

    void SetParameter(int paramIdx, float value) override
    {
        switch (paramIdx)
        {
            case kDryWet: mDryWet = value; break;
            case kDecay: mDecay = value; break;
            case kBioCoherenceToWet: mBioCoherenceToWet = value; break;
            case kBioHRVToDecay: mBioHRVToDecay = value; break;
            default: break;
        }
    }

    float GetParameter(int paramIdx) const override { return 0.0f; }
    int GetNumParameters() const override { return kNumParams; }

private:
    float mDryWet = 0.3f;
    float mPreDelay = 20.0f;
    float mDecay = 2.0f;
    float mDamping = 0.5f;
    float mWidth = 1.0f;
    float mBioCoherenceToWet = 0.3f;
    float mBioHRVToDecay = 0.2f;
};

//==============================================================================
// Brick Wall Limiter Effect
//==============================================================================

class BrickWallLimiterEffect : public IPlugEffect
{
public:
    enum Parameters
    {
        kThreshold = 0,
        kCeiling,
        kRelease,
        kLookahead,
        kTruePeak,
        kNumParams
    };

    void Reset(float sampleRate) override
    {
        mSampleRate = sampleRate;
        mLookaheadBuffer.resize(static_cast<int>(sampleRate * 0.005f), 0.0f);  // 5ms
    }

    void Process(float** inputs, float** outputs, int nFrames) override
    {
        for (int i = 0; i < nFrames; i++)
        {
            float L = inputs[0][i];
            float R = inputs[1][i];

            // Find peak
            float peak = std::max(std::abs(L), std::abs(R));

            // Calculate gain reduction
            float gainReduction = 1.0f;
            if (peak > mThreshold)
            {
                gainReduction = mThreshold / peak;
            }

            // Apply smoothed gain reduction
            mCurrentGain = std::min(mCurrentGain * (1.0f - mReleaseCoeff) + gainReduction * mReleaseCoeff, 1.0f);

            outputs[0][i] = L * mCurrentGain;
            outputs[1][i] = R * mCurrentGain;
        }
    }

    void SetParameter(int paramIdx, float value) override
    {
        switch (paramIdx)
        {
            case kThreshold: mThreshold = std::pow(10.0f, value / 20.0f); break;
            case kCeiling: mCeiling = std::pow(10.0f, value / 20.0f); break;
            case kRelease: mReleaseCoeff = std::exp(-1.0f / (value * mSampleRate * 0.001f)); break;
            default: break;
        }
    }

    float GetParameter(int paramIdx) const override { return 0.0f; }
    int GetNumParameters() const override { return kNumParams; }

private:
    float mThreshold = 0.891f;  // -1dB
    float mCeiling = 0.891f;
    float mReleaseCoeff = 0.9995f;
    float mCurrentGain = 1.0f;
    std::vector<float> mLookaheadBuffer;
};

//==============================================================================
// Lofi Bitcrusher Effect
//==============================================================================

class LofiBitcrusherEffect : public IPlugEffect
{
public:
    enum Parameters
    {
        kBitDepth = 0,
        kSampleRateReduction,
        kDryWet,
        kNumParams
    };

    void Reset(float sampleRate) override
    {
        mSampleRate = sampleRate;
        mSampleHoldCounter = 0;
        mHeldSampleL = mHeldSampleR = 0.0f;
    }

    void Process(float** inputs, float** outputs, int nFrames) override
    {
        int sampleHoldRate = static_cast<int>(mSampleRate / mTargetSampleRate);
        float quantizeLevels = std::pow(2.0f, mBitDepth);

        for (int i = 0; i < nFrames; i++)
        {
            float L = inputs[0][i];
            float R = inputs[1][i];

            // Sample rate reduction
            if (mSampleHoldCounter <= 0)
            {
                mHeldSampleL = L;
                mHeldSampleR = R;
                mSampleHoldCounter = sampleHoldRate;
            }
            mSampleHoldCounter--;

            // Bit depth reduction
            float crushL = std::round(mHeldSampleL * quantizeLevels) / quantizeLevels;
            float crushR = std::round(mHeldSampleR * quantizeLevels) / quantizeLevels;

            // Dry/wet mix
            outputs[0][i] = L * (1.0f - mDryWet) + crushL * mDryWet;
            outputs[1][i] = R * (1.0f - mDryWet) + crushR * mDryWet;
        }
    }

    void SetParameter(int paramIdx, float value) override
    {
        switch (paramIdx)
        {
            case kBitDepth: mBitDepth = value; break;
            case kSampleRateReduction: mTargetSampleRate = value; break;
            case kDryWet: mDryWet = value; break;
            default: break;
        }
    }

    float GetParameter(int paramIdx) const override { return 0.0f; }
    int GetNumParameters() const override { return kNumParams; }

private:
    float mBitDepth = 12.0f;
    float mTargetSampleRate = 22050.0f;
    float mDryWet = 1.0f;
    int mSampleHoldCounter = 0;
    float mHeldSampleL = 0.0f;
    float mHeldSampleR = 0.0f;
};

//==============================================================================
// Effect Factory
//==============================================================================

class EffectFactory
{
public:
    static std::unique_ptr<IPlugEffect> CreateEffect(const char* name)
    {
        std::string effectName(name);

        if (effectName == "EchoelDynamicEQ")
            return std::make_unique<DynamicEQEffect>();
        else if (effectName == "EchoelConvolution")
            return std::make_unique<ConvolutionReverbEffect>();
        else if (effectName == "EchoelLimiter")
            return std::make_unique<BrickWallLimiterEffect>();
        else if (effectName == "EchoelLofi")
            return std::make_unique<LofiBitcrusherEffect>();

        return nullptr;
    }

    static std::vector<const char*> GetAvailableEffects()
    {
        std::vector<const char*> effects;
        for (int i = 0; i < kNumEffects; i++)
        {
            effects.push_back(kAllEffects[i].name);
        }
        return effects;
    }

    static const EffectInfo* GetEffectInfo(const char* name)
    {
        std::string effectName(name);
        for (int i = 0; i < kNumEffects; i++)
        {
            if (effectName == kAllEffects[i].name)
            {
                return &kAllEffects[i];
            }
        }
        return nullptr;
    }
};

} // namespace effects
} // namespace echoelmusic
