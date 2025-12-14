/**
 * ╔═══════════════════════════════════════════════════════════════════════════╗
 * ║                    ULTRA TAP DELAY                                         ║
 * ║                                                                            ║
 * ║     "64 Taps of Rhythmic Infinity"                                        ║
 * ║                                                                            ║
 * ╚═══════════════════════════════════════════════════════════════════════════╝
 *
 * Inspired by:
 * - Eventide UltraTap (H9, H90, standalone pedal)
 * - Eventide TimeFactor multi-tap algorithms
 * - Classic multi-head tape delays
 *
 * Unique Features:
 * - Up to 64 independent delay taps
 * - SPREAD: Control tap spacing (linear to exponential)
 * - TAPER: Volume envelope across taps (fade in/out)
 * - SLURM: Smear/blur the taps together
 * - CHOP: Rhythmic gating of taps
 * - Tap patterns: Linear, Exponential, Random, Euclidean, Bio-reactive
 *
 * ══════════════════════════════════════════════════════════════════════════════
 *
 *     Linear Spread:                    Exponential Spread:
 *     ▓ ▓ ▓ ▓ ▓ ▓ ▓ ▓                  ▓▓▓▓ ▓▓ ▓  ▓   ▓
 *     │ │ │ │ │ │ │ │                  ││││ ││ │  │   │
 *     Equal spacing                     Clustered early, sparse late
 *
 *     Taper Down:                       Taper Up:
 *     ▓▓▓▒▒░░                           ░░▒▒▓▓▓
 *     Loud→Quiet                        Quiet→Loud
 *
 * Bio-Reactive Mapping:
 * - HRV → Spread amount
 * - Coherence → Taper direction
 * - Breathing → Chop rate
 * - Stress → Slurm amount
 */

#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <cmath>
#include <random>

class UltraTapDelay
{
public:
    //==========================================================================
    // Constants
    //==========================================================================

    static constexpr int kMaxTaps = 64;
    static constexpr int kMaxDelaySamples = 192000 * 4;  // 4 seconds at 192kHz

    //==========================================================================
    // Tap Patterns
    //==========================================================================

    enum class TapPattern
    {
        Linear,         // Evenly spaced taps
        Exponential,    // Clustered early, spread late
        Logarithmic,    // Spread early, clustered late
        Random,         // Random spacing
        Euclidean,      // Euclidean rhythm distribution
        Fibonacci,      // Golden ratio spacing
        Primes,         // Prime number spacing
        BioReactive     // Driven by bio-data
    };

    //==========================================================================
    // Parameters
    //==========================================================================

    struct Parameters
    {
        // Core
        float mix = 0.5f;               // 0-1 dry/wet
        float length = 1.0f;            // Total delay time (seconds)
        int numTaps = 8;                // 1-64 taps
        float feedback = 0.3f;          // 0-1

        // Tap distribution
        TapPattern pattern = TapPattern::Linear;
        float spread = 0.5f;            // 0-1 (affects spacing curve)
        float taper = 0.0f;             // -1 to +1 (volume across taps)

        // Special
        float slurm = 0.0f;             // 0-1 (smear/blur taps)
        float chop = 0.0f;              // 0-1 (rhythmic gating)
        float chopRate = 4.0f;          // Hz (gate frequency)

        // Tone
        float lowCut = 20.0f;
        float highCut = 20000.0f;
        float diffusion = 0.0f;         // 0-1 (smear each tap)

        // Modulation
        float modRate = 0.5f;
        float modDepth = 0.0f;

        // Width
        float width = 1.0f;             // 0-2 (stereo spread)

        Parameters() = default;
    };

    //==========================================================================
    // Single Tap Structure
    //==========================================================================

    struct Tap
    {
        int delaySamples = 0;
        float gain = 1.0f;
        float pan = 0.5f;               // 0=L, 0.5=C, 1=R
        bool active = true;

        Tap() = default;
    };

    //==========================================================================
    // Bio State
    //==========================================================================

    struct BioState
    {
        float hrv = 0.5f;
        float coherence = 0.5f;
        float breathingPhase = 0.0f;
        float stress = 0.5f;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    UltraTapDelay()
    {
        reset();
    }

    ~UltraTapDelay() = default;

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;

        // Initialize delay buffer
        delayBuffer[0].resize(kMaxDelaySamples, 0.0f);
        delayBuffer[1].resize(kMaxDelaySamples, 0.0f);

        // Slurm diffusion buffers
        for (int i = 0; i < 8; ++i)
        {
            slurmBuffer[i].resize(4096, 0.0f);
            slurmWritePos[i] = 0;
        }

        reset();
        calculateTaps();
    }

