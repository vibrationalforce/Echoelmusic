/**
 * ╔═══════════════════════════════════════════════════════════════════════════╗
 * ║                    GRAVITY REVERB                                          ║
 * ║                                                                            ║
 * ║     "Defy Physics - Reverse Time - Infinite Space"                        ║
 * ║                                                                            ║
 * ╚═══════════════════════════════════════════════════════════════════════════╝
 *
 * Inspired by:
 * - Eventide Blackhole (Gravity control, inverse decay)
 * - Eventide SP2016 (legendary reverb algorithms)
 * - Strymon BigSky (Cloud, Bloom modes)
 *
 * Unique Features:
 * - GRAVITY control: Normal → Inverse decay (swells instead of decays)
 * - SIZE beyond physical: From closet to infinite void
 * - BLOOM: Reverb builds then releases
 * - FREEZE: Infinite sustain of current reverb state
 * - Bio-reactive modulation of all parameters
 *
 * ══════════════════════════════════════════════════════════════════════════════
 *
 *     Normal Gravity (1.0):          Inverse Gravity (-1.0):
 *     ▓▓▓▓▓▓▓▒▒▒░░░░                 ░░░░▒▒▒▓▓▓▓▓▓▓
 *     │  ╲                                      ╱  │
 *     │    ╲  Decay                    Swell  ╱    │
 *     │      ╲                              ╱      │
 *     └────────────────               ────────────────┘
 *
 * Bio-Reactive Mapping:
 * - Coherence → Gravity (high coherence = natural, low = inverse)
 * - HRV → Size modulation
 * - Breathing → Bloom rate
 * - Stress → Freeze probability
 */

#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <cmath>
#include <random>

class GravityReverb
{
public:
    //==========================================================================
    // Constants
    //==========================================================================

    static constexpr int kMaxDelayLines = 16;
    static constexpr int kMaxDelaySamples = 192000 * 10;  // 10 seconds at 192kHz
    static constexpr int kDiffusionStages = 4;

    //==========================================================================
    // Reverb Modes
    //==========================================================================

    enum class Mode
    {
        Hall,           // Traditional concert hall
        Room,           // Small room
        Plate,          // Vintage plate reverb
        Spring,         // Spring reverb character
        Shimmer,        // Octave-up in feedback
        Cloud,          // Dense, diffuse, infinite
        Blackhole,      // Massive, dark, infinite
        Bloom,          // Builds then releases
        Inverse,        // Reverse envelope
        Freeze          // Infinite sustain
    };

    //==========================================================================
    // Parameters
    //==========================================================================

    struct Parameters
    {
        // Core
        float mix = 0.5f;               // 0-1 dry/wet
        float size = 0.7f;              // 0-1 (maps to 0.1s - 100s)
        float decay = 0.8f;             // 0-1 (maps to 0.1 - infinite)
        float predelay = 0.0f;          // 0-500ms

        // Gravity (unique feature)
        float gravity = 1.0f;           // -1 to +1 (negative = inverse decay)

        // Tone
        float lowCut = 20.0f;           // 20-2000 Hz
        float highCut = 20000.0f;       // 1000-20000 Hz
        float damping = 0.5f;           // 0-1 (high freq decay)

        // Modulation
        float modRate = 0.5f;           // 0-10 Hz
        float modDepth = 0.3f;          // 0-1

        // Special
        float bloom = 0.0f;             // 0-1 (attack envelope)
        float shimmer = 0.0f;           // 0-1 (pitch shift amount)
        float diffusion = 0.8f;         // 0-1 (smear)
        bool freeze = false;            // Infinite hold

        // Mode
        Mode mode = Mode::Hall;

        Parameters() = default;
    };

    //==========================================================================
    // Bio State
    //==========================================================================

    struct BioState
    {
        float coherence = 0.5f;
        float hrv = 0.5f;
        float breathingPhase = 0.0f;
        float stress = 0.5f;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    GravityReverb()
    {
        initializeDelayLines();
    }