    void reset()
    {
        writePos = 0;
        for (auto& buf : delayBuffer)
            std::fill(buf.begin(), buf.end(), 0.0f);

        for (auto& buf : slurmBuffer)
            std::fill(buf.begin(), buf.end(), 0.0f);

        chopPhase = 0.0f;
        modPhase = 0.0f;
        lpState[0] = lpState[1] = 0.0f;
        hpState[0] = hpState[1] = 0.0f;
    }

    //==========================================================================
    // Parameter Control
    //==========================================================================

    void setParameters(const Parameters& newParams)
    {
        params = newParams;
        calculateTaps();
        calculateFilterCoeffs();
    }

    void setNumTaps(int num)
    {
        params.numTaps = std::clamp(num, 1, kMaxTaps);
        calculateTaps();
    }

    void setSpread(float spread)
    {
        params.spread = std::clamp(spread, 0.0f, 1.0f);
        calculateTaps();
    }

    void setTaper(float taper)
    {
        params.taper = std::clamp(taper, -1.0f, 1.0f);
        calculateTaps();
    }

    void setPattern(TapPattern pattern)
    {
        params.pattern = pattern;
        calculateTaps();
    }

    const Parameters& getParameters() const
    {
        return params;
    }

    //==========================================================================
    // Bio-Reactive Control
    //==========================================================================

    void setBioState(const BioState& state)
    {
        bioState = state;

        if (bioReactiveEnabled)
        {
            applyBioModulation();
        }
    }

    void setBioReactiveEnabled(bool enabled)
    {
        bioReactiveEnabled = enabled;
    }

    //==========================================================================
    // Processing
    //==========================================================================

    void process(juce::AudioBuffer<float>& buffer)
    {
        const int numSamples = buffer.getNumSamples();
        const int numChannels = std::min(buffer.getNumChannels(), 2);

        for (int sample = 0; sample < numSamples; ++sample)
        {
            // Update modulation
            updateModulation();

            // Update chop gate
            updateChop();

            // Get input
            float inputL = numChannels > 0 ? buffer.getSample(0, sample) : 0.0f;
            float inputR = numChannels > 1 ? buffer.getSample(1, sample) : inputL;
            float monoInput = (inputL + inputR) * 0.5f;

            // Read from all taps
            float tapSumL = 0.0f;
            float tapSumR = 0.0f;

            for (int t = 0; t < params.numTaps; ++t)
            {
                const auto& tap = taps[t];
                if (!tap.active) continue;

                // Calculate read position with modulation
                int modOffset = static_cast<int>(currentModulation * 20.0f);
                int readPos = writePos - tap.delaySamples - modOffset;
                while (readPos < 0)
                    readPos += delayBuffer[0].size();

                // Read from delay buffer
                float tapSample = delayBuffer[0][readPos];

                // Apply slurm (diffusion per tap)
                if (params.slurm > 0.01f)
                {
                    tapSample = applySlurm(t % 8, tapSample);
                }

                // Apply chop (rhythmic gate)
                if (params.chop > 0.01f)
                {
                    tapSample *= chopGain;
                }

                // Apply tap gain with taper
                tapSample *= tap.gain;

                // Pan to stereo
                float panL = std::cos(tap.pan * M_PI * 0.5f);
                float panR = std::sin(tap.pan * M_PI * 0.5f);

                tapSumL += tapSample * panL;
                tapSumR += tapSample * panR;
            }

            // Normalize by number of taps
            float normFactor = 1.0f / std::sqrt(static_cast<float>(params.numTaps));
            tapSumL *= normFactor;
            tapSumR *= normFactor;

            // Apply filters
            tapSumL = applyFilters(tapSumL, 0);
            tapSumR = applyFilters(tapSumR, 1);

            // Apply stereo width
            float mid = (tapSumL + tapSumR) * 0.5f;
            float side = (tapSumL - tapSumR) * 0.5f * params.width;
            tapSumL = mid + side;
            tapSumR = mid - side;

            // Write to delay buffer with feedback
            float feedbackSample = (tapSumL + tapSumR) * 0.5f * params.feedback;
            delayBuffer[0][writePos] = monoInput + feedbackSample;
            delayBuffer[1][writePos] = monoInput + feedbackSample;

            // Increment write position
            writePos++;
            if (writePos >= static_cast<int>(delayBuffer[0].size()))
                writePos = 0;

            // Mix dry/wet
            float outL = inputL * (1.0f - params.mix) + tapSumL * params.mix;
            float outR = inputR * (1.0f - params.mix) + tapSumR * params.mix;

            // Output
            if (numChannels > 0)
                buffer.setSample(0, sample, outL);
            if (numChannels > 1)
                buffer.setSample(1, sample, outR);
        }
    }

    //==========================================================================
    // Tap Access (for visualization)
    //==========================================================================

    const std::array<Tap, kMaxTaps>& getTaps() const
    {
        return taps;
    }