    ~GravityReverb() = default;

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;

        // Initialize delay lines
        for (auto& delay : delayLines)
        {
            delay.resize(kMaxDelaySamples, 0.0f);
            std::fill(delay.begin(), delay.end(), 0.0f);
        }

        // Initialize filters
        for (int i = 0; i < kMaxDelayLines; ++i)
        {
            lowpassState[i] = 0.0f;
            highpassState[i] = 0.0f;
            allpassState[i][0] = 0.0f;
            allpassState[i][1] = 0.0f;
        }

        // Pre-delay buffer
        predelayBuffer.resize(static_cast<int>(sampleRate * 0.5f), 0.0f);

        // Bloom envelope
        bloomEnvelope = 0.0f;

        // Freeze buffer
        freezeBuffer[0].resize(maxBlockSize * 4, 0.0f);
        freezeBuffer[1].resize(maxBlockSize * 4, 0.0f);

        calculateDelayTimes();
    }

    //==========================================================================
    // Parameter Control
    //==========================================================================

    void setParameters(const Parameters& newParams)
    {
        params = newParams;
        calculateDelayTimes();
        calculateFilterCoefficients();
    }

    const Parameters& getParameters() const
    {
        return params;
    }

    void setGravity(float gravity)
    {
        params.gravity = std::clamp(gravity, -1.0f, 1.0f);
    }

    void setFreeze(bool freeze)
    {
        if (freeze && !params.freeze)
        {
            // Capture current state
            captureFreeze();
        }
        params.freeze = freeze;
    }

    void setMode(Mode mode)
    {
        params.mode = mode;
        applyModePreset();
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
        const int numChannels = buffer.getNumChannels();

        for (int sample = 0; sample < numSamples; ++sample)
        {
            // Update modulation
            updateModulation();

            // Update bloom envelope
            updateBloomEnvelope();

            // Get input (mono sum for reverb input)
            float inputL = numChannels > 0 ? buffer.getSample(0, sample) : 0.0f;
            float inputR = numChannels > 1 ? buffer.getSample(1, sample) : inputL;
            float monoInput = (inputL + inputR) * 0.5f;

            // Pre-delay
            float delayedInput = processPredelay(monoInput);

            // Apply bloom envelope to input
            float bloomedInput = delayedInput * getBloomGain();

            // Process reverb network
            float reverbL = 0.0f;
            float reverbR = 0.0f;

            if (params.freeze)
            {
                // Use frozen buffer
                reverbL = processFreezeBuffer(0, sample);
                reverbR = processFreezeBuffer(1, sample);
            }
            else
            {
                // Normal reverb processing with gravity
                processReverbNetwork(bloomedInput, reverbL, reverbR);
            }

            // Apply shimmer (octave-up pitch shift in feedback)
            if (params.shimmer > 0.01f)
            {
                applyShimmer(reverbL, reverbR);
            }

            // Mix dry/wet
            float wetL = reverbL * params.mix;
            float wetR = reverbR * params.mix;
            float dryL = inputL * (1.0f - params.mix);
            float dryR = inputR * (1.0f - params.mix);

            // Output
            if (numChannels > 0)
                buffer.setSample(0, sample, dryL + wetL);
            if (numChannels > 1)
                buffer.setSample(1, sample, dryR + wetR);
        }
    }

    //==========================================================================
    // Presets
    //==========================================================================

    void loadPreset(int presetIndex)
    {
        switch (presetIndex)
        {
            case 0: // Infinite Void
                params.size = 1.0f;
                params.decay = 0.99f;
                params.gravity = 1.0f;
                params.damping = 0.3f;
                params.diffusion = 0.95f;
                params.mode = Mode::Blackhole;
                break;

            case 1: // Reverse Swell
                params.size = 0.7f;
                params.decay = 0.85f;
                params.gravity = -0.8f;
                params.bloom = 0.7f;
                params.mode = Mode::Inverse;
                break;

            case 2: // Shimmer Heaven
                params.size = 0.8f;
                params.decay = 0.9f;
                params.gravity = 1.0f;
                params.shimmer = 0.5f;
                params.mode = Mode::Shimmer;
                break;

            case 3: // Bio-Breath
                params.size = 0.6f;
                params.decay = 0.8f;
                params.gravity = 0.0f;  // Will be modulated by coherence
                params.modDepth = 0.4f;
                bioReactiveEnabled = true;
                break;

            case 4: // Frozen Time
                params.size = 0.9f;
                params.decay = 1.0f;
                params.freeze = true;
                params.diffusion = 1.0f;
                params.mode = Mode::Freeze;
                break;

            default:
                break;
        }

        calculateDelayTimes();
        calculateFilterCoefficients();
    }

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    Parameters params;
    BioState bioState;
    bool bioReactiveEnabled = false;

    double currentSampleRate = 48000.0;

    // Delay lines for FDN reverb
    std::array<std::vector<float>, kMaxDelayLines> delayLines;
    std::array<int, kMaxDelayLines> delayWritePos;
    std::array<int, kMaxDelayLines> delayTimes;

    // Filters
    std::array<float, kMaxDelayLines> lowpassState;
    std::array<float, kMaxDelayLines> highpassState;
    std::array<std::array<float, 2>, kMaxDelayLines> allpassState;
    float lpCoeff = 0.5f;
    float hpCoeff = 0.01f;

    // Pre-delay
    std::vector<float> predelayBuffer;
    int predelayWritePos = 0;
    int predelaySamples = 0;

    // Modulation
    float modPhase = 0.0f;
    float currentModulation = 0.0f;

    // Bloom
    float bloomEnvelope = 0.0f;
    float bloomAttack = 0.0f;
    float bloomRelease = 0.0f;

    // Freeze
    std::array<std::vector<float>, 2> freezeBuffer;
    int freezeReadPos = 0;
    bool freezeCaptured = false;

    // Shimmer pitch shifter state
    float shimmerPhase = 0.0f;
    std::array<float, 4096> shimmerBuffer;
    int shimmerWritePos = 0;

    // Random for diffusion
    std::mt19937 rng{ std::random_device{}() };

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void initializeDelayLines()
    {
        for (int i = 0; i < kMaxDelayLines; ++i)
        {
            delayWritePos[i] = 0;
            delayTimes[i] = 1000 + i * 500;
        }

        shimmerBuffer.fill(0.0f);
    }

    void calculateDelayTimes()
    {
        // Prime number based delay times for maximum diffusion
        const int primes[] = { 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53 };

        float sizeMs = 10.0f + params.size * params.size * 5000.0f;  // 10ms to 5s

        for (int i = 0; i < kMaxDelayLines; ++i)
        {
            float baseTime = sizeMs * (0.5f + 0.5f * i / kMaxDelayLines);
            float primeScale = primes[i % 16] / 10.0f;
            delayTimes[i] = static_cast<int>(baseTime * primeScale * currentSampleRate / 1000.0f);
            delayTimes[i] = std::min(delayTimes[i], kMaxDelaySamples - 1);
        }

        // Pre-delay
        predelaySamples = static_cast<int>(params.predelay * currentSampleRate / 1000.0f);
    }

    void calculateFilterCoefficients()
    {
        // Lowpass for damping
        float dampFreq = 20000.0f * (1.0f - params.damping);
        lpCoeff = std::exp(-2.0f * M_PI * dampFreq / currentSampleRate);

        // Highpass for low cut
        hpCoeff = std::exp(-2.0f * M_PI * params.lowCut / currentSampleRate);
    }

    float processPredelay(float input)
    {
        if (predelaySamples == 0)
            return input;

        int readPos = predelayWritePos - predelaySamples;
        if (readPos < 0)
            readPos += predelayBuffer.size();

        float output = predelayBuffer[readPos];
        predelayBuffer[predelayWritePos] = input;

        predelayWritePos++;
        if (predelayWritePos >= static_cast<int>(predelayBuffer.size()))
            predelayWritePos = 0;

        return output;
    }