    //==========================================================================
    // Presets
    //==========================================================================

    void loadPreset(int presetIndex)
    {
        switch (presetIndex)
        {
            case 0: // Rhythmic Echoes
                params.numTaps = 8;
                params.length = 0.5f;
                params.pattern = TapPattern::Linear;
                params.spread = 0.5f;
                params.taper = -0.3f;
                params.feedback = 0.3f;
                break;

            case 1: // Swell
                params.numTaps = 16;
                params.length = 1.0f;
                params.pattern = TapPattern::Exponential;
                params.spread = 0.7f;
                params.taper = 0.8f;  // Volume builds up
                params.slurm = 0.4f;
                break;

            case 2: // Diffuse Cloud
                params.numTaps = 32;
                params.length = 2.0f;
                params.pattern = TapPattern::Random;
                params.slurm = 0.8f;
                params.diffusion = 0.6f;
                params.feedback = 0.5f;
                break;

            case 3: // Euclidean Rhythm
                params.numTaps = 12;
                params.length = 0.75f;
                params.pattern = TapPattern::Euclidean;
                params.chop = 0.5f;
                params.chopRate = 8.0f;
                break;

            case 4: // Golden Spiral
                params.numTaps = 21;  // Fibonacci number
                params.length = 1.5f;
                params.pattern = TapPattern::Fibonacci;
                params.spread = 0.618f;  // Golden ratio
                params.width = 1.5f;
                break;

            case 5: // Bio Pulse
                params.numTaps = 16;
                params.length = 1.0f;
                params.pattern = TapPattern::BioReactive;
                bioReactiveEnabled = true;
                break;

            default:
                break;
        }

        calculateTaps();
    }

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    Parameters params;
    BioState bioState;
    bool bioReactiveEnabled = false;

    double currentSampleRate = 48000.0;

    // Delay buffer (stereo)
    std::array<std::vector<float>, 2> delayBuffer;
    int writePos = 0;

    // Taps
    std::array<Tap, kMaxTaps> taps;

    // Slurm diffusion
    std::array<std::vector<float>, 8> slurmBuffer;
    std::array<int, 8> slurmWritePos;

    // Chop
    float chopPhase = 0.0f;
    float chopGain = 1.0f;

    // Modulation
    float modPhase = 0.0f;
    float currentModulation = 0.0f;

    // Filters
    float lpCoeff = 0.99f;
    float hpCoeff = 0.01f;
    std::array<float, 2> lpState;
    std::array<float, 2> hpState;

    // Random
    std::mt19937 rng{ std::random_device{}() };

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void calculateTaps()
    {
        int totalSamples = static_cast<int>(params.length * currentSampleRate);
        totalSamples = std::min(totalSamples, kMaxDelaySamples - 1);

        // Calculate tap positions based on pattern
        std::vector<float> positions(params.numTaps);

        switch (params.pattern)
        {
            case TapPattern::Linear:
                for (int i = 0; i < params.numTaps; ++i)
                {
                    positions[i] = static_cast<float>(i + 1) / params.numTaps;
                }
                break;

            case TapPattern::Exponential:
                for (int i = 0; i < params.numTaps; ++i)
                {
                    float t = static_cast<float>(i) / (params.numTaps - 1);
                    float curve = params.spread * 3.0f + 1.0f;
                    positions[i] = std::pow(t, curve);
                }
                break;

            case TapPattern::Logarithmic:
                for (int i = 0; i < params.numTaps; ++i)
                {
                    float t = static_cast<float>(i + 1) / params.numTaps;
                    float curve = params.spread * 3.0f + 1.0f;
                    positions[i] = 1.0f - std::pow(1.0f - t, curve);
                }
                break;

            case TapPattern::Random:
            {
                std::uniform_real_distribution<float> dist(0.0f, 1.0f);
                for (int i = 0; i < params.numTaps; ++i)
                {
                    positions[i] = dist(rng);
                }
                std::sort(positions.begin(), positions.begin() + params.numTaps);
                break;
            }

            case TapPattern::Euclidean:
            {
                // Euclidean rhythm algorithm
                int pulses = params.numTaps;
                int steps = static_cast<int>(pulses / params.spread + 0.5f);
                steps = std::max(steps, pulses);

                for (int i = 0; i < params.numTaps; ++i)
                {
                    int bucket = (i * steps) / pulses;
                    positions[i] = static_cast<float>(bucket) / steps;
                }
                break;
            }

            case TapPattern::Fibonacci:
            {
                // Golden ratio spacing
                float phi = 1.618033988749895f;
                for (int i = 0; i < params.numTaps; ++i)
                {
                    float fib = std::fmod(i * phi, 1.0f);
                    positions[i] = fib;
                }
                std::sort(positions.begin(), positions.begin() + params.numTaps);
                break;
            }

            case TapPattern::Primes:
            {
                // Prime number based spacing
                const int primes[] = { 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37,
                                       41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89 };
                int maxPrime = primes[std::min(params.numTaps - 1, 23)];
                for (int i = 0; i < params.numTaps; ++i)
                {
                    positions[i] = static_cast<float>(primes[i % 24]) / maxPrime;
                }
                break;
            }

            case TapPattern::BioReactive:
            {
                // Bio-data driven spacing
                for (int i = 0; i < params.numTaps; ++i)
                {
                    float base = static_cast<float>(i + 1) / params.numTaps;
                    float hrvMod = std::sin(i * bioState.hrv * M_PI) * 0.2f;
                    positions[i] = std::clamp(base + hrvMod, 0.0f, 1.0f);
                }
                std::sort(positions.begin(), positions.begin() + params.numTaps);
                break;
            }
        }

        // Apply positions to taps with taper
        for (int i = 0; i < params.numTaps; ++i)
        {
            taps[i].delaySamples = static_cast<int>(positions[i] * totalSamples);
            taps[i].delaySamples = std::max(taps[i].delaySamples, 1);
            taps[i].active = true;

            // Calculate gain based on taper
            float tapPosition = static_cast<float>(i) / (params.numTaps - 1);
            if (params.taper > 0.0f)
            {
                // Taper up (quiet to loud)
                taps[i].gain = std::pow(tapPosition, params.taper * 2.0f);
            }
            else if (params.taper < 0.0f)
            {
                // Taper down (loud to quiet)
                taps[i].gain = std::pow(1.0f - tapPosition, -params.taper * 2.0f);
            }
            else
            {
                taps[i].gain = 1.0f;
            }

            // Pan across stereo field
            taps[i].pan = tapPosition;
        }

        // Deactivate unused taps
        for (int i = params.numTaps; i < kMaxTaps; ++i)
        {
            taps[i].active = false;
        }
    }