    void updateModulation()
    {
        modPhase += params.modRate / currentSampleRate;
        if (modPhase >= 1.0f)
            modPhase -= 1.0f;

        currentModulation = std::sin(modPhase * 2.0f * M_PI) * params.modDepth;
    }

    void updateBloomEnvelope()
    {
        if (params.bloom > 0.01f)
        {
            // Bloom creates an attack envelope
            float target = 1.0f;
            float attackTime = params.bloom * 2.0f;  // 0-2 seconds
            float attackCoeff = 1.0f - std::exp(-1.0f / (attackTime * currentSampleRate));

            bloomEnvelope += (target - bloomEnvelope) * attackCoeff;
        }
        else
        {
            bloomEnvelope = 1.0f;
        }
    }

    float getBloomGain()
    {
        return bloomEnvelope;
    }

    void processReverbNetwork(float input, float& outL, float& outR)
    {
        // Feedback Delay Network (FDN) with gravity control
        std::array<float, kMaxDelayLines> outputs;

        // Read from delay lines
        for (int i = 0; i < kMaxDelayLines; ++i)
        {
            int modOffset = static_cast<int>(currentModulation * 50.0f);
            int readPos = delayWritePos[i] - delayTimes[i] - modOffset;
            while (readPos < 0)
                readPos += delayLines[i].size();

            outputs[i] = delayLines[i][readPos];

            // Apply damping filter
            lowpassState[i] = outputs[i] * (1.0f - lpCoeff) + lowpassState[i] * lpCoeff;
            outputs[i] = lowpassState[i];
        }

        // Calculate feedback with gravity
        float decayGain = params.decay;
        float gravityFactor = params.gravity;

        // Gravity affects the envelope shape
        if (gravityFactor < 0.0f)
        {
            // Inverse gravity: early reflections are quiet, tail is loud
            float timeFactor = bloomEnvelope;  // Use bloom as time proxy
            decayGain *= (1.0f + std::abs(gravityFactor) * timeFactor);
        }

        // Hadamard-like mixing matrix
        std::array<float, kMaxDelayLines> mixed;
        for (int i = 0; i < kMaxDelayLines; ++i)
        {
            mixed[i] = 0.0f;
            for (int j = 0; j < kMaxDelayLines; ++j)
            {
                float sign = ((i + j) % 2 == 0) ? 1.0f : -1.0f;
                mixed[i] += outputs[j] * sign / std::sqrt(static_cast<float>(kMaxDelayLines));
            }
        }

        // Write back to delay lines with input and feedback
        for (int i = 0; i < kMaxDelayLines; ++i)
        {
            float feedback = mixed[i] * decayGain;

            // Soft clip feedback to prevent runaway
            feedback = std::tanh(feedback);

            // Add diffusion via allpass
            if (params.diffusion > 0.01f)
            {
                feedback = processAllpass(i, feedback, params.diffusion * 0.7f);
            }

            delayLines[i][delayWritePos[i]] = input + feedback;

            delayWritePos[i]++;
            if (delayWritePos[i] >= static_cast<int>(delayLines[i].size()))
                delayWritePos[i] = 0;
        }

        // Sum outputs for stereo
        outL = 0.0f;
        outR = 0.0f;
        for (int i = 0; i < kMaxDelayLines; ++i)
        {
            if (i % 2 == 0)
                outL += outputs[i];
            else
                outR += outputs[i];
        }

        outL /= (kMaxDelayLines / 2);
        outR /= (kMaxDelayLines / 2);
    }

    float processAllpass(int index, float input, float gain)
    {
        float& state = allpassState[index][0];
        float output = -input * gain + state;
        state = input + output * gain;
        return output;
    }

    void applyShimmer(float& left, float& right)
    {
        // Simple pitch doubling for shimmer effect
        float pitchRatio = 2.0f;  // Octave up

        shimmerBuffer[shimmerWritePos] = (left + right) * 0.5f;
        shimmerWritePos = (shimmerWritePos + 1) % shimmerBuffer.size();

        // Read at half speed for octave up
        float readPos = shimmerPhase;
        int readPosInt = static_cast<int>(readPos);
        float frac = readPos - readPosInt;

        int idx0 = readPosInt % shimmerBuffer.size();
        int idx1 = (readPosInt + 1) % shimmerBuffer.size();

        float shimmerSample = shimmerBuffer[idx0] * (1.0f - frac) +
                              shimmerBuffer[idx1] * frac;

        shimmerPhase += pitchRatio;
        while (shimmerPhase >= shimmerBuffer.size())
            shimmerPhase -= shimmerBuffer.size();

        // Mix shimmer into output
        float shimmerGain = params.shimmer * 0.5f;
        left += shimmerSample * shimmerGain;
        right += shimmerSample * shimmerGain;
    }

    void captureFreeze()
    {
        // Capture current reverb state
        freezeCaptured = true;
        freezeReadPos = 0;

        // Copy from delay lines to freeze buffer
        for (size_t i = 0; i < freezeBuffer[0].size(); ++i)
        {
            float sumL = 0.0f, sumR = 0.0f;
            for (int d = 0; d < kMaxDelayLines; ++d)
            {
                int pos = (delayWritePos[d] - i) % delayLines[d].size();
                if (pos < 0) pos += delayLines[d].size();

                if (d % 2 == 0)
                    sumL += delayLines[d][pos];
                else
                    sumR += delayLines[d][pos];
            }
            freezeBuffer[0][i] = sumL / (kMaxDelayLines / 2);
            freezeBuffer[1][i] = sumR / (kMaxDelayLines / 2);
        }
    }

    float processFreezeBuffer(int channel, int sample)
    {
        if (!freezeCaptured)
            return 0.0f;

        float output = freezeBuffer[channel][freezeReadPos];

        if (channel == 1)
        {
            freezeReadPos++;
            if (freezeReadPos >= static_cast<int>(freezeBuffer[0].size()))
                freezeReadPos = 0;
        }

        return output;
    }

    void applyBioModulation()
    {
        // Coherence → Gravity
        // High coherence = natural decay (gravity = 1)
        // Low coherence = inverse decay (gravity = -1)
        params.gravity = (bioState.coherence - 0.5f) * 2.0f;

        // HRV → Size modulation
        float sizeModulation = (bioState.hrv - 0.5f) * 0.2f;
        params.size = std::clamp(params.size + sizeModulation, 0.0f, 1.0f);

        // Breathing → Bloom
        params.bloom = std::sin(bioState.breathingPhase * M_PI) * 0.5f;

        // Stress → Freeze tendency (high stress = more likely to freeze)
        if (bioState.stress > 0.8f && !params.freeze)
        {
            std::uniform_real_distribution<float> dist(0.0f, 1.0f);
            if (dist(rng) < 0.01f)
            {
                setFreeze(true);
            }
        }
        else if (bioState.stress < 0.3f && params.freeze)
        {
            setFreeze(false);
        }
    }

    void applyModePreset()
    {
        switch (params.mode)
        {
            case Mode::Hall:
                params.size = 0.6f;
                params.decay = 0.75f;
                params.diffusion = 0.7f;
                break;

            case Mode::Blackhole:
                params.size = 1.0f;
                params.decay = 0.95f;
                params.diffusion = 0.95f;
                params.damping = 0.4f;
                break;

            case Mode::Shimmer:
                params.shimmer = 0.4f;
                params.decay = 0.85f;
                break;

            case Mode::Inverse:
                params.gravity = -0.7f;
                params.bloom = 0.5f;
                break;

            case Mode::Freeze:
                params.freeze = true;
                params.decay = 1.0f;
                break;

            default:
                break;
        }

        calculateDelayTimes();
    }

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GravityReverb)
};