    void calculateFilterCoeffs()
    {
        lpCoeff = std::exp(-2.0f * M_PI * params.highCut / currentSampleRate);
        hpCoeff = std::exp(-2.0f * M_PI * params.lowCut / currentSampleRate);
    }

    void updateModulation()
    {
        modPhase += params.modRate / currentSampleRate;
        if (modPhase >= 1.0f)
            modPhase -= 1.0f;

        currentModulation = std::sin(modPhase * 2.0f * M_PI) * params.modDepth;
    }

    void updateChop()
    {
        if (params.chop < 0.01f)
        {
            chopGain = 1.0f;
            return;
        }

        chopPhase += params.chopRate / currentSampleRate;
        if (chopPhase >= 1.0f)
            chopPhase -= 1.0f;

        // Square wave gate with adjustable duty cycle
        float dutyCycle = 1.0f - params.chop;
        chopGain = chopPhase < dutyCycle ? 1.0f : 0.0f;

        // Smooth the gate to avoid clicks
        static float smoothedChopGain = 1.0f;
        smoothedChopGain = smoothedChopGain * 0.99f + chopGain * 0.01f;
        chopGain = smoothedChopGain;
    }

    float applySlurm(int slurmIndex, float input)
    {
        // Slurm is a diffusion/smear effect
        auto& buffer = slurmBuffer[slurmIndex];
        int& wPos = slurmWritePos[slurmIndex];

        int delaySamples = static_cast<int>(params.slurm * 200.0f + 1);
        int readPos = wPos - delaySamples;
        if (readPos < 0)
            readPos += buffer.size();

        float delayed = buffer[readPos];
        float output = input * (1.0f - params.slurm * 0.5f) + delayed * params.slurm * 0.5f;

        buffer[wPos] = input + delayed * params.slurm * 0.3f;

        wPos++;
        if (wPos >= static_cast<int>(buffer.size()))
            wPos = 0;

        return output;
    }

    float applyFilters(float input, int channel)
    {
        // Lowpass
        lpState[channel] = input * (1.0f - lpCoeff) + lpState[channel] * lpCoeff;
        float lp = lpState[channel];

        // Highpass
        hpState[channel] = (input - lp) * hpCoeff + hpState[channel] * (1.0f - hpCoeff);

        return lp - hpState[channel] * 0.1f;
    }

    void applyBioModulation()
    {
        // HRV → Spread
        params.spread = bioState.hrv;

        // Coherence → Taper direction
        params.taper = (bioState.coherence - 0.5f) * 2.0f;

        // Breathing → Chop rate
        params.chopRate = 2.0f + bioState.breathingPhase * 8.0f;

        // Stress → Slurm
        params.slurm = bioState.stress * 0.8f;

        calculateTaps();
    }

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(UltraTapDelay)
};
